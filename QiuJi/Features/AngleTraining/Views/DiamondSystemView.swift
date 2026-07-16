import SwiftUI
import SceneKit

/// 反射解球器 — 2D top-down kick-shot solver.
/// Place the cue & target balls anywhere; the app solves cushion-first kick routes
/// (cue off 1–3 rails into the target) with the real physics engine.
///
/// W4 版面（20260709 翻袋反射页重构方案 §1.2，与翻袋页同构，无袋口点选与切角读数）：
/// 顶部 1 行库数 chip；右缘纯力度柱（力度 = 求解输入）；右下贴边动作列（下一解 / 重置）；
/// 底部球库带（拖入 = 障碍球，真实碰撞体进反解模拟）。
struct DiamondSystemView: View {
    @StateObject private var vm = DiamondSystemViewModel()
    @State private var showInfo = false
    @State private var hasAppeared = false
    @State private var showSpinPad = false

    @State private var projector = TableProjector()

    // 球库拖拽状态（reflection 坐标空间，编排台同款交互）。
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    /// 球库列数（条 17.8：全 16 球位 = 2 行 × 8 列；G8 排球总宽 = 球桌宽）。
    private static let paletteColumns = 8

    /// 固定在桌球（母球 / 黑 8 目标球）：球库位灰显、不可拖、点击脉冲提示（条 17.8）。
    private static func isFixedBall(_ key: String) -> Bool {
        key == PositionPlayBall.cueKey || key == "_8"
    }
    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight = ShotStageMetrics.topRowHeight
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue

