# House Connect — Product Requirements Document

**Version:** 2.0
**Date:** 2026-04-17
**Status:** In Development
**Platform:** iOS 17+ (iPhone, iPad)

---

## 1. Product Overview

### 1.1 Vision
House Connect is a premium native iOS app that provides a beautiful, unified smart home experience over a Home Assistant backend. It replaces the default HA companion app with a curated, design-forward interface that makes controlling your entire home feel effortless.

### 1.2 Problem Statement
Smart home users with multiple ecosystems (HomeKit, SmartThings, Nest, Sonos, Hue) face fragmented control across 5+ apps. Home Assistant unifies the backend but its companion app lacks the polish and native iOS feel that premium users expect. House Connect bridges this gap.

### 1.3 Target User
Tech-savvy homeowner (25-45) with 10-50+ smart devices across multiple ecosystems, running Home Assistant on a dedicated device. Values design quality, fast interactions, and a "just works" experience. Willing to do initial setup but expects zero daily friction after.

### 1.4 Core Differentiators
- Native SwiftUI with custom animations (not a web wrapper)
- Device-specific detail views (not generic forms)
- Cross-provider capability union with smart command routing
- Real-time updates via WebSocket
- Automatic local/remote URL switching (home Wi-Fi vs Tailscale)
- Curated device experiences (Samsung Frame TV art mode, Sonos multi-room zones)

---

## 2. Architecture

### 2.1 Backend
- **Primary:** Home Assistant (WebSocket + REST API)
- **Server:** User's HA instance (local IP + optional Tailscale remote)
- **Auth:** Long-lived access token stored in iOS Keychain
- **Legacy providers:** HomeKit, SmartThings, Sonos, Nest (coexist alongside HA, removable once HA verified)

### 2.2 Data Flow
```
HA WebSocket ──→ HomeAssistantProvider ──→ ProviderRegistry ──→ SwiftUI Views
                       ↓                        ↓
                  Capability Mapper         SmartCommandRouter
                       ↓                        ↓
                  Accessory Model           MergedDeviceLookup
```

### 2.3 State Management
- `@Observable` classes for all providers, stores, controllers
- `@Environment` injection from app root
- `@AppStorage` for UI preferences only (never secrets)
- `KeychainTokenStore` for all credentials

---

## 3. Screen Inventory

### 3.1 Tab Structure

| Tab | Icon | Primary Screen | Description |
|-----|------|----------------|-------------|
| Home | house.fill | HomeDashboardView | Dashboard with weather, scenes, rooms |
| Devices | rectangle.stack.fill | AllDevicesView | All devices merged across providers |
| Add | plus.circle | AddDeviceView | Device pairing flow |
| Settings | gearshape.fill | SettingsView | App + provider configuration |

### 3.2 Core Navigation Screens

#### Home Dashboard (`HomeDashboardView`)
- **Pencil:** `A1WUK`
- **Purpose:** At-a-glance home status, quick scene activation, room navigation
- **Sections:**
  - Header: Greeting + profile avatar + notification bell (with unread badge)
  - Weather card: Temperature, condition, suggestion (via Open-Meteo API)
  - Home status row: Device count, active count, offline count chips
  - Disconnected provider banners (amber, when a provider is offline)
  - Stale data hint (when last refresh > 5 minutes)
  - Quick Scenes: Horizontal scroll of local + HA unified scenes
  - My Rooms: 2-column grid of room tiles with device counts
- **Navigation targets:** Room detail, scene editor, notifications, all settings destinations
- **Data sources:** ProviderRegistry, SceneStore, WeatherService, AppEventStore

#### All Devices (`AllDevicesView`)
- **Pencil:** `rv14r` (by room), `j8hFZ` (by device)
- **Purpose:** Browse and control all devices across all providers
- **Modes:** Devices (merged tiles) | Rooms (grouped by room) | Networks (grouped by provider)
- **Features:**
  - Search bar (filters by name)
  - Pull-to-refresh (fans out to all providers)
  - Device tiles with provider badge chips
  - Category icons (light, thermostat, camera, speaker, lock, etc.)
  - Offline state dimming
  - DeviceMerging: Same physical device from multiple providers collapses to one tile
