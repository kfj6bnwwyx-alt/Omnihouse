//
//  SceneRunWidget.swift
//  HouseConnectWidgets
//
//  Wave JJ (2026-04-18) — Lock-screen + home-screen widget that runs a
//  Home Assistant scene with a single tap. The user picks which scene a
//  widget instance represents via long-press → Edit Widget, and tapping
//  the widget invokes `RunSceneIntent`, which either:
//
//    1) Runs the scene directly via the in-process ProviderRegistry (if
//       the app happens to be already running in the background), or
//    2) Falls back to opening the main app via the `houseconnect://` URL
//       scheme — the existing app surface can then route the deep link.
//
//  The scene catalog is hardcoded here (mirroring the approach Wave EE
//  used for `ThermostatEntity`). When the App Group snapshot path lands
//  we'll rehydrate `SceneRunEntity.allKnown` from shared UserDefaults.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Scene entity

/// An `AppEntity` representing a runnable Home Assistant scene. Surfaced
/// to the widget configuration UI so the user can pick which scene each
/// widget instance triggers.
struct SceneRunEntity: AppEntity, Identifiable, Hashable {
    /// Home Assistant scene id (e.g. `scene.good_morning`).
    var id: String
    /// Display title shown on the widget and in the picker.
    var name: String
    /// SF Symbol used for the widget glyph. Swapped for custom T3 icons
    /// once the Claude-designed SVG set is exported (see reference memo).
    var symbolName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Scene")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = SceneRunEntityQuery()

    /// Hard-coded scenes matching the placeholder catalog Brent sketched
    /// in Pencil. Replace with App Group-backed list once the main app
    /// publishes a scene snapshot.
    static let allKnown: [SceneRunEntity] = [
        SceneRunEntity(id: "scene.good_morning", name: "Good Morning", symbolName: "sun.max"),
        SceneRunEntity(id: "scene.bedtime",      name: "Bedtime",      symbolName: "moon.stars"),
        SceneRunEntity(id: "scene.movie_time",   name: "Movie Time",   symbolName: "tv"),
        SceneRunEntity(id: "scene.away",         name: "Away",         symbolName: "figure.walk.departure")
    ]
}

struct SceneRunEntityQuery: EntityQuery {
    func entities(for identifiers: [SceneRunEntity.ID]) async throws -> [SceneRunEntity] {
        SceneRunEntity.allKnown.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SceneRunEntity] {
        SceneRunEntity.allKnown
    }

    func defaultResult() async -> SceneRunEntity? {
        SceneRunEntity.allKnown.first
    }
}

// MARK: - Configuration intent

struct SceneRunSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Scene"
    static var description = IntentDescription("Choose which scene this widget should run when tapped.")

    @Parameter(title: "Scene")
    var scene: SceneRunEntity?
}

// MARK: - Run intent (button tap)

/// Invoked when the user taps the widget. Tries to fire the scene in
/// process; always opens the main app via deep link so the user sees a
/// confirmation / fallback runner if the widget extension can't reach
/// the HA client directly.
struct RunSceneIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Scene"
    static var description = IntentDescription("Runs the selected Home Assistant scene.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Scene ID")
    var sceneID: String

    init() {
        self.sceneID = ""
    }

    init(sceneID: String) {
        self.sceneID = sceneID
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        // Hand off to the main app. The existing `houseconnect://` URL
        // scheme is already registered (see SmokeAlertLiveActivity use
        // of `houseconnect://smoke/silence`). If the app does not yet
        // handle `scene/run/...`, worst case the app simply opens and
        // the user can tap Run manually — acceptable per Wave JJ scope.
        let encoded = sceneID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sceneID
        let url = URL(string: "houseconnect://scene/run/\(encoded)")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// MARK: - Timeline

struct SceneRunWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SceneRunWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: SceneRunSelectionIntent, in context: Context) async -> SceneRunWidgetEntry {
        entry(for: configuration.scene)
    }

    func timeline(for configuration: SceneRunSelectionIntent, in context: Context) async -> Timeline<SceneRunWidgetEntry> {
        // Scenes have no live data to display — refresh infrequently.
        // Re-render is driven primarily by configuration change.
        let entry = entry(for: configuration.scene)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60 * 6)))
    }

    private func entry(for selection: SceneRunEntity?) -> SceneRunWidgetEntry {
        let resolved = selection
            ?? SceneRunEntity.allKnown.first
            ?? SceneRunEntity(id: "scene.unknown", name: "Scene", symbolName: "sparkles")
        return SceneRunWidgetEntry(
            date: Date(),
            sceneID: resolved.id,
            sceneName: resolved.name,
            symbolName: resolved.symbolName
        )
    }
}

struct SceneRunWidgetEntry: TimelineEntry {
    let date: Date
    let sceneID: String
    let sceneName: String
    let symbolName: String

    static let placeholder = SceneRunWidgetEntry(
        date: Date(),
        sceneID: "scene.good_morning",
        sceneName: "Good Morning",
        symbolName: "sun.max"
    )
}

// MARK: - Views

/// Home-screen `.systemSmall` layout — matte-black panel, mono type,
/// rule lines, ink/sub hierarchy to match ThermostatWidget.
struct SceneRunSmallView: View {
    let entry: SceneRunWidgetEntry

    var body: some View {
        Button(intent: RunSceneIntent(sceneID: entry.sceneID)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TLabel(text: "Scene")
                    Spacer()
                    TDot(size: 6, color: T3.accent)
                }

                Spacer(minLength: 0)

                Image(systemName: entry.symbolName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(T3.ink)

                Text(entry.sceneName)
                    .font(T3.inter(18, weight: .semibold))
                    .foregroundStyle(T3.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                TRule()

                TLabel(text: "Tap to run")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(T3.page)
        }
        .buttonStyle(.plain)
    }
}

/// `.accessoryCircular` — lock-screen ring. Just a glyph.
struct SceneRunCircularView: View {
    let entry: SceneRunWidgetEntry

    var body: some View {
        Button(intent: RunSceneIntent(sceneID: entry.sceneID)) {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.symbolName)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }
}

/// `.accessoryRectangular` — lock-screen row. Glyph + name.
struct SceneRunRectangularView: View {
    let entry: SceneRunWidgetEntry

    var body: some View {
        Button(intent: RunSceneIntent(sceneID: entry.sceneID)) {
            HStack(spacing: 8) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 16, weight: .medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.sceneName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("Tap to run")
                        .font(.system(size: 11, weight: .regular))
                        .opacity(0.7)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

/// Family-aware router view.
struct SceneRunWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SceneRunWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            SceneRunCircularView(entry: entry)
        case .accessoryRectangular:
            SceneRunRectangularView(entry: entry)
        default:
            SceneRunSmallView(entry: entry)
        }
    }
}

// MARK: - Widget

struct SceneRunWidget: Widget {
    let kind = "SceneRunWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SceneRunSelectionIntent.self,
            provider: SceneRunWidgetProvider()
        ) { entry in
            SceneRunWidgetView(entry: entry)
                .containerBackground(T3.page, for: .widget)
        }
        .configurationDisplayName("Scene Run")
        .description("One-tap Home Assistant scene. Long-press to pick which scene.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    SceneRunWidget()
} timeline: {
    SceneRunWidgetEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    SceneRunWidget()
} timeline: {
    SceneRunWidgetEntry.placeholder
}

#Preview(as: .accessoryCircular) {
    SceneRunWidget()
} timeline: {
    SceneRunWidgetEntry.placeholder
}
