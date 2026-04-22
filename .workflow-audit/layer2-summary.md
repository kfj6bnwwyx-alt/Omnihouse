# Layer 2: Flow Traces

## Flow 001 — Track a smoke-alarm history event
- Entry: Devices tab → tap a smoke alarm row (e.g. Nest Protect)
- `T3DeviceDetailView.routedView(for:)` → `case .smokeAlarm:` → `T3AccessoryDetailView`
- Expected: smoke-specific detail with alert history + simulate button
- Actual: generic capabilities table. No alert history card, no Simulate Alert entry point even though `SmokeAlertController` is wired to drive one.
- Severity: critical

## Flow 002 — Energy from Home
- Entry: Home → weather strip Energy cell OR Explore → Energy
- Both paths push `T3EnergyView` via `HomeDestination.energy` nav value
- Works when HA connected; falls back to fake hourly curve on failure (Layer 5 flag)

## Flow 003 — Trigger an HA automation
- Entry: Settings → Automations → play button on row
- `try? await haProvider?.triggerAutomation(...)` then unconditional success toast
- Failure path is invisible to the user

## Flow 004 — Add a device
- Entry: Devices tab → "Add device" dashed button → `T3AddDeviceSheet` (honest intermediate explaining the model) → OPEN CONNECTIONS → `navigator.goToSettings(.providers)`
- This is a two-step flow but it's the correct pattern — each provider owns its own pairing.
- No issue. (Skill's "two_step" flag would trip here; context-aware: acceptable.)

## Flow 005 — Rooms from Settings vs Rooms tab
- Entry A: Rooms tab → T3RoomsTabView (root)
- Entry B: Settings → Rooms → same `T3RoomsTabView` pushed onto stack
- Same screen reached two ways; pushed copy has no back header; minor inconsistency.

## Flow 006 — Notifications bell
- Entry: Home masthead bell (unread count dot)
- → `HomeDestination.notifications` → T3NotificationsView
- Clean. Mark read + clear work against real `AppEventStore`.
