#!/usr/bin/env bash
#
# Installs a git pre-push hook that runs scripts/check.sh. One-time
# setup per clone — git hooks live in .git/hooks/ which isn't
# tracked, so each engineer (or machine) runs this once.
#
# Usage:  scripts/install-hooks.sh
# Skip:   git push --no-verify   # bypasses the hook for one push
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_PATH="$ROOT/.git/hooks/pre-push"

mkdir -p "$ROOT/.git/hooks"

cat > "$HOOK_PATH" <<'HOOK'
#!/usr/bin/env bash
# Installed by scripts/install-hooks.sh — blocks pushes that break
# the build or fail tests. Skip with `git push --no-verify`.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
exec "$ROOT/scripts/check.sh"
HOOK

chmod +x "$HOOK_PATH"
chmod +x "$ROOT/scripts/check.sh"

echo "✓ installed pre-push hook at $HOOK_PATH"
echo "  Every 'git push' will now build + test first."
echo "  Bypass with 'git push --no-verify' if you really need to."
