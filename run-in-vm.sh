#!/bin/bash
# RHOIM VM Setup Script
# Creates a Linux VM on macOS for testing RHOIM containers

set -e

VM_NAME="${VM_NAME:-rhoim}"
VM_CPUS="${VM_CPUS:-4}"
VM_MEMORY="${VM_MEMORY:-8G}"
VM_DISK="${VM_DISK:-50G}"

echo "=========================================="
echo "RHOIM VM Setup"
echo "=========================================="
echo "VM Name: $VM_NAME"
echo "CPUs: $VM_CPUS"
echo "Memory: $VM_MEMORY"
echo "Disk: $VM_DISK"
echo "=========================================="
echo ""

# Check if Multipass is installed
if ! command -v multipass &> /dev/null; then
    echo "❌ Multipass not found"
    echo ""
    echo "Install Multipass:"
    echo "  brew install --cask multipass"
    echo ""
    echo "Or download from: https://multipass.run"
    exit 1
fi

echo "✓ Multipass found: $(multipass version | head -1)"
echo ""

# Check if VM already exists
if multipass list | grep -q "^$VM_NAME"; then
    echo "⚠️  VM '$VM_NAME' already exists"
    echo ""
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing VM..."
        multipass delete $VM_NAME
        multipass purge
    else
        echo "Using existing VM"
        VM_IP=$(multipass info $VM_NAME | grep IPv4 | awk '{print $2}')
        echo ""
        echo "VM IP: $VM_IP"
        echo ""
        echo "Shell into VM:"
        echo "  multipass shell $VM_NAME"
        exit 0
    fi
fi

# Create VM
echo "Creating VM..."
multipass launch --name $VM_NAME \
  --cpus $VM_CPUS \
  --memory $VM_MEMORY \
  --disk $VM_DISK \
  22.04

echo "✓ VM created"
echo ""

# Wait for VM to be ready
echo "Waiting for VM to be ready..."
sleep 5

# Install dependencies
echo "Installing Podman and dependencies..."
multipass exec $VM_NAME -- bash -c '
  sudo apt update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt install -y podman curl jq
'

echo "✓ Dependencies installed"
echo ""

# Get VM IP
VM_IP=$(multipass info $VM_NAME | grep IPv4 | awk '{print $2}')

echo "=========================================="
echo "✓ VM Setup Complete!"
echo "=========================================="
echo ""
echo "VM Details:"
echo "  Name: $VM_NAME"
echo "  IP: $VM_IP"
echo "  CPUs: $VM_CPUS"
echo "  Memory: $VM_MEMORY"
echo ""
echo "Next Steps:"
echo ""
echo "1. Shell into VM:"
echo "   multipass shell $VM_NAME"
echo ""
echo "2. Pull RHOIM images:"
echo "   podman login quay.io"
echo "   podman pull quay.io/rhoim-test/rhoim-model-downloader:v0.2.0-test"
echo "   podman pull quay.io/rhoim-test/rhoim-bootc:v0.2.0-test"
echo ""
echo "3. Create model volume:"
echo "   podman volume create rhoim-models"
echo ""
echo "4. Download model (small for CPU testing):"
echo "   podman run --rm \\"
echo "     -v rhoim-models:/models:Z \\"
echo "     -e MODEL_NAME=\"ibm-granite/granite-3b-code-instruct\" \\"
echo "     -e HF_TOKEN=\"hf_YOUR_TOKEN\" \\"
echo "     quay.io/rhoim-test/rhoim-model-downloader:v0.2.0-test"
echo ""
echo "5. Run inference server (CPU mode):"
echo "   podman run -d --name rhoim-cpu \\"
echo "     -v rhoim-models:/models:Z \\"
echo "     -p 8000:8000 \\"
echo "     quay.io/rhoim-test/rhoim-bootc:v0.2.0-test \\"
echo "     python3.11 -m vllm.entrypoints.openai.api_server \\"
echo "       --model /models \\"
echo "       --host 0.0.0.0 \\"
echo "       --port 8000 \\"
echo "       --device cpu"
echo ""
echo "6. Test from macOS:"
echo "   curl http://$VM_IP:8000/v1/models"
echo ""
echo "To delete VM later:"
echo "  multipass delete $VM_NAME && multipass purge"
echo "=========================================="
