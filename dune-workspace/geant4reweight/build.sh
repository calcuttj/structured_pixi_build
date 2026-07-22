#!/bin/bash
# geant4reweight: standalone cetmodules build (Geant4 + ROOT + cetlib/fhiclcpp).
# Gates protoduneana (geant4reweight::ReweightBaseLib/PropBaseLib). No generator env
# or larsoft contract needed — it only depends on the art utility libs + Geant4/ROOT.
set -euo pipefail

# Pin the host ROOT for dictionary generation (avoid a second ROOT in $BUILD_PREFIX).
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

export CXXFLAGS="${CXXFLAGS:-} -fpermissive -include cassert"

# Drop WERROR (GCC-14/C++20 warning set) if present.
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' "$SRC_DIR/CMakeLists.txt" || true

mkdir -p build
cd build
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -D_CheckClassVersion_ENABLED:BOOL=FALSE \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  "$SRC_DIR"

make -j"${CPU_COUNT:-2}" install
