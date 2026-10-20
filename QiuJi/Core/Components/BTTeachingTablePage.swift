import SwiftUI
import SceneKit

/// Business actions supplied by solver/planning pages; the table layout and camera remain shared.
struct BTTablePlanningControls {
    var spinX: Binding<Double>
    var spinY: Binding<Double>
    var transparency: Binding<Double>
    var hides3DAssists: Binding<Bool>? = nil
    var velocityRange: ClosedRange<Double> = ShotTuning.velocityRange
    var instrumentsEnabled: Bool
    var showsSpinSlot: Bool = true
    /// Assessment pages expose a fixed contact point and no answer assists.
    var assessmentMode = false
    var isAnimating: Bool
    var paletteEnabled: Bool
    var allowsPocketSelection: Bool = true
    var primaryTitle: String
    var primaryEnabled: Bool
    var onPrimary: () -> Void
    var primaryControlID: String = "shot.strike"
    var onPaletteTap: (String) -> Void
    var menuItems: [DailyHUDMenuItem]
    var refreshTrajectory: () -> Void
    var applyPreferences: (TablePreferenceSnapshot) -> Void = { _ in }
    var onSetup: () -> Void = {}
    var onDisappear: () -> Void = {}
    /// Page-owned gestures/confirmation phases outside the scene's drag lifecycle.
    var layoutEditingBlocked = false
    var onAimNudged: ((Float) -> Void)? = nil
    var onAimDragActiveChanged: ((Bool) -> Void)? = nil
    var onObservation: ((String) -> Void)? = nil
    var closeupSnapshot: AimCloseupSnapshot? = nil
    var closeupUnavailableReason: String? = nil
    /// One physical contact point must reach the host as one complete intent.
    var onSpinChange: ((Double, Double) -> Void)? = nil
    var overlay: (TableProjector, CGRect) -> AnyView = { _, _ in AnyView(EmptyView()) }
}

/// Common daily-template shell for editable teaching tables. Hosts provide only
/// their title, teaching controls, status and optional cue-speed binding.
struct BTTeachingTablePage<Host: TeachingTableHost, Title: View, Left: View, Status: View>: View {
    @ObservedObject var vm: Host
    let titleLabel: String
    let identifier: String
    let preferencePage: TablePreferencePage
    /// Entry identity can fix the presentation independently of general preferences.
    var fixedView3D: Bool? = nil
    var velocity: Binding<Double>? = nil
    /// Optional vertical-only spin control for the side-spin atlas.
    var spinHeight: Binding<Double>? = nil
    var showsDisabledSpinEntry: Bool = false
    var planning: BTTablePlanningControls? = nil
    var leftControlGroup: ControlLayoutGroup = .planning
    var layoutEditingBlocked = false
    /// Page-owned display options; empty for all existing consumers.
    var displayMenuItems: [DailyHUDMenuItem] = []
    /// Opt-in migration: notices and persistent teaching readouts retain distinct lifetimes.
    var information: [BTTeachingInformation]? = nil
    var usesStandardTitle = false
    var onPocketOrientationChange: (PocketDisplay.Orientation) -> Void = { _ in }
    /// Paired instrument hosts receive the same dimensions and top anchor as the power column.
    var pairedLeftContent: ((BTTeachingInstrumentLayout) -> AnyView)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var spinTouchActive = false
    @State private var aimTouchActive = false
    @State private var powerTouchActive = false
    @State private var protectedCloseupFrames: [CGRect] = []
    @State private var showSpinPad = false
    @ObservedObject private var freeControlLayouts = FreeControlLayoutStore.shared
    private var preservesPersonalControlLayout: Bool {
        preferencePage.usesFreeControlLayout && (editingControlLayout ||
            !freeControlLayouts.values(page: preferencePage, mode: is3D ? .threeD : .twoD).isEmpty)
    }
    @State private var editingControlLayout = false
    @State private var scenePausedBeforeLayout = false
    @State private var layoutAimDragging = false
    @AccessibilityFocusState private var moreFocused: Bool
    private var controlLayoutBusy: Bool {
        layoutEditingBlocked || planning?.isAnimating == true || planning?.layoutEditingBlocked == true
        || vm.temporaryTopDownActive || vm.cameraTransitionBusy || vm.isDragging
        || aimTouchActive || powerTouchActive || spinTouchActive || layoutAimDragging || draggingKey != nil
    }
    @Environment(\.displayScale) private var displayScale
    @ViewBuilder var title: () -> Title
    @ViewBuilder var leftContent: (CGSize) -> Left
    @ViewBuilder var status: () -> Status
    var onPalettePlace: ((String, SCNVector3) -> Void)? = nil
    private var allowsPaletteDrag: Bool { onPalettePlace != nil }
    @State private var projector = TableProjector()
    @State private var sceneFrame = CGRect.zero
    @State private var paletteFrame = CGRect.zero
    @State private var draggingKey: String?
    @State private var dragLocation = CGPoint.zero
    @State private var dragOverTable = false
    var onFirstDrag: () -> Void = {}
    @State private var cameraStackHeight: CGFloat = 188
    private var is3D: Bool { vm.cameraMode == .perspective3D }
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var preferences = UserPreferences.shared
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    private var pagePreferences: TablePreferenceSnapshot { tablePreferences.snapshot(for: preferencePage) }
    private func setPagePreference(_ field: TablePreferenceField, _ value: Double) {
        tablePreferences.apply(field, value: value, to: preferencePage)
        applyPagePreferences()
    }
    private func applyPagePreferences() {
        guard hasAppeared, !editingControlLayout, planning?.isAnimating != true, !vm.temporaryTopDownActive, !vm.isDragging else { return }
        let next = pagePreferences
        let previous = vm.scene.tablePreferences
        vm.scene.tablePreferencePage = preferencePage
        vm.scene.tablePreferences = next
        if previous?.enabled(.view3D) != next.enabled(.view3D) {
            vm.setCameraMode((fixedView3D ?? next.enabled(.view3D)) ? .perspective3D : (portrait ? .topDown2DRotated : .topDown2D))
        }
        vm.scene.setTableGridVisible(next.enabled(.grid))
        planning?.applyPreferences(next)
        if previous?.trajectoryDetail != next.trajectoryDetail || previous?.enabled(.separation) != next.enabled(.separation) {
            planning?.refreshTrajectory()
        }
    }
    @State private var hasAppeared = false
    @StateObject private var fps = TableFPSReadoutState()
    @State private var portrait = false
    @State private var windowControls = UIEdgeInsets.zero
    @State private var windowSafeArea = UIEdgeInsets.zero
    @State private var systemStatusVisible = false
    @State private var menu: MenuPage?
    @State private var titleSize = CGSize(width: 60, height: 34)
    private enum MenuPage { case settings, transparency, trajectory }
    @State private var cameraReadableFrame: CGRect?
    private let paletteKeys = PositionPlayBall.allKeys.filter { !PositionPlayBall.isCue($0) }

