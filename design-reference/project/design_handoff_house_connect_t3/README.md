# Handoff: House Connect — T3 (Braun / Dieter Rams) direction

## Overview
House Connect is an iOS app that consolidates smart-home devices from multiple
providers (HomeKit, SmartThings, Sonos, Nest) into a single quiet controller.
This handoff covers the **T3 direction** — a Braun T3 radio / Dieter Rams-inspired
modernist aesthetic. Off-white cream, jet-black text, a single disciplined
Braun-orange accent, precise hairlines, and oversized tabular numerals.

## Screens covered (14)
**Core flow**
1. **Splash** — first-launch loading
2. **Home** — greeting, weather/inside/energy, scene chips, room list
3. **Rooms** (tab) — 2-col index of all rooms
4. **Room** — single-room device list with toggles

**Device detail**
5. **Thermostat** — 168px number, tick scale, mode, schedule
6. **Light** — brightness scale, color-temp segmented
7. **Lock** — tap-to-toggle circle, battery, recent access
8. **Speaker** — now-playing, volume, group-with

**Everything else**
9. **Devices** (tab) — flat filterable list
10. **Settings** (tab) — grouped account / connections / preferences / automation / system
11. **Scene editor** — trigger + time + actions
12. **Activity** — today's event log
13. **Energy** — daily kWh, hourly bars, by-category
14. **Add device** — providers + discovered-nearby

## About the Design Files
The files in this bundle are **design references created in HTML/React-in-browser** —
a prototype showing intended look and behavior, **not production code to copy directly**.
The task is to **recreate these HTML designs in the target codebase's existing environment**
(SwiftUI / React Native / React web / etc.) using its established patterns, theming, and
component library. If no codebase exists yet, SwiftUI is a natural fit for iOS.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, and interactions are specified below.
Recreate pixel-perfectly using the codebase's existing libraries and patterns.

---

## Design Tokens

### Color
| Token    | Hex       | Usage                                              |
| -------- | --------- | -------------------------------------------------- |
| `page`   | `#f2f1ed` | Warm cream — primary background                    |
| `panel`  | `#ffffff` | Cards, tab bar, segmented control background       |
| `ink`    | `#0e0e0d` | Primary text, primary buttons, on-state track      |
| `sub`    | `#86847e` | Secondary/tertiary text, inactive tab icons/labels |
| `rule`   | `#d9d7d0` | Hairline dividers and borders                      |
| `accent` | `#e7591a` | Braun orange — single restrained accent            |
| `frame`  | `#1a1a1a` | Device frame (only in the prototype canvas)        |

**Accent discipline**: the orange is used ONLY for:
- the single dot on splash / headers / status indicators
- the `+` primary button circle on thermostat and speaker transport
- the `°` glyph on the giant temperature readout; `kWh` unit on Energy
- the knob of an ON pill toggle
- the tiny "active" indicator dot on the selected tab
- one highlighted bar in the hourly energy chart (current hour)
- one highlighted category bar on Energy (top category)

Never use it for general borders, fills, backgrounds, or decoration.

### Typography
- **Display / UI**: `Inter Tight` (fallback: `-apple-system, system-ui, sans-serif`)
  - Splash logotype: 44 / 500 / -1.4 / 1.0 lh
  - Home greeting: 36 / 500 / -1.0
  - Screen title (Room/Rooms/Devices/Settings/etc.): 42 / 500 / -1.4
  - Thermo big number: **168 / 300 / -8 / 0.85 lh**
  - Energy big number: 120 / 300 / -5 / 0.85 lh
  - Light big number: 96 / 300 / -4 / 0.85 lh
  - Stat values: 22–38 / 400 / -0.6 to -1.4
  - Section titles: 15–17 / 500
- **Mono caption**: `IBM Plex Mono`, 10–11px / 400 / 1.6 letter-spacing / uppercase —
  all micro-labels, time stamps, provider names, numeric indices, state strings.
- All numerics: `font-variant-numeric: tabular-nums`.

### Spacing
- Screen horizontal padding: **24px**
- Tab bar: 22px bottom inset, 20px horizontal inset, 14px border radius
- Section header: 18px top / 8px bottom; rows use 14–16px vertical padding
- Icon sizes: 12 (chevrons), 14 (mode glyphs, back), 18 (row icons), 20 (tab icons), 22 (rooms-grid)

### Radii
- Scene chips, filter chips, pill toggle track: `999px`
- Tab bar container, segmented-control outer: `14px` / `8px`
- Segmented-control inner cell: `6px`
- Circular buttons: `50%` (52×52 secondary, 72×72 primary on Speaker)
- All **cards/rows: no rounding** — rely on hairlines.

### Shadows
- Tab bar: `0 1px 2px rgba(0,0,0,0.03)` only.
- No other shadows.

