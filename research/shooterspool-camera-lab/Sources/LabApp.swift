import SwiftUI
import SwiftData

@main
struct ShotCameraLabApp: App {
    private let store = ModelContainerFactory.makeInMemoryContainer()
    var body: some Scene {
        WindowGroup {
            LabHome()
                .environmentObject(SubscriptionManager.shared)
                .environmentObject(CurrentOwnerContext.shared)
                .modelContainer(store)
                .preferredColorScheme(.dark)
        }
    }
}

enum LabLayout: String, CaseIterable, Identifiable {
    case open = "普通散局", rail = "贴库薄球", rack = "中八开球"
    var id: Self { self }
    @MainActor func prepare() {
        let store = DailyClearanceStore()
        var draft = store.makeDraft(game: .chineseEightBall, seed: 816)
        if self != .rack {
            let cue = PositionPlayBall.cueKey
            let points: [String: CGPoint] = self == .rail
                ? [cue: CGPoint(x: 0.16, y: 0.19), "_1": CGPoint(x: 0.66, y: 0.022),
                   "_8": CGPoint(x: 0.82, y: 0.37)]
                : [cue: CGPoint(x: 0.72, y: 0.31), "_1": CGPoint(x: 0.33, y: 0.17),
                   "_2": CGPoint(x: 0.49, y: 0.34), "_9": CGPoint(x: 0.78, y: 0.12),
                   "_8": CGPoint(x: 0.21, y: 0.35)]
            draft.phase = .playing
            draft.firstBreakAt = Date()
            draft.board = BoardSnapshot(onTable: points.mapValues { CanvasPoint(x: $0.x, y: $0.y) })
        }
        // This app has a separate defaults domain. Entering a fixture always starts a new trial.
        UserDefaults.standard.removeObject(forKey: DailyClearanceStoreKey.latestCompletion)
        store.saveDraft(draft)
        TablePreferencesStore.shared.apply(.view3D, value: 1, to: .dailyClearance)
    }
}

struct LabHome: View {
    @State private var path: [LabLayout] = []
    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 20) {
                Text("球迹视角研究").font(.title.bold())
                HStack(spacing: 16) {
                    ForEach(LabLayout.allCases) { layout in
                        Button(layout.rawValue) { layout.prepare(); path.append(layout) }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("lab." + String(describing: layout))
                    }
                }
                Text("进袋时横滑看球，拨方向尺后横滑调杆。点眼睛看全桌，再点回到原位。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .navigationDestination(for: LabLayout.self) { _ in FreePlayView(entryMode: .dailyClearance) }
        }
    }
}
