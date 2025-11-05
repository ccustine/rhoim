#!/bin/bash
# RHOIM Build Script for macOS
# Handles platform detection and cross-compilation

set -e

# Configuration
REGISTRY="${REGISTRY:-quay.io}"
ORG="${ORG:-ccustine}"
VERSION="${VERSION:-v0.2.0}"

BOOTC_IMAGE="${REGISTRY}/${ORG}/rhoim-bootc:${VERSION}"
DOWNLOADER_IMAGE="${REGISTRY}/${ORG}/rhoim-model-downloader:${VERSION}"

# Detect platform
ARCH=$(uname -m)
OS=$(uname -s)

echo "=========================================="
echo "RHOIM Image Builder (macOS)"
echo "=========================================="
echo "Host OS: ${OS}"
echo "Host Architecture: ${ARCH}"
echo "Registry: ${REGISTRY}"
echo "Organization: ${ORG}"
echo "Version: ${VERSION}"
echo "=========================================="

# Detect Apple Silicon
if [ "$ARCH" = "arm64" ]; then
    echo "⚠️  Detected Apple Silicon (ARM64)"
    echo "   Building for linux/amd64 (x86_64) - this will be slower"
    PLATFORM="linux/amd64"
else
    echo "Detected Intel Mac (x86_64)"
    PLATFORM="linux/amd64"
fi

# Check if podman is available
if ! command -v podman &> /dev/null; then
    echo "❌ ERROR: podman not found"
    echo ""
    echo "Install podman:"
    echo "  brew install podman"
    echo "  podman machine init --cpus 4 --memory 8192 --disk-size 100"
    echo "  podman machine start"
    exit 1
fi

# Check if podman machine is running
if ! podman machine list | grep -q "Currently running"; then
    echo "⚠️  Podman machine is not running"
    echo "Starting podman machine..."
    podman machine start || {
        echo "❌ Failed to start podman machine"
        echo ""
        echo "Initialize podman machine first:"
        echo "  podman machine init --cpus 4 --memory 8192 --disk-size 100"
        echo "  podman machine start"
        exit 1
    }
fi

echo ""
echo "✓ Podman is ready"
echo ""

# Build model downloader image
echo "=========================================="
echo "Building model downloader image..."
echo "Platform: ${PLATFORM}"
echo "Using Containerfile.public (no Red Hat credentials required)"
echo "=========================================="
cd model-downloader

if [ ! -f "Containerfile.public" ]; then
    echo "❌ ERROR: Containerfile.public not found"
    exit 1
fi

podman build \
    --platform "${PLATFORM}" \
    -t "${DOWNLOADER_IMAGE}" \
    -f Containerfile.public \
    .

echo "✓ Built: ${DOWNLOADER_IMAGE}"
cd ..

# Build bootc image
echo ""
echo "=========================================="
echo "Building bootc inference image..."
echo "Platform: ${PLATFORM}"
echo "Using Containerfile.public (no Red Hat credentials required)"
echo "=========================================="
echo "⚠️  This may take 15-30 minutes on Apple Silicon due to emulation"
echo ""

cd bootc-image

if [ ! -f "Containerfile.public" ]; then
    echo "❌ ERROR: Containerfile.public not found"
    exit 1
fi

podman build \
    --platform "${PLATFORM}" \
    -t "${BOOTC_IMAGE}" \
    -f Containerfile.public \
    .

echo "✓ Built: ${BOOTC_IMAGE}"
cd ..

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "Images:"
echo "  ✓ ${DOWNLOADER_IMAGE}"
echo "  ✓ ${BOOTC_IMAGE}"
echo ""
echo "Platform: ${PLATFORM}"
echo ""
echo "⚠️  Note: These images are built for x86_64 Linux"
echo "   They cannot run on macOS but will work on:"
echo "   - Linux x86_64 servers"
echo "   - Kubernetes/OpenShift clusters with x86_64 nodes"
echo "   - Cloud GPU instances (AWS, GCP, Azure)"
echo ""
echo "Next steps:"
echo "  1. Push to registry: ./push.sh"
echo "  2. Deploy to cluster: ./deploy.sh"
echo ""
echo "To test locally (without GPU):"
echo "  podman run --rm ${DOWNLOADER_IMAGE} --help"
echo "=========================================="