    var body: some View {
        GeometryReader { geo in
            let sceneH = max(geo.size.height - Self.topRowHeight - Self.bottomBarHeight, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH)
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topRow
                        .frame(height: Self.topRowHeight)
                    stage(proxy)
                        .frame(height: sceneH)
                    bottomBar(proxy)
                        .frame(height: Self.bottomBarHeight)
                }
                if let key = draggingKey { dragGhost(key) }
            }
        }
        .coordinateSpace(name: "reflection")
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle("反射解球器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            // 条 17.1/17.2/17.7：principal 品牌绿标题 + 副标题承载解描述 / 无解说明（同三解页）。
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(title: "反射解球器", isBusy: vm.isSolving, statusText: vm.statusText)
            }
            // 条 17.9（G19）：i → 三点菜单（原理说明 + 台面网格 + 恢复默认）。
            ToolbarItem(placement: .topBarTrailing) {
                BTSolverMoreMenu(scene: vm.scene,
                                 onPrinciple: { showInfo = true },
                                 onReset: { vm.reset() })
                    .disabled(vm.isPlaying)
            }
        }
        .sheet(isPresented: $showInfo) {
            ReflectionSolverInfoSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
            }
        }
    }

    // MARK: - Top row（SPEC §8.4：1 行 = 模式切换 + 库数 chip；自由模式库数隐藏，§1.3）

    private var topRow: some View {
        HStack(spacing: Spacing.sm) {
            BTAimModeToggleButton(isFree: vm.mode == .free,
                                  solvedLabel: "求解", solvedIcon: "target") {
                vm.toggleMode()
            }
            .accessibilityIdentifier("solver.mode")
            if vm.mode == .solve {
                cushionPicker
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.2), value: vm.currentIndex)
        .animation(.easeInOut(duration: 0.2), value: vm.mode)   // §1.3 顶部行过渡。
        .disabled(vm.isPlaying)          // 演示/击球中锁顶部控件（W5/W6）。
        .opacity(vm.isPlaying ? 0.42 : 1)
    }

    private var cushionPicker: some View {
        BTChipRow(
            options: ["自动"] + vm.cushionOptions.map { "\($0)库" },
            selection: Binding(
                get: { vm.selectedCushions ?? 0 },
                set: { vm.selectCushions($0 == 0 ? nil : $0) }
            ),
            scrollable: false
        )
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer

            if proxy.isValid {
                // 左缘瞄准刻度轮（W6 自由模式细调，T-P18-43）。
                if vm.mode == .free {
                    BTAimWheel(onNudge: { vm.nudgeFreeAim(byDegrees: $0) })
                        .btStageFrame(proxy.aimWheelFrame())
                        .allowsHitTesting(!vm.isPlaying)
                }

                // 右缘仪表柱：求解 = 纯力度柱（力度 = 求解输入，改力度重求解）；
                // 自由 = 完整仪表柱（打点盘置顶 + 力度柱，§1.3）。两模式共享同一力度值。
                BTShotInstrumentColumn(
                    spinX: vm.spinX, spinY: vm.spinY,
                    onSpinTap: vm.mode == .free ? { showSpinPad = true } : nil,
                    velocity: $vm.reflectionPower,
                    range: Double(CushionReflectionSettings.minPower)
                        ... Double(CushionReflectionSettings.maxPower)
                )
                .btStageFrame(proxy.instrumentFrame())
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("solver.power")
                .disabled(vm.isPlaying)
                .opacity(vm.isPlaying ? 0.42 : 1)

                // 右下贴边动作列：求解 = 击打/下一解/重置（回放中切单「停止」，W5）；
                // 自由 = 击球/上一杆/回放（W6）。
                actionColumn
                    .btStageFrame(proxy.bottomTrailingFrame(size: CGSize(
                        width: ShotStageMetrics.actionColumnWidth, height: 106)))

                // 左下：自由 = 「恢复球形」；求解 = 「下一解」（条 17.4：下一解移到左侧）。
                if vm.mode == .free {
                    restoreButton
                        .btStageFrame(proxy.bottomLeadingFrame(size: CGSize(width: 52, height: 46)))
                } else {
                    nextSolutionButton
                        .btStageFrame(proxy.bottomLeadingFrame(size: CGSize(width: 52, height: 46)))
                }
            }

            // 打点盘浮层（自由模式，编排台同款 ADR-P11-09）。
            if showSpinPad {
                BTSpinPadOverlay(spinX: $vm.spinX, spinY: $vm.spinY,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.solutionCount)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.hasSolution)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.mode)   // §1.3 过渡。
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .environment(\.colorScheme, .dark)
    }

    /// 左下「恢复球形」（W6）：回最近求解快照，切回求解命中缓存直显。
    private var restoreButton: some View {
        Button {
            vm.restoreSolveSnapshot()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                Text("恢复球形")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(vm.canRestoreSnapshot ? Color.btPrimary : .white.opacity(0.35))
            .frame(width: 52, height: 46)
            .btHudGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!vm.canRestoreSnapshot || vm.isPlaying)
        .accessibilityIdentifier("solver.restore")
        .accessibilityLabel("恢复球形")
    }

    /// 贴边动作列（条 17.5：求解态收敛为 击打/上一杆/回放，与自由态、其他击打页同规范）。
    /// 条 17.3：删演示中「停止」与「重置」（演示不可中断；重置移入三点菜单「恢复默认」）。
    /// 求解态「上一杆」按 G17 全量恢复（球形 + 库数 + 解集 + 档位 + 力度）。
    @ViewBuilder
    private var actionColumn: some View {
        if vm.mode == .free {
            BTShotActionColumn(
                strikeTitle: vm.isPlaying ? "击球中" : "击球",
                strikeEnabled: vm.canFreeStrike,
                onStrike: { vm.freeStrike() },
                undoEnabled: !vm.isPlaying && vm.canUndoShot,
                onUndo: { vm.undoLastShot() },
                playbackEnabled: !vm.isPlaying && vm.canPlaybackShot,
                onPlayback: { vm.replayLastShot() }
            )
        } else {
            BTShotActionColumn(
                strikeTitle: vm.isPlaying ? "击球中" : "击打",
                strikeEnabled: vm.canStrike,
                onStrike: { vm.strike() },
                undoEnabled: !vm.isPlaying && vm.canUndoSolve,
                onUndo: { vm.undoSolveShot() },
                playbackEnabled: !vm.isPlaying && vm.canReplaySolve,
                onPlayback: { vm.replaySolveShot() }
            )
        }
    }

    /// 左下「下一解」（条 17.4）：求解态切换多解；单解禁用（对应自由态「恢复球形」位置带）。
    private var nextSolutionButton: some View {
        Button {
            vm.nextSolution()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                Text("下一解")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(vm.solutionCount > 1 ? Color.btPrimary : .white.opacity(0.35))
            .frame(width: 52, height: 46)
            .btHudGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(vm.solutionCount <= 1 || vm.isPlaying)
        .accessibilityIdentifier("solver.nextSolution")
        .accessibilityLabel("下一解")
    }

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(.topDown2DRotated),
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            draggableBallNodes: vm.draggableNodes,
            onDragBegan: { node in vm.dragBegan(node: node) },
            onDragMoved: { node, world in vm.handleDrag(node: node, to: world) },
            onDragEnded: { node in vm.dragEnded(node: node) },
            onDragEndedAt: { node, localPoint in
                handleTableDragEnd(node: node, localPoint: localPoint)
            },
            onAimNudged: { vm.nudgeFreeAim(byDegrees: $0) },   // 自由模式瞄准相对调整（G13）。
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    // MARK: - Bottom bar（W4 球库带：拖入 = 障碍球真实碰撞体，编排台同款交互）

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        // 条 17.8：球库含全 16 球位（母球 / 黑 8 固定在桌 → 球库位灰显）。
        let keys = PositionPlayBall.allKeys
        let row1 = Array(keys.prefix(Self.paletteColumns))
        let row2 = Array(keys.dropFirst(Self.paletteColumns))
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        let columnWidth = max(libraryWidth / CGFloat(Self.paletteColumns), 1)
        return VStack(spacing: 3) {
            paletteRow(row1, columnWidth: columnWidth)
            paletteRow(row2, columnWidth: columnWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUDStyle.panelBackground)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
        .disabled(vm.isPlaying)          // 演示中锁球库（W5）。
        .opacity(vm.isPlaying ? 0.55 : 1)
    }

    private func paletteRow(_ keys: [String], columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count {
                        ballToken(keys[i])
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth, height: 38)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ballToken(_ key: String) -> some View {
        // 母球 / 黑 8 = 固定在桌（灰显、不可拖、点击脉冲）；障碍球 = 现行增删（条 17.8）。
        let onTable = Self.isFixedBall(key) || vm.onTableObstacleKeys.contains(key)
        return PoolBallFace(key: key, diameter: 36)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 38, height: 38)
            .contentShape(Circle())
            .opacity(draggingKey == key ? 0.3 : (onTable ? 0.3 : 1))
            .accessibilityIdentifier("paletteBall_\(key)")
            .onTapGesture {
                if Self.isFixedBall(key) { vm.pulsePaletteBall(key) }
                else if vm.onTableObstacleKeys.contains(key) { vm.pulseTableBall(key) }
                else { vm.placeObstacle(key) }
            }
            .gesture(paletteDrag(key), including: onTable ? .subviews : .all)
    }

    private func paletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("reflection"))
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
                    vm.placeObstacle(key, atWorld: world)
                } else {
                    vm.placeObstacle(key)
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

    // 在桌障碍球拖回球库带 → 移除（编排台同款）。
    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard sceneFrame != .zero, paletteFrame != .zero else { return }
        let point = CGPoint(x: localPoint.x + sceneFrame.minX, y: localPoint.y + sceneFrame.minY)
        guard paletteFrame.contains(point),
              let key = vm.scene.ballKey(for: node),
              vm.onTableObstacleKeys.contains(key) else { return }
        vm.removeObstacle(key)
    }

    // MARK: - Frame reader

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                                   value: [id: geo.frame(in: .named("reflection"))])
        }
    }
}