    var body: some View {
        GeometryReader { geo in
            let extraTop = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.top - geo.safeAreaInsets.top) : 0
            let extraBottom = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.bottom - geo.safeAreaInsets.bottom) : 0
            let size = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: max(0, geo.size.height - extraTop - extraBottom))
            ZStack(alignment: .topLeading) {
            template(size: size, safe: max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing))
                .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
                .padding(.top, extraTop).padding(.bottom, extraBottom)
                .offset(x: -geo.safeAreaInsets.leading)
                .ignoresSafeArea(.container, edges: .trailing)
                if let draggingKey {
                    BTBallPaletteDragGhost(key: draggingKey, location: dragLocation, overTable: dragOverTable,
                        placement: projector.palettePreview, projector: projector)
                }
            }.frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .coordinateSpace(name: identifier)
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let frame = frames["scene"] { sceneFrame = frame }
            if let frame = frames["palette"] { paletteFrame = frame }
        }
        .background { DailyTableOrientation(landscape: true, allowsTabletRotation: true) }
        .trainingBackgroundMusic()
        .btDarkToolChrome(titleLabel)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(UIDevice.current.userInterfaceIdiom != .pad)
        .preference(key: TrainingActivityPausedKey.self, value: editingControlLayout)
        .onChange(of: editingControlLayout) { _, editing in
            if editing {
                scenePausedBeforeLayout = vm.scene.isPaused
                vm.scene.isPaused = true
            } else {
                vm.scene.isPaused = scenePausedBeforeLayout
                moreFocused = true
                if scenePhase == .active { applyPagePreferences() }
            }
        }
        .onAppear {
            if !editingControlLayout { vm.resumeTeachingActivity() }
            guard !hasAppeared else { applyPagePreferences(); return }
            hasAppeared = true
            vm.scene.tablePreferencePage = preferencePage
            vm.scene.tablePreferences = pagePreferences
            vm.setupScene()
            planning?.onSetup()
            vm.setCameraMode((fixedView3D ?? pagePreferences.enabled(.view3D)) ? .perspective3D : (portrait ? .topDown2DRotated : .topDown2D))
            applyPagePreferences()
            updateProjection()
        }
        .onChange(of: scenePhase) { _, phase in
            // The idle editor owns a paused scene. Do not call planning.onDisappear:
            // that callback cancels solver/playback work and belongs to a real exit.
            if !editingControlLayout {
                if phase == .active { vm.resumeTeachingActivity(); applyPagePreferences() }
                else { suspendActivity() }
            }
        }
        .onChange(of: tablePreferences.revision) { _, _ in applyPagePreferences() }
        .onChange(of: planning?.isAnimating) { _, busy in if busy != true { applyPagePreferences() } }
        .onChange(of: vm.temporaryTopDownActive) { _, active in if !active { applyPagePreferences() } }
        .onChange(of: vm.isDragging) { _, active in if !active { applyPagePreferences() } }
        .onDisappear {
            if editingControlLayout { vm.scene.isPaused = scenePausedBeforeLayout }
            suspendActivity()
        }
        .onPreferenceChange(BTCloseupProtectedFramesKey.self) { protectedCloseupFrames = $0 }
    }

    private func suspendActivity() {
        aimTouchActive = false
        powerTouchActive = false
        layoutAimDragging = false
        draggingKey = nil
        vm.endTemporaryTopDown()
        vm.cameraTransitionBusy = false
        planning?.onDisappear()
        vm.suspendTeachingActivity()
    }

    private func template(size: CGSize, safe: CGFloat) -> some View {
        let side = max(4, safe)
        let titleWidth: CGFloat = usesStandardTitle ? 60 : max(60, titleSize.width)
        let reservation = DailyLayoutMetrics.FoundationReservation(width: size.width - 2 * side,
            targetCount: paletteKeys.count, chineseEightBall: true,
            titleWidth: 32 + titleWidth, actionWidth: 138,
            prefersSeparateRow: size.height > size.width || size.height >= 600,
            separateWidth: size.width > size.height && size.height < 600 ? size.width - 2 * (side + 60 + 8) : nil)
        let f = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: safe, trailingSafeArea: safe,
            halfLength: vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength,
            halfWidth: vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth,
            instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight, palette: reservation)
        let plan = DailyLayoutMetrics.Palette(size: size, sideInset: side, table: f.table,
            targetCount: paletteKeys.count, chineseEightBall: true, obstacles: [
                CGRect(x: side + windowControls.left, y: 0, width: 44, height: 44),
                CGRect(x: side + windowControls.left + 32, y: (44 - titleSize.height) / 2, width: titleWidth, height: titleSize.height),
                CGRect(x: size.width - side - windowControls.right - 44, y: 0, width: 44, height: 44), f.left, f.right])
        let pointsPerMetre = f.table.height / CGFloat(2 * (f.rotated
            ? (vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength)
            : (vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth)))
        let instruments = BTTeachingInstrumentLayout(foundation: f)
        let layout = BTTeachingPageLayout(stageSize: f.stage.size, rotated: f.rotated,
            pointsPerMetre: pointsPerMetre, instruments: instruments, spinPadPresented: showSpinPad,
            displayScale: displayScale, spinPadMaximumExtent: UIDevice.current.userInterfaceIdiom == .pad ? 310 : .greatestFiniteMagnitude)
        let compactTitle = plan.diameter < DailyLayoutMetrics.regularBallDiameter
        let primaryEnabled = BTTeachingInstrumentLayout.effectiveEnabled(
            planning?.primaryEnabled == true, temporaryTopDownActive: vm.temporaryTopDownActive)
        return ZStack(alignment: .topLeading) {
            if let planning {
                planning.overlay(projector, sceneFrame)
                    .frame(width: f.stage.width, height: f.stage.height)
                    .position(x: f.stage.midX, y: f.stage.midY)
            }
            DailyTemplateHeader(size: size, safe: safe, foundation: f, plan: plan,
                targets: paletteKeys, chineseEightBall: true, titleWidth: titleWidth, titleHeight: usesStandardTitle ? 34 : titleSize.height,
                windowControlInsets: windowControls, fps: fps, showsDeviceStatus: !systemStatusVisible, keepsPaletteVisible: preservesPersonalControlLayout,
                title: { navigationTitle(compact: compactTitle) }, actions: {
                    Button { showSpinPad = false; menu = .settings } label: {
                        Image(systemName: BTIcon.menuCircle).font(.system(size: 22, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: Circle()) }
                    }.overlay(Circle().strokeBorder(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth).allowsHitTesting(false))
                    .accessibilityLabel("更多").accessibilityIdentifier("\(identifier).more")
                    .accessibilityFocused($moreFocused)
                }, ball: { key, diameter, height in ballToken(key, diameter: diameter, slotHeight: height) },
                paletteMarker: { frameReader("palette") })
                .background(DailyWindowControlInsets { controls, window, visible in
                    windowControls = controls; windowSafeArea = window; systemStatusVisible = visible
                }.allowsHitTesting(false))
            if let pairedLeftContent {
                pairedLeftContent(instruments)
                    .environment(\.teachingInstrumentActivity, { aimTouchActive = $0 })
                    .controlLayoutGroup(.direction)
                    .frame(width: f.left.width, height: f.left.height, alignment: .top)
                    .position(x: f.left.midX, y: f.left.midY)
            } else {
                leftContent(CGSize(width: f.left.width, height: min(420, size.height - max(44, f.stage.minY))))
                    .frame(width: f.left.width)
                    .controlLayoutGroup(leftControlGroup)
                    .position(x: f.left.midX, y: f.table.midY)
            }
            if let velocity {
                VStack(spacing: 4) {
                    powerColumn(velocity: velocity, foundation: f)
                        .controlLayoutGroup(.instrument)
                    if let planning {
                        Button { showSpinPad = false; planning.onPrimary() } label: {
                            Text(planning.primaryTitle).font(.btSubheadlineSemibold)
                                .frame(width: instruments.strikeDiameter, height: instruments.strikeDiameter)
                        }.buttonStyle(DailyStrikeButtonStyle())
                            .disabled(!primaryEnabled)
                            .opacity(primaryEnabled ? 1 : 0.3)
                            .accessibilityIdentifier(identifier + ".strike")
                            .freeControlItem(planning.primaryControlID, name: planning.primaryTitle)
                            .controlLayoutGroup(.primary)
                    }
                }
                .frame(width: f.right.width, height: f.right.height, alignment: .top)
                .position(x: f.right.midX, y: f.right.midY)
            } else if is3D {
                cameraButtons.controlLayoutGroup(.camera).position(x: f.right.midX, y: f.table.midY)
            }
            // The camera viewport exists even when there is no information to show.
            // An empty conditional Group emits no geometry preference and would
            // incorrectly hide the 2D scene when the final notice disappears.
            ZStack {
                Color.clear.allowsHitTesting(false)
                if let information {
                    BTTeachingInformationLayer(items: information)
                } else {
                    status()
                }
            }
                .frame(width: f.stage.width, height: f.stage.height)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: TeachingCameraFrame.self, value: proxy.frame(in: .global))
                })
                .position(x: f.stage.midX, y: f.stage.midY)
            // A solved contact supplies geometry, not permission to keep the loupe visible.
            // Only the direction ruler's live gesture may reveal it; spin/power and idle must not.
            if planning?.assessmentMode != true, aimTouchActive, !showSpinPad, menu == nil,
               let snapshot = planning?.closeupSnapshot, !vm.temporaryTopDownActive {
                GeometryReader { proxy in
                    let inner = CGSize(
                        width: CGFloat(f.rotated ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength) * pointsPerMetre,
                        height: CGFloat(f.rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * pointsPerMetre)
                    BTAimCloseupOverlay(snapshot: snapshot, sceneSize: f.stage.size, scene: vm.scene,
                        safeInsets: .init(top: 0, leading: 0, bottom: 28, trailing: 0),
                        blockedSide: nil, protectsDailySight: true, frameInWindow: proxy.frame(in: .global),
                        placementBounds: CGRect(x: (f.stage.width - inner.width) / 2, y: (f.stage.height - inner.height) / 2,
                            width: inner.width, height: inner.height), protectedFramesInWindow: protectedCloseupFrames)
                }.frame(width: f.stage.width, height: f.stage.height).position(x: f.stage.midX, y: f.stage.midY)
            }
            if showSpinPad, spinHeight != nil || planning != nil {
                teachingSpinPad(spinHeight ?? planning!.spinY, foundation: f, pointsPerMetre: pointsPerMetre)
            }
            if !plan.fits && !preservesPersonalControlLayout {
                Text("扩大窗口后继续摆球").font(.btFootnote).padding()
                    .background(.regularMaterial, in: Capsule())
                    .position(x: size.width / 2, y: size.height / 2)
            }
            if menu != nil {
                Button { self.menu = nil } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("关闭菜单")
                    .accessibilityIdentifier("\(identifier).dismissMenu")
                Group {
                    if menu == .transparency, let planning {
                        DailySpinTransparencyPanel(transparency: planning.transparency,
                            availableSize: CGSize(width: size.width - 2 * (side + windowControls.right), height: size.height - DailyLayoutMetrics.Panels.top - 8),
                            onClose: { menu = nil })
                    } else {
                        DailyHUDMenuPanel(title: menu == .trajectory ? "轨迹显示" : nil, items: settingsItems,
                            availableSize: CGSize(width: size.width - 2 * (side + windowControls.right), height: size.height - DailyLayoutMetrics.Panels.top - 8),
                            onBack: { self.menu = .settings }, onClose: { self.menu = nil })
                    }
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, DailyLayoutMetrics.Panels.top).padding(.trailing, side + windowControls.right)
            }
        }
        .frame(width: size.width, height: size.height)
        .controlLayoutHost(page: preferencePage, mode: is3D ? .threeD : .twoD, size: size,
            leading: f.left, trailing: f.right, defaultFits: f.fits && plan.fits,
            obstacles: plan.controlLayoutProtectionFrames(table: f.table),
            busy: controlLayoutBusy, editing: $editingControlLayout, rulerHeight: instruments.rulerLength,
            primaryTitle: planning?.primaryTitle ?? "击球", editorToolbarTop: f.table.minY)
        .background {
            GeometryReader { viewport in
                let fullFrame = viewport.frame(in: .global)
                let renderFrame = is3D ? fullFrame : (cameraReadableFrame ?? fullFrame)
                sceneFullscreen.frame(width: renderFrame.width, height: renderFrame.height)
                    .position(x: renderFrame.midX - fullFrame.minX, y: renderFrame.midY - fullFrame.minY)
                    .opacity((preferencePage.usesFreeControlLayout || !editingControlLayout) && (is3D || cameraReadableFrame != nil) ? 1 : 0)
                    .allowsHitTesting(menu == nil && !editingControlLayout)
                    .accessibilityHidden(editingControlLayout)
            }.ignoresSafeArea()
        }
        .background { DailyCarpetBackground(style: preferences.roomStyle, pointsPerMetre: pointsPerMetre).ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .environment(\.dailyHUDControls, true)
        .environment(\.teachingTableLayout, layout)
        .onChange(of: size.height > size.width, initial: true) { _, value in
            portrait = value; updateProjection()
            onPocketOrientationChange(.init(portrait: value))
        }
        .onChange(of: size) { _, _ in menu = nil; showSpinPad = false }
        .onChange(of: vm.temporaryTopDownActive) { _, active in if active { showSpinPad = false } }
        .onPreferenceChange(TeachingCameraFrame.self) { cameraReadableFrame = $0 }
        .background(Color.clear.accessibilityElement().accessibilityIdentifier("\(identifier).template"))
    }

    private func navigationTitle(compact: Bool) -> some View {
        HStack(spacing: -12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.accessibilityLabel("返回").accessibilityIdentifier("\(identifier).back")
            Group {
                if usesStandardTitle {
                    BTTablePageTitle(titleLabel, width: 60, compact: compact)
                } else {
                    title()
                }
            }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(titleLabel)
                .background(GeometryReader { g in Color.clear.preference(key: TeachingTitleSize.self, value: g.size) })
        }.fixedSize(horizontal: true, vertical: false)
            .onPreferenceChange(TeachingTitleSize.self) { titleSize = $0 }
    }

    private func updateProjection() {
        vm.scene.pocketDisplayOrientation = .init(portrait: portrait)
        guard !is3D else { return }
        vm.cameraMode = portrait ? .topDown2DRotated : .topDown2D
        vm.scene.setCameraMode(vm.cameraMode, animated: false)
    }

    private func toggleCamera() {
        showSpinPad = false
        setPagePreference(.view3D, is3D ? 0 : 1)
    }

    private var settingsItems: [DailyHUDMenuItem] {
        if menu == .trajectory, let planning {
            var items: [DailyHUDMenuItem] = []
            if is3D, let hidden = planning.hides3DAssists {
                items.append(.init(id: identifier + ".trajectory.off", title: "关闭", selected: hidden.wrappedValue,
                    action: { setPagePreference(.shows3DTrajectory, 0) }))
            }
            items += TrajectoryDetail.allCases.map { detail in
                DailyHUDMenuItem(id: identifier + ".trajectory.\(detail.rawValue)", title: detail.label,
                    selected: pagePreferences.trajectoryDetail == detail && !(is3D && planning.hides3DAssists?.wrappedValue == true), action: {
                        setPagePreference(.trajectory, Double(detail.rawValue))
                    })
            }
            return items
        }
        var items: [DailyHUDMenuItem] = [.init(id: "\(identifier).display", title: "显示"),
         .init(id: "\(identifier).cameraMode", title: "视图", detail: is3D ? "3D" : "2D",
               segments: ["2D", "3D"], disabled: vm.temporaryTopDownActive, action: toggleCamera),
         .init(id: "menu.tableGrid", title: "台面网格 4×8", selected: pagePreferences.enabled(.grid), action: {
             setPagePreference(.grid, pagePreferences.enabled(.grid) ? 0 : 1)
         })]
        if fixedView3D != nil { items.removeAll { $0.id == "\(identifier).cameraMode" } }
        if let planning {
            if !planning.assessmentMode {
            items.insert(.init(id: identifier + ".transparency", title: "打点盘透明度",
                detail: "\(Int((planning.transparency.wrappedValue * 100).rounded()))%", disclosure: true, action: { showSpinPad = true; menu = .transparency }), at: 2)
            items.append(.init(id: "menu.aimCloseup", title: "瞄准特写", detail: planning.closeupUnavailableReason, selected: pagePreferences.enabled(.closeup),
                disabled: planning.closeupUnavailableReason != nil,
                action: { setPagePreference(.closeup, pagePreferences.enabled(.closeup) ? 0 : 1) }))
            items.append(.init(id: identifier + ".trajectory", title: "轨迹显示 · " + (is3D && planning.hides3DAssists?.wrappedValue == true ? "关闭" : pagePreferences.trajectoryDetail.label),
                disclosure: true, action: { menu = .trajectory }))
            items += [TablePreferenceField.separation, .rehearsal].map { field in
                DailyHUDMenuItem(id: identifier + "." + field.rawValue, title: field.title,
                    selected: pagePreferences.enabled(field), action: {
                        setPagePreference(field, pagePreferences.enabled(field) ? 0 : 1)
                    })
            }
            }
            items += planning.menuItems.map { item in
                var closingItem = item
                if item.selected == nil, item.segments.isEmpty, let action = item.action {
                    closingItem.action = { menu = nil; action() }
                }
                return closingItem
            }
        }
        items += displayMenuItems.map { item in
            var closingItem = item
            if item.selected == nil, item.segments.isEmpty, let action = item.action {
                closingItem.action = { menu = nil; action() }
            }
            return closingItem
        }
        if preferencePage.usesFreeControlLayout && !FreeControlCatalog.ids(page: preferencePage, mode: is3D ? .threeD : .twoD).isEmpty {
            items.insert(.init(id: "controlLayout.open", title: "操作布局",
                detail: controlLayoutBusy ? "请先完成当前操作" : nil, disclosure: true,
                disabled: controlLayoutBusy, action: {
                    guard !controlLayoutBusy else { return }
                    menu = nil; showSpinPad = false; editingControlLayout = true
                }), at: min(5, items.count))
        }
        return items
    }

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            pocketDisplayOrientation: .init(portrait: portrait),
            interactionMode: is3D ? .cameraControl : .tapsOnly,
            // Core-template fitting also handles rotated 2D; the legacy rotated
            // fitter imposes an extra minimum scale and detaches the palette from the rail.
            autoFitsLandscapeTable: !is3D,
            backgroundColor: is3D ? .black : .clear,
            onPocketTapped: planning?.allowsPocketSelection == false ? nil : { index in vm.selectPocket(at: index) },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { node in
                onFirstDrag()
                vm.dragBegan(node: node)
            },
            onDragMoved: { node, pos in vm.dragMoved(node: node, worldPosition: pos) },
            onDragEnded: { node in vm.dragEnded(node: node) },
            onDragEndedAt: { node, localPoint in
                guard allowsPaletteDrag,
                      BTBallPaletteDragBack.hitPalette(localPoint: localPoint, sceneFrame: sceneFrame, paletteFrame: paletteFrame),
                      let key = vm.scene.ballKey(for: node) else { return }
                vm.removeFromTable(key)
            },
            selectableBallNodes: vm.selectableBalls + (is3D ? [vm.scene.cueBallNode].compactMap { $0 } : []),
            onBallTapped: { node in
                if let key = vm.scene.ballKey(for: node) {
                    if PositionPlayBall.isCue(key) { vm.requestPlayerView(.thirdPerson) }
                    else { vm.selectTarget(key: key) }
                }
            },
            onAimNudged: planning?.onAimNudged,
            onAimDragActiveChanged: { active in
                layoutAimDragging = active
                planning?.onAimDragActiveChanged?(active)
            },
            projector: projector,
            contentIsAnimating: spinTouchActive || aimTouchActive || powerTouchActive || vm.isDragging || vm.cameraTransitionBusy || planning?.isAnimating == true,
            fpsReadoutState: fps,
            twoViewReadableFrameInWindow: cameraReadableFrame,
            onCameraObservationBegan: { vm.beginCameraObservation() },
            onCameraObservationEnded: { vm.endCameraObservation() },
            onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },
            topDownContentRevision: vm.topDownContentRevision,
            usesStandardTemporaryTable: planning != nil
        )
        .clipped()
        .background(frameReader("scene"))
    }

    @ViewBuilder private var cameraButtons: some View {
        if let rig = vm.scene.cameraRig {
            ShotPlayerCameraButtons(controlSpacing: 4, rig: rig,
                isEnabled: vm.temporaryTopDownActive || (planning.map { !$0.isAnimating } ?? (vm.currentPlayerAim != nil)),
                onWholeTable: { planning?.onObservation?("wholeTable"); vm.requestSurfaceOverview() }, usesTwoViewControls: rig.usesTwoViewCameraControls,
                temporaryTopDownActive: vm.temporaryTopDownActive,
                onTemporaryTopDownBegan: { vm.beginTemporaryTopDown() },
                onTemporaryTopDownEnded: { vm.endTemporaryTopDown() },
                onSelect: { vm.requestPlayerView($0) })
        }
    }

    private func powerColumn(velocity: Binding<Double>, foundation f: DailyLayoutMetrics.Foundation) -> some View {
        // Measure the actual native instrument, not the reserved 60pt column.
        // Keep a >=44pt power target and the original camera's absolute centre.
        let instrumentWidth = max(CGFloat(44), f.topDiameter)
        var cameraColumn = f.right
        cameraColumn.size.width = instrumentWidth
        return BTShotInstrumentColumn(spinX: planning?.spinX.wrappedValue ?? 0, spinY: planning?.spinY.wrappedValue ?? spinHeight?.wrappedValue ?? 0,
            onSpinTap: (spinHeight == nil && planning == nil) || planning?.showsSpinSlot == false ? nil : { showSpinPad = true },
            showsDisabledSpinEntry: showsDisabledSpinEntry, velocity: velocity,
            range: planning?.velocityRange ?? ShotTuning.velocityRange,
            isDisabled: !BTTeachingInstrumentLayout.effectiveEnabled(planning?.instrumentsEnabled ?? true,
                temporaryTopDownActive: vm.temporaryTopDownActive),
            spinTapEnabled: !vm.temporaryTopDownActive,
            onPowerDragBegan: { powerTouchActive = true }, onPowerDragEnded: { _ in powerTouchActive = false },
            fixedPowerBarHeight: f.rulerLength,
            powerLabel: "杆速", compactPowerBarWidth: DailyLayoutMetrics.rulerWidth,
            compactSpinButtonDiameter: f.topDiameter, compactGroupSpacing: Spacing.xs,
            reportsPowerShellBounds: true)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("solver.power")
            .accessibilityLabel("杆速")
            .accessibilityValue(String(format: "%.2f", velocity.wrappedValue))
            .frame(width: instrumentWidth)
            .overlayPreferenceValue(BTPowerShellBoundsKey.self) { bounds in
                GeometryReader { proxy in
                    if is3D, let bounds {
                        cameraButtons
                            .background(GeometryReader { measure in
                                Color.clear.preference(key: TeachingCameraHeight.self, value: measure.size.height)
                            })
                            .controlLayoutGroup(.camera, anchorMotion: .instrument)
                            .offset(DailyLayoutMetrics.CameraLane(column: cameraColumn, rulerHeight: f.rulerLength,
                                powerShell: proxy[bounds], stackHeight: cameraStackHeight).offset)
                    }
                }
            }
            .onPreferenceChange(TeachingCameraHeight.self) { if $0 > 0 { cameraStackHeight = $0 } }
    }

    private func teachingSpinPad(_ height: Binding<Double>, foundation f: DailyLayoutMetrics.Foundation,
                                 pointsPerMetre: CGFloat) -> some View {
        // Same unzoomed inner-cloth bounds and fixed card sizing as daily.
        let inner = CGRect(x: 0, y: 0,
            width: CGFloat(f.rotated ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength) * pointsPerMetre,
            height: CGFloat(f.rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * pointsPerMetre)
        let layout = DailyLayoutMetrics.SpinPad(playingRect: inner, displayScale: displayScale,
            maximumExtent: UIDevice.current.userInterfaceIdiom == .pad ? 310 : max(inner.width, inner.height))
        return BTSceneSpinPadOverlay(spinX: planning?.spinX ?? .constant(0), spinY: height, scene: vm.scene,
            tableWidth: inner.width, bottomPadding: (f.stage.height - layout.extent) / 2,
            fixedCardExtent: layout.extent, discOpacity: planning.map { 1 - $0.transparency.wrappedValue } ?? 1,
            locksSideSpin: planning == nil,
            isReadOnly: planning?.assessmentMode == true,
            onSpinChange: planning?.onSpinChange,
            onClose: { showSpinPad = false })
            .simultaneousGesture(DragGesture(minimumDistance: 0).updating($spinTouchActive) { _, active, _ in active = true })
            .frame(width: f.stage.width, height: f.stage.height)
            .position(x: f.stage.midX, y: f.stage.midY)
            .accessibilityIdentifier(identifier + ".spinPad")
    }

    /// 球库槽位：在库点击上桌；在桌点击（非母球）撤下回库；当前目标球高亮圈。
    private func ballToken(_ key: String, diameter: CGFloat, slotHeight: CGFloat) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        let selected = vm.selectedTargetKey == key
        return Button {
            if let planning { planning.onPaletteTap(key) }
            else if onTable { vm.removeFromTable(key) } else { vm.placeFromPalette(key) }
        } label: {
            PoolBallFace(key: key, diameter: diameter).opacity(onTable ? 0.3 : 1)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1).padding(-1).opacity(selected ? 1 : 0))
                .frame(width: diameter + 2, height: min(max(32, diameter), slotHeight))
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: key == paletteKeys.first || key == paletteKeys.last ? 16 : 4), selected: selected, normal: .clear) }
                .frame(height: slotHeight).contentShape(Rectangle())
        }
        .buttonStyle(BTHUDPressStyle()).disabled((is3D && planning == nil) || planning?.paletteEnabled == false)
        .simultaneousGesture(DragGesture(minimumDistance: BTBallPaletteMetrics.dragMinimumDistance,
                                        coordinateSpace: .named(identifier))
            .onChanged { value in
                guard allowsPaletteDrag, planning?.paletteEnabled != false, (!is3D || planning != nil), !onTable else { return }
                draggingKey = key
                let preview = BTPalettePlacement.sample(key: key, finger: value.location, sourceDiameter: diameter,
                    sceneFrame: sceneFrame, projector: projector, constrain: vm.palettePlacement)
                dragLocation = preview.location; dragOverTable = preview.isValid
            }.onEnded { value in
                defer { draggingKey = nil; dragOverTable = false }
                guard allowsPaletteDrag, planning?.paletteEnabled != false, (!is3D || planning != nil), !onTable,
                      let world = projector.palettePreview?.requestedWorld else { return }
                onPalettePlace?(key, world)
            }, including: allowsPaletteDrag && (!is3D || planning != nil) && !onTable ? .all : .subviews)
        .accessibilityLabel("\(PositionPlayBall.shortLabel(for: key))号球")
        .accessibilityValue(onTable ? "在桌上" : "未在桌上")
        .accessibilityHint(planning?.assessmentMode == true ? "题目指定，不可更改" :
            (onTable ? (planning == nil ? "点按撤回球库" : "点按定位桌上球，拖回球库可移除") : "点按摆到桌面"))
        .accessibilityIdentifier("paletteBall_\(key)")
    }

    private func frameReader(_ id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                value: [id: proxy.frame(in: .named(identifier))])
        }
    }

}

