#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 16-10-2026
# Version: 2.2
# Description: Verify Backstage platform environment
##################################################################

set -uo pipefail

#-----------------------------------------------------------------
# GLOBAL VARIABLES
#-----------------------------------------------------------------

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SHARED_FILE="${PARENT_DIR}/shared.sh"
CONFIG_FILE="${PARENT_DIR}/config.sh"

source "${SHARED_FILE}"
source "${CONFIG_FILE}"

ERRORS=0

#-----------------------------------------------------------------
# FUNCTIONS
#-----------------------------------------------------------------

function load_postgres_credentials() {

  POSTGRES_USER=$(kubectl get secret ${POSTGRES_SECRET} \
    -n "${NS_BACKSTAGE}" \
    -o jsonpath='{.data.user}' | base64 -d)

  POSTGRES_PASSWORD=$(kubectl get secret ${POSTGRES_SECRET} \
    -n "${NS_BACKSTAGE}" \
    -o jsonpath='{.data.password}' | base64 -d)

  POSTGRES_DB=$(kubectl get secret ${POSTGRES_SECRET} \
    -n "${NS_BACKSTAGE}" \
    -o jsonpath='{.data.database}' | base64 -d)
}

function check_cluster() {

  SetHeading "Verify Kubernetes Cluster"

  if kubectl cluster-info >/dev/null 2>&1; then
    SetComment "Cluster '${CLUSTER_NAME}' is reachable."
  else
    SetError "Cluster '${CLUSTER_NAME}' is not reachable."
    ((ERRORS++))
  fi
}

function check_postgresql() {

  SetHeading "Verify PostgreSQL"

  local POD_NAME="${POSTGRES_RELEASE}-0"

  if kubectl get pod "${POD_NAME}" \
      -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then

    STATUS=$(kubectl get pod "${POD_NAME}" \
      -n "${NS_BACKSTAGE}" \
      -o jsonpath='{.status.phase}')

    if [[ "${STATUS}" == "Running" ]]; then
      SetComment "PostgreSQL is running."
    else
      SetError "PostgreSQL status: ${STATUS}"
      ((ERRORS++))
    fi

  else

    SetError "PostgreSQL pod not found."
    ((ERRORS++))
  fi
}

function check_postgresql_connection() {

  SetHeading "Verify PostgreSQL Connection"

  load_postgres_credentials

  RESULT=$(kubectl exec \
    -n "${NS_BACKSTAGE}" \
    "${POSTGRES_RELEASE}-0" -- \
    env PGPASSWORD="${POSTGRES_PASSWORD}" \
    psql \
      -U "${POSTGRES_USER}" \
      -d "${POSTGRES_DB}" \
      -tAc "select 1;" \
      2>/dev/null)

  RESULT=$(echo "${RESULT}" | tr -d '[:space:]')

  if [[ "${RESULT}" == "1" ]]; then

    SetComment "PostgreSQL connection successful."

  else

    SetError "PostgreSQL connection failed."
    ((ERRORS++))

  fi
}

function check_backstage() {

  SetHeading "Verify Backstage"

  if kubectl get deployment "${BACKSTAGE_RELEASE}" \
      -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then

    READY=$(kubectl get deployment "${BACKSTAGE_RELEASE}" \
      -n "${NS_BACKSTAGE}" \
      -o jsonpath='{.status.readyReplicas}')

    if [[ "${READY:-0}" -ge 1 ]]; then
      SetComment "Backstage deployment is ready."
    else
      SetError "Backstage deployment is not ready."
      ((ERRORS++))
    fi

  else

    SetError "Backstage deployment not found."
    ((ERRORS++))

  fi
}

