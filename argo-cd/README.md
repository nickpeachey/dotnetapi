# Local kind + Argo CD Setup

## Prerequisites

- Docker Desktop running
- `kind`
- `kubectl`
- `git`

## Bootstrap cluster, ingress, and Argo CD

Run from repository root:

```powershell
./argo-cd/scripts/bootstrap-kind-argocd.ps1
```

This script will:

1. Create a `kind` cluster named `argocd-local` using `argo-cd/cluster/kind-config.yaml`
2. Install `ingress-nginx`
3. Install Argo CD in namespace `argocd`
4. Create Argo CD server ingress at `http://argocd.localdev.me`
5. Register Argo CD application `dotnetwebapi` pointing to `argo-cd/apps/dotnetwebapi/overlays/local`

## Access

- Argo CD UI: `http://argocd.localdev.me`
- Argo CD UI (no DNS required): `http://localhost` (hostless ingress fallback)
- API endpoint (after sync): `http://dotnetapi.localdev.me/weatherforecast`
- Initial Argo CD admin password:

```powershell
./argo-cd/scripts/get-argocd-admin-password.ps1
```

If DNS for `*.localdev.me` is unavailable on your machine, add this hosts entry:

```text
127.0.0.1 argocd.localdev.me
127.0.0.1 dotnetapi.localdev.me
```

If `kubectl port-forward` drops on request, use the resilient helper script:

```powershell
./argo-cd/scripts/start-argocd-port-forward.ps1
```

Then browse to `http://localhost:8080`.

## Health Check

Run one command to verify ingress + Argo + API route status:

```powershell
./argo-cd/scripts/health-check-local.ps1
```

## GitOps Flow

- GitHub Actions workflow: `.github/workflows/dotnetwebapi-ci-cd.yml`
- Workflow builds/tests API, pushes image to GHCR, then updates `argo-cd/apps/dotnetwebapi/overlays/local/kustomization.yaml` with the new image tag.
- Argo CD detects the Git change and deploys automatically.
