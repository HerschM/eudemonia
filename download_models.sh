#!/bin/bash
set -euo pipefail

# Downloads the on-device AI models at pinned upstream revisions, verifies each
# file against its published SHA-256, and pushes the verified set to the
# connected Android device.
#
# Files are fetched to "<name>.part" and only moved into place after the
# checksum matches, so an interrupted or mismatched download can never be
# mistaken for (or spliced onto) a good model file.

DEST_DIR="/sdcard/Android/data/com.eudemonia.eudemonia/files"

QWEN_REPO="Qwen/Qwen2.5-1.5B-Instruct-GGUF"
QWEN_REV="91cad51170dc346986eccefdc2dd33a9da36ead9"
PARAKEET_REPO="csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8"
PARAKEET_REV="84b478d541cdbf0c296a7ab5f1e20a6f8f998114"

# "<local path>|<repo>|<revision>|<remote file>|<sha256>"
MODEL_FILES=(
  "models/qwen2.5-1.5b.gguf|$QWEN_REPO|$QWEN_REV|qwen2.5-1.5b-instruct-q4_k_m.gguf|6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"
  "models/parakeet-v2/encoder.int8.onnx|$PARAKEET_REPO|$PARAKEET_REV|encoder.int8.onnx|92a10bd9c23936ea0566c29f963bc57c2a5df4261b6a8921c39abea66557ca8b"
  "models/parakeet-v2/decoder.int8.onnx|$PARAKEET_REPO|$PARAKEET_REV|decoder.int8.onnx|4d097bae3bac5c96018d5293ba39f1b657296102b142affda40378f38b020f41"
  "models/parakeet-v2/joiner.int8.onnx|$PARAKEET_REPO|$PARAKEET_REV|joiner.int8.onnx|77a29f3e5ac7d37074e0af465391b80f314015d5b97f0f90c6c7767f1d56f428"
  "models/parakeet-v2/tokens.txt|$PARAKEET_REPO|$PARAKEET_REV|tokens.txt|ec182b70dd42113aff6c5372c75cac58c952443eb22322f57bbd7f53977d497d"
)

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

fetch_verified() {
  local path="$1" repo="$2" rev="$3" remote="$4" expected="$5"

  if [ -f "$path" ] && [ "$(sha256_of "$path")" = "$expected" ]; then
    echo "  ✓ $path already verified"
    return
  fi

  echo "  ↓ $path"
  mkdir -p "$(dirname "$path")"
  rm -f "$path.part"
  curl -fL --retry 3 -o "$path.part" "https://huggingface.co/$repo/resolve/$rev/$remote"

  local actual
  actual="$(sha256_of "$path.part")"
  if [ "$actual" != "$expected" ]; then
    rm -f "$path.part"
    echo "  ✗ Checksum mismatch for $path" >&2
    echo "    expected $expected" >&2
    echo "    actual   $actual" >&2
    exit 1
  fi
  mv -f "$path.part" "$path"
  echo "  ✓ $path verified"
}

echo "======================================"
echo " Eudemonia Model Downloader"
echo "======================================"

echo "Fetching and verifying models..."
for entry in "${MODEL_FILES[@]}"; do
  IFS='|' read -r path repo rev remote expected <<< "$entry"
  fetch_verified "$path" "$repo" "$rev" "$remote" "$expected"
done

if [ "${1:-}" = "--no-push" ]; then
  echo "Skipping device push (--no-push)."
  exit 0
fi

echo ""
echo "Pushing models to connected Android device..."
adb shell mkdir -p "$DEST_DIR/parakeet-v2"
adb push models/qwen2.5-1.5b.gguf "$DEST_DIR/"
adb push models/parakeet-v2/encoder.int8.onnx models/parakeet-v2/decoder.int8.onnx \
  models/parakeet-v2/joiner.int8.onnx models/parakeet-v2/tokens.txt "$DEST_DIR/parakeet-v2/"

# Folders created by adb are owned by the shell user with no access for others, so the app
# cannot enter them and reports the model files as missing. Open them up explicitly.
adb shell chmod -R a+rwX "$DEST_DIR/parakeet-v2"

echo "Verifying files on device..."
for entry in "${MODEL_FILES[@]}"; do
  IFS='|' read -r path _ _ _ expected <<< "$entry"
  device_path="$DEST_DIR/${path#models/}"
  actual="$(adb shell sha256sum "$device_path" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "  ✗ Device copy of $device_path does not match its checksum" >&2
    exit 1
  fi
  echo "  ✓ $device_path"
done

echo "======================================"
echo " Success! Verified models are on the phone."
echo " Location: $DEST_DIR"
echo "======================================"
