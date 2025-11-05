#!/bin/bash
# RHOIM Model Download Script
# For bare metal/VM deployments - downloads model on first boot

set -e

# Configuration from environment
MODEL_NAME="${MODEL_NAME:-ibm-granite/granite-7b-instruct}"
MODEL_DIR="${MODEL_DIR:-/models}"
HF_TOKEN="${HF_TOKEN:-}"

echo "=========================================="
echo "RHOIM Model Downloader"
echo "=========================================="
echo "Model: $MODEL_NAME"
echo "Target directory: $MODEL_DIR"
echo "=========================================="

# Check if model already exists
if ls "$MODEL_DIR"/*.safetensors 2>/dev/null || \
   ls "$MODEL_DIR"/*.bin 2>/dev/null || \
   ls "$MODEL_DIR"/*.pt 2>/dev/null; then
    echo "Model files already exist in $MODEL_DIR:"
    ls -lh "$MODEL_DIR"/*.{safetensors,bin,pt} 2>/dev/null
    echo "Skipping download"
    exit 0
fi

# Ensure model directory exists
mkdir -p "$MODEL_DIR"

# Check disk space (need at least 10GB free)
AVAILABLE_GB=$(df -BG "$MODEL_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_GB" -lt 10 ]; then
    echo "ERROR: Insufficient disk space (need at least 10GB, have ${AVAILABLE_GB}GB)"
    exit 1
fi

echo "Available disk space: ${AVAILABLE_GB}GB"

# Login to HuggingFace if token provided
if [ -n "$HF_TOKEN" ]; then
    echo "Logging in to HuggingFace Hub..."
    huggingface-cli login --token "$HF_TOKEN"
fi

# Download model
echo "Downloading model: $MODEL_NAME"
echo "This may take several minutes..."

huggingface-cli download "$MODEL_NAME" \
    --local-dir "$MODEL_DIR" \
    --local-dir-use-symlinks False

# Validate download
if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo "ERROR: Model download failed - config.json not found"
    exit 1
fi

if ! ls "$MODEL_DIR"/*.safetensors 2>/dev/null && \
   ! ls "$MODEL_DIR"/*.bin 2>/dev/null && \
   ! ls "$MODEL_DIR"/*.pt 2>/dev/null; then
    echo "ERROR: Model download failed - no model weight files found"
    exit 1
fi

echo "=========================================="
echo "Model download complete!"
echo "Files:"
ls -lh "$MODEL_DIR"
echo "=========================================="
