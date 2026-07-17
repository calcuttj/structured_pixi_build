#!/bin/bash
# rstartree: header-only R*-tree. Just install the three headers under
# include/RStarTree/ (matching the UPS product layout that larreco's
# FindRStarTree.cmake expects: RSTARTREE_INC -> <inc>/RStarTree/RStarTree.h).
set -euo pipefail

mkdir -p "$PREFIX/include/RStarTree"
cp RStarBoundingBox.h RStarTree.h RStarVisitor.h "$PREFIX/include/RStarTree/"
