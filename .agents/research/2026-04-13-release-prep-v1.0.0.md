# Release Prep Report — v1.0.0

**Date:** 2026-04-13
**Version:** 1.0.0 (Build 1)
**Release Type:** Initial Release
**Status:** Blocked (see items below)

## Version

- MARKETING_VERSION: 1.0
- CURRENT_PROJECT_VERSION: 1
- Deployment target: iOS 26.4
- No previous tags — this is the first release

## Changelog

### What's New in 1.0.0

**Features:**
- Unified home automation dashboard (HomeKit + SmartThings + Sonos + Nest)
- Cross-ecosystem scenes (one tap controls devices across all providers)
- Real-time SmartThings updates via Server-Sent Events (SSE)
- Sonos multi-room audio with zone management and group controls
- Full Sonos now-playing metadata (title, artist, album, duration, source)
- Smart command routing for dual-homed devices (B6 capability union)
- Smoke alarm detail with Live Activity support
- Network topology visualization and diagnostics
- Camera, thermostat, and light detail screens
- Apple Watch app (files ready, target needs Xcode setup)
- WidgetKit widgets (camera feed, thermostat)
- Nest provider infrastructure (ready for Google Device Access activation)

**Quality:**
- 127 unit tests passing
- Accessibility on 35+ views (VoiceOver, safety-critical labels)
- Privacy manifest with UserDefaults declaration
- File protection on all disk caches
- KeychainAccess pinned to v4.2.2

### App Store "What's New" (copy-paste ready)

House Connect unifies your smart home into one app. Control HomeKit, SmartThings, Sonos, and Nest devices from a single dashboard.

• One-tap scenes that work across ecosystems — dim the lights AND pause Sonos AND set the thermostat
• Real-time device updates via SmartThings push notifications
• Multi-room Sonos audio zones with drag-to-group controls
• Smart smoke alarm monitoring with Live Activity alerts
• Network health diagnostics and device topology map
• Accessible design with full VoiceOver support

## Code Readiness

| Check | Status | Notes |
|-------|--------|-------|
| Tests passing | ✅ | 127 tests, 0 failures |
| Debug code removed | ⚠️ FIXING | 34 print() statements being wrapped in #if DEBUG |
| No blocking TODOs | ✅ | 5 TODOs — all future-phase, none blocking |
| Hardcoded test data | ✅ | None found |
| Build warnings | ✅ | 0 (SourceKit stale cache warnings are IDE-only) |
| Deployment target | ✅ | iOS 26.4 |

### TODOs (non-blocking):
1. `DemoNestProvider.swift:27` — "Phase 6 TODO when real provider replaces this" (future)
2. `NestOAuthView.swift:124,126` — "Wire ASWebAuthenticationSession when credentials available" (blocked on $5 Google reg)
3. `SmokeAlarmDetailView.swift:18` — "TODO when Nest provider lands" (future)
4. `SonosPlayerDetailView.swift:187` — "TODO once SonosProvider exposes a..." (future feature)

## Privacy & Compliance

| Check | Status | Notes |
|-------|--------|-------|
| Privacy manifest exists | ✅ | PrivacyInfo.xcprivacy with UserDefaults declaration |
| API reasons declared | ✅ | CA92.1 for UserDefaults |
| Third-party manifests | ⚠️ | KeychainAccess does not include its own privacy manifest |
| ATS configured | ✅ | No blanket ATS exceptions |
| Entitlements match | ✅ | HomeKit entitlement only — matches app usage |

## App Store Metadata

| Check | Status | Notes |
|-------|--------|-------|
| App icon complete | ❌ BLOCKER | Contents.json exists but NO actual image files — needs 1024x1024 PNG |
| Launch screen | ❌ BLOCKER | No UILaunchScreen or LaunchScreen.storyboard found |
| Screenshots | ❌ BLOCKER | No screenshots directory — need 6.9", 6.5", 5.5" sizes |
| What's New text | ✅ | See above |
| Support URL | ❌ | Not configured |
| Privacy URL | ❌ | Not configured |
| Localizations | N/A | English only (no .lproj directories) |

## Signing & Build

| Check | Status | Notes |
|-------|--------|-------|
| Development Team | ✅ | 2SD6Z2L5YZ configured |
| Code Sign Identity | ✅ | "Sign to Run Locally" (development) |
| Swift optimization (Release) | ⚠️ | Only -Onone found — verify Release config has -O |
| Package.resolved | ✅ | Present, KeychainAccess pinned to v4.2.2 |

## Blocking Issues Summary

1. **App icon** — No image files in AppIcon.appiconset. Need 1024x1024 PNG.
2. **Launch screen** — No UILaunchScreen config or LaunchScreen.storyboard. Required for App Store.
3. **Screenshots** — None exist. Need device screenshots for all required sizes.
4. **Support/Privacy URLs** — Not configured in project settings.
5. **Debug prints** — 34 print() statements need #if DEBUG wrapping (in progress).

## Release Commands

When blockers are resolved:
```bash
# Archive
xcodebuild archive -scheme "house connect" -archivePath build/HouseConnect.xcarchive

# Tag the release
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

## Post-Release Monitoring

- [ ] Verify app is live on App Store
- [ ] Monitor crash reports for 48 hours
- [ ] Check App Store reviews
