import SwiftUI
import SceneKit

/// Common daily-template shell for editable teaching tables. Hosts provide only
/// their title, teaching controls, status and optional cue-speed binding.
struct BTTeachingTablePage<Host: TeachingTableHost, Title: View, Left: View, Status: View>: View {
    @ObservedObject var vm: Host
    let titleLabel: String
    let identifier: String
    var velocity: Binding<Double>? = nil
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
    @State private var hasAppeared = false
    @StateObject private var fps = TableFPSReadoutState()
    @State private var portrait = false
    @State private var windowControls = UIEdgeInsets.zero
    @State private var windowSafeArea = UIEdgeInsets.zero
    @State private var systemStatusVisible = false
    @State private var menu: MenuPage?
    @State private var titleSize = CGSize(width: 60, height: 34)
    private enum MenuPage { case settings }
    @State private var cameraReadableFrame: CGRect?
    private let paletteKeys = PositionPlayBall.allKeys.filter { !PositionPlayBall.isCue($0) }

    var body: some View {
        GeometryReader { geo in
            let extraTop = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.top - geo.safeAreaInsets.top) : 0
            let extraBottom = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.bottom - geo.safeAreaInsets.bottom) : 0
            let size = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: max(0, geo.size.height - extraTop - extraBottom))
            template(size: size, safe: max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing))
                .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
                .padding(.top, extraTop).padding(.bottom, extraBottom)
                .offset(x: -geo.safeAreaInsets.leading)
                .ignoresSafeArea(.container, edges: .trailing)
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
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            vm.setupScene()
            updateProjection()
        }
    }

    private func template(size: CGSize, safe: CGFloat) -> some View {
        let side = max(4, safe)
        let titleWidth = max(60, titleSize.width)
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
        let renderFrame = is3D ? CGRect(origin: .zero, size: size) : f.stage
        let pointsPerMetre = f.table.height / CGFloat(2 * (f.rotated
            ? (vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength)
            : (vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth)))
        return ZStack(alignment: .topLeading) {
            // One persistent underlay and one renderer across both projections.
            DailyCarpetBackground(style: preferences.roomStyle, pointsPerMetre: pointsPerMetre).ignoresSafeArea()
            sceneFullscreen.frame(width: renderFrame.width, height: renderFrame.height)
                .position(x: renderFrame.midX, y: renderFrame.midY)
                .allowsHitTesting(menu == nil)
            DailyTemplateHeader(size: size, safe: safe, foundation: f, plan: plan,
                targets: paletteKeys, chineseEightBall: true, titleWidth: titleWidth, titleHeight: titleSize.height,
                windowControlInsets: windowControls, fps: fps, showsDeviceStatus: !systemStatusVisible,
                title: { navigationTitle }, actions: {
                    Button { menu = .settings } label: {
                        Image(systemName: BTIcon.menuCircle).font(.system(size: 22, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: Circle()) }
                    }.overlay(Circle().stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth).allowsHitTesting(false))
                    .accessibilityLabel("更多").accessibilityIdentifier("\(identifier).more")
                }, ball: { key, diameter, height in ballToken(key, diameter: diameter, slotHeight: height) },
                paletteMarker: { frameReader("palette") })
                .background(DailyWindowControlInsets { controls, window, visible in
                    windowControls = controls; windowSafeArea = window; systemStatusVisible = visible
                }.allowsHitTesting(false))
            leftContent(CGSize(width: f.left.width, height: min(420, size.height - max(44, f.stage.minY))))
                .frame(width: f.left.width)
                .position(x: f.left.midX, y: f.table.midY)
            if let velocity {
                powerColumn(velocity: velocity, foundation: f)
                    .position(x: f.right.midX, y: f.table.midY)
            } else if is3D {
                cameraButtons.position(x: f.right.midX, y: f.table.midY)
            }
            status().frame(width: f.stage.width, height: f.stage.height)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: TeachingCameraFrame.self, value: proxy.frame(in: .global))
                })
                .position(x: f.stage.midX, y: f.stage.midY)
            if !plan.fits {
                Text("扩大窗口后继续摆球").font(.btFootnote).padding()
                    .background(.regularMaterial, in: Capsule())
                    .position(x: size.width / 2, y: size.height / 2)
            }
            if let draggingKey {
                BTBallPaletteDragGhost(key: draggingKey, location: dragLocation, overTable: dragOverTable)
            }
            if menu != nil {
                Button { self.menu = nil } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("关闭菜单")
                    .accessibilityIdentifier("\(identifier).dismissMenu")
                DailyHUDMenuPanel(title: nil, items: settingsItems,
                    availableSize: CGSize(width: size.width - 2 * (side + windowControls.right), height: size.height - DailyLayoutMetrics.Panels.top - 8),
                    onBack: { self.menu = .settings }, onClose: { self.menu = nil })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, DailyLayoutMetrics.Panels.top).padding(.trailing, side + windowControls.right)
            }
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
        .environment(\.dailyHUDControls, true)
        .onChange(of: size.height > size.width, initial: true) { _, value in
            portrait = value; updateProjection()
        }
        .onChange(of: size) { _, _ in menu = nil }
        .onPreferenceChange(TeachingCameraFrame.self) { cameraReadableFrame = $0 }
        .background(Color.clear.accessibilityElement().accessibilityIdentifier("\(identifier).template"))
    }

    private var navigationTitle: some View {
        HStack(spacing: -12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.accessibilityLabel("返回").accessibilityIdentifier("\(identifier).back")
            title()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(titleLabel)
                .background(GeometryReader { g in Color.clear.preference(key: TeachingTitleSize.self, value: g.size) })
        }.fixedSize(horizontal: true, vertical: false)
            .onPreferenceChange(TeachingTitleSize.self) { titleSize = $0 }
    }

    private func updateProjection() {
        guard !is3D else { return }
        vm.cameraMode = portrait ? .topDown2DRotated : .topDown2D
        vm.scene.setCameraMode(vm.cameraMode, animated: false)
    }

    private func toggleCamera() {
        vm.setCameraMode(is3D ? (portrait ? .topDown2DRotated : .topDown2D) : .perspective3D)
    }

    private var settingsItems: [DailyHUDMenuItem] {
        [.init(id: "\(identifier).display", title: "显示"),
         .init(id: "\(identifier).cameraMode", title: "视图", detail: is3D ? "3D" : "2D",
               segments: ["2D", "3D"], disabled: vm.temporaryTopDownActive, action: toggleCamera),
         .init(id: "menu.tableGrid", title: "台面网格 4×8", selected: preferences.showTableGrid, action: {
             preferences.showTableGrid.toggle(); vm.scene.setTableGridVisible(preferences.showTableGrid); menu = nil
         })]
    }

    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: is3D ? .cameraControl : .tapsOnly,
            // Core-template fitting also handles rotated 2D; the legacy rotated
            // fitter imposes an extra minimum scale and detaches the palette from the rail.
            autoFitsLandscapeTable: !is3D,
            backgroundColor: is3D ? .black : .clear,
            onPocketTapped: { index in
                vm.selectPocket(at: index)
            },
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
            projector: projector,
            contentIsAnimating: vm.isDragging || vm.cameraTransitionBusy,
            fpsReadoutState: fps,
            twoViewReadableFrameInWindow: cameraReadableFrame,
            onCameraObservationBegan: { vm.beginCameraObservation() },
            onCameraObservationEnded: { vm.endCameraObservation() },
            onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },
            topDownContentRevision: vm.topDownContentRevision
        )
        .clipped()
        .background(frameReader("scene"))
    }

    @ViewBuilder private var cameraButtons: some View {
        if let rig = vm.scene.cameraRig {
            ShotPlayerCameraButtons(controlSpacing: 4, rig: rig,
                isEnabled: vm.temporaryTopDownActive || vm.currentPlayerAim != nil,
                onWholeTable: { vm.requestSurfaceOverview() }, usesTwoViewControls: rig.usesTwoViewCameraControls,
                temporaryTopDownActive: vm.temporaryTopDownActive,
                onTemporaryTopDownBegan: { vm.beginTemporaryTopDown() },
                onTemporaryTopDownEnded: { vm.endTemporaryTopDown() },
                onSelect: { vm.requestPlayerView($0) })
        }
    }

    private func powerColumn(velocity: Binding<Double>, foundation f: DailyLayoutMetrics.Foundation) -> some View {
        BTShotInstrumentColumn(spinX: 0, spinY: 0, velocity: velocity,
            range: ShotTuning.velocityRange, fixedPowerBarHeight: f.rulerLength,
            powerLabel: "杆速", compactPowerBarWidth: 32, reportsPowerShellBounds: true)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("solver.power")
            .accessibilityLabel("杆速")
            .accessibilityValue(String(format: "%.2f", velocity.wrappedValue))
            .frame(width: f.right.width)
            .overlayPreferenceValue(BTPowerShellBoundsKey.self) { bounds in
                GeometryReader { proxy in
                    if is3D, let bounds {
                        cameraButtons
                            .background(GeometryReader { measure in
                                Color.clear.preference(key: TeachingCameraHeight.self, value: measure.size.height)
                            })
                            .offset(DailyLayoutMetrics.CameraLane(column: f.right, rulerHeight: f.rulerLength,
                                powerShell: proxy[bounds], stackHeight: cameraStackHeight).offset)
                    }
                }
            }
            .onPreferenceChange(TeachingCameraHeight.self) { if $0 > 0 { cameraStackHeight = $0 } }
    }

    /// 球库槽位：在库点击上桌；在桌点击（非母球）撤下回库；当前目标球高亮圈。
    private func ballToken(_ key: String, diameter: CGFloat, slotHeight: CGFloat) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        let selected = vm.selectedTargetKey == key
        return Button {
            if onTable { vm.removeFromTable(key) } else { vm.placeFromPalette(key) }
        } label: {
            PoolBallFace(key: key, diameter: diameter).opacity(onTable ? 0.3 : 1)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1).padding(-1).opacity(selected ? 1 : 0))
                .frame(width: diameter + 2, height: min(max(32, diameter), slotHeight))
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: key == paletteKeys.first || key == paletteKeys.last ? 16 : 4), selected: selected, normal: .clear) }
                .frame(height: slotHeight).contentShape(Rectangle())
        }
        .buttonStyle(BTHUDPressStyle()).disabled(is3D)
        .simultaneousGesture(DragGesture(minimumDistance: BTBallPaletteMetrics.dragMinimumDistance,
                                        coordinateSpace: .named(identifier))
            .onChanged { value in
                guard allowsPaletteDrag, !is3D, !onTable else { return }
                draggingKey = key; dragLocation = value.location
                dragOverTable = sceneFrame.contains(value.location)
            }.onEnded { value in
                defer { draggingKey = nil; dragOverTable = false }
                guard allowsPaletteDrag, !is3D, !onTable, sceneFrame.contains(value.location) else { return }
                let local = CGPoint(x: value.location.x - sceneFrame.minX, y: value.location.y - sceneFrame.minY)
                if let world = projector.unproject?(local) { onPalettePlace?(key, world) }
            }, including: allowsPaletteDrag && !is3D && !onTable ? .all : .subviews)
        .accessibilityLabel("\(PositionPlayBall.shortLabel(for: key))号球")
        .accessibilityValue(onTable ? "在桌上" : "未在桌上")
        .accessibilityHint(is3D ? "切到2D摆球" : (onTable ? "点按撤回球库" : "点按摆到桌面"))
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
