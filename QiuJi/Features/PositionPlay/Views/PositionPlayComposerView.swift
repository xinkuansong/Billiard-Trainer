import SwiftUI
import SceneKit

/// 走位编排台（ADR-P11-01）：自由摆球 + 逐杆编排击打序列，用于教学视频制作与走位演示。
///
/// 布局：球桌全屏；顶部状态卡；底部「球库 + 序列时间轴」常驻条；右侧竖排操作按钮
/// （设置 / 记录此杆 / 播放 / 更多）；点「设置」弹出击球设置（连续力度 + 打点盘）。
struct PositionPlayComposerView: View {
    @StateObject private var vm = PositionPlayViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var hasAppeared = false
    @State private var showSettings = false

    // Export / save
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var banner: String?

    var body: some View {
        ZStack {
            sceneLayer
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { topCard }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay(alignment: .trailing) { sideButtons }
        .overlay { if isExporting { exportOverlay } }
        .overlay(alignment: .top) { bannerView }
        .navigationTitle(vm.sequence.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { exportMenu } }
        .sheet(isPresented: $showSettings) { settingsSheet }
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
            }
        }
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
            Button("清空桌面", systemImage: "trash", role: .destructive) { vm.clearTable() }
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
            Text(banner)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
                .background(Color.btSuccess, in: Capsule())
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Actions

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

    // MARK: - Scene

    private var sceneLayer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            onPocketTapped: { vm.selectPocket(at: $0) },
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) },
            selectableBallNodes: vm.selectableBalls,
            onBallTapped: { vm.selectTarget(node: $0) }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Top status card

    private var topCard: some View {
        HStack(spacing: Spacing.md) {
            VStack(spacing: 2) {
                Text("瞄准夹角")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text(vm.cutAngleDeg.map { String(format: "%.0f°", $0) } ?? "—")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 60)

            Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 34)

            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(statusTint)
                Text(vm.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if vm.isComputing {
                    ProgressView().scaleEffect(0.7).tint(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BTRadius.lg))
        .environment(\.colorScheme, .dark)
        .overlay(RoundedRectangle(cornerRadius: BTRadius.lg).stroke(.white.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
    }

    private var statusIcon: String {
        if !vm.isFeasible { return "xmark.octagon.fill" }
        if vm.cuePocketed { return "exclamationmark.triangle.fill" }
        if vm.objectPocketed { return "checkmark.circle.fill" }
        return "scope"
    }

    private var statusTint: Color {
        if !vm.isFeasible || vm.cuePocketed { return .btDestructive }
        if vm.objectPocketed { return .btSuccess }
        return .white.opacity(0.7)
    }

    // MARK: - Side action buttons

    private var sideButtons: some View {
        VStack(spacing: Spacing.sm) {
            circleButton(icon: "slider.horizontal.3", label: "设置",
                         tint: Color.white.opacity(0.16)) { showSettings = true }
                .disabled(vm.isPlaying)

            circleButton(icon: "plus.circle.fill", label: "记录",
                         tint: recordEnabled ? Color.btPrimary : Color.btPrimary.opacity(0.3)) {
                vm.recordStep()
            }
            .disabled(!recordEnabled)

            circleButton(icon: "play.fill", label: vm.isPlaying ? "击球中" : "播放",
                         tint: playEnabled ? Color.btPrimary : Color.btPrimary.opacity(0.3)) {
                vm.play()
            }
            .disabled(!playEnabled)

            circleButton(icon: "arrow.counterclockwise", label: "重置",
                         tint: Color.white.opacity(0.16)) { vm.resetAll() }
                .disabled(vm.isPlaying)
        }
        .padding(.trailing, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var playEnabled: Bool { !vm.isPlaying && vm.isFeasible }
    private var recordEnabled: Bool { !vm.isPlaying && vm.isFeasible }

    @ViewBuilder
    private func circleButton(icon: String, label: String, tint: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
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

    // MARK: - Bottom bar (timeline + palette)

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            if vm.stepCount > 0 { timelineStrip }
            paletteBar
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(.ultraThinMaterial)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("球库（点击上桌 · 长按移除 · 点桌上球选目标）")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, Spacing.md)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PositionPlayBall.allKeys, id: \.self) { key in
                        ballToken(key)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, 2)
            }
        }
    }

    private func ballToken(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        let isTarget = vm.selectedTargetKey == key
        let isCue = PositionPlayBall.isCue(key)
        let label = PositionPlayBall.shortLabel(for: key)
        return Button {
            if !onTable {
                vm.placeFromPalette(key)
            } else if !isCue {
                vm.selectTarget(key: key)
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tokenFg(isCue: isCue, onTable: onTable))
                .frame(width: 36, height: 36)
                .background(tokenBg(isCue: isCue, onTable: onTable), in: Circle())
                .overlay(
                    Circle().stroke(isTarget ? Color.btPrimary : .white.opacity(0.15),
                                    lineWidth: isTarget ? 2.5 : 0.5)
                )
                .opacity(onTable ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onTable {
                Button("移除回球库", systemImage: "tray.and.arrow.down", role: .destructive) {
                    vm.removeFromTable(key)
                }
            }
        }
    }

    private func tokenFg(isCue: Bool, onTable: Bool) -> Color {
        if isCue { return .black }
        return .white
    }

    private func tokenBg(isCue: Bool, onTable: Bool) -> Color {
        if isCue { return .white }
        return Color(red: 0.20, green: 0.42, blue: 0.30)
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
}

#Preview("Dark") {
    NavigationStack { PositionPlayComposerView() }
        .preferredColorScheme(.dark)
}
