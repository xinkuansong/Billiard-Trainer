//
//  RackGeneratorView.swift
//  QiuJi
//
//  P17「球形生成器」页面（ADR-P17-01）。布局语言对齐走位编排台 / 拍照建球形：
//  黑底、顶部玩法分段、主区 2D 真台、底部力度/打点 + 开球/换一局 + 交付。
//
//  交互：选玩法 → 拖母球定开球点（自动锁顶球瞄准，绿色短杆示意方向）→ 设力度/打点 →
//  「开球」跑真实物理 livesim 并回放散开 → 停稳后「送入编排台 / 思路训练器」消费球形。
//

import SwiftUI
import SceneKit

struct RackGeneratorView: View {
    @StateObject private var vm = RackGeneratorViewModel()
    @State private var hasAppeared = false
    @State private var showSpinPad = false

    @State private var goComposer = false
    @State private var goSilu = false
    @State private var goPlanThree = false
    @State private var deliveredBoard: BoardSnapshot?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                gamePicker
                sceneContainer
                bottomBar
            }
            if showSpinPad { spinPadOverlay }
        }
        .navigationTitle("球形生成器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { navStatus }
        }
        .navigationDestination(isPresented: $goComposer) {
            PositionPlayComposerView(initialBoard: deliveredBoard)
        }
        .navigationDestination(isPresented: $goSilu) {
            SiluTrainerView(initialBoard: deliveredBoard)
        }
        .navigationDestination(isPresented: $goPlanThree) {
            PlanThreeView(initialBoard: deliveredBoard)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
            }
        }
    }

    // MARK: - Nav status

    private var navStatus: some View {
        VStack(spacing: 1) {
            Text("球形生成器")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if vm.phase == .computing { ProgressView().controlSize(.mini).tint(.white) }
                Text(vm.resultSummary ?? vm.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Game picker

    private var gamePicker: some View {
        HStack(spacing: Spacing.sm) {
            BTChipRow(
                options: ["中式八球", "9球"],
                selection: Binding(
                    get: { vm.gameKind == .eightBall ? 0 : 1 },
                    set: { vm.gameKind = $0 == 0 ? .eightBall : .zhuifen }
                ),
                scrollable: false
            )
            .disabled(vm.isBusy)

            if vm.gameKind == .zhuifen {
                BTChipRow(
                    options: RackGeneratorViewModel.zhuifenOptions.map { "\($0)" },
                    selection: Binding(
                        get: { RackGeneratorViewModel.zhuifenOptions.firstIndex(of: vm.zhuifenBalls) ?? 3 },
                        set: { vm.zhuifenBalls = RackGeneratorViewModel.zhuifenOptions[$0] }
                    ),
                    scrollable: false
                )
                .disabled(vm.isBusy)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            draggableBallNodes: vm.draggableCue,
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            hintRow
            HStack(alignment: .center, spacing: Spacing.md) {
                shotControls
                actionColumn
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .environment(\.colorScheme, .dark)
    }

    private var hintRow: some View {
        HStack(spacing: Spacing.sm) {
            Text(vm.statusText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// 力度滑杆 + 打点状态图标（点开打点盘）。
    private var shotControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: Spacing.sm) {
                Button { showSpinPad.toggle() } label: {
                    BTSpinMiniIcon(spinX: vm.spinX, spinY: vm.spinY, diameter: 34)
                }
                .buttonStyle(.plain)
                .disabled(vm.isBusy)
                .accessibilityLabel("打点")

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(PowerDisplay.name(vm.power)) \(String(format: "%.1f", vm.power)) m/s")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Slider(value: $vm.power, in: RackGeneratorViewModel.powerRange)
                        .tint(.btPrimary)
                        .disabled(vm.isBusy)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 常驻按钮列（#9）：开球 / 送入编排台 / 送入思路 / 换一局 始终在位，
    /// 不可用时变灰禁用，避免阶段切换时整列按钮增删导致布局跳变。
    private var actionColumn: some View {
        VStack(spacing: 5) {
            deliverButton("开球", tint: vm.canBreak ? .btPrimary : .white.opacity(0.12)) {
                vm.breakNow()
            }
            .disabled(!vm.canBreak)
            deliverButton("送入编排台", tint: vm.canDeliver ? .btPrimary : .white.opacity(0.12)) {
                deliveredBoard = vm.deliveredBoard(); goComposer = true
            }
            .disabled(!vm.canDeliver)
            deliverButton("送入思路训练器", tint: vm.canDeliver ? .btAccent : .white.opacity(0.12)) {
                deliveredBoard = vm.deliveredBoard(); goSilu = true
            }
            .disabled(!vm.canDeliver)
            deliverButton("送入打一走二想三", tint: vm.canDeliver ? .btAccent : .white.opacity(0.12)) {
                deliveredBoard = vm.deliveredBoard(); goPlanThree = true
            }
            .disabled(!vm.canDeliver)
            deliverButton("换一局", tint: .white.opacity(0.14)) { vm.nextRack() }
                .disabled(vm.isBusy)
        }
    }

    private func deliverButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 138, height: 32)
                .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Spin pad overlay

    private var spinPadOverlay: some View {
        VStack {
            Spacer()
            BTSpinPadCard(spinX: $vm.spinX, spinY: $vm.spinY) { showSpinPad = false }
                .frame(maxWidth: 240)
                .padding(.bottom, 150)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview("Dark") {
    NavigationStack { RackGeneratorView() }
        .preferredColorScheme(.dark)
}
