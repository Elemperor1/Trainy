#!/usr/bin/env bash
# =============================================================================
# check-design-system-bypass.sh
# Guardrail: keeps screen code on Trainy's shared Design System tokens,
# modifiers, and components. Run locally and in CI. Exits non-zero on bypasses.
#
# Approved Design System implementation files (not scanned as consumers):
#   Sources/TrainyCore/DesignSystem/**
#
# False-positive policy:
#   * Prefer adding or extending a token/component in an approved file.
#   * A line-level `// ds-allow: <specific reason>` is reserved for visual
#     geometry that is data-driven or platform-defined (for example a MapKit
#     annotation), where replacing the literal with a UI token would be less
#     truthful. The reason must be at least eight characters.
#   * Do not exempt ordinary screen colors, typography, cards, buttons,
#     spacing, elevation, or "temporary"/"legacy" styling.
#   * There is no legacy exception list. Existing screen code and new screen
#     code are held to the same boundary.
#
# iOS consumer rules:
#   * no raw Color/UIColor literals or system color constants
#   * no direct Liquid Glass primitives
#   * no non-zero numeric padding or stack spacing
#   * no numeric corner radii
#   * no direct system font aliases, Font.system, shadow, material, or animation construction
#   * no new token namespaces or custom style/modifier types outside the library
#   * no redefinition of a component name owned by an approved library file
#   * persistent interface preferences are owned by ContentView/Settings and
#     injected through RailInterfacePreferences; components do not read storage
#
# Design System dependency rules:
#   * no AppStorage, UserDefaults, NotificationCenter, TrainStore, MapKit, or
#     feature-only navigation/filter types inside Sources/TrainyCore/DesignSystem
#
# Web rules:
#   * app.js must route dynamic markup through components.js
#   * styles.css color literals are allowed only in CSS custom-property
#     declarations; consumers must use var(--token)
#
# Test modes:
#   scripts/check-design-system-bypass.sh --self-test
#   TRAINY_DESIGN_SYSTEM_ROOT=/path/to/tree scripts/check-design-system-bypass.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/Tests/TrainyCoreTests/DesignSystem/GuardrailFixtures"

run_self_test() {
  local fixture
  local fixture_name
  local case_root
  local output
  local detail
  local failures=0
  local cases=0

  if [ ! -d "$FIXTURE_DIR" ]; then
    printf 'FAIL: guardrail fixture directory is missing: %s\n' "$FIXTURE_DIR"
    return 1
  fi

  printf 'Running design-system guardrail fixtures...\n'
  while IFS= read -r fixture; do
    fixture_name="$(basename "$fixture")"
    if [ "$fixture_name" = "approved-library.swift.fixture" ]; then
      continue
    fi

    cases=$((cases + 1))
    case_root="$(mktemp -d "${TMPDIR:-/tmp}/trainy-ds-guardrail.XXXXXX")"
    mkdir -p "$case_root/Sources/TrainyCore/DesignSystem"
    cp "$FIXTURE_DIR/approved-library.swift.fixture" \
      "$case_root/Sources/TrainyCore/DesignSystem/RailDesignLibrary.swift"
    cp "$FIXTURE_DIR/valid-screen.swift.fixture" \
      "$case_root/Sources/TrainyCore/FixtureScreen.swift"
    printf '"use strict";\n' > "$case_root/app.js"
    printf ':root {\n  --ink: #101419;\n}\n.fixture { color: var(--ink); }\n' > "$case_root/styles.css"

    case "$fixture_name" in
      *.app.js.fixture)
        cp "$fixture" "$case_root/app.js"
        ;;
      *.styles.css.fixture)
        cp "$fixture" "$case_root/styles.css"
        ;;
      *.content-view.swift.fixture)
        cp "$fixture" "$case_root/Sources/TrainyCore/ContentView.swift"
        ;;
      *.design-system.swift.fixture)
        cp "$fixture" "$case_root/Sources/TrainyCore/DesignSystem/Forbidden.swift"
        ;;
      *.swift.fixture)
        cp "$fixture" "$case_root/Sources/TrainyCore/FixtureScreen.swift"
        ;;
      *)
        printf '  FAIL  %s: unknown fixture type\n' "$fixture_name"
        failures=$((failures + 1))
        rm -rf "$case_root"
        continue
        ;;
    esac

    if output="$(TRAINY_DESIGN_SYSTEM_ROOT="$case_root" bash "$SCRIPT_PATH" 2>&1)"; then
      if [[ "$fixture_name" == forbidden-* ]]; then
        printf '  FAIL  %s: forbidden fixture was not detected\n' "$fixture_name"
        failures=$((failures + 1))
      else
        printf '  PASS  %s\n' "$fixture_name"
      fi
    else
      if [[ "$fixture_name" == forbidden-* ]]; then
        detail="$(printf '%s\n' "$output" | grep '  FAIL  ' | head -n 1 || true)"
        printf '  PASS  %s detected: %s\n' "$fixture_name" "${detail#*FAIL  }"
      else
        printf '  FAIL  %s: valid fixture was rejected\n%s\n' "$fixture_name" "$output"
        failures=$((failures + 1))
      fi
    fi

    rm -rf "$case_root"
  done < <(find "$FIXTURE_DIR" -maxdepth 1 -type f -name '*.fixture' | sort)

  if [ "$cases" -eq 0 ]; then
    printf 'FAIL: no guardrail fixtures found in %s\n' "$FIXTURE_DIR"
    return 1
  fi
  if [ "$failures" -ne 0 ]; then
    printf 'Guardrail self-test failed: %s of %s fixture(s) failed.\n' "$failures" "$cases"
    return 1
  fi

  printf 'Guardrail self-test passed: %s fixture(s).\n' "$cases"
}

