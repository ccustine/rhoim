# Building RHOIM on macOS

Building bootc images on macOS requires workarounds since bootc and CUDA are Linux-specific. Here are your options, ranked from easiest to most complex.

---

## Option 1: Podman Desktop (Recommended for macOS)

Podman Desktop runs a Linux VM under the hood and works well for building x86_64 Linux containers.

### Install Podman Desktop

```bash
# Install via Homebrew
brew install podman

# Initialize and start Podman machine
podman machine init --cpus 4 --memory 8192 --disk-size 100
podman machine start

# Verify it's running
podman info
```

### Build Images

```bash
# Build model downloader (this will work)
cd model-downloader
podman build -t quay.io/ccustine/rhoim-model-downloader:v0.2.0 .

# Build bootc image (will work with caveats)
cd ../bootc-image
podman build -t quay.io/ccustine/rhoim-bootc:v0.2.0 .
```

### ⚠️ Limitations

- **No GPU support in macOS VM** - Can build but can't test GPU functionality locally
- **Architecture**: Podman on Apple Silicon (M1/M2/M3) defaults to ARM64, but you need x86_64
- **CUDA installation may fail** in the bootc image build

### Solutions for Apple Silicon

If you're on Apple Silicon Mac:

```bash
# Build for x86_64 (amd64) architecture
podman build --platform linux/amd64 \
  -t quay.io/ccustine/rhoim-model-downloader:v0.2.0 .

# For bootc image
cd ../bootc-image
podman build --platform linux/amd64 \
  -t quay.io/ccustine/rhoim-bootc:v0.2.0 .
```

**Note**: Cross-architecture builds are slower (uses emulation).

---

## Option 2: Remote Build on Linux Server (Best for bootc)

Build on a remote Linux machine with GPU access.

### Setup

```bash
# SSH to your Linux build server
ssh user@build-server.example.com

# Clone repo
git clone YOUR_REPO_URL
cd RHOIM

# Build on the remote server
./build.sh

# Push to registry from remote server
./push.sh
```

### Automate with Script

Create `build-remote.sh`:

```bash
#!/bin/bash
# Build on remote Linux server via SSH

REMOTE_HOST="${REMOTE_HOST:-build-server.example.com}"
REMOTE_USER="${REMOTE_USER:-$(whoami)}"
REMOTE_DIR="${REMOTE_DIR:-~/rhoim-build}"

echo "Building on remote: ${REMOTE_USER}@${REMOTE_HOST}"

# Sync code to remote
rsync -avz --exclude '.git' \
  --exclude 'models/' \
  --exclude 'output/' \
  ./ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/

# Build remotely
ssh ${REMOTE_USER}@${REMOTE_HOST} "
  cd ${REMOTE_DIR}
  export REGISTRY=${REGISTRY}
  export ORG=${ORG}
  export VERSION=${VERSION}
  ./build.sh
  ./push.sh
"

echo "✓ Remote build complete"
echo "Images pushed to registry"
```

Make it executable:

```bash
chmod +x build-remote.sh

# Usage
export REGISTRY=quay.io ORG=YOUR_ORG VERSION=v0.2.0
./build-remote.sh
```

---

## Option 3: GitHub Actions / CI/CD (Recommended for Production)

Let GitHub build your images automatically.

### Create `.github/workflows/build.yaml`

```yaml
name: Build RHOIM Images

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  REGISTRY: quay.io
  ORG: YOUR_ORG

jobs:
  build-model-downloader:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Quay.io
        uses: docker/login-action@v3
        with:
          registry: quay.io
          username: ${{ secrets.QUAY_USERNAME }}
          password: ${{ secrets.QUAY_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: quay.io/${{ env.ORG }}/rhoim-model-downloader
          tags: |
            type=semver,pattern={{version}}
            type=ref,event=branch
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./model-downloader
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          platforms: linux/amd64
          cache-from: type=gha
          cache-to: type=gha,mode=max

  build-bootc:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Quay.io
        uses: docker/login-action@v3
        with:
          registry: quay.io
          username: ${{ secrets.QUAY_USERNAME }}
          password: ${{ secrets.QUAY_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: quay.io/${{ env.ORG }}/rhoim-bootc
          tags: |
            type=semver,pattern={{version}}
            type=ref,event=branch
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./bootc-image
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          platforms: linux/amd64
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Setup Secrets

In GitHub repo settings, add secrets:
- `QUAY_USERNAME` - Your Quay.io username
- `QUAY_PASSWORD` - Your Quay.io password or robot token

### Usage

```bash
# Push to trigger build
git add .
git commit -m "Trigger build"
git push

# Or create a release
git tag v0.2.0
git push origin v0.2.0
```

GitHub will build and push images automatically!

---

## Option 4: Colima (Alternative to Podman)

Colima is another macOS container runtime option.

### Install

```bash
# Install Colima and Docker
brew install colima docker

# Start Colima with sufficient resources
colima start --cpu 4 --memory 8 --disk 100

# Verify
docker info
```

### Build

```bash
# Use docker command instead of podman
cd model-downloader
docker build -t quay.io/ccustine/rhoim-model-downloader:v0.2.0 .

cd ../bootc-image
docker build -t quay.io/ccustine/rhoim-bootc:v0.2.0 .

# Push
docker push quay.io/ccustine/rhoim-model-downloader:v0.2.0
docker push quay.io/ccustine/rhoim-bootc:v0.2.0
```

### For Apple Silicon

```bash
# Build for x86_64
docker buildx build --platform linux/amd64 \
  -t quay.io/ccustine/rhoim-bootc:v0.2.0 \
  --push .
