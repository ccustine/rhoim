#!/bin/bash
# RHOIM Inference Server Startup Script
# This script is used as an alternative entry point for container deployments

set -e

# Configuration
MODEL_PATH="${MODEL_PATH:-/models}"
MODEL_NAME="${MODEL_NAME:-granite-7b-instruct}"
PORT="${PORT:-8000}"
GPU_MEMORY="${GPU_MEMORY:-0.9}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"

echo "=========================================="
echo "RHOIM vLLM Inference Server"
echo "=========================================="
echo "Model path: $MODEL_PATH"
echo "Model name: $MODEL_NAME"
echo "Port: $PORT"
echo "GPU memory utilization: $GPU_MEMORY"
echo "Max model length: $MAX_MODEL_LEN"
echo "=========================================="

# Validate CUDA/GPU availability
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
else
    echo "WARNING: nvidia-smi not found - GPU may not be available"
fi

# Validate model directory
if [ ! -d "$MODEL_PATH" ]; then
    echo "ERROR: Model directory does not exist: $MODEL_PATH"
    exit 1
fi

# Check for model files
if ! ls "$MODEL_PATH"/*.safetensors 2>/dev/null && \
   ! ls "$MODEL_PATH"/*.bin 2>/dev/null && \
   ! ls "$MODEL_PATH"/*.pt 2>/dev/null; then
    echo "ERROR: No model files found in $MODEL_PATH"
    echo "Please ensure model is downloaded to this directory"
    exit 1
fi

# Validate config.json exists
if [ ! -f "$MODEL_PATH/config.json" ]; then
    echo "ERROR: Model config.json not found in $MODEL_PATH"
    exit 1
fi

echo "Model files found:"
ls -lh "$MODEL_PATH"/*.{safetensors,bin,pt} 2>/dev/null || true
echo "=========================================="

# Start vLLM server
echo "Starting vLLM OpenAI-compatible server..."
exec python3.11 -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --served-model-name "$MODEL_NAME" \
    --gpu-memory-utilization "$GPU_MEMORY" \
    --max-model-len "$MAX_MODEL_LEN" \
    --dtype auto \
    --trust-remote-code
