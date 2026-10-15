#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 15-10-2026
# Version: 1.0
# Description: Install PostgreSQL for Backstage
##################################################################

set -euo pipefail

#-----------------------------------------------------------------
# GLOBAL VARIABLES
#-----------------------------------------------------------------

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SHARED_FILE="${PARENT_DIR}/shared.sh"

source "${SHARED_FILE}"

NS_BACKSTAGE="backstage"
POSTGRES_RELEASE="backstage-postgresql"

VALUES_FILE="${SCRIPT_DIR}/charts/postgresql/values-postgresql.yaml"

#-----------------------------------------------------------------
# FUNCTIONS
#-----------------------------------------------------------------

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

function install_postgresql() {

  SetHeading "Install PostgreSQL"

  helm upgrade --install "${POSTGRES_RELEASE}" \
    bitnami/postgresql \
    --namespace "${NS_BACKSTAGE}" \
    --wait \
    --timeout 15m \
    -f "${VALUES_FILE}"

  SetComment "PostgreSQL deployment completed."
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
  SetInfo "Persistent Volume Claims"
  kubectl get pvc -n "${NS_BACKSTAGE}"

  echo ""

  SetComment "Deployment verification completed."
}

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------

clear

SetTopHeading "Setup PostgreSQL"

create_namespace
add_helm_repo
install_postgresql
verify_deployment

SetComment "PostgreSQL installation completed successfully."
