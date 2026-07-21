#!/usr/bin/env python3
"""Normalize machine-local metadata in a completed iOS archive."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


FORBIDDEN_PRODUCT_PREFIXES = (
    b"/Users/",
    b"/private/tmp/",
    b"/tmp/trainy",
)
FORBIDDEN_DSYM_PREFIXES = (b"/Users/",)


def normalize_relocation_maps(archive: Path) -> int:
    """Replace Xcode's absolute dSYM input path with a stable logical path."""
    changed = 0
    for path in sorted(archive.glob("dSYMs/*.dSYM/Contents/Resources/Relocations/**/*.yml")):
        text = path.read_text(encoding="utf-8")
        binary_name = path.stem
        replacement = f"binary-path:     '/Trainy.app/{binary_name}'"
        updated, count = re.subn(r"^binary-path:\s+.*$", replacement, text, count=1, flags=re.MULTILINE)
        if count != 1:
            raise ValueError(f"expected one binary-path entry in {path.relative_to(archive)}")
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed += 1
    return changed


def sensitive_path_hits(root: Path, relative_to: Path, prefixes: tuple[bytes, ...]) -> list[str]:
    """Return files below root that retain machine-local path prefixes."""
    hits: list[str] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        data = path.read_bytes()
        if any(prefix in data for prefix in prefixes):
            hits.append(str(path.relative_to(relative_to)))
    return hits


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()

    archive = args.archive.resolve()
    if not (archive / "Info.plist").is_file():
        parser.error("archive does not contain Info.plist")

    changed = normalize_relocation_maps(archive)
    products = archive / "Products"
    product_hits = sensitive_path_hits(products, archive, FORBIDDEN_PRODUCT_PREFIXES)
    if product_hits:
        print("shipped products still contain machine-local path metadata:", file=sys.stderr)
        for hit in product_hits:
            print(f"  {hit}", file=sys.stderr)
        return 1

    dsym_user_hits = sensitive_path_hits(archive / "dSYMs", archive, FORBIDDEN_DSYM_PREFIXES)
    if dsym_user_hits:
        print("dSYMs still contain a user-home path:", file=sys.stderr)
        for hit in dsym_user_hits:
            print(f"  {hit}", file=sys.stderr)
        return 1

    dsym_temp_hits = sensitive_path_hits(
        archive / "dSYMs",
        archive,
        (b"/private/tmp/", b"/tmp/trainy"),
    )
    print(
        f"Normalized {changed} dSYM relocation map(s); "
        f"shipped-product machine paths: 0; user-home paths: 0; "
        f"dSYM temporary debug-path files retained: {len(dsym_temp_hits)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
