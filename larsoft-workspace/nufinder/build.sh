#!/bin/bash
# nufinder: installs CMake find-modules only (no compiled code, LANGUAGES NONE).
set -euo pipefail

mkdir -p build
cd build

cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DWANT_UPS:BOOL=OFF \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install
