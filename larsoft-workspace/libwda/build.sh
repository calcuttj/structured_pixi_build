#!/bin/bash
# libwda: Fermilab Web Data Access C library. Plain Makefile build (no cetmodules).
set -euo pipefail

cd src

# The tarball has no .git, so the Makefile's `wda_version.h` rule (guarded by
# `test -d ../.git ... || true`) silently produces no header and the compile fails
# on the missing include. Pre-create it; the FORCE rule then no-ops and leaves it.
# (Equivalent to the fnal_art spack version.patch, without patching the Makefile.)
echo '#define WDA_VERSION "wda_v2_30_0"' > wda_version.h

# Makefile hardcodes `gcc` in its recipes; route through conda's compiler.
sed -i 's/gcc/$(CC)/g' Makefile

# Build the shared lib + test. CXXFLAGS is the Makefile's C compile flag var; keep
# its -fPIC/-I. and add the conda prefix include/lib so libcurl/openssl resolve.
# LDFLAGS appends after -lcurl on the link line (so -lcrypto ordering is fine).
# parallel=False upstream -> -j1.
make CC="$CC" \
     CXXFLAGS="-fPIC -O3 -I. -I$PREFIX/include ${CFLAGS:-}" \
     LDFLAGS="-L$PREFIX/lib -lcrypto ${LDFLAGS:-}" \
     -j1 all

make PREFIX="$PREFIX" install
