# Minimal CMake build for pythia6 (derived from the spack builtin pythia6
# recipe's CMakeLists.txt, with the example-driven test targets removed).
# The shipped Makefile is gfortran/Makefile specific and does not handle the
# +root interface sources, so we build the shared library ourselves.
cmake_minimum_required(VERSION 3.5)

project(pythia6 C Fortran)
message(STATUS "pythia version is ${PYTHIA6_VERSION}")

# build the library in a single directory
set(LIBRARY_OUTPUT_PATH ${PROJECT_BINARY_DIR}/lib)

# default GNU release flags; -fno-second-underscore keeps the Fortran symbol
# names matching what ROOT's TPythia6 / GENIE expect.
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG")
set(CMAKE_Fortran_FLAGS_RELEASE "-O3 -DNDEBUG -fno-second-underscore")

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# append the conda toolchain flags ($CFLAGS/$FFLAGS, incl. -fcommon)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} $ENV{CFLAGS}")
set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} $ENV{FFLAGS}")
message(STATUS "CMAKE_C_FLAGS = ${CMAKE_C_FLAGS}")
message(STATUS "CMAKE_Fortran_FLAGS = ${CMAKE_Fortran_FLAGS}")

# shared library from every C/Fortran source in the tree root (the +root glue
# files pythia6_common_address.c and tpythia6_called_from_cc.F are copied here
# by build.sh so they are picked up too). Example mains live under example/ and
# are intentionally excluded.
file(GLOB src_files *.c *.F *.f)
add_library(Pythia6 SHARED ${src_files})

# Installation. main60.f goes to include/ so NuSoftHEP nufinder's
# FindPythia6.cmake (which locates Pythia6 via main60.f under $PYTHIA_INC) and
# defines the Pythia6::Pythia6 imported target for consumers (nugen, etc.).
install(TARGETS Pythia6 DESTINATION lib)
install(FILES example/main60.f DESTINATION include)