if [ "${1:-}" = "--self-test" ]; then
  run_self_test
  exit $?
fi
if [ "$#" -ne 0 ]; then
  printf 'Usage: %s [--self-test]\n' "${BASH_SOURCE[0]}" >&2
  exit 64
fi

ROOT_DIR="${TRAINY_DESIGN_SYSTEM_ROOT:-$REPO_ROOT}"
STATUS=0
VIOLATIONS=0

add_violation() {
  printf '  FAIL  %s\n' "$1"
  VIOLATIONS=$((VIOLATIONS + 1))
  STATUS=1
}

trim_leading_space() {
  local value="$1"
  printf '%s' "${value#"${value%%[![:space:]]*}"}"
}

has_valid_allowance() {
  local content="$1"
  local reason

  case "$content" in
    *"ds-allow:"*)
      reason="${content#*ds-allow:}"
      reason="$(trim_leading_space "$reason")"
      [ "${#reason}" -ge 8 ]
      ;;
    *)
      return 1
      ;;
  esac
}

is_comment_line() {
  local content
  content="$(trim_leading_space "$1")"
  [[ "$content" == //* ]]
}

PREFERENCE_TIME_FORMAT=0
PREFERENCE_UNIT_SYSTEM=0
PREFERENCE_SOURCE_VERBOSITY=0

consume_owned_app_storage() {
  local rel="$1"
  local content
  content="$(trim_leading_space "$2")"

  [ "$rel" = "Sources/TrainyCore/ContentView.swift" ] || return 1

  if [[ "$content" == '@AppStorage("trainy.timeFormat")'* ]] && [ "$PREFERENCE_TIME_FORMAT" -lt 2 ]; then
    PREFERENCE_TIME_FORMAT=$((PREFERENCE_TIME_FORMAT + 1))
    return 0
  fi
  if [[ "$content" == '@AppStorage("trainy.unitSystem")'* ]] && [ "$PREFERENCE_UNIT_SYSTEM" -lt 2 ]; then
    PREFERENCE_UNIT_SYSTEM=$((PREFERENCE_UNIT_SYSTEM + 1))
    return 0
  fi
  if [[ "$content" == '@AppStorage("trainy.sourceLabelVerbosity")'* ]] && [ "$PREFERENCE_SOURCE_VERBOSITY" -lt 1 ]; then
    PREFERENCE_SOURCE_VERBOSITY=$((PREFERENCE_SOURCE_VERBOSITY + 1))
    return 0
  fi

  return 1
}

scan_ios_rule() {
  local file="$1"
  local rel="$2"
  local rule="$3"
  local guidance="$4"
  local regex="$5"
  local line
  local lineno
  local content

  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if is_comment_line "$content" || has_valid_allowance "$content"; then
      continue
    fi
    add_violation "$rel:$lineno: $rule; $guidance — $content"
  done < <(grep -nE "$regex" "$file" || true)
}

ios_files=()
if [ -d "$ROOT_DIR/Sources/TrainyCore" ]; then
  while IFS= read -r -d '' file; do
    case "$file" in
      */DesignSystem/*)
        continue
        ;;
    esac
    ios_files+=("$file")
  done < <(find "$ROOT_DIR/Sources/TrainyCore" -type f -name '*.swift' -print0)
else
  add_violation "Sources/TrainyCore is missing"
fi

printf 'Checking iOS design-system bypass across %s non-library Swift files...\n' "${#ios_files[@]}"

protected_components=()
if [ -d "$ROOT_DIR/Sources/TrainyCore/DesignSystem" ]; then
  while IFS= read -r -d '' library_file; do
    while IFS= read -r name; do
      protected_components+=("$name")
    done < <(
      sed -nE 's/^[[:space:]]*(private[[:space:]]+|fileprivate[[:space:]]+|internal[[:space:]]+|public[[:space:]]+)?struct[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*(View|ButtonStyle|ViewModifier|LabelStyle|ToggleStyle|TextFieldStyle).*/\2/p' "$library_file"
    )
  done < <(find "$ROOT_DIR/Sources/TrainyCore/DesignSystem" -type f -name '*.swift' -print0)
fi

is_protected_component() {
  local candidate="$1"
  local protected
  for protected in "${protected_components[@]}"; do
    if [ "$candidate" = "$protected" ]; then
      return 0
    fi
  done
  return 1
}

for file in "${ios_files[@]}"; do
  rel="${file#$ROOT_DIR/}"

  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if [[ "$content" == *ds-allow* ]] && ! has_valid_allowance "$content"; then
      add_violation "$rel:$lineno: invalid ds-allow; provide a specific reason of at least eight characters — $content"
    fi
  done < <(grep -n 'ds-allow' "$file" || true)

  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if ! consume_owned_app_storage "$rel" "$content"; then
      add_violation "$rel:$lineno: hidden persistent UI state; own AppStorage at ContentView/Settings and inject RailInterfacePreferences — $content"
    fi
  done < <(grep -n '@AppStorage' "$file" || true)

  scan_ios_rule "$file" "$rel" \
    "raw color" "use RailDesign.Palette" \
    'Color[[:space:]]*\([[:space:]]*(red:|hue:)|UIColor[[:space:]]*\([[:space:]]*(red:|hue:)|Color\.(black|white|gray|red|blue|green|orange|yellow|pink|purple|brown|cyan|mint|indigo|teal)([^A-Za-z0-9_]|$)|(^|[(:=,[:space:]])\.white([^A-Za-z0-9_]|$)|\.(foregroundStyle|background|fill|stroke|tint)[[:space:]]*\([[:space:]]*\.(black|gray|red|blue|green|orange|yellow|pink|purple|brown|cyan|mint|indigo|teal)([^A-Za-z0-9_]|$)'

  scan_ios_rule "$file" "$rel" \
    "direct glass primitive" "use an approved glass component or modifier from the library" \
    '\.glassEffect[[:space:]]*\(|GlassEffectContainer[[:space:]]*\(|\.glassEffectID[[:space:]]*\(|\.buttonStyle[[:space:]]*\([[:space:]]*\.glass'

  scan_ios_rule "$file" "$rel" \
    "raw corner radius" "use RailDesign.Radius" \
    'RoundedRectangle[[:space:]]*\([[:space:]]*cornerRadius:[[:space:]]*[0-9]|\.cornerRadius[[:space:]]*\([[:space:]]*[0-9]|\.rect[[:space:]]*\([[:space:]]*cornerRadius:[[:space:]]*[0-9]'

  scan_ios_rule "$file" "$rel" \
    "raw spacing" "use RailDesign.Spacing or a named RailDesign.Layout measurement" \
    '\.padding[[:space:]]*\([[:space:]]*((\.(horizontal|vertical|top|bottom|leading|trailing)[[:space:]]*,[[:space:]]*)?([1-9][0-9]*|0\.[0-9]+))|((HStack|VStack|LazyHStack|LazyVStack|Grid)[[:space:]]*\([^)]*spacing:[[:space:]]*([1-9][0-9]*|0\.[0-9]+))'

  scan_ios_rule "$file" "$rel" \
    "raw typography" "use RailDesign.Typography" \
    '\.font[[:space:]]*\([[:space:]]*\.(largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)([^A-Za-z0-9_]|$)|\.font[[:space:]]*\([[:space:]]*\.system[[:space:]]*\([[:space:]]*size:'

  scan_ios_rule "$file" "$rel" \
    "raw elevation" "use RailDesign.Elevation or railPanelShadow" \
    '\.shadow[[:space:]]*\('

  scan_ios_rule "$file" "$rel" \
    "raw material" "wrap the material in an approved Design System component" \
    '\.(background|fill|toolbarBackground)[[:space:]]*\([[:space:]]*\.(ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial|bar)([^A-Za-z0-9_]|$)'

  scan_ios_rule "$file" "$rel" \
    "raw motion" "use RailDesign.Motion" \
    '\.animation[[:space:]]*\([[:space:]]*(\.(spring|interactiveSpring|easeIn|easeOut|easeInOut|linear)|Animation\.)'

  scan_ios_rule "$file" "$rel" \
    "token namespace outside DesignSystem" "define tokens in DesignSystem/RailDesignSystem.swift" \
    '(^|[[:space:]])(enum|struct)[[:space:]]+(RailDesign|Palette|Spacing|Radius|Typography|Motion|Elevation)([^A-Za-z0-9_]|$)'

  scan_ios_rule "$file" "$rel" \
    "custom style outside DesignSystem" "define reusable styles and modifiers in an approved library file" \
    '^[[:space:]]*(private[[:space:]]+|fileprivate[[:space:]]+|internal[[:space:]]+|public[[:space:]]+)?(struct|class|final[[:space:]]+class)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(<[^>]+>)?[[:space:]]*:[^{]*(ButtonStyle|ViewModifier|ShapeStyle|LabelStyle|ToggleStyle|TextFieldStyle)'

  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    if is_comment_line "$content" || has_valid_allowance "$content"; then
      continue
    fi
    component_name="$(
      printf '%s\n' "$content" |
        sed -nE 's/^[[:space:]]*(private[[:space:]]+|fileprivate[[:space:]]+|internal[[:space:]]+|public[[:space:]]+)?struct[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p'
    )"
    if [ -n "$component_name" ] && is_protected_component "$component_name"; then
      add_violation "$rel:$lineno: protected component '$component_name' is owned by the Design System library; reuse it instead of redefining it — $content"
    fi
  done < <(
    grep -nE '^[[:space:]]*(private[[:space:]]+|fileprivate[[:space:]]+|internal[[:space:]]+|public[[:space:]]+)?struct[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$file" || true
  )