- **Data sources:** ProviderRegistry, DeviceMerging, MergedDeviceLookup

#### Room Detail (`RoomDetailView`)
- **Pencil:** `ewnMb`
- **Purpose:** View and control all devices in a specific room
- **Features:**
  - Room name + device count header
  - Device rows with category icon, name, state subtitle, power toggle
  - Swipe actions: Remove from room
  - Context menu: Edit, Remove
  - Add device button (assign existing devices)
  - Delete room (with confirmation)
  - Rename room (inline alert)
- **Data sources:** ProviderRegistry (filtered by room)

#### Settings (`SettingsView`)
- **Pencil:** `RlG8v`
- **Purpose:** App and provider configuration
- **Sections:**
  - HOME: Connections, Rooms, Scenes, Automations, Audio Zones, Network Topology
  - PREFERENCES: Appearance, Notifications
  - SUPPORT: Help & FAQ, About
- **Navigation:** Each row pushes to a dedicated settings screen

### 3.3 Device Detail Screens

#### Light Control (`LightControlView`)
- **Pencil:** `kNqSI`
- **Purpose:** Full light control with visual feedback
- **Controls:**
  - Power toggle (via DeviceDetailHeader)
  - Brightness bar visualizer (drag to adjust, 0-100%)
  - Color temperature slider (2700K-6500K warm→cool gradient)
  - Quick presets: Reading, Relax, Energize, Movie, Party (brightness + kelvin combos)
  - Schedule section: "Coming soon" placeholder
  - Remove device button
- **Commands:** setPower, setBrightness, setColorTemperature
- **Features:** isExecuting loading state, offline banner, error banner with dismiss

#### Thermostat Detail (`ThermostatDetailView`)
- **Pencil:** `gpAyI`
- **Purpose:** Temperature control with mode selection
- **Controls:**
  - Large temperature display (current reading)
  - +/- nudge buttons (±1°F or ±0.5°C with draft debounce)
  - Target temperature chip
  - Temperature bar (visual range indicator)
  - HVAC mode chips: Heat, Cool, Auto, Off (highlight selected)
  - Stats card: Indoor temp, Outdoor (N/A), Humidity (N/A)
  - Schedule card: "Coming soon" placeholder
- **Commands:** setTargetTemperature, setHVACMode, setPower
- **Features:** Unit toggle (°F/°C via AppStorage), isExecuting guard

#### Samsung Frame TV (`FrameTVDetailView`)
- **Pencil:** `GrzJY`
- **Purpose:** Premium TV control with art mode awareness
- **Controls:**
  - Hero card: Now-playing / art mode / TV-off states
  - Status row: Power indicator + current source
  - Input source selector: Horizontal chip scroll from HA sourceList
  - Remote buttons: Power, Vol-, Vol+, Mute (circular)
  - Brightness + Color Tone sliders
  - Volume display
- **Commands:** setPower, selectSource, setVolume, setMute, setBrightness
- **Features:** Art mode detection from source name, smart command routing (B6)

#### Sonos Speaker (`SonosPlayerDetailView`)
- **Pencil:** `ypxJT`
- **Purpose:** Music playback and multi-room audio control
- **Controls:**
  - Album art card with title/artist/album
  - Transport row: Shuffle, Previous, Play/Pause, Next, Repeat
  - Progress bar with elapsed/remaining time
  - Volume slider
  - Speaker group card: Group volume, per-member volume, add/remove rooms
- **Commands:** play, pause, next, previous, setVolume, setGroupVolume, setMute, setShuffle, setRepeatMode, joinSpeakerGroup, leaveSpeakerGroup
- **Features:** Coordinator routing, group topology refresh