### Stroke weight
- All icons: **1.4px** base stroke, `strokeLinecap="square"`, `strokeLinejoin="miter"`.
- Active tab icon: 1.7px.

---

## Navigation Model

Four tabs in the persistent bar: **Home / Rooms / Devices / Settings**.

Tab routing rules (the tab highlight is derived from the active screen):
- `home` → Home tab
- `rooms`, `room`, `thermo`, `device` → Rooms tab
- `devices` → Devices tab
- `settings`, `account`, `integrations` → Settings tab
- `activity`, `energy`, `addDevice`, `scene` → Home tab (opened from Home/Settings; back returns there)

### Screen graph

```
Splash → Home
Home  ─┬→ Room(id)      (via Rooms list)
       ├→ Scene edit     (via scene chip, long-press or edit)
       ├→ Activity       (future: via greeting-area action)
       └→ Energy         (via weather-strip Energy cell, future)
Rooms → Room(id)
Room  ─┬→ Thermo         (thermostat row)
       ├→ Device(id)     (light / lock / speaker rows)
       └→ back → Rooms
Devices ─┬→ Thermo
         ├→ Device(id)
         └→ Add device
Settings ─┬→ Integrations (placeholder)
          ├→ Account      (placeholder)
          ├→ Scene edit
          └→ Energy
```

Back chevron on detail screens mirrors this graph.

---

## Iconography
Hand-built outlined glyphs, not SF Symbols — see `lib/glyphs.jsx` for the full set.
Every glyph is a component accepting `{ size, stroke, sw, fill }`. Port the set 1:1.

Glyphs used by T3:
`sun cloud moon bell plus minus back chevR home rooms devices settings scenes
lightbulb thermo lock speaker camera fan door sofa bed kitchen
play pause next heat cool auto off drop wind wifi bolt dot arrowUp arrowDn
arrowR target search user grid check close more`.

---

## Shared primitives

From `lib/t3-theme.jsx`, exposed via `window.T3Primitives`:

- **`TLabel`** — mono uppercase caption, 10px / 1.6 letter-spacing, default `sub` color.
- **`TRule`** — 1px `rule` hairline, full-bleed.
- **`TDot`** — inline orange dot (defaults 8px, `accent`).

Additional primitives used in extra screens (defined in `lib/t3-screens-extra.jsx`,
but you should lift them into your design system):

- **`XHeader`** — screen header: back-chevron + left label / right label.
- **`XTitle`** — eyebrow-dot + big title + sub (for screen intros).
- **`XSectionHead`** — section title (15/500) + trailing mono count.
- **`XPill`** — animated 40×22 or 48×26 pill toggle; ON = ink track + orange knob.

---

## Screen specs (delta from the 4 in v0)

### Rooms (tab)
- Header "Your Home" / "06 rooms"
- `XTitle` "Rooms." with sub "N devices active across the house"
- Full-bleed 2-column grid of room cards (no rounding):
  - Each cell 150px min-height, 22×20 padding
  - Top row: glyph (22px, `ink`) / index TLabel ("01"…)
  - Bottom: 18/500 name, 6px dot + `"N/M on"` in mono `sub`
  - Cell borders: bottom `rule`, right `rule` only on left column
- Dashed "New room" button at the foot.

### Devices (tab)
- `XTitle` "Devices." with sub "N on now · across 6 rooms"
- Horizontal filter chip row: `All / On / Lights / Climate / Media` (selected = ink pill)
- Rows grid: `28 1fr auto auto` — glyph / title + `ROOM · state` / provider / pill
- Dashed "Add device" at foot → navigates to Add.

### Settings (tab)
- `XTitle` "Settings."
- Groups (XSectionHead + list), in order: Account / Connections / Preferences / Automation / System.
- Each row: `grid 28 1fr 14` — glyph, title + sub, chevR (chevron omitted on non-navigating rows).
- Version line at foot: `House Connect · 1.0.0 · Build 214`.

### Light detail
- Standard header (back → room)
- Eyebrow dot (when on) + `On` / `Off`
- 96/300 percentage number (orange `%` when on, otherwise `0` with `sub`), pill toggle to the right
- **Brightness** labeled tick scale (41 ticks, majors every 5), 10px dot at current; quick-pick row: 25 / 50 / 75 / 100.
- **Temperature** segmented: Warm 2700K / Neutral 3500K / Cool 5000K / Day 6500K.
- Stats strip: Power 9W / Uptime 4h 12m / Since Morning.

### Lock detail
- Header (back → room) / provider right
- Eyebrow dot + `Secured` / `Unlocked`
- 42/500 name
- **Centered 220px circular button**: locked → panel fill, ink border, ink glyph; unlocked → ink fill, orange glyph, "Tap to lock" in page color. 54px lock glyph with 1.2 stroke.
- Stats strip: Battery / Signal / Firmware.
- Section "Recent access": rows `grid 60 1fr 14` — mono time / action + who / method caption / trailing lock-or-check icon.

