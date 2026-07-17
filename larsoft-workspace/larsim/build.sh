#!/bin/bash
# larsim: LArSoft simulation layer. cetmodules build. The big trunk milestone --
# all of its hard-REQUIRED externals (genie/marley/cry/nugen/nutools/ppfx/...) are
# now green.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
# find-module env contracts (larsim Modules/FindMARLEY + nufinder/nugen/nutools):
export MARLEY_FQ_DIR="$PREFIX"            # FindMARLEY -> marley-config
export MARLEY_LIB="$PREFIX/lib"
export CRYHOME="$PREFIX"                   # FindCRY
export GENIE_INC="$PREFIX/include"         # FindGENIE
export GENIE_LIB="$PREFIX/lib"
export DK2NUGENIE_INC="$PREFIX/include"
export DK2NUDATA_INC="$PREFIX/include"
export LHAPDF_INC="$PREFIX/include"
export LOG4CPP_INC="$PREFIX/include"
export LOG4CPP_LIB="$PREFIX/lib"
export PYTHIA_INC="$PREFIX/include"
export LIBWDA_INC="$PREFIX/include"
# dictionary autoparsing needs the GENIE + dependency headers
export ROOT_INCLUDE_PATH="$PREFIX/include:$PREFIX/include/GENIE:${ROOT_INCLUDE_PATH:-}"

# drop WERROR (GCC 14 cautious diagnostics)
sed -i '/^[[:space:]]*WERROR[[:space:]]*$/d' CMakeLists.txt

# lardataobj BitMask.tcc is a hard -Wtemplate-body error for all C++20 consumers
export CXXFLAGS="${CXXFLAGS:-} -fpermissive"

# --- Re-supply RooInt (ROOT removed the RooFitCore RooInt class after 6.28) -
# larsim/PhotonPropagation/PhotonLibrary.cxx still #include "RooInt.h" and
# stores photon-library voxel metadata (NVoxels/NChannels/NDivX/Y/Z) as RooInt
# objects in the library ROOT file (RooDouble, used identically for the float
# metadata, still ships in 6.36). Drop a verbatim 6.28 RooInt header next to
# PhotonLibrary.cxx (its existing same-dir `#include "RooInt.h"` then resolves
# to ours) and generate a ROOT dictionary so the class can be written/read.
cp "$RECIPE_DIR/rooint/RooInt.h" \
   "$RECIPE_DIR/rooint/classes.h" \
   "$RECIPE_DIR/rooint/classes_def.xml" \
   larsim/PhotonPropagation/
cat >> larsim/PhotonPropagation/CMakeLists.txt <<'EOF'

# --- conda: vendored RooInt dictionary (see RooInt.h) -----------------------
build_dictionary(larsim_PhotonPropagation_RooInt
  NO_CHECK_CLASS_VERSION
  DICTIONARY_LIBRARIES ROOT::RIO ROOT::Core
  )
target_link_libraries(larsim_PhotonPropagation PRIVATE larsim_PhotonPropagation_RooInt_dict)
EOF

mkdir build && cd build
# CMAKE_IGNORE_PATH on the fftw3 config dir: cetmodules' include() wrapper trips
# on conda's FFTW3Config (pulled transitively via lardataConfig); the pkg-config
# fallback works.
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DCMAKE_IGNORE_PATH="$PREFIX/lib/cmake/fftw3" \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
