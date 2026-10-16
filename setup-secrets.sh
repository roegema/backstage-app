#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 15-10-2026
# Version: 1.0
# Description: Create Kubernetes secrets for Backstage
##################################################################

set -euo pipefail

#-----------------------------------------------------------------
# GLOBAL VARIABLES
#-----------------------------------------------------------------

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SHARED_FILE="${PARENT_DIR}/shared.sh"
SECRETS_FILE="${PARENT_DIR}/secrets.sh"

source "${SHARED_FILE}"
source "${SECRETS_FILE}"

NS_BACKSTAGE="backstage"

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

function create_postgres_secret() {

  SetHeading "Create PostgreSQL secret"

  kubectl create secret generic backstage-db \
    --namespace "${NS_BACKSTAGE}" \
    --from-literal=host="${POSTGRES_HOST}" \
    --from-literal=user="${POSTGRES_USER}" \
    --from-literal=password="${POSTGRES_PASSWORD}" \
    --from-literal=database="${POSTGRES_DB}" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

  SetComment "PostgreSQL secret created/updated."
}

function create_github_secret() {

  SetHeading "Create GitHub token secret"

  kubectl create secret generic backstage-github \
    --namespace "${NS_BACKSTAGE}" \
    --from-literal=token="${GITHUB_TOKEN}" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

  SetComment "GitHub token secret created/updated."
}

function create_github_auth_secret() {

  SetHeading "Create GitHub OAuth secret"

  kubectl create secret generic backstage-github-auth \
    --namespace "${NS_BACKSTAGE}" \
    --from-literal=client-id="${AUTH_GITHUB_CLIENT_ID}" \
    --from-literal=client-secret="${AUTH_GITHUB_CLIENT_SECRET}" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

  SetComment "GitHub OAuth secret created/updated."
}

function verify() {

  SetHeading "Verify secrets"

  kubectl get secrets -n "${NS_BACKSTAGE}"
}

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------

clear

SetTopHeading "Setup Secrets"

create_namespace

create_postgres_secret

create_github_secret

create_github_auth_secret

verify

SetComment "Secrets setup completed successfully."
