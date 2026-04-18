# House Connect — Pencil Design Screens Reference

**Pencil file:** `/Users/brentbrooks/Documents/pencil/house connect.pen`
**Total screens:** 45+
**Design tokens:** See variables section below

Use this document to understand every screen in the House Connect iOS app. Each entry maps a Pencil node ID to its purpose, content sections, and the iOS SwiftUI view that implements it.

---

## Design Tokens (Pencil Variables)

| Token | Value | Usage |
|-------|-------|-------|
| `$accent` | `#4F46E5` | Primary action color (indigo) |
| `$accent-light` | `#4F46E51A` | Accent tinted backgrounds |
| `$fg-primary` | `#111827` | Main text |
| `$fg-secondary` | `#4B5563` | Secondary text |
| `$fg-muted` | `#9CA3AF` | Disabled/hint text |
| `$fg-inverse` | `#FFFFFF` | Text on dark/accent surfaces |
| `$surface-primary` | `#F7F8FA` | Page background |
| `$surface-card` | `#FFFFFF` | Card background |
| `$surface-secondary` | `#E5E7EB` | Dividers, disabled fills |
| `$surface-inverse` | `#111827` | Dark surfaces |
| `$danger` | `#EF4444` | Error, destructive, smoke alert |
| `$success` | `#10B981` | Success states |
| `$warning` | `#F59E0B` | Warning states |
| `$rounded-xl` | `12` | Standard card corner radius |
| `$rounded-2xl` | `16` | Large card corner radius |
| `$rounded-full` | `9999` | Pills, circles |

## Reusable Components

| Component | Pencil ID | Description |
|-----------|-----------|-------------|
| Status Bar | `Cyg8I` | iOS status bar — time + signal icons. Used as `ref` in every screen. |
| Tab Bar | `pRYHW` | 4-tab pill navigation — HOME, ROOMS, ADD, SETTINGS. Active tab uses `$accent` fill. |
| Room Card | `nwmvT` | Room tile — icon chip + room name + device count. Used in dashboard grid. |
| Device Card | `M71ku` | Device row — icon chip + name/subtitle + toggle track. Used in room detail. |

---

## Core Navigation (Frame: `18Q74`)

### Home Dashboard
- **Pencil ID:** `A1WUK`
- **iOS View:** `HomeDashboardView`
- **Content:** Greeting header ("Good Morning") + profile avatar, weather card (temp + condition + suggestion), "Quick Scenes" horizontal scroll (scene tiles), "My Rooms" 2x2 grid (room cards with device counts), tab bar
- **Key design:** Weather card uses icon chip with colored background circle. Scene tiles are square cards with icon + name. Room cards use the `nwmvT` component.

### All Rooms
- **Pencil ID:** `iVVkt`
- **iOS View:** Part of `AllDevicesView` (Rooms mode)
- **Content:** Search bar, room list with device counts, each room is a card with icon + name + count

### Room Detail
- **Pencil ID:** `ewnMb`
- **iOS View:** `RoomDetailView`
- **Content:** Room name header, device rows (Device Card component), FAB button (accent circle with plus icon, absolute positioned at bottom-right)

### Device Control (Light)
- **Pencil ID:** `kNqSI`
- **iOS View:** `LightControlView`
- **Content:** Back button + title + power toggle header, brightness bar visualizer (horizontal bars), color temperature gradient slider, "Quick Presets" chips (Reading, Relax, Energize, Movie, Party), schedule card

### Add Device
- **Pencil ID:** `KPsYW`
- **iOS View:** `AddDeviceView`
- **Content:** Header with search, category grid (lights, climate, cameras, etc.), device pairing flow

### Settings
- **Pencil ID:** `RlG8v`
- **iOS View:** `SettingsView`
- **Content:** Profile card (avatar + name), HOME section (Connections, Network, Rooms, Audio Zones, Scenes, Automations), PREFERENCES section (Appearance, Notifications), SUPPORT section (Help, About)

---

## Device Controls (Frame: `lK0E2`)

