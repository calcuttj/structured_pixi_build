# Standalone build of ROOT's TPythia6 interface (libEGPythia6).
#
# ROOT REMOVED the montecarlo/pythia6 module after 6.28 (absent in 6.34/6.36),
# so conda-forge root_base 6.36 ships no libEGPythia6. GENIE and NuSoftHEP nugen
# still require it (ROOT::EGPythia6). We vendor the TPythia6 sources from ROOT
# v6-28-12 and compile them against our conda ROOT 6.36 + pythia6, reproducing
# libEGPythia6 (this is what the now-unavailable ShipSoft/TPythia6 repo did).
cmake_minimum_required(VERSION 3.12)
project(tpythia6 CXX)

find_package(ROOT REQUIRED COMPONENTS Core EG Graf Physics MathCore)
find_package(Pythia6 REQUIRED)   # nufinder FindPythia6 -> Pythia6::Pythia6

include(${ROOT_USE_FILE})

set(_inc ${CMAKE_CURRENT_SOURCE_DIR}/inc)
include_directories(${_inc})

# ROOT dictionary for the three persistent classes (LinkDef in inc/).
ROOT_GENERATE_DICTIONARY(G__EGPythia6
  TMCParticle.h TPythia6Calls.h TPythia6Decayer.h TPythia6.h
  MODULE EGPythia6
  LINKDEF ${_inc}/LinkDef.h)

add_library(EGPythia6 SHARED
  src/TMCParticle.cxx
  src/TPythia6.cxx
  src/TPythia6Decayer.cxx
  G__EGPythia6.cxx)

target_include_directories(EGPythia6 PUBLIC
  $<BUILD_INTERFACE:${_inc}>
  $<INSTALL_INTERFACE:include>
  ${ROOT_INCLUDE_DIRS})

# TPythia6.cxx calls the pythia6 fortran entry points (pyevnt_, pylist_, ...)
# and pythia6_common_address -- all provided by libPythia6 (built +root).
target_link_libraries(EGPythia6 PUBLIC ${ROOT_LIBRARIES} Pythia6::Pythia6)

install(TARGETS EGPythia6 LIBRARY DESTINATION lib)
install(FILES
  ${_inc}/TMCParticle.h ${_inc}/TPythia6Calls.h
  ${_inc}/TPythia6Decayer.h ${_inc}/TPythia6.h
  DESTINATION include)
# dictionary pcm + rootmap next to the library (ROOT autoloading)
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/libEGPythia6_rdict.pcm
  ${CMAKE_CURRENT_BINARY_DIR}/libEGPythia6.rootmap
  DESTINATION lib)
