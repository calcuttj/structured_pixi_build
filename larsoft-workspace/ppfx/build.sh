#!/bin/bash
# ppfx: "Package to predict the flux" (NuSoftHEP ppfxv2). cetmodules build.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
# nufinder Finddk2nudata / Findlibwda search contracts
export DK2NUDATA_INC="$PREFIX/include"
export LIBWDA_INC="$PREFIX/include"

# drop WERROR (GCC 14 cautious diagnostics would fail this code)
sed -i 's/DIAGS CAUTIOUS WERROR/DIAGS CAUTIOUS/' CMakeLists.txt

mkdir build && cd build
# -Dppfx_FW_DIR=fw gives install_fw a real destination (avoids the "vacuous
# destination" error seen without WANT_UPS).
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -Dppfx_FW_DIR=fw \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
