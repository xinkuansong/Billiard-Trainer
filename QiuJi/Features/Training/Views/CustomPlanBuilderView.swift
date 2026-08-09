import SwiftUI
import SwiftData

// MARK: - Drill Settings Target

private struct DrillSettingsTarget: Identifiable {
    let id: UUID
    let index: Int
    let name: String
    /// 每球形轮数（唯一可调项，v31 R4）。
    let rounds: Int
    /// 内容派生的只读展开：球形数与各球形每轮球数。
    let groups: [ResolvedDose.Group]
    let unitLabel: String
}

// MARK: - Custom Plan Builder View

struct CustomPlanBuilderView: View {
    @StateObject private var viewModel: CustomPlanBuilderViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showActivateConfirm = false
    @State private var drillSettingsTarget: DrillSettingsTarget?

    init(editingPlanId: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: CustomPlanBuilderViewModel(editingPlanId: editingPlanId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                planInfoCard
                weeklyConfigCard
                drillListSection
                addDrillButton
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle(viewModel.isEditing ? "编辑计划" : "新建计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                saveMenu
            }
        }
        .sheet(isPresented: $viewModel.showDrillPicker) {
            DrillPickerSheet(
                initiallySelectedIds: Set(viewModel.drillItems.map(\.drillId)),
                onSelect: { content in
                    withAnimation(BTMotion.springPanel) {
                        viewModel.addDrill(content)
                    }
                },
                onDeselect: { content in
                    withAnimation(BTMotion.springPanel) {
                        viewModel.removeDrill(drillId: content.id)
                    }
                }
            )
        }
        .sheet(item: $drillSettingsTarget) { target in
            DrillSettingsSheet(
                drillName: target.name,
                initialRounds: target.rounds,
                groups: target.groups,
                unitLabel: target.unitLabel,
                onSave: { newRounds in
                    withAnimation(BTMotion.springPanel) {
                        viewModel.updateRounds(at: target.index, rounds: newRounds)
                    }
                },
                onDelete: {
                    withAnimation(BTMotion.springPanel) {
                        viewModel.removeDrill(at: target.index)
                    }
                }
            )
        }
        .alert("保存失败", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = viewModel.saveError {
                Text(error)
            }
        }
        .alert("保存并激活", isPresented: $showActivateConfirm) {
            Button("取消", role: .cancel) {}
            Button("保存并激活") {
                saveAndActivate()
            }
        } message: {
            Text("保存计划并将其设为当前激活计划？这将替换当前已激活的计划。")
        }
        .task {
            viewModel.loadExistingPlan(context: modelContext)
        }
    }

    // MARK: - Plan Info Card

