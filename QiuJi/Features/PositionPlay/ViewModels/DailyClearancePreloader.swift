import SceneKit

/// One unused scene, transferred exclusively to the next daily entry. No game or display loop.
@MainActor
final class DailyClearancePreloader {
    static let shared = DailyClearancePreloader()

    struct Appearance: Equatable {
        let room: RoomStyle
        let table: TableStyle
        let cloth: ClothColor
        let sights: Bool
        let balls: BallStickerStyle
        let cue: CueStyle

        @MainActor static var current: Self {
            let preferences = UserPreferences.shared
            return Self(room: preferences.roomStyle, table: preferences.tableStyle,
                        cloth: preferences.clothColor, sights: preferences.showsTableSights,
                        balls: preferences.ballStickerStyle, cue: preferences.cueStyle)
        }
    }

    /// The worker exclusively owns this graph until its task completes. After delivery,
    /// only the consuming page can mutate it. The renderer prepares resources but never plays.
    struct Prepared {
        let scene: AngleTrainingScene
        let markers: [SCNNode]
        let renderer: SCNRenderer
        let appearance: Appearance
    }

    private var cached: Prepared?
    private var pending: (id: UUID, task: Task<Prepared?, Never>)?
    private var consumers: Set<UUID> = []
    private var suspended = false
    var isReady: Bool { cached != nil }

    func warmUp() {
        guard consumers.isEmpty, !suspended else { return }
        startIfNeeded()
    }

    func setForeground(_ foreground: Bool) {
        suspended = !foreground
        if foreground { warmUp() }
        else { discard() }
    }

    func discard() {
        pending?.task.cancel()
        pending = nil
        cached = nil
    }

    func release(_ owner: UUID) {
        consumers.remove(owner)
        warmUp()
    }

    func acquire(for owner: UUID) async -> PositionPlayViewModel? {
        consumers.insert(owner)
        let start = CACurrentMediaTime()
        while !Task.isCancelled && !suspended && consumers.contains(owner) {
            if let prepared = cached, prepared.appearance == .current {
                cached = nil
                #if DEBUG
                print("[DailyPreload] acquired waitMs=\((CACurrentMediaTime() - start) * 1000)")
                #endif
                return PositionPlayViewModel(preparedDailyScene: prepared)
            }
            startIfNeeded()
            guard let work = pending else { return nil }
            let prepared = await work.task.value
            finish(id: work.id, prepared: prepared)
        }
        return nil
    }

    private func startIfNeeded() {
        let appearance = Appearance.current
        if cached?.appearance != appearance { cached = nil }
        guard cached == nil, pending == nil else { return }
        let id = UUID()
        let task = Task.detached(priority: .utility) { () -> Prepared? in
            autoreleasepool {
                let start = CACurrentMediaTime()
                TableModelLoader.preloadModel()
                TableModelLoader.preloadPocketRegions()
                guard !Task.isCancelled else { return nil }
                let scene = AngleTrainingScene()
                scene.configureDailyClearanceRendering()
                scene.applyTableStyle(appearance.table, showsSights: appearance.sights)
                scene.applyClothColor(appearance.cloth)
                scene.setupScene(roomStyle: appearance.room)
                guard !Task.isCancelled else { return nil }
                scene.setupVisualizationNodes()
                let markers = scene.addPocketMarkers()
                scene.hideAllBalls()
                scene.hideCueStick()
                scene.applyBallStickerStyle(appearance.balls)
                scene.cueStick?.applyStyle(appearance.cue)
                let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
                renderer.scene = scene
                renderer.isPlaying = false
                let prepared = renderer.prepare(scene, shouldAbortBlock: { Task.isCancelled })
                guard !Task.isCancelled else { return nil }
                if !prepared { print("[DailyPreload] GPU preparation incomplete; scene will prepare on display") }
                #if DEBUG
                print("[DailyPreload] ready buildMs=\((CACurrentMediaTime() - start) * 1000) stages=\(scene.setupTiming)")
                #endif
                return Prepared(scene: scene, markers: markers, renderer: renderer, appearance: appearance)
            }
        }
        pending = (id, task)
        Task { [weak self] in
            let prepared = await task.value
            self?.finish(id: id, prepared: prepared)
        }
    }

    private func finish(id: UUID, prepared: Prepared?) {
        // A background/memory release must not be undone by a late worker completion.
        guard pending?.id == id else { return }
        pending = nil
        cached = suspended ? nil : prepared
    }
}
