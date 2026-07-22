#!/usr/bin/env python3
"""Harvest pixi-built source packages into a local conda channel directory.

A pixi-build workspace resolves some packages from source (the workspace members);
in pixi.lock these appear as `conda_source` entries, e.g.

    - conda_source: dunecore[6dc97326] @ dunecore

(as opposed to channel binaries, which are `conda:` entries pointing at a
.conda url/path). This script reads a pixi.lock, collects every `conda_source`
package, locates the `.conda` that pixi built for it under the workspace
`.pixi/bld/` tree, and copies it into an output channel directory (preserving the
`linux-64/` vs `noarch/` subdir). It does NOT index -- run your conda indexer
afterwards (the exact command is printed at the end).

Key facts this relies on (verified against pixi.lock v7 / pixi 0.71):
  * The built artifact lives at
        <bld-root>/<package-name>/<hash>/output/<subdir>/<package-name>-<ver>-<build>.conda
    keyed by the PACKAGE NAME (the token before `[` in the conda_source value),
    NOT the member/source directory after `@`. So two members that build the same
    package name at different versions (e.g. duneanaobj 3.16.0 and 4.0.0) both land
    under <bld-root>/duneanaobj/ and are distinguished only by the output filename.
  * Only successful builds have an output/ subdir, so globbing output/ naturally
    skips failed attempts. When a name has several outputs, we keep the NEWEST
    build per (subdir, version) -- dropping stale rebuilds of the same version
    while keeping genuinely distinct versions.

Usage:
    ./harvest-conda-source.py <pixi.lock> -o <output-channel-dir> [options]

Examples:
    # Harvest every source package in the lock into ./dune-channel
    ./harvest-conda-source.py dune-workspace/pixi.lock -o dune-channel

    # Only the packages belonging to one environment, wiping stale files first
    ./harvest-conda-source.py dune-workspace/pixi.lock -o ndcaf-channel \\
        --environment ndcaf --clean

    # See what would happen without touching anything
    ./harvest-conda-source.py dune-workspace/pixi.lock -o dune-channel -n
"""
from __future__ import annotations

import argparse
import glob
import os
import shutil
import sys

import yaml


def _name_of(conda_source_value: str) -> str:
    """'dunecore[6dc97326] @ dunecore' -> 'dunecore' (the package name)."""
    return conda_source_value.split("[", 1)[0].strip()


def parse_source_names(lock: dict, environment: str | None) -> list[str]:
    """Return the sorted, de-duplicated conda_source package names.

    Without --environment: the top-level `packages:` list = every source package
    the lock knows about. With --environment: only the packages listed under
    `environments.<env>.packages.<platform>`.
    """
    names: set[str] = set()

    if environment is None:
        for entry in lock.get("packages", []):
            if isinstance(entry, dict) and "conda_source" in entry:
                names.add(_name_of(entry["conda_source"]))
        return sorted(names)

    envs = lock.get("environments", {})
    if environment not in envs:
        print(f"error: environment '{environment}' not in lock "
              f"(have: {', '.join(sorted(envs)) or 'none'})", file=sys.stderr)
        return []
    packages_by_platform = envs[environment].get("packages", {})
    for _platform, entries in packages_by_platform.items():
        for entry in entries or []:
            if isinstance(entry, dict) and "conda_source" in entry:
                names.add(_name_of(entry["conda_source"]))
    return sorted(names)


