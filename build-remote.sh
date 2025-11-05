#!/bin/bash
# RHOIM Remote Build Script
# Build images on a remote Linux server from macOS

set -e

# Configuration
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-$(whoami)}"
REMOTE_DIR="${REMOTE_DIR:-~/rhoim-build}"
REGISTRY="${REGISTRY:-quay.io}"
ORG="${ORG:-ccustine}"
VERSION="${VERSION:-v0.2.0}"

echo "=========================================="
echo "RHOIM Remote Builder"
echo "=========================================="

# Check if REMOTE_HOST is set
if [ -z "$REMOTE_HOST" ]; then
    echo "❌ ERROR: REMOTE_HOST not set"
    echo ""
    echo "Usage:"
    echo "  export REMOTE_HOST=build-server.example.com"
    echo "  export REMOTE_USER=your-username (optional)"
    echo "  export REMOTE_DIR=~/rhoim-build (optional)"
    echo "  ./build-remote.sh"
    echo ""
    echo "Or set in environment:"
    echo "  REMOTE_HOST=server.com ./build-remote.sh"
    exit 1
fi

echo "Remote: ${REMOTE_USER}@${REMOTE_HOST}"
echo "Directory: ${REMOTE_DIR}"
echo "Registry: ${REGISTRY}/${ORG}"
echo "Version: ${VERSION}"
echo "=========================================="

# Test SSH connection
echo ""
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" "echo 'Connection OK'" 2>/dev/null; then
    echo "❌ ERROR: Cannot connect to ${REMOTE_USER}@${REMOTE_HOST}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check SSH keys: ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}"
    echo "  2. Test manually: ssh ${REMOTE_USER}@${REMOTE_HOST}"
    echo "  3. Check firewall/network connectivity"
    exit 1
fi
echo "✓ SSH connection successful"

# Sync code to remote
echo ""
echo "Syncing code to remote server..."
rsync -avz --delete \
    --exclude '.git' \
    --exclude 'models/' \
    --exclude 'output/' \
    --exclude '.obsidian/' \
    --exclude 'obsidian/.obsidian' \
    --exclude '*.qcow2' \
    --exclude '.DS_Store' \
    --exclude '__pycache__' \
    ./ "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" || {
    echo "❌ ERROR: rsync failed"
    exit 1
}
echo "✓ Code synced"

# Build on remote
echo ""
echo "=========================================="
echo "Building on remote server..."
echo "=========================================="
ssh "${REMOTE_USER}@${REMOTE_HOST}" bash <<EOF
set -e
cd ${REMOTE_DIR}

echo "Working directory: \$(pwd)"
echo ""

# Export variables
export REGISTRY=${REGISTRY}
export ORG=${ORG}
export VERSION=${VERSION}

# Make scripts executable
chmod +x build.sh push.sh

# Build images
echo "Running build.sh..."
./build.sh

echo ""
echo "Build complete on remote server"
EOF

echo ""
echo "=========================================="
echo "Remote Build Complete!"
echo "=========================================="
echo ""
echo "Images built on ${REMOTE_HOST}:"
echo "  - ${REGISTRY}/${ORG}/rhoim-bootc:${VERSION}"
echo "  - ${REGISTRY}/${ORG}/rhoim-model-downloader:${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Push from remote:"
echo "     ssh ${REMOTE_USER}@${REMOTE_HOST} 'cd ${REMOTE_DIR} && ./push.sh'"
echo ""
echo "  2. Or push using this script:"
echo "     ./push-remote.sh"
echo ""
echo "  3. Deploy to cluster (from macOS):"
echo "     ./deploy.sh"
echo "=========================================="
