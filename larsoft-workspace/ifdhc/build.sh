#!/bin/bash
# ifdhc: the intensity-frontier data-handling client (fnal-fife/ifdhc). Custom
# multi-subdir Makefile build (util, numsg, ifdh). Installs into prefix/{bin,
# inc,lib} (NOTE: headers under inc/, not include/) + lib/python/ifdh.so.
set -euo pipefail

# patches (spack): drop the ../util/ relative prefix from installed-header
# includes so they resolve from inc/; strip the hardcoded -Werror in util.
sed -i -E 's@^([[:space:]]*#[[:space:]]*include[[:space:]]+["<])\.\./util/@\1@' \
  ifdh/ifdh.h numsg/numsg.h 2>/dev/null || true
sed -i 's/ -Werror//g' util/Makefile

PYINC=$(python3 -c 'import sysconfig; print(sysconfig.get_path("include"))')
PYMAJOR=$(python3 -c 'import sys; print(sys.version_info[0])')

# the config-file half lives in ifdhc_config
export IFDHC_CONFIG_DIR="$PREFIX"

# ARCH carries the C++ standard (match the stack) + uuid/conda include+lib paths.
make \
  SHELL=/bin/bash \
  PYMAJOR="$PYMAJOR" \
  PYTHON=python3 \
  PYTHON_LIB="$PREFIX/lib" \
  PYTHON_INCLUDE="$PYINC" \
  ARCH="-g -DNDEBUG -std=c++20 -L$PREFIX/lib -I$PREFIX/include" \
  all

# the Makefile install target keys off DESTDIR (needs the trailing slash)
make SHELL=/bin/bash DESTDIR="$PREFIX/" install

# www_cp / auth_session / decode_token belong to ifdhc_config; don't ship them here
for f in www_cp.sh auth_session.sh decode_token.sh; do
  rm -f "$PREFIX/bin/$f"
done
