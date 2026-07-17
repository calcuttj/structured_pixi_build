#!/bin/bash
# larreco: LArSoft reconstruction layer. cetmodules build, directly above larsim
# on the trunk.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# rstartree: larreco's Modules/FindRStarTree.cmake locates the headers via
# RSTARTREE_INC -> <inc>/RStarTree/RStarTree.h.
export RSTARTREE_INC="$PREFIX/include"

# find-module env contracts re-exported transitively through larsimConfig
# (find_dependency GENIE/MARLEY/CRY/dk2nu*/...); same block as the larsim build.
export MARLEY_FQ_DIR="$PREFIX"            # FindMARLEY -> marley-config
export MARLEY_LIB="$PREFIX/lib"
export CRYHOME="$PREFIX"                   # FindCRY
export GENIE_INC="$PREFIX/include"         # FindGENIE
export GENIE_LIB="$PREFIX/lib"
export DK2NUGENIE_INC="$PREFIX/include"
export DK2NUDATA_INC="$PREFIX/include"
export LHAPDF_INC="$PREFIX/include"
export LOG4CPP_INC="$PREFIX/include"
export LOG4CPP_LIB="$PREFIX/lib"
export PYTHIA_INC="$PREFIX/include"
export LIBWDA_INC="$PREFIX/include"        # larevt consumer (Findlibwda)
# dictionary autoparsing needs the GENIE + dependency headers
export ROOT_INCLUDE_PATH="$PREFIX/include:$PREFIX/include/GENIE:${ROOT_INCLUDE_PATH:-}"

# drop WERROR (GCC 14 cautious diagnostics)
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' CMakeLists.txt

# oneTBB skew: conda-forge ships oneTBB, whose parallel_for(first,last,f) invokes
# the body with a prvalue index, so the two GausHitFinder loop bodies taking the
# index by non-const reference `[&](size_t& iter)` no longer bind. The indices
# are used read-only, so take them by value. (FNAL builds against an older TBB
# where this compiled.)
sed -i 's/\[&\](size_t& wireIter)/[\&](size_t wireIter)/' \
  larreco/HitFinder/GausHitFinder_module.cc
sed -i 's/\[&\](size_t& rangeIter)/[\&](size_t rangeIter)/' \
  larreco/HitFinder/GausHitFinder_module.cc

# lardataobj BitMask.tcc is a hard -Wtemplate-body error for all C++20 consumers
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

mkdir build && cd build
# CMAKE_IGNORE_PATH on the fftw3 config dir: cetmodules' include() wrapper trips
# on conda's FFTW3Config (pulled transitively via lardataConfig); the pkg-config
# fallback works.
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  -Dlarreco_FW_DIR=fw \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