function check_backstage_service() {

  SetHeading "Verify Backstage Service"

  ENDPOINTS=$(kubectl get endpoints "${BACKSTAGE_RELEASE}" \
    -n "${NS_BACKSTAGE}" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' \
    2>/dev/null)

  if [[ -n "${ENDPOINTS}" ]]; then
    SetComment "Backstage service has active endpoint(s)."
  else
    SetError "Backstage service has no active endpoints."
    ((ERRORS++))
  fi
}

function check_backstage_url() {

  SetHeading "Verify Backstage URL"

  if curl -ksf "https://${BACKSTAGE_HOST}" >/dev/null 2>&1; then
    SetComment "Backstage URL is reachable."
  else
    SetWarning "Backstage URL is not reachable."
  fi
}

function check_secrets() {

  SetHeading "Verify Secrets"

  for SECRET in \
    ${POSTGRES_SECRET} \
    ${GITHUB_SECRET} \
    ${GITHUB_AUTH_SECRET}
  do

    if kubectl get secret "${SECRET}" \
        -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then

      SetComment "${SECRET} exists."

    else

      SetError "${SECRET} missing."
      ((ERRORS++))

    fi

  done
}

function check_catalog() {

  SetHeading "Verify Catalog"

  load_postgres_credentials

  local CATALOG_DB="${POSTGRES_DB}_plugin_catalog"

  COUNT=$(kubectl exec \
    -n "${NS_BACKSTAGE}" \
    "${POSTGRES_RELEASE}-0" -- \
    env PGPASSWORD="${POSTGRES_PASSWORD}" \
    psql \
      -U "${POSTGRES_USER}" \
      -d "${CATALOG_DB}" \
      -tAc "select count(*) from final_entities;" \
      2>/dev/null)

  COUNT=$(echo "${COUNT}" | tr -d '[:space:]')

  if [[ "${COUNT}" =~ ^[0-9]+$ ]] && [[ "${COUNT}" -gt 0 ]]; then

    SetComment "Catalog contains ${COUNT} entities."

    USERS=$(kubectl exec -n "${NS_BACKSTAGE}" "${POSTGRES_RELEASE}-0" -- \
      env PGPASSWORD="${POSTGRES_PASSWORD}" \
      psql -U "${POSTGRES_USER}" \
      -d "${CATALOG_DB}" \
      -tAc "select count(*) from final_entities where entity_ref like 'user:%';" \
      2>/dev/null | tr -d '[:space:]')

    GROUPS=$(kubectl exec -n "${NS_BACKSTAGE}" "${POSTGRES_RELEASE}-0" -- \
      env PGPASSWORD="${POSTGRES_PASSWORD}" \
      psql -U "${POSTGRES_USER}" \
      -d "${CATALOG_DB}" \
      -tAc "select count(*) from final_entities where entity_ref like 'group:%';" \
      2>/dev/null | tr -d '[:space:]')

    COMPONENTS=$(kubectl exec -n "${NS_BACKSTAGE}" "${POSTGRES_RELEASE}-0" -- \
      env PGPASSWORD="${POSTGRES_PASSWORD}" \
      psql -U "${POSTGRES_USER}" \
      -d "${CATALOG_DB}" \
      -tAc "select count(*) from final_entities where entity_ref like 'component:%';" \
      2>/dev/null | tr -d '[:space:]')

    TEMPLATES=$(kubectl exec -n "${NS_BACKSTAGE}" "${POSTGRES_RELEASE}-0" -- \
      env PGPASSWORD="${POSTGRES_PASSWORD}" \
      psql -U "${POSTGRES_USER}" \
      -d "${CATALOG_DB}" \
      -tAc "select count(*) from final_entities where entity_ref like 'template:%';" \
      2>/dev/null | tr -d '[:space:]')

    SetComment "Users      : ${USERS}"
    SetComment "Groups     : ${GROUPS}"
    SetComment "Components : ${COMPONENTS}"
    SetComment "Templates  : ${TEMPLATES}"

  else

    SetError "Catalog query failed."
    ((ERRORS++))

  fi
}

function check_argocd() {

  SetHeading "Verify ArgoCD"

  if kubectl get namespace "${NS_ARGOCD}" >/dev/null 2>&1; then

    POD_COUNT=$(kubectl get pods \
      -n "${NS_ARGOCD}" \
      --no-headers 2>/dev/null | wc -l | xargs)

    SetComment "ArgoCD installed (${POD_COUNT} pods)."

  else

    SetWarning "ArgoCD namespace not found."

  fi
}

function check_ingress() {

  SetHeading "Verify Ingress"

  if kubectl get ingress \
      -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then

    SetComment "Ingress found."

  else

    SetWarning "No ingress found."

  fi
}

function show_versions() {

  SetHeading "Platform Versions"

  echo ""

  SetInfo "Backstage Chart"
  echo "${BACKSTAGE_CHART_VERSION}"

  echo ""

  SetInfo "Backstage Image"
  echo "${BACKSTAGE_IMAGE_VERSION}"

  echo ""

  SetInfo "PostgreSQL Chart"
  echo "${POSTGRESQL_CHART_VERSION}"
}

function show_summary() {

  SetHeading "Verification Summary"

  echo ""

  if [[ "${ERRORS}" -eq 0 ]]; then

    echo "✅ Kubernetes"
    echo "✅ PostgreSQL"
    echo "✅ PostgreSQL Connection"
    echo "✅ Backstage"
    echo "✅ Backstage Service"
    echo "✅ Secrets"
    echo "✅ Catalog"
    echo "✅ ArgoCD"
    echo "✅ Ingress"

    echo ""

    SetComment "Platform verification successful."

  else

    echo "❌ Verification failed"

    SetError "${ERRORS} issue(s) detected."

    exit 1

  fi
}

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------

clear

SetTopHeading "Verify Platform"

check_cluster

check_postgresql
check_postgresql_connection

check_backstage
check_backstage_service
check_backstage_url

check_secrets

check_catalog

check_argocd
check_ingress

show_versions

show_summary
