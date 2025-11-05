# RHOIM Quick Start Guide

Get RHOIM up and running in 15 minutes.

## Prerequisites

### Required
- GPU-enabled Kubernetes/OpenShift cluster
- NVIDIA GPU Operator installed
- `kubectl` or `oc` CLI
- Container registry access (Quay.io)

### For Building Images
- **Linux system** with Podman/Docker
- **macOS users**: See [BUILD_ON_MACOS.md](BUILD_ON_MACOS.md) - you'll need either:
  - Podman Desktop (for local builds with emulation)
  - Remote Linux build server (recommended)
  - GitHub Actions (automated)

### Optional
- HuggingFace account and token (for gated models)

## Step 1: Build Images (5 minutes)

```bash
# Set your registry and organization
export REGISTRY=quay.io
export ORG=YOUR_ORG
export VERSION=v0.2.0

# Build images (choose based on your OS)

# On Linux:
./build.sh

# On macOS (local with Podman):
./build-macos.sh

# On macOS (remote build - fastest):
export REMOTE_HOST=build-server.example.com
./build-remote.sh

# Expected output:
# ✓ Built: quay.io/ccustine/rhoim-bootc:v0.2.0
# ✓ Built: quay.io/ccustine/rhoim-model-downloader:v0.2.0
```

**macOS Note**: Building on Apple Silicon uses emulation and is slower (15-30 min).
Remote building is recommended. See [BUILD_ON_MACOS.md](BUILD_ON_MACOS.md).

## Step 2: Push to Registry (2 minutes)

```bash
# Login to registry
podman login quay.io

# Push images
./push.sh

# Expected output:
# ✓ Pushed: quay.io/ccustine/rhoim-bootc:v0.2.0
# ✓ Pushed: quay.io/ccustine/rhoim-model-downloader:v0.2.0
```

## Step 3: Update Kubernetes Manifests (1 minute)

```bash
# Edit k8s/kustomization.yaml
# Update image references to use your registry

sed -i "s|quay.io/redhat|${REGISTRY}/${ORG}|g" k8s/kustomization.yaml
```

## Step 4: Deploy to Cluster (2 minutes)

```bash
# Set namespace
export NAMESPACE=rhoim

# Set HuggingFace token (optional, for gated models)
export HF_TOKEN=hf_YOUR_TOKEN

# Deploy
./deploy.sh

# Expected output:
# ✓ Namespace created
# ✓ Secret created
# ✓ Deployment started
```

## Step 5: Wait for Ready (5-10 minutes)

```bash
# Watch pod status
kubectl get pods -n rhoim -w

# Expected progression:
# NAME                               READY   STATUS
# rhoim-inference-xxx                0/1     Init:0/1    # Downloading model
# rhoim-inference-xxx                0/1     PodInitializing
# rhoim-inference-xxx                0/1     Running     # Loading model
# rhoim-inference-xxx                1/1     Running     # Ready!
```

## Step 6: Test API (1 minute)

```bash
# Get service URL
export RHOIM_URL=$(kubectl get svc rhoim-inference -n rhoim -o jsonpath='{.spec.clusterIP}')

# Or for OpenShift Route:
export RHOIM_URL=$(oc get route rhoim-inference -n rhoim -o jsonpath='{.spec.host}')

# Test models endpoint
curl http://${RHOIM_URL}:8000/v1/models

# Expected output:
# {
#   "object": "list",
#   "data": [
#     {
#       "id": "granite-7b-instruct",
#       "object": "model",
#       ...
#     }
#   ]
# }

# Test chat completion
curl http://${RHOIM_URL}:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-7b-instruct",
    "messages": [
      {"role": "user", "content": "What is Kubernetes?"}
    ],
    "max_tokens": 50
  }'

# Expected output:
# {
#   "id": "cmpl-xxx",
#   "object": "chat.completion",
#   "choices": [
#     {
#       "message": {
#         "role": "assistant",
#         "content": "Kubernetes is an open-source container orchestration platform..."
#       },
#       ...
#     }
#   ],
#   ...
# }
```

## Step 7: Use with OpenAI SDK

```python
from openai import OpenAI

# Create client
client = OpenAI(
    base_url=f"http://{RHOIM_URL}:8000/v1",
    api_key="dummy"  # Not used but required
)

# Chat completion
response = client.chat.completions.create(
    model="granite-7b-instruct",
    messages=[
        {"role": "user", "content": "Explain RHEL in one sentence."}
    ]
)

print(response.choices[0].message.content)
```

## Troubleshooting

### Init container stuck downloading

```bash
# Check init container logs
kubectl logs -n rhoim POD_NAME -c model-downloader

# Common fixes:
# - Verify HF_TOKEN is correct
# - Check internet connectivity
# - Ensure sufficient disk space (20Gi emptyDir)
```

### Pod fails to start

```bash
# Check events
kubectl describe pod -n rhoim POD_NAME

# Common issues:
# - No GPU nodes available
# - GPU Operator not installed
# - Insufficient resources
```

### Model fails to load

```bash
# Check inference logs
kubectl logs -n rhoim deployment/rhoim-inference -c inference

# Common fixes:
# - Reduce GPU_MEMORY to 0.7
# - Use quantized model (AWQ)
# - Reduce MAX_MODEL_LEN to 2048
```

## Alternative: Local Testing

Test locally with Podman before deploying to cluster:

```bash
# Set model and token
export MODEL_NAME=ibm-granite/granite-7b-instruct
export HF_TOKEN=hf_YOUR_TOKEN

# Run test script
./test-local.sh

# Access at http://localhost:8000
```

## Next Steps

1. **Configure monitoring**: Set up Prometheus/Grafana
2. **Add authentication**: Implement API key validation
3. **Scale up**: Add more replicas or use autoscaling
4. **Try different models**: Llama, Mistral, etc.
5. **Production hardening**: See [BOOTC_VLLM_DESIGN.md](obsidian/docs/BOOTC_VLLM_DESIGN.md)

## Clean Up

```bash
# Delete deployment
kubectl delete -k k8s/ -n rhoim

# Delete namespace
kubectl delete namespace rhoim

# Delete images
podman rmi quay.io/ccustine/rhoim-bootc:v0.2.0
podman rmi quay.io/ccustine/rhoim-model-downloader:v0.2.0
```

## Getting Help

- **Documentation**: See [README.md](README.md) and [obsidian/docs/](obsidian/docs/)
- **Issues**: Check pod logs and events
- **Performance**: See [BOOTC_VLLM_DESIGN.md](obsidian/docs/BOOTC_VLLM_DESIGN.md#performance)

---

**Estimated total time**: 15-20 minutes (including model download)

**Success criteria**:
- ✓ Pod running and ready
- ✓ API responds to /v1/models
- ✓ Chat completion works
- ✓ OpenAI SDK compatible
