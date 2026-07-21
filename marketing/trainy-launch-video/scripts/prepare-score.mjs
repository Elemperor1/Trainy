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
    `apad=pad_dur=3,atrim=duration=${durationSeconds},loudnorm=I=-15:TP=-1.2:LRA=7`,
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
  `Prepared licensed upbeat score: ${durationSeconds}s, ${sampleRate} Hz stereo, -15 LUFS target\n`,
);
