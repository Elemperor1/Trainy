#!/usr/bin/env python3
"""Fail when a locally authorized provider credential crosses Trainy's boundary.

The check reads ignored developer env files without printing their values, then
looks for those exact byte sequences in versionable repository files, Trainy
temporary logs, and the credential-neutral simulator build products. It reports
paths only on failure.
"""

from __future__ import annotations

import os
from pathlib import Path
import plistlib
import subprocess
import sys
from typing import Iterable


ROOT = Path(__file__).resolve().parent.parent
ENV_SOURCES = (
    (Path(os.environ.get("NS_ENV_FILE") or ROOT / "TrainyIOS/Config/ns.env"), "NS_SUBSCRIPTION_KEY"),
    (Path(os.environ.get("ODPT_ENV_FILE") or ROOT / "TrainyIOS/Config/odpt.env"), "ODPT_CONSUMER_KEY"),
)
# The canonical iOS build wrapper owns this fixed output location. Keeping the
# scan root repository-defined prevents an environment value from expanding the
# credential audit to arbitrary filesystem paths.
APP_PRODUCTS = Path("/private/tmp/trainy-derived/Build/Products/Debug-iphonesimulator")
APP_ONLY_MARKERS = (
    b"gateway.apiportal.ns.nl",
    b"ocp-apim-subscription-key",
    b"ns_subscription_key",
)


class EnvConfigurationError(ValueError):
    """An env file is ambiguous or does not match the executable loader contract."""


def read_env_value(path: Path, key: str) -> bytes | None:
    if not path.is_file():
        return None
    found: bytes | None = None
    saw_key = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise EnvConfigurationError(f"unsupported entry in {path}")
        parsed_key, value = line.split("=", 1)
        parsed_key = parsed_key.strip()
        if parsed_key != key:
            raise EnvConfigurationError(f"unsupported key in {path}")
        if saw_key:
            raise EnvConfigurationError(f"duplicate {key} assignment in {path}")
        saw_key = True

        value = value.strip()
        if value[:1] in {"'", '"'}:
            if len(value) < 2 or value[-1:] != value[:1]:
                raise EnvConfigurationError(f"malformed quoted {key} value in {path}")
            value = value[1:-1]
        else:
            value = value.split("#", 1)[0].strip()
        if "$(" in value or "`" in value:
            raise EnvConfigurationError(f"unsafe {key} value in {path}")
        found = value.encode("utf-8") if value else None
    return found


def effective_secret_values() -> tuple[bytes, ...]:
    candidates: list[bytes] = []
    for path, key in ENV_SOURCES:
        process_value = os.environ.get(key, "")
        if process_value.strip():
            candidates.append(process_value.encode("utf-8"))
            trimmed = process_value.strip().encode("utf-8")
            if trimmed != candidates[-1]:
                candidates.append(trimmed)
        file_value = read_env_value(path, key)
        if file_value:
            candidates.append(file_value)
    return tuple(dict.fromkeys(candidates))


