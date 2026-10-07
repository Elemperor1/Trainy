#!/usr/bin/env python3
"""List the failed tests in an .xcresult bundle, with their failure messages.

`xcodebuild test -quiet` names the tests that failed but prints nothing about
why, so Swift CI passes -resultBundlePath and runs this after a failed test
step. The report goes to the job log and to $GITHUB_STEP_SUMMARY.

The script always exits 0. Its job is to explain a failure, never to add one.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

MAX_MESSAGE_CHARS = 8000
MAX_RAW_CHARS = 12000
MAX_TESTS_REPORTED = 40
SCOPE_NODE_TYPES = {"Unit test bundle", "UI test bundle", "Test Suite"}


class ReportError(Exception):
    """The result bundle could not be read."""


def read_result(bundle: Path, *subcommand: str) -> dict[str, object]:
    """Run `xcresulttool get test-results <subcommand>` and parse its JSON."""
    command = ["xcrun", "xcresulttool", "get", "test-results", *subcommand, "--path", str(bundle)]
    label = " ".join(subcommand)
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ReportError(f"could not run xcresulttool {label}: {error}") from error
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()[:2000]
        raise ReportError(f"xcresulttool {label} exited {completed.returncode}: {detail}")
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise ReportError(f"xcresulttool {label} did not return JSON: {error}") from error
    if not isinstance(payload, dict):
        raise ReportError(f"xcresulttool {label} returned {type(payload).__name__}, expected an object")
    return payload


def children_of(node: dict[str, object]) -> list[dict[str, object]]:
    children = node.get("children")
    if not isinstance(children, list):
        return []
    return [child for child in children if isinstance(child, dict)]


def failure_messages(node: dict[str, object]) -> list[str]:
    """Collect the text of every failure message under a test case."""
    messages: list[str] = []

    def visit(current: dict[str, object]) -> None:
        if current.get("nodeType") == "Failure Message":
            text = str(current.get("name") or current.get("details") or "").strip()
            if text and text not in messages:
                messages.append(text)
        for child in children_of(current):
            visit(child)

    visit(node)
    return messages


def failed_tests(tests: dict[str, object]) -> list[tuple[str, list[str]]]:
    """Return (test path, failure messages) for every failed test case."""
    found: list[tuple[str, list[str]]] = []

    def visit(node: dict[str, object], scope: list[str]) -> None:
        kind = node.get("nodeType")
        name = str(node.get("name", ""))
        if kind == "Test Case":
            messages = failure_messages(node)
            if node.get("result") == "Failed" or messages:
                found.append((" / ".join([*scope, name]), messages))
            return
        inner = [*scope, name] if kind in SCOPE_NODE_TYPES and name else scope
        for child in children_of(node):
            visit(child, inner)

    roots = tests.get("testNodes")
    for root in roots if isinstance(roots, list) else []:
        if isinstance(root, dict):
            visit(root, [])
    return found


def summary_failures(summary: dict[str, object]) -> list[tuple[str, list[str]]]:
    """Fall back to the summary's flat failure list when the test tree has no messages."""
    entries: list[tuple[str, list[str]]] = []
    failures = summary.get("testFailures")
    for item in failures if isinstance(failures, list) else []:
        if not isinstance(item, dict):
            continue
        name = " / ".join(str(item[key]) for key in ("targetName", "testName") if item.get(key))
        text = str(item.get("failureText") or "").strip()
        entries.append((name or "(unnamed test)", [text] if text else []))
    return entries


def count_line(summary: dict[str, object]) -> str:
    labels = (
        ("totalTestCount", "tests"),
        ("passedTests", "passed"),
        ("failedTests", "failed"),
        ("skippedTests", "skipped"),
        ("expectedFailures", "expected failures"),
    )
    parts = [f"{summary[key]} {label}" for key, label in labels if isinstance(summary.get(key), int)]
    return ", ".join(parts)


def clip(text: str) -> str:
    if len(text) <= MAX_MESSAGE_CHARS:
        return text
    return text[:MAX_MESSAGE_CHARS] + f"\n... ({len(text) - MAX_MESSAGE_CHARS} more characters)"


def render(
    failures: list[tuple[str, list[str]]], counts: str, notes: list[str]
) -> tuple[str, str]:
    """Return the plain-text log report and the Markdown job summary."""
    heading = "Test failures" + (f" ({counts})" if counts else "")
    text = [heading, ""]
    markdown = [f"## {heading}", ""]
    shown = failures[:MAX_TESTS_REPORTED]
    for name, messages in shown:
        body = [clip(message) for message in messages] or ["(xcresulttool reported no failure message)"]
        text += [f"FAILED {name}", *("    " + line for message in body for line in message.splitlines()), ""]
        markdown += [f"**{name}**", "", "```text", *body, "```", ""]
    if len(failures) > len(shown):
        omitted = f"{len(failures) - len(shown)} more failed tests are not listed."
        text += [omitted, ""]
        markdown += [omitted, ""]
    for note in notes:
        text += [note, ""]
        markdown += [note, ""]
    return "\n".join(text).rstrip() + "\n", "\n".join(markdown).rstrip() + "\n"


def report(bundle: Path) -> tuple[str, str]:
    notes: list[str] = []
    counts = ""
    summary: dict[str, object] = {}
    try:
        summary = read_result(bundle, "summary")
        counts = count_line(summary)
    except ReportError as error:
        notes.append(f"Could not read the test summary: {error}")

    failures: list[tuple[str, list[str]]] = []
    raw = ""
    try:
        tests = read_result(bundle, "tests")
        failures = failed_tests(tests)
        raw = json.dumps(tests, indent=1)
    except ReportError as error:
        notes.append(f"Could not read the test list: {error}")

    if not any(messages for _, messages in failures):
        fallback = summary_failures(summary)
        if fallback:
            failures = fallback
    if not failures and not notes:
        notes.append(
            "xcresulttool found no failed test cases in the bundle. "
            "The test step may have failed before any test ran; read its log above."
        )
    if not failures and raw:
        notes.append("Test tree (truncated):\n" + raw[:MAX_RAW_CHARS])
    return render(failures, counts, notes)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Explain failed tests in an .xcresult bundle.")
    parser.add_argument("bundle", type=Path, help="path to the .xcresult bundle")
    args = parser.parse_args(argv)

    if not args.bundle.exists():
        text = f"No test result bundle at {args.bundle}. The build or the test launch failed before tests ran.\n"
        markdown = "## Test failures\n\n" + text
    else:
        text, markdown = report(args.bundle)

    print(text, end="")
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        try:
            with open(summary_path, "a", encoding="utf-8") as handle:
                handle.write(markdown + "\n")
        except OSError as error:
            print(f"Could not write the job summary: {error}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
