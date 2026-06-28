#!/usr/bin/env bash
set -euo pipefail

PROJECT="MathCross.xcodeproj"
SCHEME="MathCross"
BUNDLE_ID="org.spumoni.mathcross"
DEFAULT_DEVICE_ID="A7F4BF00-3885-4478-9AD7-DA1D4D368AA4"
DERIVED_DATA="${DERIVED_DATA:-/private/tmp/MathCrossCLISimDerivedData}"

DEVICE_ID="${DEVICE_ID:-$DEFAULT_DEVICE_ID}"
OPEN_SIMULATOR=1
CLEAN_INSTALL=1

usage() {
  cat <<USAGE
Usage: scripts/run_simulator.sh [options]

Build, install, and launch MathCross on an iOS Simulator without Xcode's
debug launcher.

Options:
  -d, --device-id ID      Simulator UUID. Default: $DEFAULT_DEVICE_ID
  --derived-data PATH     DerivedData output path. Default: $DERIVED_DATA
  --no-open               Do not bring the Simulator app to the foreground.
  --no-uninstall          Install over the existing app instead of uninstalling first.
  -h, --help              Show this help.

Environment:
  DEVICE_ID               Same as --device-id.
  DERIVED_DATA            Same as --derived-data.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device-id)
      DEVICE_ID="${2:?Missing value for $1}"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA="${2:?Missing value for $1}"
      shift 2
      ;;
    --no-open)
      OPEN_SIMULATOR=0
      shift
      ;;
    --no-uninstall)
      CLEAN_INSTALL=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$(dirname "$0")/.."

echo "Booting simulator: $DEVICE_ID"
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

if [[ "$OPEN_SIMULATOR" -eq 1 ]]; then
  open -a Simulator 2>/dev/null || true
fi

echo "Building $SCHEME for simulator..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "*.app" -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not find built .app under $DERIVED_DATA" >&2
  exit 1
fi

echo "Built app: $APP_PATH"

if [[ "$CLEAN_INSTALL" -eq 1 ]]; then
  echo "Removing previous install if present..."
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
fi

echo "Installing..."
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

echo "Launching..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
