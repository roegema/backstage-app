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
SECRETS_FILE="${PARENT_DIR}/python-app/__secrets/custom_info.sh"
DEBUG_ON="yes"
BACKSTAGE_APP="backstage"
export BACKSTAGE_APP_DIR="${SCRIPT_DIR}/${BACKSTAGE_APP}"
# Colors
readonly COLOR_NC="\e[0m"
readonly COLOR_RED="\e[1;31m"
readonly COLOR_GREEN="\e[0;32m"
readonly COLOR_YELLOW="\e[1;33m"
readonly COLOR_BLUE="\e[1;34m"
readonly COLOR_MAGENTA="\e[1;35m"
readonly COLOR_CYAN="\e[1;36m"

source ${SECRETS_FILE}
cd ${BACKSTAGE_APP_DIR}

# Ensure the pg driver is installed (run once if needed)
# yarn workspace backend add pg

echo -e "${COLOR_CYAN}Ensuring PostgreSQL container is running...${COLOR_NC}"
# Start the database container in detached mode
docker compose up -d

# Wait for the database to be ready to accept connections
echo -e "${COLOR_YELLOW}Waiting for Postgres to be ready...${COLOR_NC}"
until docker exec backstage-db pg_isready -U postgres; do
  echo "Postgres is unavailable - sleeping"
  sleep 2
done

echo -e "${COLOR_GREEN}Database is up! Starting Backstage app...${COLOR_NC}"

# Start Backstage with the specified configurations
yarn start \
  --config ${SCRIPT_DIR}/${BACKSTAGE_APP}/app-config.yaml \
  --config ${SCRIPT_DIR}/${BACKSTAGE_APP}/app-config.local.yaml

# # DEBUG config
# echo ${GITHUB_TOKEN}
# echo ${AUTH_GITHUB_CLIENT_ID}
# echo ${AUTH_GITHUB_CLIENT_SECRET}
# yarn backstage-cli config:print \
#   --config ./app-config.yaml \
#   --config ./app-config.local.yaml
