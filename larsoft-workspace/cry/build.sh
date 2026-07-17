#!/bin/bash
# cry: LLNL cosmic-ray shower generator. Plain Makefile leaf (no external deps).
# install = the built source tree copied to $PREFIX (CRYHOME layout), as spack does.
set -euo pipefail

# spack cry_v1.7.patch: make CXX overridable + also build the shared libCRY.so
patch -p1 < "$RECIPE_DIR/cry_v1.7.patch"
# spack patch(): keep the test target finding the freshly built lib
sed -i 's@C test@C test LD_LIBRARY_PATH=../lib@' Makefile

# drop the hardcoded compiler so conda's $CXX is used; inject flags + C++ std
sed -i 's/^CXX = .*//' Makefile.common
cat > Makefile.local <<'EOF'
CXXFLAGS += -O3 -g -DNDEBUG -fno-omit-frame-pointer -fPIC \
            -std=c++20
EOF

make

# install the cry tree under $PREFIX (CRYHOME). Copy only real cry contents --
# $SRC_DIR is the work dir, so a blanket copy would also grab conda_build.sh.
rm -f src/*.o
mkdir -p "$PREFIX"
for item in lib src data doc interface geant cog mcnp mcnpx test \
            Makefile Makefile.common README Release_notes.txt \
            setup.sh setup.csh setup.create; do
  [ -e "$item" ] && cp -a "$item" "$PREFIX/"
done
