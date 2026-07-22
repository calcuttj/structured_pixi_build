#!/bin/bash
# duneutil: scripts/python/xml/config only (no compiled code). Modern cetmodules
# build (it already calls cet_cmake_config()).
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

cml="$SRC_DIR/CMakeLists.txt"
# Drop WERROR (cet_set_compiler_flags DIAGS CAUTIOUS WERROR): harmless here (no
# .cc compiles) but avoids any -Werror surprise, matching the other recipes.
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' "$cml"
# Drop the test/ subdir (not needed; may pull test-only deps).
sed -i '/add_subdirectory(test)/d' "$cml"

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
