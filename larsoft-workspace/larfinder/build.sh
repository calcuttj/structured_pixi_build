#!/bin/bash
# larfinder: LANGUAGES-NONE, ARCH_INDEPENDENT cetmodules helper. cmake configure
# + install just generates larfinderConfig.cmake and installs the Find modules
# (FindTensorFlow.cmake). No compiled artifacts.
set -euo pipefail

mkdir build && cd build
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DWANT_UPS:BOOL=OFF \
  -DBUILD_TESTING=OFF \
  "$SRC_DIR"
make install

# Strip stray prefix-root doc files only (guard [ -f ]).
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
