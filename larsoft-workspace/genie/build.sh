#!/bin/bash
set -euo pipefail

# GENIE builds in-source ($GENIE/lib, $GENIE/bin) then `make install` copies to
# --prefix. It is a perl-configure + GNU make project (not cmake/autoconf).
export GENIE="$SRC_DIR"
export GENIE_REWEIGHT="$SRC_DIR/Reweight"
export GENIE_VERSION="v${PKG_VERSION//./_}"
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md
# in-source libs must be findable while the Reweight half links against them
export LD_LIBRARY_PATH="$SRC_DIR/lib:${LD_LIBRARY_PATH:-}"
# cling autoparsing (ROOT dict gen) needs the GENIE + dependency headers
export ROOT_INCLUDE_PATH="$SRC_DIR/src:$PREFIX/include:${ROOT_INCLUDE_PATH:-}"

# --- patches ----------------------------------------------------------------
# NOTE: spack applies GENIE-Generator.patch only for 3.04.00 (we build 3.06.02,
# which carries those fixes upstream) and root_subdir.patch only for spack's
# lib/root/ layout -- both are correctly SKIPPED here (conda root_base uses a
# flat lib/, so GENIE's stock $ROOTSYS/lib/libMathMore.so configure check works).
# drop -lnsl (not present / not needed on the conda sysroot)
sed -i 's/-lnsl//g' src/make/Make.include

# Reweight RwCalculators dictionary fix: GReWeightINuke.h / GReWeightUtils.h use
# genie::GHepParticle in function signatures but only the .cxx includes it. ROOT
# 6.36's stricter rootcling parses the headers standalone and errors ("unknown
# type name 'GHepParticle'"); ROOT 6.28 (what upstream/spack uses) was lax. Add
# the missing include so the dictionary parses.
for _h in GReWeightINuke.h GReWeightUtils.h; do
  _f="$SRC_DIR/Reweight/src/RwCalculators/$_h"
  grep -q 'Framework/GHEP/GHepParticle.h' "$_f" || \
    sed -i '/^#define _G_REWEIGHT.*_H_/a #include "Framework/GHEP/GHepParticle.h"' "$_f"
done

# --- configure --------------------------------------------------------------
# root-config (cxx20) drives the C++ standard, matching the art/larsoft stack.
# -lEGPythia6 (hardcoded in Make.include's ROOT_LIBRARIES) resolves from
# $PREFIX/lib via the tpythia6 package.
./configure \
  --prefix="$PREFIX" \
  --enable-rwght \
  --enable-fnal \
  --enable-atmo \
  --enable-event-server \
  --enable-nucleon-decay \
  --enable-nnbar-oscillation \
  --with-pythia6-lib="$PREFIX/lib" \
  --with-libxml2-inc="$PREFIX/include/libxml2" \
  --with-libxml2-lib="$PREFIX/lib" \
  --with-log4cpp-inc="$PREFIX/include" \
  --with-log4cpp-lib="$PREFIX/lib" \
  --with-optimiz-level=O3 \
  --enable-lhapdf6 \
  --with-lhapdf6-lib="$PREFIX/lib" \
  --with-lhapdf6-inc="$PREFIX/include"

# --- build (GENIE then the Reweight half) -----------------------------------
make
( cd "$GENIE_REWEIGHT" && make )

# --- install ----------------------------------------------------------------
mkdir -p "$PREFIX/bin" "$PREFIX/lib" "$PREFIX/include" "$PREFIX/src" \
         "$PREFIX/config" "$PREFIX/data"
make install
( cd "$GENIE_REWEIGHT" && make install )

# Runtime-required source trees (tunes/config, PDG data, build fragments +
# scripts) that GENIE consumers (and gen-config) expect under $GENIE.
cp -a src/scripts "$PREFIX/src/" 2>/dev/null || true
cp -a src/make    "$PREFIX/src/" 2>/dev/null || true
cp -a config/.    "$PREFIX/config/"
cp -a data/.      "$PREFIX/data/"

echo "${PKG_VERSION}" > "$PREFIX/VERSION"

# --- conda activation: set $GENIE / $GENIE_FQ_DIR (mirror the UPS genie.table) ----
# genie-config sources $GENIE/src/make/Make.config_no_paths and reads $GENIE/{lib,src},
# and other GENIE tools/consumers key off $GENIE / $GENIE_FQ_DIR (the UPS "flavor-
# qualified dir"). GENIE ships no CMake package, so downstreams reach it via genie-config
# -- which is useless without $GENIE. Export both on env activation so NO consumer has to
# set them by hand. rattler-build sources a host dependency's activate.d during a
# downstream build, so this fixes genie-config at BUILD time (every consuming recipe) as
# well as at runtime. $CONDA_PREFIX resolves to the genie prefix in both cases.
mkdir -p "$PREFIX/etc/conda/activate.d" "$PREFIX/etc/conda/deactivate.d"
cat > "$PREFIX/etc/conda/activate.d/genie.sh" <<'EOF'
export GENIE="$CONDA_PREFIX"
export GENIE_FQ_DIR="$CONDA_PREFIX"
EOF
cat > "$PREFIX/etc/conda/deactivate.d/genie.sh" <<'EOF'
unset GENIE
unset GENIE_FQ_DIR
EOF
