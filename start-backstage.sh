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
BACKSTAGE_APP=backstage

# Colors
readonly COLOR_NC="\e[0m"
readonly COLOR_RED="\e[1;31m"
readonly COLOR_GREEN="\e[0;32m"
readonly COLOR_YELLOW="\e[1;33m"
readonly COLOR_BLUE="\e[1;34m"
readonly COLOR_MAGENTA="\e[1;35m"
readonly COLOR_CYAN="\e[1;36m"

source ${SECRETS_FILE}

cd ${SCRIPT_DIR}/${BACKSTAGE_APP}
yarn start