private struct TeachingTitleSize: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private struct TeachingCameraFrame: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = nextValue() ?? value }
}

private struct TeachingCameraHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Five-character teaching titles share the same two-line words and centred third character.
struct BTTeachingFiveCharacterTitle: View {
    let words: String
    let middleCharacter: String
    let identifier: String

    var body: some View {
        HStack(spacing: 1) {
            Text(words).lineLimit(2).accessibilityIdentifier(identifier + ".titleWords")
            Text(middleCharacter).accessibilityIdentifier(identifier + ".titleConjunction")
        }.font(Font.btFootnote.weight(.semibold))
    }
}

/// Logical-point contract shared by the two instrument columns. The containing
/// page aligns pairedLeftContent and the power column at Foundation.left/right.minY.
struct BTTeachingInstrumentLayout: Equatable {
    let topDiameter: CGFloat
    let rulerLength: CGFloat
    let auxiliarySize: CGFloat
    let horizontalActions: Bool
    var columnWidth: CGFloat { DailyLayoutMetrics.controlColumnWidth }
    var rulerWidth: CGFloat { DailyLayoutMetrics.rulerWidth }
    var groupSpacing: CGFloat { Spacing.xs }
    var strikeDiameter: CGFloat { DailyLayoutMetrics.controlColumnWidth }

