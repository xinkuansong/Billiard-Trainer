import SwiftUI
import SceneKit

/// 走位编排台（ADR-P11-01）：自由摆球 + 逐杆编排击打序列，用于教学视频制作与走位演示。
///
/// 布局：上方球桌区（铺满，夹角浮标贴目标球、右侧竖排操作按钮），下方实心球库栏（双行真实球面
/// + 序列时间轴）不遮挡球桌。交互：球库球拖到桌面落位、桌面球拖回球库区移除、点桌上球选目标、
/// 点袋口选目标袋。击球后球停在终局，「记录」存为一杆、「重打」退回本杆重来。
struct PositionPlayComposerView: View {
    @StateObject private var vm = PositionPlayViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var hasAppeared = false
    @State private var showSettings = false
    @State private var showRandom = false
    @State private var randomCount = 5

    // Ball-face thumbnails (USDZ baked once)
    @State private var ballFaces: [String: UIImage] = [:]
    @State private var projector = TableProjector()

    // Palette drag-to-place state (composer coordinate space)
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false

    // Frames in "composer" coordinate space
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    // Export / save
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var banner: String?

    private let paletteRows = [GridItem(.fixed(40), spacing: 8), GridItem(.fixed(40), spacing: 8)]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                sceneContainer
                bottomBar
            }
            if let key = draggingKey { dragGhost(key) }
            if isExporting { exportOverlay }
            bannerView
        }
        .coordinateSpace(name: "composer")
        .onPreferenceChange(ComposerFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle(vm.sequence.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { exportMenu } }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: $showRandom) { randomSheet }
        .sheet(isPresented: $showShare) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
        .alert("命名走位序列", isPresented: $showRename) {
            TextField("名称", text: $renameText)
            Button("保存") { vm.renameSequence(renameText) }
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                loadBallFaces()
            }
        }
    }

    // MARK: - Scene container (table + badge + side buttons)

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            onPocketTapped: { vm.selectPocket(at: $0) },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) },
            onDragEndedAt: { node, localPoint in handleTableDragEnd(node: node, localPoint: localPoint) },
            selectableBallNodes: vm.selectableBalls,
            onBallTapped: { vm.selectTarget(node: $0) },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) { angleChip.padding(.top, Spacing.sm) }
        .overlay(alignment: .trailing) { sideButtons }
        .background(frameReader(id: "scene"))
        .clipped()
    }

    // MARK: - Fixed angle chip (style aligned with 角度与打点 page; does not follow target)

    private var angleChip: some View {
        let hasAngle = vm.cutAngleDeg != nil
        return HStack(spacing: Spacing.sm) {
            metricItem(icon: "angle",
                       value: hasAngle ? "\(Int(vm.cutAngleDeg!.rounded()))°" : "—°")
            if hasAngle {
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
                thicknessItem(cutAngle: vm.cutAngleDeg!)
            }
            if vm.cuePocketed {
                Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 12)
                HStack(spacing: 4) {
                    Circle().fill(Color.btDestructive).frame(width: 7, height: 7)
                    Text("母球进袋").font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.btDestructive)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func metricItem(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func thicknessItem(cutAngle: Double) -> some View {
        Text(AngleSceneCalculator.thicknessName(cutAngle: cutAngle))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
    }

    // MARK: - Side action buttons

    private var sideButtons: some View {
        VStack(spacing: Spacing.sm) {
            circleButton(label: "设置", tint: .white.opacity(0.16)) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 17, weight: .semibold))
            } action: { showSettings = true }
                .disabled(vm.isPlaying)

            circleButton(label: "随机", tint: .white.opacity(0.16)) {
                Image(systemName: "shuffle").font(.system(size: 16, weight: .semibold))
            } action: { showRandom = true }
                .disabled(vm.isPlaying)

            circleButton(label: vm.isPlaying ? "击球中" : "击球",
                         tint: strikeEnabled ? Color.btPrimary : Color.btPrimary.opacity(0.3)) {
                CueStickShape().frame(width: 20, height: 20)
            } action: { vm.play() }
                .disabled(!strikeEnabled)

            circleButton(label: "记录",
                         tint: recordEnabled ? Color.btSuccess : Color.btSuccess.opacity(0.3)) {
                Image(systemName: "plus.circle.fill").font(.system(size: 17, weight: .semibold))
            } action: { vm.recordStep() }
                .disabled(!recordEnabled)

            circleButton(label: "重打", tint: .white.opacity(0.16)) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 16, weight: .semibold))
            } action: { vm.replayCurrent() }
                .disabled(vm.isPlaying)
        }
        .padding(.trailing, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private var strikeEnabled: Bool { !vm.isPlaying && vm.isFeasible && !vm.hasStruck }
    private var recordEnabled: Bool { !vm.isPlaying && vm.isFeasible }

    @ViewBuilder
    private func circleButton<Glyph: View>(label: String, tint: Color,
                                           @ViewBuilder glyph: () -> Glyph,
                                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                glyph().foregroundStyle(.white)
                Text(label).font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 54, height: 54)
            .background(tint, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom bar (timeline + palette), opaque so it never covers the table

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            if vm.stepCount > 0 { timelineStrip }
            paletteBar
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    private var timelineStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Array(vm.sequence.steps.enumerated()), id: \.element.id) { idx, step in
                    stepChip(index: idx, step: step)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func stepChip(index: Int, step: SequenceStep) -> some View {
        let targetLabel = PositionPlayBall.shortLabel(for: step.shot.targetKey)
        return Menu {
            Button("回退到此杆前（截断重录）", systemImage: "arrow.uturn.backward") {
                vm.revertToBefore(stepIndex: index)
            }
            Button("查看此杆后球形", systemImage: "eye") {
                vm.previewBoard(afterStep: index)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 3) {
                    Text(targetLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Image(systemName: step.objectPocketed ? "arrow.right.circle.fill" : "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(step.cuePocketed ? .btDestructive : .btPrimary)
                }
                Text(PocketDisplay.name(id: step.shot.pocket))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: 58, height: 52)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: BTRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: BTRadius.sm).stroke(.white.opacity(0.1), lineWidth: 0.5))
        }
    }

    private var paletteBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("球库（拖到桌面摆球 · 点球面快速上桌 · 桌上球拖回此处移除 · 点桌上球选目标）")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, Spacing.md)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: paletteRows, spacing: 8) {
                    ForEach(PositionPlayBall.allKeys, id: \.self) { key in
                        ballToken(key)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Ball token (real face + drag to place)

    private func ballToken(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        let isTarget = vm.selectedTargetKey == key
        return ZStack {
            ballFaceView(key)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(isTarget ? Color.btPrimary : .white.opacity(0.18),
                                    lineWidth: isTarget ? 2.5 : 0.5)
                )
                .opacity(onTable ? 0.5 : 1)   // 在桌的球在球库里淡显，提示已上桌
        }
        .frame(width: 40, height: 40)
        .contentShape(Circle())
        .opacity(draggingKey == key ? 0.3 : 1)
        .onTapGesture {
            if !onTable { vm.placeFromPalette(key) }
            else if !PositionPlayBall.isCue(key) { vm.selectTarget(key: key) }
        }
        .gesture(paletteDrag(key))
    }

    @ViewBuilder
    private func ballFaceView(_ key: String) -> some View {
        if let img = ballFaces[key] {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Circle()
                .fill(PositionPlayBall.isCue(key) ? Color.white : Color(red: 0.20, green: 0.42, blue: 0.30))
                .overlay(
                    Text(PositionPlayBall.shortLabel(for: key))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PositionPlayBall.isCue(key) ? .black : .white)
                )
        }
    }

    private func paletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("composer"))
            .onChanged { value in
                draggingKey = key
                dragLocation = value.location
                dragOverTable = sceneFrame.contains(value.location)
            }
            .onEnded { value in
                let loc = value.location
                defer { draggingKey = nil; dragOverTable = false }
                guard sceneFrame.contains(loc) else { return }
                let local = CGPoint(x: loc.x - sceneFrame.minX, y: loc.y - sceneFrame.minY)
                if let world = projector.unproject?(local) {
                    vm.placeFromPalette(key, atWorld: world)
                } else {
                    vm.placeFromPalette(key)
                }
            }
    }

    // Floating ghost following the finger during a palette drag.
    @ViewBuilder
    private func dragGhost(_ key: String) -> some View {
        ballFaceView(key)
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .overlay(Circle().stroke(dragOverTable ? Color.btSuccess : .white.opacity(0.4),
                                     lineWidth: dragOverTable ? 2.5 : 1))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .position(dragLocation)
            .allowsHitTesting(false)
    }

    // MARK: - Table ball dragged back to palette → remove

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard sceneFrame != .zero, paletteFrame != .zero else { return }
        let composerPoint = CGPoint(x: localPoint.x + sceneFrame.minX, y: localPoint.y + sceneFrame.minY)
        guard paletteFrame.contains(composerPoint), let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
        flash("已移回球库")
    }

    // MARK: - Toolbar export / save menu

    private var exportMenu: some View {
        Menu {
            Button("重命名", systemImage: "pencil") {
                renameText = vm.sequence.name
                showRename = true
            }
            Section("保存与导出") {
                Button("保存到我的序列", systemImage: "tray.and.arrow.down") { saveSequence() }
                    .disabled(vm.stepCount == 0)
                Button("导出教学视频 (MP4)", systemImage: "film") { exportVideo() }
                    .disabled(vm.stepCount == 0)
                Button("导出 GIF", systemImage: "square.stack.3d.down.right") { exportGIF() }
                    .disabled(vm.stepCount == 0)
                Button("导出训练关卡 (JSON)", systemImage: "doc.text") { exportDrillJSON() }
                    .disabled(vm.stepCount == 0)
            }
            Section {
                Button("清空桌面", systemImage: "trash") { vm.clearTable() }
                Button("清空并重来", systemImage: "arrow.counterclockwise", role: .destructive) { vm.resetAll() }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                ProgressView(value: exportProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 180)
                    .tint(Color.btPrimary)
                Text("导出中… \(Int(exportProgress * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(Spacing.xl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BTRadius.lg))
            .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner {
            VStack {
                Text(banner)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
                    .background(Color.btSuccess, in: Capsule())
                    .padding(.top, 60)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func loadBallFaces() {
        Task { @MainActor in
            ballFaces = BallFaceRenderer.renderAll()
        }
    }

    private func saveSequence() {
        do {
            try PositionPlaySequenceStore(context: modelContext).save(vm.sequence)
            flash("已保存到我的序列")
        } catch {
            flash("保存失败")
        }
    }

    private func exportVideo() {
        isExporting = true
        exportProgress = 0
        let sequence = vm.sequence
        Task { @MainActor in
            do {
                let url = try await SequenceVideoExporter.exportVideo(
                    sequence: sequence, progress: { exportProgress = $0 }
                )
                exportURL = url
                isExporting = false
                showShare = true
            } catch {
                isExporting = false
                flash("视频导出失败")
            }
        }
    }

    private func exportGIF() {
        isExporting = true
        exportProgress = 0
        let sequence = vm.sequence
        Task { @MainActor in
            do {
                let url = try SequenceVideoExporter.exportGIF(
                    sequence: sequence, progress: { exportProgress = $0 }
                )
                exportURL = url
                isExporting = false
                showShare = true
            } catch {
                isExporting = false
                flash("GIF 导出失败")
            }
        }
    }

    private func exportDrillJSON() {
        do {
            let data = try PositionPlayDrillExporter.makeJSON(from: vm.sequence)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(vm.sequence.name)-drill.json")
            try data.write(to: url)
            exportURL = url
            showShare = true
        } catch {
            flash("JSON 导出失败")
        }
    }

    private func flash(_ message: String) {
        withAnimation { banner = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { banner = nil }
        }
    }

    // MARK: - Random layout sheet

    private var randomSheet: some View {
        VStack(spacing: Spacing.lg) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 36, height: 5).padding(.top, 8)

            Text("随机球形").font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("目标球数量（不含母球）")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text("\(randomCount)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.btPrimary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(randomCount) },
                        set: { randomCount = Int($0.rounded()) }
                    ),
                    in: 1...15, step: 1
                )
                .tint(Color.btPrimary)
                HStack {
                    Text("1").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text("15").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                }
                Text("球号随机不重复、位置随机且分散。母球为自由球，请自行摆放。")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.lg)

            Button {
                vm.randomLayout(objectCount: randomCount)
                showRandom = false
            } label: {
                Text("生成球形")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm + 2)
                    .background(Color.btPrimary, in: RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.1).ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.height(290)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Settings sheet (velocity + spin)

    private var settingsSheet: some View {
        VStack(spacing: Spacing.lg) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 36, height: 5).padding(.top, 8)

            Text("击球设置").font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            HStack(alignment: .center, spacing: Spacing.xl) {
                VStack(spacing: 6) {
                    BTSpinPad(spinX: $vm.spinX, spinY: $vm.spinY)
                        .frame(width: 100, height: 100)
                    Text("打点").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Label("力度", systemImage: "speedometer")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Text(String(format: "%.1f m/s", vm.velocity))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.btPrimary)
                            .monospacedDigit()
                    }
                    Slider(value: $vm.velocity, in: 1.2...6.0, step: 0.1)
                        .tint(Color.btPrimary)
                    HStack {
                        Text("轻").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text("大力").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.1).ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Frame reader

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: ComposerFramePreference.self,
                                   value: [id: geo.frame(in: .named("composer"))])
        }
    }
}

// MARK: - Cue stick glyph

/// 简易球杆图标（细长锥形 + 杆尖小点），SF Symbols 无球杆符号时用。
private struct CueStickShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // 斜向锥形：左下粗（杆尾）→ 右上细（杆尖）
        let tip = CGPoint(x: w * 0.84, y: h * 0.16)
        let buttA = CGPoint(x: w * 0.08, y: h * 0.74)
        let buttB = CGPoint(x: w * 0.26, y: h * 0.92)
        p.move(to: tip)
        p.addLine(to: buttA)
        p.addLine(to: buttB)
        p.closeSubpath()
        // 杆尖小圆点
        p.addEllipse(in: CGRect(x: w * 0.80, y: h * 0.12, width: w * 0.13, height: w * 0.13))
        return p
    }
}

// MARK: - Frame preference

private struct ComposerFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("Dark") {
    NavigationStack { PositionPlayComposerView() }
        .preferredColorScheme(.dark)
}
