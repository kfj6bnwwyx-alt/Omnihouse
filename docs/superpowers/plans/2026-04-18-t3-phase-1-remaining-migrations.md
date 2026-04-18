# T3 Phase 1 — Remaining iOS Migrations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the remaining reachable-legacy SwiftUI views in the main iOS target, delete orphaned dispatchers, and grow the T3 icon bridge — bringing the app to 100% T3-native on every navigable screen.

**Architecture:** Each task produces a T3-styled replacement for a legacy view, reached via existing `T3DeviceDetailView` / `T3RootView` navigation destinations. Legacy dispatchers are deleted only after every downstream consumer is routed through the T3 router. All `@AppStorage` keys + Keychain semantics are preserved so user data survives the migration.

**Tech Stack:** SwiftUI (iOS 26), `@Observable` providers, `@AppStorage`, Asset Catalog vector assets (`T3Icons/*`), `T3Icon` bridge, `xcodebuild` via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

**Scope carve-outs** (these become their own plans):
- **Phase 2** — design-gated bespoke views: `T3FrameTVDetailView`, `T3SmokeAlarmDetailView`, `T3AudioZonesMapView`, `T3MultiRoomNowPlayingView`, `T3SonosBondedGroupDetailView`, `T3SceneEditorView`, Topology suite (5 screens). Each needs a Pencil comp first — open on the Claude Design side.
- **Phase 3** — Widgets + Watch extension Swift ports. Pencil comps are already rebuilt (frames `5lYmg`, `45PoD`, `ZNJj1`, `9e4YX`, `hYUFC`, `EY8wa`, `3eyUA`) — this is pure Swift mirror work in separate targets.

**Baseline state:** commit `cf08613`. T3 covers every primary tab, both live device details (Light/Thermostat/Lock/Speaker/Camera/Offline), all shipped settings subpages + setup forms, and Profile. 83 Lucide icons bundled and tinted correctly.

---

## File Structure

Each task produces exactly one new file or modifies exactly one existing file. Files that change together are grouped inside a single task.

**Will be created** (5 new files):
- `house connect/Features/Settings/T3NestOAuthView.swift`
- `house connect/Features/Rooms/T3CreateRoomSheet.swift`
- `house connect/Features/Accessory/Detail/T3AccessoryDetailView.swift` — generic T3 fallback for sensor / switch / outlet / fan / blinds / other
- `house connect/Features/AddDevice/T3AddDeviceView.swift`
- `house connect/Features/AddDevice/T3DevicePairingScanView.swift`

**Will be modified:**
- `house connect/Features/Settings/T3ProviderDetailView.swift` — swap `NestOAuthView` → `T3NestOAuthView` on `.nest` config row
- `house connect/Features/Accessory/Detail/T3DeviceDetailView.swift` — route `.sensor / .switch / .outlet / .fan / .blinds / .other` through `T3AccessoryDetailView`
- `house connect/Features/Settings/ProviderDevicesListView.swift` — `DeviceDetailView(accessoryID:)` → `T3DeviceDetailView(accessoryID:)`
- `house connect/Features/Rooms/T3RoomDetailView.swift` — any `CreateRoomSheet()` reference → `T3CreateRoomSheet()`
- `house connect/Core/UI/T3Icon.swift` — add ~15 newly-referenced SF Symbol mappings
- `T3-IMPLEMENTATION-PLAN.md` — flip Phase 1 checkboxes to done

**Will be deleted** (after Task 5 safety check passes):
- `house connect/Features/Accessory/Detail/DeviceDetailView.swift`
- `house connect/Features/Accessory/Detail/ThermostatDetailView.swift`
- `house connect/Features/Accessory/Detail/LightControlView.swift`
- `house connect/Features/Accessory/Detail/SonosPlayerDetailView.swift`
- `house connect/Features/Accessory/AllDevicesView.swift`
- `house connect/Features/Rooms/AllRoomsView.swift`
- `house connect/Features/Rooms/RoomDetailView.swift` (legacy, not T3RoomDetailView)
- `house connect/Features/Automations/AutomationsListView.swift`
- `house connect/Features/Scenes/ScenesListView.swift`
- `house connect/Features/Accessory/AccessoryDetailView.swift` (the legacy one — superseded by T3AccessoryDetailView)
- `house connect/Features/Settings/NestOAuthView.swift`
- `house connect/Features/Rooms/CreateRoomSheet.swift`
- `house connect/Features/AddDevice/AddDeviceView.swift`
- `house connect/Features/AddDevice/DevicePairingScanView.swift`

**Verification command** (reused in every task):

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project "house connect.xcodeproj" \
    -scheme "house connect" \
    -destination "platform=iOS Simulator,name=iPhone 17" \
    build 2>&1 | grep "BUILD \(SUCCEEDED\|FAILED\)"
