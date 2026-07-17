#!/bin/bash
# canvas_root_io: ROOT I/O + dictionaries for canvas (first ROOT-dependent
# product). Dictionaries are generated via art_dictionary() -> cetmodules
# build_dictionary -> rootcling. Same cetmodules build pattern; ROOT and the
# sibling closure resolve from the host env.
set -euo pipefail

mkdir -p build
cd build

# _CheckClassVersion_ENABLED=FALSE: skip cetmodules' post-dictionary
# checkClassVersion step. That step runs `import ROOT` (PyROOT/cppyy) to verify
# ClassDef checksums, but PyROOT's interpreter cannot initialize in the
# rattler-build sandbox ("cppyy.gbl has no attribute 'gSystem'" / no interpreter
# info for TFunction). The dictionaries themselves (rootcling .cxx + .pcm) build
# fine -- only this PyROOT *validation* fails -- so we disable it. cetmodules
# normally force-enables it because conda ROOT reports the pyroot feature.
# See conda/potential_improvements.md (#8).
# CMAKE_CXX_STANDARD=20: the e28 stack is C++20, and conda-forge ROOT is cxx20.
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

# Strip stray prefix-root docs the product itself installs. Guard with [ -f ]:
# ROOT is a host dep here, so $PREFIX/README is ROOT's *directory* -- a plain
# `rm -f $PREFIX/README` would hit EISDIR ("Is a directory") and abort under
# set -e. Only remove regular FILES (this product's own pollution), never the
# dependency's directory. See conda/potential_improvements.md (#7) and the
# check-prefix-collisions skill.
#for f in INSTALL LICENSE README; do
#  if [ -f "$PREFIX/$f" ]; then rm -f "$PREFIX/$f"; fi   # if/fi returns 0 even when absent (a bare `[ -f ] && rm` would exit 1 under set -e)
#done

# --- conda activation: ROOT_INCLUDE_PATH (guided by FNALssi/fnal_art spack) ------------
# canvas_root_io is the first ROOT-I/O product; art_root_io / larsoft data-product
# dictionaries rely on ROOT's cling autoparsing the installed headers at RUN time. spack's
# canvas_root_io sets ROOT_INCLUDE_PATH=<prefix>/include in its run environment; mirror
# that here so reading/writing art-ROOT files works without manual setup. (CET_PLUGIN_PATH
# + PERL5LIB are set once by cetlib -- see that recipe for the consolidation note.)
mkdir -p "$PREFIX/etc/conda/activate.d" "$PREFIX/etc/conda/deactivate.d"
cat > "$PREFIX/etc/conda/activate.d/canvas_root_io.sh" <<'EOF'
export ROOT_INCLUDE_PATH="$CONDA_PREFIX/include${ROOT_INCLUDE_PATH:+:$ROOT_INCLUDE_PATH}"
EOF
cat > "$PREFIX/etc/conda/deactivate.d/canvas_root_io.sh" <<'EOF'
# Remove just our entry (preserve any pre-existing user value), not a blind unset.
_cri_path_remove() {
  _n="$1"; _rm="$2"; _out=""; eval "_cur=\${$_n:-}"
  _OIFS="$IFS"; IFS=":"
  for _e in $_cur; do [ "$_e" = "$_rm" ] || _out="${_out:+$_out:}$_e"; done
  IFS="$_OIFS"
  if [ -n "$_out" ]; then eval "export $_n=\"$_out\""; else unset "$_n"; fi
  unset _n _rm _out _cur _e _OIFS
}
_cri_path_remove ROOT_INCLUDE_PATH "$CONDA_PREFIX/include"
unset -f _cri_path_remove
EOF
