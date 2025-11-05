#!/bin/bash
# RHOIM Local Test Script
# Tests images locally with Podman

set -e

# Configuration
MODEL_NAME="${MODEL_NAME:-ibm-granite/granite-7b-instruct}"
HF_TOKEN="${HF_TOKEN:-}"
VOLUME_NAME="rhoim-models-test"

echo "=========================================="
echo "RHOIM Local Test"
echo "=========================================="
echo "Model: ${MODEL_NAME}"
echo "Volume: ${VOLUME_NAME}"
echo "=========================================="

# Create volume if it doesn't exist
if ! podman volume exists "${VOLUME_NAME}"; then
    echo "Creating volume ${VOLUME_NAME}..."
    podman volume create "${VOLUME_NAME}"
fi

# Check if model is already downloaded
echo ""
echo "Checking for existing model..."
MODEL_EXISTS=$(podman run --rm \
    -v "${VOLUME_NAME}:/models:Z" \
    quay.io/ccustine/rhoim-model-downloader:v0.2.0 \
    bash -c "ls /models/*.safetensors 2>/dev/null || ls /models/*.bin 2>/dev/null || echo 'none'" | tail -1)

if [ "${MODEL_EXISTS}" = "none" ]; then
    echo "Model not found, downloading..."
    echo "This may take several minutes..."

    if [ -z "${HF_TOKEN}" ]; then
        echo "WARNING: No HF_TOKEN set - this may fail for gated models"
    fi

    podman run --rm \
        -v "${VOLUME_NAME}:/models:Z" \
        -e MODEL_NAME="${MODEL_NAME}" \
        -e HF_TOKEN="${HF_TOKEN}" \
        -e SKIP_IF_EXISTS="false" \
        quay.io/ccustine/rhoim-model-downloader:v0.2.0
else
    echo "Model already downloaded, skipping..."
fi

# Run inference server
echo ""
echo "Starting inference server..."
echo "This will take 30-60 seconds to load the model..."
echo ""

podman run --rm -it \
    --name rhoim-test \
    --device nvidia.com/gpu=all \
    -v "${VOLUME_NAME}:/models:Z" \
    -p 8000:8000 \
    -e MODEL_PATH="/models" \
    -e MODEL_NAME="granite-7b-instruct" \
    quay.io/ccustine/rhoim-bootc:v0.2.0 \
    /opt/rhoim/scripts/start-inference.sh

echo ""
echo "=========================================="
echo "Server stopped"
echo "=========================================="
echo ""
echo "To test the API, run in another terminal:"
echo "  curl http://localhost:8000/v1/models"
echo "  curl http://localhost:8000/v1/chat/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"model\":\"granite-7b-instruct\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"
echo ""
echo "Clean up:"
echo "  podman volume rm ${VOLUME_NAME}"
echo "=========================================="
