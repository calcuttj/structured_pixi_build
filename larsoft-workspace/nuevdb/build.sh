#!/bin/bash
# nuevdb: NuSoftHEP event-display base + IF conditions-DB interface (cetmodules,
# ROOT dict via build_dictionary). _CheckClassVersion off is the standard ROOT-dict
# guard (PyROOT can't init in the rattler-build sandbox; see pot_impr #8).
set -euo pipefail

# find_package(nusimdata) -> find_dependency(dk2nudata) -> nufinder Finddk2nudata
# fallback needs $DK2NUDATA_INC at the include root.
export DK2NUDATA_INC="$PREFIX/include"

# IFDatabase find_package(libwda): cetmodules' Findlibwda falls back to locating
# wda.h via $LIBWDA_INC, then derives lib/ and builds the wda::wda imported target.
export LIBWDA_INC="$PREFIX/include"

# --- ROOT-6.36 rootcling / fhiclcpp 4.19.0 coding.h fix --------------------
# coding.h DECLARES the "none of the above" encode<T> with a requires-clause
# (`requires(!std::is_arithmetic_v<T>)`) but DEFINES it with the `non_numeric`
# concept. clang's concept normalisation (in ROOT 6.36 rootcling) rejects the
# mismatch -> "out-of-line definition of 'encode' does not match any declaration"
# when the EventDisplayBase dictionary pulls in ParameterSet.h -> coding.h. GCC
# accepts it (fhiclcpp itself builds fine). Align the definition's constraint to
# the declaration's requires-clause so rootcling can match them (header-only,
# build-time only, no ABI change). Same fix is needed for lareventdisplay.
_coding="$PREFIX/include/fhiclcpp/coding.h"
if grep -q '^template <fhicl::detail::non_numeric T> // none of the above' "$_coding"; then
  chmod u+w "$_coding"
  sed -i 's|^template <fhicl::detail::non_numeric T> // none of the above|template <class T> // none of the above\n  requires(!std::is_arithmetic_v<T>)|' "$_coding"
  echo "patched fhiclcpp coding.h (non_numeric concept -> requires-clause) for rootcling"
fi

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
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install

# Strip stray prefix-root doc FILES only (guard [ -f ]; never ROOT's README dir).
for f in INSTALL LICENSE README; do
  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi
done
