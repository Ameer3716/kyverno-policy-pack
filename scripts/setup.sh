#!/bin/bash
# =============================================================
# Kyverno Project - Full Setup Script
# =============================================================

set -e  # Exit immediately if any command fails

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_ok()   { echo -e "${GREEN}  ✅ $1${NC}"; }
print_warn() { echo -e "${YELLOW}  ⚠️  $1${NC}"; }
print_err()  { echo -e "${RED}  ❌ $1${NC}"; }

# -------------------------------------------
print_step "STEP 1: Checking Prerequisites"
# -------------------------------------------

command -v kubectl >/dev/null 2>&1 && print_ok "kubectl found" || { print_err "kubectl not found. Install it first."; exit 1; }
command -v helm    >/dev/null 2>&1 && print_ok "helm found"    || { print_err "helm not found. Install it first."; exit 1; }
command -v minikube>/dev/null 2>&1 && print_ok "minikube found"|| print_warn "minikube not found. Assuming cluster is already running."

# -------------------------------------------
print_step "STEP 2: Starting Kubernetes Cluster"
# -------------------------------------------

if command -v minikube >/dev/null 2>&1; then
    if minikube status | grep -q "Running"; then
        print_ok "minikube already running"
    else
        echo "  Starting minikube..."
        minikube start --driver=docker --cpus=2 --memory=4096
        print_ok "minikube started"
    fi
fi

kubectl cluster-info --request-timeout=10s >/dev/null && print_ok "Cluster is accessible" || { print_err "Cannot access cluster"; exit 1; }

# -------------------------------------------
print_step "STEP 3: Installing Kyverno via Helm"
# -------------------------------------------

helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
helm repo update

if helm status kyverno -n kyverno >/dev/null 2>&1; then
    print_warn "Kyverno already installed, upgrading..."
    helm upgrade kyverno kyverno/kyverno --namespace kyverno
else
    helm install kyverno kyverno/kyverno \
        --namespace kyverno \
        --create-namespace \
        --set replicaCount=1 \
        --wait \
        --timeout 3m
    print_ok "Kyverno installed successfully"
fi

echo "  Waiting for Kyverno pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n kyverno --timeout=120s
print_ok "All Kyverno pods are running"

# -------------------------------------------
print_step "STEP 4: Creating Demo Namespace"
# -------------------------------------------

kubectl create namespace devops-demo --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace devops-demo environment=demo --overwrite
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace production env=production --overwrite
print_ok "Namespaces created"

# -------------------------------------------
print_step "STEP 5: Applying Kyverno Policies"
# -------------------------------------------

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "  Applying validation policies..."
kubectl apply -f "$PROJECT_DIR/policies/validation/"
print_ok "Validation policies applied"

echo "  Applying mutation policies..."
kubectl apply -f "$PROJECT_DIR/policies/mutation/"
print_ok "Mutation policies applied"

echo "  Applying generation policies..."
kubectl apply -f "$PROJECT_DIR/policies/generation/"
print_ok "Generation policies applied"

# -------------------------------------------
print_step "STEP 6: Verifying Setup"
# -------------------------------------------

echo -e "\n  Active Cluster Policies:"
kubectl get clusterpolicies

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}  ✅ SETUP COMPLETE!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "  Next steps:"
echo "  1. Run tests:   ./scripts/test-policies.sh"
echo "  2. View reports: kubectl get policyreport -A"
echo ""