    private var planInfoCard: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.btBGTertiary)
                    .frame(width: 40, height: 40)
                Image(systemName: BTIcon.pencil)
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                TextField("我的训练计划", text: $viewModel.name)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)

                Text("\(viewModel.totalSetsCount) 组  \(viewModel.drillItems.count) 动作")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Weekly Config Card

    private var weeklyConfigCard: some View {
        HStack {
            Text("每周训练天数")
                .font(.btBodyMedium)
                .foregroundStyle(.btText)

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button {
                    withAnimation(BTMotion.easeFast) {
                        viewModel.sessionsPerWeek = max(1, viewModel.sessionsPerWeek - 1)
                    }
                } label: {
                    Image(systemName: BTIcon.minus)
                        .font(.btFootnote14)
                        .fontWeight(.medium)
                        .foregroundStyle(.btPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BTPressableStyle.capsule)
                .disabled(viewModel.sessionsPerWeek <= 1)

                Text("\(viewModel.sessionsPerWeek)")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                    .frame(minWidth: 16)
                    .contentTransition(.numericText())

                Button {
                    withAnimation(BTMotion.easeFast) {
                        viewModel.sessionsPerWeek = min(7, viewModel.sessionsPerWeek + 1)
                    }
                } label: {
                    Image(systemName: BTIcon.plus)
                        .font(.btFootnote14)
                        .fontWeight(.medium)
                        .foregroundStyle(.btPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BTPressableStyle.capsule)
                .disabled(viewModel.sessionsPerWeek >= 7)
            }
            .padding(Spacing.xs)
            .background(.btBGTertiary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Drill List Section

    private var drillListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("训练项目")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, Spacing.xs)

            if viewModel.drillItems.isEmpty {
                emptyDrillsPlaceholder
            } else {
                List {
                    ForEach(Array(viewModel.drillItems.enumerated()), id: \.element.id) { index, item in
                        drillRow(item: item, index: index)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.btBGSecondary)
                    }
                    .onMove { source, destination in
                        viewModel.moveDrills(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .scrollDisabled(true)
                .frame(height: CGFloat(viewModel.drillItems.count) * 80)
                .animation(BTMotion.springPanel, value: viewModel.drillItems.count)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
        }
    }

    private func drillRow(item: CustomDrillItem, index: Int) -> some View {
        HStack(spacing: Spacing.lg) {
            BTDrillListThumbnail(drillId: item.drillId)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.nameZh)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                    .lineLimit(1)

                Text(item.volumeText)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            Button {
                drillSettingsTarget = DrillSettingsTarget(
                    id: item.id,
                    index: index,
                    name: item.nameZh,
                    rounds: item.rounds,
                    groups: item.groups,
                    unitLabel: item.unitLabel
                )
            } label: {
                Image(systemName: BTIcon.menuCircle)
                    .font(.btBody)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BTPressableStyle.capsule)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var emptyDrillsPlaceholder: some View {
        // F-PL-14: reuse BTEmptyState; keep「添加训练项目」as separate section CTA below.
        BTEmptyState(
            icon: BTIcon.emptyDoc,
            title: "还没有添加训练项目",
            subtitle: "点击下方按钮从动作库选择"
        )
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Add Drill Button

    private var addDrillButton: some View {
        Button {
            viewModel.showDrillPicker = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: BTIcon.plusCircleFilled)
                    .font(.btTitle2)
                    .fontWeight(.regular)
                    .foregroundStyle(.btPrimary)
                Text("添加训练项目")
                    .font(.btBody)
                    .foregroundStyle(.btPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .buttonStyle(BTPressableStyle.row)
    }

    // MARK: - Save Menu

    private var saveMenu: some View {
        Menu {
            Button {
                if viewModel.save(context: modelContext) != nil {
                    dismiss()
                }
            } label: {
                Label("仅保存", systemImage: "square.and.arrow.down")
            }

            Button {
                showActivateConfirm = true
            } label: {
                Label("保存并激活", systemImage: "play.circle")
            }
        } label: {
            Text("保存")
                .fontWeight(.semibold)
        }
        .disabled(!viewModel.canSave)
    }

    // MARK: - Actions

    private func saveAndActivate() {
        if let planId = viewModel.save(context: modelContext) {
            viewModel.activate(planId: planId, context: modelContext)
            dismiss()
        }
    }
}

// MARK: - Drill Settings Sheet

private struct DrillSettingsSheet: View {
    let drillName: String
    @State var rounds: Int
    /// 逐球形每轮球数（内容真源派生，用户不可改，v31 R4）。
    let groups: [ResolvedDose.Group]
    let unitLabel: String
    let onSave: (Int) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(drillName: String, initialRounds: Int, groups: [ResolvedDose.Group], unitLabel: String,
         onSave: @escaping (Int) -> Void, onDelete: @escaping () -> Void) {
        self.drillName = drillName
        self._rounds = State(initialValue: initialRounds)
        self.groups = groups
        self.unitLabel = unitLabel
        self.onSave = onSave
        self.onDelete = onDelete
    }

    /// 每球形每轮球数（球形顺序同内容 `perFormation`）。
    private var ballsPerRound: [Int] { groups.map(\.ballsPerRound) }

    private var totalBalls: Int { rounds * ballsPerRound.reduce(0, +) }

    var body: some View {
        NavigationStack {
            List {
                Section("训练设置") {
                    Stepper(value: $rounds, in: 1...20) {
                        HStack {
                            Text("每球形轮数")
                                .font(.btBody)
                                .foregroundStyle(.btText)
                            Spacer()
                            Text("\(rounds)")
                                .font(.btBodyMedium)
                                .foregroundStyle(.btPrimary)
                        }
                    }

                    HStack {
                        Text(groups.count > 1 ? "每轮球数（逐球形）" : "每轮球数")
                            .font(.btBody)
                            .foregroundStyle(.btText)
                        Spacer()
                        Text(ballsPerRound.map(String.init).joined(separator: " / "))
                            .font(.btBodyMedium)
                            .foregroundStyle(.btTextSecondary)
                    }

                    HStack {
                        Text("总\(unitLabel)数")
                            .font(.btBody)
                            .foregroundStyle(.btText)
                        Spacer()
                        Text("\(totalBalls)")
                            .font(.btBodyMedium)
                            .foregroundStyle(.btTextSecondary)
                    }
                }

                Section {
                    Text("每轮球数由动作内容决定，不可在计划里改（改量请调轮数）。")
                        .font(.btFootnote)
                        .foregroundStyle(.btTextTertiary)
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("移除此训练", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(drillName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onSave(rounds)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        // F-OV-01: form/settings sheet — medium (+ large) + drag indicator.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Previews

#Preview("New Plan") {
    NavigationStack {
        CustomPlanBuilderView()
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
}

#Preview("Dark") {
    NavigationStack {
        CustomPlanBuilderView()
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .preferredColorScheme(.dark)
}
