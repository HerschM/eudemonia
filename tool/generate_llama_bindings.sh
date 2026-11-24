#!/usr/bin/env bash
# Regenerates lib/features/ai_processing/native/llama_bindings.g.dart from the
# llama.cpp headers, using ffigen.yaml at the repository root.
#
# The headers must come from the commit the native libraries are built from
# (LLAMA_CPP_COMMIT in tool/build_llama_android.sh): struct layouts are copied
# into the generated Dart code, so a mismatch corrupts memory at run time.
# ffigen needs libclang (Xcode command line tools provide it on macOS).
#
# Environment overrides:
#   LLAMA_CPP_DIR  llama.cpp checkout (default ${TMPDIR:-/tmp}/eudemonia-llama-build/src,
#                  where tool/build_llama_android.sh checks the source out)
#   DART           dart binary (default: dart on PATH, else $HOME/flutter/bin/dart)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-${TMPDIR:-/tmp}/eudemonia-llama-build/src}"
DART="${DART:-$(command -v dart || echo "$HOME/flutter/bin/dart")}"

[[ -f "$LLAMA_CPP_DIR/include/llama.h" ]] || { echo "llama.h not found under $LLAMA_CPP_DIR/include" >&2; exit 1; }

EXPECTED_COMMIT="$(sed -n 's/^LLAMA_CPP_COMMIT=//p' "$REPO_ROOT/tool/build_llama_android.sh")"
ACTUAL_COMMIT="$(git -C "$LLAMA_CPP_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
if [[ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ]]; then
  echo "warning: $LLAMA_CPP_DIR is at $ACTUAL_COMMIT, but tool/build_llama_android.sh builds $EXPECTED_COMMIT" >&2
fi

# ffigen.yaml refers to the headers through this link so it holds no machine-specific path.
mkdir -p "$REPO_ROOT/.dart_tool"
ln -sfn "$LLAMA_CPP_DIR" "$REPO_ROOT/.dart_tool/llama_cpp_src"

cd "$REPO_ROOT"
"$DART" run ffigen --config ffigen.yaml
echo "llama.cpp $ACTUAL_COMMIT -> lib/features/ai_processing/native/llama_bindings.g.dart"
