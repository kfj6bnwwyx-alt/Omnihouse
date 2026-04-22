# scripts/

Local quality gates paired with the GitHub Actions workflow in
`.github/workflows/ci.yml`.

## One-time setup

```
scripts/install-hooks.sh
```

Installs a `pre-push` hook that runs `scripts/check.sh` before every
`git push`. Skip for a single push with `git push --no-verify`.

## Usage

```
scripts/check.sh           # clean build + all unit tests
scripts/check.sh --build   # build only (faster; skip tests)
```

Exit code is non-zero on any failure. The script uses whichever iOS
26 simulator the machine has — no specific device pinned, so it
works across engineers.

## What CI runs

Same thing, on `macos-15` with Xcode 17, on every push to `main` and
on PRs. The workflow uploads the `TestResult.xcresult` bundle as an
artifact if tests fail, so you can open it in Xcode and see which
case broke.
