#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 15-10-2026
# Version: 3.3
# Description: Install or upgrade Backstage using external
#              PostgreSQL
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

BACKSTAGE_RELEASE="backstage"

VALUES_FILE="${SCRIPT_DIR}/charts/backstage/values-backstage.yaml"

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

  helm repo add backstage https://backstage.github.io/charts >/dev/null 2>&1 || true
  helm repo update >/dev/null

  SetComment "Backstage Helm repository configured."
}

function verify_postgresql() {

  SetHeading "Verify PostgreSQL service"

  kubectl get svc backstage-postgresql \
    -n "${NS_BACKSTAGE}" >/dev/null 2>&1 \
    || {
      SetError "Service 'backstage-postgresql' not found."
      SetError "Run setup-postgresql.sh first."
      exit 1
    }

  SetComment "PostgreSQL service found."
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

function verify_github_secret() {

  SetHeading "Verify GitHub secret"

  if kubectl get secret backstage-github \
      -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then
    SetComment "GitHub secret found."
  else
    SetWarning "GitHub secret not found."
    SetWarning "GitHub integrations may not function."
  fi
}

function verify_github_auth_secret() {

  SetHeading "Verify GitHub OAuth secret"

  if kubectl get secret backstage-github-auth \
      -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then
    SetComment "GitHub OAuth secret found."
  else
    SetWarning "GitHub OAuth secret not found."
    SetWarning "GitHub authentication may not function."
  fi
}

function install_backstage() {

  SetHeading "Install / Upgrade Backstage"

  SetInfo "Chart Version"
  echo "${BACKSTAGE_CHART_VERSION}"

  helm upgrade --install "${BACKSTAGE_RELEASE}" \
    backstage/backstage \
    --version "${BACKSTAGE_CHART_VERSION}" \
    --namespace "${NS_BACKSTAGE}" \
    --wait \
    --timeout 15m \
    -f "${VALUES_FILE}"

  SetComment "Backstage deployment completed."
}

function wait_for_backstage() {

  SetHeading "Wait for Backstage"

  kubectl rollout status deployment/backstage \
    -n "${NS_BACKSTAGE}" \
    --timeout=600s

  SetComment "Backstage deployment is ready."
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
  SetInfo "Deployments"
  kubectl get deployments -n "${NS_BACKSTAGE}"
}

function show_backstage_info() {

  SetHeading "Backstage information"

  echo ""
  SetInfo "Chart Version"
  echo "${BACKSTAGE_CHART_VERSION}"

  echo ""
  SetInfo "Image Version"
  echo "${BACKSTAGE_IMAGE_VERSION}"

  echo ""
  SetInfo "Port Forward"
  echo "kubectl port-forward svc/backstage -n backstage 7007:7007"

  echo ""
  SetInfo "Open Backstage"
  echo "http://localhost:7007"

  echo ""
  SetInfo "Authentication Test"
  echo "curl -i http://localhost:7007/api/auth/guest/refresh"

  echo ""
  SetInfo "Helm Releases"
  helm list -n "${NS_BACKSTAGE}"
}

function start_port_forward() {

  SetHeading "Start Port Forward"

  if pgrep -f "kubectl port-forward svc/backstage.*7007:7007" >/dev/null; then
    SetComment "Port-forward already running."
  else
    nohup kubectl port-forward \
      svc/backstage \
      -n "${NS_BACKSTAGE}" \
      7007:7007 \
      >/tmp/backstage-port-forward.log 2>&1 &

    SetComment "Port-forward started."
  fi
}

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------

clear

SetTopHeading "Setup Backstage"

cd "${SCRIPT_DIR}"

validate_prerequisites
validate_configuration

create_namespace

add_helm_repo

verify_postgresql
verify_postgres_secret
verify_github_secret
verify_github_auth_secret

install_backstage

wait_for_backstage

verify_deployment

show_backstage_info

# start_port_forward

SetComment "Backstage installation completed successfully."
