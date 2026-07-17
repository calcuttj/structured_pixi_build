#!/bin/bash
# PandoraSDK: clean self-contained CMake package. Build C++20 (ABI consistency
# with the art/ROOT/LArSoft stack) and drop the upstream -Werror (GCC 14's
# cautious diagnostics would otherwise fail the build).
set -euo pipefail

# drop -Werror from target_compile_options
sed -i '/-Werror/d' CMakeLists.txt

mkdir build && cd build
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DCMAKE_BUILD_TYPE=Release \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
