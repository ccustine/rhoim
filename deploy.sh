#!/bin/bash
# RHOIM Deployment Script
# Deploys RHOIM to Kubernetes/OpenShift cluster

set -e

# Configuration
NAMESPACE="${NAMESPACE:-rhoim}"
HF_TOKEN="${HF_TOKEN:-}"

echo "=========================================="
echo "RHOIM Deployment"
echo "=========================================="
echo "Namespace: ${NAMESPACE}"
echo "=========================================="

# Check if kubectl/oc is available
if command -v oc &> /dev/null; then
    K8S_CLI="oc"
elif command -v kubectl &> /dev/null; then
    K8S_CLI="kubectl"
else
    echo "ERROR: Neither kubectl nor oc found"
    exit 1
fi

echo "Using CLI: ${K8S_CLI}"

# Create namespace if it doesn't exist
if ! ${K8S_CLI} get namespace "${NAMESPACE}" &> /dev/null; then
    echo "Creating namespace ${NAMESPACE}..."
    ${K8S_CLI} create namespace "${NAMESPACE}"
else
    echo "Namespace ${NAMESPACE} already exists"
fi

# Create HuggingFace token secret if provided
if [ -n "${HF_TOKEN}" ]; then
    echo "Creating HuggingFace token secret..."
    ${K8S_CLI} create secret generic huggingface-token \
        --from-literal=token="${HF_TOKEN}" \
        -n "${NAMESPACE}" \
        --dry-run=client -o yaml | ${K8S_CLI} apply -f -
    echo "✓ Secret created/updated"
else
    echo "WARNING: No HF_TOKEN provided"
    echo "Set HF_TOKEN environment variable for gated models"
fi

# Deploy using Kustomize
echo ""
echo "Deploying RHOIM..."
${K8S_CLI} apply -k k8s/ -n "${NAMESPACE}"

echo ""
echo "=========================================="
echo "Deployment Started!"
echo "=========================================="
echo ""
echo "Check status:"
echo "  ${K8S_CLI} get pods -n ${NAMESPACE} -w"
echo ""
echo "View logs:"
echo "  ${K8S_CLI} logs -n ${NAMESPACE} deployment/rhoim-inference -f"
echo ""

if [ "${K8S_CLI}" = "oc" ]; then
    echo "Get route URL:"
    echo "  oc get route rhoim-inference -n ${NAMESPACE} -o jsonpath='{.spec.host}'"
    echo ""
fi

echo "Test API (after ready):"
echo "  curl http://\$(${K8S_CLI} get svc rhoim-inference -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}'):8000/v1/models"
echo "=========================================="
