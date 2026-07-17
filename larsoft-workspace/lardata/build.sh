#!/bin/bash
# lardata: LArSoft data-access / utilities layer (cetmodules, art plugins, dicts).
# _CheckClassVersion off is the standard ROOT-dict guard (PyROOT can't init in the
# rattler-build sandbox; see conda/potential_improvements.md #8).
set -euo pipefail

# find_package(lardataalg) -> find_dependency(nusimdata) -> find_dependency(dk2nudata)
# -> nufinder Finddk2nudata.cmake fallback needs $DK2NUDATA_INC at the include root.
export DK2NUDATA_INC="$PREFIX/include"

# lardata compiles code including the INSTALLED lardataobj header
# Utilities/BitMask.tcc, whose Bits_t::negate() use-before-declaration is a hard
# error under GCC 14 / C++20 (-Wtemplate-body) — the same issue lardataobj's own
# build hit. -fpermissive demotes it to a warning. (Affects every C++20 consumer
# of lardataobj/BitMask; a future lardataobj header patch would remove the need.)
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

mkdir -p build
cd build

# CMAKE_IGNORE_PATH: cetmodules' FindFFTW3 first tries find_package(FFTW3 CONFIG),
# which loads conda-forge's FFTW3Config.cmake; that file's
# include("...FFTW3LibraryDepends.cmake" OPTIONAL) trips cetmodules' overridden
# include() ("OPTIONAL used twice", a hard configure error). Telling CMake to ignore
# the fftw3 cmake-config dir makes the CONFIG probe miss, so cetmodules falls back to
# its pkg-config path (resolves fftw3 cleanly). Purely declarative — no prefix edits.
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