done

if [ -d "$ROOT_DIR/Sources/TrainyCore/DesignSystem" ]; then
  while IFS= read -r -d '' library_file; do
    rel="${library_file#$ROOT_DIR/}"
    while IFS= read -r line; do
      lineno="${line%%:*}"
      content="${line#*:}"
      if is_comment_line "$content"; then
        continue
      fi
      add_violation "$rel:$lineno: forbidden Design System dependency; keep persistence, navigation, stores, and platform features outside the library — $content"
    done < <(
      grep -nE '@AppStorage|UserDefaults|NotificationCenter|TrainStore|import[[:space:]]+MapKit|(^|[^A-Za-z0-9_])(TripBucket|RailTab|RailSheet)([^A-Za-z0-9_]|$)' "$library_file" || true
    )
  done < <(find "$ROOT_DIR/Sources/TrainyCore/DesignSystem" -type f -name '*.swift' -print0)
fi

# Phase 17 semantic-palette boundary: decorative color names are no longer
# part of the library or consumer API. Scan the whole Swift tree so a future
# alias cannot silently reintroduce them inside the Design System itself.
if [ -d "$ROOT_DIR/Sources/TrainyCore" ]; then
  while IFS= read -r -d '' palette_file; do
    rel="${palette_file#"$ROOT_DIR"/}"
    while IFS= read -r line; do
      lineno="${line%%:*}"
      content="${line#*:}"
      if is_comment_line "$content"; then
        continue
      fi
      add_violation "$rel:$lineno: decorative palette role; use accent, success, warning, danger, or info — $content"
    done < <(
      grep -nE 'RailDesign\.Palette\.(marine|violet|copper|mint|amber|red|blue)([^A-Za-z0-9_]|$)' "$palette_file" || true
    )
  done < <(find "$ROOT_DIR/Sources/TrainyCore" -type f -name '*.swift' -print0)
