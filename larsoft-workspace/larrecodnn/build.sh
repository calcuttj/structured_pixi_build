#!/bin/bash
# larrecodnn: LArSoft DNN reco layer. cetmodules build. Core only (TF/Triton/
# Torch all off -> CVN/NuSonic/NuGraph skipped); requires hep_hpc + HDF5.
set -euo pipefail

export ROOTSYS="$PREFIX"
# Append (not prepend) host bin: we need host ROOT's root-config/rootcling (host-only),
# but prepending $PREFIX/bin also shadows the build compiler with the one root_base pulls
# into the HOST env (conda's $CC/$CXX are bare names). That host compiler's --sysroot then
# mismatches libs find_library locates in the BUILD sysroot (e.g. HDF5/OpenMP -lpthread, a
# GNU ld script with absolute /lib64 GROUP paths) -> "cannot find /lib64/libpthread.so.0"
# on a local (non-Docker) build. Appending keeps build tools first; find_package(ROOT)
# still selects host ROOT via CMAKE_PREFIX_PATH + ROOTSYS.
export PATH="$PATH:$PREFIX/bin"

# rstartree (via larreco) + the generator env contracts re-exported transitively
# through larsimConfig/larrecoConfig (find_dependency GENIE/MARLEY/CRY/dk2nu*/...).
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
