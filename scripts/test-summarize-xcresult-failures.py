#!/usr/bin/env python3
"""Regression tests for the xcresult failure reporter used by Swift CI."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parent.parent


def load_reporter():
    path = ROOT / "scripts/summarize-xcresult-failures.py"
    spec = importlib.util.spec_from_file_location("trainy_xcresult_reporter", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load the xcresult reporter")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


reporter = load_reporter()


def case(name: str, result: str, *messages: str) -> dict[str, object]:
    return {
        "name": name,
        "nodeType": "Test Case",
        "result": result,
        "children": [
            {"name": message, "nodeType": "Failure Message", "result": "Failed"} for message in messages
        ],
    }


def tests_payload(*cases: dict[str, object]) -> dict[str, object]:
    return {
        "testNodes": [
            {
                "name": "TrainyTests",
                "nodeType": "Test Plan",
                "children": [
                    {
                        "name": "TrainyUITests",
                        "nodeType": "UI test bundle",
                        "children": [
                            {"name": "TrainyCriticalUITests", "nodeType": "Test Suite", "children": list(cases)}
                        ],
                    }
                ],
            }
        ]
    }


def completed(payload: object, code: int = 0, stderr: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess([], code, stdout=json.dumps(payload), stderr=stderr)


class FailedTestTests(unittest.TestCase):
    def test_lists_only_failed_cases_with_their_scope_and_messages(self) -> None:
        payload = tests_payload(
            case("testPasses()", "Passed"),
            case("testFails()", "Failed", "TrainyCriticalUITests.swift:219: XCTAssertTrue failed"),
        )

        self.assertEqual(
            reporter.failed_tests(payload),
            [
                (
                    "TrainyUITests / TrainyCriticalUITests / testFails()",
                    ["TrainyCriticalUITests.swift:219: XCTAssertTrue failed"],
                )
            ],
        )

    def test_a_failed_case_without_a_message_is_still_listed(self) -> None:
        found = reporter.failed_tests(tests_payload(case("testCrashes()", "Failed")))

        self.assertEqual([name for name, _ in found], ["TrainyUITests / TrainyCriticalUITests / testCrashes()"])
        self.assertEqual(found[0][1], [])

    def test_messages_nested_under_a_device_run_are_found_once(self) -> None:
        nested = case("testFails()", "Failed")
        run = {
            "name": "iPhone 17",
            "nodeType": "Device",
            "children": [{"name": "Expected value", "nodeType": "Failure Message"}] * 2,
        }
        nested["children"] = [run]

        found = reporter.failed_tests(tests_payload(nested))

        self.assertEqual(found[0][1], ["Expected value"])

    def test_malformed_trees_do_not_raise(self) -> None:
        for payload in ({}, {"testNodes": "nope"}, {"testNodes": [1, None, {"children": "x"}]}):
            self.assertEqual(reporter.failed_tests(payload), [])

    def test_summary_failures_name_the_target_and_test(self) -> None:
        summary = {
            "testFailures": [
                {"targetName": "TrainyUITests", "testName": "testFails()", "failureText": "boom"},
                {"testName": "testBare()"},
                "ignored",
            ]
        }

        self.assertEqual(
            reporter.summary_failures(summary),
            [("TrainyUITests / testFails()", ["boom"]), ("testBare()", [])],
        )

    def test_count_line_skips_missing_counts(self) -> None:
        self.assertEqual(
            reporter.count_line({"totalTestCount": 66, "passedTests": 65, "failedTests": 1}),
            "66 tests, 65 passed, 1 failed",
        )
        self.assertEqual(reporter.count_line({}), "")


class ReportTests(unittest.TestCase):
    def run_report(self, summary: object, tests: object) -> tuple[str, str]:
        responses = {"summary": summary, "tests": tests}

        def fake_run(command, **_kwargs):
            payload = responses[command[command.index("test-results") + 1]]
            if isinstance(payload, subprocess.CompletedProcess):
                return payload
            return completed(payload)

        with mock.patch.object(reporter.subprocess, "run", side_effect=fake_run):
            return reporter.report(Path("/tmp/results.xcresult"))

    def test_report_prints_counts_tests_and_messages(self) -> None:
        text, markdown = self.run_report(
            {"totalTestCount": 3, "passedTests": 2, "failedTests": 1},
            tests_payload(case("testFails()", "Failed", "line one\nline two")),
        )

        self.assertIn("Test failures (3 tests, 2 passed, 1 failed)", text)
        self.assertIn("FAILED TrainyUITests / TrainyCriticalUITests / testFails()", text)
        self.assertIn("    line two", text)
        self.assertIn("```text\nline one\nline two\n```", markdown)

    def test_report_falls_back_to_the_summary_when_the_tree_has_no_messages(self) -> None:
        text, _ = self.run_report(
            {"testFailures": [{"targetName": "TrainyUITests", "testName": "testFails()", "failureText": "boom"}]},
            tests_payload(case("testFails()", "Failed")),
        )

        self.assertIn("FAILED TrainyUITests / testFails()", text)
        self.assertIn("    boom", text)

    def test_report_explains_a_tool_failure_instead_of_raising(self) -> None:
        broken = subprocess.CompletedProcess([], 64, stdout="", stderr="unknown option --path")

        text, _ = self.run_report(broken, broken)

        self.assertIn("Could not read the test summary", text)
        self.assertIn("unknown option --path", text)

    def test_report_says_so_when_no_failed_case_exists(self) -> None:
        text, _ = self.run_report({}, tests_payload(case("testPasses()", "Passed")))

        self.assertIn("found no failed test cases", text)

    def test_long_messages_are_clipped(self) -> None:
        long_message = "x" * (reporter.MAX_MESSAGE_CHARS + 500)

        text, _ = self.run_report({}, tests_payload(case("testFails()", "Failed", long_message)))

        self.assertIn("500 more characters", text)
        self.assertLess(len(text), reporter.MAX_MESSAGE_CHARS + 1000)

    def test_a_long_failure_list_is_capped(self) -> None:
        cases = [case(f"test{index}()", "Failed", "boom") for index in range(reporter.MAX_TESTS_REPORTED + 3)]

        text, _ = self.run_report({}, tests_payload(*cases))

        self.assertIn("3 more failed tests are not listed.", text)


class MainTests(unittest.TestCase):
    def test_a_missing_bundle_is_reported_and_exits_zero(self) -> None:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = reporter.main(["/nonexistent/results.xcresult"])

        self.assertEqual(status, 0)
        self.assertIn("No test result bundle", output.getvalue())

    def test_the_report_is_appended_to_the_job_summary(self) -> None:
        with tempfile.TemporaryDirectory(prefix="trainy-xcresult-test-") as directory:
            bundle = Path(directory) / "results.xcresult"
            bundle.mkdir()
            summary_file = Path(directory) / "summary.md"
            summary_file.write_text("existing\n", encoding="utf-8")

            with (
                mock.patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(summary_file)}),
                mock.patch.object(reporter, "report", return_value=("log text\n", "## markdown\n")),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                status = reporter.main([str(bundle)])

            self.assertEqual(status, 0)
            self.assertEqual(summary_file.read_text(encoding="utf-8"), "existing\n## markdown\n\n")


if __name__ == "__main__":
    unittest.main()