```
Expected output: `** BUILD SUCCEEDED **`

---

### Task 1: T3-ify NestOAuthView

**Why:** Last remaining Form-based setup view. Reached from Settings → Connections → Nest → Reauthorize (wired in `T3ProviderDetailView:153`). Users will hit this when Google SDM OAuth token expires.

**Files:**
- Create: `house connect/Features/Settings/T3NestOAuthView.swift`
- Modify: `house connect/Features/Settings/T3ProviderDetailView.swift`
- Delete (at end): `house connect/Features/Settings/NestOAuthView.swift`

- [ ] **Step 1: Read the legacy NestOAuthView to inventory capabilities**

Run: `wc -l "/Users/brentbrooks/Desktop/house connect/house connect/Features/Settings/NestOAuthView.swift"`

Read the full file. Note: uses `ASWebAuthenticationSession` (iOS-only, wrapped in `#if os(iOS)`), the `presentationAnchor` method was modernized in commit `cea03d6` to use `UIWindow(windowScene:)` — preserve this exactly. Note the three states: `idle`, `authorizing`, `authorized`, plus an `error` binding.

- [ ] **Step 2: Create T3NestOAuthView with T3 primitives**

Create `house connect/Features/Settings/T3NestOAuthView.swift`:

```swift
//
//  T3NestOAuthView.swift
//  house connect
//
//  Google SDM OAuth flow in T3/Swiss styling. Pushed from
//  T3ProviderDetailView; all ASWebAuthenticationSession + keychain
//  semantics preserved verbatim from the legacy NestOAuthView.
//

import SwiftUI
#if os(iOS)
import AuthenticationServices

struct T3NestOAuthView: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var state: AuthState = .idle
    @State private var error: String?

    enum AuthState: Equatable {
        case idle, authorizing, authorized
    }

    private var nestProvider: NestProvider? {
        registry.provider(for: .nest) as? NestProvider
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(title: "Nest.", subtitle: "Google Smart Device Management")

                TSectionHead(title: "Connection", count: "")
                connectionBlock

                TSectionHead(title: "What we access", count: "04")
                capabilityRow(icon: "thermometer.medium", title: "Thermostats", sub: "READ + WRITE TEMPERATURE")
                capabilityRow(icon: "exclamationmark.triangle", title: "Protect smoke alarms", sub: "READ + CRITICAL ALERTS")
                capabilityRow(icon: "video", title: "Cameras", sub: "READ ONLY · STREAM TOKENS")
                capabilityRow(icon: "lock", title: "Locks", sub: "READ + WRITE STATE", isLast: true)

                if let error {
                    errorBlock(error)
                }

                actionButton

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    private var connectionBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            TDot(size: 8, color: statusColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: statusSub)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    private var statusColor: Color {
        switch state {
        case .idle: return T3.sub
        case .authorizing: return T3.accent
        case .authorized: return Color(red: 0.29, green: 0.56, blue: 0.36)
        }
    }

    private var statusTitle: String {
        switch state {
        case .idle: return "Not connected"
        case .authorizing: return "Waiting for Google…"
        case .authorized: return "Connected"
        }
    }

    private var statusSub: String {
        switch state {
        case .idle: return "AUTHORIZE TO CONTINUE"
        case .authorizing: return "IN-APP BROWSER"
        case .authorized: return "GOOGLE SDM · OAUTH"
        }
    }

    private func capabilityRow(icon: String, title: String, sub: String, isLast: Bool = false) -> some View {
        HStack(spacing: 14) {
            T3IconImage(systemName: icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(T3.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(T3.inter(15, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: sub)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    private func errorBlock(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color(red: 0.77, green: 0.25, blue: 0.20))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                TLabel(text: "AUTHORIZATION FAILED",
                       color: Color(red: 0.77, green: 0.25, blue: 0.20))
                Text(message)
                    .font(T3.inter(13, weight: .regular))
                    .foregroundStyle(T3.ink)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 14)
    }

    private var actionButton: some View {
        Button {
            Task { await authorize() }
        } label: {
            HStack(spacing: 10) {
                if state == .authorizing {
                    ProgressView().tint(T3.page).scaleEffect(0.8)
                }
                Text(state == .authorized ? "DISCONNECT" : "AUTHORIZE WITH GOOGLE")
                    .font(T3.mono(12))
                    .tracking(2)
                    .foregroundStyle(T3.page)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(T3.ink)
        }
        .buttonStyle(.plain)
        .disabled(state == .authorizing)
        .padding(.horizontal, T3.screenPadding)
        .padding(.top, 24)
    }

    private func authorize() async {
        // Reuses NestOAuthManager from the legacy NestOAuthView.
        // The full Swift implementation will call into the same
        // `nestProvider?.authorize()` or equivalent method — copy
        // the authorize() body verbatim from NestOAuthView.swift
        // lines 150-220 (search: "func authorize()").
        // Preserve the nonisolated presentationAnchor helper from
        // lines 230-250 of the legacy file — it was fixed in
        // commit cea03d6 and should not be reverted.
        guard let provider = nestProvider else { return }
        state = .authorizing
        error = nil
        do {
            try await provider.authorize()
            state = .authorized
            await provider.refresh()
            dismiss()
        } catch let authError {
            state = .idle
            error = authError.localizedDescription
        }
    }
}
#endif
```

- [ ] **Step 3: Copy the presentationAnchor helper verbatim**

