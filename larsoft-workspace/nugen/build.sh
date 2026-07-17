#!/bin/bash
# nugen: NuSoftHEP generator interfaces to art for GENIE/GiBUU. cetmodules build.
set -euo pipefail

export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
# nufinder Find-module env contracts (find_file HINTS ENV ...):
export GENIE_INC="$PREFIX/include"        # FindGENIE: GENIE/Framework/Messenger/Messenger.h
export GENIE_LIB="$PREFIX/lib"
export DK2NUGENIE_INC="$PREFIX/include"   # Finddk2nugenie: dk2nu/genie/GDk2NuFlux.h
export DK2NUDATA_INC="$PREFIX/include"    # Finddk2nudata: dk2nu/tree/dk2nu.h
export LHAPDF_INC="$PREFIX/include"       # FindLHAPDF: LHAPDF/LHAPDF.h
export LOG4CPP_INC="$PREFIX/include"      # Findlog4cpp: log4cpp/LoggingEvent.hh
export PYTHIA_INC="$PREFIX/include"       # FindPythia6: main60.f
export LIBWDA_INC="$PREFIX/include"
# nugen builds ROOT dictionaries; cling needs the GENIE + dk2nu + nusimdata headers
export ROOT_INCLUDE_PATH="$PREFIX/include:$PREFIX/include/GENIE:${ROOT_INCLUDE_PATH:-}"

# --- option-B EGPythia6 contract ---------------------------------------------
# conda ROOT 6.36 dropped the pythia6 module, so the EGPythia6 ROOT component
# does not exist. Remove it from the ROOT COMPONENTS list and pull in our
# tpythia6 package, whose config defines the imported target ROOT::EGPythia6
# that nugen's 8 target_link_libraries lines reference.
sed -i 's/ EGPythia6//' CMakeLists.txt
sed -i '/find_package(ROOT COMPONENTS/a find_package(tpythia6 REQUIRED)' CMakeLists.txt

# drop WERROR (GCC 14 cautious diagnostics would fail this older code)
sed -i 's/DIAGS CAUTIOUS WERROR/DIAGS CAUTIOUS/' CMakeLists.txt

mkdir build && cd build
cmake \
  -DWANT_UPS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DIGNORE_ABSOLUTE_TRANSITIVE_DEPENDENCIES=ON \
  -DGENIE_INC="$PREFIX/include" \
  "$SRC_DIR"
make -j"${CPU_COUNT:-2}" install
