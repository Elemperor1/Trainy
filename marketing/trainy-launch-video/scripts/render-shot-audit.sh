#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$ROOT/public/stills/shot-audit"
mkdir -p "$OUTPUT"
cd "$ROOT"

frames=(
  52 120 183 245 360 445 520
  630 780 900 1033 1130 1210 1320
  1440 1535 1660 1670 1710 1798 1838
  1885 1930 1945 2010 2081 2143 2257
  2476 2600
)

index=1
for frame in "${frames[@]}"; do
  label="$(printf '%02d' "$index")"
  npx remotion still TrainyLaunch "$OUTPUT/shot-$label.png" --frame="$frame" --scale=0.5
  index=$((index + 1))
done

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -y -hide_banner -loglevel error \
    -framerate 1 \
    -i "$OUTPUT/shot-%02d.png" \
    -vf "scale=384:216,tile=6x5:margin=3:padding=3:color=0x080B0D" \
    -frames:v 1 \
    -update 1 \
    "$OUTPUT/contact-sheet.jpg"
elif command -v magick >/dev/null 2>&1; then
  magick montage "$OUTPUT"/shot-*.png \
    -thumbnail 384x216 \
    -tile 6x5 \
    -geometry +3+3 \
    -background '#080B0D' \
    "$OUTPUT/contact-sheet.jpg"
fi

echo "Rendered ${#frames[@]} internal-shot midpoint stills."
