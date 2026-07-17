#!/bin/bash
# ifbeam: FNAL beam-conditions client (fnal-fife/ifbeam). Small Makefile build
# in src/. Installs libifbeam.{so,a} + headers to $PREFIX/{lib,include}.
set -euo pipefail

cd src

# spack patch: catch the WebAPIException by reference
sed -i 's/catch (WebAPIException e)/catch (WebAPIException \&e)/' ifbeam.cc
# the Makefile hardcodes -Werror; GCC 14 -Wall/-Wextra would fail this old code
sed -i 's/ -Werror//g' Makefile

# LIBWDA/IFDHC paths: libwda + ifbeam headers live under include/, ifdhc under inc/
make \
  LIBWDA_FQ_DIR="$PREFIX" LIBWDA_LIB="$PREFIX/lib" \
  IFDHC_FQ_DIR="$PREFIX" IFDHC_LIB="$PREFIX/lib" \
  ARCH="-std=c++20"

make DESTDIR="$PREFIX" install
