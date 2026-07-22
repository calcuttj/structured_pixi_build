# conda-forge issue draft: log4cpp over-links libnsl.so.3 (breaks on Python 3.13+)

Target repo: **conda-forge/log4cpp-feedstock**
Suggested title: **log4cpp over-links `libnsl.so.3` → runtime load failure in Python 3.13+ environments**

---

## Summary

The `log4cpp` package links `liblog4cpp.so` against `libnsl.so.3` even though log4cpp
uses **no symbols** from libnsl, and the recipe declares **no `libnsl` run
dependency**. This phantom `DT_NEEDED` was harmless while `libnsl` was pulled into
essentially every environment by CPython, but **Python 3.13 removed the `nis`
module (PEP 594)**, and with it the transitive `libnsl` dependency. In a Python
3.13+ environment nothing provides `libnsl.so.3`, so any executable that loads
`liblog4cpp` fails at startup:

```
error while loading shared libraries: libnsl.so.3: cannot open shared object file: No such file or directory
```

## Affected build

- `log4cpp 1.1.4`, build `h59595ed_0` (current linux-64), and any build produced with
  the stock feedstock `build.sh`.

## Root cause

log4cpp's `configure` runs `AC_CHECK_LIB(nsl, gethostbyname)`. On the conda-forge
build image the probe succeeds (sysroot provides libnsl), so `-lnsl` is appended to
the link line. log4cpp itself never calls a libnsl symbol, so the result is a phantom
`DT_NEEDED` entry with zero corresponding relocations.

## Evidence

`readelf -d liblog4cpp.so.5.0.6`:

```
# conda-forge build (h59595ed_0) — BROKEN
 NEEDED   libnsl.so.3        <-- phantom; no symbols used
 NEEDED   libstdc++.so.6
 NEEDED   libm.so.6
 NEEDED   libc.so.6
 NEEDED   libgcc_s.so.1

# rebuilt with the nsl probe disabled — FIXED
 NEEDED   libstdc++.so.6
 NEEDED   libm.so.6
 NEEDED   libc.so.6
 NEEDED   libgcc_s.so.1
```

Reproduce the runtime failure:

```bash
# any recent env WITHOUT an explicit libnsl (i.e. python >= 3.13)
conda create -n t -c conda-forge python=3.13 log4cpp
# then run anything linked against liblog4cpp, or:
readelf -d "$CONDA_PREFIX"/lib/liblog4cpp.so.5 | grep NEEDED   # shows libnsl.so.3
```

## Proposed fix (either one)

**Preferred — stop emitting the phantom link.** Disable the autoconf probe in
`build.sh` so `-lnsl` is never added:

```bash
export ac_cv_lib_nsl_gethostbyname=no
./configure --prefix="$PREFIX" --host="$HOST" --build="$BUILD"
```

This produces a `liblog4cpp.so` with no `libnsl` `DT_NEEDED` (see FIXED output above)
and does not change any functionality — log4cpp uses no libnsl symbols. Bump
`build: number` accordingly.

**Alternative — declare the dependency.** If keeping the link is preferred for some
platform, add `libnsl` to `requirements/run` (and `host`) so it is actually installed.
This is heavier (pulls libnsl into every consumer) and papers over an unused link, so
the probe-disable fix above is cleaner.

## Notes

- Local fix verified: rebuilding 1.1.4 with `ac_cv_lib_nsl_gethostbyname=no` yields the
  FIXED `readelf` output above and lets a downstream executable (`makeCAF`, DUNE
  ND_CAFMaker, which loads liblog4cpp via GENIE) start in a Python 3.13 environment.
- This is purely a link-line issue; no source patch is required.