// MARK: - Principle sheet

private struct ReflectionSolverInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    principleBlock(
                        title: "这是什么",
                        body: "一个通用的反射解球器：把母球和目标球放到台面任意位置，用真实物理引擎反解母球经过 1 库、2 库、3 库反弹后碰到目标球的走位路线。"
                    )
                    principleBlock(
                        title: "原理：入射角 = 反射角",
                        body: "「入射角 = 反射角」是台球走位的几何基础，著名的颗星 / 钻石公式（CB − TR = FR）正是该反射模型在「母球贴库、平行库」特例下的算术近似。求解先用「镜像展开」枚举候选撞库顺序，真实路线在此之上由物理引擎逐段模拟：低力度下反射「偏短」（库呢吸收）、滑动到滚动的状态过渡都会如实反映。"
                    )
                    principleBlock(
                        title: "操作",
                        body: "拖动母球（白）与目标球（黑）到任意位置（松手后自动求解）；顶部选「自动」按好打程度排序，或手选 1–3 库。白色实线即母球解线、金点是碰库点、虚线是碰到后两球的真实去向。多条解时点「下一解」切换；点「击打」演示这一杆（出杆 → 真实物理回放 → 自动复位，可重复击打）；点「重置」恢复默认摆球。"
                    )
                    principleBlock(
                        title: "障碍球",
                        body: "从底部球库把球拖上桌即成障碍球（拖回球库移除）。障碍球是真实碰撞体：母球绕库途中撞上障碍的候选路线会被物理引擎自然淘汰，不做几何近似过滤。"
                    )
                    principleBlock(
                        title: "自由模式",
                        body: "顶部切到「自由」即可亲手试打：拖动台面或左侧刻度轮瞄准，点右上打点盘设加塞，拖力度柱调力度，点「击球」真实物理开打——球停在哪是哪。选中解会以暗虚线留在台面供你照着练。「上一杆」撤销上次击打、「回放」重看、左下「恢复球形」回到最近一次求解的球形，切回「求解」立即显示原解。"
                    )
                    principleBlock(
                        title: "真实物理求解与力度",
                        body: "每条解都由完整物理引擎反解并复核——画面即物理。力度是求解输入：拖动右侧力度柱（m/s）会重新求解，力度不足够绕库时该路线会自动消失；该设置与翻袋解球器共享并会被记住。"
                    )
                    principleBlock(
                        title: "好打优先",
                        body: "多条解按「好打程度」排序：综合首库入射角、库数、路线长度评出难度档（易 / 中 / 难），再对每条解做小幅瞄准与力度扰动测出「容错」——容错越高，执行误差下仍能碰到目标球的概率越大。"
                    )
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("反射解球原理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        // §1.6：Z7 浮出层统一暗材质（T-P18-49）。
        .preferredColorScheme(.dark)
    }

    private func principleBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.btHeadline).foregroundStyle(.btText)
            Text(body).font(.btSubheadline).foregroundStyle(.btTextSecondary)
        }
    }
}
