#!/usr/bin/env python3
"""Regression tests for the xcresult failure reporter used by Swift CI."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
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
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="trainy-xcresult-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)

    def write(self, name: str, payload: object) -> None:
        text = payload if isinstance(payload, str) else json.dumps(payload)
        (self.directory / name).write_text(text, encoding="utf-8")

    def test_report_prints_counts_tests_and_messages(self) -> None:
        self.write("summary.json", {"totalTestCount": 3, "passedTests": 2, "failedTests": 1})
        self.write("tests.json", tests_payload(case("testFails()", "Failed", "line one\nline two")))

        text = reporter.report(self.directory)

        self.assertIn("## Test failures (3 tests, 2 passed, 1 failed)", text)
        self.assertIn("**TrainyUITests / TrainyCriticalUITests / testFails()**", text)
        self.assertIn("```text\nline one\nline two\n```", text)

    def test_report_falls_back_to_the_summary_when_the_tree_has_no_messages(self) -> None:
        self.write(
            "summary.json",
            {"testFailures": [{"targetName": "TrainyUITests", "testName": "testFails()", "failureText": "boom"}]},
        )
        self.write("tests.json", tests_payload(case("testFails()", "Failed")))

        text = reporter.report(self.directory)

        self.assertIn("**TrainyUITests / testFails()**", text)
        self.assertIn("```text\nboom\n```", text)

    def test_report_explains_unreadable_json_instead_of_raising(self) -> None:
        self.write("summary.json", "")
        self.write("tests.json", "[]")

        text = reporter.report(self.directory)

        self.assertIn("Could not read the test summary: summary.json is not JSON", text)
        self.assertIn("Could not read the test list: tests.json holds list", text)

    def test_report_says_so_when_nothing_was_saved(self) -> None:
        text = reporter.report(self.directory)

        self.assertIn("No test results were saved", text)
        self.assertNotIn("Could not read", text)

    def test_report_keeps_going_when_only_the_summary_is_missing(self) -> None:
        self.write("tests.json", tests_payload(case("testFails()", "Failed", "boom")))

        text = reporter.report(self.directory)

        self.assertIn("Could not read the test summary: summary.json was not written", text)
        self.assertIn("```text\nboom\n```", text)

    def test_report_says_so_when_no_failed_case_exists(self) -> None:
        self.write("summary.json", {})
        self.write("tests.json", tests_payload(case("testPasses()", "Passed")))

        text = reporter.report(self.directory)

        self.assertIn("found no failed test cases", text)
        self.assertIn("Test tree (truncated)", text)

    def test_long_messages_are_clipped(self) -> None:
        self.write("summary.json", {})
        self.write(
            "tests.json",
            tests_payload(case("testFails()", "Failed", "x" * (reporter.MAX_MESSAGE_CHARS + 500))),
        )

        text = reporter.report(self.directory)

        self.assertIn("500 more characters", text)
        self.assertLess(len(text), reporter.MAX_MESSAGE_CHARS + 1000)

    def test_a_long_failure_list_is_capped(self) -> None:
        self.write("summary.json", {})
        self.write(
            "tests.json",
            tests_payload(*[case(f"test{index}()", "Failed", "boom") for index in range(reporter.MAX_TESTS_REPORTED + 3)]),
        )

        text = reporter.report(self.directory)

        self.assertIn("3 more failed tests are not listed.", text)


class MainTests(unittest.TestCase):
    def test_main_prints_the_report_and_exits_zero(self) -> None:
        with tempfile.TemporaryDirectory(prefix="trainy-xcresult-main-") as directory:
            output = io.StringIO()
            with (
                mock.patch.object(sys, "argv", ["summarize-xcresult-failures.py", directory]),
                contextlib.redirect_stdout(output),
            ):
                status = reporter.main()

        self.assertEqual(status, 0)
        self.assertIn("No test results were saved", output.getvalue())


if __name__ == "__main__":
    unittest.main()
