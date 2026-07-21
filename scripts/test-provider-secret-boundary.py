#!/usr/bin/env python3
"""Credential-neutral regression tests for Trainy's provider boundary guard."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parent.parent
SYNTHETIC_PROCESS_VALUE = "SYNTHETIC_PROCESS_CREDENTIAL_FOR_BOUNDARY_TEST"
SYNTHETIC_FILE_VALUE = "SYNTHETIC_FILE_CREDENTIAL_FOR_BOUNDARY_TEST"


def load_checker():
    path = ROOT / "scripts/check-provider-secret-boundary.py"
    spec = importlib.util.spec_from_file_location("trainy_provider_boundary", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load provider boundary checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ProviderSecretBoundaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="trainy-boundary-test-")
        self.root = Path(self.temporary.name)
        self.products = self.root / "products"
        self.app = self.products / "Trainy.app"
        self.app.mkdir(parents=True)
        self.ns_env = self.root / "ns.env"
        self.odpt_env = self.root / "odpt.env"
        self.checker = load_checker()
        self.checker.ROOT = self.root
        self.checker.ENV_SOURCES = (
            (self.ns_env, "NS_SUBSCRIPTION_KEY"),
            (self.odpt_env, "ODPT_CONSUMER_KEY"),
        )
        self.checker.APP_PRODUCTS = self.products
        self.checker.versionable_files = lambda: []
        self.checker.documentation_files = lambda: []
        self.checker.trainy_temporary_files = lambda: iter(())
        self.checker.simulator_log_files = lambda: iter(())
        self.checker.git_diff_contains = lambda needles: False

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_plist(self, value: str) -> None:
        with (self.app / "Info.plist").open("wb") as handle:
            plistlib.dump({"ODPTConsumerKey": value}, handle)

    def run_checker(self, environment: dict[str, str] | None = None) -> tuple[int, str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with mock.patch.dict(os.environ, environment or {}, clear=True):
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                result = self.checker.main()
        output = stdout.getvalue() + stderr.getvalue()
        self.assertNotIn(SYNTHETIC_PROCESS_VALUE, output)
        self.assertNotIn(SYNTHETIC_FILE_VALUE, output)
        return result, output

    def test_process_only_effective_value_is_detected(self) -> None:
        self.write_plist(SYNTHETIC_PROCESS_VALUE)
        result, output = self.run_checker({"ODPT_CONSUMER_KEY": SYNTHETIC_PROCESS_VALUE})
        self.assertEqual(result, 1)
        self.assertIn("Info.plist", output)

    def test_duplicate_file_assignments_fail_closed(self) -> None:
        self.write_plist("")
        self.odpt_env.write_text(
            f"ODPT_CONSUMER_KEY={SYNTHETIC_FILE_VALUE}\n"
            "ODPT_CONSUMER_KEY=SECOND_SYNTHETIC_VALUE\n",
            encoding="utf-8",
        )
        result, output = self.run_checker()
        self.assertEqual(result, 1)
        self.assertIn("duplicate ODPT_CONSUMER_KEY assignment", output)

    def test_file_value_is_scanned_without_being_printed(self) -> None:
        self.write_plist("")
        self.odpt_env.write_text(f"ODPT_CONSUMER_KEY={SYNTHETIC_FILE_VALUE}\n", encoding="utf-8")
        retained_log = self.root / "retained.log"
        retained_log.write_text(SYNTHETIC_FILE_VALUE, encoding="utf-8")
        self.checker.trainy_temporary_files = lambda: iter((retained_log,))
        result, output = self.run_checker()
        self.assertEqual(result, 1)
        self.assertIn("retained.log", output)

    def test_empty_credential_neutral_app_passes(self) -> None:
        self.write_plist("")
        result, output = self.run_checker()
        self.assertEqual(result, 0)
        self.assertIn("0 authorized local credential value(s) checked", output)


if __name__ == "__main__":
    unittest.main()
