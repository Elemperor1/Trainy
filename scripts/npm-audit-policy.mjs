#!/usr/bin/env node
// npm audit policy for Trainy's npm projects.
//
//   * Advisories in production dependencies fail the check at `high` or above.
//   * Advisories that only reach development tooling fail it at `critical`.
//   * A documented exception in scripts/npm-audit-policy.json suppresses one
//     advisory until its expiry date; an expired exception fails again.
//
// `npm audit --audit-level` cannot tell production from tooling, so a single
// advisory in wrangler, vitest, or Remotion used to fail every pull request and
// skip the iOS build and tests behind it. The policy keeps that signal at the
// severity where it matters and keeps shipped dependencies strict.
//
// Usage:
//   node scripts/npm-audit-policy.mjs                  audit every project in the policy
//   node scripts/npm-audit-policy.mjs <project-path>   audit one project
//   node scripts/npm-audit-policy.mjs --policy <file>  use another policy file
//
// Exit status: 0 policy satisfied, 1 policy violated, 2 audit could not run.

import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const SEVERITIES = ["info", "low", "moderate", "high", "critical"];

const GHSA_PATTERN = /GHSA(?:-[0-9a-z]{4}){3}/i;
const GHSA_EXACT = /^GHSA(?:-[0-9a-z]{4}){3}$/i;
const MIN_REASON_LENGTH = 20;
const DAY_MS = 24 * 60 * 60 * 1000;

export class PolicyError extends Error {}
export class AuditUnavailableError extends Error {}

/** GitHub advisory ids are `GHSA` plus lowercase groups; compare them in that one form. */
export function normalizeAdvisoryId(id) {
  return GHSA_EXACT.test(id) ? `GHSA${id.slice(4).toLowerCase()}` : id;
}

export function severityRank(severity) {
  const rank = SEVERITIES.indexOf(severity);
  if (rank === -1) {
    throw new PolicyError(`Unknown severity "${severity}"; expected one of ${SEVERITIES.join(", ")}.`);
  }
  return rank;
}

/** Flatten an `npm audit --json` (report version 2) document into one record per advisory and package. */
export function extractAdvisories(report) {
  if (report?.error) {
    const detail = report.error.summary ?? report.error.code ?? "unknown error";
    throw new AuditUnavailableError(`npm audit reported an error: ${detail}`);
  }
  const found = new Map();
  for (const [name, vulnerability] of Object.entries(report?.vulnerabilities ?? {})) {
    for (const via of vulnerability.via ?? []) {
      // A string names the package this one is vulnerable through; the advisory
      // itself is the object recorded on that other package.
      if (typeof via !== "object" || via === null) continue;
      const ghsa = (via.url ?? "").match(GHSA_PATTERN)?.[0];
      const id = ghsa ? normalizeAdvisoryId(ghsa) : via.source === undefined ? undefined : `npm-${via.source}`;
      if (!id) continue;
      const pkg = via.name ?? name;
      const key = `${pkg}|${id}`;
      if (!found.has(key)) {
        found.set(key, {
          id,
          package: pkg,
          severity: via.severity,
          title: via.title ?? "(no title)",
          url: via.url ?? "",
          range: via.range ?? "",
        });
      }
    }
  }
  return [...found.values()];
}

export function advisoryKey(advisory) {
  return `${advisory.package}|${normalizeAdvisoryId(advisory.id)}`;
}

/** Directories that hold a package-lock.json the policy does not list, so a new npm project cannot skip the audit. */
export function findUnlistedProjects(lockfilePaths, policy) {
  const listed = new Set(policy.projects.map((project) => project.path));
  return lockfilePaths.map((file) => path.posix.dirname(file)).filter((directory) => !listed.has(directory));
}

