#!/bin/bash
# dunedetdataformats: prebuilt header-only distribution. No compile — just install
# the headers and the (relocatable, INTERFACE) CMake package config into $PREFIX.
# python/ and pybindsrc/ (pybind11 bindings) are intentionally NOT installed:
# dunecore's C++ find_package only needs the headers + CMake config.
set -euo pipefail

cp -r "$SRC_DIR/include" "$PREFIX/"
cp -r "$SRC_DIR/lib"     "$PREFIX/"
