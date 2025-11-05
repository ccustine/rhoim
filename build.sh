#!/bin/bash
# RHOIM Build Script
# Builds both bootc and model-downloader images

set -e

# Configuration
REGISTRY="${REGISTRY:-quay.io}"
ORG="${ORG:-ccustine}"
VERSION="${VERSION:-v0.2.0}"

BOOTC_IMAGE="${REGISTRY}/${ORG}/rhoim-bootc:${VERSION}"
DOWNLOADER_IMAGE="${REGISTRY}/${ORG}/rhoim-model-downloader:${VERSION}"

echo "=========================================="
echo "RHOIM Image Builder"
echo "=========================================="
echo "Registry: ${REGISTRY}"
echo "Organization: ${ORG}"
echo "Version: ${VERSION}"
echo "=========================================="

# Build bootc image
echo ""
echo "Building bootc inference image..."
cd bootc-image
podman build -t "${BOOTC_IMAGE}" .
echo "✓ Built: ${BOOTC_IMAGE}"

# Build model downloader image
echo ""
echo "Building model downloader image..."
cd ../model-downloader
podman build -t "${DOWNLOADER_IMAGE}" .
echo "✓ Built: ${DOWNLOADER_IMAGE}"

cd ..

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "Images:"
echo "  - ${BOOTC_IMAGE}"
echo "  - ${DOWNLOADER_IMAGE}"
echo ""
echo "Next steps:"
echo "  1. Test locally: ./test-local.sh"
echo "  2. Push to registry: ./push.sh"
echo "  3. Deploy to cluster: kubectl apply -k k8s/"
echo "=========================================="
