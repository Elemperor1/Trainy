#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p public/stills

render_still() {
  local label="$1"
  local frame="$2"
  npx remotion still TrainyLaunch "public/stills/$label.png" --frame="$frame"
}

render_still scene-01-question 120
render_still scene-02-meet-your-train 360
render_still scene-03-tokyo-shin-osaka 780
render_still scene-04-utrecht 1630
render_still scene-05-clear-fallback 1710
render_still scene-06-accessibility 1798
render_still scene-07-build-week-privacy 1885
render_still scene-08-final-product 2010
render_still scene-09-end-identity 2400
render_still scene-10-credit 2600

echo "Rendered representative 4K stills for the continuous journey and credit."