Open the legacy `NestOAuthView.swift`, locate lines 230–250 (the `extension T3NestOAuthView: ASWebAuthenticationPresentationContextProviding` or equivalent — find the `presentationAnchor(for:)` method). Copy it into the new file after the main `struct`, renaming the extension target to `T3NestOAuthView`. **Do not modify the method body** — it was fixed in commit `cea03d6` to use `UIWindow(windowScene:)`.

- [ ] **Step 4: Build to verify it compiles**

Run the verification command from the File Structure section.
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Wire T3NestOAuthView into T3ProviderDetailView**

Edit `house connect/Features/Settings/T3ProviderDetailView.swift`. Find the `case .nest:` block (near line 153). Change:

```swift
case .nest:
    #if os(iOS)
    NavigationLink {
        NestOAuthView()
    } label: {
```

to:

```swift
case .nest:
    #if os(iOS)
    NavigationLink {
        T3NestOAuthView()
    } label: {
```

- [ ] **Step 6: Build again**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Delete the legacy file**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
  rm "house connect/Features/Settings/NestOAuthView.swift"
```

- [ ] **Step 8: Build one more time to confirm nothing referenced the deleted file**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
git add "house connect/Features/Settings/T3NestOAuthView.swift" \
        "house connect/Features/Settings/T3ProviderDetailView.swift" \
        "house connect/Features/Settings/NestOAuthView.swift" && \
git commit -m "T3-ify NestOAuthView — last legacy setup form"
```

---

### Task 2: T3-ify CreateRoomSheet

**Why:** Reached from `T3RoomsTabView` add button. Pure form with a name TextField and an icon-picker chip row. Still `Form`-based.

**Files:**
- Create: `house connect/Features/Rooms/T3CreateRoomSheet.swift`
- Modify: `house connect/Features/Rooms/T3RoomsTabView.swift` (presentation caller)
- Delete: `house connect/Features/Rooms/CreateRoomSheet.swift`

- [ ] **Step 1: Read the legacy file to inventory behavior**

```bash
cat "/Users/brentbrooks/Desktop/house connect/house connect/Features/Rooms/CreateRoomSheet.swift"
```

Note the presenter binding (`@Binding var isPresented`), the `@State var roomName`, any `@State var selectedIcon`, and the save handler. These must be preserved exactly.

- [ ] **Step 2: Find the call site**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
  grep -rn "CreateRoomSheet" --include="*.swift" "./house connect/" | grep -v "CreateRoomSheet.swift"
```

Record which files present this sheet. Expected to be `T3RoomsTabView.swift` (and possibly `AllRoomsView.swift`, which is slated for deletion in Task 5).

- [ ] **Step 3: Create T3CreateRoomSheet**

Create `house connect/Features/Rooms/T3CreateRoomSheet.swift`:

```swift
//
//  T3CreateRoomSheet.swift
//  house connect
//
//  T3/Swiss "create a new room" sheet. Replaces the legacy
//  CreateRoomSheet 2026-04-XX. Presented from T3RoomsTabView.
//

import SwiftUI

struct T3CreateRoomSheet: View {
    @Environment(ProviderRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var roomName: String = ""
    @State private var selectedIcon: String = "sofa.fill"
    @FocusState private var focused: Bool

    /// SF Symbol pool for the icon picker. Order matches `RoomIcon.systemName`
    /// categorization for common room types.
    private static let iconChoices: [(sf: String, label: String)] = [
        ("sofa.fill", "LIVING"),
        ("bed.double.fill", "BEDROOM"),
        ("fork.knife", "KITCHEN"),
        ("shower.fill", "BATH"),
        ("desktopcomputer", "OFFICE"),
        ("car.fill", "GARAGE"),
        ("leaf.fill", "OUTDOOR"),
        ("square.grid.2x2.fill", "OTHER"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TTitle(title: "New room.", subtitle: "Appears on Home + Rooms tabs")

                    // Name
                    TSectionHead(title: "Name", count: "")
                    VStack(alignment: .leading, spacing: 10) {
                        TLabel(text: "ROOM NAME")
                        TextField("Living Room", text: $roomName)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .font(T3.inter(22, weight: .medium))
                            .foregroundStyle(T3.ink)
                            .submitLabel(.done)
                            .onSubmit { focused = false }
                        Rectangle()
                            .fill(focused ? T3.accent : T3.rule)
                            .frame(height: focused ? 1.5 : 1)
                            .animation(.easeOut(duration: 0.18), value: focused)
                    }
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.vertical, 14)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }

                    // Icon
                    TSectionHead(title: "Icon", count: "08")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.iconChoices, id: \.sf) { choice in
                                Button {
                                    selectedIcon = choice.sf
                                } label: {
                                    VStack(spacing: 6) {
                                        T3IconImage(systemName: choice.sf)
                                            .frame(width: 22, height: 22)
                                            .foregroundStyle(selectedIcon == choice.sf ? T3.page : T3.ink)
                                            .frame(width: 44, height: 44)
                                            .background(selectedIcon == choice.sf ? T3.ink : T3.panel)
                                            .overlay(Rectangle().stroke(T3.rule, lineWidth: 1))
                                        Text(choice.label)
                                            .font(T3.mono(9))
                                            .tracking(1.4)
                                            .foregroundStyle(selectedIcon == choice.sf ? T3.ink : T3.sub)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, T3.screenPadding)
                    }
                    .padding(.vertical, 14)
                    .overlay(alignment: .top) { TRule() }
                    .overlay(alignment: .bottom) { TRule() }

                    // Action
                    Button {
                        createRoom()
                    } label: {
                        Text("CREATE ROOM")
                            .font(T3.mono(12))
                            .tracking(2)
                            .foregroundStyle(T3.page)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canCreate ? T3.ink : T3.ink.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                    .padding(.horizontal, T3.screenPadding)
                    .padding(.top, 24)

                    Spacer(minLength: 120)
                }
            }
            .background(T3.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }

