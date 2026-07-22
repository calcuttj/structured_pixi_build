#!/bin/bash
# dunecore: large art/cetmodules build on the LArSoft stack + DUNE leaves.
# Reuses the larsoft-metapackage find_dependency contract (generator env block,
# libtorch-cpu Torch_DIR, PandoraMonitoring -D vars, FFTW3 CMAKE_IGNORE_PATH),
# plus WERROR drop + -fpermissive for the actual C++20 compile.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

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
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

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

# dunetrigger's top CMakeLists uses the legacy UPS macro `find_ups_product(...)` for
# nlohmann_json and TRACE ("this seems to be deprecated but I can't find other working
# ways"). Under conda/cetmodules with WANT_UPS=OFF that does not create the imported
# targets its plugins link (nlohmann_json::nlohmann_json, TRACE via include path).
# Convert both to real find_package() calls: nlohmann_json ships a CONFIG, and our
# `trace` package installs lib/TRACE/cmake/TRACEConfig.cmake.
sed -i 's|^find_ups_product( *nlohmann_json *)|find_package( nlohmann_json REQUIRED )|' "$SRC_DIR/CMakeLists.txt"
sed -i 's|^find_ups_product( *TRACE *)|find_package( TRACE REQUIRED )|' "$SRC_DIR/CMakeLists.txt"

# dunetrigger adds ups/ unconditionally (unlike dunecore); ups/CMakeLists.txt calls
# process_ups_files() which errors under WANT_UPS=OFF. We don't generate UPS artifacts
# in conda -> drop the ups subdir (cetbuildtools->cetmodules port pattern).
sed -i '/^add_subdirectory( *ups *)/d' "$SRC_DIR/CMakeLists.txt"

# TriggerAna/TriggerAnaTree_module is a C++17-only analysis-tree module: its
# reflection (FieldNames.hh + {Scalar,Vector}FieldsBuffer.hh) relies on boost::pfr
# auto-derivation which, under our forced C++20, static-asserts ("Type must be
# aggregate initializable" / "does not support empty structs" / "REGISTER_FIELD_NAMES
# not needed in C++20") on non-aggregate row types (dunetrigger::MCTruthRow etc.).
# It is a self-contained analysis module — nothing else depends on it. Rather than
# delete it, the modernized TriggerAna/CMakeLists.txt (see patches/) simply does NOT
# emit a cet_build_plugin() for it, so the source stays in place for a future C++20
# boost::pfr port. (No `rm` here — the file is kept, just not compiled.)

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
