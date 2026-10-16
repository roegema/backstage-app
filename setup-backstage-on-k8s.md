# Backstage on Kubernetes (Kind)

This document describes the complete setup of a working Backstage environment running on a local Kind cluster.

The environment consists of:

- Backstage deployed via Helm
- PostgreSQL deployed as a separate Helm release
- Kubernetes Secrets managed separately
- GitHub integration support
- Guest authentication
- TechDocs support
- Persistent PostgreSQL storage

---

# Architecture

```text
Kind Cluster (backstage)

Namespace: backstage
├── Helm Release: backstage
│   ├── Backstage Frontend
│   └── Backstage Backend
│
├── Helm Release: backstage-postgresql
│   └── PostgreSQL
│
└── Kubernetes Secrets
    ├── backstage-db
    ├── backstage-github
    └── backstage-github-auth

Namespace: ingress-nginx
└── NGINX Ingress Controller

Namespace: argocd
└── ArgoCD

Namespace: python
└── Python Applications
```

---

# Prerequisites

The following tools must be installed:

```bash
kubectl
helm
kind
docker
```

Verify installation:

```bash
kubectl version --client
helm version
kind version
docker --version
```

---

# Directory Structure

```text
backstage-app/
├── config.sh
├── secrets.sh
├── setup-secrets.sh
├── setup-postgresql.sh
├── setup-backstage.sh
├── shared.sh
│
├── charts/
│   ├── backstage/
│   │   └── values-backstage.yaml
│   │
│   └── postgresql/
│       └── values-postgresql.yaml
│
└── docs/
    └── setup-backstage-on-k8s.md
```

---

# Step 1 - Configure Versions

Create the central configuration file.

## config.sh

```bash
#!/usr/bin/env bash

##################################################################
# Global Configuration
##################################################################

BACKSTAGE_CHART_VERSION="2.10.2"
BACKSTAGE_IMAGE_VERSION="1.42.0"

POSTGRESQL_CHART_VERSION="16.7.27"
```

All installation scripts will use these versions.

---

# Step 2 - Configure Secrets

Create the secrets configuration file.

## secrets.sh

```bash
#!/usr/bin/env bash

##################################################################
# PostgreSQL
##################################################################

POSTGRES_USER="backstage"
POSTGRES_PASSWORD="backstage"
POSTGRES_DATABASE="backstage"

##################################################################
# GitHub Personal Access Token
##################################################################

GITHUB_TOKEN="<your-token>"

##################################################################
# GitHub OAuth Application
##################################################################

AUTH_GITHUB_CLIENT_ID="<client-id>"
AUTH_GITHUB_CLIENT_SECRET="<client-secret>"
```

Do not commit this file to Git.

Add it to `.gitignore`.

```gitignore
secrets.sh
```

---

# Step 3 - Create Kubernetes Secrets

Create all required Kubernetes secrets.

```bash
./setup-secrets.sh
```

Verify:

```bash
kubectl get secrets -n backstage
```

Expected:

```text
backstage-db
backstage-github
backstage-github-auth
```

---

# Step 4 - Install PostgreSQL

Install PostgreSQL as a standalone Helm release.

```bash
./setup-postgresql.sh
```

Verify:

```bash
kubectl get pods -n backstage
```

Expected:

```text
backstage-postgresql-0   Running
```

Check the service:

```bash
kubectl get svc -n backstage
```

Expected:

```text
backstage-postgresql
```

---

# PostgreSQL Configuration

## charts/postgresql/values-postgresql.yaml

```yaml
auth:
  postgresPassword: postgres
  username: backstage
  password: backstage
  database: backstage

primary:
  persistence:
    enabled: true
    size: 5Gi
```

---

# Step 5 - Configure Backstage

## charts/backstage/values-backstage.yaml

```yaml
postgresql:
  enabled: false

backstage:

  extraEnvVars:

    - name: GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: backstage-github
          key: token

    - name: AUTH_GITHUB_CLIENT_ID
      valueFrom:
        secretKeyRef:
          name: backstage-github-auth
          key: client-id

    - name: AUTH_GITHUB_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: backstage-github-auth
          key: client-secret

    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: backstage-db
          key: password

  image:
    registry: ghcr.io
    repository: backstage/backstage
    tag: "1.42.0"

  appConfig:

    app:
      title: Backstage
      baseUrl: http://localhost:7007

    organization:
      name: Local Development

    backend:
      baseUrl: http://localhost:7007

      database:
        client: pg
        connection:
          host: backstage-postgresql
          port: 5432
          user: backstage
          password: ${POSTGRES_PASSWORD}
          database: backstage

    auth:
      providers:
        guest:
          dangerouslyAllowOutsideDevelopment: true

    techdocs:
      builder: local
      generator:
        runIn: local
      publisher:
        type: local

    catalog:
      rules:
        - allow:
            - Component
            - API
            - Resource
            - System
            - Location

    integrations:
      github:
        - host: github.com
          token: ${GITHUB_TOKEN}
```

---

# Step 6 - Install Backstage

Run:

```bash
./setup-backstage.sh
```

The script performs:

- Namespace validation
- Helm repository validation
- PostgreSQL service validation
- PostgreSQL secret validation
- GitHub secret validation
- Backstage installation or upgrade

Verify:

```bash
kubectl get pods -n backstage
```

Expected:

```text
backstage-xxxxx            Running
backstage-postgresql-0     Running
```

---

# Step 7 - Verify Backstage

View logs:

```bash
kubectl logs deployment/backstage -n backstage
```

Expected output:

```text
Plugin initialization complete
```

This indicates a successful startup.

---

# Step 8 - Access Backstage

Create a port forward:

```bash
kubectl port-forward svc/backstage -n backstage 7007:7007
```

Open:

```text
http://localhost:7007
```

---

# Step 9 - Validate Authentication

Run:

```bash
curl -i http://localhost:7007/api/auth/guest/refresh
```

Expected response:

```text
HTTP/1.1 200 OK
```

The response should contain a valid authentication token.

---

# Upgrade Procedure

Backstage can be upgraded safely without affecting PostgreSQL.

Run:

```bash
./setup-backstage.sh
```

The script executes:

```bash
helm upgrade --install
```

This preserves:

- Catalog entities
- Templates
- Plugin data
- User settings
- Notifications
- Scaffolder data

---

# Database Persistence

The PostgreSQL deployment and PVCs must not be removed during Backstage upgrades.

Safe:

```bash
helm upgrade --install backstage ...
```

Safe:

```bash
helm uninstall backstage -n backstage
```

Not safe:

```bash
helm uninstall backstage-postgresql -n backstage
```

Not safe:

```bash
kubectl delete pvc --all -n backstage
```

Removing PVCs will permanently delete all stored Backstage data.

---

# Current Environment Status

The following components are operational:

- ✅ Kind
- ✅ Helm
- ✅ PostgreSQL
- ✅ Backstage 1.42.0
- ✅ Guest Authentication
- ✅ TechDocs
- ✅ Catalog
- ✅ Scaffolder
- ✅ Search
- ✅ Notifications
- ✅ GitHub Integration
- ✅ Persistent Database Storage

---

# Recommended Next Steps

1. Configure GitHub Authentication
2. Create a dedicated Backstage Catalog repository
3. Register software templates
4. Enable the Kubernetes plugin
5. Integrate ArgoCD
6. Publish TechDocs from GitHub repositories
7. Register applications as catalog components

This setup provides a solid foundation for building an Internal Developer Platform (IDP) with Backstage.
