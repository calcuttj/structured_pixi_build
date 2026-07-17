#!/bin/bash
# ifdh_art: art service wrappers around the ifdh data-handling stack
# (art-framework-suite/ifdh-art). cetmodules CMake build.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
# cetmodules' bundled Find{ifdhc,ifbeam,nucondb,libwda} search contracts:
#   ifdhc headers are under inc/ (FNAL layout); ifbeam/nucondb/libwda under include/.
export IFDHC_INC="$PREFIX/inc"
export IFDHC_DIR="$PREFIX"
export IFBEAM_FQ_DIR="$PREFIX"
export NUCONDB_FQ_DIR="$PREFIX"
export LIBWDA_INC="$PREFIX/include"

# drop WERROR: cet_set_compiler_flags(DIAGS VIGILANT WERROR ...) would promote
# GCC 14's vigilant warnings to errors on this older code.
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' CMakeLists.txt

mkdir build && cd build
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
