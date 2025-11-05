# RHOIM - Red Hat OpenShift Inference Microservices

Bootable container (bootc) images for serving LLM inference using vLLM with OpenAI-compatible API.

## Quick Start

### Prerequisites

- GPU-enabled Kubernetes/OpenShift cluster with NVIDIA GPU Operator
- Container registry access (Quay.io)
- HuggingFace account (for model downloads)
- Linux system with Podman/Docker for building images
  - **macOS users**: See [BUILD_ON_MACOS.md](BUILD_ON_MACOS.md) for special instructions

### Build Images

**On Linux:**

```bash
# Build bootc inference image
cd bootc-image
podman build -t quay.io/ccustine/rhoim-bootc:v0.2.0 .
podman push quay.io/ccustine/rhoim-bootc:v0.2.0

# Build model downloader image
cd ../model-downloader
podman build -t quay.io/ccustine/rhoim-model-downloader:v0.2.0 .
podman push quay.io/ccustine/rhoim-model-downloader:v0.2.0
```

**On macOS:**

```bash
# Use macOS-specific build script
./build-macos.sh

# Or build remotely on Linux server
export REMOTE_HOST=build-server.example.com
./build-remote.sh
```

See [BUILD_ON_MACOS.md](BUILD_ON_MACOS.md) for detailed macOS build instructions.

### Deploy to OpenShift/Kubernetes

```bash
# Create namespace
kubectl create namespace rhoim

# Create HuggingFace token secret
kubectl create secret generic huggingface-token \
  --from-literal=token=hf_YOUR_TOKEN \
  -n rhoim

# Deploy using Kustomize
kubectl apply -k k8s/ -n rhoim

# Check deployment status
kubectl get pods -n rhoim -w

# Get route URL (OpenShift)
oc get route rhoim-inference -n rhoim
```

### Test API

```bash
# Get the service URL
export RHOIM_URL=$(oc get route rhoim-inference -n rhoim -o jsonpath='{.spec.host}')

# Test with curl
curl https://$RHOIM_URL/v1/models

# Test chat completion
curl https://$RHOIM_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-7b-instruct",
    "messages": [
      {"role": "user", "content": "What is Red Hat OpenShift?"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

### Use with OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url=f"https://{os.getenv('RHOIM_URL')}/v1",
    api_key="dummy"  # Not used, but required by SDK
)

response = client.chat.completions.create(
    model="granite-7b-instruct",
    messages=[
        {"role": "user", "content": "Hello, how are you?"}
    ]
)

print(response.choices[0].message.content)
```

## Project Structure

```
.
├── bootc-image/              # Main bootc inference image
│   ├── Containerfile         # Multi-stage bootc build
│   └── cuda-rhel9.repo       # NVIDIA CUDA repository
├── model-downloader/         # Init container for model downloads
│   ├── Containerfile         # Model downloader image
│   └── download-model.py     # Model download script
├── k8s/                      # Kubernetes manifests
│   ├── deployment.yaml       # Main deployment with init container
│   ├── service.yaml          # ClusterIP service
│   ├── route.yaml            # OpenShift route
│   ├── configmap.yaml        # Configuration
│   ├── serviceaccount.yaml   # RBAC
│   ├── pvc.yaml              # PersistentVolumeClaim (optional)
│   └── kustomization.yaml    # Kustomize config
├── config/                   # Configuration files
│   └── config.yaml           # Default vLLM config
├── scripts/                  # Startup scripts
│   ├── start-inference.sh    # Container entry point
│   └── download-model.sh     # Bare metal model download
├── systemd/                  # Systemd service units
│   └── rhoim-inference.service  # vLLM systemd service
└── obsidian/docs/            # Documentation
    ├── BOOTC_VLLM_DESIGN.md  # Detailed technical design
    ├── POC_TECHNICAL_DESIGN.md
    ├── POC_IMPLEMENTATION_ROADMAP.md
    └── EXECUTIVE_SUMMARY.md
```

## Deployment Patterns

### 1. OpenShift/Kubernetes (Recommended)

Uses init container to download model on first start:

```bash
kubectl apply -k k8s/
```

**Features**:
- ✓ Automatic model downloading
- ✓ Easy scaling
- ✓ Health checks and monitoring
- ✓ TLS termination via Route/Ingress

### 2. Standalone Podman/Docker

For development and testing:

```bash
# Create model volume
podman volume create rhoim-models

# Download model
podman run --rm \
  -v rhoim-models:/models:Z \
  -e MODEL_NAME="ibm-granite/granite-7b-instruct" \
  -e HF_TOKEN="hf_YOUR_TOKEN" \
  quay.io/ccustine/rhoim-model-downloader:v0.2.0

# Run inference server
podman run -d \
  --name rhoim-inference \
  --device nvidia.com/gpu=all \
  -v rhoim-models:/models:Z \
  -p 8000:8000 \
  quay.io/ccustine/rhoim-bootc:v0.2.0 \
  /opt/rhoim/scripts/start-inference.sh
```

### 3. Testing in VM on macOS

For local testing without GPU, run in a Linux VM:

```bash
# Quick setup with Multipass
./run-in-vm.sh

# Or see detailed guide
open RUN_IN_VM_MACOS.md
```

**Note**: macOS doesn't support NVIDIA GPUs. For GPU testing, use:
- Cloud instances (AWS, GCP, Azure)
- Remote Linux servers
- Kubernetes clusters with GPU nodes

See [RUN_IN_VM_MACOS.md](RUN_IN_VM_MACOS.md) for complete VM testing guide.

