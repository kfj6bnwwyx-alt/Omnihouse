#!/usr/bin/env bash
#
# Local pre-push / pre-commit gate. Runs the same build + tests
# that CI runs, but targets a local simulator so it's fast enough
# to wait on. Exits non-zero on any failure — hook this up via
# scripts/install-hooks.sh or run it manually before pushing.
#
# Usage:
#   scripts/check.sh           # build + test
#   scripts/check.sh --build   # build only (skip tests)
#
set -euo pipefail

MODE="full"
if [ "${1:-}" = "--build" ]; then
  MODE="build"
fi

# Resolve repo root relative to this script so `check.sh` works
# regardless of cwd.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Prefer Xcode over CommandLineTools.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "→ building house connect ($(basename "$DEVELOPER_DIR"))..."
xcodebuild \
  -project "house connect.xcodeproj" \
  -scheme "house connect" \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

if [ "$MODE" = "build" ]; then
  echo "✓ build passed"
  exit 0
fi

# Find an available iOS 26 simulator. Falls back to any booted
# iPhone if none is explicitly 26.x (matches CI's behaviour).
SIM_ID=$(xcrun simctl list devices available 2>/dev/null | \
  awk '/-- iOS 26/{v=1; next} /--/{v=0} v && /iPhone/{match($0, /\(([-0-9A-F]{36})\)/, a); print a[1]; exit}')

if [ -z "$SIM_ID" ]; then
  echo "! no iOS 26 simulator — using first available"
  SIM_ID=$(xcrun simctl list devices available 2>/dev/null | \
    awk '/iPhone/{match($0, /\(([-0-9A-F]{36})\)/, a); print a[1]; exit}')
fi

if [ -z "$SIM_ID" ]; then
  echo "✗ no simulator available"
  exit 1
fi

echo "→ running tests on $SIM_ID..."
xcodebuild \
  -project "house connect.xcodeproj" \
  -scheme "house connect" \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  test \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

echo "✓ build + tests passed"
