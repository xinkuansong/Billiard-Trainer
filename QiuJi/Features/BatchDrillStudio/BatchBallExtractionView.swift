//
//  BatchBallExtractionView.swift
//  QiuJi
//
//  批量出片台 · 拍照建球形（仅模拟器）。
//
//  复用 `BallExtractionViewModel`（标定/标球/确认逻辑与生产版一致），仅替换图片来源：
//  从当前 drill 文件夹直接加载截图、顺时针旋转 90°（横屏 → 竖版真台），确认后把球形 +
//  drill 上下文交给「编排求解二合一」工具。人工确认仍是一等公民（四角/球位/球号可改定）。
//

#if targetEnvironment(simulator)
import SwiftUI
import SceneKit

struct BatchBallExtractionView: View {
    @ObservedObject var context: BatchAuthoringContext
    @StateObject private var vm = BallExtractionViewModel()

    @State private var activeHandle: Int?
    @State private var markDragLockedOffset: CGSize?

    // 确认页（场景）状态
    @State private var projector = TableProjector()
    @State private var cameraMode = AngleTrainingScene.CameraMode.topDown2DRotated
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    @State private var goAuthor = false
    @State private var showNewFormationOptions = false
    @State private var showClonePicker = false
    @State private var cloneCandidates: [(token: String, name: String, initial: BoardSnapshot)] = []
    /// 长按已存球形后待确认删除的目标（token + 展示名）。
    @State private var pendingDelete: (token: String, label: String)?
    @State private var showDeleteConfirm = false

    private var drill: BatchDrill? { context.current }