def versionable_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return [ROOT / item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


def documentation_files() -> list[Path]:
    candidates = [
        ROOT / "README.md",
        ROOT / "CLAUDE.md",
        ROOT / "TrainyIOS/README.md",
        ROOT / "provider-proxy/README.md",
    ]
    candidates.extend((ROOT / "docs").rglob("*.md"))
    return [path for path in candidates if path.is_file()]


def git_diff_contains(needles: tuple[bytes, ...]) -> bool:
    for arguments in (["git", "diff", "--no-ext-diff"], ["git", "diff", "--cached", "--no-ext-diff"]):
        result = subprocess.run(arguments, cwd=ROOT, check=True, capture_output=True)
        if any(needle in result.stdout for needle in needles):
            return True
    return False


def files_below(path: Path) -> Iterable[Path]:
    if path.is_file() and not path.is_symlink():
        yield path
    elif path.is_dir():
        for candidate in path.rglob("*"):
            if candidate.is_file() and not candidate.is_symlink():
                yield candidate


def trainy_temporary_files() -> Iterable[Path]:
    roots = {Path("/private/tmp"), Path(os.environ.get("TMPDIR", "/tmp"))}
    allowed_prefixes = (
        "trainy-ns-",
        "trainy-proxy-",
        "trainy-provider-proxy-",
        "trainy-final-",
        "trainy-bridge-",
        "trainy-current-worker-",
    )
    for root in roots:
        if not root.is_dir():
            continue
        for entry in root.iterdir():
            if entry.name.lower().startswith(allowed_prefixes):
                yield from files_below(entry)


def simulator_log_files() -> Iterable[Path]:
    workspaces = Path.home() / "Library/Developer/XcodeBuildMCP/workspaces"
    if not workspaces.is_dir():
        return
    for logs in workspaces.glob("Trainy-*/logs"):
        yield from files_below(logs)


def contains(path: Path, needles: tuple[bytes, ...]) -> bool:
    if not needles:
        return False
    overlap = max(len(needle) for needle in needles) - 1
    previous = b""
    try:
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                searchable = previous + chunk
                if any(needle in searchable for needle in needles):
                    return True
                previous = searchable[-overlap:] if overlap > 0 else b""
    except (OSError, PermissionError):
        return False
    return False


def app_has_resolved_odpt_credential(app_path: Path) -> bool:
    info_plist = app_path / "Info.plist"
    try:
        with info_plist.open("rb") as handle:
            value = plistlib.load(handle).get("ODPTConsumerKey", "")
    except (OSError, plistlib.InvalidFileException):
        raise EnvConfigurationError(f"could not inspect built app metadata at {info_plist}") from None
    return (
        isinstance(value, str)
        and bool(value.strip())
        and not value.strip().startswith("$(")
    )


def main() -> int:
    try:
        secret_values = effective_secret_values()
    except EnvConfigurationError as error:
        print(f"Provider secret boundary check failed: {error}", file=sys.stderr)
        return 1
    repository_files = list(set(versionable_files() + documentation_files()))
    temporary_files = list(trainy_temporary_files()) + list(simulator_log_files())
    generated_files = list(files_below(APP_PRODUCTS))
    scanned = set(repository_files + temporary_files + generated_files)
    leaked = sorted(str(path) for path in scanned if contains(path, secret_values))
    if git_diff_contains(secret_values):
        leaked.append("<git diff>")

    app_path = APP_PRODUCTS / "Trainy.app"
    if not app_path.is_dir():
        print(f"Provider secret boundary check failed: app bundle not found at {app_path}", file=sys.stderr)
        return 1
    app_files = list(files_below(app_path))
    shipping_app_files = [
        path
        for path in app_files
        if not any(part.endswith(".xctest") for part in path.relative_to(app_path).parts)
    ]
    try:
        if app_has_resolved_odpt_credential(app_path):
            leaked.append(str(app_path / "Info.plist"))
    except EnvConfigurationError as error:
        print(f"Provider secret boundary check failed: {error}", file=sys.stderr)
        return 1
    # App-only marker checks are case-insensitive. The exact-value scan above
    # stays byte-for-byte across every generated file, including test bundles,
    # so no normalized form of a credential is emitted. Xcode injects `.xctest`
    # plug-ins containing these marker assertions into the built app while
    # testing; those plug-ins are not part of a shipped application payload.
    marker_files = []
    for path in shipping_app_files:
        try:
            data = path.read_bytes().lower()
        except (OSError, PermissionError):
            continue
        if any(marker in data for marker in APP_ONLY_MARKERS):
            marker_files.append(str(path))

    if leaked or marker_files:
        print("Provider secret boundary check failed; sensitive material appeared in:", file=sys.stderr)
        for path in sorted(set(leaked + marker_files)):
            print(f"  {path}", file=sys.stderr)
        return 1

    print(
        "Provider secret boundary passed: "
        f"{len(scanned)} repository/generated/log files and {len(shipping_app_files)} shipping app files checked for NS boundary markers; "
        f"{len(secret_values)} authorized local credential value(s) checked."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
