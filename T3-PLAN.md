# T3 Design — Implementation Plan & Gap Analysis

**Date:** 2026-04-17
**Current state:** 20 T3 SwiftUI views built, core flow works, many gaps in wiring and data binding

---

## Current Status

### ✅ Fully T3 + Wired
| View | Data | Navigation | Commands |
|------|------|-----------|----------|
| T3SplashView | Static | → T3RootView | N/A |
| T3RootView | Registry | Tab switching | N/A |
| T3TabBar | Selection binding | Tab routing | N/A |
| T3RoomDetailView | Live devices | → T3DeviceDetailView | Power toggle via TPill |
| T3ThermostatView | Live capabilities | Back → Room | +/- target, mode select |
| T3LightDetailView | Live capabilities | Back → Room | Brightness, color temp, power |
| T3LockDetailView | Static access log | Back → Room | Lock/unlock toggle |
| T3SpeakerDetailView | Live capabilities | Back → Room | Play/pause, volume, prev/next |
| T3DeviceDetailView | Category routing | Dispatches to detail | N/A |

### ⚠️ T3 Built But NOT Fully Wired

| View | Issue |
|------|-------|
| **T3HomeDashboardView** | ❌ No notification bell / link to notifications. ❌ Scene chips don't actually RUN scenes (visual only). ❌ Weather "Inside" + "Energy" are hardcoded. ❌ No pull-to-refresh. |
| **T3RoomsTabView** | ❌ "New room" button is no-op. ❌ No pull-to-refresh. |
| **T3DevicesTabView** | ❌ Device rows don't navigate to detail. ❌ "Add device" button is no-op. ❌ Filter only works client-side (no HA integration). |
| **T3SettingsTabView** | ❌ All rows are static — NO NavigationLinks to any settings screen. Just visual. |
| **T3ScenesListView** | ❌ "Add scene" button is no-op. ❌ RUN button works ✅ |
| **T3AutomationsView** | ✅ Trigger + toggle work. |
| **T3ProvidersView** | ❌ Rows don't navigate to provider detail. |
| **T3NotificationsView** | ❌ Not reachable from T3HomeDashboard (no bell icon). |
| **T3ActivityView** | ❌ Not reachable from any T3 view. |
| **T3EnergyView** | ❌ Not reachable from any T3 view. ❌ All data hardcoded. |

### ❌ Old Views Still Used (Fallback from T3DeviceDetailView)
| View | Why |
|------|-----|
| FrameTVDetailView | Partially T3-styled but uses old Theme colors |
| SmokeAlarmDetailView | Green/red colors don't match T3 palette |
| CameraDetailView | Dark feed clashes with cream background |
| DeviceOfflineView | Old lavender styling |
| AccessoryDetailView | Old generic form — covers sensors, switches, fans, blinds, outlets |
| SonosBondedGroupDetailView | Old styling |
| AudioZonesMapView | Old styling + circle visualization |
| All network/topology views | Old styling + hardcoded data |
| SceneEditorView | Old form styling |
| AddDeviceView | Old styling |
| AboutView, HelpFAQView | Old styling |
| AppearanceView, NotificationPreferencesView | Old styling |
| HomeAssistantSetupView | Functional but old styling |

### ❌ Icons
All T3 views use SF Symbols as fallback. The T3 handoff specifies 40+ custom outlined glyphs (1.4px stroke, square linecap, miter join). See `T3-ICON-GAPS.md`.

### ❌ Fonts
Inter Tight + IBM Plex Mono are bundled but may not load if the font files aren't added to the Xcode target's "Copy Bundle Resources" build phase. Need to verify in Xcode.

---

## Implementation Plan

### Phase 1: Wire T3 Navigation (HIGH PRIORITY)
**Goal:** Make every tap in the T3 UI go somewhere real.

| # | Task | Effort | Files |
|---|------|--------|-------|
| 1.1 | T3HomeDashboard: Add notification bell → T3NotificationsView | Small | T3HomeDashboardView |
| 1.2 | T3HomeDashboard: Wire scene chips to actually run scenes via SceneRunner | Small | T3HomeDashboardView |
| 1.3 | T3HomeDashboard: Add pull-to-refresh | Small | T3HomeDashboardView |
| 1.4 | T3SettingsTabView: Wire ALL rows with NavigationLinks to SettingsDestination | Medium | T3SettingsTabView |
| 1.5 | T3DevicesTabView: Wire device rows to navigate to T3DeviceDetailView | Small | T3DevicesTabView |
| 1.6 | T3DevicesTabView: Wire "Add device" button to AddDeviceView | Trivial | T3DevicesTabView |
| 1.7 | T3RoomsTabView: Wire "New room" to CreateRoomSheet | Small | T3RoomsTabView |
| 1.8 | T3ProvidersView: Wire rows to provider detail (or ProvidersSettingsView) | Small | T3ProvidersView |
| 1.9 | T3HomeDashboard: Wire Energy cell to T3EnergyView | Small | T3HomeDashboardView |
| 1.10 | T3HomeDashboard: Wire Activity (future) | Small | T3HomeDashboardView |

