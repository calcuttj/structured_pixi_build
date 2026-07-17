#!/bin/bash
# nucondb: FNAL conditions-DB client (fnal-fife/nucondb). Small Makefile build
# in src/, links ifdhc + ifbeam + libwda (+ libcurl). Installs libnucondb.{so,a}
# + headers to $PREFIX/{lib,include}.
set -euo pipefail

cd src

# spack patch: catch the WebAPIException by reference
sed -i 's/catch (WebAPIException we)/catch (WebAPIException \&we)/' nucondb.cc
sed -i 's/ -Werror//g' Makefile

# IFDHC_DIR is used for the -L link path (distinct from IFDHC_FQ_DIR for -I/inc);
# ifbeam/libwda headers under include/, ifdhc under inc/.
make \
  IFDHC_FQ_DIR="$PREFIX" IFDHC_DIR="$PREFIX" IFDHC_LIB="$PREFIX/lib" \
  IFBEAM_FQ_DIR="$PREFIX" \
  LIBWDA_FQ_DIR="$PREFIX" LIBWDA_LIB="$PREFIX/lib" \
  ARCH="-std=c++20"

make DESTDIR="$PREFIX" install