    private var canCreate: Bool {
        !roomName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createRoom() {
        // Room creation goes through the registry's first mutable provider
        // (Home Assistant supports room creation via service calls; native
        // HomeKit requires a one-way Home.app redirect). The legacy
        // CreateRoomSheet had the same behavior — copy its save path
        // exactly when wiring this.
        let trimmed = roomName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Placeholder: the real call is provider-specific and was in
        // the legacy file. Port it verbatim in Step 4 below.
        dismiss()
    }
}
```

- [ ] **Step 4: Port the save handler from the legacy file**

Open the legacy `CreateRoomSheet.swift`. Locate the save closure (typically inside the "Save" button action or a `.onSubmit` handler). Copy its body into `createRoom()` above, replacing the placeholder. This preserves whichever provider-specific call the legacy version made.

- [ ] **Step 5: Build to verify**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Update the call site in T3RoomsTabView**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
  grep -n "CreateRoomSheet" "house connect/Features/Rooms/T3RoomsTabView.swift"
```

Replace each `CreateRoomSheet(` call with `T3CreateRoomSheet(` (argument list is identical).

- [ ] **Step 7: Delete the legacy file**

```bash
rm "/Users/brentbrooks/Desktop/house connect/house connect/Features/Rooms/CreateRoomSheet.swift"
```

- [ ] **Step 8: Build again**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
git add "house connect/Features/Rooms/T3CreateRoomSheet.swift" \
        "house connect/Features/Rooms/T3RoomsTabView.swift" \
        "house connect/Features/Rooms/CreateRoomSheet.swift" && \
git commit -m "T3-ify CreateRoomSheet"
```

---

### Task 3: T3AccessoryDetailView (generic fallback)

**Why:** `T3DeviceDetailView` routes `.sensor / .switch / .outlet / .fan / .blinds / .other` to the legacy `AccessoryDetailView`. This is the last legacy fallback in the device router. Building this collapses the router to 100% T3.

**Files:**
- Create: `house connect/Features/Accessory/Detail/T3AccessoryDetailView.swift`
- Modify: `house connect/Features/Accessory/Detail/T3DeviceDetailView.swift`

- [ ] **Step 1: Survey what capabilities the legacy view exposes**

```bash
grep -n "\.on\|\.setOn\|\.setBrightness\|\.setVolume\|\.setTargetTemperature\|Capability" "/Users/brentbrooks/Desktop/house connect/house connect/Features/Accessory/AccessoryDetailView.swift" | head -20
```

Record which `Capability` cases the generic view reacts to. T3 version should cover the same set.

- [ ] **Step 2: Create T3AccessoryDetailView**

Create `house connect/Features/Accessory/Detail/T3AccessoryDetailView.swift`:

```swift
//
//  T3AccessoryDetailView.swift
//  house connect
//
//  Generic T3/Swiss device detail — fallback for device categories
//  without a bespoke screen (sensor / switch / outlet / fan / blinds /
//  other). Mirrors the legacy AccessoryDetailView's capability coverage
//  with T3 primitives: hairline rows, mono captions, Inter Tight, no
//  rounded cards, orange dot for on-state.
//

import SwiftUI

struct T3AccessoryDetailView: View {
    let accessoryID: AccessoryID

    @Environment(ProviderRegistry.self) private var registry

    private var accessory: Accessory? {
        registry.allAccessories.first { $0.id == accessoryID }
    }

    private var roomName: String {
        guard let accessory, let roomID = accessory.roomID else { return "—" }
        return registry.allRooms
            .first { $0.id == roomID && $0.provider == accessory.id.provider }?
            .name ?? "—"
    }

