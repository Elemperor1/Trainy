#!/usr/bin/env python3
"""Render the JSON report from audit-ios-archive.py as a Markdown summary.

Swift CI appends the output to $GITHUB_STEP_SUMMARY so a reviewer sees the
failing and limited checks without opening the raw log. The report contains
only check names, outcomes, counts, and hashes; the auditor never writes a
credential value into it.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

STATUS_ORDER = {"fail": 0, "warning": 1, "pass": 2}
STATUS_LABEL = {"fail": "FAIL", "warning": "WARN", "pass": "PASS"}
HASH_KEYS = ("archive_sha256", "app_binary_sha256", "dsym_binary_sha256")


def cell(value: object) -> str:
    """Make a value safe for a single Markdown table cell."""
    return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ").strip()


def render(report: dict[str, object]) -> str:
    checks = [check for check in report.get("checks", []) if isinstance(check, dict)]
    counts = {status: 0 for status in STATUS_ORDER}
    for check in checks:
        counts[check.get("status", "pass")] = counts.get(check.get("status", "pass"), 0) + 1

    lines = [
        "## Release archive audit",
        "",
        f"**Result:** `{report.get('result', 'unknown')}`. "
        f"{len(checks)} checks, {counts['fail']} failed, {counts['warning']} with limitations.",
        "",
    ]

    attention = sorted(
        (check for check in checks if check.get("status") != "pass"),
        key=lambda check: STATUS_ORDER.get(str(check.get("status")), 3),
    )
    if attention:
        lines += ["| Status | Check | Detail |", "| --- | --- | --- |"]
        for check in attention:
            label = STATUS_LABEL.get(str(check.get("status")), str(check.get("status")).upper())
            lines.append(f"| {label} | {cell(check.get('name'))} | {cell(check.get('detail'))} |")
        lines.append("")

    passing = [check for check in checks if check.get("status") == "pass"]
    if passing:
        lines += [f"<details><summary>{len(passing)} passing checks</summary>", ""]
        for check in passing:
            lines.append(f"- **{cell(check.get('name'))}**: {cell(check.get('detail'))}")
        lines += ["", "</details>", ""]

    metadata = report.get("metadata", {})
    if isinstance(metadata, dict):
        identity = [(key, metadata.get(key)) for key in HASH_KEYS if metadata.get(key)]
        if identity:
            lines += ["Archive identity:", ""]
            lines += [f"- `{key}`: `{value}`" for key, value in identity]
            lines.append("")
        if metadata.get("signed") is False:
            lines += [
                "The archive is unsigned by design, so this run is content proof only. "
                "A distribution-signed export needs its own audit.",
                "",
            ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="JSON written by audit-ios-archive.py --json-output")
    args = parser.parse_args()

    if not args.report.is_file():
        print("## Release archive audit\n\nNo audit report was produced; see the job log for the failing step.")
        return 0
    try:
        report = json.loads(args.report.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"## Release archive audit\n\nThe audit report could not be read: {cell(error)}")
        return 0
    if not isinstance(report, dict):
        print("## Release archive audit\n\nThe audit report has an unexpected shape.")
        return 0
    print(render(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
