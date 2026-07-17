#!/bin/bash
# larcoreobj: leaf LArSoft product (core data objects + simple types). Generates
# ROOT dictionaries (SummaryData) via cetmodules build_dictionary -> rootcling,
# so it follows the canvas_root_io/art_root_io ROOT-dictionary build pattern.
set -euo pipefail

mkdir -p build
cd build

# _CheckClassVersion_ENABLED=FALSE: skip cetmodules' post-dictionary
# checkClassVersion (a PyROOT script that can't initialize in the rattler-build
# sandbox). The dictionaries themselves build fine. See
# conda/potential_improvements.md (#8).
# CMAKE_CXX_STANDARD=20: LArSoft + conda-forge ROOT are cxx20.
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

# Strip any stray prefix-root doc FILES the product installs (INSTALL/LICENSE).
# Guard with [ -f ]: ROOT is a host dep, so $PREFIX/README is ROOT's *directory*
# -- only remove regular files (our own pollution), never ROOT's dir. See
# conda/potential_improvements.md (#7).
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
