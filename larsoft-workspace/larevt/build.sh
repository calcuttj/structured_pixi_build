#!/bin/bash
# larevt: LArSoft calibration/conditions + event layer (cetmodules, art plugins).
set -euo pipefail

# find_package(nusimdata) -> find_dependency(dk2nudata) -> Finddk2nudata fallback.
export DK2NUDATA_INC="$PREFIX/include"
# find_package(libwda): cetmodules' Findlibwda locates wda.h via $LIBWDA_INC and
# builds the wda::wda imported target.
export LIBWDA_INC="$PREFIX/include"
# larevt compiles lardataobj RawData headers (Utilities/BitMask.tcc), whose
# Bits_t::negate() use-before-declaration is a hard error under GCC 14 / C++20.
# -fpermissive demotes it (same as lardataobj/lardata). See pot_impr / status doc.
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

mkdir -p build
cd build

# CMAKE_IGNORE_PATH: find_package(lardata) -> lardataConfig find_dependency(FFTW3);
# cetmodules' FindFFTW3 tries find_package(FFTW3 CONFIG) and conda's FFTW3Config.cmake
# trips cetmodules' include() wrapper ("OPTIONAL used twice"). Ignoring the fftw3
# cmake-config dir makes cetmodules use its pkg-config path instead.
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
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
