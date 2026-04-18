# Workflow Audit — House Connect

**Date:** 2026-04-17
**Scope:** Full 5-layer audit
**Files scanned:** 110+ Swift files across Features/, Core/, Tests/

---

## Executive Summary

The app has solid core navigation (tabs, settings, device detail routing) but contains **6 orphaned views** that were built but never wired into the navigation graph, **5 placeholder action buttons** in multi-room audio that do nothing when tapped, and **3 views with fully hardcoded data** in the Network Diagnostics section. The critical user paths (device control, scenes, settings) work correctly. The main risk area is multi-room audio where several buttons silently fail.

---

## Issue Rating Table

| # | Finding | Urgency | Risk: Fix | Risk: No Fix | ROI | Blast Radius | Fix Effort |
|---|---------|---------|-----------|-------------|-----|-------------|------------|
| 1 | **Orphaned:** MultiRoomNowPlayingView — built but unreachable, no navigation path exists | 🔴 Critical | ⚪ Low | 🟡 High | 🟠 Excellent | ⚪ 1 file | Small |
| 2 | **Orphaned:** DeviceGroupDetailView — built but unreachable (SonosBondedGroupDetailView used instead) | 🔴 Critical | ⚪ Low | 🟢 Medium | 🟢 Good | ⚪ 1 file | Trivial |
| 3 | **Orphaned:** NetworkSettingsView, NetworkDiagnosticsView, NetworkListView, TopologyConnectionDetailView — all unreachable from DeviceNetworkTopologyView | 🔴 Critical | ⚪ Low | 🟡 High | 🟠 Excellent | 🟡 4 files | Small |
| 4 | **Dead button:** MultiRoomNowPlayingView "Cast" button — empty action placeholder | 🟡 High | ⚪ Low | 🟡 High | 🟢 Good | ⚪ 1 file | Small |
| 5 | **Dead button:** MultiRoomNowPlayingView "Remove room from group" — empty action | 🟡 High | ⚪ Low | 🟡 High | 🟢 Good | ⚪ 1 file | Small |
| 6 | **Dead button:** MultiRoomNowPlayingView "Retry connection" — shows toast but no real retry | 🟡 High | ⚪ Low | 🟡 High | 🟢 Good | ⚪ 1 file | Small |
| 7 | **Dead button:** MultiRoomNowPlayingView "Remove from group" (disconnected) — empty action | 🟡 High | ⚪ Low | 🟡 High | 🟢 Good | ⚪ 1 file | Small |
| 8 | **Mock data:** NetworkDiagnosticsView — all metrics are hardcoded (lastScan = "2 min ago", etc.) | 🟡 High | ⚪ Low | 🟢 Medium | 🟡 Marginal | ⚪ 1 file | Medium |
| 9 | **Mock data:** NetworkSettingsView — all toggles are local @State, no persistence or real effect | 🟡 High | ⚪ Low | 🟢 Medium | 🟡 Marginal | ⚪ 1 file | Medium |
| 10 | **Mock data:** TopologyNodeDetailSheet — network info (IP, signal, latency) is placeholder | 🟢 Medium | ⚪ Low | ⚪ Low | 🟡 Marginal | ⚪ 1 file | Medium |
| 11 | **Mock data:** TopologyConnectionDetailView — connection metrics are all fabricated | 🟢 Medium | ⚪ Low | ⚪ Low | 🟡 Marginal | ⚪ 1 file | Medium |
| 12 | **Disabled feature:** Camera Record button — permanently disabled, shows "Use Circle app" | 🟢 Medium | ⚪ Low | ⚪ Low | 🔴 Poor | ⚪ 1 file | N/A |
| 13 | **Disabled feature:** Camera Siren button — permanently disabled, shows "Use Circle app" | 🟢 Medium | ⚪ Low | ⚪ Low | 🔴 Poor | ⚪ 1 file | N/A |
| 14 | **Disabled feature:** Smoke Alarm "Run Self-Test" — shows "Soon" badge, not functional | 🟢 Medium | ⚪ Low | ⚪ Low | 🟡 Marginal | ⚪ 1 file | Medium |
| 15 | **Stale comment:** HomeDashboardView header comment says "Weather card is a static placeholder" — but WeatherService IS wired and live | ⚪ Low | ⚪ Low | ⚪ Low | 🟠 Excellent | ⚪ 1 file | Trivial |

---

## Layer 1: Entry Point Inventory

