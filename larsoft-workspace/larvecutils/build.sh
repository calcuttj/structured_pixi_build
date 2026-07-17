#!/bin/bash
# larvecutils: small LArSoft utility (MarqFitAlg, OpenMP). No ROOT dictionaries,
# so the plain cetmodules-no-UPS cmake build suffices.
set -euo pipefail

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
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install

# Strip stray prefix-root doc FILES (no ROOT here, but keep the pattern uniform).
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
