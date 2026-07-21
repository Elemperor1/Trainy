#!/usr/bin/env python3
"""Audit a Trainy Release xcarchive without exposing credential values."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import plistlib
import re
import stat
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent
PRODUCTION_PROXY = "https://trainy-ns-provider-proxy.trainy-jacob.workers.dev"
SENSITIVE_KEY_RE = re.compile(
    r"(?:KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|SUBSCRIPTION|CLIENT_ID|USERNAME)",
    re.IGNORECASE,
)
PDF_CREDENTIAL_RE = re.compile(
    r"\b(?P<key>[A-Z][A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|CLIENT_ID|USERNAME))"
    r"[ \t]+(?P<value>\S{8,})"
)
ENDPOINT_RE = re.compile(rb"https?://(?:\[[0-9A-Fa-f:]+\]|[A-Za-z0-9._-]+)(?::[0-9]{1,5})?")
PERMISSION_KEYS = {
    "NSAppleMusicUsageDescription",
    "NSBluetoothAlwaysUsageDescription",
    "NSBluetoothPeripheralUsageDescription",
    "NSCalendarsFullAccessUsageDescription",
    "NSCalendarsUsageDescription",
    "NSCameraUsageDescription",
    "NSContactsUsageDescription",
    "NSFaceIDUsageDescription",
    "NSHealthClinicalHealthRecordsShareUsageDescription",
    "NSHealthShareUsageDescription",
    "NSHealthUpdateUsageDescription",
    "NSHomeKitUsageDescription",
    "NSLocationAlwaysAndWhenInUseUsageDescription",
    "NSLocationAlwaysUsageDescription",
    "NSLocationTemporaryUsageDescriptionDictionary",
    "NSLocationWhenInUseUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSMotionUsageDescription",
    "NSNearbyInteractionUsageDescription",
    "NSPhotoLibraryAddUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSRemindersFullAccessUsageDescription",
    "NSRemindersUsageDescription",
    "NSSensorKitUsageDescription",
    "NSSiriUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "NSUserTrackingUsageDescription",
}
EXPECTED_PRIVACY_MANIFESTS = {
    "PrivacyInfo.xcprivacy",
    "Firebase_FirebaseCore.bundle/PrivacyInfo.xcprivacy",
    "Firebase_FirebaseCoreExtension.bundle/PrivacyInfo.xcprivacy",
    "Firebase_FirebaseCoreInternal.bundle/PrivacyInfo.xcprivacy",
    "Firebase_FirebaseCrashlytics.bundle/PrivacyInfo.xcprivacy",
    "Firebase_FirebaseInstallations.bundle/PrivacyInfo.xcprivacy",
    "GoogleDataTransport_GoogleDataTransport.bundle/PrivacyInfo.xcprivacy",
    "GoogleUtilities_GoogleUtilities-Environment.bundle/PrivacyInfo.xcprivacy",
    "GoogleUtilities_GoogleUtilities-Logger.bundle/PrivacyInfo.xcprivacy",
    "GoogleUtilities_GoogleUtilities-NSData.bundle/PrivacyInfo.xcprivacy",
    "GoogleUtilities_GoogleUtilities-UserDefaults.bundle/PrivacyInfo.xcprivacy",
    "Promises_FBLPromises.bundle/PrivacyInfo.xcprivacy",
    "Promises_Promises.bundle/PrivacyInfo.xcprivacy",
    "nanopb_nanopb.bundle/PrivacyInfo.xcprivacy",
}
ALLOWED_PRIVACY_KEYS = {
    "NSPrivacyAccessedAPITypes",
    "NSPrivacyCollectedDataTypes",
    "NSPrivacyTracking",
    "NSPrivacyTrackingDomains",
}
PROHIBITED_PRODUCT_MARKERS = {
    "automation launch argument": b"--trainy-automation",
    "automation fixture host": b"fixture.trainy.invalid",
    "automation defaults suite": b"TrainyAutomation-",
    "NS upstream-only host": b"gateway.apiportal.ns.nl",
    "NS subscription-key setting": b"NS_SUBSCRIPTION_KEY",
    "NS upstream auth header": b"Ocp-Apim-Subscription-Key",
}
MACHINE_PATH_MARKERS = {
    "user home": b"/Users/",
    "private temporary path": b"/private/tmp/",
    "Trainy temporary path": b"/tmp/trainy",
}


@dataclass
class Check:
    name: str
    status: str
    detail: str


class Audit:
    def __init__(self) -> None:
        self.checks: list[Check] = []
        self.metadata: dict[str, object] = {}

    def pass_(self, name: str, detail: str) -> None:
        self.checks.append(Check(name, "pass", detail))

    def fail(self, name: str, detail: str) -> None:
        self.checks.append(Check(name, "fail", detail))

    def warn(self, name: str, detail: str) -> None:
        self.checks.append(Check(name, "warning", detail))

    def check(self, name: str, condition: bool, pass_detail: str, fail_detail: str) -> None:
        (self.pass_ if condition else self.fail)(name, pass_detail if condition else fail_detail)


def run(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def load_plist(path: Path) -> dict[str, object]:
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path.name} is not a dictionary plist")
    return value


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def hash_tree(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        digest.update(str(path.relative_to(root)).encode("utf-8"))
        digest.update(b"\0")
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
    return digest.hexdigest()


def regular_files(root: Path) -> Iterable[Path]:
    if root.is_file() and not root.is_symlink():
        yield root
        return
    if not root.is_dir():
        return
    for path in root.rglob("*"):
        if path.is_file() and not path.is_symlink():
            yield path


def endpoint_is_private(value: str) -> bool:
    try:
        host = (urlsplit(value).hostname or "").lower()
    except ValueError:
        return False
    if not host:
        return False
    if host == "localhost" or host.endswith((".local", ".internal", ".invalid")):
        return True
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return False
    return address.is_private or address.is_loopback or address.is_link_local


def scan_private_endpoints(roots: list[tuple[str, Path]]) -> dict[str, set[str]]:
    """Return only fingerprints and locations for private URL literals."""
    hits: dict[str, set[str]] = {}
    seen: set[tuple[int, int]] = set()
    for root_label, root in roots:
        for path in regular_files(root):
            try:
                inode = path.stat()
                identity = (inode.st_dev, inode.st_ino)
                if identity in seen:
                    continue
                seen.add(identity)
                relative = path.name if root.is_file() else str(path.relative_to(root))
                display_path = f"{root_label}/{relative}"
                tail = b""
                with path.open("rb") as handle:
                    while chunk := handle.read(4 * 1024 * 1024):
                        data = tail + chunk
                        for match in ENDPOINT_RE.finditer(data):
                            endpoint = match.group().decode("ascii", errors="ignore")
                            if endpoint_is_private(endpoint):
                                fingerprint = hashlib.sha256(match.group()).hexdigest()[:12]
                                hits.setdefault(fingerprint, set()).add(display_path)
                        tail = data[-512:]
            except OSError:
                continue
    return hits


def scan_patterns(
    roots: list[tuple[str, Path]], patterns: dict[str, bytes]
) -> tuple[dict[str, set[str]], int, int]:
    hits = {label: set() for label in patterns}
    if not patterns:
        return hits, 0, 0
    max_length = max(len(value) for value in patterns.values())
    files_scanned = 0
    bytes_scanned = 0
    seen: set[tuple[int, int]] = set()
    for root_label, root in roots:
        for path in regular_files(root):
            try:
                inode = path.stat()
                identity = (inode.st_dev, inode.st_ino)
                if identity in seen:
                    continue
                seen.add(identity)
                files_scanned += 1
                relative = path.name if root.is_file() else str(path.relative_to(root))
                display_path = f"{root_label}/{relative}"
                tail = b""
                with path.open("rb") as handle:
                    while chunk := handle.read(4 * 1024 * 1024):
                        bytes_scanned += len(chunk)
                        data = tail + chunk
                        for label, pattern in patterns.items():
                            if pattern in data:
                                hits[label].add(display_path)
                        tail = data[-max_length:]
            except OSError:
                continue
    return hits, files_scanned, bytes_scanned


def parse_env_candidates() -> tuple[dict[bytes, set[str]], list[Path]]:
    candidates: dict[bytes, set[str]] = {}
    files = [ROOT / ".env", *sorted((ROOT / "TrainyIOS" / "Config").glob("*.env"))]
    present: list[Path] = []
    for path in files:
        if not path.is_file():
            continue
        present.append(path)
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            key = key.removeprefix("export ").strip()
            value = value.strip().strip('"').strip("'")
            if (not SENSITIVE_KEY_RE.search(key) and not endpoint_is_private(value)) or len(value) < 8:
                continue
            if value.lower() in {"changeme", "placeholder", "none", "null"}:
                continue
            candidates.setdefault(value.encode("utf-8"), set()).add(key)
    return candidates, present


def parse_pdf_candidates(path: Path) -> dict[bytes, set[str]]:
    """Extract filled credential tokens through pdftotext without logging values."""
    result = run(["pdftotext", "-layout", str(path), "-"])
    if result.returncode != 0:
        raise RuntimeError("pdftotext could not extract the supplied credential form")

    candidates: dict[bytes, set[str]] = {}
    text = result.stdout.decode("utf-8", errors="replace")
    for match in PDF_CREDENTIAL_RE.finditer(text):
        key = match.group("key")
        value = match.group("value")
        lowered = value.lower()
        if lowered.startswith(("http://", "https://")):
            continue
        if lowered in {"changeme", "placeholder", "none", "null", "key_not_required"}:
            continue
        candidates.setdefault(value.encode("utf-8"), set()).add(key)
    return candidates


def swift_sources() -> list[Path]:
    roots = [ROOT / "Sources", ROOT / "TrainyIOS" / "Trainy"]
    return [path for source_root in roots for path in source_root.rglob("*.swift")]


def audit_archive(args: argparse.Namespace) -> Audit:
    audit = Audit()
    archive = args.archive.resolve()
    archive_info_path = archive / "Info.plist"
    if not archive_info_path.is_file():
        audit.fail("archive structure", "Info.plist is missing")
        return audit

    try:
        archive_info = load_plist(archive_info_path)
    except (OSError, ValueError, plistlib.InvalidFileException):
        audit.fail("archive metadata", "archive Info.plist is invalid")
        return audit

    app_candidates = sorted((archive / "Products" / "Applications").glob("*.app"))
    if len(app_candidates) != 1:
        audit.fail("application bundle", f"expected one app bundle, found {len(app_candidates)}")
        return audit
    app = app_candidates[0]
    app_info_path = app / "Info.plist"
    try:
        app_info = load_plist(app_info_path)
    except (OSError, ValueError, plistlib.InvalidFileException):
        audit.fail("generated app plist", "app Info.plist is missing or invalid")
        return audit

    executable_name = str(app_info.get("CFBundleExecutable", ""))
    executable = app / executable_name
    audit.check("app executable", executable.is_file(), "arm64 app executable is present", "app executable is missing")

    application_properties = archive_info.get("ApplicationProperties", {})
    if not isinstance(application_properties, dict):
        application_properties = {}
    architectures = application_properties.get("Architectures", [])
    audit.check(
        "archive architecture",
        architectures == ["arm64"],
        "archive contains arm64 only",
        "archive architecture is not exactly arm64",
    )
    audit.check(
        "archive scheme",
        archive_info.get("SchemeName") == "Trainy",
        "archive records the shared Trainy scheme",
        "archive scheme is not Trainy",
    )
    audit.check(
        "bundle identity",
        app_info.get("CFBundleIdentifier") == "com.jacobcyber.Trainy"
        and app_info.get("CFBundleShortVersionString") == "1.0"
        and app_info.get("CFBundleVersion") == "1",
        "bundle com.jacobcyber.Trainy version 1.0 (1)",
        "bundle identifier or version differs from the release contract",
    )
    audit.check(
        "platform metadata",
        app_info.get("DTPlatformName") == "iphoneos"
        and app_info.get("MinimumOSVersion") == "26.0"
        and app_info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"],
        "generated plist targets iPhoneOS 26.0",
        "generated platform metadata is unexpected",
    )

    audit.check(
        "ODPT release credential",
        app_info.get("ODPTConsumerKey") == "",
        "ODPTConsumerKey is present but empty",
        "ODPTConsumerKey is not empty",
    )
    audit.check(
        "production provider proxy",
        app_info.get("TrainyProviderProxyBaseURL") == PRODUCTION_PROXY,
        "approved public HTTPS NS proxy is pinned",
        "provider proxy is missing or differs from the approved release endpoint",
    )
    audit.check(
        "App Transport Security",
        "NSAppTransportSecurity" not in app_info,
        "no ATS exceptions are shipped",
        "an ATS exception dictionary is present",
    )
    usage_keys = sorted(PERMISSION_KEYS.intersection(app_info))
    audit.check(
        "permission descriptions",
        not usage_keys,
        "no protected-resource permission strings are shipped because no protected API is used",
        f"unexpected permission descriptions: {', '.join(usage_keys)}",
    )

    audit.check(
        "Crashlytics default",
        app_info.get("FirebaseCrashlyticsCollectionEnabled") is False,
        "automatic Crashlytics collection is disabled in the generated plist",
        "automatic Crashlytics collection is not explicitly disabled",
    )
    app_source = (ROOT / "TrainyIOS" / "Trainy" / "TrainyApp.swift").read_text(encoding="utf-8")
    consent_source_ok = all(
        marker in app_source
        for marker in (
            'bool(forKey: "trainy.diagnosticsConsent")',
            "setCrashlyticsCollectionEnabled(diagnosticsConsent)",
            "deleteUnsentReports()",
        )
    )
    audit.check(
        "Crashlytics consent behavior",
        consent_source_ok,
        "runtime collection follows explicit opt-in and deletes unsent reports when disabled",
        "Crashlytics opt-in or unsent-report cleanup wiring is incomplete",
    )

    source_info = load_plist(ROOT / "TrainyIOS" / "Trainy" / "GoogleService-Info.plist")
    shipped_google_info = load_plist(app / "GoogleService-Info.plist")
    audit.check(
        "Firebase public configuration",
        source_info == shipped_google_info,
        "shipped Firebase client configuration matches the tracked source plist",
        "shipped Firebase client configuration differs from the tracked source plist",
    )
    audit.check(
        "Firebase analytics and ads",
        shipped_google_info.get("IS_ANALYTICS_ENABLED") is False
        and shipped_google_info.get("IS_ADS_ENABLED") is False,
        "Firebase Analytics and Ads flags are disabled",
        "Firebase Analytics or Ads is enabled in the shipped configuration",
    )

    privacy_paths = sorted(app.rglob("PrivacyInfo.xcprivacy"))
    privacy_relative = {str(path.relative_to(app)) for path in privacy_paths}
    audit.check(
        "privacy manifest inventory",
        privacy_relative == EXPECTED_PRIVACY_MANIFESTS,
        f"all {len(EXPECTED_PRIVACY_MANIFESTS)} pinned app and SDK privacy manifests are present",
        "privacy manifest inventory differs from the pinned Firebase 12.15.0 release set",
    )
    privacy_valid = True
    tracking_manifests: list[str] = []
    tracking_domains = 0
    collected_types: set[str] = set()
    privacy_values: dict[str, dict[str, object]] = {}
    for path in privacy_paths:
        relative = str(path.relative_to(app))
        try:
            value = load_plist(path)
        except (OSError, ValueError, plistlib.InvalidFileException):
            privacy_valid = False
            continue
        privacy_values[relative] = value
        if not set(value).issubset(ALLOWED_PRIVACY_KEYS):
            privacy_valid = False
        if value.get("NSPrivacyTracking") is not False:
            tracking_manifests.append(relative)
        domains = value.get("NSPrivacyTrackingDomains", [])
        if not isinstance(domains, list):
            privacy_valid = False
        else:
            tracking_domains += len(domains)
        accessed = value.get("NSPrivacyAccessedAPITypes", [])
        collected = value.get("NSPrivacyCollectedDataTypes", [])
        if not isinstance(accessed, list) or not isinstance(collected, list):
            privacy_valid = False
            continue
        for item in accessed:
            if not isinstance(item, dict) or not isinstance(item.get("NSPrivacyAccessedAPITypeReasons"), list):
                privacy_valid = False
        for item in collected:
            if not isinstance(item, dict):
                privacy_valid = False
            elif isinstance(item.get("NSPrivacyCollectedDataType"), str):
                collected_types.add(str(item["NSPrivacyCollectedDataType"]))
    audit.check(
        "privacy manifest syntax",
        privacy_valid,
        "every privacy manifest is a valid plist with recognized keys and value shapes",
        "one or more privacy manifests is invalid",
    )
    audit.check(
        "tracking declarations",
        not tracking_manifests and tracking_domains == 0,
        "all app and SDK manifests declare no tracking and no tracking domains",
        "a manifest declares tracking or a tracking domain",
    )
    first_party_privacy = privacy_values.get("PrivacyInfo.xcprivacy", {})
    expected_access = [
        {
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
        }
    ]
    audit.check(
        "first-party privacy declaration",
        first_party_privacy.get("NSPrivacyAccessedAPITypes") == expected_access
        and first_party_privacy.get("NSPrivacyCollectedDataTypes") == [],
        "Trainy declares only UserDefaults reason CA92.1 and no first-party off-device collection",
        "Trainy's first-party privacy declaration is incomplete or non-minimal",
    )
    crash_privacy = privacy_values.get("Firebase_FirebaseCrashlytics.bundle/PrivacyInfo.xcprivacy", {})
    crash_types = {
        item.get("NSPrivacyCollectedDataType")
        for item in crash_privacy.get("NSPrivacyCollectedDataTypes", [])
        if isinstance(item, dict)
    }
    audit.check(
        "Crashlytics SDK privacy declaration",
        crash_types
        == {
            "NSPrivacyCollectedDataTypeCrashData",
            "NSPrivacyCollectedDataTypeOtherDiagnosticData",
        },
        "Crashlytics declares crash and other diagnostic data for app functionality",
        "Crashlytics privacy data declarations differ from the reviewed SDK contract",
    )
    audit.metadata["sdk_collected_data_types"] = sorted(collected_types)

    sources = swift_sources()
    source_text = "\n".join(path.read_text(encoding="utf-8") for path in sources)
    required_reason_other = re.findall(
        r"(?:systemUptime|mach_absolute_time|volumeAvailableCapacity|volumeTotalCapacity|activeInputModes|contentModificationDateKey|creationDateKey)",
        source_text,
    )
    audit.check(
        "first-party required-reason APIs",
        ("UserDefaults" in source_text or "@AppStorage" in source_text) and not required_reason_other,
        "source uses UserDefaults only among Apple's reviewed required-reason API categories",
        "source contains an undeclared required-reason API category",
    )
    protected_api_patterns = (
        "CLLocationManager",
        "AVCaptureDevice",
        "PHPhotoLibrary",
        "CNContactStore",
        "EKEventStore",
        "UNUserNotificationCenter",
        "ATTrackingManager",
        "CMMotionActivityManager",
    )
    protected_hits = [marker for marker in protected_api_patterns if marker in source_text]
    audit.check(
        "protected-resource API use",
        not protected_hits,
        "no first-party API requiring a permission description is referenced",
        f"protected API references require plist review: {', '.join(protected_hits)}",
    )
    first_party_logging = re.findall(
        r"\b(?:print|debugPrint|NSLog)\s*\(|\bos_log\b|Crashlytics\.crashlytics\(\)\.(?:log|setCustomValue|setUserID|record)",
        source_text,
    )
    audit.check(
        "first-party diagnostic payloads",
        not first_party_logging,
        "Trainy adds no logs, custom keys, user IDs, or nonfatal payloads to Crashlytics",
        "first-party logging or custom Crashlytics payload code is present",
    )

    artifact_names = [str(path.relative_to(app)) for path in app.rglob("*")]
    debug_artifacts = [
        name
        for name in artifact_names
        if name.endswith((".xctest", ".debug.dylib"))
        or "Preview Assets" in name
        or name.endswith("__preview.dylib")
    ]
    extensions = list(app.rglob("*.appex"))
    frameworks = list(app.rglob("*.framework"))
    audit.check(
        "debug and test artifacts",
        not debug_artifacts,
        "no previews, debug dylibs, or test bundles are shipped",
        f"debug/test artifacts found: {len(debug_artifacts)}",
    )
    audit.check(
        "extensions",
        not extensions,
        "no app extensions are shipped and no extension entitlements are required",
        f"unexpected app extensions found: {len(extensions)}",
    )
    audit.check(
        "embedded frameworks",
        not frameworks,
        "Firebase and Trainy dependencies are statically linked; no dynamic third-party frameworks are embedded",
        f"unexpected embedded frameworks found: {len(frameworks)}",
    )

    product_roots = [("app", app)]
    prohibited_hits, _, _ = scan_patterns(product_roots, PROHIBITED_PRODUCT_MARKERS)
    prohibited = [label for label, paths in prohibited_hits.items() if paths]
    audit.check(
        "Release-only strings",
        not prohibited,
        "automation fixtures and NS upstream secret-boundary markers are absent",
        f"prohibited product markers found: {', '.join(prohibited)}",
    )
    product_private_endpoints = scan_private_endpoints(product_roots)
    audit.check(
        "shipped private endpoints",
        not product_private_endpoints,
        "no loopback, private-network, local, internal, or invalid URL is shipped",
        f"{len(product_private_endpoints)} private endpoint fingerprint(s) are present in the app bundle",
    )
    path_hits, _, _ = scan_patterns(product_roots, MACHINE_PATH_MARKERS)
    product_path_markers = [label for label, paths in path_hits.items() if paths]
    audit.check(
        "shipped local paths",
        not product_path_markers,
        "the shipped app bundle contains no user-home or Trainy temporary build paths",
        f"machine-local product paths found: {', '.join(product_path_markers)}",
    )

    provenance_markers = {
        "NS attribution": b"Data from Nederlandse Spoorwegen (NS)",
        "NS terms": b"NS API terms",
        "ODPT attribution": b"Timetable data from ODPT TrainTimetable",
        "starter attribution": b"Trainy curated Shinkansen starter catalog",
    }
    provenance_hits, _, _ = scan_patterns(product_roots, provenance_markers)
    missing_provenance = [label for label, paths in provenance_hits.items() if not paths]
    audit.check(
        "provider provenance strings",
        not missing_provenance,
        "NS, ODPT, and starter-catalog source/terms disclosures are present in Release",
        f"missing provenance markers: {', '.join(missing_provenance)}",
    )

    env_candidates, env_files = parse_env_candidates()
    pdf_candidates: dict[bytes, set[str]] = {}
    credential_files = list(env_files)
    if args.credential_pdf:
        credential_pdf = args.credential_pdf.resolve()
        if not credential_pdf.is_file():
            audit.fail("credential PDF extraction", "the supplied credential PDF is missing")
        else:
            credential_files.append(credential_pdf)
            try:
                pdf_candidates = parse_pdf_candidates(credential_pdf)
                audit.check(
                    "credential PDF extraction",
                    bool(pdf_candidates),
                    f"{len(pdf_candidates)} candidate credential values were fingerprinted without printing them",
                    "the supplied credential PDF contained no extractable credential candidates",
                )
            except RuntimeError as error:
                audit.fail("credential PDF extraction", str(error))

    credential_modes_ok = all(
        stat.S_IMODE(path.stat().st_mode) == 0o600 for path in credential_files
    )
    audit.check(
        "local credential file permissions",
        credential_modes_ok,
        f"all {len(credential_files)} supplied local credential files are mode 0600",
        "one or more supplied local credential files is not mode 0600",
    )
    credential_candidates = {value: set(keys) for value, keys in env_candidates.items()}
    for value, keys in pdf_candidates.items():
        credential_candidates.setdefault(value, set()).update(keys)
    secret_patterns: dict[str, bytes] = {}
    secret_labels: dict[str, list[str]] = {}
    for value, keys in credential_candidates.items():
        fingerprint = hashlib.sha256(value).hexdigest()[:12]
        label = f"secret:{fingerprint}"
        secret_patterns[label] = value
        secret_labels[label] = sorted(keys)
    scan_roots: list[tuple[str, Path]] = [("archive", archive)]
    for index, path in enumerate(args.scan_root):
        scan_roots.append((f"build-output-{index + 1}", path.resolve()))
    combined_patterns = dict(secret_patterns)
    combined_patterns.update({f"path:{label}": value for label, value in MACHINE_PATH_MARKERS.items()})
    combined_hits, files_scanned, bytes_scanned = scan_patterns(scan_roots, combined_patterns)
    build_private_endpoints = scan_private_endpoints(scan_roots)
    secret_hit_labels = [label for label in secret_patterns if combined_hits[label]]
    if secret_hit_labels:
        for label in secret_hit_labels:
            audit.fail(
                f"credential fingerprint {label.removeprefix('secret:')}",
                f"key names {', '.join(secret_labels[label])}; matched {len(combined_hits[label])} output file(s)",
            )
    else:
        audit.pass_(
            "credential value scan",
            f"0 of {len(secret_patterns)} unique credential fingerprints "
            f"({len(env_candidates)} env, {len(pdf_candidates)} PDF candidates) matched across {files_scanned} files",
        )
    audit.metadata["scan_files"] = files_scanned
    audit.metadata["scan_bytes"] = bytes_scanned
    audit.metadata["credential_fingerprints"] = len(secret_patterns)
    audit.metadata["env_credential_fingerprints"] = len(env_candidates)
    audit.metadata["pdf_credential_fingerprints"] = len(pdf_candidates)
    audit.metadata["private_endpoint_fingerprints"] = len(build_private_endpoints)

    build_path_counts = {
        label.removeprefix("path:"): len(combined_hits[label])
        for label in combined_hits
        if label.startswith("path:")
    }
    if any(build_path_counts.values()):
        audit.warn(
            "non-shipping build paths",
            "build caches/results retain machine-local paths by design; they are excluded from the app and must remain local",
        )
    else:
        audit.pass_("non-shipping build paths", "no machine-local paths were found in the supplied scan roots")
    audit.metadata["build_path_file_counts"] = build_path_counts

    if build_private_endpoints:
        private_endpoint_files = set().union(*build_private_endpoints.values())
        audit.warn(
            "non-shipping private endpoints",
            f"{len(build_private_endpoints)} private endpoint fingerprint(s) occur in "
            f"{len(private_endpoint_files)} local build/test file(s), while the app bundle is clean",
        )
    else:
        audit.pass_("non-shipping private endpoints", "no private endpoint literal appears in supplied build outputs")

    env_key_patterns: dict[str, bytes] = {}
    for keys in credential_candidates.values():
        for key in keys:
            env_key_patterns[key] = key.encode("utf-8")
    env_key_hits, _, _ = scan_patterns(product_roots, env_key_patterns)
    shipped_key_names = sorted(key for key, paths in env_key_hits.items() if paths)
    audit.check(
        "credential key names",
        shipped_key_names in ([], ["ODPT_CONSUMER_KEY"]),
        "only the accepted empty ODPT developer-setting name is present in Release",
        f"unexpected credential key names are present: {', '.join(shipped_key_names)}",
    )
    audit.metadata["shipped_credential_key_names"] = shipped_key_names

    dsym_candidates = sorted((archive / "dSYMs").glob("*.dSYM"))
    audit.check(
        "dSYM inventory",
        len(dsym_candidates) == 1 and dsym_candidates[0].name == "Trainy.app.dSYM",
        "exactly one Trainy app dSYM is archived",
        f"expected one Trainy app dSYM, found {len(dsym_candidates)}",
    )
    dsym_binary = (
        dsym_candidates[0] / "Contents" / "Resources" / "DWARF" / executable_name
        if dsym_candidates
        else Path("/nonexistent")
    )
    app_uuid = run(["dwarfdump", "--uuid", str(executable)]) if executable.is_file() else None
    dsym_uuid = run(["dwarfdump", "--uuid", str(dsym_binary)]) if dsym_binary.is_file() else None
    uuid_re = re.compile(rb"UUID: ([0-9A-F-]+) \(arm64\)")
    app_uuid_match = uuid_re.search(app_uuid.stdout) if app_uuid and app_uuid.returncode == 0 else None
    dsym_uuid_match = uuid_re.search(dsym_uuid.stdout) if dsym_uuid and dsym_uuid.returncode == 0 else None
    uuids_match = bool(app_uuid_match and dsym_uuid_match and app_uuid_match.group(1) == dsym_uuid_match.group(1))
    audit.check(
        "app and dSYM UUID",
        uuids_match,
        "arm64 app and dSYM UUIDs match",
        "app and dSYM UUIDs do not match",
    )
    if app_uuid_match:
        audit.metadata["app_uuid"] = app_uuid_match.group(1).decode("ascii")

    dsym_user_hits, _, _ = scan_patterns(
        [("dSYM", path) for path in dsym_candidates], {"user home": b"/Users/"}
    )
    audit.check(
        "dSYM user metadata",
        not dsym_user_hits["user home"],
        "dSYM contains no user-home path",
        "dSYM contains a user-home path",
    )
    dsym_temp_hits, _, _ = scan_patterns(
        [("dSYM", path) for path in dsym_candidates],
        {"temporary compile path": b"/tmp/trainy"},
    )
    if dsym_temp_hits["temporary compile path"]:
        audit.warn(
            "dSYM compile paths",
            "temporary module/source paths remain in the developer-only symbol file for complete symbolication; credential fingerprints did not match",
        )

    relocation_maps = sorted(archive.glob("dSYMs/*.dSYM/Contents/Resources/Relocations/**/*.yml"))
    relocation_ok = bool(relocation_maps) and all(
        b"binary-path:     '/Trainy.app/" in path.read_bytes() for path in relocation_maps
    )
    audit.check(
        "dSYM relocation metadata",
        relocation_ok,
        "absolute dSYM binary input path is normalized",
        "dSYM relocation map is missing or retains an unnormalized binary path",
    )

    signing = run(["codesign", "-dvv", str(app)])
    is_signed = signing.returncode == 0
    embedded_profiles = list(app.rglob("embedded.mobileprovision"))
    entitlement_files = list(app.rglob("*.entitlements"))
    audit.check(
        "embedded provisioning and entitlement files",
        not embedded_profiles and not entitlement_files,
        "no provisioning profile or entitlement source file is embedded",
        "an embedded provisioning profile or entitlement source file is present",
    )
    if is_signed:
        entitlements_result = run(["codesign", "-d", "--entitlements", ":-", str(app)])
        entitlement_keys: list[str] = []
        if entitlements_result.returncode == 0:
            try:
                entitlements = plistlib.loads(entitlements_result.stdout)
                if isinstance(entitlements, dict):
                    entitlement_keys = sorted(entitlements)
            except plistlib.InvalidFileException:
                pass
        audit.pass_("code signing", f"app is signed; entitlement key count: {len(entitlement_keys)}")
        audit.metadata["entitlement_keys"] = entitlement_keys
    else:
        audit.warn(
            "code signing",
            "archive is intentionally unsigned because this host has no signing identity or provisioning profile; distribution signing remains external",
        )

    dynamic_dependencies = run(["otool", "-L", str(executable)]) if executable.is_file() else None
    dynamic_ok = False
    dependency_count = 0
    if dynamic_dependencies and dynamic_dependencies.returncode == 0:
        lines = dynamic_dependencies.stdout.decode("utf-8", errors="replace").splitlines()[1:]
        dependency_paths = [line.strip().split(" ", 1)[0] for line in lines if line.strip()]
        dependency_count = len(dependency_paths)
        dynamic_ok = all(path.startswith(("/System/Library/", "/usr/lib/")) for path in dependency_paths)
    audit.check(
        "dynamic dependency boundary",
        dynamic_ok,
        f"all {dependency_count} dynamic dependencies are Apple system libraries",
        "a non-system dynamic dependency is linked",
    )

    resolved = json.loads((ROOT / "TrainyIOS" / "Trainy.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved").read_text(encoding="utf-8"))
    pins = resolved.get("pins", [])
    firebase_versions = [
        pin.get("state", {}).get("version")
        for pin in pins
        if pin.get("identity") == "firebase-ios-sdk"
    ]
    audit.check(
        "Firebase dependency pin",
        firebase_versions == ["12.15.0"],
        "Firebase iOS SDK is pinned to 12.15.0",
        "Firebase iOS SDK pin differs from 12.15.0",
    )

    if args.result_bundle:
        result_bundle = args.result_bundle.resolve()
        result = run(
            [
                "xcrun",
                "xcresulttool",
                "get",
                "log",
                "--type",
                "build",
                "--compact",
                "--path",
                str(result_bundle),
            ]
        )
        if result.returncode != 0:
            audit.fail("archive build evidence", "could not read the result bundle build log")
        else:
            build_log = result.stdout
            validate_markers = build_log.count(b"--validate")
            upload_markers = sum(
                build_log.count(marker)
                for marker in (b"dSYM upload complete", b"Successfully uploaded", b"Sending build event")
            )
            audit.check(
                "Crashlytics archive phase",
                b"TRAINY_CRASHLYTICS_VALIDATE_ONLY" in build_log
                and validate_markers > 0
                and upload_markers == 0,
                f"result bundle records validation-only Crashlytics handling ({validate_markers} validation markers, 0 upload markers)",
                "result bundle does not prove validation-only Crashlytics handling",
            )

    audit.metadata.update(
        {
            "archive": str(archive),
            "archive_sha256": hash_tree(archive),
            "app_binary_sha256": hash_file(executable) if executable.is_file() else None,
            "dsym_binary_sha256": hash_file(dsym_binary) if dsym_binary.is_file() else None,
            "archive_version": archive_info.get("ArchiveVersion"),
            "xcode_build": app_info.get("DTXcodeBuild"),
            "sdk": app_info.get("DTSDKName"),
            "signed": is_signed,
            "privacy_manifest_count": len(privacy_paths),
            "permission_description_keys": usage_keys,
            "extension_count": len(extensions),
            "embedded_framework_count": len(frameworks),
        }
    )
    return audit


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--result-bundle", type=Path)
    parser.add_argument("--scan-root", type=Path, action="append", default=[])
    parser.add_argument("--credential-pdf", type=Path)
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()

    audit = audit_archive(args)
    failures = sum(check.status == "fail" for check in audit.checks)
    warnings = sum(check.status == "warning" for check in audit.checks)
    for check in audit.checks:
        print(f"[{check.status.upper()}] {check.name}: {check.detail}")
    print(f"SUMMARY failures={failures} warnings={warnings} checks={len(audit.checks)}")

    report = {
        "result": "fail" if failures else "pass_with_limitations" if warnings else "pass",
        "checks": [asdict(check) for check in audit.checks],
        "metadata": audit.metadata,
    }
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