    init(foundation: DailyLayoutMetrics.Foundation) {
        topDiameter = foundation.topDiameter
        rulerLength = foundation.rulerLength
        auxiliarySize = foundation.auxiliarySize
        horizontalActions = foundation.horizontalActions
    }

    static func effectiveEnabled(_ enabled: Bool, temporaryTopDownActive: Bool) -> Bool {
        enabled && !temporaryTopDownActive
    }
}

/// A top entry matching the spin button's circle + label ledger. A paired left
/// host should place this immediately before BTTeachingAimRuler with groupSpacing.
struct BTTeachingInstrumentEntry<Content: View>: View {
    let layout: BTTeachingInstrumentLayout
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 2) {
            content().frame(width: layout.topDiameter, height: layout.topDiameter)
            Text(label).font(.btMicro).foregroundStyle(.btTextSecondary)
        }.frame(width: layout.columnWidth)
    }
}

/// Matches the daily direction shell without stretching the effective track to
/// fill its hit target or adding a fake numeric footer opposite the speed readout.
private struct TeachingInstrumentActivityKey: EnvironmentKey {
    static let defaultValue: ((Bool) -> Void)? = nil
}

extension EnvironmentValues {
    var teachingInstrumentActivity: ((Bool) -> Void)? {
        get { self[TeachingInstrumentActivityKey.self] }
        set { self[TeachingInstrumentActivityKey.self] = newValue }
    }
}