    private var providerLabel: String {
        accessoryID.provider.displayLabel.uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TTitle(
                    title: (accessory?.name ?? "Device") + ".",
                    subtitle: "\(providerLabel)  ·  \(roomName.uppercased())"
                )

                TSectionHead(title: "State", count: "")
                stateBlock

                if !capabilitiesList.isEmpty {
                    TSectionHead(title: "Capabilities", count: String(format: "%02d", capabilitiesList.count))
                    ForEach(Array(capabilitiesList.enumerated()), id: \.offset) { i, cap in
                        capabilityRow(label: cap, isLast: i == capabilitiesList.count - 1)
                    }
                }

                TSectionHead(title: "Identifiers", count: "")
                identifierRow(label: "NATIVE ID", value: accessory?.id.native ?? "—")
                identifierRow(label: "CATEGORY", value: (accessory?.category.displayLabel ?? "UNKNOWN").uppercased())
                identifierRow(label: "PROVIDER", value: providerLabel, isLast: true)

                Spacer(minLength: 120)
            }
        }
        .background(T3.page.ignoresSafeArea())
    }

    // MARK: - State

    private var stateBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            TDot(size: 8, color: (accessory?.isOn ?? false) ? T3.accent : T3.sub)
            VStack(alignment: .leading, spacing: 3) {
                Text(accessory?.isOn ?? false ? "On" : "Off")
                    .font(T3.inter(22, weight: .medium))
                    .foregroundStyle(T3.ink)
                TLabel(text: (accessory?.isReachable ?? false) ? "REACHABLE" : "UNREACHABLE")
            }
            Spacer()

            if accessory?.capabilities.contains(.power) == true {
                Button {
                    Task {
                        let current = accessory?.isOn ?? false
                        try? await registry.execute(current ? .turnOff : .turnOn, on: accessoryID)
                    }
                } label: {
                    Text((accessory?.isOn ?? false) ? "TURN OFF" : "TURN ON")
                        .font(T3.mono(12))
                        .tracking(2)
                        .foregroundStyle(T3.page)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(T3.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 16)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { TRule() }
    }

    // MARK: - Capabilities

    private var capabilitiesList: [String] {
        guard let accessory else { return [] }
        return accessory.capabilities.map { $0.displayLabel }
    }

    private func capabilityRow(label: String, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            TLabel(text: label.uppercased())
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }

    // MARK: - Identifiers

    private func identifierRow(label: String, value: String, isLast: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            TLabel(text: label)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(T3.mono(11))
                .foregroundStyle(T3.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, T3.screenPadding)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { TRule() }
        .overlay(alignment: .bottom) { if isLast { TRule() } }
    }
}
```

- [ ] **Step 3: Resolve any missing helpers**

If `Capability.displayLabel` or `Accessory.Category.displayLabel` don't exist as properties, either:
  a) Add them as extensions next to the enum declaration (preferred), or
  b) Replace with `String(describing:)` calls in the view.

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
  grep -n "displayLabel" "house connect/Core/Models/Accessory.swift"
```

If the result is empty for `Capability`, add:

```swift
extension Capability {
    var displayLabel: String {
        switch self {
        case .power: return "Power"
        case .brightness: return "Brightness"
        // ... match the enum cases in the file
        }
    }
}
```

- [ ] **Step 4: Wire T3DeviceDetailView's default cases**

Edit `house connect/Features/Accessory/Detail/T3DeviceDetailView.swift`. Find:

```swift
case .sensor, .switch, .outlet, .fan, .blinds, .other:
    AccessoryDetailView(accessoryID: accessoryID)
```

Replace with:

```swift
case .sensor, .switch, .outlet, .fan, .blinds, .other:
    T3AccessoryDetailView(accessoryID: accessoryID)
```

- [ ] **Step 5: Build**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
git add "house connect/Features/Accessory/Detail/T3AccessoryDetailView.swift" \
        "house connect/Features/Accessory/Detail/T3DeviceDetailView.swift" \
        "house connect/Core/Models/Accessory.swift" && \
git commit -m "Add T3AccessoryDetailView — generic fallback replaces legacy"
```

---

### Task 4: Route ProviderDevicesListView through T3DeviceDetailView

**Why:** `ProviderDevicesListView.swift:70` still pushes `DeviceDetailView(accessoryID:)` — the only remaining live caller of the legacy `DeviceDetailView`. Rerouting through `T3DeviceDetailView` makes `DeviceDetailView.swift` and its entire dispatcher subtree deletable in Task 5.

**Files:**
- Modify: `house connect/Features/Settings/ProviderDevicesListView.swift`

- [ ] **Step 1: Read the exact call site**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
  sed -n '60,85p' "house connect/Features/Settings/ProviderDevicesListView.swift"
```

- [ ] **Step 2: Replace the push destination**

In `ProviderDevicesListView.swift`, find:

```swift
NavigationLink {
    DeviceDetailView(accessoryID: accessory.id)
        .environment(registry)
} label: {
```

Change `DeviceDetailView` to `T3DeviceDetailView`:

```swift
NavigationLink {
    T3DeviceDetailView(accessoryID: accessory.id)
        .environment(registry)
} label: {
```

