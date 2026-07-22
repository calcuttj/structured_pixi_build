#!/bin/bash
# dune_pardata: install only the downloader + activation scripts (no data).
set -euo pipefail

mkdir -p "$PREFIX/bin" \
         "$PREFIX/etc/conda/activate.d" \
         "$PREFIX/etc/conda/deactivate.d"

# ---------------------------------------------------------------------------
# bin/dune_pardata-fetch : idempotent download + extract of the scisoft tarball.
# Quoted heredoc ('EOF') => nothing below is expanded at build time; the script
# resolves $DUNE_PARDATA_DIR / $CONDA_PREFIX at *run* time.
# ---------------------------------------------------------------------------
cat > "$PREFIX/bin/dune_pardata-fetch" <<'EOF'
#!/bin/bash
# Download + extract dune_pardata v01_84_00 (~2.7 GB) from scisoft.
# Destination: $DUNE_PARDATA_DIR (default $CONDA_PREFIX/share/dune_pardata).
# Idempotent: no-op if already installed, unless --force is given.
set -euo pipefail

VERSION="v01_84_00"
TARBALL="dune_pardata-01.84.00-noarch.tar.bz2"
URL="https://scisoft.fnal.gov/scisoft/packages/dune_pardata/${VERSION}/${TARBALL}"
EXPECTED_SIZE=2706080811

DEST="${DUNE_PARDATA_DIR:-${CONDA_PREFIX:-$PREFIX}/share/dune_pardata}"
MARKER="$DEST/.installed-${VERSION}"
# The tarball extracts to dune_pardata/v01_84_00/ (+ .version); that inner dir is
# what fcl/code reference relative to FW_SEARCH_PATH.
DATADIR="$DEST/dune_pardata/${VERSION}"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

if [ -f "$MARKER" ] && [ "$FORCE" -eq 0 ]; then
  echo "dune_pardata ${VERSION} already present at ${DATADIR} (use --force to re-download)."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "dune_pardata-fetch: 'curl' not found on PATH." >&2; exit 1
fi

mkdir -p "$DEST"
tmp="$(mktemp "${TMPDIR:-/tmp}/dune_pardata.XXXXXX.tar.bz2")"
trap 'rm -f "$tmp"' EXIT

echo "Downloading dune_pardata ${VERSION} (~2.7 GB) from:"
echo "  ${URL}"
curl -fL --retry 3 -o "$tmp" "$URL"

sz="$(wc -c < "$tmp")"
if [ "$sz" != "$EXPECTED_SIZE" ]; then
  echo "WARNING: downloaded size ${sz} != expected ${EXPECTED_SIZE}." >&2
fi

echo "Extracting into ${DEST} ..."
tar -xjf "$tmp" -C "$DEST"

if [ ! -d "$DATADIR" ]; then
  echo "dune_pardata-fetch: expected ${DATADIR} after extraction, not found." >&2
  exit 1
fi

touch "$MARKER"
echo "dune_pardata ready. Data dir (on FW_SEARCH_PATH after re-activation):"
echo "  ${DATADIR}"
EOF
chmod +x "$PREFIX/bin/dune_pardata-fetch"

# ---------------------------------------------------------------------------
# activate.d : always put the data dir on FW_SEARCH_PATH; nudge if not fetched.
# ---------------------------------------------------------------------------
cat > "$PREFIX/etc/conda/activate.d/dune_pardata.sh" <<'EOF'
# dune_pardata: expose the runtime data directory via FW_SEARCH_PATH.
export DUNE_PARDATA_DIR="${DUNE_PARDATA_DIR:-$CONDA_PREFIX/share/dune_pardata}"
_dpd_data="$DUNE_PARDATA_DIR/dune_pardata/v01_84_00"
case ":${FW_SEARCH_PATH:-}:" in
  *":$_dpd_data:"*) : ;;                                  # already present
  *) export FW_SEARCH_PATH="$_dpd_data${FW_SEARCH_PATH:+:$FW_SEARCH_PATH}" ;;
esac
if [ ! -f "$DUNE_PARDATA_DIR/.installed-v01_84_00" ]; then
  echo "[dune_pardata] runtime data (~2.7 GB) not present; run 'dune_pardata-fetch' to download it into $DUNE_PARDATA_DIR." >&2
fi
unset _dpd_data
EOF

# ---------------------------------------------------------------------------
# deactivate.d : remove the entry we prepended (best-effort).
# ---------------------------------------------------------------------------
cat > "$PREFIX/etc/conda/deactivate.d/dune_pardata.sh" <<'EOF'
# dune_pardata: remove our FW_SEARCH_PATH entry on deactivation.
if [ -n "${DUNE_PARDATA_DIR:-}" ]; then
  _dpd_data="$DUNE_PARDATA_DIR/dune_pardata/v01_84_00"
  if [ -n "${FW_SEARCH_PATH:-}" ]; then
    _dpd_new=":$FW_SEARCH_PATH:"
    _dpd_new="${_dpd_new//:$_dpd_data:/:}"
    _dpd_new="${_dpd_new#:}"; _dpd_new="${_dpd_new%:}"
    if [ -n "$_dpd_new" ]; then export FW_SEARCH_PATH="$_dpd_new"; else unset FW_SEARCH_PATH; fi
  fi
  unset _dpd_data _dpd_new
fi
EOF

# ---------------------------------------------------------------------------
# post-link : best-effort fetch at install. MUST always exit 0 (a non-zero
# post-link fails the whole conda install). Opt out with DUNE_PARDATA_AUTOFETCH=0.
# ---------------------------------------------------------------------------
cat > "$PREFIX/bin/.dune_pardata-post-link.sh" <<'EOF'
#!/bin/bash
# Best-effort: fetch the 2.7 GB data at install time. Never fail the install.
{
  if [ "${DUNE_PARDATA_AUTOFETCH:-1}" = "0" ]; then
    echo "[dune_pardata] auto-fetch disabled (DUNE_PARDATA_AUTOFETCH=0). Run 'dune_pardata-fetch' when ready."
  else
    echo "[dune_pardata] attempting to download runtime data (~2.7 GB). Set DUNE_PARDATA_AUTOFETCH=0 to skip."
    DUNE_PARDATA_DIR="${DUNE_PARDATA_DIR:-$PREFIX/share/dune_pardata}" \
      "$PREFIX/bin/dune_pardata-fetch" \
      || echo "[dune_pardata] download skipped/failed; run 'dune_pardata-fetch' manually later."
  fi
} >> "${PREFIX}/.messages.txt" 2>&1 || true
exit 0
EOF
chmod +x "$PREFIX/bin/.dune_pardata-post-link.sh"
