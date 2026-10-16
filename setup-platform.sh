#!/usr/bin/env bash

set -e

./setup-secrets.sh
./setup-postgresql.sh
./setup-backstage.sh
