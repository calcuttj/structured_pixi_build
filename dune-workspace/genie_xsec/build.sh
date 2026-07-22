#!/bin/bash
# genie_xsec: install only the downloader + activation scripts (no data).
set -euo pipefail

mkdir -p "$PREFIX/bin" \
         "$PREFIX/etc/conda/activate.d" \
         "$PREFIX/etc/conda/deactivate.d"

# ---------------------------------------------------------------------------
# bin/genie_xsec-fetch : idempotent download + extract of the scisoft tarball.
# Quoted heredoc ('EOF') => resolved at RUN time, not build time.
# ---------------------------------------------------------------------------
cat > "$PREFIX/bin/genie_xsec-fetch" <<'EOF'
#!/bin/bash
# Download + extract the genie_xsec cross-section splines (~428 MB) from scisoft.
# Destination: $GENIE_XSEC_DIR (default $CONDA_PREFIX/share/genie_xsec).
# Idempotent: no-op if already installed, unless --force is given.
# Tune: override $GENIE_XSEC_TARBALL to select a different tune tarball.
set -euo pipefail

SCISOFT="https://scisoft.fnal.gov/scisoft/packages/genie_xsec/v3_06_00"
TARBALL="${GENIE_XSEC_TARBALL:-genie_xsec-3.06.00-noarch-AR2320i00000-k250-e1000.tar.bz2}"
URL="${SCISOFT}/${TARBALL}"
# integrity check (warning only) — matches the default AR23 tune.
EXPECTED_SIZE=448998203

DEST="${GENIE_XSEC_DIR:-${CONDA_PREFIX:-$PREFIX}/share/genie_xsec}"
# tarball extracts to genie_xsec/v3_06_00/NULL/<tune>/{data,ups}; derive the tune dir.
TUNE_DIR="$(printf '%s' "$TARBALL" | sed -E 's/^genie_xsec-3\.06\.00-noarch-//; s/\.tar\.bz2$//')"
PRODDIR="$DEST/genie_xsec/v3_06_00/NULL/${TUNE_DIR}"
MARKER="$DEST/.installed-${TUNE_DIR}"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

if [ -f "$MARKER" ] && [ "$FORCE" -eq 0 ]; then
  echo "genie_xsec (${TUNE_DIR}) already present at ${PRODDIR} (use --force to re-download)."
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "genie_xsec-fetch: 'curl' not found." >&2; exit 1; }

mkdir -p "$DEST"
tmp="$(mktemp "${TMPDIR:-/tmp}/genie_xsec.XXXXXX.tar.bz2")"
trap 'rm -f "$tmp"' EXIT

echo "Downloading genie_xsec (~428 MB) from:"
echo "  ${URL}"
curl -fL --retry 3 -o "$tmp" "$URL"

sz="$(wc -c < "$tmp")"
if [ "$TARBALL" = "genie_xsec-3.06.00-noarch-AR2320i00000-k250-e1000.tar.bz2" ] \
   && [ "$sz" != "$EXPECTED_SIZE" ]; then
  echo "WARNING: downloaded size ${sz} != expected ${EXPECTED_SIZE}." >&2
fi

echo "Extracting into ${DEST} ..."
tar -xjf "$tmp" -C "$DEST"

if [ ! -f "$PRODDIR/data/gxspl-NUsmall.xml" ]; then
  echo "genie_xsec-fetch: expected ${PRODDIR}/data/gxspl-NUsmall.xml after extraction, not found." >&2
  exit 1
fi

touch "$MARKER"
echo "genie_xsec ready. GENIEXSECFILE (after re-activation):"
echo "  ${PRODDIR}/data/gxspl-NUsmall.xml"
EOF
chmod +x "$PREFIX/bin/genie_xsec-fetch"

