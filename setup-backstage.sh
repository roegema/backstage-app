#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 15-10-2026
# Version: 2.0
# Description: Install Backstage using external PostgreSQL
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

function validate_files() {

  SetHeading "Validate files"

  if [[ ! -f "${VALUES_FILE}" ]]; then
    SetError "Values file not found:"
    SetError "${VALUES_FILE}"
    exit 1
  fi

  SetComment "Values file found."
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

function uninstall_backstage() {

  SetHeading "Remove existing Backstage release"

  if helm status "${BACKSTAGE_RELEASE}" \
      -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then

    helm uninstall "${BACKSTAGE_RELEASE}" \
      -n "${NS_BACKSTAGE}"

    SetComment "Existing Backstage release removed."
  else
    SetComment "No existing Backstage release found."
  fi
}

function verify_postgresql() {

  SetHeading "Verify PostgreSQL"

  if kubectl get svc backstage-postgresql \
      -n "${NS_BACKSTAGE}" >/dev/null 2>&1; then

    SetComment "PostgreSQL service found."
  else
    SetError "PostgreSQL service 'backstage-postgresql' not found."
    SetError "Run setup-postgresql.sh first."
    exit 1
  fi
}

function install_backstage() {

  SetHeading "Install Backstage"

  helm upgrade --install "${BACKSTAGE_RELEASE}" \
    backstage/backstage \
    --version 2.10.2 \
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

  echo ""

  SetComment "Deployment verification completed."
}

function show_backstage_info() {

  SetHeading "Backstage information"

  echo ""
  SetInfo "Port Forward"

  echo "kubectl port-forward svc/backstage -n backstage 7007:7007"

  echo ""
  SetInfo "Open Backstage"

  echo "http://localhost:7007"

  echo ""
  SetInfo "Authentication test"

  echo "curl -i http://localhost:7007/api/auth/guest/refresh"
}

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------

clear

SetTopHeading "Setup Backstage"

cd "${SCRIPT_DIR}"

validate_prerequisites
validate_files

create_namespace

add_helm_repo

verify_postgresql

uninstall_backstage

install_backstage

wait_for_backstage

verify_deployment

show_backstage_info

SetComment "Backstage installation completed successfully."

####
exit 0
####


echo "=== Uninstall Helm release ==="
helm uninstall backstage -n backstage || true

echo "=== Delete PVCs ==="
kubectl delete pvc --all -n backstage --ignore-not-found=true

echo "=== Delete Secrets ==="
kubectl delete secret --all -n backstage --ignore-not-found=true

echo "=== Delete ConfigMaps ==="
kubectl delete configmap --all -n backstage --ignore-not-found=true

echo "=== Delete Namespace ==="
kubectl delete namespace backstage --ignore-not-found=true

echo "=== Wait for namespace removal ==="
while kubectl get namespace backstage >/dev/null 2>&1; do
  echo "Waiting for namespace backstage to disappear..."
  sleep 2
done

echo "=== Recreate Namespace ==="
kubectl create namespace backstage

echo "=== Cleanup complete ==="

kubectl get ns backstage
kubectl get all -n backstage
kubectl get pvc -n backstage
kubectl get secret -n backstage
