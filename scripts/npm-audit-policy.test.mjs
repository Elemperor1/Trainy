import assert from "node:assert/strict";
import test from "node:test";

import {
  evaluateProject,
  extractAdvisories,
  findUnlistedProjects,
  normalizeAdvisoryId,
  PolicyError,
  AuditUnavailableError,
  severityRank,
  validatePolicy,
} from "./npm-audit-policy.mjs";

const TODAY = new Date("2026-10-07T12:00:00Z");

function policy(overrides = {}) {
  return {
    thresholds: { production: "high", development: "critical" },
    maxAllowanceDays: 180,
    projects: [{ path: "app" }, { path: "tools", tooling: true }],
    allowlist: [],
    ...overrides,
  };
}

function advisory(overrides = {}) {
  return {
    id: "GHSA-aaaa-bbbb-cccc",
    package: "left-pad",
    severity: "high",
    title: "Example advisory",
    url: "https://github.com/advisories/GHSA-aaaa-bbbb-cccc",
    range: "<1.0.0",
    ...overrides,
  };
}

// Trimmed from a real `npm audit --json` run (auditReportVersion 2): one package
// carries the advisory object, the package that depends on it only names it.
const REAL_REPORT = {
  auditReportVersion: 2,
  vulnerabilities: {
    "@vitest/mocker": {
      name: "@vitest/mocker",
      severity: "moderate",
      via: [
        {
          source: 1193684,
          name: "@vitest/mocker",
          title: "Vitest: Path Traversal / Arbitrary File Read via @vitest/mocker Redirect Mock",
          url: "https://github.com/advisories/GHSA-82fw-gwwq-j7x9",
          severity: "moderate",
          range: ">=2.1.0 <4.1.11",
        },
      ],
    },
    vitest: {
      name: "vitest",
      severity: "moderate",
      via: [
        "@vitest/mocker",
        {
          source: 1193683,
          name: "vitest",
          title: "Vitest: Path Traversal / Arbitrary File Read via @vitest/mocker Redirect Mock",
          url: "https://github.com/advisories/GHSA-82fw-gwwq-j7x9",
          severity: "moderate",
          range: ">=2.1.0 <4.1.11",
        },
      ],
    },
  },
};

test("extractAdvisories keeps one record per package and advisory and skips pointer strings", () => {
  const found = extractAdvisories(REAL_REPORT);
  assert.deepEqual(
    found.map((item) => [item.package, item.id, item.severity]).sort(),
    [
      ["@vitest/mocker", "GHSA-82fw-gwwq-j7x9", "moderate"],
      ["vitest", "GHSA-82fw-gwwq-j7x9", "moderate"],
    ],
  );
});

test("extractAdvisories falls back to the npm advisory number when there is no GHSA id", () => {
  const found = extractAdvisories({
    vulnerabilities: { old: { via: [{ source: 42, name: "old", severity: "low", url: "https://example.test/42" }] } },
  });
  assert.equal(found[0].id, "npm-42");
});

test("extractAdvisories treats an empty report as no advisories and an error report as unavailable", () => {
  assert.deepEqual(extractAdvisories({ auditReportVersion: 2, vulnerabilities: {} }), []);
  assert.throws(
    () => extractAdvisories({ error: { code: "ENOAUDIT", summary: "registry down" } }),
    AuditUnavailableError,
  );
});

test("normalizeAdvisoryId compares GHSA ids case-insensitively", () => {
  assert.equal(normalizeAdvisoryId("GHSA-82FW-GWWQ-J7X9"), "GHSA-82fw-gwwq-j7x9");
  assert.equal(normalizeAdvisoryId("ghsa-82fw-gwwq-j7x9"), "GHSA-82fw-gwwq-j7x9");
  assert.equal(normalizeAdvisoryId("npm-42"), "npm-42");
});

test("severityRank orders severities and rejects unknown ones", () => {
  assert.ok(severityRank("critical") > severityRank("high"));
  assert.ok(severityRank("high") > severityRank("moderate"));
  assert.throws(() => severityRank("catastrophic"), PolicyError);
});

test("production advisories fail at high and tooling advisories only at critical", () => {
  const high = advisory({ package: "next", id: "GHSA-2222-3333-4444" });
  const toolingHigh = advisory({ package: "wrangler", id: "GHSA-bbbb-cccc-dddd" });
  const toolingCritical = advisory({ package: "esbuild", id: "GHSA-cccc-dddd-ffff", severity: "critical" });
  const result = evaluateProject({
    project: { path: "app" },
    all: [high, toolingHigh, toolingCritical],
    production: [high],
    policy: policy(),
    today: TODAY,
  });
  assert.deepEqual(result.failures.map((item) => item.package).sort(), ["esbuild", "next"]);
  assert.deepEqual(result.belowThreshold.map((item) => item.package), ["wrangler"]);
  assert.equal(result.belowThreshold[0].dependencyClass, "development");
});

