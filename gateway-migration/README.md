# Gateway Migration — webdemoapp.com

**Project 1** — Replacing ingress-nginx with Envoy Gateway.
TLS via cert-manager + Let's Encrypt DNS-01 challenge against Route 53.

---

## What This Does

| Before | After |
|--------|-------|
| ingress-nginx | Envoy Gateway v1.7.2 |
| Self-signed or no TLS | Let's Encrypt wildcard via DNS-01 |
| Ingress objects | HTTPRoute objects (Gateway API v1.5.0) |

---

## Prerequisites

| Requirement | How to verify |
|-------------|--------------|
| Envoy Gateway running | `kubectl get pods -n envoy-gateway-system` |
| GatewayClass `eg` accepted | `kubectl get gatewayclass eg` |
| cert-manager running | `kubectl get pods -n cert-manager` |
| `route53-credentials` secret | `kubectl get secret route53-credentials -n cert-manager` |
| Route 53 hosted zone ID | AWS Console → Route 53 → Hosted Zones |

---

## Folder Structure

```
gateway-migration/
├── envoy-gateway/
│   └── gateway.yaml              # Gateway object — claims 10.0.0.230 via MetalLB
├── cert-manager/
│   ├── clusterissuer-route53.yaml # Staging + prod ClusterIssuers (DNS-01/Route53)
│   └── certificate.yaml          # SAN cert covering all subdomains
├── httproutes/
│   ├── wordpress.yaml            # webdemoapp.com + www — HTTP redirect + HTTPS
│   └── gitea-and-podinfo.yaml    # gitea + podinfo — HTTP redirect + HTTPS
├── RUNBOOK.sh                    # Ordered apply script with pre-flight checks
└── README.md                     # This file
```

---

## Apply Order

Order matters — dependencies must exist before dependent resources:

```bash
# 1. ClusterIssuers (cert-manager reads these to know how to issue certs)
kubectl apply -f cert-manager/clusterissuer-route53.yaml

# 2. Certificate (triggers the DNS-01 challenge via Route 53)
kubectl apply -f cert-manager/certificate.yaml

# 3. Gateway (claims MetalLB IP, references the TLS secret)
kubectl apply -f envoy-gateway/gateway.yaml

# 4. HTTPRoutes (reference the Gateway)
kubectl apply -f httproutes/wordpress.yaml
kubectl apply -f httproutes/gitea-and-podinfo.yaml
```

Or run the full runbook:
```bash
bash RUNBOOK.sh
```

---

## Monitoring Certificate Issuance

```bash
# Watch cert status — wait for READY: True
kubectl get certificate -n envoy-gateway-system -w

# If stuck, check events
kubectl describe certificate webdemoapp-tls -n envoy-gateway-system

# Check the ACME challenge
kubectl get challenge -n envoy-gateway-system
kubectl describe challenge -n envoy-gateway-system
```

---

## Switching Staging → Production

Once `READY: True` on staging:

1. Edit `cert-manager/certificate.yaml`
2. Change `issuerRef.name: letsencrypt-staging` → `letsencrypt-prod`
3. Delete the existing staging cert secret: `kubectl delete secret webdemoapp-tls -n envoy-gateway-system`
4. Reapply: `kubectl apply -f cert-manager/certificate.yaml`

---

## Credentials Note

The `route53-credentials` Kubernetes secret is **never committed to this repo**.
Create it imperatively:

```bash
kubectl create secret generic route53-credentials \
  --from-literal=access-key-id='AKIA...' \
  --from-literal=secret-access-key='yourkey' \
  -n cert-manager
```

Replace `<YOUR_HOSTED_ZONE_ID>` and `your-email@example.com` in the YAML files
before applying. Do not commit real values.

---


