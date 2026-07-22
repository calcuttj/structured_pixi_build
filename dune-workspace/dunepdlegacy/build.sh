#!/bin/bash
# dunepdlegacy: port the legacy cetbuildtools build to cetmodules, then build.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# The CMakeLists appends $CANVAS_ROOT_IO_DIR/Modules and $ART_DIR/Modules to
# CMAKE_MODULE_PATH (UPS layout). Point them at $PREFIX so the expansion is sane;
# cetmodules' compat modules supply ArtDictionary/ArtMake/BuildPlugins regardless.
export CANVAS_ROOT_IO_DIR="$PREFIX"
export ART_DIR="$PREFIX"

cml="$SRC_DIR/CMakeLists.txt"
# 1) Use cetmodules (with its cetbuildtools compat shims) instead of cetbuildtools.
sed -i 's/find_package(cetbuildtools REQUIRED)/find_package(cetmodules REQUIRED)/' "$cml"
# 2) Drop the vestigial libsigc lookup (SIGC is never referenced by any target).
sed -i '/cet_find_library([[:space:]]*SIGC/d' "$cml"
# 3) Replace legacy find_ups_boost() (demands the full monolithic component list,
#    incl. header-only `system`, as REQUIRED — fails against modern conda Boost)
#    with a plain config-mode find_package(Boost). dunepdlegacy only uses Boost
#    headers (asio/crc); Overlays links ${Boost_SYSTEM_LIBRARY}, which is empty
#    under modern header-only Boost.System (a harmless no-op). Boost headers
#    resolve via $PREFIX/include on the default compiler search path.
sed -i 's/find_ups_boost()/find_package(Boost REQUIRED)/' "$cml"
# 4) Drop the ups/ subdir (process_ups_files() errors under WANT_UPS=OFF; UPS
#    table/tarball generation is irrelevant in conda) and test/ (needs the Boost
#    unit-test framework; BUILD_TESTING is OFF anyway).
sed -i '/add_subdirectory(ups)/d; /add_subdirectory(test)/d' "$cml"
# 5) The legacy cetbuildtools CMakeLists never calls cet_cmake_config(), so no
#    dunepdlegacyConfig.cmake / target exports get generated — but dunecore does
#    find_package(dunepdlegacy) and links dunepdlegacy::Overlays etc. Append
#    cet_cmake_config() (after all targets are defined) so cetmodules exports the
#    registered targets and installs lib/dunepdlegacy/cmake/dunepdlegacyConfig.cmake.
printf '\ncet_cmake_config()\n' >> "$cml"

mkdir -p build
cd build

cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DWANT_UPS:BOOL=OFF \
  -D_CheckClassVersion_ENABLED:BOOL=FALSE \
  -Ddunepdlegacy_FW_DIR=fw \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install
