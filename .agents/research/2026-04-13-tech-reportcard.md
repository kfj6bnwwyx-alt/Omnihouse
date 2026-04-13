# Tech Report Card — House Connect

**Date:** 2026-04-13
**Analyst:** Claude Opus 4.6
**Timeline:** Pre-release
**CLAUDE.md:** No project-level CLAUDE.md found; used memory/backlog context

## Executive Summary

House Connect is a well-architected iOS 26 app with strong security practices, comprehensive accessibility, and solid test coverage. The codebase uses modern Swift concurrency (@Observable, @MainActor, async/await) consistently throughout with zero legacy DispatchQueue patterns in production code. The main gaps are large file sizes in three feature views and the absence of accessibilityIdentifiers for UI testing. At 29K LOC with 127 tests, this is ship-ready after addressing the app icon and launch assets.

## Project Metrics

```
Swift Files: 110 | LOC: 29,148 | Architecture: Provider-based MVVM
Persistence: JSON file cache + Keychain | State: @Observable + @Environment
Unit Tests: 127 (10 files) | UI Tests: 0 | Test Framework: XCTest
Providers: HomeKit, SmartThings (SSE), Sonos (SOAP/Bonjour), Nest (SDM)
```

## Grade Summary

**Overall: A- (3.72)**

```
Arch B+ | Quality A- | Perf A- | Concurrency A | Security A | A11y B+ | Testing B+ | UI A- | Data B+
```

---

## Per-Category Grades

### Architecture: B+ (3.3)
Clean provider-based architecture with strong separation of concerns.

**Strengths:**
- `AccessoryProvider` protocol enables plug-and-play ecosystem providers
- `ProviderRegistry` fan-out facade keeps views ecosystem-agnostic
- `SmartCommandRouter` handles cross-provider routing transparently
- `DeviceMerging` is pure and fully tested (13 dedicated tests)
- Every provider follows the same lifecycle pattern (start/refresh/execute/disconnect)

**Findings:**
- 9 files exceed 500 lines: SonosPlayerDetailView (1411), AllDevicesView (1013), SonosProvider (995), SonosSOAPClient (880), TopologyStatusViews (746), LightControlView (723), RoomDetailView (683), SmartThingsProvider (628), HomeDashboardView (616)
- `DeviceMerging` is embedded in `AllDevicesView.swift` rather than its own file — works for testing but hurts discoverability

### Code Quality: A- (3.7)
Clean code with minimal technical debt.

**Strengths:**
- Only 5 TODOs, all documented as future-phase work (not forgotten fixes)
- 2 force casts — both are safe (`EmptyDecodable() as! T` where T is literally EmptyDecodable)
- 49 `try?` usages — all verified as intentional (file deletion, optional conversion, cache decode)
- Typed error enums on every API client (SmartThingsError, NestSDMError, SonosSOAPError, ProviderError)
- Consistent naming conventions throughout

**Findings:**
- No issues. Force casts are provably safe. TODO count is low and well-documented.

### Performance: A- (3.7)
No main-thread blocking, efficient async patterns.

**Strengths:**
- Zero Timer usage — no polling loops or battery drain
- WeatherService uses kCLLocationAccuracyKilometer (not .best) with 15-min cache
- SmartThings uses SSE push instead of polling (B2 feature)
- Write debouncer prevents rate-limit hits during slider drags
- All disk I/O is in non-View files, accessed asynchronously
- DateFormatter cached (static let)
- LazyVGrid/LazyVStack used for all device/room lists

**Findings:**
- No confirmed performance issues

### Concurrency: A (4.0)
Excellent Swift 6 readiness.

**Strengths:**
- 55 @MainActor annotations across all providers, stores, and controllers
- 24 @Observable classes — zero ObservableObject legacy
- Only 1 DispatchQueue.main.async call (in AllDevicesView for merged lookup update — intentional)
- 25 `nonisolated` marks — all on protocol delegate methods (CLLocationManagerDelegate, HMHomeManagerDelegate) where required
- SSE client uses structured concurrency (Task + AsyncBytes)
- SmartThingsWriteDebouncer is fully MainActor-isolated

**Findings:**
- No issues. The codebase is effectively Swift 6 ready.

### Security: A (4.0)
Strong security posture.

**Strengths:**
- All tokens in Keychain (KeychainAccess v4.2.2, pinned to tagged release)
- PrivacyInfo.xcprivacy with UserDefaults declaration
- .completeFileProtection on all disk cache writes
- No hardcoded secrets (Nest credentials via Info.plist/xcconfig)
- No sensitive data in UserDefaults (14 @AppStorage keys are all UI preferences)
- No ATS exceptions
- All debug prints wrapped in #if DEBUG
- HomeKit entitlement only — matches actual usage

