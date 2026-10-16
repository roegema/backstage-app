# Backstage on Kubernetes (Kind)

This document describes the complete setup of a working Backstage environment running on a local Kind cluster.

The environment consists of:

- Backstage deployed via Helm
- PostgreSQL deployed as a separate Helm release
- Kubernetes Secrets managed separately
- GitHub OAuth authentication
- GitHub integration support
- Catalog Users and Groups
- Software Templates
- TechDocs support
- Persistent PostgreSQL storage

---

# Architecture

```text
Kind Cluster

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
└── Argo CD

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
├── shared.sh
│
├── setup-secrets.sh
├── setup-postgresql.sh
├── setup-backstage.sh
│
├── charts/
│   ├── backstage/
│   │   └── values-backstage.yaml
│   │
│   └── postgresql/
│       └── values-postgresql.yaml
│
├── catalog/
│   └── entities/
│       ├── users.yaml
│       ├── groups.yaml
│       └── component.yaml
│
└── docs/
    └── setup-backstage-on-k8s.md
```

---

# Step 1 - Configure Versions

## config.sh

```bash
#!/usr/bin/env bash

##################################################################
# Global Configuration
##################################################################

BACKSTAGE_CHART_VERSION="2.10.2"

BACKSTAGE_IMAGE_VERSION="1.48.0-github-r01"

POSTGRESQL_CHART_VERSION="16.7.27"
```

---

# Step 2 - Configure Secrets

## secrets.sh

```bash
#!/usr/bin/env bash

##################################################################
# GitHub User
##################################################################

GITHUB_USER=""

##################################################################
# GitHub OAuth Application
##################################################################

AUTH_GITHUB_CLIENT_ID=""
AUTH_GITHUB_CLIENT_SECRET=""

##################################################################
# PostgreSQL
##################################################################

POSTGRES_USER=""
POSTGRES_PASSWORD=""
POSTGRES_DB=""
POSTGRES_PORT="5432"
POSTGRES_HOST=""

##################################################################
# GitHub Tokens
##################################################################

GITHUB_TOKEN=""
GITHUB_TOKEN_RUNNERS=""

##################################################################
# Docker Hub
##################################################################

DOCKERHUB_USERNAME=""
DOCKERHUB_TOKEN=""

##################################################################
# Argo CD
##################################################################

ARGOCD_USER=""
ARGOCD_PASSWORD=""
```

Do not commit this file.

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

# PostgreSQL Secret

The PostgreSQL secret contains:

```text
host
user
password
database
```

Verify:

```bash
kubectl describe secret backstage-db -n backstage
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

Verify the service:

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

# PostgreSQL Port Forward

For local development:

```bash
kubectl port-forward \
  svc/backstage-postgresql \
  -n backstage \
  5432:5432
```

Docker containers can connect using:

```text
host.docker.internal
```

Kubernetes workloads connect using:

```text
backstage-postgresql
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

    - name: POSTGRES_USER
      valueFrom:
        secretKeyRef:
          name: backstage-db
          key: user

    - name: POSTGRES_HOST
      valueFrom:
        secretKeyRef:
          name: backstage-db
          key: host

    - name: POSTGRES_DB
      valueFrom:
        secretKeyRef:
          name: backstage-db
          key: database

  image:
    registry: docker.io
    repository: roegema/backstage
    tag: "1.48.0-github-r01"

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
          host: ${POSTGRES_HOST}
          port: 5432
          user: ${POSTGRES_USER}
          password: ${POSTGRES_PASSWORD}
          database: ${POSTGRES_DB}

    auth:
      environment: development

      providers:

        guest:
          dangerouslyAllowOutsideDevelopment: true

        github:
          development:
            clientId: ${AUTH_GITHUB_CLIENT_ID}
            clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}

            signIn:
              resolvers:
                - resolver: usernameMatchingUserEntityName

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
            - User
            - Group
            - Template

      locations:

        - type: file
          target: ./catalog/entities/users.yaml
          rules:
            - allow: [User]

        - type: file
          target: ./catalog/entities/groups.yaml
          rules:
            - allow: [Group]

        - type: file
          target: ./catalog/entities/component.yaml
          rules:
            - allow: [Component]

        - type: url
          target: https://github.com/roegema/backstage-software-templates/blob/main/python-app/template/template.yaml
          rules:
            - allow: [Template]

    integrations:
      github:
        - host: github.com
          token: ${GITHUB_TOKEN}
```

---

# Step 6 - Catalog Configuration

## catalog/entities/users.yaml

Example:

```yaml
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: roegema
spec:
  memberOf:
    - development
```

---

## catalog/entities/groups.yaml

Example:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: development
spec:
  type: team
```

---

# Step 7 - Install Backstage

Run:

```bash
./setup-backstage.sh
```

The script performs:

- Namespace validation
- Helm repository validation
- PostgreSQL service validation
- Secret validation
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

# Step 8 - Verify Backstage Startup

View logs:

```bash
kubectl logs deployment/backstage -n backstage
```

Expected:

```text
Plugin initialization complete
```

Verify readiness:

```bash
kubectl get pods -n backstage
```

Expected:

```text
1/1 Running
```

---

# Step 9 - Access Backstage

Create a port forward:

```bash
kubectl port-forward svc/backstage -n backstage 7007:7007
```

Open:

```text
http://localhost:7007
```

---

# Step 10 - Verify GitHub Authentication

Login using:

```text
Sign in with GitHub
```

User mapping is resolved through:

```yaml
resolver: usernameMatchingUserEntityName
```

Example:

GitHub username:

```text
roegema
```

Catalog entity:

```yaml
kind: User
metadata:
  name: roegema
```

This must match exactly.

---

# Step 11 - Verify Catalog Data

Connect to PostgreSQL:

```bash
kubectl exec -it \
  -n backstage \
  backstage-postgresql-0 -- \
  psql -U backstage -d backstage_plugin_catalog
```

Show all catalog entities:

```sql
select entity_ref from final_entities;
```

Expected:

```text
user:default/roegema
user:default/breanna.davison

group:default/admins
group:default/development

component:default/demo-service1
component:default/demo-service2
component:default/python-app
```

Show registered catalog locations:

```sql
select type, target from locations;
```

Expected:

```text
bootstrap
file locations
github template locations
```

Exit:

```sql
\q
```

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
- TechDocs
- Users
- Groups
- Search index
- Notifications
- Plugin data
- PostgreSQL data

---

# Database Persistence

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

Deleting the PVC removes all PostgreSQL data permanently.

---

# Current Environment Status

The following components are operational:

- ✅ Kind
- ✅ Helm
- ✅ PostgreSQL
- ✅ Backstage 1.48.0
- ✅ GitHub Authentication
- ✅ GitHub Integration
- ✅ Catalog
- ✅ Users and Groups
- ✅ Software Templates
- ✅ TechDocs
- ✅ Scaffolder
- ✅ Search
- ✅ Notifications
- ✅ Persistent PostgreSQL Storage

---

# Recommended Next Steps

1. Configure an Ingress for Backstage.
2. Integrate Argo CD.
3. Enable and configure the Kubernetes plugin.
4. Create additional software templates.
5. Create a dedicated catalog repository.
6. Publish TechDocs from GitHub repositories.
7. Add CI/CD templates.
8. Configure a production-grade authentication setup.

This setup provides a solid foundation for building an Internal Developer Platform (IDP) with Backstage on Kubernetes.
