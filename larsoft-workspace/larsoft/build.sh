#!/bin/bash
# larsoft: top-level metapackage. "Empty product" cetmodules build that
# find_package()s the reco/display layer (lareventdisplay/larexamples/larana/
# larreco/larrecodnn/larpandora) + installs scripts/releaseDB + larsoftConfig.
# No compiled libraries. The find_package chain triggers the components' Config
# find_dependency()s, so we must supply the union of their env/-D contracts.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# generator env contracts (larreco/larsim/etc. Config find_dependency
# GENIE/MARLEY/CRY/dk2nu*/rstartree/libwda/...).
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

# libtorch: larpandora's Config re-exports Torch -> find_dependency(Torch) needs
# TorchConfig (force-located; CPU build was used).
TORCH_CFG="$(find "$PREFIX" -name TorchConfig.cmake 2>/dev/null | head -1)"
if [ -n "$TORCH_CFG" ]; then export Torch_DIR="$(dirname "$TORCH_CFG")"; fi

export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

# bin/python/ installs vestigial migration scripts into $PREFIX/bin/python, which
# collides with the `python` executable already at $PREFIX/bin/python ("is not a
# directory"). Drop that subdir (the scripts are decade-old larsoft upgrade aids,
# irrelevant to the conda metapackage).
sed -i '/add_subdirectory(python)/d' bin/CMakeLists.txt

mkdir build && cd build
# -DPandoraMonitoring_*: larpandoracontent's FindPandoraMonitoring REQUIRED_VARS
#   (re-reached via find_package(larpandora)). -DTorch_DIR: find_dependency(Torch).
#   -DCMAKE_IGNORE_PATH fftw3: lardataConfig find_dependency(FFTW3) clash.
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  -DPandoraMonitoring_INCLUDE_DIRS="$PREFIX/include" \
  -DPandoraMonitoring_LIBRARIES="$PREFIX/lib/libPandoraMonitoring.so" \
  ${Torch_DIR:+-DTorch_DIR="$Torch_DIR"} \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
