#!/bin/bash
# RUNBOOK: Gateway Migration — webdemoapp.com
# Week 1 — Envoy Gateway + cert-manager + TLS
# Run from repo root: bash gateway-migration/RUNBOOK.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e
BASE="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  HOMELAB GATEWAY MIGRATION RUNBOOK"
echo "  Domain: webdemoapp.com"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── STEP 1: Pre-flight checks ─────────────────────────────────────────────
echo "[ 1/6 ] Pre-flight checks..."

echo "  → Envoy Gateway pod status:"
kubectl get pods -n envoy-gateway-system

echo ""
echo "  → GatewayClass:"
kubectl get gatewayclass eg 2>/dev/null || echo "  ⚠ GatewayClass 'eg' not found — apply it first"

echo ""
echo "  → cert-manager pods:"
kubectl get pods -n cert-manager | grep -v Completed

echo ""
echo "  → route53-credentials secret:"
kubectl get secret route53-credentials -n cert-manager 2>/dev/null \
  && echo "  ✓ Secret exists" \
  || echo "  ✗ MISSING — run: kubectl create secret generic route53-credentials --from-literal=access-key-id='AKIA...' --from-literal=secret-access-key='...' -n cert-manager"

echo ""
read -p "Pre-flight OK? Continue? (y/n) " -n 1 -r; echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

# ── STEP 2: Apply ClusterIssuers ─────────────────────────────────────────
echo ""
echo "[ 2/6 ] Applying ClusterIssuers (staging + prod)..."
kubectl apply -f "$BASE/cert-manager/clusterissuer-route53.yaml"
echo "  → Waiting for issuers to be ready..."
sleep 5
kubectl get clusterissuer

# ── STEP 3: Apply Certificate ────────────────────────────────────────────
echo ""
echo "[ 3/6 ] Applying Certificate (staging)..."
kubectl apply -f "$BASE/cert-manager/certificate.yaml"
echo ""
echo "  → Watch certificate status (Ctrl+C when READY=True):"
kubectl get certificate -n envoy-gateway-system -w &
CERT_PID=$!
sleep 60
kill $CERT_PID 2>/dev/null || true

echo ""
kubectl get certificate -n envoy-gateway-system
kubectl get certificaterequest -n envoy-gateway-system 2>/dev/null || true

# ── STEP 4: Apply Gateway ────────────────────────────────────────────────
echo ""
echo "[ 4/6 ] Applying Gateway (MetalLB IP: 10.0.0.230)..."
kubectl apply -f "$BASE/envoy-gateway/gateway.yaml"
sleep 5
echo "  → Gateway status:"
kubectl get gateway -n envoy-gateway-system

# ── STEP 5: Apply HTTPRoutes ─────────────────────────────────────────────
echo ""
echo "[ 5/6 ] Applying HTTPRoutes..."

echo "  → Creating namespaces if missing..."
kubectl create namespace wordpress --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace gitea     --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace podinfo   --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$BASE/httproutes/wordpress.yaml"
kubectl apply -f "$BASE/httproutes/gitea-and-podinfo.yaml"

echo ""
echo "  → HTTPRoute status:"
kubectl get httproute -A

# ── STEP 6: Verify ──────────────────────────────────────────────────────
echo ""
echo "[ 6/6 ] Final verification..."
echo ""
echo "  Gateway:"
kubectl get gateway -n envoy-gateway-system
echo ""
echo "  Certificate:"
kubectl get certificate -n envoy-gateway-system
echo ""
echo "  HTTPRoutes:"
kubectl get httproute -A
echo ""
echo "  TLS Secret (appears once cert is issued):"
kubectl get secret webdemoapp-tls -n envoy-gateway-system 2>/dev/null \
  && echo "  ✓ TLS secret exists" \
  || echo "  ⏳ TLS secret not yet issued — cert still pending"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RUNBOOK COMPLETE"
echo "  Next: Once READY=True on staging → swap issuerRef to"
echo "        letsencrypt-prod in certificate.yaml and reapply"
echo "═══════════════════════════════════════════════════════════"
echo ""
