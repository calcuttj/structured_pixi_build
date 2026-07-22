#!/bin/bash
# dunecore: large art/cetmodules build on the LArSoft stack + DUNE leaves.
# Reuses the larsoft-metapackage find_dependency contract (generator env block,
# libtorch-cpu Torch_DIR, PandoraMonitoring -D vars, FFTW3 CMAKE_IGNORE_PATH),
# plus WERROR drop + -fpermissive for the actual C++20 compile.
set -euo pipefail

export ROOTSYS="$PREFIX"
# Append (not prepend) host bin: we need host ROOT's root-config/rootcling (host-only),
# but prepending $PREFIX/bin also shadows the build compiler with the one root_base pulls
# into the HOST env (conda's $CC/$CXX are bare names). That host compiler's --sysroot then
# mismatches libs find_library locates in the BUILD sysroot (e.g. HDF5/OpenMP -lpthread, a
# GNU ld script with absolute /lib64 GROUP paths) -> "cannot find /lib64/libpthread.so.0"
# on a local (non-Docker) build. Appending keeps build tools first; find_package(ROOT)
# still selects host ROOT via CMAKE_PREFIX_PATH + ROOTSYS.
export PATH="$PATH:$PREFIX/bin"

# generator env contracts (larsim/larreco/nugen Config find_dependency of
# GENIE/MARLEY/CRY/dk2nu*/rstartree/libwda/log4cpp/lhapdf/pythia).
export RSTARTREE_INC="$PREFIX/include"
export MARLEY_FQ_DIR="$PREFIX"
export MARLEY_LIB="$PREFIX/lib"
export CRYHOME="$PREFIX"
export GENIE_INC="$PREFIX/include"
export GENIE_LIB="$PREFIX/lib"
export DK2NUGENIE_INC="$PREFIX/include"
export DK2NUDATA_INC="$PREFIX/include"
export LHAPDF_INC="$PREFIX/include"
export LOG4CPP_INC="$PREFIX/include"
export LOG4CPP_LIB="$PREFIX/lib"
export PYTHIA_INC="$PREFIX/include"
export LIBWDA_INC="$PREFIX/include"
export ROOT_INCLUDE_PATH="$PREFIX/include:$PREFIX/include/GENIE:${ROOT_INCLUDE_PATH:-}"

# libtorch: larpandora's Config re-exports Torch -> find_dependency(Torch) needs
# TorchConfig (CPU build pinned in host).
TORCH_CFG="$(find "$PREFIX" -name TorchConfig.cmake 2>/dev/null | head -1)"
if [ -n "$TORCH_CFG" ]; then export Torch_DIR="$(dirname "$TORCH_CFG")"; fi

# -fpermissive: lardataobj BitMask etc. under C++20 in downstream consumers.
# -include cassert: GCC-14 no longer transitively pulls <cassert> for assert().
export CXXFLAGS="${CXXFLAGS:-} -fpermissive -include cassert"

# dunereco calls the legacy UPS macro find_ups_product( dunepdlegacy ) (redundant — it
# already find_package(dunepdlegacy) above). Under WANT_UPS=OFF that macro path is
# unreliable; convert to a real (idempotent) find_package.
sed -i 's|^find_ups_product( *dunepdlegacy *)|find_package( dunepdlegacy REQUIRED EXPORT )|' "$SRC_DIR/CMakeLists.txt"

# dunereco/dunereco/Supera is the larcv2-backed DL-image (Supera) integration, kept as
# a git submodule that setup.sh turns into a CMakeLists at build time. The release
# tarball ships it EMPTY, so the submodule-init if()/endif() block + Supera/setup.sh
# execute_process + add_subdirectory(Supera) all fail. We build WITHOUT larcv2 (a
# runtime/optional external) -> delete the whole Supera block as a range (from the
# submodule-init `if ( NOT EXISTS .../Supera/.git )` through `add_subdirectory(Supera)`),
# so no dangling endif() is left behind.
sed -i '/if ( NOT EXISTS.*Supera\/\.git/,/add_subdirectory(Supera)/d' "$SRC_DIR/dunereco/CMakeLists.txt"

# ROOT-6.36 rootcling / fhiclcpp 4.19.0 coding.h fix (same as nuevdb/lareventdisplay):
# coding.h declares the "none of the above" encode<T> with a requires-clause but
# defines it with the `non_numeric` concept; ROOT 6.36 rootcling (clang concept
# normalisation) rejects the mismatch -> "out-of-line definition of 'encode' does
# not match any declaration" when a dunecore dictionary pulls in ParameterSet.h.
# Align the definition's constraint to the declaration (header-only, build-time).
_coding="$PREFIX/include/fhiclcpp/coding.h"
if grep -q '^template <fhicl::detail::non_numeric T> // none of the above' "$_coding"; then
  chmod u+w "$_coding"
  sed -i 's|^template <fhicl::detail::non_numeric T> // none of the above|template <class T> // none of the above\n  requires(!std::is_arithmetic_v<T>)|' "$_coding"
fi

# Drop WERROR (cet_set_compiler_flags DIAGS CAUTIOUS WERROR NO_UNDEFINED): the
# GCC-14 / C++20 warning set would otherwise fail the build.
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' "$SRC_DIR/CMakeLists.txt"

# conda-forge Boost >=1.90 dropped the boost_system component config (Boost.System
# is header-only now), so find_package(Boost REQUIRED COMPONENTS system) fails to
# find boost_system. dunecore never actually links Boost::system (the only
# reference is a commented-out MESSAGE); the request just pulls Boost in early.
# Drop the vestigial `system` component.
sed -i 's/Boost REQUIRED COMPONENTS system/Boost REQUIRED/' "$SRC_DIR/CMakeLists.txt"

# duneopdet's OpticalDetector/CMakeLists.txt links nlohmann_json::nlohmann_json but
# the top CMakeLists never find_package()s it (in UPS/mrb the imported target came
# in transitively via dunecore's table). In conda, dunecore's generated Config does
# NOT emit find_dependency(nlohmann_json), so the target is undefined when
# dunecoreTargets.cmake / duneopdet's own plugins reference it -> "target not found".
# Inject an explicit find_package(nlohmann_json) before find_package(dunecore).
if ! grep -q 'find_package.*nlohmann_json' "$SRC_DIR/CMakeLists.txt"; then
  sed -i 's|^find_package( dunecore REQUIRED EXPORT )|find_package( nlohmann_json REQUIRED )\nfind_package( dunecore REQUIRED EXPORT )|' "$SRC_DIR/CMakeLists.txt"
fi

mkdir -p build
cd build

# -DCMAKE_IGNORE_PATH fftw3: force cetmodules' FindFFTW3 module (conda's
#   lib/cmake/fftw3 config clashes). -DPandoraMonitoring_*: larpandoracontent's
#   FindPandoraMonitoring REQUIRED_VARS (re-reached via find_package(larpandora)).
#   -Ddunecore_GDML_DIR: install_gdml destination (avoid "vacuous destination").
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -D_CheckClassVersion_ENABLED:BOOL=FALSE \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  -Ddunecore_GDML_DIR=gdml \
  -DCMAKE_CXX_STANDARD_LIBRARIES="-lVc" \
  -DPandoraMonitoring_INCLUDE_DIRS="$PREFIX/include" \
  -DPandoraMonitoring_LIBRARIES="$PREFIX/lib/libPandoraMonitoring.so" \
  ${Torch_DIR:+-DTorch_DIR="$Torch_DIR"} \
  "$SRC_DIR"

make -j"${CPU_COUNT:-2}" install
