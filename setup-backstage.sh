#!/usr/bin/env bash

##################################################################
# Author: Rene Oegema
# Date: 14-10-2026
# Version: 1.0
# Description: Install Backstage with PostgreSQL on Kind
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

  command -v kind >/dev/null 2>&1 \
    || { SetError "kind not found"; exit 1; }

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

  if kubectl get namespace ${NS_BACKSTAGE} >/dev/null 2>&1; then
    SetComment "Namespace '${NS_BACKSTAGE}' already exists."
  else
    kubectl create namespace ${NS_BACKSTAGE}
    SetComment "Namespace '${NS_BACKSTAGE}' created."
  fi
}

function add_helm_repo() {

  SetHeading "Configure Helm repository"

  helm repo add backstage https://backstage.github.io/charts >/dev/null 2>&1 || true
  helm repo update >/dev/null

  SetComment "Backstage Helm repository configured."
}

function install_backstage() {

  SetHeading "Install Backstage"

  if helm status ${BACKSTAGE_RELEASE} -n ${NS_BACKSTAGE} >/dev/null 2>&1; then
    SetComment "Release already exists."
    SetComment "Executing Helm upgrade."
  else
    SetComment "Installing new release."
  fi


  helm upgrade --install ${BACKSTAGE_RELEASE} \
    backstage/backstage \
    --version 2.8.2 \
    --namespace ${NS_BACKSTAGE} \
    --wait \
    --timeout 15m \
    -f "${VALUES_FILE}"

  SetComment "Helm deployment completed."
}

function wait_for_backstage() {

  SetHeading "Wait for Backstage"

  kubectl wait \
    --namespace ${NS_BACKSTAGE} \
    --for=condition=Ready pod \
    --all \
    --timeout=600s

  SetComment "All pods are ready."
}

function verify_deployment() {

  SetHeading "Verify deployment"

  echo ""
  SetInfo "Pods"
  kubectl get pods -n ${NS_BACKSTAGE}

  echo ""
  SetInfo "Services"
  kubectl get svc -n ${NS_BACKSTAGE}

  echo ""
  SetInfo "StatefulSets"
  kubectl get statefulsets -n ${NS_BACKSTAGE}

  echo ""
  SetInfo "Deployments"
  kubectl get deployments -n ${NS_BACKSTAGE}

  echo ""

  SetComment "Deployment verification completed."
}

function show_backstage_info() {

  SetHeading "Backstage information"

  kubectl get all -n ${NS_BACKSTAGE}

  echo ""
  SetInfo "Port Forward"

  echo "kubectl port-forward svc/backstage -n ${NS_BACKSTAGE} 7007:80"

  echo ""
  SetInfo "Open Backstage"

  echo "http://localhost:7007"

  echo ""
  SetInfo "PostgreSQL Service"

  echo "backstage-postgresql:5432"

  echo ""
  SetInfo "PostgreSQL Secret"

  echo "kubectl get secret backstage-postgresql -n ${NS_BACKSTAGE}"
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

install_backstage

wait_for_backstage

verify_deployment

show_backstage_info

SetComment "Backstage installation completed successfully."

###
kubectl get pods -n backstage
kubectl port-forward svc/backstage -n backstage 7007:7007



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
