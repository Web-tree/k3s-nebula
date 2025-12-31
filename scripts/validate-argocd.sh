#!/usr/bin/env bash
# ArgoCD Health Validation Script
# Feature: 002-argocd-bootstrap

set -euo pipefail

NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
DOMAIN="${ARGOCD_DOMAIN:-argocd.example.com}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}[✓]${NC} $1"
}

fail() {
    echo -e "${RED}[✗]${NC} $1"
    return 1
}

echo "Validating ArgoCD deployment..."
echo "Namespace: $NAMESPACE"
echo "Domain: $DOMAIN"
echo ""

# Check namespace exists
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    pass "ArgoCD namespace exists"
else
    fail "ArgoCD namespace does not exist"
fi

# Check all ArgoCD pods are running
echo ""
echo "Checking ArgoCD pods..."
REQUIRED_PODS=(
    "argocd-application-controller"
    "argocd-applicationset-controller"
    "argocd-notifications-controller"
    "argocd-redis"
    "argocd-repo-server"
    "argocd-server"
)

ALL_PODS_RUNNING=true
for pod_prefix in "${REQUIRED_PODS[@]}"; do
    if kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$pod_prefix" --field-selector=status.phase=Running 2>/dev/null | grep -q "$pod_prefix"; then
        pass "$pod_prefix is running"
    else
        fail "$pod_prefix is not running"
        ALL_PODS_RUNNING=false
    fi
done

# Check ArgoCD server is responding
echo ""
echo "Checking ArgoCD server..."
SERVER_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=argocd-server" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$SERVER_POD" ]]; then
    if kubectl exec -n "$NAMESPACE" "$SERVER_POD" -- curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/healthz | grep -q "200"; then
        pass "ArgoCD server responding on health endpoint"
    else
        fail "ArgoCD server health endpoint not responding"
    fi
else
    fail "ArgoCD server pod not found"
fi

# Check OIDC configuration exists
echo ""
echo "Checking OIDC configuration..."
if kubectl get configmap argocd-cm -n "$NAMESPACE" -o jsonpath='{.data.oidc\.config}' 2>/dev/null | grep -q "Keycloak"; then
    pass "OIDC configuration present"
else
    fail "OIDC configuration not found"
fi

# Check Git repository connection
echo ""
echo "Checking Git repository connection..."
if kubectl get secret -n "$NAMESPACE" -l "argocd.argoproj.io/secret-type=repository" 2>/dev/null | grep -q "infrastructure-repo"; then
    pass "Git repository secret exists"
else
    fail "Git repository secret not found"
fi

# Check IngressRoute exists
echo ""
echo "Checking Traefik IngressRoute..."
if kubectl get ingressroute -n "$NAMESPACE" argocd-server &>/dev/null; then
    pass "ArgoCD IngressRoute exists"
else
    fail "ArgoCD IngressRoute not found"
fi

# Check app-of-apps if deployed
echo ""
echo "Checking app-of-apps (optional)..."
if kubectl get application -n "$NAMESPACE" app-of-apps &>/dev/null; then
    SYNC_STATUS=$(kubectl get application -n "$NAMESPACE" app-of-apps -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH_STATUS=$(kubectl get application -n "$NAMESPACE" app-of-apps -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    if [[ "$SYNC_STATUS" == "Synced" && "$HEALTH_STATUS" == "Healthy" ]]; then
        pass "App-of-apps synced and healthy"
    else
        echo "  App-of-apps: Sync=$SYNC_STATUS, Health=$HEALTH_STATUS"
    fi
else
    echo "  App-of-apps not yet deployed (deploy with: kubectl apply -f k8s/apps/argocd/templates/root-app.yaml)"
fi

echo ""
echo "Validation complete."
