#!/bin/bash
# cetlib: core utility library for the art suite (plugin/library management,
# filesystem/search-path helpers, MD5/SHA1/CRC, SQLite helpers). Links boost,
# SQLite3, OpenSSL and cetlib_except. Same cetmodules build pattern as the rest.
set -euo pipefail

mkdir -p build
cd build

# CMAKE_PREFIX_PATH=$PREFIX so find_package() resolves cetmodules + cetlib_except
# (local art-suite channel) and Boost/SQLite3/OpenSSL (conda-forge) from the host
# env. BUILD_TESTING=OFF -> skip the test/ subdir (the only Catch2 user).
# CMAKE_CXX_STANDARD=20: the e28 stack is C++20 (headers use concept/requires).
cmake \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DBUILD_TESTING=OFF \
  -DWANT_UPS:BOOL=OFF \
  "$SRC_DIR"

make -j"${CPU_COUNT:-1}" install

# Like cetmodules/cetlib_except, cetlib installs LICENSE/README as plain files at
# the PREFIX ROOT. $PREFIX/README (a file) collides with ROOT's $PREFIX/README/
# directory -- a file-vs-directory clash (ENOTDIR) when both land in one env at
# canvas_root_io (#7). Strip the stray prefix-root docs (license_file copies
# LICENSE from the SOURCE, so this does not affect it).
# See conda/potential_improvements.md (#7).
rm -f "$PREFIX/INSTALL" "$PREFIX/LICENSE" "$PREFIX/README"

# --- conda activation: art-suite runtime env (guided by FNALssi/fnal_art spack) --------
# FNAL art discovers its module/service/source/tool plugins via CET_PLUGIN_PATH (cetlib's
# LibraryManager); with it unset, `art -c job.fcl` fails ("Can't find an environment
# variable named LD_LIBRARY_PATH"). Perl-based cet tools use PERL5LIB (art ships
# $PREFIX/perllib). Set both on env activation so no consumer has to by hand.
#
# NOTE -- deliberate deviation from spack: spack sets run-time CET_PLUGIN_PATH in the
# plugin-PROVIDING packages (art, messagefacility, art_root_io) and PERL5LIB in
# art/cetlib/messagefacility, because each spack package lives in its own prefix. Conda
# installs the whole art/larsoft/dune stack into ONE $PREFIX, so we set
# CET_PLUGIN_PATH=$CONDA_PREFIX/lib ONCE here in cetlib (the lowest common dependency of
# everything art-based) instead of in three packages -- same effect (one shared plugin
# dir), simpler, and guaranteed present in any art-based env. ROOT_INCLUDE_PATH is handled
# separately in canvas_root_io (matching spack).
mkdir -p "$PREFIX/etc/conda/activate.d" "$PREFIX/etc/conda/deactivate.d"
cat > "$PREFIX/etc/conda/activate.d/cetlib.sh" <<'EOF'
export CET_PLUGIN_PATH="$CONDA_PREFIX/lib${CET_PLUGIN_PATH:+:$CET_PLUGIN_PATH}"
export PERL5LIB="$CONDA_PREFIX/perllib${PERL5LIB:+:$PERL5LIB}"
EOF
cat > "$PREFIX/etc/conda/deactivate.d/cetlib.sh" <<'EOF'
# Remove just our entry (preserve any pre-existing user value), not a blind unset.
_cet_path_remove() {
  _n="$1"; _rm="$2"; _out=""; eval "_cur=\${$_n:-}"
  _OIFS="$IFS"; IFS=":"
  for _e in $_cur; do [ "$_e" = "$_rm" ] || _out="${_out:+$_out:}$_e"; done
  IFS="$_OIFS"
  if [ -n "$_out" ]; then eval "export $_n=\"$_out\""; else unset "$_n"; fi
  unset _n _rm _out _cur _e _OIFS
}
_cet_path_remove CET_PLUGIN_PATH "$CONDA_PREFIX/lib"
_cet_path_remove PERL5LIB "$CONDA_PREFIX/perllib"
unset -f _cet_path_remove
EOF
