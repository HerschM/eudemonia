#!/usr/bin/env bash
# Generates the deterministic synthetic voice regression set with macOS `say`.
# Output: integration_test/voice_samples/synthetic/sNN.wav (16 kHz mono 16-bit PCM).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLES="$ROOT/integration_test/voice_samples"
MANIFEST="$SAMPLES/manifest.json"
mkdir -p "$SAMPLES/synthetic"

python3 - "$MANIFEST" "$SAMPLES" <<'PY'
import json, os, subprocess, sys, wave

manifest, samples = sys.argv[1], sys.argv[2]
entries = [e for e in json.load(open(manifest)) if e["file"].startswith("synthetic/")]
failures = []

for e in entries:
    path = os.path.join(samples, e["file"])
    if e["id"] == "s20":
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(16000)
            w.writeframes(b"\x00\x00" * 16000 * 5)
    else:
        text = e["reference"]
        if e["id"] == "s19":
            # Long pause between the two sentences.
            text = text.replace("restaurant. It", "restaurant. [[slnc 5000]] It")
        subprocess.run(["say", "--data-format=LEI16@16000", "-o", path, text], check=True)
    with wave.open(path, "rb") as w:
        ok = (w.getframerate(), w.getnchannels(), w.getsampwidth()) == (16000, 1, 2)
        secs = w.getnframes() / 16000.0
    if not ok or secs <= 0:
        failures.append(e["file"])
    print(("OK   " if ok else "FAIL ") + e["file"] + " %.1fs" % secs)

if failures:
    print("Invalid WAV format: " + ", ".join(failures), file=sys.stderr)
    sys.exit(1)
print("Generated %d synthetic samples." % len(entries))
PY
