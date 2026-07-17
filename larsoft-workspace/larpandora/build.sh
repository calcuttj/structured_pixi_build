#!/bin/bash
# larpandora: LArSoft art interface to PandoraPFA. cetmodules build above
# larreco + larpandoracontent.
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

# libtorch ON: point find_package(Torch QUIET) at conda's TorchConfig.cmake so
# LARPANDORA_LIBTORCH turns on and larpandoracontent::LArPandoraDLContent links.
TORCH_CFG="$(find "$PREFIX" -name TorchConfig.cmake 2>/dev/null | head -1)"
if [ -n "$TORCH_CFG" ]; then
  export Torch_DIR="$(dirname "$TORCH_CFG")"
  echo "Using Torch_DIR=$Torch_DIR"
else
  echo "ERROR: TorchConfig.cmake not found under \$PREFIX" >&2; exit 1
fi

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
# - CMAKE_IGNORE_PATH fftw3: cetmodules include() wrapper trips on conda's
#   FFTW3Config (pulled transitively via lardataConfig); pkg-config fallback works.
# - larpandora_FW_DIR: one install_fw (a Pandora settings xml) → "vacuous
#   destination" without WANT_UPS (like larg4/lardataobj/larreco).
# - PandoraMonitoring_*: larpandoracontentConfig's find_dependency(PandoraMonitoring)
#   may route through larpandoracontent's FindPandoraMonitoring.cmake, whose
#   find_package_handle_standard_args REQUIRED_VARS need these (the modern
#   PandoraMonitoring config defines only the target). Harmless if CONFIG-mode
#   resolves it instead.
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  -Dlarpandora_FW_DIR=fw \
  -DPandoraMonitoring_INCLUDE_DIRS="$PREFIX/include" \
  -DPandoraMonitoring_LIBRARIES="$PREFIX/lib/libPandoraMonitoring.so" \
  -DTorch_DIR="$Torch_DIR" \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
