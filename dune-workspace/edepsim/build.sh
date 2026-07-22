#!/bin/bash
# edep-sim 3.2.0 — EDEPSIM_READONLY (io-only) build. Compiles just the io library
# (edepsim_io / EDepSim::edepsim_io) + its ROOT dictionary; skips display/, src/,
# app/ and Geant4 entirely.
set -euo pipefail

# Pin the host ROOT so rootcling picks up $PREFIX and doesn't emit benign
# "TCling::LoadPCM does not exist" noise from a second ROOT in the sandbox.
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# The top CMakeLists hard-codes `set(CMAKE_BUILD_TYPE Debug)`, which overrides
# -DCMAKE_BUILD_TYPE on the command line. Neutralize it so we ship an optimized
# (Release) io library rather than an unoptimized debug one.
sed -i 's/^set(CMAKE_BUILD_TYPE Debug)/# set(CMAKE_BUILD_TYPE Debug)  # neutralized by conda build.sh/' \
  "$SRC_DIR/CMakeLists.txt"

mkdir -p build-conda
cd build-conda

# EDEPSIM_READONLY=TRUE  -> only io/ is built; no Geant4, no src/app.
# EDEPSIM_DISPLAY=FALSE  -> skip the OpenGL edep-disp debug event display (an app).
# CMAKE_POLICY_VERSION_MINIMUM=3.5 -> source declares cmake_minimum_required(VERSION
#   3.0); CMake 4.x refuses <3.5 compatibility without this floor.
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_BUILD_TYPE=Release \
  -DEDEPSIM_READONLY=TRUE \
  -DEDEPSIM_DISPLAY=FALSE \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install
