import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { stdout } from "node:process";

const durationSeconds = 90;
const sampleRate = 48_000;
const sourcePath = resolve(
  "public/audio/energetic-upbeat-future-bass-bombinsound.mp3",
);
const outputPath = resolve("public/audio/trainy-score.m4a");

mkdirSync(dirname(outputPath), { recursive: true });

/** Reads and validates the source duration before starting the encode. */
function probeDuration(path) {
  const probe = spawnSync(
    "ffprobe",
    [
      "-v",
      "error",
      "-show_entries",
      "format=duration",
      "-of",
      "default=noprint_wrappers=1:nokey=1",
      path,
    ],
    { encoding: "utf8" },
  );

  if (probe.status !== 0) {
    const detail =
      probe.error?.message || probe.stderr?.trim() || `exit status ${probe.status}`;
    throw new Error(`ffprobe could not read the source score: ${detail}`);
  }

  const duration = Number.parseFloat(probe.stdout);
  if (!Number.isFinite(duration) || duration <= 0) {
    throw new Error(`ffprobe returned an invalid source duration: ${probe.stdout.trim()}`);
  }
  return duration;
}

const sourceDuration = probeDuration(sourcePath);
const ffmpeg = spawnSync(
  "ffmpeg",
  [
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-i",
    sourcePath,
    "-af",
    `apad=whole_dur=${durationSeconds},atrim=duration=${durationSeconds},loudnorm=I=-15:TP=-1.2:LRA=7`,
    "-ar",
    String(sampleRate),
    "-ac",
    "2",
    "-c:a",
    "aac",
    "-b:a",
    "320k",
    "-movflags",
    "+faststart",
    outputPath,
  ],
  { stdio: "inherit" },
);

if (ffmpeg.status !== 0) {
  throw new Error(`ffmpeg failed with exit status ${ffmpeg.status}`);
}

stdout.write(
  `Prepared ${sourceDuration.toFixed(2)}s licensed source as ${durationSeconds}s, ${sampleRate} Hz stereo, -15 LUFS target\n`,
);
