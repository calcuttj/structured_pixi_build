#!/bin/bash
# nusimdata: NuSoftHEP simb data products + ROOT dictionaries (cetmodules).
# ROOT-dictionary pattern: _CheckClassVersion off (PyROOT can't init in the
# rattler-build sandbox; see conda/potential_improvements.md #8).
set -euo pipefail

# nusimdata find_package(dk2nudata) resolves via nufinder's Finddk2nudata.cmake,
# whose fallback looks for dk2nu.h under $DK2NUDATA_INC/dk2nu/tree. dk2nudata
# (legacy, no CMake config) installs headers to $PREFIX/include/dk2nu/tree and
# libdk2nuTree to $PREFIX/lib, so point the env var at the host prefix.
export DK2NUDATA_INC="$PREFIX/include"

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

# Strip stray prefix-root doc FILES only (guard [ -f ]; never ROOT's README dir).
# See conda/potential_improvements.md (#7).
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
