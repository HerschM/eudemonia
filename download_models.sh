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
PARAKEET_REPO="csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8"
PARAKEET_REV="ed5d745623472f97cfc2e6c2916ee248798fc5a8"

# "<local path>|<repo>|<revision>|<remote file>|<sha256>"
MODEL_FILES=(
  "models/qwen2.5-1.5b.gguf|$QWEN_REPO|$QWEN_REV|qwen2.5-1.5b-instruct-q4_k_m.gguf|6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"
  "models/parakeet/encoder.int8.onnx|$PARAKEET_REPO|$PARAKEET_REV|encoder.int8.onnx|1afbe69c1ffdabee94755f42e4daf1d93549131a3da11356bda84fcef0f2c479"
  "models/parakeet/decoder.int8.onnx|$PARAKEET_REPO|$PARAKEET_REV|decoder.int8.onnx|0222a86147299d4dee90edf95b6d13827edb42ad8b7c9cf0b2582f030937c0b5"
  "models/parakeet/joiner.int8.onnx|$PARAKEET_REPO|$PARAKEET_REV|joiner.int8.onnx|cbd02f3696e9944970111fb439d9c3fd365a80374565f13f2b9c7007d253fc98"
  "models/parakeet/tokens.txt|$PARAKEET_REPO|$PARAKEET_REV|tokens.txt|d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d"
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
adb shell mkdir -p "$DEST_DIR/parakeet"
adb push models/qwen2.5-1.5b.gguf "$DEST_DIR/"
adb push models/parakeet/encoder.int8.onnx models/parakeet/decoder.int8.onnx \
  models/parakeet/joiner.int8.onnx models/parakeet/tokens.txt "$DEST_DIR/parakeet/"

# Folders created by adb are owned by the shell user with no access for others, so the app
# cannot enter them and reports the model files as missing. Open them up explicitly.
adb shell chmod -R a+rwX "$DEST_DIR/parakeet"

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