### Sonos Speaker
- **Pencil ID:** `ypxJT`
- **iOS View:** `SonosPlayerDetailView`
- **Content:** Album art card (AsyncImage with music note fallback), transport row (shuffle, prev, play/pause, next, repeat), progress bar, volume slider, speaker group card with per-member volume

### Thermostat
- **Pencil ID:** `gpAyI`
- **iOS View:** `ThermostatDetailView`
- **Content:** Large current temperature (84pt bold), +/- nudge buttons, target chip, temperature bar, HVAC mode chips (Heat/Cool/Auto/Off), stats card (indoor/outdoor/humidity), schedule card

### Smoke Alarm
- **Pencil ID:** `mATCa`
- **iOS View:** `SmokeAlarmDetailView`
- **Content:** "All Clear" green shield card, status rows (Smoke/CO/Battery/Humidity with colored badges), self-test button with "Soon" badge, simulation card (dev-only), recent events list

### Samsung Frame TV
- **Pencil ID:** `GrzJY`
- **iOS View:** `FrameTVDetailView`
- **Content:** Dark hero card (16:9 aspect, shows art mode or now-playing), "Art Mode · On" status pill + source label, input source chips (HDMI 1, HDMI 2, AirPlay, Art Mode), remote buttons (power, vol-, vol+, mute as circles), brightness + color tone sliders

### Security Camera
- **Pencil ID:** `UUlP4`
- **iOS View:** `CameraDetailView`
- **Content:** Live feed preview (dark card with LIVE badge + 1080p tag), action tiles (Snapshot, Talk, Record, Siren — last 2 disabled), settings toggles (Motion, Night Vision, Notifications, Speaker), recent activity list

---

## Device Organization (Frame: `6VmxV`)

### All Devices — By Room
- **Pencil ID:** `rv14r`
- **iOS View:** `AllDevicesView` (Rooms mode)
- **Content:** Search, view mode picker (Devices/Rooms/Networks), grouped device tiles by room, provider badge chips on tiles

### All Devices — By Device
- **Pencil ID:** `j8hFZ`
- **iOS View:** `AllDevicesView` (Devices mode)
- **Content:** Same layout, flat merged device list sorted alphabetically

### Device Group Detail
- **Pencil ID:** `BUOyt`
- **iOS View:** `DeviceGroupDetailView` / `SonosBondedGroupDetailView`
- **Content:** Group name header, member list with role labels, now-playing card, group volume, ungroup button

---

## Multi-Room Audio (Frame: `c6XXy`)

### Select Rooms
- **Pencil ID:** `g00bw`
- **iOS View:** `MultiRoomSelectRoomsSheet`
- **Content:** Room toggle rows with speaker model labels, now-playing mini bar at top, CTA button "Play on N Rooms"

### Now Playing (Expanded)
- **Pencil ID:** `v5vpc`
- **iOS View:** `MultiRoomNowPlayingView`
- **Content:** Album art, transport controls, progress bar, per-room volume cards with individual sliders, remove (xmark) per room

### Room Added Toast
- **Pencil ID:** `co524`
- **iOS View:** Built into `MultiRoomNowPlayingView`
- **Content:** Success toast overlay showing added room name

### Speaker Unavailable
- **Pencil ID:** `woiK9`
- **iOS View:** Built into `MultiRoomSelectRoomsSheet`
- **Content:** Offline speaker row with disabled toggle + "Troubleshoot" link

### Connection Lost
- **Pencil ID:** `pyUlJ`
- **iOS View:** Built into `MultiRoomNowPlayingView`
- **Content:** Disconnected room card with Retry + Remove buttons

### No Speakers
- **Pencil ID:** `375nI`
- **iOS View:** Built into `MultiRoomSelectRoomsSheet`
- **Content:** Empty state — speaker icon, "No speakers found", scan button, troubleshooting tips

---

## Unhappy Paths & States (Frame: `d0BnI`)

### Smoke Alarm Alert
- **Pencil ID:** `RAISW`
- **iOS View:** `SmokeAlarmAlertView`
- **Content:** Full-screen red danger background, warning triangle icon, "Smoke Detected" title, room name + timestamp, numbered instruction steps, Call 911 button (red), Silence button (outlined)