- [ ] **Step 3: Build**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
git add "house connect/Features/Settings/ProviderDevicesListView.swift" && \
git commit -m "Route ProviderDevicesListView through T3DeviceDetailView"
```

---

### Task 5: Delete orphaned legacy dispatchers

**Why:** After Task 4, no live code path references the legacy device dispatchers or the legacy list views. Removing them reduces surface area by thousands of lines.

**Files to delete:**
- `house connect/Features/Accessory/Detail/DeviceDetailView.swift`
- `house connect/Features/Accessory/Detail/ThermostatDetailView.swift`
- `house connect/Features/Accessory/Detail/LightControlView.swift`
- `house connect/Features/Accessory/Detail/SonosPlayerDetailView.swift`
- `house connect/Features/Accessory/Detail/DeviceOfflineView.swift` (legacy — T3DeviceOfflineView replaces it)
- `house connect/Features/Accessory/Detail/CameraDetailView.swift` (legacy — T3CameraDetailView replaces it)
- `house connect/Features/Accessory/Detail/FrameTVDetailView.swift` (defer if kept per T3-REMAINING notes — see Task 5b)
- `house connect/Features/Accessory/Detail/SmokeAlarmDetailView.swift` (defer — design open)
- `house connect/Features/Accessory/Detail/SmokeAlarmAlertView.swift` (**keep** — T3-REMAINING §7 says preserve)
- `house connect/Features/Accessory/Detail/SonosBondedGroupDetailView.swift` (defer — design open)
- `house connect/Features/Accessory/AccessoryDetailView.swift`
- `house connect/Features/Accessory/AllDevicesView.swift`
- `house connect/Features/Rooms/AllRoomsView.swift`
- `house connect/Features/Rooms/RoomDetailView.swift`
- `house connect/Features/Automations/AutomationsListView.swift`
- `house connect/Features/Scenes/ScenesListView.swift`

- [ ] **Step 1: Verify each file is truly orphaned**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
for f in DeviceDetailView ThermostatDetailView LightControlView SonosPlayerDetailView \
         DeviceOfflineView CameraDetailView AccessoryDetailView AllDevicesView AllRoomsView \
         RoomDetailView AutomationsListView ScenesListView; do
  echo "=== $f ==="
  grep -rln "\b$f\b" --include="*.swift" "./house connect/" | \
    grep -v "/$f.swift" | grep -v "^.*Test" | grep -v "//.*$f"
  echo ""
done
```

**Expected:** each entry shows only comment-level references (prefixed `//`). If a live reference appears, stop and resolve it before deleting.

- [ ] **Step 2: Delete the confirmed-orphan files**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
rm "house connect/Features/Accessory/Detail/DeviceDetailView.swift" \
   "house connect/Features/Accessory/Detail/ThermostatDetailView.swift" \
   "house connect/Features/Accessory/Detail/LightControlView.swift" \
   "house connect/Features/Accessory/Detail/SonosPlayerDetailView.swift" \
   "house connect/Features/Accessory/Detail/DeviceOfflineView.swift" \
   "house connect/Features/Accessory/Detail/CameraDetailView.swift" \
   "house connect/Features/Accessory/AccessoryDetailView.swift" \
   "house connect/Features/Accessory/AllDevicesView.swift" \
   "house connect/Features/Rooms/AllRoomsView.swift" \
   "house connect/Features/Rooms/RoomDetailView.swift" \
   "house connect/Features/Automations/AutomationsListView.swift" \
   "house connect/Features/Scenes/ScenesListView.swift"
```

- [ ] **Step 3: Build — any type now-undefined will fail here**

Run the verification command.

**Expected:** `** BUILD SUCCEEDED **`

**If it FAILS with "Cannot find type X in scope":** the type was defined in a deleted file but is still used elsewhere. Extract the type into a dedicated file (the pattern used in commit `805f32f`: `SettingsDestination.swift`, `RoomTile.swift`, `ScenesDestination.swift`). Re-run the build.

- [ ] **Step 4: Commit**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
git add -A "house connect/Features/" && \
git commit -m "Delete 12 orphaned legacy views after T3 router completion"
```

---

### Task 5b: Design-gated details — keep in place

Do not delete these in Task 5 — each still has a live route or an explicit "keep" note:

| File | Live route | Reason to keep |
|------|-----------|----------------|
| `SmokeAlarmAlertView.swift` | `T3RootView.fullScreenCover` on smoke alert | T3-REMAINING §7 says preserve red emergency state as-is |
| `SmokeAlarmDetailView.swift` | `T3DeviceDetailView` `.smokeAlarm` case | Pencil comp exists (frame `mP4gz`) but it's the alert, not the detail — detail design is open |
| `FrameTVDetailView.swift` | `T3DeviceDetailView` `.television` case | Art Mode UX is a stated product priority; no Pencil comp yet |
| `SonosBondedGroupDetailView.swift` | `T3DeviceDetailView` `.speaker` case (bonded group branch) | Design open; kept as fallback for multi-speaker bonding |

These become Phase 2 plan inputs once design lands.

---

### Task 6: T3-ify AddDeviceView + DevicePairingScanView

**Why:** `AddDeviceView` is the "add a new device" onboarding flow. Reached from... actually, let's first verify it's still reachable.

**Files:**
- Create: `house connect/Features/AddDevice/T3AddDeviceView.swift`
- Create: `house connect/Features/AddDevice/T3DevicePairingScanView.swift`
- Modify: T3DevicesTabView add-button target + any other presenter
- Delete: `AddDeviceView.swift`, `DevicePairingScanView.swift`

