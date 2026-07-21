#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASTER="$ROOT/out/trainy-launch-master-4k.mp4"
REVIEW="$ROOT/out/trainy-launch-review-1080p.mp4"
POSTER="$ROOT/out/trainy-launch-poster.png"

for file in "$MASTER" "$REVIEW" "$POSTER"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing expected output: $file" >&2
    exit 1
  fi
done

read_video_value() {
  local file="$1"
  local entry="$2"
  ffprobe -v error -select_streams v:0 -show_entries "stream=$entry" -of default=noprint_wrappers=1:nokey=1 "$file"
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "$label: expected $expected, got $actual" >&2
    exit 1
  fi
}

assert_equal "$(read_video_value "$MASTER" width)" "3840" "Master width"
assert_equal "$(read_video_value "$MASTER" height)" "2160" "Master height"
assert_equal "$(read_video_value "$MASTER" codec_name)" "h264" "Master codec"
assert_equal "$(read_video_value "$MASTER" pix_fmt)" "yuv420p" "Master pixel format"
assert_equal "$(read_video_value "$MASTER" avg_frame_rate)" "30/1" "Master frame rate"
assert_equal "$(read_video_value "$REVIEW" width)" "1920" "Review width"
assert_equal "$(read_video_value "$REVIEW" height)" "1080" "Review height"
assert_equal "$(read_video_value "$REVIEW" avg_frame_rate)" "30/1" "Review frame rate"

for file in "$MASTER" "$REVIEW"; do
  duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")"
  awk -v duration="$duration" 'BEGIN { if (duration < 89.95 || duration > 90.05) exit 1 }' || {
    echo "Unexpected duration for $file: $duration" >&2
    exit 1
  }
  assert_equal "$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file")" "aac" "Audio codec"
  assert_equal "$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$file")" "48000" "Audio sample rate"
  assert_equal "$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$file")" "2" "Audio channels"
  ffmpeg -v error -i "$file" -f null -
done

poster_size="$(sips -g pixelWidth -g pixelHeight "$POSTER" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')"
assert_equal "$poster_size" "3840x2160" "Poster dimensions"

echo "Media validation passed: 90.00s, 30 fps, H.264 yuv420p, AAC stereo at 48 kHz, 4K master, 1080p review, 4K poster."
