# ✅ Working Backstage Installation on Kubernetes (Kind)

## Architecture

```text
Kind Cluster (backstage)

Namespace: backstage
├── Helm Release: backstage
│   ├── Backstage UI
│   └── Backstage Backend
│
└── Helm Release: backstage-postgresql
    └── PostgreSQL

Namespace: ingress-nginx
└── NGINX Ingress Controller

Namespace: argocd
└── ArgoCD

Namespace: python
└── Python Applications
```

---

# 1. Create the Kind Cluster

Create the cluster:

```bash
kind create cluster --name backstage
```

Verify the cluster:

```bash
kubectl cluster-info
kubectl get nodes
```

---

# 2. Install PostgreSQL

PostgreSQL is installed as a standalone Helm release.

```bash
./setup-postgresql.sh
```

## Configuration

`charts/postgresql/values-postgresql.yaml`

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

Verify the installation:

```bash
helm list -n backstage
kubectl get pods -n backstage
kubectl get pvc -n backstage
```

---

# 3. Configure Backstage

Disable the built-in PostgreSQL deployment.

## values-backstage.yaml

```yaml
postgresql:
  enabled: false
```

Configure Backstage to use the external PostgreSQL service:

```yaml
backend:
  database:
    client: pg
    connection:
      host: backstage-postgresql
      port: 5432
      user: backstage
      password: backstage
      database: backstage
```

---

# 4. Configure TechDocs

Backstage 1.42.0 requires a valid TechDocs configuration.

```yaml
techdocs:
  builder: local
  generator:
    runIn: local
  publisher:
    type: local
```

Without this configuration, the `app` plugin will fail during startup.

---

# 5. Install Backstage

Deploy Backstage:

```bash
./setup-backstage.sh
```

The deployment uses:

```yaml
image:
  registry: ghcr.io
  repository: backstage/backstage
  tag: "1.42.0"
```

Verify the deployment:

```bash
kubectl get pods -n backstage
```

Expected result:

```text
backstage-xxxxx                Running
backstage-postgresql-0         Running
```

---

# 6. Validate the Installation

Check the Backstage logs:

```bash
kubectl logs deployment/backstage -n backstage
```

Expected output:

```text
Plugin initialization complete
```

---

# 7. Access Backstage

Create a port forward:

```bash
kubectl port-forward svc/backstage -n backstage 7007:7007
```

Open Backstage:

```text
http://localhost:7007
```

---

# 8. Verify Guest Authentication

Run:

```bash
curl -i http://localhost:7007/api/auth/guest/refresh
```

Expected result:

```text
HTTP/1.1 200 OK
```

The response should contain a token for:

```text
user:development/guest
```

---

# 9. Upgrades

Backstage and PostgreSQL are managed as separate Helm releases.

Reinstall or upgrade Backstage:

```bash
./setup-backstage.sh
```

PostgreSQL remains untouched:

```text
Helm Release:
  backstage-postgresql
```

This preserves:

- Catalog entities
- Templates
- User settings
- Scaffolder data
- Notifications
- Plugin data

---

# Database Persistence

Do not remove PostgreSQL or its persistent volumes when reinstalling Backstage.

✅ Allowed:

```bash
helm uninstall backstage -n backstage
```

❌ Do not do this:

```bash
helm uninstall backstage-postgresql -n backstage
```

❌ Do not do this:

```bash
kubectl delete pvc --all -n backstage
```

Otherwise, all Backstage data will be permanently lost.

---

# Current Working Configuration

## PostgreSQL

```yaml
postgresql:
  enabled: false
```

## Database Connection

```yaml
backend:
  database:
    client: pg
    connection:
      host: backstage-postgresql
      port: 5432
      user: backstage
      password: backstage
      database: backstage
```

## Guest Authentication

```yaml
auth:
  providers:
    guest:
      dangerouslyAllowOutsideDevelopment: true
```

## TechDocs

```yaml
techdocs:
  builder: local
  generator:
    runIn: local
  publisher:
    type: local
```

---

# Current Environment

The following components are operational:

- ✅ Kind
- ✅ Helm
- ✅ PostgreSQL (standalone Helm release)
- ✅ Backstage 1.42.0
- ✅ Guest Authentication
- ✅ TechDocs
- ✅ Catalog
- ✅ Scaffolder
- ✅ Search
- ✅ Notifications
- ✅ ArgoCD integration ready
- ✅ Platform Engineering lab environment

---

# Recommended Next Steps

1. Configure GitHub Catalog Integration
2. Enable and configure the Kubernetes plugin
3. Create custom Scaffolder templates
4. Publish TechDocs from GitHub repositories
5. Integrate ArgoCD applications into Backstage
6. Register `python-app` as the first Catalog Component

This setup provides a solid foundation for building an Internal Developer Platform (IDP) with Backstage.