**Findings:**
- No issues (pre-release double-weighted, still A)

### Accessibility: B+ (3.3)
Comprehensive VoiceOver support, gaps in UI testing hooks.

**Strengths:**
- 205 accessibilityLabel annotations across 35+ views
- Safety-critical elements (smoke alarm Call 911, Silence) explicitly labeled
- `.accessibilityHidden(true)` on decorative icons
- `.accessibilityElement(children: .combine)` groups related content
- `.accessibilityAddTraits(.isHeader)` on section headers

**Findings:**
- 0 accessibilityIdentifiers — no hooks for UI automation testing
- 438 fixed font sizes via `.font(.system(size:))` — these break Dynamic Type. Many are intentional (constrained tile layouts) but some should migrate to `.font(.caption)` / `.font(.body)` equivalents

### Testing: B+ (3.3)
Good coverage across all major subsystems.

**Strengths:**
- 127 tests, 0 failures, runs in <0.3s
- 10 test files covering: DeviceMerging, SmartThingsAPIClient, SmartThingsCapabilityMapper, SceneRunner, SonosSOAPClient, KeychainTokenStore, WeatherService, ProviderRegistry, NestCapabilityMapper, SmartCommandRouter
- URLProtocol-stubbed network tests (no real API calls)
- Mock providers for isolation

**Findings:**
- No UI tests (XCUITest target not configured)
- No test coverage for SonosProvider, HomeKitProvider, or NestProvider integration paths
- No test coverage for SSE event stream parsing

### UI/UX Patterns: A- (3.7)
Modern SwiftUI patterns throughout.

**Strengths:**
- Zero deprecated APIs
- 13 `#if os()` conditionals for proper platform handling
- Toast system for non-blocking feedback (replaces .alert modals)
- Offline banner on LightControlView
- Stale data indicator on dashboard
- Pull-to-refresh with failure toast
- Scene retry mechanism for partial failures

**Findings:**
- No issues

### Data & Persistence: B+ (3.3)
Appropriate storage choices for the domain.

**Strengths:**
- JSON file caches (SmartThingsAccessoryCache, NestAccessoryCache, SmokeAlarmEventStore) with atomic writes and .completeFileProtection
- SceneStore for cross-ecosystem scene persistence
- Keychain for all secrets
- No SwiftData/CoreData (appropriate — the app is a real-time dashboard, not a data-heavy CRUD app)
- Disk cache cleared on explicit disconnect (no ghost devices)

**Findings:**
- No schema versioning on JSON caches — a breaking model change would silently drop cached data (graceful degradation is fine, but a version field would be better)

---

## Issue Rating Table

| # | Finding | Urgency | Risk: Fix | Risk: No Fix | ROI | Blast Radius | Fix Effort |
|---|---------|---------|-----------|-------------|-----|-------------|------------|
| 1 | 9 files >500 LOC (SonosPlayerDetailView 1411 lines) | 🟢 Medium | ⚪ Low | 🟢 Medium | 🟢 Good | ⚪ 1 file each | Medium |
| 2 | 0 accessibilityIdentifiers for UI test automation | 🟢 Medium | ⚪ Low | 🟢 Medium | 🟢 Good | 🟡 All views | Medium |
| 3 | 438 fixed font sizes (.system(size:)) | ⚪ Low | 🟢 Medium | ⚪ Low | 🟡 Marginal | 🟡 All views | Large |
| 4 | No XCUITest target | 🟢 Medium | ⚪ Low | 🟢 Medium | 🟢 Good | ⚪ New target | Small |
| 5 | No cache schema versioning | ⚪ Low | ⚪ Low | ⚪ Low | 🟡 Marginal | 🟢 3 files | Small |
| 6 | No provider integration tests | ⚪ Low | ⚪ Low | ⚪ Low | 🟡 Marginal | ⚪ New files | Medium |

---

## Next Steps

**Immediate (This Week):**
- App icon (1024x1024 PNG) — App Store blocker
- App Store screenshots — App Store blocker
- Support/Privacy Policy URLs — App Store blocker

**Short-term (This Month):**
- [#1] Extract 3 largest files (SonosPlayerDetailView, AllDevicesView, SonosProvider) into smaller units
- [#4] Create XCUITest target and add smoke test for main user flows
- [#2] Add accessibilityIdentifiers to key interactive elements for UI test hooks

**Medium-term (This Quarter):**
- [#3] Audit fixed font sizes — migrate to Dynamic Type where layout allows
- [#5] Add schema version to JSON caches
- [#6] Add integration tests for provider refresh/execute paths