#### Security Camera (`CameraDetailView`)
- **Pencil:** `UUlP4`
- **Purpose:** Camera feed viewing and settings
- **Controls:**
  - Live feed preview (HMCameraView for HomeKit, placeholder for others)
  - Action tiles: Snapshot, Talk (mic toggle), Record (disabled), Siren (disabled)
  - Settings toggles: Motion Detection, Night Vision, Push Notifications, Speaker
  - Recent Activity card (from CameraController.recentActivity)
- **Features:** Disabled tile hints ("Use Circle app"), unavailable hint text

#### Smoke Alarm (`SmokeAlarmDetailView`)
- **Pencil:** `mATCa`
- **Purpose:** Smoke/CO alarm monitoring and testing
- **Controls:**
  - All Clear card (green shield) or alert state
  - Status rows: Smoke, CO, Battery, Humidity (from capabilities)
  - Self-test button: "Coming soon" (needs real Nest integration)
  - Simulation card (dev-only, triggers Live Activity pipeline)
  - Recent Events card (from SmokeAlarmEventStore, persisted)
- **Features:** Data-driven from smokeDetected/coDetected capabilities
- **Emergency:** Full-screen red alert via SmokeAlarmAlertView + Live Activity

#### Device Offline (`DeviceOfflineView`)
- **Pencil:** `E7fJS`
- **Purpose:** Shown when device.isReachable is false
- **Content:** Offline icon, status message, troubleshooting tips, refresh button

### 3.4 Multi-Room Audio Screens

#### Audio Zones Map (`AudioZonesMapView`)
- **Pencil:** `ixmFl`
- **Purpose:** Visualize and manage speaker groupings
- **Modes:** Map (circle visualization) | List (speaker list)
- **Features:** Zone cards, "+" button for new groups, Edit Zone button
- **Post-dismiss:** Topology refresh via SonosProvider.refreshTopologyAndRebuild()

#### Multi-Room Select Rooms (`MultiRoomSelectRoomsSheet`)
- **Pencil:** `g00bw`, `woiK9`, `375nI`
- **Purpose:** Choose which rooms to include in a speaker group
- **States:** Normal (toggle rows), Speaker Unavailable, No Speakers
- **CTA:** "Play on N Rooms" — dispatches join/leave commands, serialized

#### Multi-Room Now Playing (`MultiRoomNowPlayingView`)
- **Pencil:** `v5vpc`, `co524`, `pyUlJ`
- **Purpose:** Expanded now-playing with per-room volume control
- **States:** Normal, Room Added toast, Connection Lost

#### Device Group Detail (`DeviceGroupDetailView`)
- **Pencil:** `BUOyt`
- **Purpose:** Bonded speaker group (home theater, stereo pair)
- **Content:** Member list, now-playing card, group volume, ungroup button

### 3.5 Network & Diagnostics Screens

#### Network Topology (`DeviceNetworkTopologyView`)
- **Pencil:** `eJwZy`
- **Purpose:** Visual network map of all devices
- **Content:** Concentric ring layout, connection lines, node detail sheet, legend

#### Network Settings (`NetworkSettingsView`)
- **Pencil:** `q5dco`
- **Purpose:** Hub configuration, protocol toggles, auto-discovery

#### Network List (`NetworkListView`)
- **Pencil:** `Z4SXt`
- **Purpose:** Searchable device list grouped by Connected/Offline with protocol badges

#### Network Diagnostics (`NetworkDiagnosticsView`)
- **Pencil:** `zo6mD`
- **Purpose:** Health status, metrics grid, health checks, Run Full Scan

#### Topology Status Views (`TopologyStatusViews`)
- **Pencil:** `WMPrn`, `nSgaN`, `jMwkI`, `w37nK`, `oKWze`
- **Purpose:** 5 state-specific status screens (Device Added, Network Optimized, All Online, Device Lost, Hub Unreachable)

### 3.6 Settings Sub-Screens

