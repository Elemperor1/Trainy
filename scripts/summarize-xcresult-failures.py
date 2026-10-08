#!/usr/bin/env python3
"""Render the failed tests in xcresulttool's JSON as Markdown, with their messages.

`xcodebuild test -quiet` names the tests that failed but prints nothing about
why. Swift CI passes -resultBundlePath and, after a failed test step, saves
`xcrun xcresulttool get test-results summary` as summary.json and `... tests` as
tests.json in one directory. This script reads that directory and prints the
report; the workflow tees it into the log and $GITHUB_STEP_SUMMARY.

The script always exits 0. Its job is to explain a failure, never to add one.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MAX_MESSAGE_CHARS = 8000
MAX_RAW_CHARS = 12000
MAX_TESTS_REPORTED = 40
SCOPE_NODE_TYPES = {"Unit test bundle", "UI test bundle", "Test Suite"}


class ReportError(Exception):
    """An xcresulttool JSON file could not be read."""


class MissingReport(ReportError):
    """The workflow never wrote the file."""


def read_json(path: Path) -> dict[str, object]:
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError as error:
        raise MissingReport(f"{path.name} was not written") from error
    except (OSError, UnicodeDecodeError) as error:
        raise ReportError(f"{path.name} could not be read: {error}") from error
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as error:
        raise ReportError(f"{path.name} is not JSON ({error}); the xcresulttool error is in the step log above") from error
    if not isinstance(payload, dict):
        raise ReportError(f"{path.name} holds {type(payload).__name__}, expected an object")
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


def render(failures: list[tuple[str, list[str]]], counts: str, notes: list[str]) -> str:
    heading = "## Test failures" + (f" ({counts})" if counts else "")
    lines = [heading, ""]
    shown = failures[:MAX_TESTS_REPORTED]
    for name, messages in shown:
        body = [clip(message) for message in messages] or ["(xcresulttool reported no failure message)"]
        lines += [f"**{name}**", "", "```text", *body, "```", ""]
    if len(failures) > len(shown):
        lines += [f"{len(failures) - len(shown)} more failed tests are not listed.", ""]
    for note in notes:
        lines += [note, ""]
    return "\n".join(lines).rstrip() + "\n"


def report(directory: Path) -> str:
    notes: list[str] = []
    counts = ""
    summary: dict[str, object] = {}
    missing = 0
    try:
        summary = read_json(directory / "summary.json")
        counts = count_line(summary)
    except MissingReport as error:
        missing += 1
        notes.append(f"Could not read the test summary: {error}.")
    except ReportError as error:
        notes.append(f"Could not read the test summary: {error}.")

    failures: list[tuple[str, list[str]]] = []
    raw = ""
    try:
        tests = read_json(directory / "tests.json")
        failures = failed_tests(tests)
        raw = json.dumps(tests, indent=1)
    except MissingReport as error:
        missing += 1
        notes.append(f"Could not read the test list: {error}.")
    except ReportError as error:
        notes.append(f"Could not read the test list: {error}.")

    if missing == 2:
        return render(
            [],
            "",
            ["No test results were saved. The build or the test launch failed before any test ran; read the Test Trainy step above."],
        )
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
        notes.append("Test tree (truncated):\n\n```json\n" + raw[:MAX_RAW_CHARS] + "\n```")
    return render(failures, counts, notes)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="directory holding summary.json and tests.json")
    args = parser.parse_args()
    print(report(args.directory), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
