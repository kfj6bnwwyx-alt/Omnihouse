#!/usr/bin/env bash
#
# Local pre-push / pre-commit gate. Runs the same build + tests
# that CI runs, but targets a local simulator so it's fast enough
# to wait on. Exits non-zero on any failure — hook this up via
# scripts/install-hooks.sh or run it manually before pushing.
#
# Usage:
#   scripts/check.sh             # clean build + all tests
#   scripts/check.sh --build     # build only (skip tests)
#   scripts/check.sh --changed   # build + only tests related to
#                                # changed files since origin/main.
#                                # Fast path for iterative work.
#                                # Falls back to a build-only check
#                                # if no test files look related.
#
set -euo pipefail

MODE="full"
case "${1:-}" in
  --build)   MODE="build" ;;
  --changed) MODE="changed" ;;
  "")        MODE="full" ;;
  *)
    echo "✗ unknown flag: $1"
    echo "  usage: check.sh [--build|--changed]"
    exit 2
    ;;
esac

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

# --changed mode: find modified Swift files since origin/main, map
# each `Foo.swift` to `FooTests.swift` in the test target, run
# only those tests. If no mapping hits, we're done — the build
# already caught compile-time regressions.
if [ "$MODE" = "changed" ]; then
  TEST_CLASSES=""
  # Diff against origin/main if we have it, else against HEAD~1.
  BASE=$(git merge-base HEAD origin/main 2>/dev/null || git rev-parse HEAD~1 2>/dev/null || true)
  if [ -z "$BASE" ]; then
    echo "! no base commit to diff against; running full tests"
  else
    CHANGED=$(git diff --name-only "$BASE"...HEAD -- "*.swift" ; git diff --name-only -- "*.swift" ; git diff --name-only --cached -- "*.swift") 2>/dev/null
    CHANGED=$(echo "$CHANGED" | sort -u)

    # Map: for each changed file, look for a matching *Tests file.
    # If the file itself is already a test file, include it.
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      BASENAME=$(basename "$f" .swift)
      if [[ "$BASENAME" == *Tests ]]; then
        TEST_CLASSES="$TEST_CLASSES $BASENAME"
      else
        MATCH_FILE=$(find "house connectTests" -name "${BASENAME}Tests.swift" 2>/dev/null | head -1)
        if [ -n "$MATCH_FILE" ]; then
          TEST_CLASSES="$TEST_CLASSES ${BASENAME}Tests"
        fi
      fi
    done <<< "$CHANGED"

    # Dedupe.
    TEST_CLASSES=$(echo "$TEST_CLASSES" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    if [ -z "$TEST_CLASSES" ]; then
      echo "✓ build passed; no test files mapped to changes"
      exit 0
    fi

    echo "→ running scoped tests: $TEST_CLASSES"
    # Build -only-testing arguments for xcodebuild.
    ONLY_ARGS=""
    for CLS in $TEST_CLASSES; do
      ONLY_ARGS="$ONLY_ARGS -only-testing:house\ connectTests/$CLS"
    done
  fi
fi

# Find an available iOS 26 simulator. Falls back to any iPhone if
# none is explicitly 26.x. Uses portable awk + sed — default macOS
# awk doesn't support gawk's 3-arg match().
# Ask xcodebuild itself for destinations — guarantees we only
# pick IDs the project actually accepts. Filter to iOS Simulator
# + iOS 26 + an iPhone, since the project's deployment target is
# 26.x and iPhone is the primary form factor.
pick_sim_id() {
  local filter_ios26="$1"
  local dests
  dests=$(xcodebuild \
    -project "house connect.xcodeproj" \
    -scheme "house connect" \
    -showdestinations 2>/dev/null)

  local match
  if [ "$filter_ios26" = "1" ]; then
    match=$(echo "$dests" | grep -E 'platform:iOS Simulator.*OS:26' | grep -E 'name:iPhone' | head -1)
  else
    match=$(echo "$dests" | grep -E 'platform:iOS Simulator.*name:iPhone' | head -1)
  fi
  echo "$match" | sed -n 's/.*id:\([-0-9A-F]\{36\}\).*/\1/p'
}

SIM_ID=$(pick_sim_id 1)
if [ -z "$SIM_ID" ]; then
  echo "! no iOS 26 iPhone simulator — using first available"
  SIM_ID=$(pick_sim_id 0)
fi

if [ -z "$SIM_ID" ]; then
  echo "✗ no simulator available"
  exit 1
fi

echo "→ running tests on $SIM_ID..."
# NOTE: we don't pass CODE_SIGNING_ALLOWED=NO here — KeychainTokenStoreTests
# needs the keychain entitlement, which disabled signing strips. The default
# developer signing is fine on a local machine.
if [ "$MODE" = "changed" ] && [ -n "${ONLY_ARGS:-}" ]; then
  # shellcheck disable=SC2086
  eval xcodebuild \
    -project '"house connect.xcodeproj"' \
    -scheme '"house connect"' \
    -destination "'platform=iOS Simulator,id=$SIM_ID'" \
    test \
    -quiet \
    $ONLY_ARGS
else
  xcodebuild \
    -project "house connect.xcodeproj" \
    -scheme "house connect" \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    test \
    -quiet
fi

echo "✓ build + tests passed"
