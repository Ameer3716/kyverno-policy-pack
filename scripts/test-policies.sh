#!/bin/bash
# =============================================================
# Kyverno Policy Test Script
# =============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
ERRORS=0

print_header() { echo -e "\n${BLUE}--- $1 ---${NC}"; }
print_pass()   { echo -e "  ${GREEN}✅ PASS:${NC} $1"; ((PASS++)); }
print_fail()   { echo -e "  ${RED}❌ FAIL:${NC} $1"; ((FAIL++)); }
print_blocked(){ echo -e "  ${GREEN}✅ BLOCKED (expected):${NC} $1"; ((PASS++)); }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NS="devops-demo"

echo -e "\n${BLUE}============================================${NC}"
echo -e "${BLUE}   Kyverno Policy Test Suite${NC}"
echo -e "${BLUE}============================================${NC}"

# -------------------------------------------
print_header "TEST GROUP 1: Compliant Resources (Should PASS)"
# -------------------------------------------

if kubectl apply -f "$PROJECT_DIR/manifests/test-pass/compliant-pod.yaml" -n $NS 2>&1 | grep -q "created\|configured"; then
    print_pass "Compliant pod with required labels, versioned image, and limits was accepted"
else
    OUTPUT=$(kubectl apply -f "$PROJECT_DIR/manifests/test-pass/compliant-pod.yaml" -n $NS 2>&1)
    echo "  Output: $OUTPUT"
    print_fail "Compliant pod was unexpectedly rejected"
    ((ERRORS++))
fi

# -------------------------------------------
print_header "TEST GROUP 2: Missing Labels (Should FAIL)"
# -------------------------------------------

OUTPUT=$(kubectl apply -f - -n $NS 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-no-labels
spec:
  containers:
    - name: nginx
      image: nginx:1.25.3
      resources:
        limits:
          cpu: "250m"
          memory: "256Mi"
EOF
)
if echo "$OUTPUT" | grep -q "admission webhook\|denied\|validation error"; then
    print_blocked "Pod without 'app' and 'env' labels was correctly rejected"
else
    print_fail "Pod without labels should have been blocked but wasn't"
fi

# -------------------------------------------
print_header "TEST GROUP 3: Latest Tag (Should FAIL)"
# -------------------------------------------

OUTPUT=$(kubectl apply -f - -n $NS 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-latest-tag
  labels:
    app: test
    env: dev
spec:
  securityContext:
    runAsNonRoot: true
  containers:
    - name: nginx
      image: nginx:latest
      resources:
        limits:
          cpu: "250m"
          memory: "256Mi"
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
EOF
)
if echo "$OUTPUT" | grep -q "admission webhook\|denied\|validation error"; then
    print_blocked "Pod with :latest image tag was correctly rejected"
else
    print_fail "Pod with :latest tag should have been blocked but wasn't"
fi

# -------------------------------------------
print_header "TEST GROUP 4: No Resource Limits (Should FAIL)"
# -------------------------------------------

OUTPUT=$(kubectl apply -f - -n $NS 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-no-limits
  labels:
    app: test
    env: dev
spec:
  securityContext:
    runAsNonRoot: true
  containers:
    - name: nginx
      image: nginx:1.25.3
      securityContext:
        privileged: false
EOF
)
if echo "$OUTPUT" | grep -q "admission webhook\|denied\|validation error"; then
    print_blocked "Pod without resource limits was correctly rejected"
else
    print_fail "Pod without resource limits should have been blocked"
fi

# -------------------------------------------
print_header "TEST GROUP 5: Privileged Container (Should FAIL)"
# -------------------------------------------

OUTPUT=$(kubectl apply -f - -n $NS 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  labels:
    app: test
    env: dev
spec:
  containers:
    - name: nginx
      image: nginx:1.25.3
      resources:
        limits:
          cpu: "250m"
          memory: "256Mi"
      securityContext:
        privileged: true
EOF
)
if echo "$OUTPUT" | grep -q "admission webhook\|denied\|validation error"; then
    print_blocked "Privileged container was correctly rejected"
else
    print_fail "Privileged container should have been blocked"
fi

# -------------------------------------------
print_header "TEST GROUP 6: Mutation Check"
# -------------------------------------------

# Apply compliant pod and check for mutated labels
MUTATED=$(kubectl get pod compliant-nginx-pod -n $NS -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null)
if [ "$MUTATED" == "kyverno" ]; then
    print_pass "Mutation policy added 'managed-by: kyverno' label automatically"
else
    print_fail "Mutation policy did not add expected label (got: $MUTATED)"
fi

# -------------------------------------------
print_header "TEST GROUP 7: Generation Check"
# -------------------------------------------

sleep 3  # Allow time for generation
NP=$(kubectl get networkpolicy default-deny-all -n production 2>/dev/null)
if [ -n "$NP" ]; then
    print_pass "NetworkPolicy 'default-deny-all' auto-generated in production namespace"
else
    print_fail "NetworkPolicy was not auto-generated (may need a moment - check manually)"
fi

# -------------------------------------------
echo -e "\n${BLUE}============================================${NC}"
echo -e "${BLUE}   TEST RESULTS SUMMARY${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
if [ $ERRORS -gt 0 ]; then
    echo -e "  ${YELLOW}Errors: $ERRORS${NC}"
fi
echo ""
echo "  View full policy reports:"
echo "  kubectl get policyreport -n $NS"
echo "  kubectl describe policyreport -n $NS"
echo ""

# Cleanup test resources
echo "  Cleaning up test resources..."
kubectl delete pod compliant-nginx-pod compliant-deployment test-no-labels \
    test-latest-tag test-no-limits test-privileged \
    -n $NS --ignore-not-found 2>/dev/null
kubectl delete deployment compliant-deployment -n $NS --ignore-not-found 2>/dev/null
echo -e "  ${GREEN}Cleanup done.${NC}\n"
