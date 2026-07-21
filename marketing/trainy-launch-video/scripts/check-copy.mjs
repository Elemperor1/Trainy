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

const source = await readFile(new URL("../src/copy.ts", import.meta.url), "utf8");
let previousIndex = -1;

for (const value of expectedJourneyCopy) {
  const index = source.indexOf(JSON.stringify(value), previousIndex + 1);
  if (index === -1) {
    throw new Error(`Missing or out-of-order launch-film copy: ${value}`);
  }
  if (wordCount(value) > 7) {
    throw new Error(`Main launch-film line exceeds seven words: ${value}`);
  }
  previousIndex = index;
}

if (!source.includes(JSON.stringify(requiredCredit))) {
  throw new Error(`Missing required final credit: ${requiredCredit}`);
}

stdout.write(
  `Copy contract passed: ${expectedJourneyCopy.length} ordered lines, word limits, and final credit verified.\n`,
);
