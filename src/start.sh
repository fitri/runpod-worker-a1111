#!/usr/bin/env bash

# Initiated message
echo "Initiated worker for runpod serverless stable diffusion webui"

# change into stable diffusion webui dir
cd /runpod-volume/stable-diffusion-webui

# Check first time setup
BOOTSTRAP_FLAG="/runpod-volume/.bootstrapped"
LOCK_FILE="/runpod-volume/.bootstrapped.lock"
STABILITY_AI="/runpod-volume/stable-diffusion-webui/repositories/stable-diffusion-stability-ai"

# Check if .bootstrapped file exist, if not proceed to first time installation
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
    echo "First time installation proceed to the setup"
    exec 9>"$LOCK_FILE"
    flock -n 9 || exit 0
    
    echo "Setting up virtual env and sourcing"
    python -m venv /runpod-volume/.venv
    source /runpod-volume/.venv/bin/activate
    
    echo "Installing modules and cache the webui"
    pip install --upgrade pip
    pip install --no-cache-dir -r /runpod-volume/stable-diffusion-webui/requirements.txt
    cp /cache.py /runpod-volume/stable-diffusion-webui/
    /runpod-volume/stable-diffusion-webui/python cache.py --use-cpu=all --ckpt /runpod-volume/stable-diffusion-webui/models/Stable-diffusion/model.safetensors

    echo "Initalized stable diffusion webui"
    if [ ! -d "$STABILITY_AI" ]; then
        echo "Initialized stable diffusion webui first time installation"
        python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test 
    fi

    # echo "Create bootstrapped file for marking installation run"
    deactivate
    touch "$BOOTSTRAP_FLAG"
fi

echo "Source virtual python env"
source /runpod-volume/.venv/bin/activate

echo "Checking for existing installation"
echo "Starting WebUI API"
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PYTHONUNBUFFERED=true
python /runpod-volume/stable-diffusion-webui/webui.py \
  --xformers \
  --no-half-vae \
  --skip-python-version-check \
  --skip-torch-cuda-test \
  --skip-install \
  --ckpt /model.safetensors \
  --lowram \
  --opt-sdp-attention \
  --disable-safe-unpickle \
  --port 3000 \
  --api \
  --nowebui \
  --skip-version-check \
  --no-hashing \
  --no-download-sd-model > /runpod-volume/webui.log 2>&1 &

echo "Starting RunPod Handler"
python -u /rp_handler.py
