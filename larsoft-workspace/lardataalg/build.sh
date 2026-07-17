#!/bin/bash
# lardataalg: LArSoft detector-info + data algorithms (cetmodules, ROOT dicts).
# ROOT-dictionary pattern: _CheckClassVersion off (PyROOT can't init in the
# rattler-build sandbox; see conda/potential_improvements.md #8).
set -euo pipefail

# find_package(nusimdata) -> nusimdataConfig find_dependency(dk2nudata) ->
# nufinder Finddk2nudata.cmake, whose fallback needs $DK2NUDATA_INC pointing at
# the include root (dk2nudata installs headers under include/dk2nu/tree).
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
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
