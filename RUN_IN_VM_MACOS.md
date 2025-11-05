# Running RHOIM Containers in a VM on macOS

Since macOS doesn't support NVIDIA GPUs in containers, you'll need to run a Linux VM. Here are your options:

---

## Option 1: UTM (Free, Best for Apple Silicon)

UTM is a free, open-source virtualization tool for macOS that works great on Apple Silicon.

### Install UTM

```bash
brew install --cask utm
```

Or download from: https://mac.getutm.app

### Create a Linux VM

1. **Download RHEL 9 or Fedora ISO**
   - RHEL 9: https://developers.redhat.com/products/rhel/download
   - Fedora 39: https://getfedora.org (easier, no registration)

2. **Create VM in UTM**
   - Open UTM
   - Click "Create a New Virtual Machine"
   - Choose "Virtualize" (faster on Apple Silicon)
   - Select "Linux"
   - Choose your downloaded ISO
   - Allocate resources:
     - **Memory**: 8GB minimum (16GB recommended)
     - **CPU**: 4 cores minimum
     - **Disk**: 50GB minimum
   - Finish and start VM

3. **Install Linux**
   - Follow the installer prompts
   - Create a user account
   - Wait for installation to complete
   - Reboot

### Setup in VM

Once Linux is running:

```bash
# 1. Install Podman
sudo dnf install -y podman

# 2. Login to your registry
podman login quay.io

# 3. Pull your images
podman pull quay.io/rhoim-test/rhoim-model-downloader:v0.2.0-test
podman pull quay.io/rhoim-test/rhoim-bootc:v0.2.0-test

# 4. Create model volume
podman volume create rhoim-models

# 5. Download a small model for testing (CPU mode)
podman run --rm \
  -v rhoim-models:/models:Z \
  -e MODEL_NAME="ibm-granite/granite-3b-code-instruct" \
  -e HF_TOKEN="hf_YOUR_TOKEN" \
  quay.io/rhoim-test/rhoim-model-downloader:v0.2.0-test

# 6. Run inference server (CPU mode - no GPU)
podman run -d \
  --name rhoim-inference \
  -v rhoim-models:/models:Z \
  -p 8000:8000 \
  -e MODEL_PATH="/models" \
  -e MODEL_NAME="granite-3b-code-instruct" \
  quay.io/rhoim-test/rhoim-bootc:v0.2.0-test \
  python3.11 -m vllm.entrypoints.openai.api_server \
    --model /models \
    --host 0.0.0.0 \
    --port 8000 \
    --dtype auto
```

### Test from macOS

```bash
# Get VM IP address (from inside VM)
ip addr show

# From your Mac
curl http://VM_IP:8000/v1/models
```

---

## Option 2: Multipass (Canonical, Very Easy)

Multipass provides quick Ubuntu VMs.

### Install Multipass

```bash
brew install --cask multipass
```

### Create and Setup VM

```bash
# Create VM
multipass launch --name rhoim --cpus 4 --memory 8G --disk 50G

# Shell into VM
multipass shell rhoim

# Inside VM - install Podman
sudo apt update
sudo apt install -y podman

# Pull and run images (same as UTM above)
```

### Access from macOS

```bash
# Get VM IP
multipass info rhoim

# Test
curl http://VM_IP:8000/v1/models
```

---

## Option 3: OrbStack (Paid, Best Integration)

OrbStack is a fast, lightweight alternative to Docker Desktop with excellent macOS integration.

### Install OrbStack

```bash
brew install --cask orbstack
```

Or download from: https://orbstack.dev

### Create Linux Machine

```bash
# Create Ubuntu machine
orb create ubuntu rhoim -a x86_64 -c 4 -m 8G -d 50G

# SSH into machine
orb shell rhoim

# Inside machine - install Podman
sudo apt update
sudo apt install -y podman

# Pull and run (same commands as above)
```

### Access from macOS

```bash
# OrbStack provides automatic networking
# Access via machine name
curl http://rhoim.orb.local:8000/v1/models
```

---

## Option 4: Cloud GPU Instance (Best for Production Testing)

For real GPU testing, use a cloud provider.

### AWS EC2 with GPU

