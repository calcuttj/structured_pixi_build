#!/bin/bash
# larwirecell: LArSoft <-> Wire-Cell Toolkit bridge. cetmodules build above
# larsim+larevt, consuming the wire-cell-toolkit 0.37.0 conda package.
set -euo pipefail

export ROOTSYS="$PREFIX"
# Put host ($PREFIX) bin AFTER the build tools, not before. We need host ROOT's
# root-config/rootcling (they live only in $PREFIX/bin -- build_env has no ROOT), but
# root_base also pulls a compiler (gxx_impl) + its own sysroot into the HOST env, and
# conda's $CC/$CXX are bare names. Prepending $PREFIX/bin would resolve the compiler to
# the HOST one, whose --sysroot then mismatches libs find_library locates in the BUILD
# sysroot (e.g. HDF5's -lpthread GNU-ld-script) -> "cannot find /lib64/libpthread.so.0".
# Appending keeps the build_env compiler first (correct sysroot) while host-only tools
# (root-config/rootcling) still resolve.
export PATH="$PATH:$PREFIX/bin"

# --- Wire-Cell discovery (larwirecell ships Modules/FindWireCell.cmake) ------
# It find_program(wire-cell) via $WIRECELL_FQ_DIR, finds WireCellApps/Main.h +
# libWireCell*.so, and derives the version from `wire-cell -v` (falling back to
# $WIRECELL_VERSION if the executable can't run in the sandbox).
export WIRECELL_FQ_DIR="$PREFIX"
export WIRECELL_VERSION="0.37.0"
# FindWireCell -> find_package(jsonnet) uses larwirecell's Find{,go}jsonnet, which
# locate the jsonnet exe / libjsonnet.h / libjsonnet via these env hints.
export JSONNET_FQ_DIR="$PREFIX"
export JSONNET_INC="$PREFIX/include"
export JSONNET_LIB="$PREFIX/lib"
export GOJSONNET_FQ_DIR="$PREFIX"
export GOJSONNET_INC="$PREFIX/include"
export GOJSONNET_LIB="$PREFIX/lib"

# generator env contracts re-exported transitively through larsim/larevt Configs
# (find_dependency GENIE/MARLEY/CRY/dk2nu*/...).
export RSTARTREE_INC="$PREFIX/include"
export MARLEY_FQ_DIR="$PREFIX"
export MARLEY_LIB="$PREFIX/lib"
export CRYHOME="$PREFIX"
export GENIE_INC="$PREFIX/include"
export GENIE_LIB="$PREFIX/lib"
export DK2NUGENIE_INC="$PREFIX/include"
export DK2NUDATA_INC="$PREFIX/include"
export LHAPDF_INC="$PREFIX/include"
export LOG4CPP_INC="$PREFIX/include"
export LOG4CPP_LIB="$PREFIX/lib"
export PYTHIA_INC="$PREFIX/include"
export LIBWDA_INC="$PREFIX/include"
export ROOT_INCLUDE_PATH="$PREFIX/include:$PREFIX/include/GENIE:${ROOT_INCLUDE_PATH:-}"

# drop WERROR (GCC 14 cautious diagnostics)
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' CMakeLists.txt

# lardataobj BitMask.tcc is a hard -Wtemplate-body error for all C++20 consumers
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

mkdir build && cd build
# CMAKE_IGNORE_PATH fftw3: cetmodules include() wrapper trips on conda's
# FFTW3Config (transitively via lardataConfig); pkg-config fallback works.
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
