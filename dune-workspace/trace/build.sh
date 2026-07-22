#!/bin/bash
# TRACE 3.17.11 (cetmodules build). Header-only INTERFACE libs + trace_cntl util
# + TRACEConfig for consumers. Do NOT pass -DCMAKE_*_COMPILER (TRACE clears them
# on Linux if set); rely on $CC/$CXX from the conda compiler activation.
set -euo pipefail

mkdir -p build
cd build

cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF \
  -DWANT_UPS:BOOL=OFF \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install

# TRACE installs a bare Makefile to $PREFIX/ (for building the kernel module post
# deploy). Drop it — it serves no purpose in a conda env and clutters the prefix
# root (guard so we never touch anything else).
if [ -f "$PREFIX/Makefile" ]; then rm -f "$PREFIX/Makefile"; fi
