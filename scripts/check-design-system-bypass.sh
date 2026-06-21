#!/usr/bin/env bash
# =============================================================================
# check-design-system-bypass.sh
# Guardrail: ensures all UI routes through the unified Design System library
# with no bypassing. Run locally and in CI. Exits non-zero on violations.
#
# iOS (SwiftUI) rules — outside the library files, screens must NOT:
#   * define raw color literals (Color(red:/UIColor(red:)
#   * call .glassEffect( directly (use the railLiquidGlass() library modifier)
#   * use RoundedRectangle(cornerRadius: <number>) (use RailDesign.Radius.*)
#   * use Color.black / Color.white / Color.gray (use RailDesign.Palette.*)
# A line may be exempted for a legitimate canvas/primitive by appending:
#   // ds-allow: <reason>
#
# Library files (excluded from scanning):
#   Sources/TrainyCore/RailDesignSystem.swift
#   Sources/TrainyCore/RailComponents.swift
#   Sources/TrainyCore/DesignSystem/**
#
# Web rules:
#   * app.js must not construct component HTML inline — all markup comes from
#     components.js (TrainyUI.* factories).
#   * styles.css must not hardcode hex/rgba outside the :root token layer.
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS=0
VIOLATIONS=0

add_violation() {
  printf '  FAIL  %s\n' "$1"
  VIOLATIONS=$((VIOLATIONS + 1))
  STATUS=1
}

# Gather iOS Swift files, excluding the design-system library.
ios_files=()
while IFS= read -r f; do
  ios_files+=("$f")
done < <(find "$ROOT_DIR/Sources/TrainyCore" -name '*.swift' \
  | grep -v '/RailDesignSystem.swift$' \
  | grep -v '/RailComponents.swift$' \
  | grep -v '/DesignSystem/')

echo "Checking iOS design-system bypass across ${#ios_files[@]} non-library Swift files..."

for f in "${ios_files[@]}"; do
  rel="${f#$ROOT_DIR/}"
  # Print each matching line, then filter out ds-allow exempted lines.
  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    case "$content" in
      *ds-allow*) continue ;;   # explicit, audited exception
    esac
    add_violation "$rel:$lineno: $content"
  done < <(
    grep -nE 'Color\(red:|UIColor\(red:|\.glassEffect\(|RoundedRectangle\(cornerRadius: [0-9]|Color\.(black|white|gray)\b' "$f" || true
  )
done

# ---- Web: app.js must not build component markup inline ----
echo "Checking web: app.js inline component markup..."
web_app="$ROOT_DIR/app.js"
while IFS= read -r line; do
  add_violation "app.js:${line%%:*}: inline component markup (route through components.js TrainyUI.*) — ${line#*:}"
done < <(grep -nE 'class="(trip-card|mini-pill|timeline-row|alert-item|network-row|car |car"|empty-state)' "$web_app" || true)

# ---- Web: styles.css must not hardcode colors outside the :root token layer ----
echo "Checking web: styles.css hardcoded color literals outside :root..."
web_css="$ROOT_DIR/styles.css"
while IFS= read -r line; do
  content="${line#*:}"
  # A line that defines a token contains "--". Allow those.
  case "$content" in
    *"--"*) continue ;;
  esac
  add_violation "styles.css:${line%%:*}: hardcoded color literal outside :root tokens — ${content}"
done < <(grep -nE '#[0-9a-fA-F]{3,8}\b|rgba\([0-9]' "$web_css" || true)

echo
if [ "$STATUS" -eq 0 ]; then
  echo "✅ design-system bypass check passed — all UI routes through the library."
else
  echo "❌ design-system bypass check failed with $VIOLATIONS violation(s)."
fi
exit "$STATUS"
