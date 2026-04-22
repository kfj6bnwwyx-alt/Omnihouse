# Home dashboard — Active devices sections

**Status:** Approved (brainstorming 2026-04-22)
**Author:** collaborative design w/ Brent
**Related:** plan `the-app-still-isn-t-soft-oasis.md` #14 (new item)

## Product context

From `Omni-house/PRD.md`:

> "House Connect is a single iOS control surface for the devices that live
> across HomeKit, SmartThings, Sonos, Samsung Frame TV, and Google Nest."

The PRD's deferred-roadmap section (Phase 3 widgets) already calls out
*"room-level 'active devices' count"* as a planned widget. This spec
pulls that intent into the main Home dashboard — answering "what's on in
the house right now?" at a glance — and retires the duplicate rooms grid
that's currently there. `PHASES.md:347` establishes the vocabulary we'll
reuse: **"active = `isOn == true`"**, with sensors/cameras contributing
to denominators but not numerators.

## Problem

The Home tab and the Rooms tab both render a 2-column Rooms grid. The overlap
wastes the best real estate on Home (which users see constantly) on content
that has its own dedicated tab. Meanwhile the app has no at-a-glance view of
*what's actually running right now* — "which lights are on", "what's playing",
"is the thermostat heating". Those answers live inside individual device
detail screens today.

## Goal

Replace the Rooms grid on Home with an **"active devices" area** that
surfaces devices currently doing something — with inline quick control —
while leaving the Rooms tab untouched. Aligns with the product pitch of a
"single control surface": Home becomes the glance view, Rooms tab stays the
browse view.

## Scope

**In scope:**
- Remove the Rooms grid from `T3HomeDashboardView`
- Add three new sections to Home, grouped by category of activity:
  1. **Lights on** — lights whose `isOn == true`
  2. **Playing** — speakers / TVs / Apple TVs with media playing
  3. **Climate** — thermostats in a non-off HVAC mode
- Each section hides entirely when its list is empty
- Existing Home sections stay in exactly the current order; only the Rooms
  grid changes

**Out of scope (explicit):**
- Changes to the Rooms tab
- New "Unlocked" / "Running" / "Open" sections — can be added later if the
  three-category split proves too narrow; not part of this spec
- Home widget/WatchKit parity — the new sections are app-only in v1
- Reorder / toggle / edit of which categories show up — fixed list in v1
- A "pinned" user-curated list — different feature, different spec

## Final order on Home

```
1. Greeting + status line          (unchanged)
2. Weather strip                   (unchanged)  — Outside / Inside / Energy
3. Quick Actions                   (unchanged)
4. Scenes                          (unchanged)
5. Lights on                       NEW — list rows, shown only if non-empty
6. Playing                         NEW — list rows, shown only if non-empty
7. Climate                         NEW — list rows, shown only if non-empty
8. Explore → Activity              (unchanged)
```

## What "active" means per category

| Category | Predicate | Data source |
|---|---|---|
| Lights on | `accessory.category == .light && accessory.isOn == true` | `registry.allAccessories` |
| Playing | `accessory.category ∈ {.speaker, .television, .appleTV}` and media playing | `nowPlaying` capability present with `isPlaying == true`, or fallback to `isOn == true` for devices with no now-playing data |
| Climate | `accessory.category == .thermostat && hvacMode != .off` | `accessory.hvacMode` |

Non-reachable devices (`!isReachable`) are filtered out of all three
sections — the point is "what's on *right now*," and an unreachable device's
state is stale.

## Row behavior

Each row has:
- **Icon** — SF Symbol matching the capability (lightbulb.fill, speaker.wave.2.fill, thermometer)
- **Name** — `accessory.name`
- **Meta caption** — T3 mono caption, uppercase:
  - Lights: `"<room name> · <brightness>%"` (brightness omitted if unavailable)
  - Playing: `"<room name> · <artist or track>"` (falls back to `"<room name> · PLAYING"`)
  - Climate: `"<mode> · <current>→<target>°"`
- **Toggle pill** on the right (`TPill`), bound to the device's power state

