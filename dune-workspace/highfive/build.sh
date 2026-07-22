#!/bin/bash
# HighFive 2.4.1 — header-only install. No libraries compiled; cmake just
# configures H5Version.hpp, installs the headers, and generates the CMake config
# (HighFiveConfig.cmake -> share/HighFive/CMake).
set -euo pipefail

mkdir -p build
cd build

# HIGHFIVE_USE_BOOST=OFF: dunecore's vendored usage needs no Boost serialization,
#   and leaving it ON would inject a Boost find_dependency into consumers.
# UNIT_TESTS/EXAMPLES/DOCS OFF: nothing to compile/generate for a packaged header lib.
# HighFive 2.4.1 declares cmake_minimum_required(VERSION 3.1); CMake 4.x dropped
# compat with <3.5, so pin the policy version floor to configure it anyway.
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_BUILD_TYPE=Release \
  -DHIGHFIVE_USE_BOOST=OFF \
  -DHIGHFIVE_USE_EIGEN=OFF \
  -DHIGHFIVE_USE_XTENSOR=OFF \
  -DHIGHFIVE_USE_OPENCV=OFF \
  -DHIGHFIVE_UNIT_TESTS=OFF \
  -DHIGHFIVE_EXAMPLES=OFF \
  -DHIGHFIVE_BUILD_DOCS=OFF \
  -DHIGHFIVE_PARALLEL_HDF5=OFF \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install
