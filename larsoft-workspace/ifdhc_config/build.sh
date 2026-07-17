#!/bin/bash
# ifdhc_config: the config half of fnal-fife/ifdhc -- just ifdh.cfg + a few
# shell scripts (no compilation). Kept separate from ifdhc so environments point
# at this package for these files (matches the spack ifdhc_config package).
set -euo pipefail

mkdir -p "$PREFIX/bin"
install -m 644 ifdh.cfg "$PREFIX/ifdh.cfg"
for s in www_cp auth_session decode_token; do
  install -m 755 "ifdh/${s}.sh" "$PREFIX/bin/${s}.sh"
done