### 4. Bootable System Image (Edge/Bare Metal)

Create bootable disk image for bare metal or VM deployment:

```bash
# Build bootable disk image
podman run --rm -it \
  --privileged \
  --pull=newer \
  -v $(pwd)/output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --output /output \
  quay.io/ccustine/rhoim-bootc:v0.2.0

# Deploy to VM
virt-install \
  --name rhoim-inference \
  --memory 16384 \
  --vcpus 4 \
  --disk path=output/qcow2/disk.qcow2 \
  --import \
  --os-variant rhel9.0 \
  --network bridge=virbr0
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_NAME` | `granite-7b-instruct` | Model identifier |
| `MODEL_PATH` | `/models` | Model storage path |
| `PORT` | `8000` | Server port |
| `GPU_MEMORY` | `0.9` | GPU memory utilization (0.0-1.0) |
| `MAX_MODEL_LEN` | `4096` | Maximum sequence length |
| `HF_TOKEN` | - | HuggingFace API token |

### Configuration File

Edit `/etc/rhoim/config.yaml` or mount ConfigMap:

```yaml
model:
  name: "granite-7b-instruct"
  path: "/models"

gpu:
  memory_utilization: 0.9

inference:
  max_model_len: 4096
  max_num_seqs: 256
```

## API Endpoints

### OpenAI-Compatible

- `POST /v1/chat/completions` - Chat completions (streaming supported)
- `GET /v1/models` - List available models

### Health & Metrics

- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

### Example Request

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-7b-instruct",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain Kubernetes in one sentence."}
    ],
    "temperature": 0.7,
    "max_tokens": 50
  }'
```

## Monitoring

### Prometheus Metrics

Available at `/metrics`:

- `vllm:num_requests_running` - Active requests
- `vllm:num_requests_waiting` - Queued requests
- `vllm:gpu_cache_usage_perc` - GPU KV cache usage
- `vllm:time_to_first_token_seconds` - TTFT latency
- `vllm:time_per_output_token_seconds` - Token generation time

### Example ServiceMonitor (Prometheus Operator)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rhoim-inference
spec:
  selector:
    matchLabels:
      app: rhoim
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

## Troubleshooting

### Model fails to load

```bash
# Check logs
kubectl logs -n rhoim deployment/rhoim-inference -c inference

# Common issues:
# - Insufficient GPU memory -> Reduce GPU_MEMORY or use quantized model
# - Model files missing -> Check init container logs
# - CUDA errors -> Verify GPU Operator is running
```

### Init container fails

```bash
# Check init container logs
kubectl logs -n rhoim POD_NAME -c model-downloader

# Common issues:
# - Invalid HF_TOKEN -> Recreate secret with valid token
# - Network issues -> Check cluster internet access
# - Disk space -> Increase emptyDir sizeLimit or use PVC
```

### GPU not detected

```bash
# Verify GPU nodes
kubectl get nodes -l nvidia.com/gpu.present=true

# Check GPU Operator
kubectl get pods -n gpu-operator-resources

# Verify GPU in pod
kubectl exec -n rhoim POD_NAME -- nvidia-smi
```

## Development

### Local Testing

```bash
# Build locally
podman build -t rhoim-bootc:dev -f bootc-image/Containerfile .

# Run with local model
podman run --rm -it \
  --device nvidia.com/gpu=all \
  -v /path/to/models:/models:Z \
  -p 8000:8000 \
  rhoim-bootc:dev \
  /opt/rhoim/scripts/start-inference.sh
```

### Testing API

```bash
# Run test suite (create this)
pytest tests/

# Load testing
locust -f tests/locustfile.py --host http://localhost:8000
```

## Security

### Image Security

- Based on Red Hat Enterprise Linux 9
- Runs as non-root user (UID 1001)
- SELinux enabled
- Minimal attack surface

### Runtime Security

- Read-only root filesystem (where possible)
- No privileged containers
- Resource limits enforced
- Network policies recommended

### Model Security

- Checksum validation on download
- Only trusted HuggingFace repositories
- Token stored in Kubernetes Secret
- Optional: Scan models with safety tools

## Performance

### Expected Performance (Granite 7B on A10G GPU)

- Time to First Token (TTFT): ~200-500ms
- Throughput: ~50-100 tokens/sec
- Concurrent requests: 10-20 (depending on sequence length)
- GPU utilization: 80-95%

### Optimization Tips

1. **Use quantization**: AWQ 4-bit reduces memory by 4x
2. **Tune batch size**: Adjust `max_num_batched_tokens`
3. **Enable prefix caching**: For repetitive prompts
4. **Use tensor parallelism**: For multi-GPU setups

## Contributing

See [obsidian/docs/](obsidian/docs/) for detailed design documentation:

- [BOOTC_VLLM_DESIGN.md](obsidian/docs/BOOTC_VLLM_DESIGN.md) - Technical design
- [POC_TECHNICAL_DESIGN.md](obsidian/docs/POC_TECHNICAL_DESIGN.md) - Overall architecture
- [POC_IMPLEMENTATION_ROADMAP.md](obsidian/docs/POC_IMPLEMENTATION_ROADMAP.md) - Implementation plan

## License

Copyright Red Hat, Inc.

## Support

For issues and questions:
- GitHub Issues: (link to repo)
- Red Hat Support: (for supported deployments)

## References

- [vLLM Documentation](https://docs.vllm.ai)
- [bootc Documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Granite Models](https://huggingface.co/ibm-granite)