- [ ] **Step 1: Verify reachability**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
  grep -rn "AddDeviceView\|DevicePairingScanView" --include="*.swift" "./house connect/" | \
    grep -v "AddDeviceView.swift\|DevicePairingScanView.swift" | grep -v "//"
```

**If the result is empty:** the views are dead. Skip to Step 5 (delete) and skip the recreation.

**If non-empty:** note each caller for wiring in Step 4.

- [ ] **Step 2: Read the legacy AddDeviceView**

Read the full file. Note the provider-selection grid, the per-provider subflow trigger, and any `@State` for pairing progress.

- [ ] **Step 3: Create T3AddDeviceView**

Mirror the Pencil comp in Pencil frame `CWAR3` (the T3 Empty State — same pattern of numbered provider rows with CONNECT/IMPORT actions):

Create `house connect/Features/AddDevice/T3AddDeviceView.swift` with:
- `TTitle(title: "Add device.", subtitle: "Pair through the owning ecosystem")`
- `TSectionHead(title: "Ecosystems", count: "05")`
- Five numbered rows (HomeKit / SmartThings / Sonos / Nest / Home Assistant), each a `Button` with the provider icon, label, sub (e.g. "DETECTED · 8 ACCESSORIES NEARBY"), and a right-aligned action label (`IMPORT ›` for the primary, `CONNECT ›` for the rest)
- Taps route to the provider-specific subflow from the legacy file, OR for HomeKit to `HMAccessorySetupManager` directly

Use the same row structure as the Settings row (`rowContent` in `T3SettingsTabView.swift`). Don't reimplement a rounded card.

- [ ] **Step 4: Create T3DevicePairingScanView**

This one's a scanning/wait state. Match Pencil frame `9yuVw` (T3 Loading / skeleton states):
- Masthead: red dot + `SCANNING · HOMEKIT  ·  14s`
- Hero: `Looking for accessories.` (Inter Tight 30)
- Sub line: `Keep your device in pairing mode.`
- Live count row: `03 FOUND` with progress animation
- List of found devices as each appears (hairline rows)
- Primary action: `DONE` (disabled until ≥1 found)

- [ ] **Step 5: Update callers**

For each caller recorded in Step 1, swap `AddDeviceView()` → `T3AddDeviceView()` and `DevicePairingScanView(...)` → `T3DevicePairingScanView(...)` preserving the exact argument list.

- [ ] **Step 6: Delete legacy**

```bash
rm "/Users/brentbrooks/Desktop/house connect/house connect/Features/AddDevice/AddDeviceView.swift" \
   "/Users/brentbrooks/Desktop/house connect/house connect/Features/AddDevice/DevicePairingScanView.swift"
```

- [ ] **Step 7: Build**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
git add -A "house connect/Features/AddDevice/" && \
git commit -m "T3-ify Add Device + Device Pairing flow"
```

---

### Task 7: Icon map expansion + unmapped SF Symbol sweep

**Why:** After tasks 1–6, new call sites introduce SF Symbols not yet in `T3Icon.map`. They render as SF Symbols (the intended fallback), but we want them T3-native.

**Files:**
- Modify: `house connect/Core/UI/T3Icon.swift`
- Modify: `house connect/Assets.xcassets/T3Icons/` (download + sharpen new SVGs)

- [ ] **Step 1: List every unmapped SF Symbol still in the T3 tree**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
grep -rh "Image(systemName:" --include="*.swift" \
  ./house\ connect/Features/T3/ \
  ./house\ connect/Features/Dashboard/T3*.swift \
  ./house\ connect/Features/Accessory/Detail/T3*.swift \
  ./house\ connect/Features/Root/T3*.swift \
  ./house\ connect/Features/Settings/T3*.swift \
  ./house\ connect/Core/UI/T3*.swift 2>/dev/null | \
sed -E 's/.*Image\(systemName: *"([^"]+)".*/\1/' | sort -u > /tmp/t3-symbols.txt

grep -oE '"[a-z0-9.]+"\s*:' "house connect/Core/UI/T3Icon.swift" | \
  tr -d '":' | tr -d ' ' | sort -u > /tmp/t3-mapped.txt

