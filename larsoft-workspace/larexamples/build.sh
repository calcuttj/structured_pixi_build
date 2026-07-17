#!/bin/bash
# larexamples: LArSoft examples/tutorial layer. cetmodules build above larsim.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# generator env contracts re-exported transitively through larsimConfig
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
# FFTW3Config (pulled transitively via lardataConfig); pkg-config fallback works.
# BUILD_TESTING=OFF also avoids compiling test/ (one test source lacks <cassert>).
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