| Screen | Purpose |
|--------|---------|
| ProvidersSettingsView | Connect/disconnect providers, status badges, device counts, last refreshed |
| HomeAssistantSetupView | HA discovery + URL entry + token entry + Tailscale remote URL |
| NestOAuthView | Google OAuth consent flow via ASWebAuthenticationSession |
| SmartThingsTokenEntryView | PAT entry for SmartThings |
| AutomationsListView | HA automations with trigger/toggle controls |
| ScenesListView | Local + HA scenes with run/retry |
| SceneEditorView | Create/edit local scenes (name, icon, action list) |
| AppearanceView | Theme, temperature unit, compact mode |
| NotificationPreferencesView | Push notification toggles per category |
| AboutView | App version, ecosystem status, support links |
| HelpFAQView | FAQ accordion with contact info |

### 3.7 Widgets & Watch

#### iOS Widgets
| Widget | Pencil | Size | Content |
|--------|--------|------|---------|
| Camera | `5lYmg` | Medium | Live badge, feed placeholder, motion event, armed status |
| Thermostat | `45PoD` | Medium | Target temp, +/- buttons, segmented bar, current temp, humidity |

#### Apple Watch
| Screen | Pencil | Content |
|--------|--------|---------|
| Watch Home | `ZNJj1` | 2x2 category grid (Lights, Climate, Locks, Media) |
| Watch Device | `9e4YX` | Light toggle + brightness bar |

### 3.8 Live Activities

| Surface | Pencil | Content |
|---------|--------|---------|
| Dynamic Island (Compact) | `hYUFC` | Smoke alert icon + room name |
| Dynamic Island (Expanded) | `EY8wa` | Alert details + Call 911 + Silence buttons |
| Lock Screen | `3eyUA` | Full alert with guidance + action buttons |

### 3.9 Branding

| Asset | Pencil | Notes |
|-------|--------|-------|
| App Icon | `LXwhQ` | 1024x1024, needs actual PNG |
| Watch Icon | `7Mhv9` | Circular variant |
| Splash Screen | `QXNHS` | Gradient + icon grid + wordmark |

---

## 4. Data Models

### 4.1 Core Models

```swift
struct Accessory: Identifiable, Hashable, Sendable, Codable {
    let id: AccessoryID           // provider + nativeID
    var name: String
    var category: Category        // light, thermostat, camera, speaker, lock, fan, blinds, outlet, switch, sensor, television, smokeAlarm, other
    var roomID: String?
    var isReachable: Bool
    var capabilities: [Capability]
    var groupedParts: [String]?   // bonded speaker sets
    var speakerGroup: SpeakerGroupMembership?
}

enum Capability: Hashable, Sendable, Codable {
    case power(isOn: Bool)
    case brightness(value: Double)        // 0.0-1.0
    case hue(degrees: Double)             // 0-360
    case saturation(value: Double)        // 0.0-1.0
    case colorTemperature(mireds: Int)
    case currentTemperature(celsius: Double)
    case targetTemperature(celsius: Double)
    case hvacMode(HVACMode)
    case contactSensor(isOpen: Bool)
    case motionSensor(isDetected: Bool)
    case batteryLevel(percent: Int)
    case playback(state: PlaybackState)
    case volume(percent: Int)
    case mute(isMuted: Bool)
    case nowPlaying(NowPlaying)
    case shuffle(isOn: Bool)
    case repeatMode(RepeatMode)
    case smokeDetected(Bool)
    case coDetected(Bool)
    case humidity(percent: Int)
    case currentSource(String)
    case sourceList([String])
    // + presetMode, climateFanMode, fanSpeed, fanDirection, coverPosition, mediaPosition, currentEffect
}
```

### 4.2 Provider Models

| Provider | Model | Mapping |
|----------|-------|---------|
| Home Assistant | HAEntityState → Accessory | Domain-based (light, climate, media_player, camera, etc.) |
| HomeKit | HMAccessory → Accessory | Service/characteristic-based |
| SmartThings | SmartThingsDTO.Device → Accessory | Capability-based |
| Sonos | SonosDiscoveredPlayer → Accessory | SOAP/UPnP-based |
| Nest | NestSDMDTO.Device → Accessory | SDM trait-based |

