import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { stdout } from "node:process";
import { URL } from "node:url";

const expectedJourneyCopy = [
  "Going somewhere?",
  "Meet your train.",
  "Tokyo → Shin‑Osaka",
  "Nozomi 231 · 09:21",
  "Utrecht Centraal",
  "What leaves next?",
  "Live when it’s live.",
  "Clear when it isn’t.",
  "Built with Codex + GPT‑5.6",
  "Trainy",
  "Know before you go.",
];
const requiredCredit = "Created with GPT‑5.6 Sol + Skills";

/** Counts copy words using whitespace-delimited editorial tokens. */
function wordCount(value) {
  return value.trim().split(/\s+/u).filter(Boolean).length;
}

const contract = JSON.parse(
  await readFile(new URL("../src/copy.json", import.meta.url), "utf8"),
);
const actualJourneyCopy = [
  contract.hook,
  contract.welcome,
  contract.japan.route,
  contract.japan.trip,
  contract.netherlands.station,
  contract.netherlands.question,
  contract.availability.live,
  contract.availability.unavailable,
  contract.build.line,
  contract.brand,
  contract.tagline,
];

assert.deepEqual(actualJourneyCopy, expectedJourneyCopy, "Journey copy must match the ordered contract");

for (const value of actualJourneyCopy) {
  if (wordCount(value) > 7) {
    throw new Error(`Main launch-film line exceeds seven words: ${value}`);
  }
}

assert.equal(contract.credit, requiredCredit, "Final credit must match the required wording");
assert.equal(
  Object.keys(contract).at(-1),
  "credit",
  "The required credit must be the final structured copy entry",
);

stdout.write(
  `Copy contract passed: ${expectedJourneyCopy.length} ordered lines, word limits, and final credit verified.\n`,
);
