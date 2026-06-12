#!/usr/bin/env bash
set -euo pipefail

XCODES_VERSION="1.6.2"
XCODES_SHA256="c4530102af12850d63fd674bdcf6030649be47e1f7d283450b6f526c9285c4f7"
XCODES_URL="https://github.com/XcodesOrg/xcodes/releases/download/${XCODES_VERSION}/xcodes-${XCODES_VERSION}.macos.arm64.tar.gz"
XCODE_VERSION="${XCODE_VERSION:-26.5}"
WORK_DIR="${WORK_DIR:-/private/tmp/trainy-xcodes}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/private/tmp/trainy-xcode-downloads}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

mkdir -p "$WORK_DIR" "$DOWNLOAD_DIR"

ARCHIVE="$WORK_DIR/xcodes-${XCODES_VERSION}.macos.arm64.tar.gz"
XCODES_BIN="$WORK_DIR/xcodes/${XCODES_VERSION}/bin/xcodes"

if [[ ! -x "$XCODES_BIN" ]]; then
  echo "Downloading xcodes ${XCODES_VERSION}..."
  curl -L --fail --output "$ARCHIVE" "$XCODES_URL"

  ACTUAL_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
  if [[ "$ACTUAL_SHA" != "$XCODES_SHA256" ]]; then
    echo "Checksum mismatch for xcodes archive." >&2
    echo "Expected: $XCODES_SHA256" >&2
    echo "Actual:   $ACTUAL_SHA" >&2
    exit 1
  fi

  tar -xzf "$ARCHIVE" -C "$WORK_DIR"
fi

echo "Using $("$XCODES_BIN" version)"
echo "This uses Apple Developer downloads, not the Mac App Store."
echo "If prompted, sign in with an Apple Account that can access developer.apple.com/download/all."

"$XCODES_BIN" download "$XCODE_VERSION" \
  --directory "$DOWNLOAD_DIR" \
  --no-aria2 \
  --no-color

XIP_PATH="$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "Xcode_${XCODE_VERSION}*.xip" -print -quit)"
if [[ -z "$XIP_PATH" ]]; then
  echo "Download finished but no Xcode_${XCODE_VERSION} .xip was found in $DOWNLOAD_DIR." >&2
  exit 1
fi

echo "Installing $XIP_PATH into $INSTALL_DIR..."
"$XCODES_BIN" install "$XCODE_VERSION" \
  --path "$XIP_PATH" \
  --directory "$INSTALL_DIR" \
  --select \
  --experimental-unxip \
  --empty-trash \
  --no-color

echo "Xcode install complete."
xcodebuild -version