    /// 空台面起点：仅母球（厨房区惯例位，与编排台默认母球位一致；不生成任何目标球坐标）。
    private static let emptyCueBoard = BoardSnapshot(
        onTable: [PositionPlayBall.cueKey: CanvasPoint(x: 0.30, y: 0.30)]
    )

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            if let key = draggingKey {
                BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)
            }
        }
        .btToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        .coordinateSpace(name: "batchExtract")
        .navigationTitle(drill.map { "建球形 · \($0.drillId)" } ?? "建球形")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $goAuthor) {
            BatchAuthoringView(context: context)
        }
        .confirmationDialog("新增球形起点", isPresented: $showNewFormationOptions, titleVisibility: .visible) {
            Button("空台面（仅母球）") {
                startManualFormation(initial: Self.emptyCueBoard)
            }
            Button("克隆已有球形…") {
                presentClonePicker()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("跳过截图标定，直接进编排台摆球。克隆只复制已有球形的 initial，不改坐标。")
        }
        .confirmationDialog("选择要克隆的球形", isPresented: $showClonePicker, titleVisibility: .visible) {
            ForEach(cloneCandidates, id: \.token) { item in
                Button("\(item.token) · \(item.name)") {
                    // 只复制 initial 快照；新球形另发 manualNN token，不覆盖来源。
                    startManualFormation(initial: item.initial)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "删除此球形？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { confirmDeleteFormation() }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete.map {
                "将移除内容库序列「\($0.label)」，不可撤销。源截图与 drill 课程不受影响。"
            } ?? "")
        }
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        // 「保存并下个 drill」从编排台 dismiss 回来时，context.current 已切到下一 drill：
        // 重置向导到选图步，展示新 drill 的截图（避免复用上一 drill 的确认页）。
        .onChange(of: context.current?.drillId) { _, _ in resetToPicker() }
        // 「保存」（留在本 drill 继续做下一张图）回来时 drillId 未变，靠此信号重置回选图栅格。
        .onChange(of: context.pickerResetToken) { _, _ in resetToPicker() }
    }

    private func resetToPicker() {
        vm.image = nil
        vm.marks = []
        vm.corners = BallExtractionViewModel.defaultCorners
        vm.step = .pickPhoto
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch vm.step {
            case .pickPhoto: pickStep
            case .calibrate: if let img = vm.image { calibrateStep(img) }
            case .markBalls: if let img = vm.image { markStep(img) }
            case .confirm: confirmStep
            }
        }
        // F-BD-06：四步向导切换 + 步骤条过渡；状态机不变。
        .animation(BTMotion.springPanel, value: vm.step)
        .transition(.opacity)
    }

    // MARK: - Step header

    private func stepHeader(_ hint: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(BallExtractionViewModel.Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= vm.step.rawValue ? Color.btPrimary : Color.white.opacity(0.15))
                        .frame(height: 3)
                        .animation(BTMotion.springPanel, value: vm.step)
                }
            }
            Text(hint)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - Step 1: pick from drill folder（替换 PhotosPicker）

    private var pickStep: some View {
        VStack(spacing: Spacing.md) {
            stepHeader(drill?.hasSourceImages == false
                       ? "无源图：点「+ 新增球形」空台或克隆；长按已存可删除"
                       : "每张图 = 一个球形。点图/「重做」续编；长按已存可删除；「+」无图建形")
            if let drill {
                ScrollView {
                    // 旧版存档（早期保存、未绑定截图，故任何图都不打勾）：单独给改存档入口。
                    if drill.savedStems.contains("") {
                        Button { editLegacyArchive() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "archivebox.fill")
                                    .foregroundStyle(Color.btAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("已有旧版存档（未绑定截图，图片不打勾）")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("点此进编排台改存档 · 长按可删除")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(Spacing.md)
                            .background(Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: BTRadius.sm))
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                            requestDelete(token: "", label: "旧版存档")
                        })
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm),
                                        GridItem(.flexible(), spacing: Spacing.sm)],
                              spacing: Spacing.sm) {
                        ForEach(drill.imageURLs, id: \.self) { url in
                            let saved = drill.isImageSaved(url)
                            // 外层用 tap gesture（不是 Button）：Button 嵌套 Button 时外层会抢走
                            // 内层「重做」的点击；gesture 的优先级低于内层 Button，才能各点各的。
                            thumbnail(url, saved: saved)
                                .contentShape(Rectangle())
                                .onTapGesture { saved ? editArchive(url) : loadImage(url) }
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    guard saved else { return }
                                    let token = BatchDrillCatalog.formationToken(forImage: url)
                                    requestDelete(token: token, label: url.lastPathComponent)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if saved {
                                        Button { editArchive(url) } label: {
                                            Label("重做", systemImage: "arrow.counterclockwise")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8).padding(.vertical, 4)
                                                .background(.black.opacity(0.55), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(6)
                                    }
                                }
                        }
                        // 已存无图球形（manualNN / A1…）：点进续编；长按删除。
                        ForEach(drill.unboundSavedTokens, id: \.self) { token in
                            manualFormationTile(token: token, saved: true)
                                .contentShape(Rectangle())
                                .onTapGesture { editManualArchive(token: token) }
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    requestDelete(token: token, label: token)
                                }
                        }
                        newFormationTile
                            .contentShape(Rectangle())
                            .onTapGesture { showNewFormationOptions = true }
                    }
                    .padding(Spacing.md)
                }
            } else {
                Spacer()
                Text("未选择 drill").foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        }
    }

    private var newFormationTile: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.btPrimary)
            Text("+ 新增球形")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text("空台 / 克隆 · 跳过标定")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: BTRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: BTRadius.sm)
            .stroke(Color.btPrimary.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }

    private func manualFormationTile(token: String, saved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(token)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Text("人工球形")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
            Label("重做", systemImage: "arrow.counterclockwise")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: BTRadius.sm))
        .overlay(alignment: .topTrailing) {
            if saved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.btSuccess)
                    .padding(6)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: BTRadius.sm)
            .stroke(saved ? Color.btSuccess.opacity(0.8) : .white.opacity(0.12), lineWidth: saved ? 2 : 1))
    }

    private func thumbnail(_ url: URL, saved: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.white.opacity(0.06)
            }
            Text(url.lastPathComponent)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .padding(4)
                .background(.black.opacity(0.45))
                .lineLimit(1)
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .overlay(alignment: .topTrailing) {
            if saved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.btSuccess)
                    .padding(6)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: BTRadius.sm)
            .stroke(saved ? Color.btSuccess.opacity(0.8) : .white.opacity(0.12), lineWidth: saved ? 2 : 1))
    }

    private func loadImage(_ url: URL) {
        guard let raw = UIImage(contentsOfFile: url.path) else {
            vm.flash("无法读取图片：\(url.lastPathComponent)", tone: .error)
            return
        }
        vm.image = raw.rotated90Clockwise()
        vm.corners = BallExtractionViewModel.defaultCorners
        vm.marks = []
        vm.activePaletteKey = PositionPlayBall.cueKey
        vm.step = .calibrate
        context.sourceImageURL = url
        context.manualFormationStem = nil
        context.editingSequence = nil
        context.editingLegacyArchive = false
    }

    /// 「改存档」：读回该图已存序列，直接进编排台续接编辑（跳过拍照建球形）。
    private func editArchive(_ url: URL) {
        guard let drill = context.current else { return }
        guard let seq = BatchDrillCatalog.loadSequence(drillId: drill.drillId, imageURL: url) else {
            vm.flash("读取存档失败：\(url.lastPathComponent)", tone: .error)
            return
        }
        context.sourceImageURL = url          // 保存时按同一 token 覆盖原存档
        context.manualFormationStem = nil
        context.confirmedBoard = seq.initial
        context.editingSequence = seq
        context.editingLegacyArchive = false
        goAuthor = true
    }

    /// 「改旧版存档」：旧版单序列（无 `__`、未绑定截图）→ 进编排台续接编辑，保存时覆盖原旧版文件。
    private func editLegacyArchive() {
        guard let drill = context.current else { return }
        guard let url = BatchDrillCatalog.savedSequenceURL(drillId: drill.drillId, token: ""),
              let seq = BatchDrillCatalog.loadSequence(at: url) else {
            vm.flash("读取旧版存档失败：\(drill.drillId)", tone: .error)
            return
        }
        context.sourceImageURL = nil
        context.manualFormationStem = nil
        context.confirmedBoard = seq.initial
        context.editingSequence = seq
        context.editingLegacyArchive = true
        goAuthor = true
    }

    private func presentClonePicker() {
        guard let drill = context.current else { return }
        let items = BatchDrillCatalog.savedFormationSummaries(drillId: drill.drillId)
        guard !items.isEmpty else {
            vm.flash("尚无已存球形可克隆", tone: .info)
            return
        }
        cloneCandidates = items
        showClonePicker = true
    }

    /// 无图新增球形：仿 `editArchive` 直进编排台（跳过标定四步）；`manualNN` 新 token。
    private func startManualFormation(initial: BoardSnapshot) {
        guard let drill = context.current else { return }
        let token = BatchDrillCatalog.nextManualToken(drillId: drill.drillId)
        context.sourceImageURL = nil
        context.manualFormationStem = token
        context.confirmedBoard = initial
        context.editingSequence = nil
        context.editingLegacyArchive = false
        goAuthor = true
    }

    /// 续编已存人工/无图球形：同一 token 覆盖；允许 initial-only。
    private func editManualArchive(token: String) {
        guard let drill = context.current else { return }
        guard let url = BatchDrillCatalog.savedSequenceURL(drillId: drill.drillId, token: token),
              let seq = BatchDrillCatalog.loadSequence(at: url) else {
            vm.flash("读取存档失败：\(token)", tone: .error)
            return
        }
        context.sourceImageURL = nil
        context.manualFormationStem = token
        context.confirmedBoard = seq.initial
        context.editingSequence = seq
        context.editingLegacyArchive = false
        goAuthor = true
    }

    private func requestDelete(token: String, label: String) {
        pendingDelete = (token, label)
        showDeleteConfirm = true
    }

    /// 确认删除：只移除内容库序列 JSON，不动源截图 / drill 课程。
    private func confirmDeleteFormation() {
        guard let drill = context.current, let pending = pendingDelete else { return }
        defer { pendingDelete = nil }
        do {
            let n = try BatchSequenceArchive.deleteArchive(drillId: drill.drillId, token: pending.token)
            context.refreshSaved()
            if n > 0 {
                vm.flash("已删除球形 · \(pending.label)", tone: .success)
            } else {
                vm.flash("未找到可删文件：\(pending.label)", tone: .error)
            }
        } catch {
            vm.flash("删除失败：\(error.localizedDescription)", tone: .error)
        }
    }

    // MARK: - Step 2: calibrate corners

    private func calibrateStep(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            stepHeader("拖动四个角点，贴住台面内沿四角（绿色台呢的角）")
            GeometryReader { geo in
                let fitted = fittedRect(image.size, in: geo.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image).resizable()
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: fitted.midX, y: fitted.midY)
                    quadOverlay(fitted: fitted)
                    ForEach(0..<4, id: \.self) { i in cornerHandle(i, fitted: fitted) }
                    if let active = activeHandle {
                        loupe(image: image, center: point(from: vm.corners[active], in: fitted), fitted: fitted)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding(Spacing.md)
            orientationPicker
            footer {
                secondaryButton("重新选图") { vm.step = .pickPhoto }
                primaryButton("下一步", enabled: vm.calibrationValid) { vm.enterMarkBalls() }
            }
        }
    }

    private var orientationPicker: some View {
        VStack(spacing: 4) {
            Text("离镜头最近的边（照片底边）是：")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("", selection: $vm.orientation) {
                Text("长库（长边）").tag(BallExtractionViewModel.TableOrientation.longRailNear)
                Text("短库（端库）").tag(BallExtractionViewModel.TableOrientation.shortRailNear)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .environment(\.colorScheme, .dark)
    }

    private let calibColor = Color.yellow

    private func quadOverlay(fitted: CGRect) -> some View {
        let pts = vm.corners.map { point(from: $0, in: fitted) }
        return Path { p in
            guard pts.count == 4 else { return }
            p.move(to: pts[0]); p.addLine(to: pts[1]); p.addLine(to: pts[2]); p.addLine(to: pts[3]); p.closeSubpath()
        }
        .stroke(calibColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        .background(
            Path { p in
                guard pts.count == 4 else { return }
                p.move(to: pts[0]); p.addLine(to: pts[1]); p.addLine(to: pts[2]); p.addLine(to: pts[3]); p.closeSubpath()
            }.fill(calibColor.opacity(0.10))
        )
    }

    private func cornerHandle(_ i: Int, fitted: CGRect) -> some View {
        let labels = ["左上", "右上", "右下", "左下"]
        let pos = point(from: vm.corners[i], in: fitted)
        return ZStack {
            Circle().fill(calibColor.opacity(0.25))
                .overlay(Circle().stroke(calibColor, lineWidth: 2)).frame(width: 28, height: 28)
            Circle().fill(calibColor).frame(width: 6, height: 6)
            Text(labels[i]).font(.system(size: 9, weight: .bold)).foregroundStyle(.white).offset(y: -24)
        }
        .position(pos)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    activeHandle = i
                    vm.corners[i] = uv(from: value.location, in: fitted)
                }
                .onEnded { _ in activeHandle = nil }
        )
    }

    // MARK: - Step 3: mark balls

    private func markStep(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            stepHeader("先在下方选球号，再点照片上球的底部；可拖动微调、按 ✕ 删除")
            GeometryReader { geo in
                let fitted = fittedRect(image.size, in: geo.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image).resizable()
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: fitted.midX, y: fitted.midY)
                    quadOverlay(fitted: fitted)
                    ForEach(vm.marks) { mark in markBadge(mark, fitted: fitted) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { e in
                        let p = uv(from: e.location, in: fitted)
                        if (0...1).contains(p.x), (0...1).contains(p.y) { vm.placeMark(at: p) }
                    }
                )
                .overlay(alignment: .trailing) { undoRedoControls }
            }
            .padding(Spacing.md)
            markBottomBar
        }
    }

    private func markBadge(_ mark: BallExtractionViewModel.Mark, fitted: CGRect) -> some View {
        let pos = point(from: mark.uv, in: fitted)
        let isActive = vm.activePaletteKey == mark.key
        return PoolBallFace(key: mark.key, diameter: isActive ? 18 : 14)
            .overlay(Circle().stroke(isActive ? Color.btPrimary : .white.opacity(0.7), lineWidth: isActive ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if isActive {
                    Button { vm.removeMark(id: mark.id) } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                            .foregroundStyle(.white, Color.btDestructive)
                    }
                    .offset(x: 5, y: -5)
                }
            }
            .position(pos)
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        vm.activePaletteKey = mark.key
                        let adjusted = deadZoneTrail(start: value.startLocation, current: value.location)
                        vm.moveMark(id: mark.id, to: uv(from: adjusted, in: fitted))
                    }
                    .onEnded { _ in markDragLockedOffset = nil; vm.endMarkDrag() }
            )
            .onTapGesture { vm.activePaletteKey = mark.key }
    }

    private var markBottomBar: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(spacing: 4) {
                HStack {
                    Text("待标球号").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("已标 \(vm.marks.count) 颗").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                paletteTwoRows(PositionPlayBall.allKeys) { key in markCell(key) }
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 6) {
                columnPrimary("下一步", enabled: !vm.marks.isEmpty) { vm.enterConfirm() }
                columnSecondary("上一步") { vm.step = .calibrate }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(HUDStyle.panelBackground)
        .environment(\.colorScheme, .dark)
    }

    private func markCell(_ key: String) -> some View {
        let marked = vm.marks.contains { $0.key == key }
        let d = BTBallPaletteMetrics.compactDiameter
        return PoolBallFace(key: key, diameter: d)
            .opacity(marked ? 0.28 : 1)
            .overlay(Circle().stroke(vm.activePaletteKey == key ? Color.btPrimary : .clear, lineWidth: 2.5))
            .frame(width: BTBallPaletteMetrics.minimumHitSize,
                   height: BTBallPaletteMetrics.minimumHitSize)
            .contentShape(Rectangle())
            .onTapGesture { vm.activePaletteKey = key }
    }

    // MARK: - Step 4: confirm on 2D table

    private var confirmStep: some View {
        VStack(spacing: 0) {
            stepHeader("拖动微调位置 · 点球后从下方改号 · 球库拖到桌上增球 · 拖回球库删球")
            sceneContainer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(frameReader(id: "scene"))
                .clipped()
                .overlay(alignment: .trailing) { undoRedoControls }
            confirmBottomBar
        }
    }

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            draggableBallNodes: vm.draggableBalls,
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) },
            onDragEndedAt: { node, localPoint in handleTableDragEnd(node: node, localPoint: localPoint) },
            selectableBallNodes: vm.draggableBalls,
            onBallTapped: { vm.selectBall(node: $0) },
            onTableTapped: { _ in vm.deselect() },
            projector: projector
        )
    }

    private var confirmBottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                if let key = vm.selectedKey {
                    Text("已选 \(PositionPlayBall.shortLabel(for: key)) 号 · 拖动球可移位 · 点球库改号")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.btPrimary)
                    Spacer()
                    Button { vm.removeFromTable(key) } label: {
                        Label("移除", systemImage: "trash").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.btDestructive)
                    }
                } else {
                    Text("桌上 \(vm.onTableKeys.count) 颗 · 拖动球可移位 · 点选可改号/移除")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            HStack(alignment: .center, spacing: Spacing.sm) {
                paletteTwoRows(PositionPlayBall.allKeys) { key in confirmCell(key) }
                    .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    columnPrimary("送入编排求解台", enabled: !vm.onTableKeys.isEmpty, height: 36) {
                        context.confirmedBoard = vm.currentSnapshot()
                        goAuthor = true
                    }
                    columnSecondary("重新标记", height: 28) { vm.enterMarkBalls() }
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
        }
        .background(HUDStyle.panelBackground)
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    private func confirmCell(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return BTBallPaletteToken(
            key: key,
            ballDiameter: BTBallPaletteMetrics.compactDiameter,
            isOnTable: onTable,
            isDragging: draggingKey == key,
            allowsDrag: !onTable,
            coordinateSpace: "batchExtract",
            sceneFrame: sceneFrame,
            unproject: { projector.unproject?($0) },
            onTap: {
                if onTable { vm.pulseTableBall(key) }
                else if vm.selectedKey != nil { vm.assignNumber(key) }
                else { vm.addFromPalette(key) }
            },
            onPlace: { world in
                if let world { vm.addFromPalette(key, atWorld: world) }
                else { vm.addFromPalette(key) }
            },
            draggingKey: $draggingKey,
            dragLocation: $dragLocation,
            dragOverTable: $dragOverTable
        )
    }

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard BTBallPaletteDragBack.hitPalette(localPoint: localPoint,
                                               sceneFrame: sceneFrame,
                                               paletteFrame: paletteFrame),
              let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
    }

    // MARK: - Undo / Redo controls

    private var undoRedoControls: some View {
        VStack(spacing: 10) {
            undoRedoButton(system: "arrow.uturn.backward", enabled: vm.canUndo) { vm.undo() }
            undoRedoButton(system: "arrow.uturn.forward", enabled: vm.canRedo) { vm.redo() }
        }
        .padding(.trailing, Spacing.sm)
    }

    private func undoRedoButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(enabled ? 0.9 : 0.25))
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(.white.opacity(enabled ? 0.3 : 0.1), lineWidth: 1))
        }
        .buttonStyle(BTPressableStyle.capsule)
        .disabled(!enabled)
    }

    // MARK: - Footer buttons

    private func footer<Buttons: View>(@ViewBuilder _ buttons: () -> Buttons) -> some View {
        HStack(spacing: Spacing.sm) { buttons() }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(HUDStyle.panelBackground)
            .environment(\.colorScheme, .dark)
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(enabled ? Color.btPrimary : Color.btPrimary.opacity(0.3), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule)
        .disabled(!enabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule)
    }

    // MARK: - Two-row palette + column buttons

    private static let paletteColumns = 8

    private func paletteTwoRows<Cell: View>(_ keys: [String], @ViewBuilder cell: @escaping (String) -> Cell) -> some View {
        let row1 = Array(keys.prefix(Self.paletteColumns))
        let row2 = Array(keys.dropFirst(Self.paletteColumns))
        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: BTBallPaletteMetrics.rowSpacing) {
                paletteRow(row1, cell: cell)
                paletteRow(row2, cell: cell)
            }
            .frame(width: CGFloat(Self.paletteColumns) * BTBallPaletteMetrics.minimumHitSize)
        }
    }

    private func paletteRow<Cell: View>(_ keys: [String], @ViewBuilder cell: @escaping (String) -> Cell) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count { cell(keys[i]) } else {
                        Color.clear.frame(width: BTBallPaletteMetrics.minimumHitSize,
                                          height: BTBallPaletteMetrics.minimumHitSize)
                    }
                }
                .frame(width: BTBallPaletteMetrics.minimumHitSize,
                       height: BTBallPaletteMetrics.minimumHitSize)
            }
        }
    }

    private func columnPrimary(_ title: String, enabled: Bool, tint: Color = .btPrimary,
                               height: CGFloat = 42, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 6)
                .frame(width: 96, height: height)
                .background(enabled ? tint : tint.opacity(0.3), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule).disabled(!enabled)
    }

    private func columnSecondary(_ title: String, height: CGFloat = 42, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 6)
                .frame(width: 96, height: height)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule)
    }

    // MARK: - Photo coordinate helpers

    private func fittedRect(_ imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func uv(from p: CGPoint, in fitted: CGRect) -> CGPoint {
        guard fitted.width > 0, fitted.height > 0 else { return .zero }
        return CGPoint(x: (p.x - fitted.minX) / fitted.width, y: (p.y - fitted.minY) / fitted.height)
    }

    private func point(from uv: CGPoint, in fitted: CGRect) -> CGPoint {
        CGPoint(x: fitted.minX + uv.x * fitted.width, y: fitted.minY + uv.y * fitted.height)
    }

    private func deadZoneTrail(start: CGPoint, current: CGPoint, deadZone: CGFloat = 52) -> CGPoint {
        if let locked = markDragLockedOffset {
            return CGPoint(x: current.x + locked.width, y: current.y + locked.height)
        }
        let dx = current.x - start.x, dy = current.y - start.y
        guard hypot(dx, dy) > deadZone else { return start }
        let locked = CGSize(width: start.x - current.x, height: start.y - current.y)
        markDragLockedOffset = locked
        return CGPoint(x: current.x + locked.width, y: current.y + locked.height)
    }

    private func loupe(image: UIImage, center: CGPoint, fitted: CGRect) -> some View {
        let zoom: CGFloat = 2.6
        let d: CGFloat = 120
        let rel = CGPoint(x: center.x - fitted.minX, y: center.y - fitted.minY)
        let off = CGPoint(x: d / 2 - rel.x * zoom, y: d / 2 - rel.y * zoom)
        return ZStack(alignment: .topLeading) {
            Color.black
            Image(uiImage: image).resizable()
                .frame(width: fitted.width * zoom, height: fitted.height * zoom)
                .offset(x: off.x, y: off.y)
            Path { p in
                p.move(to: CGPoint(x: d / 2 - 10, y: d / 2)); p.addLine(to: CGPoint(x: d / 2 + 10, y: d / 2))
                p.move(to: CGPoint(x: d / 2, y: d / 2 - 10)); p.addLine(to: CGPoint(x: d / 2, y: d / 2 + 10))
            }.stroke(calibColor, lineWidth: 1)
        }
        .frame(width: d, height: d, alignment: .topLeading)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                                   value: [id: geo.frame(in: .named("batchExtract"))])
        }
    }
}
#endif
