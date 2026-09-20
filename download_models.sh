#!/bin/bash
set -e

# Define the destination on the Android device
DEST_DIR="/sdcard/Android/data/com.eudemonia.eudemonia/files"
mkdir -p models

echo "======================================"
echo " Eudemonia Model Downloader (Testing) "
echo "======================================"

# NOTE: For rapid testing, this script generates small dummy model files.
# To download the ACTUAL 1.5GB models, uncomment the wget commands below!

echo "1. Getting Qwen-2.5 1.5B (GGUF)..."
wget -c -O models/qwen2.5-1.5b.gguf "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
# dd if=/dev/zero of=models/qwen2.5-1.5b.gguf bs=1M count=10 status=none

echo "2. Getting Parakeet v3 (ONNX)..."
wget -c -O models/parakeet-v3.onnx "https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/main/encoder-model.int8.onnx"
# dd if=/dev/zero of=models/parakeet-v3.onnx bs=1M count=10 status=none

echo ""
echo "Pushing models to connected Android device..."
adb shell mkdir -p $DEST_DIR

adb push models/qwen2.5-1.5b.gguf $DEST_DIR/
adb push models/parakeet-v3.onnx $DEST_DIR/

echo "======================================"
echo " Success! Models transferred to phone."
echo " Location: $DEST_DIR"
echo "======================================"