**Tap targets:**
- Tap the row body (icon + name area) → push `T3DeviceDetailView` for that accessory
- Tap the toggle → fire on/off via `registry.execute(.setPower(...))` using the same
  `T3ActionFeedback.perform` pattern as other detail views, with rollback on error

## Empty state

When all three category lists are empty simultaneously, sections collapse and
nothing is rendered between Scenes and Explore. No placeholder copy in v1 —
the weather strip and scenes above already give the dashboard weight. Cheap
to add a "All quiet in the house." caption later if the empty Home feels
abrupt in practice.

## Architecture

### New view
`Features/Dashboard/T3HomeActiveDevicesSection.swift` — a single reusable
`View` struct that takes the `ProviderRegistry` (environment) and renders the
three sub-sections internally. Keeps `T3HomeDashboardView` flat — one call
site.

### No new models
Everything comes from existing types: `Accessory`, `Capability`, `AccessoryID`,
`registry.allAccessories`. No additional persistence. No new environment objects.

### Computed properties on the new view (not the registry)
- `lightsOn: [Accessory]` — filter by category + isOn + isReachable, sorted by name
- `nowPlaying: [Accessory]` — filter by category ∈ media + playing predicate, sorted by name
- `climateActive: [Accessory]` — filter by category + hvacMode != .off, sorted by name

These are cheap (single `filter` pass over ~30–100 accessories) and co-located
with the view that reads them so SwiftUI's observation tracks them correctly.

### Removed
`roomsList` computed property and its call site in `T3HomeDashboardView`, plus
the now-unused `roomIcon(_:)` helper and the `@Environment(RoomLinkStore.self)` /
`MergedRoom`-based filters that only existed for the Home grid. The Rooms tab
(`T3RoomsTabView`) and Rooms Settings (`T3RoomsSettingsView`) both still use
those imports, so the types themselves stay.

## Interactions

- **Toggle off-from-Home** → row disappears from Home on the next observation
  cycle, because `accessory.isOn` flipped. No special animation needed — the
  list filter does the work.
- **Scene that turns on 10 lights** → all 10 rows appear. Lights on section
  grows; no capping. If this becomes noisy in practice we can add a
  "show all" cap later.
- **Media playback stops** → row leaves Playing section; same mechanism.
- **Pull-to-refresh** → unchanged; the existing `.refreshable` on the ScrollView
  covers the new sections since they read from `registry.allAccessories`.

## Accessibility

- Each row's accessibility label: `"<name>, <meta caption>, <on|off>"` matching
  the pattern used in existing detail views.
- Toggle uses the same `TPill` component as thermostat/light detail — already
  VoiceOver-labeled.
- Section headers are `TSectionHead` (existing primitive, already semantic).

## Error handling

- Toggle tap that fails → `T3ActionFeedback.perform` catches, rolls back optimistic
  state, shows an `.error("Couldn't reach <name>")` toast. Matches existing
  detail-view behaviour.
- Device goes offline mid-session → `isReachable` flips, filter drops it from
  the list on the next observation cycle.

## Testing

Unit tests on the filter predicates are cheap and worth adding — a new
`T3HomeActiveDevicesTests` with:
- Empty registry → all three lists empty
- Mixed accessories → only the on/playing/active-climate ones land
- Unreachable devices excluded even when their logical state is "on"
- Sort order stable by name

View-layer testing (snapshot, interaction) is not in scope — T3 doesn't have
snapshot infra today and the user-visible behaviour is straightforward.

## Migration

No user-visible migration needed. Zero data-model changes. The Home tab simply
renders differently after the update.

## Verification

1. Fresh install, no accessories → Home shows greeting/weather/QA/scenes only.
   No empty sections visible.
2. Turn one light on via detail view → Home's Lights on section appears with
   one row. Toggle it off from Home → row and section disappear.
3. Start media playback on a speaker → Playing section appears with the track
   subtitle.
4. Set thermostat to heat → Climate section appears; mode changes to off →
   section disappears.
5. Rooms tab and Rooms settings unaffected.