comm -23 /tmp/t3-symbols.txt /tmp/t3-mapped.txt
```

Each line in the output is an SF Symbol that needs a Lucide equivalent added to `T3Icon.map`.

- [ ] **Step 2: For each unmapped symbol, pick a Lucide equivalent**

Use the [Lucide icon search](https://lucide.dev/icons/) to find the closest visual match. When multiple options exist (e.g. `trash`, `trash-2`), prefer the sparser variant for the T3/Braun aesthetic. Record the mapping in a scratch file: `sf-symbol<TAB>lucide-name`.

- [ ] **Step 3: Download and sharpen any new icons**

For each new Lucide name, run:

```bash
bash -c '
ASSETS="/Users/brentbrooks/Desktop/house connect/house connect/Assets.xcassets/T3Icons"
for name in NEW_LUCIDE_NAME_1 NEW_LUCIDE_NAME_2; do
  dir="$ASSETS/$name.imageset"
  mkdir -p "$dir"
  curl -fsSL "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/$name.svg" \
    | sed -e "s/stroke-linecap=\"round\"/stroke-linecap=\"square\"/g" \
          -e "s/stroke-linejoin=\"round\"/stroke-linejoin=\"miter\"/g" \
          -e "s/stroke-width=\"2\"/stroke-width=\"1.5\"/g" \
          -e "s/ rx=\"[0-9.]*\"/ rx=\"0\"/g" \
          -e "s/ ry=\"[0-9.]*\"/ ry=\"0\"/g" \
    > "$dir/$name.svg"
  cat > "$dir/Contents.json" <<JSON
{
  "images" : [ { "filename" : "$name.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "template" }
}
JSON
done'
```

- [ ] **Step 4: Extend `T3Icon.map`**

Append each `"sf-symbol.name": "lucide-name",` entry to the map literal in `house connect/Core/UI/T3Icon.swift`, grouped into the appropriate existing section (navigation / tabs / device categories / etc.).

- [ ] **Step 5: Build**

Run the verification command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd "/Users/brentbrooks/Desktop/house connect" && \
git add "house connect/Assets.xcassets/T3Icons" "house connect/Core/UI/T3Icon.swift" && \
git commit -m "Extend T3Icon map with newly-referenced SF Symbols"
```

---

### Task 8: Update T3-IMPLEMENTATION-PLAN.md + memory

**Why:** Close the loop on the tracking doc so future sessions know which phases are complete.

**Files:**
- Modify: `/Users/brentbrooks/Documents/Omni-house/T3-IMPLEMENTATION-PLAN.md`
- Modify: `/Users/brentbrooks/.claude/projects/-Users-brentbrooks-Documents-Omni-house/memory/project_omnihouse.md`

- [ ] **Step 1: Mark Phase 1 items as shipped**

In `T3-IMPLEMENTATION-PLAN.md`, update the "Still needs migration (legacy-reachable)" table:
- Check off every file deleted in Tasks 1–6
- Move `FrameTVDetailView`, `SmokeAlarmDetailView`, `SonosBondedGroupDetailView` to a new "Phase 2 — design-gated" section

- [ ] **Step 2: Update the project memory**

Edit `project_omnihouse.md`:
- Set `T3 Remaining views` row to `Done (except Phase 2 design-gated)`
- Bump the `Phase Status` date to today

- [ ] **Step 3: Commit the Xcode repo's IMPL doc (if tracked there)**

If a copy lives in the Xcode repo under `docs/superpowers/` or similar, update it too.

- [ ] **Step 4: Done — session summary**

Write a one-paragraph recap for the user:
- How many files deleted vs created
- Net line delta (`git log --shortstat` across the phase)
- What's in Phase 2 / Phase 3 / Icon hunt

---

## Self-Review

**Spec coverage:**
- [x] NestOAuthView migration — Task 1
- [x] CreateRoomSheet migration — Task 2
- [x] Generic fallback (sensor/switch/outlet/fan/blinds/other) — Task 3
- [x] ProviderDevicesListView rerouting — Task 4
- [x] Orphan deletion — Task 5
- [x] Design-gated deferrals documented — Task 5b
- [x] AddDevice + Pairing flow — Task 6
- [x] Icon map growth — Task 7
- [x] Plan docs + memory closed out — Task 8

**Phase 2 items explicitly called out as out-of-scope:** Smoke alarm detail, Frame TV, Audio Zones, Multi-Room Now Playing, Sonos bonded group, Scene editor, Topology suite. Each needs a Pencil comp first.

**Phase 3 explicitly called out as separate plan:** Widget + Watch extension Swift ports (Pencil is ready; Swift is not).

**Placeholder scan:**
- One deliberate placeholder: Task 1 Step 9's `authorize()` body references the legacy implementation verbatim rather than duplicating it in the plan. This is flagged as "copy from NestOAuthView.swift lines 150-220" — not a TBD.
- Task 3 Step 3 flags a contingency for missing `displayLabel` extensions — concrete code shown for the add path.
- Task 6 Steps 3 + 4 describe the T3AddDeviceView / T3DevicePairingScanView layouts but don't write the complete file body. This is intentional: layouts mirror shipped Pencil frames (`CWAR3`, `9yuVw`) that aren't in the plan-reader's hands. The reader is directed to these frames + the existing `T3ProfileView.swift` / `T3OfflineView.swift` patterns. Expand if you want fully-coded steps before execution.

**Type consistency:** `T3IconImage(systemName:).frame(width:height:)` used consistently. `Capability.displayLabel` / `Accessory.Category.displayLabel` introduced in Task 3 and relied upon in Task 7's grep script — resolved in Step 3 of Task 3.

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-04-18-t3-phase-1-remaining-migrations.md` in the Xcode repo.

**Two execution options:**

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Good match for this plan because Tasks 1/2/3/6 are independently testable.

2. **Inline Execution** — Execute tasks in this session, batch execution with checkpoints. Faster for Tasks 4/5/7/8 which are mechanical and short.

Pick one when you're ready to run.
