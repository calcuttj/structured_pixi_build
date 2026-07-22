#!/bin/bash
# dunedaqdataformats: prebuilt header-only distribution. No compile — just install
# the headers and the (relocatable, INTERFACE) CMake package config into $PREFIX.
# python/ and pybindsrc/ (pybind11 bindings) are intentionally NOT installed:
# dunecore's C++ find_package only needs the headers + CMake config.
set -euo pipefail

# C++20 fix: older Fragment.hpp versions use
#   std::accumulate(..., [](auto& a, auto& b){ return a + b.second; })
# but C++20 std::accumulate MOVES the accumulator, so the non-const lvalue ref
# `auto& a` cannot bind to the resulting rvalue ("cannot bind non-const lvalue
# reference ... to an rvalue"). Take the accumulator by value (the newer v4_4_0
# header already uses `const size_t&`, which is fine and won't match).
find "$SRC_DIR/include" -name 'Fragment.hpp' -exec \
  sed -i 's/\[\](auto& a, auto& b)/[](auto a, const auto\& b)/g' {} +

cp -r "$SRC_DIR/include" "$PREFIX/"
cp -r "$SRC_DIR/lib"     "$PREFIX/"
