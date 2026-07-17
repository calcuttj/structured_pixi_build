#!/bin/bash
# PandoraMonitoring: ROOT-based monitoring lib. Links PandoraSDK + ROOT
# (Eve/Geom/RGL/EG). Build C++20 (its CMakeLists hard-sets CXX_STANDARD 17 as a
# target property, which would override -DCMAKE_CXX_STANDARD; sed it to 20 to
# match the cxx20 conda ROOT it links) and drop the upstream -Werror.
set -euo pipefail

# Pin the host ROOT (silences benign dual-ROOT LoadPCM noise).
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# drop -Werror; force C++20 (the target property would otherwise pin 17)
sed -i '/-Werror/d' CMakeLists.txt
sed -i 's/CXX_STANDARD 17/CXX_STANDARD 20/' CMakeLists.txt

mkdir build && cd build
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DCMAKE_BUILD_TYPE=Release \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