### Sheets (12 triggers)
| Sheet | Trigger File | Target |
|-------|-------------|--------|
| SmartThings Token Entry | ProvidersSettingsView | SmartThingsTokenEntryView |
| Nest OAuth | ProvidersSettingsView | NestOAuthView |
| HA Setup | ProvidersSettingsView | HomeAssistantSetupView |
| Create Room | HomeDashboardView, AllRoomsView | CreateRoomSheet |
| Select Rooms (multi-room) | AudioZonesMapView | MultiRoomSelectRoomsSheet |
| Action Picker (scene editor) | SceneEditorView | ActionPickerSheet |
| Add Device category | AddDeviceView | CategoryChooser |
| Add Device to room | RoomDetailView | DeviceAssignSheet |
| Smoke alert | RootTabView | SmokeAlarmAlertView (fullScreenCover) |

### Navigation Destinations (11 settings routes)
All `SettingsDestination` cases are handled in 3 switches (Settings, Dashboard, RootTab): ✅ Complete

### Tab Bar (4 tabs)
Home, Devices, Add, Settings: ✅ All wired

---

## Layer 2: Critical Flow Traces

### ✅ Working Flows
1. **Home → Room → Device → Control** — full path works
2. **Devices → Merged tile → Detail → Command** — smart routing works
3. **Settings → Connections → Connect HA** — fixed, works with dual URL
4. **Settings → Scenes → Run** — local + HA scenes both fire
5. **Settings → Automations → Trigger/Toggle** — wired to HA
6. **Notification bell → Notifications Center** — wired, unread badge works
7. **Scene tile → Run → Toast feedback** — works with retry on failure

### ❌ Broken Flows
1. **Settings → Network Topology → [sub-views]** — topology view renders the map but has NO navigation to NetworkSettingsView, NetworkDiagnosticsView, NetworkListView, or TopologyConnectionDetailView. These 4 views exist but are unreachable.
2. **Multi-room audio → Now Playing** — `MultiRoomNowPlayingView` exists but is never instantiated. The audio zone map shows linked groups but there's no way to reach the expanded now-playing view.
3. **Speaker group → DeviceGroupDetailView** — exists but never instantiated. `SonosBondedGroupDetailView` is used instead (which is a different view for bonded/home-theater sets).

---

## Layer 3: Issue Catalog

### Orphaned Views (6)
Views that exist in the project but have zero instantiation paths:

| View | Lines | Purpose | Likely Fix |
|------|-------|---------|------------|
| `MultiRoomNowPlayingView` | 441 | Expanded now playing with per-room volume | Wire from AudioZonesMapView linked group tap |
| `DeviceGroupDetailView` | 285 | Bonded speaker group detail | Wire from DeviceDetailView or remove (SonosBondedGroupDetailView covers this) |
| `NetworkSettingsView` | 210 | Hub config with protocol toggles | Wire from DeviceNetworkTopologyView settings button |
| `NetworkDiagnosticsView` | ~200 | Health checks and metrics | Wire from DeviceNetworkTopologyView diagnostics button |
| `NetworkListView` | ~240 | Searchable device list | Wire from DeviceNetworkTopologyView list button |
| `TopologyConnectionDetailView` | ~200 | Connection detail between nodes | Wire from topology node tap → connection |

### Placeholder Actions (5)
Buttons that exist in the UI but have empty/no-op action closures:

| Button | File | Line | Action |
|--------|------|------|--------|
| "Cast" (AirPlay) | MultiRoomNowPlayingView | 121 | `// Cast action placeholder` |
| "Remove room from group" (xmark) | MultiRoomNowPlayingView | 365 | `// Remove room from group placeholder` |
| "Retry connection" | MultiRoomNowPlayingView | 431 | Shows toast only, no real retry |
| "Remove from group" (disconnected) | MultiRoomNowPlayingView | 448 | `// Remove from group placeholder` |

### Hardcoded Data Views (4)
Views where all or most data is static/fabricated:

| View | What's Hardcoded |
|------|-----------------|
| NetworkDiagnosticsView | lastScan, all metric values, health check results, "Run Full Scan" does nothing |
| NetworkSettingsView | All toggles are local @State, no persistence, no effect on real devices |
| TopologyNodeDetailSheet | IP address, signal strength, latency, connected devices are all placeholder |
| TopologyConnectionDetailView | Bandwidth, latency, packet loss, connection history are fabricated |

---

## Layer 4: UX Impact Assessment