def find_builds(bld_root: str, name: str) -> list[tuple[str, str, str]]:
    """Locate built .conda for a package name.

    Returns (subdir, version, path) for the newest build per (subdir, version).
    subdir is 'linux-64' or 'noarch'.
    """
    pattern = os.path.join(bld_root, name, "*", "output", "*", f"{name}-*.conda")
    newest: dict[tuple[str, str], tuple[str, float]] = {}
    for path in glob.glob(pattern):
        fname = os.path.basename(path)
        subdir = os.path.basename(os.path.dirname(path))
        # filename = <name>-<version>-<build>.conda ; name is known, so strip it.
        rest = fname[len(name) + 1 : -len(".conda")]  # "<version>-<build>"
        version = rest.rsplit("-", 1)[0] if "-" in rest else rest
        mtime = os.path.getmtime(path)
        key = (subdir, version)
        if key not in newest or mtime > newest[key][1]:
            newest[key] = (path, mtime)
    return sorted((sd, ver, p) for (sd, ver), (p, _mt) in newest.items())


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Copy pixi-built source (conda_source) packages from a lock "
        "into a channel directory for indexing.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("lock", help="path to pixi.lock")
    ap.add_argument("-o", "--output", required=True,
                    help="output channel directory (linux-64/ and noarch/ created under it)")
    ap.add_argument("--bld-root", default=None,
                    help="pixi build tree (default: <lockdir>/.pixi/bld)")
    ap.add_argument("--environment", default=None,
                    help="restrict to one environment's source packages "
                         "(default: all source packages in the lock)")
    ap.add_argument("--clean", action="store_true",
                    help="remove existing *.conda from the output subdirs before copying "
                         "(clears stale build strings so the indexer can't offer them)")
    ap.add_argument("--move", action="store_true",
                    help="move instead of copy (NOT recommended: breaks the pixi build cache)")
    ap.add_argument("-n", "--dry-run", action="store_true",
                    help="print what would happen; touch nothing")
    args = ap.parse_args()

    lock_path = os.path.abspath(args.lock)
    if not os.path.isfile(lock_path):
        print(f"error: lock not found: {lock_path}", file=sys.stderr)
        return 2
    with open(lock_path) as fh:
        lock = yaml.safe_load(fh)

    bld_root = args.bld_root or os.path.join(os.path.dirname(lock_path), ".pixi", "bld")
    if not os.path.isdir(bld_root):
        print(f"error: build tree not found: {bld_root}\n"
              f"       (pass --bld-root, or run `pixi install` first)", file=sys.stderr)
        return 2

    out_dir = os.path.abspath(args.output)

    names = parse_source_names(lock, args.environment)
    if not names:
        print("No conda_source packages selected -- nothing to do.", file=sys.stderr)
        return 1

    scope = f"environment '{args.environment}'" if args.environment else "all environments"
    print(f"Lock:       {lock_path}")
    print(f"Build tree: {bld_root}")
    print(f"Output:     {out_dir}")
    print(f"Selected:   {len(names)} source packages ({scope})")
    print(f"Mode:       {'MOVE' if args.move else 'copy'}{'  [DRY-RUN]' if args.dry_run else ''}")
    print()

    if args.clean:
        for sub in ("linux-64", "noarch"):
            for f in glob.glob(os.path.join(out_dir, sub, "*.conda")):
                if args.dry_run:
                    print(f"[dry-run] would remove {os.path.relpath(f, out_dir)}")
                else:
                    os.remove(f)
        print("cleaned existing *.conda from output subdirs\n")

    copied = 0
    missing: list[str] = []
    for name in names:
        builds = find_builds(bld_root, name)
        if not builds:
            missing.append(name)
            continue
        for subdir, version, src in builds:
            dst_dir = os.path.join(out_dir, subdir)
            dst = os.path.join(dst_dir, os.path.basename(src))
            verb = "move" if args.move else "copy"
            print(f"  {verb} {name}-{version}  ->  {subdir}/{os.path.basename(src)}")
            if not args.dry_run:
                os.makedirs(dst_dir, exist_ok=True)
                if args.move:
                    shutil.move(src, dst)
                else:
                    shutil.copy2(src, dst)
            copied += 1

    print()
    print(f"{'Would ' if args.dry_run else ''}{'moved' if args.move else 'copied'} "
          f"{copied} artifact(s) for {len(names) - len(missing)}/{len(names)} packages.")
    if missing:
        print(f"WARNING: no built .conda found under {bld_root} for "
              f"{len(missing)} package(s): {', '.join(missing)}", file=sys.stderr)
        print("         (not built yet in this workspace, or built elsewhere?)",
              file=sys.stderr)

    print()
    print("Next: index the channel, then it's usable as a file:// channel, e.g.")
    print(f"  pixi exec --spec conda-index -- python -m conda_index {out_dir}")

    # exit non-zero if anything selected was missing, so callers can detect it
    return 3 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