### Device Offline
- **Pencil ID:** `E7fJS`
- **iOS View:** `DeviceOfflineView`
- **Content:** Offline icon, "Device unreachable" message, numbered troubleshooting tips, refresh button

### No Rooms Empty State
- **Pencil ID:** `ApNW6`
- **iOS View:** `NoRoomsEmptyState` (in `EmptyStateCard.swift`)
- **Content:** House icon, "No rooms yet" message, "Add a Room" CTA button

### Device Pairing
- **Pencil ID:** `Oa5ev`
- **iOS View:** `DevicePairingScanView`
- **Content:** Animated radar scan, discovered device list, pairing progress

### Notifications
- **Pencil ID:** `mCjOM`
- **iOS View:** `NotificationsCenterView`
- **Content:** Header with "Clear All", grouped by Today/Yesterday/Older, event rows with icon + title + time + unread dot

---

## Visualizations (Frame: `p062h`)

### Audio Zones Map
- **Pencil ID:** `ixmFl`
- **iOS View:** `AudioZonesMapView`
- **Content:** Map/List mode switcher, circle visualization of speakers with group connection lines, "+" button for new zones, linked group cards, quick links to Device List + Diagnostics

### Device Network Topology
- **Pencil ID:** `eJwZy`
- **iOS View:** `DeviceNetworkTopologyView`
- **Content:** Topology/List segment control, concentric ring layout with hub at center, connection lines (accent for linked, gray for standalone), node circles with device names, status label + legend, active connections section, gear icon → Network Settings

---

## Network Topology Screens (Frame: `LtPTJ`)

### Network Settings
- **Pencil ID:** `q5dco`
- **iOS View:** `NetworkSettingsView`
- **Content:** Hub config, protocol toggles, auto-discovery toggle, network name

### Network List
- **Pencil ID:** `Z4SXt`
- **iOS View:** `NetworkListView`
- **Content:** Search bar, device rows grouped by Connected/Offline, protocol badges (Wi-Fi, Zigbee, Z-Wave, Thread)

### Device Node Detail
- **Pencil ID:** `I2kbG`
- **iOS View:** `TopologyNodeDetailSheet`
- **Content:** Bottom sheet with device info (IP, signal, protocol), connected devices list, Ping/Restart/Remove buttons

### Connection Detail
- **Pencil ID:** `rcXFH`
- **iOS View:** `TopologyConnectionDetailView`
- **Content:** Connection metrics grid (bandwidth, latency, packet loss), shared content, connection history

### Network Diagnostics
- **Pencil ID:** `zo6mD`
- **iOS View:** `NetworkDiagnosticsView`
- **Content:** Overall health status card, 2x2 metrics grid (latency, devices, uptime, errors), health checks list with colored dots, "Run Full Scan" button

### Topology Status Screens (5)

| Screen | Pencil ID | iOS View | Content |
|--------|-----------|----------|---------|
| Device Added | `WMPrn` | `TopologyDeviceAddedView` | Success banner, device details card, action buttons |
| Network Optimized | `nSgaN` | `TopologyNetworkOptimizedView` | Success icon, improvements table, changes card, done button |
| All Devices Online | `jMwkI` | `TopologyAllOnlineView` | Status pill, network health card, connected devices card |
| Device Lost | `w37nK` | `TopologyDeviceLostView` | Warning banner, device info, troubleshooting card, reconnect button |
| Hub Unreachable | `oKWze` | `TopologyHubUnreachableView` | Error icon, troubleshooting steps, action buttons |

---

## Widgets & Watch (Frame: `RcZlG`)

### iOS Widget — Camera
- **Pencil ID:** `5lYmg`
- **iOS View:** `CameraWidget` (WidgetKit)
- **Size:** systemMedium (360x376)
- **Content:** Header (camera name + LIVE badge), dark feed preview area, bottom row (motion event + armed status)

### iOS Widget — Thermostat
- **Pencil ID:** `45PoD`
- **iOS View:** `ThermostatWidget` (WidgetKit)
- **Size:** systemMedium (360x376)
- **Content:** Header (thermostat name + mode), large target temp with +/- buttons, segmented color bar, current temp + humidity

