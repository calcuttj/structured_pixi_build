#!/bin/bash
# ND_CAFMaker 5.1.0 — conda build. The upstream CMake reads UPS env vars
# (cmake/FindUPSPackage.cmake) to locate each external; we point them all at the
# conda $PREFIX so find_ups_package / find_library resolve against the env.
set -euo pipefail

# Pin the host ROOT (rootcling / dictionary consumers) to $PREFIX.
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# UPS-style locators the top CMakeLists + FindUPSPackage.cmake consume. Every
# product is co-installed under $PREFIX, so *_INC=$PREFIX/include, *_LIB or
# *_LIBRARY=$PREFIX/lib, and *_FQ_DIR=$PREFIX.
export HDF5_INC="$PREFIX/include"
export HDF5_LIB="$PREFIX/lib"
export HDF5_FQ_DIR="$PREFIX"            # not a "debug" path -> selects hdf5_cpp
export LOG4CPP_INC="$PREFIX/include"
export LOG4CPP_LIB="$PREFIX/lib"
export GSL_LIB="$PREFIX/lib"
export LHAPDF_LIB="$PREFIX/lib"
export NLOHMANN_JSON_INC="$PREFIX/include"
export SRPROXY_INC="$PREFIX/include"    # #include <SRProxy/BasicTypesProxy.h>
# NB: $GENIE and $GENIE_FQ_DIR are exported by the genie package's activate.d (sourced
# by rattler-build during this build), so genie-config resolves without any genie-specific
# env here. -> $PREFIX/bin/genie-config, include/GENIE.
export LIBXML2_FQ_DIR="$PREFIX"
export PYTHIA6_LIBRARY="$PREFIX/lib"    # libPythia6.so + (patched) libEGPythia6.so
export SQLITE_FQ_DIR="$PREFIX"
export CURL_FQ_DIR="$PREFIX"            # patched curl block reads $CURL_FQ_DIR/{lib,include}

mkdir -p build-conda
cd build-conda

cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_TMS=ON \
  -DENABLE_TESTEXE=OFF \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}"
make install