struct BTTeachingAimRuler: View {
    @Environment(\.teachingInstrumentActivity) private var reportActivity
    let layout: BTTeachingInstrumentLayout
    var enabled = true
    let onNudge: (Float) -> Void
    var degreesPerPoint: Float = AimWheelGain.defaultDegreesPerPoint
    var onDragActiveChanged: ((Bool) -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            BTAimWheel(onNudge: onNudge, degreesPerPoint: degreesPerPoint,
                degreeHapticEnabled: false, travelHapticEnabled: true,
                onDragActiveChanged: { active in
                    reportActivity?(active)
                    onDragActiveChanged?(active)
                }, visibleWidth: layout.rulerWidth,
                usesCompactAppearance: true, showsDirectionLabel: false)
                .frame(width: 44, height: layout.rulerLength)
            Text("方向").font(.btMicro).foregroundStyle(.btTextSecondary)
        }
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: BTRadius.xl)
                .fill(HUDStyle.controlBackground)
                .overlay(RoundedRectangle(cornerRadius: BTRadius.xl)
                    .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                .frame(width: layout.rulerWidth + 12)
        }
        .frame(width: layout.columnWidth)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .freeControlItem("shot.aim", name: "方向")
    }
}

/// Stage-local points: x right, y down. This reference is derived from the
/// unzoomed 2D table, even while the scene is showing a perspective camera.
struct BTTeachingPageLayout {
    let stageSize: CGSize
    let innerRect: CGRect
    let instruments: BTTeachingInstrumentLayout
    let spinPadPresented: Bool
    let spinPadFrame: CGRect
    /// Persistent teaching data remains readable beside, rather than underneath, the editor.
    var expandedReadoutFrame: CGRect {
        CGRect(x: innerRect.minX + Spacing.md, y: informationTop,
            width: max(1, spinPadFrame.minX - innerRect.minX - 2 * Spacing.md),
            height: max(1, innerRect.height - 2 * Spacing.md))
    }
    var informationTop: CGFloat { innerRect.minY + Spacing.md }