# ---------------------------------------------------------------------------
# activate.d : set the GENIE xsec env vars (mirror the UPS genie_xsec.table).
# ---------------------------------------------------------------------------
cat > "$PREFIX/etc/conda/activate.d/genie_xsec.sh" <<'EOF'
# genie_xsec: expose the cross-section spline data to GENIE.
export GENIE_XSEC_DIR="${GENIE_XSEC_DIR:-$CONDA_PREFIX/share/genie_xsec}"
_gx_tune="${GENIE_XSEC_TARBALL:-genie_xsec-3.06.00-noarch-AR2320i00000-k250-e1000.tar.bz2}"
_gx_tune="$(printf '%s' "$_gx_tune" | sed -E 's/^genie_xsec-3\.06\.00-noarch-//; s/\.tar\.bz2$//')"
_gx_prod="$GENIE_XSEC_DIR/genie_xsec/v3_06_00/NULL/${_gx_tune}"
export GENIEXSECPATH="$_gx_prod/data"
export GENIEXSECFILE="$_gx_prod/data/gxspl-NUsmall.xml"
export GENIE_XSEC_TUNE="AR23_20i_00_000"
export GENIE_XSEC_GENLIST="Default"
export GENIE_XSEC_KNOTS="250"
export GENIE_XSEC_EMAX="1000.0"
case ":${GXMLPATH:-}:" in
  *":$GENIEXSECPATH:"*) : ;;
  *) export GXMLPATH="$GENIEXSECPATH${GXMLPATH:+:$GXMLPATH}" ;;
esac
if [ ! -f "$GENIE_XSEC_DIR/.installed-${_gx_tune}" ]; then
  echo "[genie_xsec] splines (~428 MB) not present; run 'genie_xsec-fetch' to download into $GENIE_XSEC_DIR." >&2
fi
unset _gx_tune _gx_prod
EOF

# ---------------------------------------------------------------------------
# deactivate.d : drop our GXMLPATH entry + unset the vars we set (best-effort).
# ---------------------------------------------------------------------------
cat > "$PREFIX/etc/conda/deactivate.d/genie_xsec.sh" <<'EOF'
# genie_xsec: undo activation.
if [ -n "${GENIEXSECPATH:-}" ] && [ -n "${GXMLPATH:-}" ]; then
  _gx_new=":$GXMLPATH:"; _gx_new="${_gx_new//:$GENIEXSECPATH:/:}"
  _gx_new="${_gx_new#:}"; _gx_new="${_gx_new%:}"
  if [ -n "$_gx_new" ]; then export GXMLPATH="$_gx_new"; else unset GXMLPATH; fi
  unset _gx_new
fi
unset GENIEXSECPATH GENIEXSECFILE GENIE_XSEC_TUNE GENIE_XSEC_GENLIST GENIE_XSEC_KNOTS GENIE_XSEC_EMAX
EOF

# ---------------------------------------------------------------------------
# post-link : best-effort fetch at install. MUST always exit 0. Opt out with
# GENIE_XSEC_AUTOFETCH=0.
# ---------------------------------------------------------------------------
cat > "$PREFIX/bin/.genie_xsec-post-link.sh" <<'EOF'
#!/bin/bash
{
  if [ "${GENIE_XSEC_AUTOFETCH:-1}" = "0" ]; then
    echo "[genie_xsec] auto-fetch disabled (GENIE_XSEC_AUTOFETCH=0). Run 'genie_xsec-fetch' when ready."
  else
    echo "[genie_xsec] attempting to download cross-section splines (~428 MB). Set GENIE_XSEC_AUTOFETCH=0 to skip."
    GENIE_XSEC_DIR="${GENIE_XSEC_DIR:-$PREFIX/share/genie_xsec}" \
      "$PREFIX/bin/genie_xsec-fetch" \
      || echo "[genie_xsec] download skipped/failed; run 'genie_xsec-fetch' manually later."
  fi
} >> "${PREFIX}/.messages.txt" 2>&1 || true
exit 0
EOF
chmod +x "$PREFIX/bin/.genie_xsec-post-link.sh"
