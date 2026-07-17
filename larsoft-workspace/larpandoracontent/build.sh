#!/bin/bash
# larpandoracontent: LArTPC Pandora algorithm content. cetmodules build,
# consuming the pandora externals (pandorasdk + pandoramonitoring).
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# libtorch ON: point find_package(Torch QUIET) at conda's TorchConfig.cmake
# (location varies: share/cmake/Torch or a site-packages torch dir). It is QUIET,
# so a miss would silently skip LArPandoraDLContent -- set Torch_DIR explicitly.
TORCH_CFG="$(find "$PREFIX" -name TorchConfig.cmake 2>/dev/null | head -1)"
if [ -n "$TORCH_CFG" ]; then
  export Torch_DIR="$(dirname "$TORCH_CFG")"
  echo "Using Torch_DIR=$Torch_DIR"
else
  echo "ERROR: TorchConfig.cmake not found under \$PREFIX" >&2; exit 1
fi

# drop WERROR (cet_set_compiler_flags WERROR in cetmodules_build.cmake; GCC 14)
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' cmake/cetmodules_build.cmake

mkdir build && cd build
# larpandoracontent's Modules/FindPandoraMonitoring.cmake passes the modern
# (target-only) PandoraMonitoring config through find_package_handle_standard_args
# with REQUIRED_VARS PandoraMonitoring_INCLUDE_DIRS/_LIBRARIES, which the config
# does not set. Supply them on the command line (the imported target itself comes
# from the config, so this only satisfies the FPHSA REQUIRED_VARS check).
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DPandoraMonitoring_INCLUDE_DIRS="$PREFIX/include" \
  -DPandoraMonitoring_LIBRARIES="$PREFIX/lib/libPandoraMonitoring.so" \
  -DTorch_DIR="$Torch_DIR" \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