```bash
# 1. Launch GPU instance (from macOS)
aws ec2 run-instances \
  --image-id ami-xxxxxxxxx \
  --instance-type g4dn.xlarge \
  --key-name your-key \
  --security-group-ids sg-xxxxx

# 2. SSH to instance
ssh -i your-key.pem ec2-user@INSTANCE_IP

# 3. Install NVIDIA drivers and Podman
sudo dnf install -y nvidia-driver podman

# 4. Run with GPU
podman run -d \
  --device nvidia.com/gpu=all \
  -v rhoim-models:/models:Z \
  -p 8000:8000 \
  quay.io/rhoim-test/rhoim-bootc:v0.2.0-test
```

### GCP with GPU

```bash
# Create GPU instance
gcloud compute instances create rhoim-gpu \
  --zone=us-central1-a \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --maintenance-policy=TERMINATE \
  --image-family=rhel-9 \
  --image-project=rhel-cloud

# SSH and setup
gcloud compute ssh rhoim-gpu
```

---

## Recommended Approach for Testing

### Quick Testing (No GPU) - Use Multipass

```bash
# 1. Install
brew install --cask multipass

# 2. Create VM
multipass launch --name rhoim --cpus 4 --memory 8G --disk 50G

# 3. Transfer your images (option A: via registry)
multipass shell rhoim
sudo apt update && sudo apt install -y podman
podman login quay.io
podman pull quay.io/rhoim-test/rhoim-bootc:v0.2.0-test

# Or (option B: save/load locally)
# On macOS:
podman save quay.io/rhoim-test/rhoim-bootc:v0.2.0-test -o rhoim-bootc.tar
multipass transfer rhoim-bootc.tar rhoim:/tmp/

# In VM:
multipass shell rhoim
podman load -i /tmp/rhoim-bootc.tar
```

---

## Complete Working Example (Multipass)

Here's a complete script to test RHOIM in a VM:

### On macOS

```bash
#!/bin/bash
# setup-rhoim-vm.sh

echo "Creating VM..."
multipass launch --name rhoim \
  --cpus 4 \
  --memory 8G \
  --disk 50G \
  22.04

echo "Waiting for VM to be ready..."
sleep 10

echo "Installing Podman in VM..."
multipass exec rhoim -- bash -c '
  sudo apt update
  sudo apt install -y podman curl
'

echo "Pulling images..."
multipass exec rhoim -- bash -c "
  podman login quay.io
  podman pull quay.io/rhoim-test/rhoim-model-downloader:v0.2.0-test
  podman pull quay.io/rhoim-test/rhoim-bootc:v0.2.0-test
"

echo "Creating volume..."
multipass exec rhoim -- podman volume create rhoim-models

echo "Setup complete!"
echo ""
echo "To access VM:"
echo "  multipass shell rhoim"
echo ""
echo "To run inference server:"
echo "  multipass exec rhoim -- podman run -d --name rhoim -p 8000:8000 ..."
echo ""

VM_IP=$(multipass info rhoim | grep IPv4 | awk '{print $2}')
echo "VM IP: $VM_IP"
echo "Test with: curl http://$VM_IP:8000/v1/models"
```

Make it executable and run:

```bash
chmod +x setup-rhoim-vm.sh
./setup-rhoim-vm.sh
```

---

## Testing Without GPU (CPU Mode)

vLLM can run on CPU (slowly) for testing. Use a small model:

```bash
# In VM
podman volume create rhoim-models

# Download small model (3B parameters)
podman run --rm \
  -v rhoim-models:/models:Z \
  -e MODEL_NAME="ibm-granite/granite-3b-code-instruct" \
  -e HF_TOKEN="${HF_TOKEN}" \
  quay.io/rhoim-test/rhoim-model-downloader:v0.2.0-test

# Run on CPU
podman run -d \
  --name rhoim-cpu \
  -v rhoim-models:/models:Z \
  -p 8000:8000 \
  quay.io/rhoim-test/rhoim-bootc:v0.2.0-test \
  bash -c 'python3.11 -m vllm.entrypoints.openai.api_server \
    --model /models \
    --host 0.0.0.0 \
    --port 8000 \
    --dtype auto \
    --device cpu \
    --max-model-len 2048'
```

**Note**: CPU inference is **very slow** (10-100x slower than GPU). Only use for testing API compatibility.

---

## Testing from macOS (After VM Setup)

### Get VM IP

```bash
# Multipass
multipass info rhoim | grep IPv4

# UTM
# Check VM's terminal: ip addr show

# OrbStack
# Use: rhoim.orb.local
```

### Test API

```bash
# Set VM IP
export RHOIM_URL="http://192.168.64.X:8000"

# List models
curl $RHOIM_URL/v1/models

# Chat completion
curl $RHOIM_URL/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-3b-code-instruct",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "max_tokens": 50
  }'
```