/** Validate the policy document and return it unchanged, or throw with every problem found. */
export function validatePolicy(policy, today = new Date()) {
  const problems = [];
  for (const kind of ["production", "development"]) {
    if (!SEVERITIES.includes(policy?.thresholds?.[kind])) {
      problems.push(`thresholds.${kind} must be one of ${SEVERITIES.join(", ")}`);
    }
  }
  if (!Number.isInteger(policy?.maxAllowanceDays) || policy.maxAllowanceDays < 1) {
    problems.push("maxAllowanceDays must be a positive integer");
  }
  if (!Array.isArray(policy?.projects) || policy.projects.length === 0) {
    problems.push("projects must list at least one npm project");
  }
  for (const project of policy?.projects ?? []) {
    if (typeof project.path !== "string" || project.path.length === 0) {
      problems.push("every project needs a path");
    }
  }
  if (!Array.isArray(policy?.allowlist)) {
    problems.push("allowlist must be an array");
  }
  for (const [index, entry] of (policy?.allowlist ?? []).entries()) {
    const label = `allowlist[${index}]`;
    if (!GHSA_EXACT.test(entry.advisory ?? "")) {
      problems.push(`${label}.advisory must be a GitHub advisory id such as GHSA-xxxx-xxxx-xxxx`);
    }
    if (typeof entry.reason !== "string" || entry.reason.trim().length < MIN_REASON_LENGTH) {
      problems.push(`${label}.reason must explain the exception in at least ${MIN_REASON_LENGTH} characters`);
    }
    const expires = parseDate(entry.expires);
    if (!expires) {
      problems.push(`${label}.expires must be a YYYY-MM-DD date`);
    } else if (Number.isInteger(policy?.maxAllowanceDays)) {
      const horizon = today.getTime() + policy.maxAllowanceDays * DAY_MS;
      if (expires.getTime() > horizon) {
        problems.push(`${label}.expires is more than ${policy.maxAllowanceDays} days away; review exceptions sooner`);
      }
    }
    if (entry.project !== undefined && !(policy.projects ?? []).some((project) => project.path === entry.project)) {
      problems.push(`${label}.project "${entry.project}" is not a project in this policy`);
    }
  }
  if (problems.length > 0) {
    throw new PolicyError(`Invalid npm audit policy:\n  - ${problems.join("\n  - ")}`);
  }
  return policy;
}

function parseDate(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return undefined;
  const date = new Date(`${value}T23:59:59Z`);
  return Number.isNaN(date.getTime()) ? undefined : date;
}

/**
 * Apply the policy to one project.
 *
 * `all` is every advisory `npm audit` reports; `production` is the subset that
 * reaches production dependencies (`npm audit --omit=dev`). Anything in `all`
 * but not in `production` is development tooling.
 */
export function evaluateProject({ project, all, production, policy, today = new Date() }) {
  const productionKeys = new Set(production.map(advisoryKey));
  const result = {
    project: project.path,
    failures: [],
    allowed: [],
    belowThreshold: [],
    expiredAllowances: [],
    unusedAllowances: [],
  };
  const matchedEntries = new Set();

  for (const advisory of all) {
    const dependencyClass = !project.tooling && productionKeys.has(advisoryKey(advisory)) ? "production" : "development";
    const finding = { ...advisory, dependencyClass };
    const threshold = policy.thresholds[dependencyClass];
    if (severityRank(advisory.severity) < severityRank(threshold)) {
      result.belowThreshold.push(finding);
      continue;
    }
    const entry = policy.allowlist.find(
      (candidate) =>
        normalizeAdvisoryId(candidate.advisory) === normalizeAdvisoryId(advisory.id) &&
        (candidate.project === undefined || candidate.project === project.path),
    );
    if (!entry) {
      result.failures.push(finding);
      continue;
    }
    matchedEntries.add(entry);
    if (parseDate(entry.expires).getTime() < today.getTime()) {
      result.failures.push({ ...finding, expiredOn: entry.expires });
      result.expiredAllowances.push(entry);
    } else {
      result.allowed.push({ ...finding, entry });
    }
  }

  result.unusedAllowances = policy.allowlist.filter(
    (entry) => (entry.project === undefined || entry.project === project.path) && !matchedEntries.has(entry),
  );
  return result;
}

