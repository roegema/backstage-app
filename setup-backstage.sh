#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 16-10-2026
# Version: 3.4
# Description: Install or upgrade Backstage using external
#              PostgreSQL including Ingress configuration
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

BACKSTAGE_HOST="backstage.test.com"

VALUES_FILE="${SCRIPT_DIR}/charts/backstage/values-backstage.yaml"

INGRESS_FILE="/tmp/backstage-ingress.yaml"

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

function create_ingress() {

  SetHeading "Create / Update Ingress"

  cat > "${INGRESS_FILE}" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage
  namespace: ${NS_BACKSTAGE}
spec:
  ingressClassName: nginx

  rules:
    - host: ${BACKSTAGE_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backstage
                port:
                  number: 7007
EOF

  kubectl apply -f "${INGRESS_FILE}"

  SetComment "Ingress configured for ${BACKSTAGE_HOST}"
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

  echo ""
  SetInfo "Ingress"
  kubectl get ingress -n "${NS_BACKSTAGE}"
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
  SetInfo "Backstage URL"
  echo "https://${BACKSTAGE_HOST}"

  echo ""
  SetInfo "Hosts File"

  echo "Add the following entry to /etc/hosts:"
  echo ""
  echo "127.0.0.1 ${BACKSTAGE_HOST}"

  echo ""
  SetInfo "GitHub OAuth Callback"
  echo "https://${BACKSTAGE_HOST}/api/auth/github/handler/frame"

  echo ""
  SetInfo "Helm Releases"
  helm list -n "${NS_BACKSTAGE}"
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

create_ingress

verify_deployment

show_backstage_info

SetComment "Backstage installation completed successfully."
