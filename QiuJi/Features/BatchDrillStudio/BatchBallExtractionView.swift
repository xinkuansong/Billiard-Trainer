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

    private var drill: BatchDrill? { context.current }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            if let key = draggingKey { dragGhost(key) }
            banner
        }
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
        .onPreferenceChange(BatchExtractFramePreference.self) { frames in
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
        switch vm.step {
        case .pickPhoto: pickStep
        case .calibrate: if let img = vm.image { calibrateStep(img) }
        case .markBalls: if let img = vm.image { markStep(img) }
        case .confirm: confirmStep
        }
    }

    // MARK: - Step header

    private func stepHeader(_ hint: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(BallExtractionViewModel.Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= vm.step.rawValue ? Color.btPrimary : Color.white.opacity(0.15))
                        .frame(height: 3)
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
            stepHeader("每张图 = 一个球形；选一张建球形（自动顺时针旋 90°）。打勾＝已存，可重做覆盖；不想做的直接跳过")
            if let drill {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm),
                                        GridItem(.flexible(), spacing: Spacing.sm)],
                              spacing: Spacing.sm) {
                        ForEach(drill.imageURLs, id: \.self) { url in
                            Button { loadImage(url) } label: {
                                thumbnail(url, saved: drill.isImageSaved(url))
                            }
                            .buttonStyle(.plain)
                        }
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
                    .foregroundStyle(.white, Color.green)
                    .padding(6)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: BTRadius.sm)
            .stroke(saved ? Color.green.opacity(0.8) : .white.opacity(0.12), lineWidth: saved ? 2 : 1))
    }

    private func loadImage(_ url: URL) {
        guard let raw = UIImage(contentsOfFile: url.path) else {
            vm.message = "无法读取图片：\(url.lastPathComponent)"
            return
        }
        vm.image = raw.rotated90Clockwise()
        vm.corners = BallExtractionViewModel.defaultCorners
        vm.marks = []
        vm.activePaletteKey = PositionPlayBall.cueKey
        vm.step = .calibrate
        context.sourceImageURL = url
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
        .background(Color(white: 0.11))
        .environment(\.colorScheme, .dark)
    }

    private func markCell(_ key: String) -> some View {
        let marked = vm.marks.contains { $0.key == key }
        return PoolBallFace(key: key, diameter: 32)
            .opacity(marked ? 0.28 : 1)
            .overlay(Circle().stroke(vm.activePaletteKey == key ? Color.btPrimary : .clear, lineWidth: 2.5))
            .frame(width: 32, height: 32)
            .contentShape(Circle())
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
        .background(Color(white: 0.11))
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    private func confirmCell(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return PoolBallFace(key: key, diameter: 32)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .opacity(draggingKey == key ? 0.3 : (onTable ? 0.3 : 1))
            .onTapGesture {
                if onTable { vm.pulseTableBall(key) }
                else if vm.selectedKey != nil { vm.assignNumber(key) }
                else { vm.addFromPalette(key) }
            }
            .gesture(paletteDrag(key), including: onTable ? .subviews : .all)
    }

    private func paletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .named("batchExtract"))
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
                if let world = projector.unproject?(local) { vm.addFromPalette(key, atWorld: world) }
                else { vm.addFromPalette(key) }
            }
    }

    @ViewBuilder
    private func dragGhost(_ key: String) -> some View {
        PoolBallFace(key: key, diameter: 42)
            .overlay(Circle().stroke(dragOverTable ? Color.btSuccess : .white.opacity(0.4), lineWidth: dragOverTable ? 2.5 : 1))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .position(dragLocation)
            .allowsHitTesting(false)
    }

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard sceneFrame != .zero, paletteFrame != .zero else { return }
        let p = CGPoint(x: localPoint.x + sceneFrame.minX, y: localPoint.y + sceneFrame.minY)
        guard paletteFrame.contains(p), let key = vm.scene.ballKey(for: node) else { return }
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
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Footer buttons

    private func footer<Buttons: View>(@ViewBuilder _ buttons: () -> Buttons) -> some View {
        HStack(spacing: Spacing.sm) { buttons() }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color(white: 0.11))
            .environment(\.colorScheme, .dark)
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(enabled ? Color.btPrimary : Color.btPrimary.opacity(0.3), in: Capsule())
        }
        .buttonStyle(.plain).disabled(!enabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Two-row palette + column buttons

    private static let paletteColumns = 8

    private func paletteTwoRows<Cell: View>(_ keys: [String], @ViewBuilder cell: @escaping (String) -> Cell) -> some View {
        let row1 = Array(keys.prefix(Self.paletteColumns))
        let row2 = Array(keys.dropFirst(Self.paletteColumns))
        return VStack(spacing: 4) { paletteRow(row1, cell: cell); paletteRow(row2, cell: cell) }
    }

    private func paletteRow<Cell: View>(_ keys: [String], @ViewBuilder cell: @escaping (String) -> Cell) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count { cell(keys[i]) } else { Color.clear.frame(width: 32, height: 32) }
                }
                .frame(maxWidth: .infinity)
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
        .buttonStyle(.plain).disabled(!enabled)
    }

    private func columnSecondary(_ title: String, height: CGFloat = 42, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 6)
                .frame(width: 96, height: height)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var banner: some View {
        if let msg = vm.message {
            VStack {
                Text(msg).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
                    .background(Color.btDestructive, in: Capsule())
                    .padding(.top, 60)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: vm.message)
        }
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
            Color.clear.preference(key: BatchExtractFramePreference.self,
                                   value: [id: geo.frame(in: .named("batchExtract"))])
        }
    }
}

private struct BatchExtractFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
#endif