---

## 5. Feature Requirements

### 5.1 Home Assistant Integration (Primary)

| Req | Description | Status |
|-----|-------------|--------|
| HA-1 | WebSocket connection with auth, state subscription, service calls | Done |
| HA-2 | Entity → Accessory mapping for all common domains | Done (6 bugs fixed) |
| HA-3 | Samsung Frame TV custom detail from HA entities | Done |
| HA-4 | HA scenes alongside local scenes | Done |
| HA-5 | HA automations list with trigger/toggle | Done |
| HA-6 | Dual-URL auto-fallback (local + Tailscale) | Done |
| HA-7 | Nest integration via HA (not direct SDM) | In Progress |

### 5.2 Real-Time Updates

| Req | Description | Status |
|-----|-------------|--------|
| RT-1 | HA WebSocket state_changed events → live tile updates | Done |
| RT-2 | SmartThings SSE push → live tile updates | Done |
| RT-3 | Sonos SOAP polling → status refresh | Done |

### 5.3 Cross-Provider Intelligence

| Req | Description | Status |
|-----|-------------|--------|
| CP-1 | DeviceMerging: same device from multiple providers → one tile | Done |
| CP-2 | SmartCommandRouter: per-command best-provider routing | Done |
| CP-3 | MergedDeviceLookup: environment-injected for detail views | Done |
| CP-4 | Automatic fallback: if preferred provider fails, try next | Done |

### 5.4 Safety & Alerts

| Req | Description | Status |
|-----|-------------|--------|
| SA-1 | Smoke alarm Live Activity (warning → critical escalation) | Done |
| SA-2 | Full-screen emergency alert with Call 911 + Silence | Done |
| SA-3 | SmokeAlarmEventStore for persistent event history | Done |

### 5.5 Quality Requirements

| Req | Description | Status |
|-----|-------------|--------|
| QA-1 | 153 unit tests, 0 failures | Done |
| QA-2 | Accessibility on 35+ views (VoiceOver labels, hints, traits) | Done |
| QA-3 | PrivacyInfo.xcprivacy with UserDefaults declaration | Done |
| QA-4 | .completeFileProtection on all disk caches | Done |
| QA-5 | All debug prints in #if DEBUG | Done |
| QA-6 | KeychainAccess pinned to v4.2.2 tagged release | Done |
| QA-7 | Tech report card: Overall A- (3.72/4.0) | Done |

---

## 6. Design System

### 6.1 Design Tokens (from Pencil variables)

| Token | Value | Usage |
|-------|-------|-------|
| `$accent` | #4F46E5 | Primary action color (indigo) |
| `$accent-light` | #4F46E51A | Accent background tint |
| `$fg-primary` | #111827 | Main text |
| `$fg-secondary` | #4B5563 | Secondary text |
| `$fg-muted` | #9CA3AF | Disabled/hint text |
| `$fg-inverse` | #FFFFFF | Text on dark/accent backgrounds |
| `$surface-primary` | #F7F8FA | Page background |
| `$surface-card` | #FFFFFF | Card background |
| `$surface-secondary` | #E5E7EB | Dividers, disabled backgrounds |
| `$surface-inverse` | #111827 | Dark surfaces |
| `$danger` | #EF4444 | Error, destructive actions |
| `$success` | #10B981 | Success states |
| `$warning` | #F59E0B | Warning states |
| `$rounded-xl` | 12 | Standard card radius |
| `$rounded-2xl` | 16 | Large card radius |
| `$rounded-full` | 9999 | Pill/circle radius |

### 6.2 Typography

| Style | iOS Equivalent | Usage |
|-------|---------------|-------|
| Screen Title | .system(22, .bold) | Top-level screen headers |
| Section Header | .system(14, .semibold) + .uppercased + tracking | Section labels |
| Card Title | .system(15, .semibold) | Card heading text |
| Card Subtitle | .system(13) | Card secondary text |
| Body | .system(14) | General content |
| Caption | .system(12) | Timestamps, hints |

