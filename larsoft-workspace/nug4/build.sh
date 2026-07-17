#!/bin/bash
# nug4: NuSoftHEP Geant4 interface for art (cetmodules, art plugins + dicts).
set -euo pipefail

# find_package(nusimdata) -> nusimdataConfig find_dependency(dk2nudata) ->
# nufinder's Finddk2nudata fallback looks for dk2nu.h under $DK2NUDATA_INC/dk2nu/tree.
export DK2NUDATA_INC="$PREFIX/include"

mkdir -p build
cd build

# IGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES: keep absolute lib paths out of the
# exported nug4 targets (matches the upstream spack recipe).
# _CheckClassVersion off: PyROOT can't init in the rattler-build sandbox.
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DWANT_UPS:BOOL=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES:BOOL=ON \
  -D_CheckClassVersion_ENABLED:BOOL=FALSE \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install

# Strip stray prefix-root doc FILES only (guard [ -f ]; never ROOT's README dir).
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
