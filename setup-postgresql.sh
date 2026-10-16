#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 15-10-2026
# Version: 2.0
# Description: Install or upgrade PostgreSQL for Backstage
##################################################################

set -euo pipefail

#-----------------------------------------------------------------
# GLOBAL VARIABLES
#-----------------------------------------------------------------

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SHARED_FILE="${PARENT_DIR}/shared.sh"
CONFIG_FILE="${PARENT_DIR}/config.sh"

source "${SHARED_FILE}"
source "${CONFIG_FILE}"

NS_BACKSTAGE="backstage"

POSTGRES_RELEASE="backstage-postgresql"

VALUES_FILE="${SCRIPT_DIR}/charts/postgresql/values-postgresql.yaml"

#-----------------------------------------------------------------
# FUNCTIONS
#-----------------------------------------------------------------

function validate_prerequisites() {

  SetHeading "Validate prerequisites"

  command -v kubectl >/dev/null 2>&1 \
    || { SetError "kubectl not found"; exit 1; }

  command -v helm >/dev/null 2>&1 \
    || { SetError "helm not found"; exit 1; }

  SetComment "All prerequisites found."
}

function validate_configuration() {

  SetHeading "Validate configuration"

  [[ -f "${CONFIG_FILE}" ]] \
    || { SetError "Configuration file not found: ${CONFIG_FILE}"; exit 1; }

  [[ -f "${VALUES_FILE}" ]] \
    || { SetError "Values file not found: ${VALUES_FILE}"; exit 1; }

  SetComment "Configuration validated."
}

function create_namespace() {

  SetHeading "Create namespace"

  if kubectl get namespace "${NS_BACKSTAGE}" >/dev/null 2>&1; then
    SetComment "Namespace '${NS_BACKSTAGE}' already exists."
  else
    kubectl create namespace "${NS_BACKSTAGE}"
    SetComment "Namespace '${NS_BACKSTAGE}' created."
  fi
}

function add_helm_repo() {

  SetHeading "Configure Helm repository"

  helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
  helm repo update >/dev/null

  SetComment "Bitnami Helm repository configured."
}

function verify_postgres_secret() {

  SetHeading "Verify PostgreSQL secret"

  kubectl get secret backstage-db \
    -n "${NS_BACKSTAGE}" >/dev/null 2>&1 \
    || {
      SetError "Secret 'backstage-db' not found."
      SetError "Run setup-secrets.sh first."
      exit 1
    }

  SetComment "PostgreSQL secret found."
}

function install_postgresql() {

  SetHeading "Install / Upgrade PostgreSQL"

  SetInfo "Chart Version"
  echo "${POSTGRESQL_CHART_VERSION}"

  helm upgrade --install "${POSTGRES_RELEASE}" \
  --version ${POSTGRESQL_CHART_VERSION} \
    bitnami/postgresql \
    --namespace "${NS_BACKSTAGE}" \
    --wait \
    --timeout 15m \
    -f "${VALUES_FILE}"

  SetComment "PostgreSQL deployment completed."
}

function wait_for_postgresql() {

  SetHeading "Wait for PostgreSQL"

  kubectl rollout status statefulset/${POSTGRES_RELEASE} \
    -n "${NS_BACKSTAGE}" \
    --timeout=600s

  SetComment "PostgreSQL is ready."
}

function verify_deployment() {

  SetHeading "Verify deployment"

  echo ""
  SetInfo "Pods"
  kubectl get pods -n "${NS_BACKSTAGE}"

  echo ""
  SetInfo "Services"
  kubectl get svc -n "${NS_BACKSTAGE}"

  echo ""
  SetInfo "StatefulSets"
  kubectl get statefulsets -n "${NS_BACKSTAGE}"

  echo ""
  SetInfo "Persistent Volume Claims"
  kubectl get pvc -n "${NS_BACKSTAGE}"
}

function show_postgresql_info() {

  SetHeading "PostgreSQL information"

  echo ""
  SetInfo "Chart Version"
  echo "${POSTGRESQL_CHART_VERSION}"

  echo ""
  SetInfo "Service"
  echo "backstage-postgresql"

  echo ""
  SetInfo "Port"
  echo "5432"

  echo ""
  SetInfo "Connection Host (inside Kubernetes)"
  echo "backstage-postgresql"

  echo ""
  SetInfo "Port Forward Command (for Docker Backstage)"

  echo "kubectl port-forward \\"
  echo "  svc/backstage-postgresql \\"
  echo "  5432:5432 \\"
  echo "  -n ${NS_BACKSTAGE}"

  echo ""
  SetInfo "Docker Configuration"

  echo "export POSTGRES_HOST=\"host.docker.internal\""
  echo "export POSTGRES_PORT=\"5432\""

  echo ""
  SetInfo "Kubernetes Configuration"

  echo "POSTGRES_HOST=backstage-postgresql"
  echo "POSTGRES_PORT=5432"

  echo ""
  SetInfo "Helm Releases"
  helm list -n "${NS_BACKSTAGE}"
}

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------

clear

SetTopHeading "Setup PostgreSQL"

cd "${SCRIPT_DIR}"

validate_prerequisites
validate_configuration

create_namespace

add_helm_repo

verify_postgres_secret

install_postgresql

wait_for_postgresql

verify_deployment

show_postgresql_info

SetComment "PostgreSQL installation completed successfully."
