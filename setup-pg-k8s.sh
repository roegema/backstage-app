#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 09-10-2026
# Version: 0.2
# Description: Install PostgreSQL on Kind using Helm
##################################################################

set -euo pipefail

#-----------------------------------------------------------------
# GLOBAL VARIABLES
#-----------------------------------------------------------------

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )
PARENT_DIR="$(cd ${SCRIPT_DIR} && cd ../ && pwd)"

SHARED_FILE="${PARENT_DIR}/shared.sh"
SECRETS_FILE="${PARENT_DIR}/secrets.sh"

source "${SHARED_FILE}"
source "${SECRETS_FILE}"

NS_POSTGRES="postgres"

POSTGRES_RELEASE="postgres"

#-----------------------------------------------------------------
# FUNCTIONS
#-----------------------------------------------------------------

function validate_prerequisites() {

  SetHeading "Validate prerequisites"

  command -v kubectl >/dev/null 2>&1 \
    || { SetError "kubectl not found"; exit 1; }

  command -v helm >/dev/null 2>&1 \
    || { SetError "helm not found"; exit 1; }

  command -v kind >/dev/null 2>&1 \
    || { SetError "kind not found"; exit 1; }

  SetComment "All prerequisites found."
}

function validate_secrets() {

  SetHeading "Validate secrets"

  if [[ -z "${POSTGRES_USERNAME:-}" ]]; then
    SetError "POSTGRES_USERNAME not defined in secrets.sh"
    exit 1
  fi

  if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
    SetError "POSTGRES_PASSWORD not defined in secrets.sh"
    exit 1
  fi

  if [[ -z "${POSTGRES_DATABASE:-}" ]]; then
    SetError "POSTGRES_DATABASE not defined in secrets.sh"
    exit 1
  fi

  SetComment "All PostgreSQL variables found."
}

function create_namespace() {

  SetHeading "Create namespace"

  if kubectl get namespace ${NS_POSTGRES} >/dev/null 2>&1; then
    SetComment "Namespace '${NS_POSTGRES}' already exists."
  else
    kubectl create namespace ${NS_POSTGRES}
    SetComment "Namespace '${NS_POSTGRES}' created."
  fi
}

function add_helm_repo() {

  SetHeading "Configure Helm repository"

  helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
  helm repo update >/dev/null

  SetComment "Bitnami repository configured."
}

function create_values_file() {

  SetHeading "Create values file"

  mkdir -p "${SCRIPT_DIR}/charts/postgresql"

  cat > "${SCRIPT_DIR}/charts/postgresql/values-postgresql.yaml" <<EOF
auth:
  username: ${POSTGRES_USERNAME}
  password: ${POSTGRES_PASSWORD}
  database: ${POSTGRES_DATABASE}

primary:
  persistence:
    enabled: false
EOF

  SetComment "Values file created."
  SetComment "${SCRIPT_DIR}/charts/postgresql/values-postgresql.yaml"
}

function install_postgresql() {

  SetHeading "Install PostgreSQL"

  if helm status ${POSTGRES_RELEASE} -n ${NS_POSTGRES} >/dev/null 2>&1; then
    SetComment "Release already exists."
    SetComment "Executing Helm upgrade."
  else
    SetComment "Installing new release."
  fi

  helm upgrade --install ${POSTGRES_RELEASE} \
    bitnami/postgresql \
    --namespace ${NS_POSTGRES} \
    --wait \
    --timeout 10m \
    -f "${SCRIPT_DIR}/charts/postgresql/values-postgresql.yaml"

  SetComment "Helm deployment completed."
}

function wait_for_postgresql() {

  SetHeading "Wait for PostgreSQL"

  kubectl wait \
    --namespace ${NS_POSTGRES} \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/instance=${POSTGRES_RELEASE} \
    --timeout=300s

  SetComment "PostgreSQL pod is ready."
}

function verify_postgresql() {

  SetHeading "Verify deployment"

  kubectl get pods -n ${NS_POSTGRES}
  kubectl get svc  -n ${NS_POSTGRES}

  SetComment "Deployment verification completed."
}

function show_postgresql_info() {

  SetHeading "PostgreSQL information"

  kubectl get all -n ${NS_POSTGRES}

  echo ""

  SetInfo "Connection settings"

  SetComment "Namespace : ${NS_POSTGRES}"
  SetComment "Release   : ${POSTGRES_RELEASE}"
  SetComment "Database  : ${POSTGRES_DATABASE}"
  SetComment "Username  : ${POSTGRES_USERNAME}"
  SetComment "Service   : postgres-postgresql"

  echo ""

  SetInfo "Port forward command"

  echo "kubectl port-forward svc/postgres-postgresql -n ${NS_POSTGRES} 5432:5432"

  echo ""

  SetInfo "psql example"

  echo "PGPASSWORD=${POSTGRES_PASSWORD} psql -h localhost -p 5432 -U ${POSTGRES_USERNAME} -d ${POSTGRES_DATABASE}"
}

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------

clear

SetTopHeading "Setup PostgreSQL"

cd "${SCRIPT_DIR}"

validate_prerequisites

validate_secrets

create_namespace

add_helm_repo

create_values_file

install_postgresql

wait_for_postgresql

verify_postgresql

show_postgresql_info

SetComment "PostgreSQL installation completed successfully."
