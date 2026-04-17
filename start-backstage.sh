#!/usr/bin/env bash
##################################################################
# Author: Rene Oegema
# Date: 10-03-2026
# Version: 0.1
# Description: Script to start local backstage
# Used by course on https://www.udemy.com/course/from-devops-to-platform-engineering-master-backstage-idps/
##################################################################

#-----------------------------------------------------------------
# GLOBAL VARIABLES
#-----------------------------------------------------------------
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR="$(cd ${SCRIPT_DIR} && cd ../ && pwd)"
SHARED_FILE="${PARENT_DIR}/shared.sh"
SECRETS_FILE="${PARENT_DIR}/secrets.sh"
source ${SHARED_FILE}
source ${SECRETS_FILE}
DEBUG_ON="yes"
BACKSTAGE_APP="backstage"
BACKSTAGE_APP_DIR="${SCRIPT_DIR}/${BACKSTAGE_APP}"

#-----------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------
cd ${BACKSTAGE_APP_DIR}
SetTopHeading "Start Backstage environment"
# Ensure the pg driver is installed (run once if needed)
# yarn workspace backend add pg
SetHeading "PostgreSQL"
SetInfo "Ensuring PostgreSQL container is running"
# Start the database container in detached mode
docker compose up -d
# Wait for the database to be ready to accept connections
SetComment "Waiting for Postgres to be ready"
until docker exec backstage-db pg_isready -U postgres; do
  SetComment2 "Postgres is unavailable - sleeping"
  sleep 2
done
SetInfo "Database is up! Starting Backstage app"

# Start Backstage with the specified configurations
SetHeading "Backstage backend/app"
yarn start \
  --config ${BACKSTAGE_APP_DIR}/app-config.yaml \
  --config ${BACKSTAGE_APP_DIR}/app-config.local.yaml

# # DEBUG config
# echo ${GITHUB_TOKEN}
# echo ${AUTH_GITHUB_CLIENT_ID}
# echo ${AUTH_GITHUB_CLIENT_SECRET}
# yarn backstage-cli config:print \
#   --config ./app-config.yaml \
#   --config ./app-config.local.yaml
