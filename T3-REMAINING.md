# T3 Design — Views Needing Claude Design Input

These views need design decisions before they can be converted to T3.
Feed this to Claude Design for mockups.

## ⚠️ Needs T3 Design (Low Confidence)

### 1. AudioZonesMapView
**Current:** Circle visualization of speaker groups with connection lines
**T3 question:** Should this be a brutalist grid layout instead of organic circles? The T3 aesthetic is very grid/index-based — circles feel wrong. Options:
- A. 2-column indexed grid (like T3 Rooms tab) with group indicators
- B. Flat list with group headers and connection status rows
- C. Keep circles but strip colors — ink/rule only, square nodes
**File:** `Features/Audio/AudioZonesMapView.swift`

### 2. MultiRoomNowPlayingView
**Current:** Expanded now-playing with album art, transport, per-room volume cards
**T3 question:** T3SpeakerDetailView covers the basic speaker case. For multi-room, the design needs:
- How to show per-room volume in a grid/list (not cards)?
- Should the album art card match T3 Speaker's ink-square-with-dot?
- Remove/retry buttons for disconnected rooms — T3 button style?
**File:** `Features/Audio/MultiRoomNowPlayingView.swift`

### 3. TopologyStatusViews (5 screens)
**Current:** Device Added, Network Optimized, All Online, Device Lost, Hub Unreachable
**T3 question:** These are heavy visual feedback screens. Need T3 treatment for:
- Success/warning/error states using only cream/ink/orange (no green/red fills)
- How to express "success" without green? Orange dot? Ink check?
- How to express "error" without red background? Dashed border? Ink exclamation?
**File:** `Features/Diagnostics/TopologyStatusViews.swift`

### 4. SceneEditorView
**Current:** Form with name field, icon picker, action list, triggers
**T3 question:** Complex form needing:
- T3 text field style (hairline border? Rule-only bottom border?)
- Icon picker — how to select icons in T3 (grid? horizontal scroll?)
- "When to run" segmented control matches T3 pattern ✓
- Action list rows — use indexed grid pattern ✓
**File:** `Features/Scenes/SceneEditorView.swift`

### 5. Camera Detail (CameraDetailView)
**Current:** Live feed preview, action tiles (Snapshot/Talk/Record/Siren), settings toggles
**T3 question:** The dark 16:9 feed preview clashes with cream background. Options:
- A. Full-bleed dark feed with thin ink border
- B. Inset feed with cream padding and rule border
- C. Split: dark feed at top, cream controls below (like FrameTVDetailView hero)
**File:** `Features/Accessory/Detail/CameraDetailView.swift`

### 6. Smoke Alarm Detail (SmokeAlarmDetailView)
**Current:** Green "All Clear" shield, colored status badges (Normal/Detected), event history
**T3 question:** T3 only uses ONE color for accent. Options:
- A. Status = ink text "OK" / orange text "DETECTED" (no colored badges)
- B. Status rows with TDot (orange=active/detected, none=normal)
- C. Full-screen orange alert state instead of green→red transition
**File:** `Features/Accessory/Detail/SmokeAlarmDetailView.swift`

### 7. SmokeAlarmAlertView (Emergency Full-Screen)
**Current:** Full red background, white text, Call 911 / Silence buttons
**T3 question:** The red emergency screen breaks the T3 palette. Options:
- A. Keep red for safety (life-safety exception to design system)
- B. Black (ink) background with orange dot pulsing, white text
- C. Cream background with ink text, orange 911 button, ink border silence
**File:** `Features/Accessory/Detail/SmokeAlarmAlertView.swift`
**Recommendation:** Keep red. Life safety > design system.

### 8. Device Offline View
**Current:** Offline icon, troubleshooting tips, refresh button
**T3 question:** Simple conversion, but:
- Should the "try these steps" be numbered with T3 mono labels?
- Refresh button style — dashed border like "Add device"? Or outlined circle?
**File:** `Features/Accessory/Detail/DeviceOfflineView.swift`

## ✅ Already Converted to T3

| View | T3 File |
|------|---------|
| Splash | T3SplashView |
| Home Dashboard | T3HomeDashboardView |
| Rooms tab | T3RoomsTabView |
| Devices tab | T3DevicesTabView |
| Settings tab | T3SettingsTabView |
| Room Detail | T3RoomDetailView |
| Thermostat | T3ThermostatView |
| Light | T3LightDetailView |
| Lock | T3LockDetailView |
| Speaker | T3SpeakerDetailView |
| Activity | T3ActivityView |
| Energy | T3EnergyView |
| Scenes List | T3ScenesListView |
| Automations | T3AutomationsView |
| Providers | T3ProvidersView |
| Notifications | T3NotificationsView |
| Device Router | T3DeviceDetailView |
| Tab Bar | T3TabBar |
| Theme | T3Theme |

## Screens Using Old Design (Acceptable Fallback)

These use the old views via T3DeviceDetailView fallback:
- Generic AccessoryDetailView (sensors, switches, outlets, fans, blinds)
- SonosBondedGroupDetailView (home theater bonded sets)
- AboutView, HelpFAQView, AppearanceView, NotificationPreferencesView
- AddDeviceView, DevicePairingScanView
- HomeAssistantSetupView, NestOAuthView, SmartThingsTokenEntryView
