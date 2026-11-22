#!/usr/bin/env bash
# Builds the llama.cpp native libraries bundled in
# android/app/src/main/jniLibs/arm64-v8a/ for the llama_cpp_dart binding.
#
# Why: the app runs inference on the CPU only. This build drops the Vulkan
# backend (about 1 GB extra RAM on Mali GPUs) and OpenMP, and compiles the CPU
# backend for armv8.2-a+dotprod so Q4_K/Q4_0 matmuls use the SDOT kernels.
# i8mm is left out on purpose: Cortex-A55/A78/X1 phones (e.g. Pixel 7a) do not
# have it and crash with SIGILL. Devices without dotprod are NOT supported.
#
# The llama.cpp commit is the submodule pinned by llama_cpp_dart 0.2.2
# (netdur/llama_cpp_dart@8d441a0), so the struct layouts match its ffigen
# bindings in lib/src/llama_cpp.dart.
#
# Layout: BUILD_SHARED_LIBS=ON, GGML_BACKEND_DL=OFF. libggml.so links
# libggml-cpu.so directly, so the CPU backend is registered without any
# directory scanning. libmtmd.so is required: the binding opens it as its
# entry library on Android (Llama.libraryPath = "libmtmd.so").
#
# Environment overrides:
#   ANDROID_NDK_HOME  NDK root (default $ANDROID_HOME/ndk/28.2.13676358)
#   CMAKE             cmake binary (default $ANDROID_HOME/cmake/3.22.1/bin/cmake, else PATH)
#   ANDROID_PLATFORM  e.g. android-26 (default)
#   WORK_DIR          scratch dir for the source checkout and build tree
#                     (default ${TMPDIR:-/tmp}/eudemonia-llama-build)
#   OUT_DIR           destination (default <repo>/android/app/src/main/jniLibs/arm64-v8a)
set -euo pipefail

LLAMA_CPP_COMMIT=4ffc47cb2001e7d523f9ff525335bbe34b1a2858
LLAMA_CPP_REPO=https://github.com/ggml-org/llama.cpp.git
CPU_ARCH=armv8.2-a+dotprod

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-26}"
WORK_DIR="${WORK_DIR:-${TMPDIR:-/tmp}/eudemonia-llama-build}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/android/app/src/main/jniLibs/arm64-v8a}"

if [[ -z "${CMAKE:-}" ]]; then
  if [[ -x "$ANDROID_HOME/cmake/3.22.1/bin/cmake" ]]; then
    CMAKE="$ANDROID_HOME/cmake/3.22.1/bin/cmake"
  else
    CMAKE="$(command -v cmake)"
  fi
fi
NINJA_DIR="$(dirname "$CMAKE")"   # the SDK cmake package ships ninja next to cmake
export PATH="$NINJA_DIR:$PATH"

TOOLCHAIN_BIN="$(echo "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/bin)"
STRIP="$TOOLCHAIN_BIN/llvm-strip"
LIBCXX="$(echo "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so)"
[[ -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]] || { echo "NDK not found at $ANDROID_NDK_HOME" >&2; exit 1; }

SRC="$WORK_DIR/src"
BUILD="$WORK_DIR/build-arm64-v8a"

# Fetch exactly the pinned commit.
if [[ ! -d "$SRC/.git" ]]; then
  git init -q "$SRC"
  git -C "$SRC" remote add origin "$LLAMA_CPP_REPO"
fi
if [[ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)" != "$LLAMA_CPP_COMMIT" ]]; then
  git -C "$SRC" fetch -q --depth 1 origin "$LLAMA_CPP_COMMIT"
  git -C "$SRC" checkout -q --detach FETCH_HEAD
fi

OPT_FLAGS="-O3 -DNDEBUG"
LINK_FLAGS="-Wl,-z,max-page-size=16384 -Wl,--gc-sections"

"$CMAKE" -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
  -DANDROID_STL=c++_shared \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS_RELEASE="$OPT_FLAGS" \
  -DCMAKE_CXX_FLAGS_RELEASE="$OPT_FLAGS" \
  -DCMAKE_SHARED_LINKER_FLAGS="$LINK_FLAGS" \
  -DBUILD_SHARED_LIBS=ON \
  -DGGML_BACKEND_DL=OFF \
  -DGGML_NATIVE=OFF \
  -DGGML_CPU_ARM_ARCH="$CPU_ARCH" \
  -DGGML_CPU_REPACK=ON \
  -DGGML_LLAMAFILE=ON \
  -DGGML_OPENMP=OFF \
  -DGGML_VULKAN=OFF \
  -DGGML_OPENCL=OFF \
  -DLLAMA_CURL=OFF \
  -DLLAMA_HTTPLIB=OFF \
  -DLLAMA_BUILD_COMMON=ON \
  -DLLAMA_BUILD_TOOLS=ON \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_BUILD_TESTS=OFF

# Only the libraries the binding loads; no tool executables.
"$CMAKE" --build "$BUILD" --target llama mtmd -j

LIBS=(libggml-base.so libggml-cpu.so libggml.so libllama.so libmtmd.so)
mkdir -p "$OUT_DIR"
rm -f "${OUT_DIR:?}"/*.so
for lib in "${LIBS[@]}"; do
  src_lib="$(find "$BUILD/bin" "$BUILD" -name "$lib" -type f -print -quit)"
  [[ -n "$src_lib" ]] || { echo "missing build output $lib" >&2; exit 1; }
  cp "$src_lib" "$OUT_DIR/$lib"
  "$STRIP" --strip-unneeded "$OUT_DIR/$lib"
done
cp "$LIBCXX" "$OUT_DIR/libc++_shared.so"
"$STRIP" --strip-unneeded "$OUT_DIR/libc++_shared.so"

echo "llama.cpp $LLAMA_CPP_COMMIT ($CPU_ARCH) -> $OUT_DIR"
ls -l "$OUT_DIR"
