#!/bin/bash
# larg4: LArSoft Geant4 simulation layer (cetmodules, art plugins).
set -euo pipefail

# find_package(nusimdata) -> nusimdataConfig find_dependency(dk2nudata) ->
# nufinder's Finddk2nudata fallback looks for dk2nu.h under $DK2NUDATA_INC/dk2nu/tree.
export DK2NUDATA_INC="$PREFIX/include"
# larg4 compiles lardataobj headers (Utilities/BitMask.tcc), whose Bits_t::negate()
# use-before-declaration is a hard error under GCC 14 / C++20. -fpermissive demotes it
# (same as lardataobj/lardata/larevt).
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

mkdir -p build
cd build

# CMAKE_IGNORE_PATH: find_package(lardata) -> lardataConfig find_dependency(FFTW3);
# cetmodules' FindFFTW3 tries find_package(FFTW3 CONFIG) and conda's FFTW3Config.cmake
# trips cetmodules' include() wrapper ("OPTIONAL used twice"). Ignoring the fftw3
# cmake-config dir makes cetmodules use its pkg-config path instead.
# larg4_FW_DIR / larg4_GDML_DIR: cetmodules derives these install dests from the UPS
# product_deps (fwdir->G4, gdmldir->gdml) only under WANT_UPS; with UPS off they are
# empty and install_fw()/install_gdml() abort with "vacuous destination". Set them
# explicitly (same pattern as lardataobj_FW_DIR).
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  -Dlarg4_FW_DIR=G4 \
  -Dlarg4_GDML_DIR=gdml \
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