### Phase 2: Live Data Binding (HIGH PRIORITY)
**Goal:** Replace all hardcoded values with real provider data.

| # | Task | Effort | Files |
|---|------|--------|-------|
| 2.1 | T3HomeDashboard: Read indoor temp from HA climate entity | Small | T3HomeDashboardView |
| 2.2 | T3HomeDashboard: Read energy from HA energy entities (or keep placeholder) | Medium | T3HomeDashboardView |
| 2.3 | T3LockDetailView: Read real recent access from provider events | Medium | T3LockDetailView |
| 2.4 | T3SpeakerDetailView: Read group-with state from speakerGroup membership | Small | T3SpeakerDetailView |
| 2.5 | T3EnergyView: Wire to HA energy entities (if available) | Large | T3EnergyView |
| 2.6 | T3SettingsTabView: Read real provider counts + connection status | Small | T3SettingsTabView |

### Phase 3: Convert Remaining Old Views to T3 (MEDIUM PRIORITY)
**Goal:** Consistent T3 aesthetic everywhere.

| # | Task | Effort | Needs Design Input? |
|---|------|--------|-------------------|
| 3.1 | DeviceOfflineView → T3 version | Small | Low confidence — ask Claude Design |
| 3.2 | FrameTVDetailView → Fully T3 tokens (already partially done) | Small | No |
| 3.3 | AboutView → T3 version | Small | No |
| 3.4 | HelpFAQView → T3 version | Small | No |
| 3.5 | AppearanceView → T3 version | Small | No |
| 3.6 | NotificationPreferencesView → T3 version | Small | No |
| 3.7 | AddDeviceView → T3 version | Medium | Low confidence |
| 3.8 | HomeAssistantSetupView → T3 version | Small | No |
| 3.9 | AccessoryDetailView (generic) → T3 version | Medium | Low confidence |
| 3.10 | CameraDetailView → T3 version | Medium | Needs design input |
| 3.11 | SmokeAlarmDetailView → T3 version | Medium | Needs design input |
| 3.12 | SmokeAlarmAlertView → T3 version (keep red?) | Small | Needs design input |
| 3.13 | AudioZonesMapView → T3 version | Large | Needs design input |
| 3.14 | MultiRoomNowPlayingView → T3 version | Medium | Needs design input |
| 3.15 | SceneEditorView → T3 version | Medium | Needs design input |
| 3.16 | TopologyStatusViews (5) → T3 version | Medium | Needs design input |

### Phase 4: Custom Icons (MEDIUM PRIORITY)
**Goal:** Replace SF Symbol fallbacks with T3 custom glyphs.

| # | Task | Effort |
|---|------|--------|
| 4.1 | Get SVG exports from Claude Design (40+ glyphs) | External |
| 4.2 | Convert SVGs to Xcode Custom Symbol Images or SwiftUI Shape paths | Medium |
| 4.3 | Create T3Icon component that renders the right glyph by name | Small |
| 4.4 | Replace all Image(systemName:) calls in T3 views with T3Icon | Medium |

### Phase 5: Polish & Verify (LOW PRIORITY)
| # | Task |
|---|------|
| 5.1 | Verify Inter Tight + IBM Plex Mono fonts are loading (check Xcode build phase) |
| 5.2 | Add pull-to-refresh to T3RoomsTabView + T3DevicesTabView |
| 5.3 | Add toast feedback system to T3 views (success/error) |
| 5.4 | Add accessibility labels to all T3 views |
| 5.5 | Verify tab bar doesn't overlap scrollable content (add bottom padding to all scroll views) |
| 5.6 | Test on iPhone SE (small screen) — verify 168px thermostat number scales |
| 5.7 | Test dark mode (T3 is light-only by design — should force light) |

---

## Priority Order

1. **Phase 1 (Wire Navigation)** — users are tapping dead buttons right now
2. **Phase 2 (Live Data)** — hardcoded values look wrong when real devices exist
3. **Phase 3.2-3.6 (Easy T3 Conversions)** — About, Help, Appearance, Notifications, FrameTV
4. **Phase 4 (Icons)** — waiting on Claude Design SVG exports
5. **Phase 3.7-3.16 (Complex T3 Conversions)** — waiting on Claude Design mockups
6. **Phase 5 (Polish)** — before App Store submission

---

## What to Feed to Claude Design

1. `T3-REMAINING.md` — 8 views needing mockups with specific design questions
2. `T3-ICON-GAPS.md` — 40+ glyphs needing SVG export
3. Screenshot of current T3 app for context
4. Ask: "Design T3-style versions of these 8 screens, and export the 40 custom glyphs as SVGs"
