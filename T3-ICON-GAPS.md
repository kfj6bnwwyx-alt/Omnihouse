# T3 Icon Set — Gap Analysis

Status of the T3/Swiss icon coverage in the iOS build. The T3 design
handoff calls for ~40+ hand-built glyphs with 1.4px stroke,
`stroke-linecap="square"`, and `stroke-linejoin="miter"` — Braun/Dieter
Rams angular/mechanical aesthetic, not SF Symbol humanist geometry.

## Source of Truth

**Canonical T3 icon reference (Claude Design share URL, Brent-approved
2026-04-18):**

https://claude.ai/design/p/b3aa1e0c-9e12-40df-b5ce-a3f814d989a7?file=House+Connect+-+Swiss.html&via=share

All missing glyphs below should be exported from this design instance.
See `/Users/brentbrooks/.claude/projects/-Users-brentbrooks-Documents-Omni-house/memory/reference_claude_design.md`
for access notes.

## Coverage Summary

- `Core/UI/T3Icon.swift` — **129** SF-Symbol → Lucide mappings
- Bundled Lucide imagesets in `Assets.xcassets/T3Icons/` — **86** unique
- All T3-prefixed views and `Core/UI/T*.swift` primitives render via
  `T3IconImage(systemName:)`; unmapped symbols fall back to SF Symbols.

## Unmapped SF Symbols Still in Use

Grouped by category. Each entry: `sf.name` → suggested Lucide glyph →
status. "Needs SVG" means the Lucide SVG isn't bundled yet and must be
exported from the Claude Design share URL above (or Lucide upstream
with the rounded→square/miter transform applied).

### Device (category chips, Diagnostics list, dashboard cards)
- `desktopcomputer` → Lucide `monitor` → needs SVG export
- `smoke.fill` → Lucide `alert-octagon` / custom smoke glyph → needs SVG
- `sensor.fill` → Lucide `radar` or custom sensor glyph → needs SVG
- `switch.2` → Lucide `toggle-right` → needs SVG
- `poweroutlet.type.b.fill` → Lucide `plug` → needs SVG
- `blinds.horizontal.closed` → Lucide `blinds` (custom, not in Lucide core) → needs SVG
- `washer.fill` → Lucide `washing-machine` → needs SVG
- `cable.connector` → Lucide `cable` → needs SVG
- `antenna.radiowaves.left.and.right` → Lucide `radio-tower` → needs SVG
- `externaldrive.fill` → Lucide `hard-drive` → needs SVG
- `car.fill` → Lucide `car` → needs SVG
- `shower.fill` → Lucide `shower-head` → needs SVG
- `bath` → Lucide `bath` → needs SVG
- `soundbar` → Lucide `speaker` (reuse) or custom → needs SVG
- `video.fill` → Lucide `video` (already bundled) → **add mapping** (no new SVG needed)

### Action (controls, buttons)
- `trash` → Lucide `trash-2` (already bundled) → **add mapping** (no new SVG needed)
- `arrow.right` → Lucide `arrow-right` → needs SVG
- `arrow.2.squarepath` → Lucide `repeat` / `refresh-cw` → needs SVG
- `clock.arrow.circlepath` → Lucide `history` → needs SVG
- `paintbrush` → Lucide `paintbrush` → needs SVG
- `link.badge.plus` → already partly mapped to `link-2`; review visual
- `point.3.connected.trianglepath.dotted` → Lucide `network` or `share-2` → needs SVG

### Status (alerts, indicators)
- `questionmark.circle` → Lucide `help-circle` → needs SVG
- `questionmark.app.fill` / `questionmark.app` → Lucide `help-circle` → needs SVG
- `info.circle` → Lucide `info` → needs SVG (currently falls back to `triangle-alert`, wrong affordance)
- `book.fill` → Lucide `book-open` → needs SVG (currently uses `sparkles` placeholder)
- `party.popper.fill` → no close Lucide equivalent → needs custom SVG (currently uses `sparkles` placeholder)

### Decorative / kept as SF Symbol on purpose
These are intentionally left on Image(systemName:) or rendered inside
non-T3 views that aren't part of this sweep:
- `chevron.*` — already bundled; all T3 views use the Lucide variant
- `sparkle` / `sparkles` — bundled; used for placeholder affordance
- All tab-bar glyphs — routed through T3IconImage via tab.icon

## Immediate Next Steps

1. Add mappings for `trash` → `trash-2` and `video.fill` → `video` in
   `Core/UI/T3Icon.swift` (assets already bundled, just missing map keys).
2. Export the ~14 "needs SVG" glyphs above from the Claude Design share
   URL as 24×24 viewBox SVGs with `stroke-linecap="square"` +
   `stroke-linejoin="miter"` and drop them into
   `Assets.xcassets/T3Icons/`.
3. Add corresponding `"sf.name": "lucide-name"` entries in `T3Icon.map`.

## Historical: Original Glyph Inventory (from `glyphs.jsx`)

The original T3 handoff shipped these glyph groups; the mappings above
reflect which are now bundled and which still need export.

- **Navigation/Chrome:** back, chevR, chevD, close, check, plus, minus,
  more, search — all bundled.
- **Tabs:** home, rooms, devices, settings — all bundled.
- **Device categories:** lightbulb, thermo, lock, speaker, camera, fan,
  door — bundled; plus the additional "needs SVG" items above.
- **Room icons:** sofa, bed, kitchen — bundled; bath/shower still pending.
- **Weather & environment:** sun, cloud, moon, drop, wind — bundled.
- **HVAC modes:** heat, cool, auto, off — heat/cool/off bundled; `auto`
  (A letter) pending.
- **Media transport:** play, pause, next/back — bundled.
- **Misc:** bell, bolt, wifi, user, target, arrows — mostly bundled;
  `arrow.right` / `arrow.2.squarepath` still pending.
