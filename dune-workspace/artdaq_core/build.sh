#!/bin/bash
# artdaq_core (art/cetmodules build). Built against our newer art stack + ROOT
# 6.36/cxx20 (product_deps floors: release targeted c++17, we absorb cxx20).
set -euo pipefail

# Pin the host ROOT so ROOT dictionary generation doesn't pick up a second ROOT
# pulled into the build sandbox (silences TCling::LoadPCM noise).
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# Drop WERROR from cet_set_compiler_flags: the VIGILANT+WERROR+-pedantic combo
# turns GCC-14 / C++20 warnings into errors (deprecated decls, etc.). Remove just
# the WERROR line (leave DIAGS VIGILANT / NO_UNDEFINED / EXTRA_FLAGS intact).
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' "$SRC_DIR/CMakeLists.txt"

mkdir -p build
cd build

cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DWANT_UPS:BOOL=OFF \
  -D_CheckClassVersion_ENABLED:BOOL=FALSE \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install