### Use OpenAI SDK from macOS

```python
# On your Mac
from openai import OpenAI

client = OpenAI(
    base_url="http://192.168.64.X:8000/v1",
    api_key="dummy"
)

response = client.chat.completions.create(
    model="granite-3b-code-instruct",
    messages=[
        {"role": "user", "content": "Write a hello world in Python"}
    ]
)

print(response.choices[0].message.content)
```

---

## Comparison of VM Options

| Solution | Cost | Speed | Integration | GPU Support | Best For |
|----------|------|-------|-------------|-------------|----------|
| **UTM** | Free | Good | Basic | No | Apple Silicon testing |
| **Multipass** | Free | Excellent | Good | No | Quick Ubuntu VMs |
| **OrbStack** | $8/mo | Excellent | Excellent | No | Best macOS integration |
| **Parallels** | $100/yr | Excellent | Excellent | Limited | Professional use |
| **Cloud GPU** | ~$0.50/hr | Excellent | Remote | Yes | Production testing |

---

## Recommended Setup for RHOIM Development

### Local Testing (No GPU)
1. **Use Multipass** for quick Linux VMs
2. **Small model** (3B params) on CPU
3. **Test API compatibility** only

### GPU Testing
1. **AWS EC2 g4dn.xlarge** (~$0.50/hour)
2. **Full model** (7B+ params)
3. **Performance benchmarking**

### Development Workflow

```bash
# 1. Develop on macOS
code .

# 2. Build images on macOS
./build-macos.sh

# 3. Test locally in VM (API only)
multipass shell rhoim
podman run -p 8000:8000 ...

# 4. Push to registry
./push.sh

# 5. Test on GPU cloud instance
ssh aws-gpu-instance
podman pull quay.io/.../rhoim-bootc:latest
podman run --device nvidia.com/gpu=all ...

# 6. Deploy to production cluster
./deploy.sh
```

---

## Troubleshooting VM Issues

### VM won't start
```bash
# Multipass
multipass stop rhoim
multipass start rhoim

# UTM
# Restart from GUI
```

### Can't access VM from macOS
```bash
# Check VM IP
multipass info rhoim

# Test connectivity
ping VM_IP

# Check port forwarding
multipass exec rhoim -- sudo netstat -tlnp | grep 8000
```

### Out of memory in VM
```bash
# Recreate with more memory
multipass delete rhoim
multipass purge
multipass launch --name rhoim --memory 16G --cpus 4 --disk 50G
```

### Podman issues in VM
```bash
# Inside VM
sudo apt remove podman
sudo apt install -y podman

# Or use Docker instead
sudo apt install -y docker.io
sudo systemctl start docker
sudo usermod -aG docker $USER
```

---

## Next Steps

1. **Choose your VM solution** (I recommend Multipass for simplicity)
2. **Set up Linux VM** with the scripts above
3. **Test with CPU** using small model
4. **For GPU testing**, use cloud instance
5. **For production**, deploy to Kubernetes cluster

---

## Quick Start Script

Save this as `run-in-vm.sh`:

```bash
#!/bin/bash
set -e

VM_NAME="${VM_NAME:-rhoim}"

echo "Setting up RHOIM test VM..."

# Create VM
multipass launch --name $VM_NAME --cpus 4 --memory 8G --disk 50G 22.04

# Install Podman
multipass exec $VM_NAME -- bash -c '
  sudo apt update
  sudo apt install -y podman
'

# Get VM IP
VM_IP=$(multipass info $VM_NAME | grep IPv4 | awk '{print $2}')

echo ""
echo "✓ VM created: $VM_NAME"
echo "✓ IP: $VM_IP"
echo ""
echo "Next steps:"
echo "1. Shell into VM:"
echo "   multipass shell $VM_NAME"
echo ""
echo "2. Pull images:"
echo "   podman pull quay.io/rhoim-test/rhoim-bootc:v0.2.0-test"
echo ""
echo "3. Run container:"
echo "   podman run -p 8000:8000 ..."
echo ""
echo "4. Test from macOS:"
echo "   curl http://$VM_IP:8000/v1/models"
```

Run it:
```bash
chmod +x run-in-vm.sh
./run-in-vm.sh
```

---

**Recommendation**: Start with **Multipass** for easy testing, then move to **cloud GPU instance** for real performance testing.