### Critical Impact (Users will notice)
- **Multi-room "Remove from group" doesn't work** — user taps xmark to remove a room from the audio group, nothing happens. No error, no feedback. This is the worst kind of failure — silent.
- **Network sub-views unreachable** — Settings has a "Network Topology" row that opens the map, but there's no way to reach the detailed settings, diagnostics, or device list views from there. The map is a dead end.

### Medium Impact (Power users will notice)
- **MultiRoomNowPlayingView unreachable** — users see linked speaker groups on the audio zones map but can't tap into the expanded now-playing view with per-room volume controls. This was a key design in Pencil.
- **Network diagnostics shows fake data** — if a user reaches this view (currently they can't), they'd see hardcoded metrics that don't reflect reality.

### Low Impact (Cosmetic/maintenance)
- **Camera Record/Siren permanently disabled** — documented as intentional (HomeKit limitation), hint text explains it. Not a bug.
- **Smoke alarm "Soon" badge** — documented as waiting for real Nest integration. Acceptable.

---

## Layer 5: Data Wiring

### ✅ Properly Wired
| Feature | Data Source | Status |
|---------|-----------|--------|
| Weather card | WeatherService (Open-Meteo API) | Live data ✅ |
| Device tiles | ProviderRegistry.allAccessories | Live data ✅ |
| Room tiles | ProviderRegistry.allRooms | Live data ✅ |
| Scene tiles | SceneStore + HomeAssistantProvider.scenes | Live data ✅ |
| Automation list | HomeAssistantProvider.automations | Live data ✅ |
| Smoke alarm events | SmokeAlarmEventStore (persisted) | Live data ✅ |
| Provider status | ProviderAuthorizationState | Live data ✅ |
| Notification feed | AppEventStore | Live data ✅ |

### ❌ Mock/Hardcoded Data
| Feature | Issue | Impact |
|---------|-------|--------|
| NetworkDiagnosticsView | All metrics hardcoded | Shows fake health data |
| NetworkSettingsView | Toggles have no backing store | Changes don't persist or do anything |
| TopologyNodeDetailSheet | Device info is placeholder | Shows fake IP/signal/latency |
| TopologyConnectionDetailView | Connection metrics fabricated | Shows fake bandwidth/packet loss |
| Camera activity (fixed) | Was hardcoded → now uses CameraController.recentActivity | ✅ Fixed earlier |

### ❌ Unwired Integration Points
| Integration | What Exists | What's Missing |
|-------------|-------------|----------------|
| HA Nest | Google OAuth client + HA integration | OAuth consent screen blocked (org_internal) |
| Multi-room remove/retry | SOAP join/leave commands exist | MultiRoomNowPlayingView buttons not wired to them |
| Network topology → sub-views | 4 sub-views fully built | No navigation from topology view to any of them |

---

## Recommendations (Priority Order)

### Immediate (fix now)
1. **Wire multi-room now playing:** Add NavigationLink from AudioZonesMapView linked group rows → MultiRoomNowPlayingView
2. **Wire network sub-views:** Add buttons/NavigationLinks in DeviceNetworkTopologyView to reach NetworkSettingsView, NetworkDiagnosticsView, NetworkListView
3. **Wire multi-room remove/retry buttons:** Connect the 4 placeholder buttons in MultiRoomNowPlayingView to real `leaveSpeakerGroup` / `refresh` commands

### Short-term (this week)
4. **Decide on DeviceGroupDetailView:** Either wire it (different from SonosBondedGroupDetailView) or delete it as dead code
5. **TopologyConnectionDetailView:** Wire from topology node detail → connection tap, or mark as future feature
6. **Fix stale comment:** Update HomeDashboardView header to acknowledge WeatherService is live

### Medium-term (this month)
7. **Replace hardcoded network data:** When HA is the primary backend, network diagnostics can pull real device/connectivity data from HA's device registry
8. **NetworkSettingsView toggles:** Either persist to UserDefaults or remove the view if it's not meaningful without hub hardware

---

## Metrics

| Metric | Count |
|--------|-------|
| Total entry points scanned | 23 (12 sheets + 11 nav destinations) |
| Working flows | 7 |
| Broken flows | 3 |
| Orphaned views | 6 |
| Placeholder actions | 5 (4 in MultiRoomNowPlayingView) |
| Mock data views | 4 |
| Total issues | 15 |
| Critical | 3 |
| High | 6 |
| Medium | 4 |
| Low | 2 |
