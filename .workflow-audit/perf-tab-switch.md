# Perf audit — tab-switch slowdown / freeze after 4–5 screens

Read-only audit run 2026-04-22 against the state captured on commit `20b2efa`.
Scope: the user reports that switching tabs or navigating between 4–5 detail
screens gradually degrades the UI and eventually freezes. Earlier logs also
showed Sonos SSDP churn and HA WebSocket TCP resets.

## Smoking guns

### 1. HA WebSocket state-change churn → full-array observation on every event
`Core/Providers/HomeAssistant/HomeAssistantProvider.swift:416–421`

```swift
nonisolated func didReceiveStateChange(entityID: String, newState: HAEntityState) {
    Task { @MainActor in
        self.entityStates[entityID] = newState
        self.lastStateUpdateAt = Date()
        self.rebuildAccessory(for: entityID)   // per event
    }
}
```

`rebuildAccessory` writes into `accessories[idx] = updated` — the array is
@Observable, so every write triggers the whole observation graph downstream
(detail views, Home dashboard, Rooms tab). A busy HA install can emit dozens
of state-change events per second. `didReceiveAllStates` (line 424) *does*
debounce with a 500ms sleep before calling `rebuildAll`; single-entity changes
bypassed that entirely.

### 2. NavigationStack retention across tab switches
`Features/Root/T3RootView.swift:18` + `Features/Root/T3TabNavigator.swift:27`

Only one `NavigationStack(path: $navigator.path)` in the whole app, shared
across all tabs. When the user pushes a detail view on Home then taps the
Settings tab, the Home detail view stays retained — its `@State`, observers,
`.task`, and any timers keep running. Switching back doesn't pop; it resumes
the stale stack. Across 4–5 navigations this accumulates live tasks.

Representative examples of views with live work:
- `T3LockDetailView.swift:174` — `.task { await loadLockHistory() }`
- `T3CameraDetailView.swift:48` — `clockTimer` state

Only `goToSettings(_:)` reset the path; regular tab-bar taps did not.

### 3. Observation cascade through existentials
`Core/Providers/ProviderRegistry.swift:22–24`

```swift
var allAccessories: [Accessory] {
    providers.flatMap(\.accessories)
}
```

Every detail view reads `registry.allAccessories.first { $0.id == accessoryID }`
inside a computed property. When ANY provider's `accessories` changes, every
detail view's observation fires, each one re-running a full flatMap over every
provider. With 4–5 detail views in the stack (see #2) that's 4–5× nested-read
cost on every state mutation. Compounds with #1.

## Landed fixes

### Fix A — Debounce single-entity rebuilds (#1)
Replaced the per-event `rebuildAccessory` call with a queued-and-flushed
pattern:

```swift
private func enqueueEntityRebuild(_ entityID: String) {
    pendingEntityUpdates.insert(entityID)
    pendingEntityFlushTask?.cancel()
    pendingEntityFlushTask = Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(50))
        guard !Task.isCancelled, let self else { return }
        await self.flushPendingEntityRebuilds()
    }
}
```

50ms window coalesces rapid updates into one observation cycle. Under normal
load (a few events/sec) latency is unchanged; under burst load (dozens/sec)
observation work drops to ~20 Hz.

### Fix B — Clear NavigationStack on tab switch (#2)
`T3TabNavigator.selection.didSet` now resets `path = NavigationPath()` when
the selection changes. Pushed detail views dismiss, their `.task`/`Timer`
lifecycles end, and returning to a tab lands on its root instead of a stale
deep screen. `goToSettings(_:)` still works because `selection = .settings`
fires didSet first, then the explicit `path.append(dest)` runs.

### Deferred — Cache layer for `allAccessories` (#3)
Not landed in this pass. A shim class like:

```swift
@MainActor @Observable
final class AccessoryCacheView {
    private(set) var cachedAccessories: [Accessory] = []
    func update(from providers: [any AccessoryProvider]) { … }
    func accessory(by id: AccessoryID) -> Accessory? { … }
}
```

would decouple detail-view reads from the underlying provider observations.
Bigger surface — every detail view's `accessory` computed property would
need to route through the cache. Worth doing if the user still sees
degradation after A + B.

## Needs Instruments

These can't be diagnosed from code reading alone:

1. **Actual frame-rate under load** — whether the 50ms debounce is enough
   or needs to move to 100ms. Use Core Animation instrument.
2. **Memory growth** — confirm detail views are actually deallocating after
   Fix B. Allocations / Heapshots in Xcode. If residual retention exists,
   look for unpaired `.onAppear` / `.onDisappear` or retained closures.
3. **Sonos SSDP churn** — the "already cancelled, ignoring cancel" + TCP
   reset logs. Network instrument with BrowseMulticast filter. Likely a
   rediscovery loop that should reuse connections instead of tearing down.
4. **Time spent in `flatMap(\.accessories)`** — System Trace > Swift
   allocations, or Time Profiler. If Fix #3 (cache) materially helps,
   it will show up here first.
