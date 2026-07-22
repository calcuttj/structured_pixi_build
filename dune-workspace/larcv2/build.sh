#!/bin/bash
# larcv2: custom `source configure.sh && make` build (no CMake, no make install).
# Standalone package — nothing in the dunesw stack build-depends on it (dunereco's
# Supera/larcv2 integration is dropped). Builds liblarcv.so (+ROOT dict) and ships the
# `larcv` python package.
set -euo pipefail

# Pin the host ROOT for rootcling dict generation.
export ROOTSYS="$PREFIX"
export PATH="$PATH:$PREFIX/bin"  # append, not prepend: prepending shadows the build compiler root_base pulls into host_env -> sysroot mismatch breaks -lpthread; host-only tools (root-config/rootcling) still resolve. See PACKAGING_GOTCHAS.md

# larcv2 hardcodes -std=c++0x (C++11); ROOT 6.36 headers require >= C++17. Bump to
# c++17 (also add -include cassert/cstdint for GCC-14, which no longer pulls them in).
sed -i 's/-std=c++0x/-std=c++17 -include cassert -include cstdint/' "$SRC_DIR/Makefile/Makefile.Linux"

cd "$SRC_DIR"
# configure.sh sets the LARCV_* env (BASEDIR/BUILDDIR/LIBDIR/INCDIR, python, ROOT, numpy)
# and must be *sourced*. It references unbound vars (FORCE_LARCV_BASEDIR, OPENCV_INCDIR,
# ...) so disable `set -u` around it. It defaults LARCV_CXX to clang++/g++; override to
# conda's $CXX afterwards.
set +u
source ./configure.sh
set -u
export LARCV_CXX="$CXX"

make -j"${CPU_COUNT:-2}"

# --- manual install (no `make install`) ---------------------------------------
# liblarcv.so + its ROOT dict pcm/rootmap go in a DEDICATED dir: the larcv python
# __init__ gSystem.Load()s every *.so in $LARCV_LIBDIR, so it must not be $PREFIX/lib.
mkdir -p "$PREFIX/lib/larcv" "$PREFIX/include" "$PREFIX/etc/conda/activate.d" \
         "$PREFIX/etc/conda/deactivate.d"
cp -a "$LARCV_LIBDIR"/*.so "$PREFIX/lib/larcv/"
cp -a "$LARCV_LIBDIR"/*.pcm "$PREFIX/lib/larcv/" 2>/dev/null || true
cp -a "$LARCV_LIBDIR"/*.rootmap "$PREFIX/lib/larcv/" 2>/dev/null || true
cp -a "$LARCV_INCDIR"/. "$PREFIX/include/"

# the `larcv` python package (pure-python loader over the compiled lib).
SP="$($PREFIX/bin/python -c 'import site; print([p for p in site.getsitepackages() if p.endswith("site-packages")][0])')"
mkdir -p "$SP"
cp -a "$SRC_DIR/python/larcv" "$SP/"

# --- activation: larcv2's python __init__ requires these at runtime --------------
cat > "$PREFIX/etc/conda/activate.d/larcv2.sh" <<'EOF'
# larcv2: env required by the `larcv` python package (see larcv/__init__.py).
export LARCV_BASEDIR="${LARCV_BASEDIR:-$CONDA_PREFIX}"
export LARCV_LIBDIR="${LARCV_LIBDIR:-$CONDA_PREFIX/lib/larcv}"
export LARCV_INCDIR="${LARCV_INCDIR:-$CONDA_PREFIX/include}"
export LARCV_NUMPY=1
case ":${LD_LIBRARY_PATH:-}:" in
  *":$LARCV_LIBDIR:"*) : ;;
  *) export LD_LIBRARY_PATH="$LARCV_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
esac
EOF
cat > "$PREFIX/etc/conda/deactivate.d/larcv2.sh" <<'EOF'
if [ -n "${LARCV_LIBDIR:-}" ] && [ -n "${LD_LIBRARY_PATH:-}" ]; then
  _lc=":$LD_LIBRARY_PATH:"; _lc="${_lc//:$LARCV_LIBDIR:/:}"
  _lc="${_lc#:}"; _lc="${_lc%:}"
  if [ -n "$_lc" ]; then export LD_LIBRARY_PATH="$_lc"; else unset LD_LIBRARY_PATH; fi
  unset _lc
fi
unset LARCV_BASEDIR LARCV_LIBDIR LARCV_INCDIR LARCV_NUMPY
EOF
