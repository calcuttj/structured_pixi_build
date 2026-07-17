#!/bin/bash
set -euo pipefail

# --- ROOT TPythia6 interface glue (+root variant) ---------------------------
# ROOT's pythia6 shim ships two extra sources the TPythia6 C++ class (and GENIE)
# need linked into libPythia6. Copy them into the source root so the library
# glob in our CMakeLists.txt compiles them in.
# (rattler-build strips the tarball's single top-level pythia6/ wrapper dir, so
# these land directly under root-shim/)
cp root-shim/pythia6_common_address.c .
cp root-shim/tpythia6_called_from_cc.F .

# --- patches (from spack builtin pythia6) -----------------------------------
# pythia6.patch (-p0): replace the source's dummy UPINIT/UPEVNT/UPVETO/PYTIME/
#   PYSTRF stubs with usable defaults. pythia6-root.patch (-p1): add the missing
#   <string.h> include to the ROOT glue C source.
patch -p0 < "$RECIPE_DIR/pythia6.patch"
patch -p1 < "$RECIPE_DIR/pythia6-root.patch"

# --- /HEPEVT/ particle-array extent -----------------------------------------
# NMXHEP -> 4000 (spack default; large enough for the LArSoft/GENIE consumers).
sed -i -E 's/^([[:space:]]+PARAMETER[[:space:]]*\([[:space:]]*NMXHEP[[:space:]]*=[[:space:]]*)[0-9]+/\14000/' pyhepc.f

# --- build ------------------------------------------------------------------
# Use our CMakeLists (the shipped Makefile can't build the +root sources).
cp "$RECIPE_DIR/CMakeLists.txt" .

# gcc/gfortran >= 10 default to -fno-common; pythia6 relies on tentative COMMON
# definitions across translation units, so force the legacy behaviour.
export CFLAGS="${CFLAGS:-} -fcommon"
export FFLAGS="${FFLAGS:-} -fcommon"

mkdir build && cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DPYTHIA6_VERSION=6.4.28
make -j"${CPU_COUNT:-2}"
make install
