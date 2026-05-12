#!/usr/bin/env bash
# Extract this runner into a new repo. Run from anywhere; pass the target
# directory as the only argument. The target should already exist and be the
# root of a fresh git repo (git init done, no commits required).
#
# Usage:
#   ./migrate-to-new-repo.sh /path/to/new-repo
#
# What it does:
#   1. Copies package.json, package-lock.json, tsconfig.json, run.ts, and
#      .env.example to the target root.
#   2. Copies the GitHub Actions workflow to .github/workflows/, removing
#      the working-directory block so it runs at the new repo root.
#   3. Writes a sensible .gitignore (node_modules, .env, build output).
#   4. Prints the follow-up checklist (npm install, add secrets, push).

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/new-repo" >&2
  exit 2
fi

target="$1"
if [[ ! -d "$target" ]]; then
  echo "error: target directory does not exist: $target" >&2
  exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"
omnihouse_root="$(cd "$here/../.." && pwd)"

echo "Copying runner files to $target ..."
cp "$here/package.json"       "$target/"
cp "$here/package-lock.json"  "$target/"
cp "$here/tsconfig.json"      "$target/"
cp "$here/run.ts"             "$target/"
cp "$here/.env.example"       "$target/"

echo "Copying workflow (stripping working-directory) ..."
mkdir -p "$target/.github/workflows"
src_wf="$omnihouse_root/.github/workflows/daily-job-search.yml"
# Remove the three-line `defaults:\n  run:\n    working-directory: ...` block.
# awk strategy: drop lines from "defaults:" through the working-directory line.
awk '
  /^[[:space:]]*defaults:[[:space:]]*$/ { in_defaults = 1; next }
  in_defaults && /working-directory:/    { in_defaults = 0; next }
  in_defaults && /^[[:space:]]/          { next }
  in_defaults                            { in_defaults = 0 }
  { print }
' "$src_wf" > "$target/.github/workflows/daily-job-search.yml"

echo "Writing .gitignore ..."
cat > "$target/.gitignore" <<'EOF'
node_modules/
.env
.env.*
!.env.example
dist/
build/
.DS_Store
EOF

cat <<EOF

Done. Next steps:

  cd "$target"
  npm ci                                       # verify lockfile installs cleanly
  git add -A && git commit -m "Initial: extracted from omnihouse"
  git remote add origin git@github.com:YOU/simona-job-search.git
  git push -u origin main

Then in the new repo's GitHub settings:
  - Settings -> Secrets and variables -> Actions, add:
      ANTHROPIC_API_KEY, SHEET_ID, EMAIL_TO,
      GOOGLE_SERVICE_ACCOUNT_JSON_B64,
      GMAIL_OAUTH_CLIENT_ID, GMAIL_OAUTH_CLIENT_SECRET, GMAIL_OAUTH_REFRESH_TOKEN
  - Set default branch to 'main' (cron only fires on default branch)
  - Actions -> Daily job search for Simona -> Run workflow (manual smoke test)
EOF