### Apple Watch — Home
- **Pencil ID:** `ZNJj1`
- **iOS View:** `WatchHomeView`
- **Content:** 2x2 category grid (Lights, Climate, Locks, Media) on dark background

### Apple Watch — Device
- **Pencil ID:** `9e4YX`
- **iOS View:** `WatchDeviceDetailView`
- **Content:** Light name, on/off toggle, brightness bar visualization

---

## Live Activities (Frame: `HXNGX`)

### Dynamic Island — Compact
- **Pencil ID:** `hYUFC`
- **iOS View:** `SmokeAlertLiveActivity` (compact)
- **Content:** Warning triangle icon + "Smoke Detected" text + room name + pulsing ring

### Dynamic Island — Expanded
- **Pencil ID:** `EY8wa`
- **iOS View:** `SmokeAlertLiveActivity` (expanded)
- **Content:** Alert icon + timestamp, room + device info, guidance text, Call 911 + Silence buttons

### Lock Screen
- **Pencil ID:** `3eyUA`
- **iOS View:** `SmokeAlertLiveActivity` (lock screen)
- **Content:** Warning icon + title + timestamp, guidance row, Call 911 + Silence buttons

---

## Branding (Frame: `kmKNU`)

### App Icon
- **Pencil ID:** `LXwhQ`
- **Size:** 256x256 (design), needs 1024x1024 export
- **Content:** Generated image fill with rounded corners

### Apple Watch Icon
- **Pencil ID:** `7Mhv9`
- **Size:** 196x196 circular
- **Content:** Generated image fill

### Splash Screen
- **Pencil ID:** `QXNHS`
- **Size:** 393x852 (iPhone)
- **Content:** Generated background image, centered "House Connect" wordmark (30pt bold white), "Your smart home, simplified" tagline (14pt white 60%), loading progress bar at bottom

---

## Weather Tiles (Frame: `xHl4s`)

12 weather state variants for the dashboard weather card:

| State | Pencil ID | Icon | Color | Detail |
|-------|-----------|------|-------|--------|
| Sunny | `pAqqm` | sun (lucide) | `#F59E0B` on `#FEF3C7` | 45% humidity |
| Partly Cloudy | `0JBef` | cloud-sun | `#6B7280` on `#F3F4F6` | 55% humidity |
| Cloudy | `iDzlP` | cloud | `#9CA3AF` on `#F3F4F6` | 62% humidity |
| Rainy | `WEZYO` | cloud-rain | `#3B82F6` on `#DBEAFE` | 85% humidity |
| Thunderstorm | `WKDQr` | cloud-lightning | `#7C3AED` on `#EDE9FE` | 92% humidity |
| Snow | `JR8ER` | snowflake | `#06B6D4` on `#CFFAFE` | 70% humidity |
| Wind | `XJOxF` | wind | `#0EA5E9` on `#E0F2FE` | 25 mph |
| Fog | `uoVGJ` | cloud-fog | `#9CA3AF` on `#F3F4F6` | Low vis |
| Night Clear | `Y4mEq` | moon | `#4F46E5` on `#E0E7FF` | 50% |
| Night Cloudy | `rsVKu` | cloud-moon | `#6B7280` on `#E5E7EB` | 65% |
| Loading | `V46Ug` | — | shimmer bars | — |
| Heatwave | `31Nya` | thermometer | `$danger` on `#FEE2E2` | 22% |

---

## Home Assistant Screens (Frame: `ZlK3s`)

### Automations List
- **Pencil ID:** `aWYRK`
- **iOS View:** `AutomationsListView`
- **Content:** Header with back button + "Automations" title + count badge, automation rows with zap icon chip, name, last-triggered timestamp, play trigger button, enable/disable toggle

### Home Assistant Setup
- **Pencil ID:** `dt7eg`
- **iOS View:** `HomeAssistantSetupView`
- **Content:** Centered layout — house icon in accent circle, "Connect to Home Assistant" title, description text, URL text field (globe icon), token secure field (key icon), "Connect" CTA button, help text footer