    init(stageSize: CGSize, rotated: Bool, pointsPerMetre: CGFloat,
         instruments: BTTeachingInstrumentLayout, spinPadPresented: Bool,
         displayScale: CGFloat = 1, spinPadMaximumExtent: CGFloat = 310) {
        self.stageSize = stageSize
        let innerSize = CGSize(
            width: CGFloat(rotated ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength) * pointsPerMetre,
            height: CGFloat(rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * pointsPerMetre)
        innerRect = CGRect(x: (stageSize.width - innerSize.width) / 2,
                           y: (stageSize.height - innerSize.height) / 2,
                           width: innerSize.width, height: innerSize.height)
        let extent = DailyLayoutMetrics.SpinPad(playingRect: innerRect, displayScale: displayScale,
            maximumExtent: spinPadMaximumExtent.isFinite ? spinPadMaximumExtent : max(innerRect.width, innerRect.height)).extent
        spinPadFrame = CGRect(x: (stageSize.width - extent) / 2, y: (stageSize.height - extent) / 2,
                              width: extent, height: extent)
        self.instruments = instruments
        self.spinPadPresented = spinPadPresented
    }
}

private struct BTTeachingPageLayoutKey: EnvironmentKey {
    static let defaultValue: BTTeachingPageLayout? = nil
}

extension EnvironmentValues {
    var teachingTableLayout: BTTeachingPageLayout? {
        get { self[BTTeachingPageLayoutKey.self] }
        set { self[BTTeachingPageLayoutKey.self] = newValue }
    }
}

/// Ordinary notices yield to the spin editor; persistent teaching values do not
/// disappear merely because a notice is suppressed. Confirmation cards are not
/// represented by this type and keep their own presentation/interaction contract.
struct BTTeachingInformation: Equatable {
    enum Kind: Equatable { case notice, readout }
    let text: String
    var kind: Kind = .notice
    var symbol: String? = nil
    var identifier: String? = nil
    var expandedText: String? = nil
    var showsSymbol = true

