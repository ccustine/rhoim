#!/bin/bash
# RHOIM Remote Push Script
# Push images from remote server to registry

set -e

# Configuration
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-$(whoami)}"
REMOTE_DIR="${REMOTE_DIR:-~/rhoim-build}"
REGISTRY="${REGISTRY:-quay.io}"
ORG="${ORG:-ccustine}"
VERSION="${VERSION:-v0.2.0}"

echo "=========================================="
echo "RHOIM Remote Push"
echo "=========================================="

# Check if REMOTE_HOST is set
if [ -z "$REMOTE_HOST" ]; then
    echo "❌ ERROR: REMOTE_HOST not set"
    echo ""
    echo "Usage:"
    echo "  export REMOTE_HOST=build-server.example.com"
    echo "  ./push-remote.sh"
    exit 1
fi

echo "Remote: ${REMOTE_USER}@${REMOTE_HOST}"
echo "Registry: ${REGISTRY}/${ORG}"
echo "Version: ${VERSION}"
echo "=========================================="

# Push from remote
echo ""
echo "Pushing images from remote server..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" bash <<EOF
set -e
cd ${REMOTE_DIR}

export REGISTRY=${REGISTRY}
export ORG=${ORG}
export VERSION=${VERSION}

# Run push script
./push.sh
EOF

echo ""
echo "=========================================="
echo "Push Complete!"
echo "=========================================="
echo ""
echo "Images pushed to registry:"
echo "  - ${REGISTRY}/${ORG}/rhoim-bootc:${VERSION}"
echo "  - ${REGISTRY}/${ORG}/rhoim-model-downloader:${VERSION}"
echo ""
echo "Next step: Deploy to cluster"
echo "  ./deploy.sh"
echo "=========================================="
