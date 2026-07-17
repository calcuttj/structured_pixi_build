# Building the art stack and publishing it as a conda channel

This directory builds the FNAL **art suite** (9 packages) from source in one
`pixi` workspace, then publishes the resulting `.conda` files as a local channel
that other workspaces can install from as ordinary binary dependencies.

```
structured_pixi_build/
├── art_workspace/     # the pixi-build workspace (builds all 9 from source)
│   ├── pixi.toml      #   [workspace] + all pins + the 9 members as path deps
│   ├── cetlib_except/ #   each member = staged recipe dir + thin pixi.toml
│   ├── cetlib/
│   └── ...            #   hep_concurrency, fhiclcpp, messagefacility, canvas,
│                      #   canvas_root_io, art, art_root_io
└── art-channel/       # the published channel (this file's subject)
    ├── linux-64/      #   the .conda files + repodata.json
    └── noarch/        #   (empty) + repodata.json
```

Build order (resolved automatically from the path-dep graph):

```
cetlib_except → cetlib → hep_concurrency → fhiclcpp → messagefacility
→ canvas → canvas_root_io → art → art_root_io
```

---

## 1. Build the stack

```bash
cd art_workspace
pixi install
```

`pixi install` builds every member from source in dependency order and installs
them into the workspace's default env. Each package's `.conda` lands in
`art_workspace/.pixi/bld/<pkg>/<hash>/output/linux-64/`.

### How pinning works (important)

The `pixi-build-rattler-build` backend **ignores** each recipe's adjacent
`conda_build_config.yaml`. Every pin therefore lives in one place — the root
`[workspace.build-variants]` table in `art_workspace/pixi.toml`:

```toml
[workspace.build-variants]
c_stdlib = ["sysroot"]
c_stdlib_version = ["2.17"]      # manylinux2014 baseline
libboost_devel = ["1.90"]        # match conda-forge geant4
libboost_headers = ["1.90"]
libboost_python_devel = ["1.90"]
root_base = ["6.36.6"]           # single value each → one combo, no zip_keys needed
root_cxx_standard = ["20"]
```

Notes:
- Pinning a variant key only works if that key is a **direct** dep of a recipe.
  `icu`/`libxml2` are *not* direct deps of any art recipe (they come in via
  `root_base`), so pinning them here is a **no-op** — this stack resolves whatever
  icu/libxml2 current conda-forge ships (presently icu 78 / libxml2 2.15).
- The per-member `conda_build_config.yaml` files were removed for this reason;
  they did nothing under pixi-build.

### Each member's `pixi.toml`

A thin shim — the recipe stays the source of truth for binary deps:

```toml
[package]
name = "cetlib"
version = "3.19.0"

[package.build]
backend = { name = "pixi-build-rattler-build", version = "0.*" }

[package.build.config]
extra-input-globs = ["build.sh", "patches/**"]   # recipe.yaml + source hashed by default

# inter-member SOURCE deps (every art sibling in the recipe's host: section);
# binary deps (cetmodules, boost, root_base, ...) stay in recipe.yaml only.
[package.host-dependencies]
cetlib_except = { path = "../cetlib_except" }
```

---

## 2. Publish + index the channel

A directory of `.conda` files is not usable until it has a `repodata.json`.

```bash
cd structured_pixi_build
CHANNEL=$(pwd)/art-channel      # absolute path to the channel

# (a) refresh the artifacts — clear stale build strings first, then copy the
#     current build-variant .conda files in
rm -f "$CHANNEL"/linux-64/*.conda
find art_workspace/.pixi/bld -path '*/output/linux-64/*.conda' \
     ! -name 'cetlib_except-1.10.0-ha35fb5c_0.conda' \
     -exec cp {} "$CHANNEL/linux-64/" \;

# (b) index it — `pixi exec` pulls conda-index into a throwaway env on demand,
#     so nothing has to be installed (no staged-recipes, no persistent env).
pixi exec --spec conda-index -- python -m conda_index "$CHANNEL"
```

- `pixi exec --spec <pkg> -- <cmd>` runs `<cmd>` in an ephemeral env with `<pkg>`
  installed; here conda-index brings its own python, so `python -m conda_index`
  just works. (If you'd rather keep it in-project, add
  `[dependencies] conda-index = "*"` to a dedicated feature/env and
  `pixi run -e <env> python -m conda_index "$CHANNEL"` instead.)
- The `! -name '...ha35fb5c_0...'` filter drops a **stale build-string
  duplicate** (an early cetlib_except built before the sysroot pin). Always clear
  `linux-64/*.conda` before copying so the solver can't pick an old build.
- Re-run both steps after any rebuild. Indexing is idempotent.

---

## 3. Consume it from another workspace

Reference the channel by **`file://` URL** (a bare path is treated as an
anaconda.org channel → 404) and depend on the packages normally:

```toml
[workspace]
channels = [
  "file:///abs/path/to/structured_pixi_build/art-channel",
  "conda-forge",
]
platforms = ["linux-64"]

[dependencies]
art_root_io = "*"    # pulls the whole stack transitively via run_exports
```

`pixi install` in that workspace pulls all 9 art packages from the local channel
(no rebuild); `root_base`, `libboost`, etc. come from conda-forge.

The channel is just a directory of `.conda` + `repodata.json`, so it can be
rsync'd to another machine or served over HTTP unchanged.

### Caveat: icu/libxml2

These binaries are built against **icu 78 / libxml2 2.15** (current conda-forge).
They resolve fine against current conda-forge but are **not co-installable** with
older stacks built on icu 75 / libxml2 2.14.
