//
//  BallExtractionView.swift
//  QiuJi
//
//  拍照建球形（P15 阶段 1，ADR-P15-01）。布局/交互语言对齐走位编排台：
//  黑底、顶部提示行、主区（照片或 2D 真台）、底部球库 + 操作。
//
//  四步向导：① 选图 → ② 拖四角标定（解单应）→ ③ 照片上标球与号码
//  （经 H 映射到台面系）→ ④ 2D 真台人工确认（拖动/改号/增删）→ 产出
//  `BoardSnapshot` 送走位编排台。人工确认是一等公民：每一步用户都能改定。
//

import SwiftUI
import PhotosUI
import SceneKit

struct BallExtractionView: View {
    @StateObject private var vm = BallExtractionViewModel()

    @State private var photoItem: PhotosPickerItem?
    @State private var activeHandle: Int?

    /// 建球形拖动：死区破区后锁定的恒定错位（nil = 尚未破区）。
    /// 一次性闸门，破区后球标 1:1 跟随手指、反向拖动保留间距。`.onEnded` 清空。
    @State private var markDragLockedOffset: CGSize?

    // 确认页（场景）状态
    @State private var projector = TableProjector()
    @State private var cameraMode = AngleTrainingScene.CameraMode.topDown2DRotated
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    // 送编排台 / 思路训练器 / 打一走二想三（T-P18-51 三目的地）
    @State private var goComposer = false
    @State private var goSilu = false
    @State private var goPlanThree = false
    @State private var confirmedBoard: BoardSnapshot?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .id(vm.step)
                .transition(.opacity)
            if let key = draggingKey { dragGhost(key) }
            banner
        }
        .animation(BTMotion.springPanel, value: vm.step)
        .coordinateSpace(name: "extract")
        .navigationTitle("拍照建球形")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // 标题统一品牌绿（SPEC §8.3）：.toolbarColorScheme(.dark) 会把系统标题渲染成白色，
        // 须自带 principal 绿标题（与思路训练器等场景页同款）。
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("拍照建球形")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.btPrimary)
            }
        }
        .navigationDestination(isPresented: $goComposer) {
            PositionPlayComposerView(initialBoard: confirmedBoard)
        }
        .navigationDestination(isPresented: $goSilu) {
            SiluTrainerView(initialBoard: confirmedBoard)
        }
        .navigationDestination(isPresented: $goPlanThree) {
            PlanThreeView(initialBoard: confirmedBoard)
        }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .onPreferenceChange(ExtractFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
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
            // 步骤指示（T-P18-51）：进度条 + 「第 n 步 · 步骤名」，用户始终知道身在四步中的哪一步。
            HStack(spacing: 6) {
                ForEach(BallExtractionViewModel.Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= vm.step.rawValue ? Color.btPrimary : Color.white.opacity(0.15))
                        .frame(height: 3)
                }
            }
            Text("第 \(vm.step.rawValue + 1) 步 / 共 4 步 · \(vm.step.title)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.btPrimary)
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

    // MARK: - Step 1: pick photo

    private var pickStep: some View {
        VStack(spacing: Spacing.lg) {
            stepHeader("拍摄或选择一张球桌照片")
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.btPrimary)
            VStack(spacing: 6) {
                Text("拍照建球形")
                    .font(.btTitle).foregroundStyle(.white)
                Text("拍摄或选择一张球桌照片，自动提取球号与位置。\n建议从球桌一端较高处拍摄，光照均匀、球尽量分散。")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                    Text("选择照片")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(height: 48).frame(maxWidth: 220)
                .background(Color.btPrimary, in: Capsule())
            }
            .buttonStyle(BTPressableStyle.capsule)
            Spacer()
        }
        .padding(Spacing.lg)
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
                    ForEach(0..<4, id: \.self) { i in
                        cornerHandle(i, fitted: fitted)
                    }
                    if let active = activeHandle {
                        // 居中放置：避免拖左上角袋口时放大镜（原贴左上角）与手指/角点互相遮挡。
                        loupe(image: image,
                              center: point(from: vm.corners[active], in: fitted),
                              fitted: fitted)
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

    /// 标定线/角点配色：用黄色，与绿色台呢、蓝色台边都有高对比，且不与红/黄球混淆位置
    /// （线在台呢边沿，不会落到球面上）。绿色（btPrimary）会和台呢糊在一起，故弃用。
    private let calibColor = Color.yellow

    private func quadOverlay(fitted: CGRect) -> some View {
        let pts = vm.corners.map { point(from: $0, in: fitted) }
        return Path { p in
            guard pts.count == 4 else { return }
            p.move(to: pts[0])
            p.addLine(to: pts[1]); p.addLine(to: pts[2]); p.addLine(to: pts[3])
            p.closeSubpath()
        }
        .stroke(calibColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        .background(
            Path { p in
                guard pts.count == 4 else { return }
                p.move(to: pts[0]); p.addLine(to: pts[1])
                p.addLine(to: pts[2]); p.addLine(to: pts[3]); p.closeSubpath()
            }.fill(calibColor.opacity(0.10))
        )
    }

    private func cornerHandle(_ i: Int, fitted: CGRect) -> some View {
        let labels = ["左上", "右上", "右下", "左下"]
        let pos = point(from: vm.corners[i], in: fitted)
        return ZStack {
            Circle().fill(calibColor.opacity(0.25))
                .overlay(Circle().stroke(calibColor, lineWidth: 2))
                .frame(width: 28, height: 28)
            Circle().fill(calibColor).frame(width: 6, height: 6)
            Text(labels[i])
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -24)
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
                    ForEach(vm.marks) { mark in
                        markBadge(mark, fitted: fitted)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { e in
                            let p = uv(from: e.location, in: fitted)
                            if (0...1).contains(p.x), (0...1).contains(p.y) {
                                vm.placeMark(at: p)
                            }
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
        // 标记球做小，密集球区也能逐个点到；✕ 只在选中（active）时出现，减少互相遮挡。
        return PoolBallFace(key: mark.key, diameter: isActive ? 18 : 14)
            .overlay(Circle().stroke(isActive ? Color.btPrimary : .white.opacity(0.7),
                                     lineWidth: isActive ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if isActive {
                    Button { vm.removeMark(id: mark.id) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
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
                    .onEnded { _ in
                        markDragLockedOffset = nil
                        vm.endMarkDrag()
                    }
            )
            .onTapGesture { vm.activePaletteKey = mark.key }
    }

    private var markBottomBar: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(spacing: 4) {
                HStack {
                    Text("待标球号")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("已标 \(vm.marks.count) 颗")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
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
        return PoolBallFace(key: key, diameter: 32)
            .opacity(marked ? 0.28 : 1)
            .overlay(Circle().stroke(vm.activePaletteKey == key ? Color.btPrimary : .clear,
                                     lineWidth: 2.5))
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.btPrimary)
                    Spacer()
                    Button { vm.removeFromTable(key) } label: {
                        Label("移除", systemImage: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.btDestructive)
                    }
                } else {
                    Text("桌上 \(vm.onTableKeys.count) 颗 · 拖动球可移位 · 点选可改号/移除")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)

            HStack(alignment: .center, spacing: Spacing.sm) {
                paletteTwoRows(PositionPlayBall.allKeys) { key in confirmCell(key) }
                    .frame(maxWidth: .infinity)

                // 送入三目的地（T-P18-51）收进一个菜单，按钮列不撑高底栏。
                VStack(spacing: 6) {
                    Menu {
                        Button {
                            confirmedBoard = vm.currentSnapshot()
                            goComposer = true
                        } label: { Label("自由走位", systemImage: "scope") }
                        Button {
                            confirmedBoard = vm.currentSnapshot()
                            goSilu = true
                        } label: { Label("思路训练", systemImage: "lightbulb") }
                        Button {
                            confirmedBoard = vm.currentSnapshot()
                            goPlanThree = true
                        } label: { Label("打一走二想三", systemImage: "3.circle") }
                    } label: {
                        Text("送入…")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 42)
                            .background(vm.onTableKeys.isEmpty ? Color.btPrimary.opacity(0.3)
                                                               : Color.btPrimary,
                                        in: Capsule())
                    }
                    .buttonStyle(BTPressableStyle.capsule)
                    .disabled(vm.onTableKeys.isEmpty)
                    columnSecondary("重新标记", height: 36) { vm.enterMarkBalls() }
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
        // #5a：球库常显全部 16 颗；在桌球变暗、不可拖，点击在桌球 = 桌上对应球放大脉冲提示位置。
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
        DragGesture(minimumDistance: 12, coordinateSpace: .named("extract"))
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
                    vm.addFromPalette(key, atWorld: world)
                } else {
                    vm.addFromPalette(key)
                }
            }
    }

    @ViewBuilder
    private func dragGhost(_ key: String) -> some View {
        PoolBallFace(key: key, diameter: 42)
            .overlay(Circle().stroke(dragOverTable ? Color.btSuccess : .white.opacity(0.4),
                                     lineWidth: dragOverTable ? 2.5 : 1))
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

    // MARK: - Undo / Redo controls（球桌右侧悬浮箭头）

    private var undoRedoControls: some View {
        VStack(spacing: 10) {
            undoRedoButton(system: "arrow.uturn.backward", enabled: vm.canUndo) { vm.undo() }
            undoRedoButton(system: "arrow.uturn.forward", enabled: vm.canRedo) { vm.redo() }
        }
        .padding(.trailing, Spacing.sm)
    }

    private func undoRedoButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .bold))
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
            .background(HUDStyle.panelBackground)
            .environment(\.colorScheme, .dark)
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(enabled ? Color.btPrimary : Color.btPrimary.opacity(0.3), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule)
        .disabled(!enabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule)
    }

    // MARK: - Two-row palette + column buttons（对齐走位编排台底部布局）

    /// 球库固定槽位列数：第一行 8、第二行 8（与编排台一致）。
    private static let paletteColumns = 8

    /// 把球键铺成两行固定槽位（左对齐补位，空槽透明占位保持网格稳定）。
    private func paletteTwoRows<Cell: View>(
        _ keys: [String], @ViewBuilder cell: @escaping (String) -> Cell
    ) -> some View {
        let row1 = Array(keys.prefix(Self.paletteColumns))
        let row2 = Array(keys.dropFirst(Self.paletteColumns))
        return VStack(spacing: 4) {
            paletteRow(row1, cell: cell)
            paletteRow(row2, cell: cell)
        }
    }

    private func paletteRow<Cell: View>(
        _ keys: [String], @ViewBuilder cell: @escaping (String) -> Cell
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count { cell(keys[i]) }
                    else { Color.clear.frame(width: 32, height: 32) }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func columnPrimary(_ title: String, enabled: Bool, tint: Color = .btPrimary,
                               height: CGFloat = 42, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .frame(width: 96, height: height)
                .background(enabled ? tint : tint.opacity(0.3), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule)
        .disabled(!enabled)
    }

    private func columnSecondary(_ title: String, height: CGFloat = 42, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .frame(width: 96, height: height)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(BTPressableStyle.capsule)
    }

    @ViewBuilder
    private var banner: some View {
        if let msg = vm.message {
            VStack {
                Text(msg)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
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

    /// 图像在容器内 aspect-fit 后占据的矩形。
    private func fittedRect(_ imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// 容器内点 → 图像归一化 uv ∈ [0,1]。
    private func uv(from p: CGPoint, in fitted: CGRect) -> CGPoint {
        guard fitted.width > 0, fitted.height > 0 else { return .zero }
        return CGPoint(x: (p.x - fitted.minX) / fitted.width,
                       y: (p.y - fitted.minY) / fitted.height)
    }

    /// 图像归一化 uv → 容器内点。
    private func point(from uv: CGPoint, in fitted: CGRect) -> CGPoint {
        CGPoint(x: fitted.minX + uv.x * fitted.width,
                y: fitted.minY + uv.y * fitted.height)
    }

    /// 拖动死区错位：与 `AngleSceneView` 的拖球手感一致。死区是一次性闸门——
    /// 手指从 `start` 拖出、前 `deadZone` 点球标不动；越过后**锁定**恒定错位
    /// （`markDragLockedOffset`），此后球标 1:1 跟随手指、反向拖动保留间距，
    /// 不会按起点重新检测死区。使手指始终在球标前方、不遮挡（球标仅 14–18pt）。
    private func deadZoneTrail(start: CGPoint, current: CGPoint, deadZone: CGFloat = 52) -> CGPoint {
        if let locked = markDragLockedOffset {
            return CGPoint(x: current.x + locked.width, y: current.y + locked.height)
        }
        let dx = current.x - start.x
        let dy = current.y - start.y
        guard hypot(dx, dy) > deadZone else { return start }
        let locked = CGSize(width: start.x - current.x, height: start.y - current.y)
        markDragLockedOffset = locked
        return CGPoint(x: current.x + locked.width, y: current.y + locked.height)
    }

    // MARK: - Loupe（放大镜）

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
        // 放大图远大于 d×d；必须按 topLeading 取景（默认 .center 会把内容居中，
        // 使 off 偏移失效、放大镜采样偏离选中角点约半张图）。
        .frame(width: d, height: d, alignment: .topLeading)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: ExtractFramePreference.self,
                                   value: [id: geo.frame(in: .named("extract"))])
        }
    }

    // MARK: - Photo loading

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run {
                    vm.image = img
                    vm.corners = BallExtractionViewModel.defaultCorners
                    vm.marks = []
                    vm.activePaletteKey = PositionPlayBall.cueKey
                    vm.step = .calibrate
                }
            }
        }
    }
}

// MARK: - Frame preference

private struct ExtractFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("Dark") {
    NavigationStack { BallExtractionView() }
        .preferredColorScheme(.dark)
}
