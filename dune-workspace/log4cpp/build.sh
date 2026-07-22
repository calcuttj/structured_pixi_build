#!/bin/bash
set -euo pipefail
# Build logic mirrors the conda-forge log4cpp-feedstock build.sh (autotools).
# Refresh config.sub/config.guess for the conda cross-triplet.
cp "$BUILD_PREFIX"/share/gnuconfig/config.* ./config

# THE FIX: skip configure's AC_CHECK_LIB(nsl, gethostbyname) probe so no phantom
# -lnsl is added. log4cpp uses no libnsl symbols; without this, the .so gets a
# DT_NEEDED on libnsl.so.3 which py3.13+ conda envs don't provide (PEP 594).
export ac_cv_lib_nsl_gethostbyname=no

./configure --prefix="${PREFIX}" \
            --host="${HOST}" \
            --build="${BUILD}"

make -j"${CPU_COUNT}"
make install

# Drop the static lib (shared-only package).
rm -f "$PREFIX/lib/liblog4cpp.a"