test("a production moderate advisory is below threshold", () => {
  const moderate = advisory({ severity: "moderate" });
  const result = evaluateProject({
    project: { path: "app" },
    all: [moderate],
    production: [moderate],
    policy: policy(),
    today: TODAY,
  });
  assert.equal(result.failures.length, 0);
  assert.equal(result.belowThreshold.length, 1);
});

test("a tooling-only project never counts as production, even if npm says so", () => {
  const high = advisory();
  const result = evaluateProject({
    project: { path: "tools", tooling: true },
    all: [high],
    production: [high],
    policy: policy(),
    today: TODAY,
  });
  assert.equal(result.failures.length, 0);
  assert.equal(result.belowThreshold[0].dependencyClass, "development");
});

test("the real vitest report passes: moderate tooling advisories are below the critical threshold", () => {
  const all = extractAdvisories(REAL_REPORT);
  const result = evaluateProject({ project: { path: "app" }, all, production: [], policy: policy(), today: TODAY });
  assert.equal(result.failures.length, 0);
  assert.equal(result.belowThreshold.length, 2);
});

test("a current exception allows an over-threshold advisory and reports its reason", () => {
  const critical = advisory({ severity: "critical" });
  const exception = {
    advisory: "ghsa-aaaa-bbbb-cccc",
    reason: "Dev server only; no fixed release exists upstream yet.",
    expires: "2026-12-31",
  };
  const result = evaluateProject({
    project: { path: "app" },
    all: [critical],
    production: [],
    policy: policy({ allowlist: [exception] }),
    today: TODAY,
  });
  assert.equal(result.failures.length, 0);
  assert.equal(result.allowed[0].entry, exception);
});

test("an expired exception fails again and is reported as expired", () => {
  const critical = advisory({ severity: "critical" });
  const exception = {
    advisory: "GHSA-aaaa-bbbb-cccc",
    reason: "Dev server only; no fixed release exists upstream yet.",
    expires: "2026-10-06",
  };
  const result = evaluateProject({
    project: { path: "app" },
    all: [critical],
    production: [],
    policy: policy({ allowlist: [exception] }),
    today: TODAY,
  });
  assert.equal(result.failures.length, 1);
  assert.equal(result.failures[0].expiredOn, "2026-10-06");
  assert.deepEqual(result.expiredAllowances, [exception]);
});

test("an exception scoped to another project does not apply, and unused exceptions are reported", () => {
  const critical = advisory({ severity: "critical" });
  const exception = {
    advisory: "GHSA-aaaa-bbbb-cccc",
    project: "tools",
    reason: "Dev server only; no fixed release exists upstream yet.",
    expires: "2026-12-31",
  };
  const forApp = evaluateProject({
    project: { path: "app" },
    all: [critical],
    production: [],
    policy: policy({ allowlist: [exception] }),
    today: TODAY,
  });
  assert.equal(forApp.failures.length, 1);
  assert.deepEqual(forApp.unusedAllowances, []);

  const forTools = evaluateProject({
    project: { path: "tools", tooling: true },
    all: [],
    production: [],
    policy: policy({ allowlist: [exception] }),
    today: TODAY,
  });
  assert.deepEqual(forTools.unusedAllowances, [exception]);
});

test("validatePolicy accepts the shipped policy shape", () => {
  assert.doesNotThrow(() => validatePolicy(policy(), TODAY));
});

test("validatePolicy rejects weak or malformed exceptions", () => {
  const cases = [
    [{ advisory: "CVE-2026-0001", reason: "x".repeat(30), expires: "2026-12-01" }, /advisory id/],
    [{ advisory: "GHSA-aaaa-bbbb-cccc", reason: "too short", expires: "2026-12-01" }, /reason/],
    [{ advisory: "GHSA-aaaa-bbbb-cccc", reason: "x".repeat(30), expires: "soon" }, /YYYY-MM-DD/],
    [{ advisory: "GHSA-aaaa-bbbb-cccc", reason: "x".repeat(30), expires: "2028-01-01" }, /days away/],
    [{ advisory: "GHSA-aaaa-bbbb-cccc", reason: "x".repeat(30), expires: "2026-12-01", project: "nope" }, /not a project/],
  ];
  for (const [entry, pattern] of cases) {
    assert.throws(() => validatePolicy(policy({ allowlist: [entry] }), TODAY), pattern);
  }
});

test("validatePolicy rejects unknown thresholds and an empty project list", () => {
  assert.throws(() => validatePolicy(policy({ thresholds: { production: "severe", development: "critical" } }), TODAY), /thresholds.production/);
  assert.throws(() => validatePolicy(policy({ projects: [] }), TODAY), /at least one/);
});

test("findUnlistedProjects reports lockfiles outside the policy and ignores listed ones", () => {
  const lockfiles = ["app/package-lock.json", "tools/package-lock.json", "marketing/new-site/package-lock.json"];
  assert.deepEqual(findUnlistedProjects(lockfiles, policy()), ["marketing/new-site"]);
  assert.deepEqual(findUnlistedProjects(["package-lock.json"], policy()), ["."]);
  assert.deepEqual(findUnlistedProjects([], policy()), []);
});
