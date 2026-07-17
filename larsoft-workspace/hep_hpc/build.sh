#!/bin/bash
# hep_hpc: self-contained CMake project (own CMakeModules; generates
# hep_hpcConfig.cmake via the ups/ subdir with WANT_UPS off). Build C++20, drop
# the upstream -Werror (GCC 14), and skip the test/examples subdirs (they pull in
# the bundled gtest); keep ups/ (it installs the CMake config) and hep_hpc/.
set -euo pipefail

# drop -Werror from add_compile_options
sed -i 's/ -Werror//' CMakeLists.txt
# skip test/examples (and the bundled gtest they need)
sed -i '/add_subdirectory(test)/d; /add_subdirectory(examples)/d; /add_subdirectory(gtest/d' CMakeLists.txt

# hep_hpc's cet_ensure_out_of_source_build() rejects a build dir *inside* the
# source tree, so build in a sibling dir outside $SRC_DIR.
mkdir -p "$SRC_DIR/../hep_hpc_build" && cd "$SRC_DIR/../hep_hpc_build"
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DCMAKE_BUILD_TYPE=Release \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
