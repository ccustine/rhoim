#!/usr/bin/env python3
"""
RHOIM Model Downloader
Downloads LLM models from HuggingFace Hub to shared volume for inference server.

Environment Variables:
    MODEL_NAME: HuggingFace model ID (e.g., "ibm-granite/granite-7b-instruct")
    HF_TOKEN: HuggingFace API token (optional, for gated models)
    MODEL_REVISION: Specific revision/branch to download (default: "main")
    OUTPUT_DIR: Target directory for model files (default: "/models")
    SKIP_IF_EXISTS: Skip download if model files exist (default: "true")
"""

import os
import sys
from pathlib import Path
from huggingface_hub import snapshot_download, HfApi
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def check_existing_model(output_dir: Path) -> bool:
    """
    Check if model files already exist in output directory.

    Args:
        output_dir: Directory to check

    Returns:
        True if model files exist, False otherwise
    """
    # Look for common model file extensions
    model_extensions = [
        "*.safetensors",  # SafeTensors format (recommended)
        "*.bin",          # PyTorch binaries
        "*.pt",           # PyTorch
        "*.gguf"          # GGUF format
    ]

    for pattern in model_extensions:
        if list(output_dir.glob(pattern)):
            return True

    return False


def validate_model_download(output_dir: Path) -> bool:
    """
    Validate that model was downloaded successfully.

    Args:
        output_dir: Directory containing downloaded model

    Returns:
        True if validation passes, False otherwise
    """
    # Check for required files
    required_files = ["config.json"]  # All models should have this

    for required_file in required_files:
        if not (output_dir / required_file).exists():
            logger.error(f"Required file not found: {required_file}")
            return False

    # Check for model weight files
    if not check_existing_model(output_dir):
        logger.error("No model weight files found")
        return False

    return True


def get_model_info(model_name: str, token: str = None) -> dict:
    """
    Get model information from HuggingFace Hub.

    Args:
        model_name: HuggingFace model ID
        token: HuggingFace API token

    Returns:
        Model info dictionary
    """
    try:
        api = HfApi(token=token)
        model_info = api.model_info(model_name)
        return {
            "id": model_info.id,
            "sha": model_info.sha,
            "last_modified": model_info.lastModified,
            "size": sum(sibling.size for sibling in model_info.siblings if hasattr(sibling, 'size'))
        }
    except Exception as e:
        logger.warning(f"Could not fetch model info: {e}")
        return {}


def main():
    """Main entry point for model downloader."""

    # Read configuration from environment
    model_name = os.getenv("MODEL_NAME", "ibm-granite/granite-7b-instruct")
    hf_token = os.getenv("HF_TOKEN")
    model_revision = os.getenv("MODEL_REVISION", "main")
    output_dir = Path(os.getenv("OUTPUT_DIR", "/models"))
    skip_if_exists = os.getenv("SKIP_IF_EXISTS", "true").lower() == "true"

    logger.info("=" * 60)
    logger.info("RHOIM Model Downloader")
    logger.info("=" * 60)
    logger.info(f"Model: {model_name}")
    logger.info(f"Revision: {model_revision}")
    logger.info(f"Output directory: {output_dir}")
    logger.info(f"Skip if exists: {skip_if_exists}")
    logger.info("=" * 60)

    # Validate output directory
    if not output_dir.exists():
        logger.error(f"Output directory does not exist: {output_dir}")
        logger.error("Ensure the volume is mounted correctly")
        return 1

    if not os.access(output_dir, os.W_OK):
        logger.error(f"Output directory is not writable: {output_dir}")
        return 1

    # Check if model already exists
    if skip_if_exists and check_existing_model(output_dir):
        logger.info("Model files already exist in output directory:")
        for pattern in ["*.safetensors", "*.bin", "*.pt"]:
            files = list(output_dir.glob(pattern))
            for file in files:
                size_gb = file.stat().st_size / (1024 ** 3)
                logger.info(f"  ✓ {file.name} ({size_gb:.2f} GB)")

        logger.info("Skipping download (SKIP_IF_EXISTS=true)")
        return 0

    # Get model information
    logger.info("Fetching model information from HuggingFace Hub...")
    model_info = get_model_info(model_name, hf_token)
    if model_info:
        size_gb = model_info.get("size", 0) / (1024 ** 3)
        logger.info(f"Model size: {size_gb:.2f} GB")
        logger.info(f"Last modified: {model_info.get('last_modified', 'unknown')}")

    # Download model
    logger.info(f"Starting download of {model_name}...")
    logger.info("This may take several minutes depending on model size and network speed")

    try:
        snapshot_download(
            repo_id=model_name,
            revision=model_revision,
            local_dir=str(output_dir),
            local_dir_use_symlinks=False,
            token=hf_token,
            # Ignore unnecessary files to save space and time
            ignore_patterns=[
                "*.msgpack",  # TensorFlow checkpoints
                "*.h5",       # Keras models
                "*.ot",       # Old format
                "*.md",       # Documentation (optional)
                ".git*"       # Git files
            ]
        )

        logger.info("✓ Download completed successfully")

    except Exception as e:
        logger.error(f"Download failed: {e}")
        logger.error("Please check:")
        logger.error("  - Model name is correct")
        logger.error("  - Network connectivity to huggingface.co")
        logger.error("  - HF_TOKEN is valid (if model is gated)")
        logger.error("  - Sufficient disk space")
        return 1

    # Validate download
    logger.info("Validating downloaded model...")
    if not validate_model_download(output_dir):
        logger.error("Model validation failed")
        return 1

    # List downloaded files
    logger.info("Downloaded model files:")
    total_size = 0
    for file in sorted(output_dir.iterdir()):
        if file.is_file() and not file.name.startswith('.'):
            size_mb = file.stat().st_size / (1024 ** 2)
            total_size += size_mb
            logger.info(f"  ✓ {file.name} ({size_mb:.1f} MB)")

    logger.info(f"Total size: {total_size / 1024:.2f} GB")
    logger.info("=" * 60)
    logger.info("Model download complete!")
    logger.info("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
