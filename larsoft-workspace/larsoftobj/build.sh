#!/bin/bash
# larsoftobj: empty (LANGUAGES NONE) cetmodules bundle. The cmake configure +
# install just generates and installs larsoftobjConfig.cmake; the bundle/ subdir
# only configure_file()s scisoft release scripts into the build tree (not
# installed). No compiled artifacts.
set -euo pipefail

mkdir -p build
cd build

cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DWANT_UPS:BOOL=OFF \
  -DBUILD_TESTING=OFF \
  "$SRC_DIR"

make install

# Strip stray prefix-root doc FILES only (guard [ -f ]).
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
