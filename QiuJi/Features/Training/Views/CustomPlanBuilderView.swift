import SwiftUI
import SwiftData

struct CustomPlanBuilderView: View {
    @StateObject private var viewModel: CustomPlanBuilderViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showActivateConfirm = false
    @State private var savedPlanId: UUID?

    init(editingPlanId: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: CustomPlanBuilderViewModel(editingPlanId: editingPlanId))
    }

    var body: some View {
        List {
            planInfoSection
            drillsSection
        }
        .listStyle(.insetGrouped)
        .background(.btBG)
        .scrollContentBackground(.hidden)
        .navigationTitle(viewModel.isEditing ? "编辑计划" : "新建计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                saveMenu
            }
        }
        .sheet(isPresented: $viewModel.showDrillPicker) {
            DrillPickerSheet { content in
                viewModel.addDrill(content)
            }
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

    // MARK: - Plan Info Section

    private var planInfoSection: some View {
        Section {
            HStack {
                Text("名称")
                    .font(.btBody)
                    .foregroundStyle(.btText)
                TextField("我的训练计划", text: $viewModel.name)
                    .font(.btBody)
                    .multilineTextAlignment(.trailing)
            }

            Stepper(value: $viewModel.sessionsPerWeek, in: 1...7) {
                HStack {
                    Text("每周训练")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                    Spacer()
                    Text("\(viewModel.sessionsPerWeek) 天")
                        .font(.btBodyMedium)
                        .foregroundStyle(.btPrimary)
                }
            }
        } header: {
            Text("计划信息")
        }
    }

    // MARK: - Drills Section

    private var drillsSection: some View {
        Section {
            if viewModel.drillItems.isEmpty {
                emptyDrillsPlaceholder
            } else {
                ForEach($viewModel.drillItems) { $item in
                    drillRow(item: $item)
                }
                .onDelete { viewModel.removeDrills(at: $0) }
                .onMove { viewModel.moveDrills(from: $0, to: $1) }
            }

            Button {
                viewModel.showDrillPicker = true
            } label: {
                Label("添加训练项目", systemImage: "plus.circle.fill")
                    .font(.btBody)
                    .foregroundStyle(.btPrimary)
            }
        } header: {
            HStack {
                Text("训练项目")
                Spacer()
                if !viewModel.drillItems.isEmpty {
                    Text("\(viewModel.drillItems.count) 项")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }
            }
        }
    }

    private var emptyDrillsPlaceholder: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 32))
                .foregroundStyle(.btTextTertiary)
            Text("还没有添加训练项目")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            Text("点击下方按钮从动作库选择")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Drill Row

    private func drillRow(item: Binding<CustomDrillItem>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(item.wrappedValue.nameZh)
                .font(.btHeadline)
                .foregroundStyle(.btText)
                .lineLimit(1)

            HStack(spacing: Spacing.xl) {
                Stepper(value: item.sets, in: 1...20) {
                    HStack(spacing: Spacing.xs) {
                        Text("组数")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                        Text("\(item.wrappedValue.sets)")
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(.btPrimary)
                            .frame(minWidth: 20)
                    }
                }

                Stepper(value: item.ballsPerSet, in: 1...50) {
                    HStack(spacing: Spacing.xs) {
                        Text("球数")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                        Text("\(item.wrappedValue.ballsPerSet)")
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(.btPrimary)
                            .frame(minWidth: 20)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Save Menu

    private var saveMenu: some View {
        Menu {
            Button {
                if let planId = viewModel.save(context: modelContext) {
                    savedPlanId = planId
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
