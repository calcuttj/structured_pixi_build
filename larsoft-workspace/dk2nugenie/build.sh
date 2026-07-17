#!/bin/bash
# dk2nugenie: the GENIE flux-driver half of NuSoftHEP/dk2nu (same source as
# dk2nudata, built GENIE_ONLY=True). Legacy non-cetmodules ROOT/CMake build.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
# find_library(... PATHS ENV GENIE_LIB / LOG4CPP_LIB ...) reads these envs to
# locate the GENIE GFw* libs and log4cpp.
export GENIE_LIB="$PREFIX/lib"
export LOG4CPP_LIB="$PREFIX/lib"
# rootcling dictionary parsing of GDk2NuFlux.h needs the GENIE + dk2nu headers
export ROOT_INCLUDE_PATH="$PREFIX/include:$PREFIX/include/GENIE:${ROOT_INCLUDE_PATH:-}"

# --- genie/CMakeLists.txt adaptations (the spack FileFilter edits) ----------
# NOTE: spack's dk2nu.patch targets the OLD (01.10.01) genie/CMakeLists.txt; the
# v01_11_00 source already carries the modern GENIE-3.x structure (GFw* lib
# names, no ART_VERSION gate, GALGORITHM/GHEP/GTOOLFLUXDRIVERS), so the patch
# does not apply and is unnecessary. Only the three filters are still needed:
#   * GENIE headers live at $PREFIX/include/GENIE here, not $GENIE/src
#   * turn $ENV{X} refs into ${X} so our -D defines satisfy them
#   * drop the `cat $GENIE/VERSION` probe (we pass -DGENIE_VERSION instead;
#     our VERSION marker is non-numeric and would mis-detect the major version)
sed -i \
  -e 's|${GENIE}/src|${GENIE}/include/GENIE|g' \
  -e 's|\$ENV|$|g' \
  -e 's|execute_process|#execute_process|g' \
  genie/CMakeLists.txt

mkdir -p build && cd build
# CMAKE_POLICY_VERSION_MINIMUM=3.5: source declares cmake_minimum_required(2.6).
# GENIE_ONLY=ON builds only the genie/ flux driver, linking the prebuilt
# dk2nudata (DK2NUDATA_DIR). WITH_TBB stays ON but -DTBB_LIBRARY pre-populates
# the cache so its env-probe find_library is a no-op (keeps ROOT Imt linkage).
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DGENIE_ONLY=ON \
  -DGENIE="$PREFIX" \
  -DGENIE_VERSION=3.06.02 \
  -DGENIE_INC="$PREFIX/include/GENIE" \
  -DDK2NUDATA_DIR="$PREFIX" \
  -DLIBXML2_INC="$PREFIX/include/libxml2" \
  -DLIBXML2_FQ_DIR="$PREFIX" \
  -DLOG4CPP_INC="$PREFIX/include" \
  -DTBB_LIBRARY="$PREFIX/lib/libtbb.so" \
  "$SRC_DIR"

# parallel=False upstream (legacy CMake not parallel-safe)
make -j1 install
