#!/bin/bash
set -euo pipefail

# Pin the host ROOT (silences the benign dual-ROOT "LoadPCM does not exist"
# noise when a tool drags another ROOT into $BUILD_PREFIX).
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
# nufinder's FindPythia6.cmake locates pythia6 via main60.f under $PYTHIA_INC.
export PYTHIA_INC="$PREFIX/include"

cp "$RECIPE_DIR/CMakeLists.txt" .
cp -r "$RECIPE_DIR/src" "$RECIPE_DIR/inc" .

mkdir build && cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_MODULE_PATH="$PREFIX/Modules" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_BUILD_TYPE=Release
make -j"${CPU_COUNT:-2}"
make install

# --- consumer shim: ROOT::EGPythia6 -----------------------------------------
# GENIE / nugen / dk2nugenie / ppfx link the target `ROOT::EGPythia6`, a ROOT
# component conda ROOT 6.36 no longer provides (module removed upstream after
# 6.28). Install a tiny package config that defines that imported target against
# our libEGPythia6, so those recipes only need to drop EGPythia6 from their
# `find_package(ROOT COMPONENTS ...)` list and add `find_package(tpythia6)`.
mkdir -p "$PREFIX/lib/cmake/tpythia6"
cat > "$PREFIX/lib/cmake/tpythia6/tpythia6Config.cmake" <<'EOF'
# tpythia6: provides ROOT::EGPythia6 (libEGPythia6 rebuilt from ROOT 6.28 source)
get_filename_component(_tp6_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
if(NOT TARGET ROOT::EGPythia6)
  add_library(ROOT::EGPythia6 SHARED IMPORTED)
  set_target_properties(ROOT::EGPythia6 PROPERTIES
    IMPORTED_LOCATION "${_tp6_prefix}/lib/libEGPythia6.so"
    INTERFACE_INCLUDE_DIRECTORIES "${_tp6_prefix}/include")
endif()
set(tpythia6_FOUND TRUE)
EOF