function runAudit(cwd, omitDev) {
  const args = ["audit", "--json", ...(omitDev ? ["--omit=dev"] : [])];
  const run = spawnSync("npm", args, { cwd, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (run.error) {
    throw new AuditUnavailableError(`could not run npm in ${cwd}: ${run.error.message}`);
  }
  // npm exits non-zero when it finds vulnerabilities but still prints the report.
  try {
    return JSON.parse(run.stdout);
  } catch {
    const detail = (run.stderr || run.stdout || "no output").trim().split("\n").slice(0, 5).join(" | ");
    throw new AuditUnavailableError(`npm audit in ${cwd} did not return JSON: ${detail}`);
  }
}

/** Tracked package-lock.json paths, or undefined when this is not a git checkout. */
function trackedLockfiles(repoRoot) {
  const run = spawnSync("git", ["ls-files", "--", "*package-lock.json"], { cwd: repoRoot, encoding: "utf8" });
  if (run.error || run.status !== 0) return undefined;
  return run.stdout.split("\n").filter(Boolean);
}

function describe(finding) {
  return `${finding.severity.toUpperCase()} ${finding.id} ${finding.package} (${finding.dependencyClass}): ${finding.title}`;
}

function annotate(level, message) {
  if (process.env.GITHUB_ACTIONS === "true") {
    console.log(`::${level} title=npm audit policy::${message.replace(/\r?\n/g, " ")}`);
  }
}

function main(argv) {
  const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  let policyPath = path.join(repoRoot, "scripts", "npm-audit-policy.json");
  const selected = [];
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--policy") {
      policyPath = path.resolve(argv[(index += 1)] ?? "");
    } else if (argv[index].startsWith("--")) {
      console.error(`Unknown option ${argv[index]}`);
      return 2;
    } else {
      selected.push(argv[index].replace(/\/$/, ""));
    }
  }

  const today = new Date();
  const policy = validatePolicy(JSON.parse(readFileSync(policyPath, "utf8")), today);
  const projects = selected.length === 0 ? policy.projects : policy.projects.filter((p) => selected.includes(p.path));
  const unknown = selected.filter((name) => !policy.projects.some((p) => p.path === name));
  if (unknown.length > 0) {
    console.error(`Not in the policy: ${unknown.join(", ")}`);
    return 2;
  }

  console.log(
    `npm audit policy: production fails at ${policy.thresholds.production}, development tooling at ${policy.thresholds.development}.`,
  );
  let failed = 0;
  if (selected.length === 0) {
    const lockfiles = trackedLockfiles(repoRoot);
    if (lockfiles === undefined) {
      console.log("Skipping the lockfile completeness check: this is not a git checkout.");
    }
    for (const directory of findUnlistedProjects(lockfiles ?? [], policy)) {
      const message = `${directory} has a package-lock.json that scripts/npm-audit-policy.json does not list; add it as a project.`;
      console.log(`\nFAIL     ${message}`);
      annotate("error", message);
      failed += 1;
    }
  }
  for (const project of projects) {
    const cwd = path.join(repoRoot, project.path);
    const all = extractAdvisories(runAudit(cwd, false));
    const production = project.tooling ? [] : extractAdvisories(runAudit(cwd, true));
    const result = evaluateProject({ project, all, production, policy, today });

    console.log(`\n${project.path}${project.tooling ? " (tooling only)" : ""}: ${all.length} advisories`);
    for (const finding of result.failures) {
      const expired = finding.expiredOn ? ` [exception expired ${finding.expiredOn}]` : "";
      console.log(`  FAIL     ${describe(finding)}${expired}\n           ${finding.url}`);
      annotate("error", `${project.path}: ${describe(finding)}${expired}`);
    }
    for (const finding of result.allowed) {
      console.log(`  ALLOWED  ${describe(finding)}\n           until ${finding.entry.expires}: ${finding.entry.reason}`);
    }
    for (const entry of result.unusedAllowances) {
      console.log(`  UNUSED   exception for ${entry.advisory} no longer matches an advisory here; remove it.`);
      annotate("warning", `${project.path}: unused npm audit exception ${entry.advisory}`);
    }
    if (result.belowThreshold.length > 0) {
      const counts = {};
      for (const finding of result.belowThreshold) {
        const bucket = `${finding.dependencyClass} ${finding.severity}`;
        counts[bucket] = (counts[bucket] ?? 0) + 1;
      }
      const summary = Object.entries(counts).map(([bucket, count]) => `${count} ${bucket}`).join(", ");
      console.log(`  below threshold: ${summary}`);
    }
    if (result.failures.length === 0) console.log("  ok");
    failed += result.failures.length;
  }

  console.log(failed === 0 ? "\nnpm audit policy satisfied." : `\nnpm audit policy violated: ${failed} finding(s) over threshold or outside the policy.`);
  return failed === 0 ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (error) {
    if (error instanceof PolicyError) {
      console.error(error.message);
      process.exitCode = 1;
    } else {
      console.error(`npm audit policy could not run: ${error.message}`);
      process.exitCode = 2;
    }
  }
}