### 6.3 Components

| Component | Pencil ID | Usage |
|-----------|-----------|-------|
| Status Bar | `Cyg8I` | Time + signal + battery (reusable) |
| Tab Bar | `pRYHW` | 4-tab pill-style navigation (reusable) |
| Room Card | `nwmvT` | Room tile with icon, name, count (reusable) |
| Device Card | `M71ku` | Device row with icon, name, toggle (reusable) |
| IconChip | (code only) | Rounded square with SF Symbol |
| Toast | (code only) | Non-blocking top banner (success/error) |
| .hcCard() | (code only) | Standard card modifier (fill, radius, shadow) |

### 6.4 Patterns

- **Hidden nav bar + custom back button:** Used on all detail screens
- **DeviceDetailHeader:** Shared header with name, room, power toggle
- **Pull-to-refresh:** On dashboard, devices, rooms
- **Offline banner:** Orange "Device offline — controls disabled"
- **Error banner:** Red with dismiss X
- **Loading guard:** isExecuting disables controls during commands

---

## 7. Pencil Document Map

### 7.1 Frame Groups

| Frame Group | Pencil ID | Screens |
|-------------|-----------|---------|
| Core Navigation | `18Q74` | Dashboard, All Rooms, Room Detail, Device Control, Add Device, Settings |
| Device Controls | `lK0E2` | Sonos, Thermostat, Smoke Alarm, Frame TV, Camera |
| Device Organization | `6VmxV` | All Devices (by Room/Device), Group Detail |
| Multi-Room Audio | `c6XXy` | Select Rooms, Now Playing, Room Added, Speaker Unavailable, Connection Lost, No Speakers |
| Unhappy Paths | `d0BnI` | Smoke Alert, Device Offline, No Rooms, Device Pairing, Notifications |
| Visualizations | `p062h` | Audio Zones Map, Network Topology |
| Network Topology | `LtPTJ` | Settings, List, Node Detail, Connection Detail, Diagnostics, 5 topo states, Interference |
| Widgets & Watch | `RcZlG` | Camera Widget, Thermostat Widget, Watch Home, Watch Device |
| Live Activities | `HXNGX` | DI Compact, DI Expanded, Lock Screen |
| Branding | `kmKNU` | App Icon, Watch Icon, Splash Screen |
| Weather Tiles | `xHl4s` | 12 weather state variants |
| Home Assistant | `ZlK3s` | Automations List, HA Setup |
| Components | `8lX45` | Status Bar, Tab Bar, Room Card, Device Card |

---

## 8. Technical Metrics

| Metric | Value |
|--------|-------|
| Swift files | 110+ |
| Lines of code | 29,000+ |
| Unit tests | 153 |
| Test pass rate | 100% |
| Accessibility labels | 205+ |
| Providers | 5 (HA, HomeKit, SmartThings, Sonos, Nest) |
| Capability types | 20+ |
| Command types | 25+ |
| Pencil screens | 45+ |
| Build time | ~15s (incremental) |
| Test time | <0.4s |

---

## 9. Roadmap

### Shipped
- All core navigation and device detail screens
- Home Assistant integration (WebSocket + REST + mapper)
- SmartThings SSE real-time push
- Sonos DIDL-Lite metadata + group/zone management
- Cross-provider capability union (B6)
- Samsung Frame TV custom detail
- HA scenes + automations UI
- Dual-URL auto-fallback (local + Tailscale)
- Security audit (A grade), performance audit (A-), accessibility (35+ views)

### Next
- Nest integration via HA (OAuth consent screen fix needed)
- UI rebuild (user wants to customize the full experience)
- App icon + screenshots for App Store
- Remove redundant providers once HA covers all devices

### Future
- Siri/Shortcuts integration (App Intents)
- Interactive widgets (iOS 17 widget intents)
- HA automations editor (create/edit from iOS, not just trigger)
- Multi-home support
- Family sharing / multi-user
