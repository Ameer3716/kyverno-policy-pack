# Kyverno DevOps Project
## Kubernetes-Native Policy Engine

---

## 📌 What is Kyverno?

Kyverno is a policy engine designed specifically for Kubernetes. It allows cluster administrators to enforce security, governance, and compliance rules using Kubernetes-native YAML — no new language required.

**Key Capabilities:**
- ✅ **Validate** — Block non-compliant resources
- 🔧 **Mutate** — Automatically patch/modify resources
- ⚙️ **Generate** — Auto-create related resources
- 📋 **Verify Images** — Check container image signatures

---

## 🗂️ Project Structure

```
kyverno-project/
├── README.md
├── policies/
│   ├── validation/
│   │   ├── require-labels.yaml              # Pods must have required labels
│   │   ├── disallow-latest-tag.yaml         # Block :latest image tags
│   │   ├── require-resource-limits.yaml     # CPU/Memory limits required
│   │   └── disallow-privileged-containers.yaml
│   ├── mutation/
│   │   ├── add-default-labels.yaml          # Auto-add labels to pods
│   │   └── add-resource-defaults.yaml       # Auto-set resource requests
│   └── generation/
│       └── generate-networkpolicy.yaml      # Auto-generate NetworkPolicy
├── manifests/
│   ├── test-pass/                           # Manifests that PASS policies
│   └── test-fail/                           # Manifests that FAIL policies
└── scripts/
    ├── setup.sh                             # Full cluster setup script
    └── test-policies.sh                     # Run all policy tests
```

---

## 🚀 Setup Guide

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Kubernetes | v1.25+ | minikube / kind |
| kubectl | Latest | https://kubernetes.io/docs/tasks/tools/ |
| Helm | v3.x | https://helm.sh/docs/intro/install/ |
| minikube | Latest | https://minikube.sigs.k8s.io/docs/start/ |

---

### Step 1: Start Local Kubernetes Cluster

```bash
# Start minikube
minikube start --driver=docker --cpus=2 --memory=4096

# Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

---

### Step 2: Install Kyverno via Helm

```bash
# Add the Kyverno Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Install Kyverno in its own namespace
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=1

# Verify Kyverno pods are running (wait ~60 seconds)
kubectl get pods -n kyverno
```

Expected output:
```
NAME                                            READY   STATUS    RESTARTS
kyverno-admission-controller-xxxx-xxxxx         1/1     Running   0
kyverno-background-controller-xxxx-xxxxx        1/1     Running   0
kyverno-cleanup-controller-xxxx-xxxxx           1/1     Running   0
kyverno-reports-controller-xxxx-xxxxx           1/1     Running   0
```

---

### Step 3: Create Test Namespace

```bash
kubectl create namespace devops-demo
kubectl label namespace devops-demo environment=demo
```

---

### Step 4: Apply All Policies

```bash
# Apply validation policies
kubectl apply -f policies/validation/

# Apply mutation policies
kubectl apply -f policies/mutation/

# Apply generation policies
kubectl apply -f policies/generation/

# Verify policies are active
kubectl get clusterpolicies
kubectl get policies -A
```

---

### Step 5: Test Policies

```bash
# Test manifests that should PASS
kubectl apply -f manifests/test-pass/ -n devops-demo

# Test manifests that should FAIL (expect errors)
kubectl apply -f manifests/test-fail/ -n devops-demo

# OR run the automated test script
chmod +x scripts/test-policies.sh
./scripts/test-policies.sh
```

---

### Step 6: View Policy Reports

```bash
# View policy violation reports
kubectl get policyreport -A
kubectl get clusterpolicyreport

# Detailed report for a namespace
kubectl describe policyreport -n devops-demo
```

---

## 🔍 Policy Summary

| Policy | Type | Action | Purpose |
|--------|------|--------|---------|
| require-labels | Validation | Enforce | All Pods must have `app` and `env` labels |
| disallow-latest-tag | Validation | Enforce | Block `:latest` container images |
| require-resource-limits | Validation | Enforce | CPU and Memory limits required |
| disallow-privileged | Validation | Enforce | Block privileged containers |
| add-default-labels | Mutation | Mutate | Auto-add `managed-by: kyverno` label |
| add-resource-defaults | Mutation | Mutate | Auto-set resource requests if missing |
| generate-networkpolicy | Generation | Generate | Auto-create default deny NetworkPolicy |

---

## 🧹 Cleanup

```bash
# Remove all policies
kubectl delete -f policies/ --recursive

# Remove test resources
kubectl delete namespace devops-demo

# Uninstall Kyverno
helm uninstall kyverno -n kyverno

# Stop minikube
minikube stop
```

---

## 📚 References

- [Kyverno Official Docs](https://kyverno.io/docs/)
- [Kyverno Policy Library](https://kyverno.io/policies/)
- [Kyverno GitHub](https://github.com/kyverno/kyverno)
# kyverno-policy-pack