fi

printf 'Checking web: app.js inline component markup...\n'
web_app="$ROOT_DIR/app.js"
if [ -f "$web_app" ]; then
  while IFS= read -r line; do
    add_violation "app.js:${line%%:*}: inline component markup; route dynamic HTML through components.js TrainyUI.* — ${line#*:}"
  done < <(grep -nE '<[A-Za-z][^>]*class[[:space:]]*=' "$web_app" || true)
else
  add_violation "app.js is missing"
fi

printf 'Checking web: styles.css color literals outside token declarations...\n'
web_css="$ROOT_DIR/styles.css"
if [ -f "$web_css" ]; then
  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"
    trimmed="$(trim_leading_space "$content")"
    if [[ "$trimmed" =~ ^--[A-Za-z0-9_-]+[[:space:]]*: ]]; then
      continue
    fi
    add_violation "styles.css:$lineno: hardcoded color literal outside a CSS token declaration; use var(--token) — $content"
  done < <(grep -nE '#[0-9a-fA-F]{3,8}([^0-9a-fA-F]|$)|rgba?\([[:space:]]*[0-9]|hsla?\([[:space:]]*[0-9]' "$web_css" || true)
else
  add_violation "styles.css is missing"
fi

# The legacy web prototype remains out of scope for spacing/radius enforcement
# until its redesign resumes. Color and component routing stay enforced because
# they are low-noise architectural boundaries. Re-enable spacing/radius only
# with a migration plan or an exact-count ratchet like the iOS rules above.

printf '\n'
if [ "$STATUS" -eq 0 ]; then
  printf 'Design-system bypass check passed — all guarded UI routes through the library.\n'
else
  printf 'Design-system bypass check failed with %s violation(s).\n' "$VIOLATIONS"
fi
exit "$STATUS"
