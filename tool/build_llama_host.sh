#!/usr/bin/env bash
# Builds llama.cpp for this machine (CPU only, shared libraries) at the commit pinned in
# tool/build_llama_android.sh, for the host test of the real library:
#
#   tool/build_llama_host.sh
#   EUDEMONIA_LLAMA_LIB=<printed path> EUDEMONIA_LLAMA_MODEL=<a ChatML .gguf> \
#     ~/flutter/bin/flutter test test/native/
#
# Environment overrides:
#   CMAKE     cmake binary (default: PATH)
#   WORK_DIR  scratch directory (default ${TMPDIR:-/tmp}/eudemonia-llama-host)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_CPP_COMMIT="$(sed -n 's/^LLAMA_CPP_COMMIT=//p' "$REPO_ROOT/tool/build_llama_android.sh")"
LLAMA_CPP_REPO=https://github.com/ggml-org/llama.cpp.git
CMAKE="${CMAKE:-$(command -v cmake)}"
WORK_DIR="${WORK_DIR:-${TMPDIR:-/tmp}/eudemonia-llama-host}"
SRC="$WORK_DIR/src"
BUILD="$WORK_DIR/build"

if [[ ! -d "$SRC/.git" ]]; then
  git init -q "$SRC"
  git -C "$SRC" remote add origin "$LLAMA_CPP_REPO"
fi
if [[ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)" != "$LLAMA_CPP_COMMIT" ]]; then
  git -C "$SRC" fetch -q --depth 1 origin "$LLAMA_CPP_COMMIT"
  git -C "$SRC" checkout -q --detach FETCH_HEAD
fi

"$CMAKE" -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DGGML_METAL=OFF \
  -DGGML_ACCELERATE=OFF \
  -DGGML_BLAS=OFF \
  -DGGML_OPENMP=OFF \
  -DLLAMA_CURL=OFF \
  -DLLAMA_HTTPLIB=OFF \
  -DLLAMA_OPENSSL=OFF \
  -DLLAMA_BUILD_COMMON=OFF \
  -DLLAMA_BUILD_TOOLS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_BUILD_TESTS=OFF
"$CMAKE" --build "$BUILD" --target llama -j 8

LIB="$(find "$BUILD/bin" -name 'libllama.dylib' -o -name 'libllama.so' | head -1)"
[[ -n "$LIB" ]] || { echo "libllama was not built" >&2; exit 1; }
echo "$LIB"