    var effectiveSymbol: String? { showsSymbol ? (symbol ?? (kind == .notice ? "info.circle" : nil)) : nil }
    func isVisible(spinPadPresented: Bool) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (kind == .readout || !spinPadPresented)
    }
}

struct BTTeachingInformationLayer: View {
    @Environment(\.teachingTableLayout) private var layout
    @State private var naturalHeight: CGFloat = 1
    @State private var wideHeight: CGFloat = 1
    let items: [BTTeachingInformation]

    var body: some View {
        if let layout {
            let expanded = layout.spinPadPresented
            let lane = layout.expandedReadoutFrame
            let fullWidth = max(1, layout.innerRect.width - 2 * Spacing.md)
            let topCapacity = max(44, layout.innerRect.maxY - layout.informationTop - Spacing.md
                - BTAimCloseupHUD.defaultDiameter - Spacing.sm)
            // When a top strip cannot fit the text, reserve the closeup's width
            // beside a scrollable information column. This also leaves a clear
            // vertical region around horizontal aiming and defensive sight lines.
            let sideColumn = !expanded && wideHeight > topCapacity
            let width = expanded ? lane.width : (sideColumn
                ? max(44, fullWidth - BTAimCloseupHUD.defaultDiameter - Spacing.sm) : fullWidth)
            let availableHeight = expanded || sideColumn ? lane.height : topCapacity
            ScrollView(.vertical) {
                content(expanded: expanded, leading: expanded || sideColumn)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: BTTeachingInformationHeightKey.self, value: geometry.size.height)
                    })
                    .anchorPreference(key: BTTeachingInformationBoundsKey.self, value: .bounds) { $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(naturalHeight <= availableHeight)
            .frame(width: width, height: min(naturalHeight, availableHeight))
            .background {
                // Measure the preferred width independently of the chosen layout,
                // so narrowing the visible column cannot create a feedback loop.
                content(expanded: expanded, leading: false)
                    .frame(width: fullWidth).fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: BTTeachingInformationWideHeightKey.self, value: geometry.size.height)
                    })
                    .hidden().allowsHitTesting(false).accessibilityHidden(true)
            }
            .backgroundPreferenceValue(BTTeachingInformationBoundsKey.self) { contentBounds in
                GeometryReader { geometry in
                    let window = geometry.frame(in: .global)
                    let visible = contentBounds.map {
                        geometry[$0].intersection(CGRect(origin: .zero, size: geometry.size))
                    } ?? .null
                    // Protect visible information, not the empty horizontal space
                    // in a wide scroll viewport. Clipped text remains scrollable.
                    let page = geometry.frame(in: .named("controlLayout"))
                    Color.clear.preference(key: BTCloseupProtectedFramesKey.self,
                        value: visible.isNull || visible.isEmpty ? [] : [
                            visible.offsetBy(dx: window.minX, dy: window.minY)])
                        .preference(key: ControlLayoutFixedFramesKey.self,
                            value: visible.isNull || visible.isEmpty ? [] : [
                                visible.offsetBy(dx: page.minX, dy: page.minY)])
                }
            }
            .accessibilityIdentifier("teaching.informationViewport")
            .allowsHitTesting(naturalHeight > availableHeight)
            .onPreferenceChange(BTTeachingInformationHeightKey.self) { height in
                if height.isFinite && height >= 0 { naturalHeight = height }
            }
            .onPreferenceChange(BTTeachingInformationWideHeightKey.self) { height in
                if height.isFinite && height >= 0 { wideHeight = height }
            }
            .padding(.leading, expanded ? lane.minX : (sideColumn ? layout.innerRect.minX + Spacing.md : 0))
            .padding(.top, layout.informationTop)
            .frame(width: layout.stageSize.width, height: layout.stageSize.height,
                   alignment: expanded || sideColumn ? .topLeading : .top)
        }
    }

    private func content(expanded: Bool, leading: Bool) -> some View {
        VStack(alignment: leading ? .leading : .center, spacing: Spacing.xs) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if item.isVisible(spinPadPresented: expanded) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        if let symbol = item.effectiveSymbol {
                            Image(systemName: symbol).accessibilityHidden(true)
                        }
                        Text(expanded ? item.expandedText ?? item.text : item.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(expanded ? .footnote : .subheadline).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.text)
                    .accessibilityIdentifier(item.identifier ?? "teaching.information")
                }
            }
        }
    }
}

