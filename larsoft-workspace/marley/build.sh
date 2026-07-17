#!/bin/bash
# MARLEY: Model of Argon Reaction Low Energy Yields. Makefile build in build/.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md   # gsl-config + root-config

# spack marley-1.2.1.patch: fix the install layout (data/react, data/structure,
# install marley-config) and drop the ldconfig calls.
patch -p1 < "$RECIPE_DIR/marley-1.2.1.patch"

# build at the art/larsoft C++ standard (matches root cxx20)
sed -i 's/CXX_STD=c++14/CXX_STD=c++20/' build/Makefile
export CPPFLAGS="${CPPFLAGS:-} -I../include"
export CXXFLAGS="${CXXFLAGS:-} -std=c++20"

cd build
make -j"${CPU_COUNT:-2}"
make prefix="$PREFIX" install
