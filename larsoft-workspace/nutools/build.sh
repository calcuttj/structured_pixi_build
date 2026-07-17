#!/bin/bash
# nutools: NuSoftHEP art tool/utility layer (EventGeneratorBase/CRY, etc.).
# cetmodules build.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
export CRYHOME="$PREFIX"                  # nufinder FindCRY (src/CRYSetup.h + lib/)
export DK2NUDATA_INC="$PREFIX/include"    # nusimdataConfig find_dependency(dk2nudata)

# drop WERROR (GCC 14 cautious diagnostics)
sed -i 's/DIAGS CAUTIOUS WERROR/DIAGS CAUTIOUS/' CMakeLists.txt

mkdir build && cd build
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
