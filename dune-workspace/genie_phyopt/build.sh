#!/bin/bash
# genie_phyopt: install only the downloader + activation scripts (no data).
set -euo pipefail

mkdir -p "$PREFIX/bin" \
         "$PREFIX/etc/conda/activate.d" \
         "$PREFIX/etc/conda/deactivate.d"

# ---------------------------------------------------------------------------
# bin/genie_phyopt-fetch : idempotent download + extract of the scisoft tarball.
# ---------------------------------------------------------------------------
cat > "$PREFIX/bin/genie_phyopt-fetch" <<'EOF'
#!/bin/bash
# Download + extract the genie_phyopt physics-option data (~4 KB) from scisoft.
# Destination: $GENIE_PHYOPT_DIR (default $CONDA_PREFIX/share/genie_phyopt).
# Idempotent: no-op if already installed, unless --force is given.
# Variant: override $GENIE_PHYOPT_TARBALL to select a different variant tarball.
set -euo pipefail

SCISOFT="https://scisoft.fnal.gov/scisoft/packages/genie_phyopt/v3_06_00"
TARBALL="${GENIE_PHYOPT_TARBALL:-genie_phyopt-3.06.00-noarch-dkcharm.tar.bz2}"
URL="${SCISOFT}/${TARBALL}"
EXPECTED_SIZE=4090

DEST="${GENIE_PHYOPT_DIR:-${CONDA_PREFIX:-$PREFIX}/share/genie_phyopt}"
# tarball extracts to genie_phyopt/v3_06_00/NULL/<variant>/; derive the variant dir.
VAR_DIR="$(printf '%s' "$TARBALL" | sed -E 's/^genie_phyopt-3\.06\.00-noarch-//; s/\.tar\.bz2$//')"
PRODDIR="$DEST/genie_phyopt/v3_06_00/NULL/${VAR_DIR}"
MARKER="$DEST/.installed-${VAR_DIR}"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

if [ -f "$MARKER" ] && [ "$FORCE" -eq 0 ]; then
  echo "genie_phyopt (${VAR_DIR}) already present at ${PRODDIR} (use --force to re-download)."
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "genie_phyopt-fetch: 'curl' not found." >&2; exit 1; }

mkdir -p "$DEST"
tmp="$(mktemp "${TMPDIR:-/tmp}/genie_phyopt.XXXXXX.tar.bz2")"
trap 'rm -f "$tmp"' EXIT

echo "Downloading genie_phyopt from:"
echo "  ${URL}"
curl -fL --retry 3 -o "$tmp" "$URL"

sz="$(wc -c < "$tmp")"
if [ "$TARBALL" = "genie_phyopt-3.06.00-noarch-dkcharm.tar.bz2" ] && [ "$sz" != "$EXPECTED_SIZE" ]; then
  echo "WARNING: downloaded size ${sz} != expected ${EXPECTED_SIZE}." >&2
fi

echo "Extracting into ${DEST} ..."
tar -xjf "$tmp" -C "$DEST"

if [ ! -d "$PRODDIR" ]; then
  echo "genie_phyopt-fetch: expected ${PRODDIR} after extraction, not found." >&2
  exit 1
fi

touch "$MARKER"
echo "genie_phyopt ready. GENIEPHYOPTPATH (after re-activation):"
echo "  ${PRODDIR}"
EOF
chmod +x "$PREFIX/bin/genie_phyopt-fetch"

# ---------------------------------------------------------------------------
# activate.d : set the GENIE phyopt env vars (mirror the UPS genie_phyopt.table).
# ---------------------------------------------------------------------------
cat > "$PREFIX/etc/conda/activate.d/genie_phyopt.sh" <<'EOF'
# genie_phyopt: expose the physics-option data to GENIE.
export GENIE_PHYOPT_DIR="${GENIE_PHYOPT_DIR:-$CONDA_PREFIX/share/genie_phyopt}"
_gp_var="${GENIE_PHYOPT_TARBALL:-genie_phyopt-3.06.00-noarch-dkcharm.tar.bz2}"
_gp_var="$(printf '%s' "$_gp_var" | sed -E 's/^genie_phyopt-3\.06\.00-noarch-//; s/\.tar\.bz2$//')"
_gp_prod="$GENIE_PHYOPT_DIR/genie_phyopt/v3_06_00/NULL/${_gp_var}"
export GENIEPHYOPTPATH="$_gp_prod"
export GENIE_PHYOPT_VARIANT="$_gp_var"
case ":${GXMLPATH:-}:" in
  *":$_gp_prod:"*) : ;;
  *) export GXMLPATH="${GXMLPATH:+$GXMLPATH:}$_gp_prod" ;;
esac
if [ ! -f "$GENIE_PHYOPT_DIR/.installed-${_gp_var}" ]; then
  echo "[genie_phyopt] data not present; run 'genie_phyopt-fetch' to download into $GENIE_PHYOPT_DIR." >&2
fi
unset _gp_var _gp_prod
EOF

# ---------------------------------------------------------------------------
# deactivate.d : drop our GXMLPATH entry + unset vars (best-effort).
# ---------------------------------------------------------------------------
cat > "$PREFIX/etc/conda/deactivate.d/genie_phyopt.sh" <<'EOF'
# genie_phyopt: undo activation.
if [ -n "${GENIEPHYOPTPATH:-}" ] && [ -n "${GXMLPATH:-}" ]; then
  _gp_new=":$GXMLPATH:"; _gp_new="${_gp_new//:$GENIEPHYOPTPATH:/:}"
  _gp_new="${_gp_new#:}"; _gp_new="${_gp_new%:}"
  if [ -n "$_gp_new" ]; then export GXMLPATH="$_gp_new"; else unset GXMLPATH; fi
  unset _gp_new
fi
unset GENIEPHYOPTPATH GENIE_PHYOPT_VARIANT
EOF

# ---------------------------------------------------------------------------
# post-link : best-effort fetch at install. MUST always exit 0. Opt out with
# GENIE_PHYOPT_AUTOFETCH=0.
# ---------------------------------------------------------------------------
cat > "$PREFIX/bin/.genie_phyopt-post-link.sh" <<'EOF'
#!/bin/bash
{
  if [ "${GENIE_PHYOPT_AUTOFETCH:-1}" = "0" ]; then
    echo "[genie_phyopt] auto-fetch disabled (GENIE_PHYOPT_AUTOFETCH=0). Run 'genie_phyopt-fetch' when ready."
  else
    echo "[genie_phyopt] attempting to download physics-option data. Set GENIE_PHYOPT_AUTOFETCH=0 to skip."
    GENIE_PHYOPT_DIR="${GENIE_PHYOPT_DIR:-$PREFIX/share/genie_phyopt}" \
      "$PREFIX/bin/genie_phyopt-fetch" \
      || echo "[genie_phyopt] download skipped/failed; run 'genie_phyopt-fetch' manually later."
  fi
} >> "${PREFIX}/.messages.txt" 2>&1 || true
exit 0
EOF
chmod +x "$PREFIX/bin/.genie_phyopt-post-link.sh"
