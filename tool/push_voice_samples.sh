#!/usr/bin/env bash
# Pushes the voice evaluation set to the phone's app-specific external files directory.
# Real recordings (git-ignored) go in real/, generated ones in synthetic/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLES="$ROOT/integration_test/voice_samples"
DEST="/sdcard/Android/data/com.eudemonia.eudemonia/files/voice_samples"

adb shell mkdir -p "$DEST/real" "$DEST/synthetic"
adb push "$SAMPLES/manifest.json" "$DEST/manifest.json"

shopt -s nullglob
for f in "$SAMPLES"/synthetic/*.wav; do
  adb push "$f" "$DEST/synthetic/$(basename "$f")"
done
for f in "$SAMPLES"/real/*.wav; do
  adb push "$f" "$DEST/real/$(basename "$f")"
done
# Folders created by adb are owned by the shell user with no access for others, so the app
# cannot enter them and reports the files as missing. Open them up explicitly.
adb shell chmod -R a+rwX "$DEST"
echo "Pushed voice samples to $DEST"
