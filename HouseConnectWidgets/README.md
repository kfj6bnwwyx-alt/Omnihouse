# HouseConnectWidgets — Widget Extension Setup

This folder contains the source files for the `HouseConnectWidgets` widget
extension that renders the smoke-alarm Live Activity (Pencil nodes
`hYUFC`, `EY8wa`, `3eyUA`). It is **not yet a target** in the Xcode
project — adding a widget extension target requires the Xcode GUI.

Do this once, on your machine, when you're back at the project:

## 1. Add the widget extension target

1. Open `house connect.xcodeproj` in Xcode.
2. File → New → Target… → iOS → **Widget Extension**.
3. Product Name: `HouseConnectWidgets`
4. **Uncheck** "Include Live Activity" (we already have our own).
5. **Uncheck** "Include Configuration App Intent" (not needed yet).
6. Team: same as the app target.
7. Embed in Application: `house connect`.
8. Finish. When prompted, click **Activate** to switch schemes.

## 2. Replace Xcode's generated files with ours

Xcode will create three starter files inside a new `HouseConnectWidgets/`
folder *inside the project bundle*. Delete all of them, then drag the
files from **this** folder (`/HouseConnectWidgets/` at the repo root)
into the target:

- `HouseConnectWidgetsBundle.swift`
- `SmokeAlertLiveActivity.swift`
- `Info.plist` (replace the auto-generated one)

When the "Add Files to Project" sheet appears:
- **Target Membership:** check `HouseConnectWidgets` only, NOT the main
  app.

## 3. Share `SmokeAlertAttributes.swift` with both targets

ActivityKit requires the `ActivityAttributes` type to be identical in
both the app target (which calls `Activity.request(...)`) and the
widget target (which renders it). Ours lives in the main app at:

```
house connect/Core/LiveActivities/SmokeAlertAttributes.swift
```

Select that file in Xcode → File Inspector (right sidebar) → Target
Membership → **also tick `HouseConnectWidgets`**. Now both targets
compile the same type.

## 4. Verify `NSSupportsLiveActivities`

- Main app: already set in `house-connect-Info.plist` (root of repo).
- Widget extension: already set in this folder's `Info.plist`.

## 5. Build + test

1. Build the `house connect` scheme. Both targets should compile.
2. Run the app on a device or iPhone simulator (Dynamic Island requires
   iPhone 14 Pro or later; lock-screen Live Activities work on all
   iPhones from iPhone X up).
3. Navigate to any device reported as `.sensor` category (or force the
   router via a preview) to reach `SmokeAlarmDetailView`.
4. Tap **Simulate Alert**. The controller will:
   - Request a Warning Live Activity immediately.
   - Escalate to Critical after 5 seconds.
   - Auto-end after 30 seconds if you don't acknowledge.

Both surfaces should appear: Dynamic Island when the app is in the
background, lock screen banner when the device is locked.

## 6. Light up live data for widgets (App Groups)

Several widgets in this extension (ActiveDevicesWidget, ThermostatWidget,
CameraWidget, SceneRunWidget) read from an App Group shared
UserDefaults suite. Without it they render placeholder/demo data. To
go live, **do this once** in Xcode:

1. App target (`house connect`) → Signing & Capabilities → + Capability
   → **App Groups**. Add identifier: `group.house-connect.shared`.
2. Widget extension target (`HouseConnectWidgetsExtension`) → same
   panel → + Capability → App Groups → tick the same identifier.
3. Commit the regenerated `.entitlements` files.

After the entitlement is live:

- `house connect/Features/Dashboard/ActiveDevicesSnapshotWriter.swift`
  automatically starts writing the active-devices snapshot on every
  Home dashboard appearance + accessory-count change. The widget's
  `SharedActiveDevicesSnapshot.read()` picks it up. No code changes
  required; the UserDefaults suite just becomes writable.

## What's still deferred

See the "Wanted — not yet buildable" block in `Documents/Omni-house/PHASES.md`
Phase 6 / Phase UI-R sections.