```

---

## Option 5: Use Red Hat Build Service

If you have access to Red Hat's infrastructure:

### Brew/Koji Build

```bash
# This requires Red Hat internal access
rhpkg clone rhoim
cd rhoim
# Add your Containerfile
rhpkg build
```

---

## Recommended Workflow for macOS Developers

### 1. Development Phase

**On macOS**: Edit code, scripts, YAML files

```bash
# Install tools you need
brew install podman kubectl

# Edit files locally
code .  # or your preferred editor
```

### 2. Build Phase

**Option A - Remote Build** (fastest for bootc):
```bash
./build-remote.sh
```

**Option B - GitHub Actions** (most automated):
```bash
git push  # CI builds automatically
```

**Option C - Local Podman** (for model-downloader):
```bash
cd model-downloader
podman build --platform linux/amd64 \
  -t quay.io/ccustine/rhoim-model-downloader:v0.2.0 .
podman push quay.io/ccustine/rhoim-model-downloader:v0.2.0
```

### 3. Test Phase

**Can't test GPU locally on macOS**, so:

```bash
# Deploy to remote K8s cluster from macOS
export KUBECONFIG=~/.kube/config
./deploy.sh

# Monitor from macOS
kubectl logs -n rhoim deployment/rhoim-inference -f
```

---

## Quick Start: Minimal macOS Setup

Here's the fastest way to get started on macOS:

```bash
# 1. Install Podman
brew install podman

# 2. Start Podman machine
podman machine init --cpus 4 --memory 8192 --disk-size 100
podman machine start

# 3. Build model downloader (this will work)
cd model-downloader
podman build --platform linux/amd64 \
  -t quay.io/ccustine/rhoim-model-downloader:v0.2.0 .

# 4. For bootc image, use remote build or skip it for now
# You can deploy using pre-built images or build remotely

# 5. Push images
podman login quay.io
podman push quay.io/ccustine/rhoim-model-downloader:v0.2.0

# 6. Deploy to remote cluster
export KUBECONFIG=~/.kube/your-cluster-config
./deploy.sh
```

---

## Troubleshooting macOS Builds

### Issue: "exec format error" when running container

**Cause**: Built for ARM64 but need x86_64

**Solution**:
```bash
# Always specify platform
podman build --platform linux/amd64 ...
```

### Issue: CUDA installation fails in bootc build

**Cause**: CUDA binaries are x86_64 Linux only

**Solutions**:
1. Build on Linux system (remote or CI)
2. Skip CUDA verification during build (builds but won't run on macOS)
3. Use multi-stage build to copy pre-built binaries

### Issue: Podman machine out of disk space

**Solution**:
```bash
# Stop machine
podman machine stop

# Remove and recreate with more space
podman machine rm
podman machine init --disk-size 200

# Start again
podman machine start
```

### Issue: Can't test GPU functionality

**This is expected** - macOS doesn't support NVIDIA GPUs in containers.

**Solutions**:
- Deploy to remote K8s cluster for testing
- Use cloud GPU instances (AWS, GCP, Azure)
- Access remote Linux server with GPU

---

## Apple Silicon (M1/M2/M3) Specific Notes

### Architecture Differences

- Apple Silicon = `arm64` / `aarch64`
- NVIDIA GPUs / CUDA = `x86_64` / `amd64`
- Must cross-compile for production

### Always Specify Platform

```bash
# For all builds on Apple Silicon
podman build --platform linux/amd64 ...

# Or set as default
export DOCKER_DEFAULT_PLATFORM=linux/amd64
```

### Performance Note

Cross-architecture builds use QEMU emulation and are **slower** (2-5x).
- Model downloader: ~5-10 minutes
- bootc image: ~15-30 minutes

For frequent builds, use remote Linux builder.

---

## Recommended Setup Summary

| Task | Best Tool on macOS |
|------|-------------------|
| **Code editing** | Local (VS Code, etc.) |
| **Model downloader build** | Podman on macOS |
| **bootc image build** | Remote Linux or GitHub Actions |
| **Push to registry** | Podman on macOS |
| **Deploy to K8s** | kubectl from macOS |
| **Testing** | Remote K8s cluster |

---

## Example: Complete macOS Workflow

```bash
# 1. Setup (one time)
brew install podman kubectl
podman machine init --cpus 4 --memory 8192 --disk-size 100
podman machine start

# 2. Configure
export REGISTRY=quay.io
export ORG=YOUR_ORG
export VERSION=v0.2.0
export KUBECONFIG=~/.kube/your-cluster

# 3. Build model downloader locally
cd model-downloader
podman build --platform linux/amd64 \
  -t ${REGISTRY}/${ORG}/rhoim-model-downloader:${VERSION} .
cd ..

# 4. Build bootc image remotely (or use GitHub Actions)
ssh build-server 'cd ~/rhoim && ./build.sh'

# 5. Push images
podman login ${REGISTRY}
podman push ${REGISTRY}/${ORG}/rhoim-model-downloader:${VERSION}

# 6. Deploy to cluster
./deploy.sh

# 7. Monitor
kubectl logs -n rhoim -l app=rhoim -f
```

---

## Need Help?

- **Podman issues**: https://podman.io/docs
- **Apple Silicon**: Use `--platform linux/amd64` for everything
- **Can't build bootc**: Use GitHub Actions or remote Linux server
- **Can't test GPU**: Deploy to remote cluster with GPU nodes

---

**Bottom line**: You can develop on macOS, but GPU testing requires Linux infrastructure.
