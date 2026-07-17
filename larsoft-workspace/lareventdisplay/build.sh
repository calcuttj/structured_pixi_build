#!/bin/bash
# lareventdisplay: LArSoft event display. cetmodules build (ROOT dict via
# cet_rootcint) above larreco + nuevdb.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# generator env contracts re-exported transitively through larsim/larreco
# Configs (find_dependency GENIE/MARLEY/CRY/dk2nu*/...) + nuevdb (libwda/dk2nudata).
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

# --- ROOT-6.36 rootcling / fhiclcpp 4.19.0 coding.h fix (see nuevdb) --------
# The EventDisplay dictionary pulls in fhiclcpp/coding.h, whose "none of the
# above" encode<T> is declared with `requires(!std::is_arithmetic_v<T>)` but
# defined with the `non_numeric` concept; clang/cling rejects the mismatch. Align
# the definition to the declaration's requires-clause (header-only, build-time).
_coding="$PREFIX/include/fhiclcpp/coding.h"
if grep -q '^template <fhicl::detail::non_numeric T> // none of the above' "$_coding"; then
  chmod u+w "$_coding"
  sed -i 's|^template <fhicl::detail::non_numeric T> // none of the above|template <class T> // none of the above\n  requires(!std::is_arithmetic_v<T>)|' "$_coding"
  echo "patched fhiclcpp coding.h (non_numeric concept -> requires-clause) for rootcling"
fi

# drop WERROR (GCC 14 cautious diagnostics)
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' CMakeLists.txt

# lardataobj BitMask.tcc is a hard -Wtemplate-body error for all C++20 consumers
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

mkdir build && cd build
# CMAKE_IGNORE_PATH fftw3: cetmodules include() wrapper trips on conda's
# FFTW3Config (transitively via lardataConfig); pkg-config fallback works.
# _CheckClassVersion off: standard ROOT-dict guard (PyROOT can't init in sandbox).
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  -D_CheckClassVersion_ENABLED:BOOL=FALSE \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
