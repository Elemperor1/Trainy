#!/usr/bin/env bash
set -euo pipefail

VIDEO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$VIDEO_ROOT/../.." && pwd)"
PROJECT="$REPO_ROOT/TrainyIOS/Trainy.xcodeproj"
CAPTURE_DIR="$VIDEO_ROOT/public/footage"
RAW_DIR="/private/tmp/trainy-launch-video/captures"
DERIVED_DATA="/private/tmp/trainy-launch-video/DerivedData"
SOURCE_PACKAGES="/private/tmp/trainy-source-packages"
PACKAGE_CACHE="/private/tmp/trainy-swiftpm-cache"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-26.5.0.app/Contents/Developer}"
PROXY_URL="https://trainy-ns-provider-proxy.trainy-jacob.workers.dev"

export DEVELOPER_DIR
mkdir -p "$CAPTURE_DIR" "$RAW_DIR" "$DERIVED_DATA" "$SOURCE_PACKAGES" "$PACKAGE_CACHE"

SIMCTL="$(xcrun --find simctl)"

SIMULATOR_ID="$(xcrun simctl list devices available | awk -F'[()]' '/iPhone 17 \(/ {gsub(/^ +| +$/, "", $2); print $2; exit}')"
if [[ -z "$SIMULATOR_ID" ]]; then
  echo "No available iPhone 17 simulator was found." >&2
  exit 1
fi

xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b >/dev/null
xcrun simctl status_bar "$SIMULATOR_ID" override \
  --time "09:21" \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3

clear_status_bar() {
  xcrun simctl status_bar "$SIMULATOR_ID" clear >/dev/null 2>&1 || true
}
trap clear_status_bar EXIT

COMMON_ARGS=(
  -project "$PROJECT"
  -scheme TrainyTests
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
  -derivedDataPath "$DERIVED_DATA"
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES"
  -packageCachePath "$PACKAGE_CACHE"
  -disableAutomaticPackageResolution
  -parallel-testing-enabled NO
  CODE_SIGNING_ALLOWED=NO
  ODPT_CONSUMER_KEY=
  TRAINY_PROVIDER_PROXY_BASE_URL="$PROXY_URL"
  TRAINY_SOURCE_PACKAGES_DIR="$SOURCE_PACKAGES"
)

echo "Preparing deterministic Trainy UI test products for iPhone 17..."
xcodebuild build-for-testing "${COMMON_ARGS[@]}" -quiet

record_test() {
  local name="$1"
  local test_name="$2"
  local raw_file="$RAW_DIR/$name-raw.mp4"
  local recorder_log="$RAW_DIR/$name-recorder.log"
  local final_file="$CAPTURE_DIR/$name.mp4"
  local recorder_pid=""
  local test_status=0

  stop_recorder() {
    if [[ -n "$recorder_pid" ]] && kill -0 "$recorder_pid" >/dev/null 2>&1; then
      kill -INT "$recorder_pid" >/dev/null 2>&1 || true
      wait "$recorder_pid" >/dev/null 2>&1 || true
    fi
  }
  trap stop_recorder RETURN

  rm -f "$raw_file" "$recorder_log" "$final_file"
  "$SIMCTL" io "$SIMULATOR_ID" recordVideo --codec=h264 --force "$raw_file" 2>"$recorder_log" &
  recorder_pid=$!

  for _ in {1..40}; do
    if grep -q "Recording started" "$recorder_log" 2>/dev/null; then
      break
    fi
    if ! kill -0 "$recorder_pid" >/dev/null 2>&1; then
      cat "$recorder_log" >&2
      echo "Simulator recorder exited before $name began." >&2
      return 1
    fi
    sleep 0.25
  done

  if ! grep -q "Recording started" "$recorder_log" 2>/dev/null; then
    cat "$recorder_log" >&2
    echo "Simulator recorder did not start $name within 10 seconds." >&2
    return 1
  fi

  set +e
  xcodebuild test-without-building \
    "${COMMON_ARGS[@]}" \
    -only-testing:"TrainyUITests/TrainyCriticalUITests/$test_name" \
    -quiet
  test_status=$?
  set -e

  sleep 1
  stop_recorder
  recorder_pid=""

  if [[ ! -s "$raw_file" ]]; then
    cat "$recorder_log" >&2
    echo "Simulator recorder did not finalize $raw_file." >&2
    return 1
  fi

  if [[ "$test_status" -ne 0 ]]; then
    echo "UI test failed while recording $name." >&2
    return "$test_status"
  fi

  ffmpeg -hide_banner -loglevel error -y \
    -i "$raw_file" \
    -map_metadata -1 -an -vf "fps=30,format=yuv420p" \
    -c:v libx264 -preset medium -crf 16 -movflags +faststart \
    "$final_file"

  ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name,width,height,avg_frame_rate \
    -of default=noprint_wrappers=1 "$final_file"
}

capture_requested() {
  local requested="$1"
  shift
  if [[ "$#" -eq 0 ]]; then
    return 0
  fi
  for argument in "$@"; do
    if [[ "$argument" == "$requested" ]]; then
      return 0
    fi
  done
  return 1
}

requested_captures=("$@")

if capture_requested onboarding "${requested_captures[@]}"; then
  record_test onboarding testLaunchFilmStandardOnboardingAndTrackedTripSurface
fi
if capture_requested shinkansen-search "${requested_captures[@]}"; then
  record_test shinkansen-search testLaunchFilmJapanJourneyAtStandardSize
fi
if capture_requested utrecht-departures "${requested_captures[@]}"; then
  record_test utrecht-departures testLaunchFilmUtrechtJourneyAtStandardSize
fi
if capture_requested provider-fallback "${requested_captures[@]}"; then
  record_test provider-fallback testCredentialNeutralFallbackAndProviderStatusAreExplicit
fi
if capture_requested failure-recovery "${requested_captures[@]}"; then
  record_test failure-recovery testNSFailureRecoversThroughTheVisibleRetryAction
fi
if capture_requested accessibility "${requested_captures[@]}"; then
  record_test accessibility testNSJourneyInLightDarkAndAX2XL
fi
if capture_requested privacy "${requested_captures[@]}"; then
  record_test privacy testCrashDiagnosticsAreOffByDefaultAndRequireOptIn
fi

echo "Captured the requested credential-neutral Trainy UI clips in $CAPTURE_DIR"
