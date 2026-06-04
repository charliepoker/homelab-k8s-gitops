# homelab-k8s-gitops

GitOps repository for the webdemoapp.com homelab Kubernetes platform.

This repo is the source of truth for all cluster manifests.
In Week 3 it will be mirrored to self-hosted Gitea (`gitea.webdemoapp.com`)
and watched by ArgoCD for continuous delivery.

---

## Projects

| Folder | Project | Status |
|--------|---------|--------|
| `gateway-migration/` | Envoy Gateway · cert-manager · TLS · HTTPRoutes |  ✅  |
| `gitops/` | ArgoCD Applications · Argo Rollouts |
| `security/` | Kyverno · Falco · Trivy  |
| `observability/` | Prometheus · Loki · Tempo · OTel |

---

## Cluster

| Detail | Value |
|--------|-------|
| Nodes | 3× Raspberry Pi 4 (ARM64) |
| Gateway IP | 10.0.0.231 (MetalLB) |
| Domain | webdemoapp.com |
| Storage | local-path · 1TB SSD on k8s-worker-1 |

---


# webhook test