### Speaker detail
- Header / provider right
- Eyebrow dot (when playing) + state
- **Now-playing card** — full-width, 1px `rule`, `panel` bg, 18px pad, grid `64 1fr`: 64×64 ink tile with orange 10px dot, then TLabel + 16/500 title + 12 `sub` artist.
- **Transport row**: 52px prev circle / **72px orange play-pause** / 52px next circle. Play-pause flips between `play` and `pause` glyphs, white fill+stroke.
- **Volume** scale (41 ticks) with 22/500 numeric on the right of its label.
- **Group with**: 4 rooms, each with `XPill` — first one on.

### Activity
- Header back → Home
- `XTitle` "Activity."
- Rows `grid 56 28 1fr` — mono time / 18px glyph / label + `sub` caption.

### Energy
- Header back → Home
- `TLabel` "Total today", then 120/300 number with orange ` kWh` suffix (36/300).
- 13 `sub` trend line: `↓ 15%` (in ink) `vs. yesterday (16.8 kWh)`.
- **Hourly bars**: 24 bars, 2px gap, height = `v / max * 100%` in 120px row. Current hour (index 18 in the mock) painted `accent`; all others `ink`. Bottom axis labels 00 / 06 / 12 / 18 / 24 in mono.
- **By category** list: each row is title / right = `pct%` mono sub + `kwh` 16/500, with a 3px progress bar under (accent on the first/top category, ink on the rest).
- Stats strip bottom: This month, Est. cost.

### Add device
- Header "Cancel" / "Add"
- `XTitle` "Add a device." with sub "Pick a provider, or pair something new over Matter."
- Section **Providers** (5 rows): wifi glyph, name, sub caption, chevR.
- Section **Discovered nearby** (3 rows): 8px dot, name, mono uppercase location caption, and a right-side **Pair** button — 1px ink border, 11/600 mono uppercase, 8/14 padding.

### Scene editor
- Header "Scenes" / "Save"
- `XTitle`: scene glyph + `XTLabel` "Scene · N actions", 42/500 scene name + ".", sub describing trigger.
- **When to run** segmented: Schedule / Arrive / Manual. Below it, a bordered "Weekdays at / 07:00" row.
- **Actions** list: 28px glyph / device name + `ROOM` mono sub / mono action string ("ON · 80%") / chevR.
- Dashed "Add action" at foot.

---

## Interactions & Behavior

- **Scene chips** (Home): single-select; selected = ink pill with cream text.
- **Filter chips** (Devices): single-select.
- **Pill toggle**: 150ms transition on track color AND knob x-position.
- **Thermostat ± buttons**: increment/decrement target by 1°F; scale+dot update live.
- **Light brightness scale**: dragging or tapping updates brightness; quick-pick buttons set exact values and force `on=true`.
- **Lock circle**: single tap toggles; 220px hit area.
- **Speaker play-pause**: toggles; 72px orange primary button.
- **Volume scale**: drag/tap.
- Back chevron follows the screen graph above.
- No haptic specs authored; default iOS light impact on taps is appropriate.

## State Management

Per session / persistent:
- `currentScreen`, `currentParams` — route (persisted to localStorage / UserDefaults)
- `targetTemp`, `mode` — per-thermostat
- `deviceOn`, `brightness`, `colorTemp` — per light
- `locked` — per lock
- `playing`, `volume` — per speaker
- `sceneSelected` — id
- `deviceFilter` — enum

## Assets
- Fonts: **Inter Tight** and **IBM Plex Mono** (both Google Fonts / open source, bundle in-app).
- No raster assets — all visuals are typography, hairlines, and inline SVG glyphs.

## Files in this bundle
| File | What it is |
| ---- | ---------- |
| `House Connect - Swiss.html`     | Root document — loads the React-in-browser prototype showing all 14 screens in 3 rows. |
| `lib/t3-theme.jsx`               | **Core T3 theme**: Splash, Home, Room, Thermo, Tabs + shared primitives (`TLabel`, `TRule`, `TDot`, tokens). |
| `lib/t3-screens-extra.jsx`       | **Additional screens**: Rooms, Devices, Settings, Device (light/lock/speaker routing), Activity, Energy, AddDevice, SceneEdit, plus `XHeader/XTitle/XSectionHead/XPill` primitives. |
| `lib/glyphs.jsx`                 | Hand-built icon set. Port every glyph verbatim. |
| `lib/data.jsx`                   | Mock data for rooms, devices (all 6 rooms), activity log, energy, thermostat. Reflects the registry model the real app should use. |
| `lib/shell.jsx`                  | Device-frame wrapper used by the prototype; not needed in the real app. |
| `lib/app-swiss.jsx`              | Review canvas that places every screen side-by-side; **ignore for implementation** — it's for review only. |

Open `House Connect - Swiss.html` in a browser to see every screen live and interactive.
