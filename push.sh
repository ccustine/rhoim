#!/bin/bash
# RHOIM Push Script
# Pushes images to container registry

set -e

# Configuration
REGISTRY="${REGISTRY:-quay.io}"
ORG="${ORG:-ccustine}"
VERSION="${VERSION:-v0.2.0}"

BOOTC_IMAGE="${REGISTRY}/${ORG}/rhoim-bootc:${VERSION}"
DOWNLOADER_IMAGE="${REGISTRY}/${ORG}/rhoim-model-downloader:${VERSION}"

echo "=========================================="
echo "RHOIM Image Push"
echo "=========================================="
echo "Pushing images to ${REGISTRY}/${ORG}"
echo "=========================================="

# Login to registry (if needed)
if [ -n "${REGISTRY_USERNAME}" ] && [ -n "${REGISTRY_PASSWORD}" ]; then
    echo "Logging in to ${REGISTRY}..."
    echo "${REGISTRY_PASSWORD}" | podman login "${REGISTRY}" -u "${REGISTRY_USERNAME}" --password-stdin
fi

# Push bootc image
echo ""
echo "Pushing bootc image..."
podman push "${BOOTC_IMAGE}"
echo "✓ Pushed: ${BOOTC_IMAGE}"

# Push model downloader image
echo ""
echo "Pushing model downloader image..."
podman push "${DOWNLOADER_IMAGE}"
echo "✓ Pushed: ${DOWNLOADER_IMAGE}"

# Tag as latest
if [ "${VERSION}" != "latest" ]; then
    echo ""
    echo "Tagging as latest..."
    podman tag "${BOOTC_IMAGE}" "${REGISTRY}/${ORG}/rhoim-bootc:latest"
    podman tag "${DOWNLOADER_IMAGE}" "${REGISTRY}/${ORG}/rhoim-model-downloader:latest"
    podman push "${REGISTRY}/${ORG}/rhoim-bootc:latest"
    podman push "${REGISTRY}/${ORG}/rhoim-model-downloader:latest"
    echo "✓ Tagged and pushed :latest"
fi

echo ""
echo "=========================================="
echo "Push Complete!"
echo "=========================================="
echo "Images available at:"
echo "  - ${BOOTC_IMAGE}"
echo "  - ${DOWNLOADER_IMAGE}"
echo ""
echo "Next step: Deploy to cluster"
echo "  kubectl apply -k k8s/"
echo "=========================================="