private struct BTTeachingInformationBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct BTTeachingInformationHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct BTTeachingInformationWideHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Uses the actual font's advance to choose a line, without expanding the header
/// or shrinking the palette. For an odd count, the middle character occupies a
/// separate right-hand column centred vertically between the two equal rows.
struct BTTablePageTitleLayout: Equatable {
    let upper: String
    let lower: String?
    let middle: String?
    let fontSize: CGFloat
    let width: CGFloat

    init(_ text: String, width: CGFloat = 60, compact: Bool = false) {
        let characters = Array(text.filter { !$0.isNewline })
        let clean = String(characters)
        let singleSize: CGFloat = compact ? 13 : 15
        let font = UIFont.systemFont(ofSize: singleSize, weight: .semibold)
        self.width = max(0, width)
        if (clean as NSString).size(withAttributes: [.font: font]).width <= self.width {
            upper = clean; lower = nil; middle = nil; fontSize = singleSize
        } else {
            let count = characters.count / 2
            upper = String(characters.prefix(count))
            lower = String(characters.suffix(count))
            middle = characters.count.isMultiple(of: 2) ? nil : String(characters[count])
            fontSize = compact ? 12 : 13
        }
    }
}

struct BTTablePageTitle: View {
    let text: String
    var width: CGFloat = 60
    var compact = false
    var fitsLongText = false
    @State private var naturalWidth: CGFloat = 0

    init(_ text: String, width: CGFloat = 60, compact: Bool = false, fitsLongText: Bool = false) {
        self.text = text; self.width = width; self.compact = compact
        self.fitsLongText = fitsLongText
    }

    var body: some View {
        let layout = BTTablePageTitleLayout(text, width: width, compact: compact)
        Group {
            if fitsLongText {
                // Measure the actual two-row SwiftUI content, including the odd
                // middle column. Fit both rows together; never truncate either row
                // or publish the natural width back to the table's reservation.
                titleContent(layout)
                    .fixedSize()
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: TablePageTitleNaturalWidth.self, value: geometry.size.width)
                    })
                    .scaleEffect(min(1, layout.width / max(layout.width, naturalWidth, 1)))
                    .frame(width: layout.width, height: 34)
                    .onPreferenceChange(TablePageTitleNaturalWidth.self) { naturalWidth = $0 }
            } else {
                titleContent(layout).frame(width: layout.width, height: 34)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.replacingOccurrences(of: "\n", with: ""))
    }

    private func titleContent(_ layout: BTTablePageTitleLayout) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(layout.upper).lineLimit(1)
                if let lower = layout.lower { Text(lower).lineLimit(1) }
            }
            if let middle = layout.middle { Text(middle).lineLimit(1) }
        }
        .font(.system(size: layout.fontSize, weight: .semibold))
        .foregroundStyle(.white)
    }
}

private struct TablePageTitleNaturalWidth: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
