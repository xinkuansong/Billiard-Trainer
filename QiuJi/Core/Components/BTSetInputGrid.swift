import SwiftUI

// MARK: - Data Model

struct DrillSetData: Identifiable {
    let id: Int
    var madeBalls: Int
    var targetBalls: Int
    var isCompleted: Bool
    var isWarmup: Bool

    init(id: Int, madeBalls: Int = 0, targetBalls: Int = 15, isCompleted: Bool = false, isWarmup: Bool = false) {
        self.id = id
        self.madeBalls = madeBalls
        self.targetBalls = targetBalls
        self.isCompleted = isCompleted
        self.isWarmup = isWarmup
    }
}

// MARK: - BTSetInputGrid

struct BTSetInputGrid: View {
    @Binding var sets: [DrillSetData]
    var onAddSet: () -> Void
    var onComplete: (Int) -> Void
    var onDeleteSet: ((Int) -> Void)? = nil

    private var activeIndex: Int? {
        sets.firstIndex(where: { !$0.isCompleted })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().foregroundStyle(.btSeparator)

            if sets.isEmpty {
                emptyState
            } else {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, setData in
                    SetRow(
                        setData: $sets[index],
                        rowState: rowState(for: index),
                        onComplete: { onComplete(index) },
                        onDelete: onDeleteSet != nil ? { onDeleteSet?(index) } : nil
                    )
                    if index < sets.count - 1 {
                        Divider()
                            .foregroundStyle(.btSeparator)
                            .padding(.leading, Spacing.lg)
                    }
                }
            }

            addButton
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 32)
            Text("进球")
                .frame(width: 52)
            Text("总球")
                .frame(width: 52)
            Spacer()
            Image(systemName: "checkmark")
                .frame(width: 44)
            Image(systemName: "ellipsis")
                .frame(width: 44)
        }
        .font(.btCaption)
        .foregroundStyle(.btTextSecondary)
        .frame(height: 36)
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "tray")
                .font(.btStatNumber)
                .fontWeight(.regular)
                .foregroundStyle(.btTextTertiary)
            Text("还没有组数")
                .font(.btFootnote)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: onAddSet) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus")
                Text("添加一组")
            }
            .font(.btCallout)
            .foregroundStyle(.btPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加一组")
    }

    // MARK: - Row State

    enum RowState {
        case completed, active, pending
    }

    func rowState(for index: Int) -> RowState {
        if sets[index].isCompleted { return .completed }
        if index == activeIndex { return .active }
        return .pending
    }
}

// MARK: - Set Row

private struct SetRow: View {
    @Binding var setData: DrillSetData
    let rowState: BTSetInputGrid.RowState
    let onComplete: () -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var madeBallsText: Binding<String> {
        Binding(
            get: { setData.madeBalls > 0 ? "\(setData.madeBalls)" : "" },
            set: { newValue in
                if let val = Int(newValue), val >= 0 {
                    setData.madeBalls = val
                } else if newValue.isEmpty {
                    setData.madeBalls = 0
                }
            }
        )
    }

    private var targetBallsText: Binding<String> {
        Binding(
            get: { "\(setData.targetBalls)" },
            set: { newValue in
                if let val = Int(newValue), val > 0 {
                    setData.targetBalls = val
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            setNumberColumn
            madeBallsColumn
            targetBallsColumn
            Spacer()
            checkColumn
            menuColumn
        }
        .frame(height: 48)
        .padding(.horizontal, Spacing.sm)
        .background(rowState == .completed ? Color.btPrimaryMuted : Color.clear)
        .overlay(alignment: .leading) {
            if rowState == .active {
                Rectangle()
                    .fill(Color.btPrimary)
                    .frame(width: 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第\(setData.id)组, \(setData.madeBalls)/\(setData.targetBalls)球")
    }

    private var setNumberColumn: some View {
        Group {
            if setData.isWarmup {
                Text("热")
                    .font(.btCaption2)
                    .fontWeight(.black)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.btWarning)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("\(setData.id)")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .frame(width: 32)
    }

    private var inputCellFill: Color {
        if rowState == .completed { return Color.btBGSecondary }
        return colorScheme == .dark ? Color.btBGTertiary : Color.btBGSecondary
    }

    private var madeBallsColumn: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: rowState == .active ? 1.5 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(inputCellFill)
                )
            if setData.isCompleted {
                Text("\(setData.madeBalls)")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            } else {
                TextField("-", text: madeBallsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
        }
        .frame(width: 44, height: 36)
        .padding(.horizontal, 4)
    }

    private var targetBallsColumn: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.btSeparator, lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(inputCellFill)
                )
            if setData.isCompleted {
                Text("\(setData.targetBalls)")
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
            } else {
                TextField("", text: targetBallsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .frame(width: 44, height: 36)
        .padding(.horizontal, 4)
    }

    private var checkColumn: some View {
        Button(action: onComplete) {
            ZStack {
                if setData.isCompleted {
                    Circle()
                        .fill(Color.btPrimary)
                    Image(systemName: "checkmark")
                        .font(.btCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .stroke(Color.btSeparator, lineWidth: 1.5)
                }
            }
            .frame(width: 24, height: 24)
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(setData.isCompleted ? "已完成" : "标记完成")
    }

    @ViewBuilder
    private var menuColumn: some View {
        if let deleteFn = onDelete {
            Menu {
                Button(role: .destructive, action: deleteFn) {
                    Label("删除此组", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.btFootnote14)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("更多操作")
        } else {
            Image(systemName: "ellipsis")
                .font(.btFootnote14)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 44, height: 44)
                .accessibilityLabel("更多操作")
        }
    }

    private var borderColor: Color {
        switch rowState {
        case .active: return .btPrimary
        case .completed: return .btSeparator
        case .pending: return .btSeparator
        }
    }
}

// MARK: - RowState conformance for external use
extension BTSetInputGrid.RowState: Sendable {}

// MARK: - Preview

#Preview("BTSetInputGrid Light") {
    SetInputGridPreview()
        .background(Color.btBG)
}

#Preview("BTSetInputGrid Dark") {
    SetInputGridPreview()
        .background(Color.btBG)
        .preferredColorScheme(.dark)
}

#Preview("BTSetInputGrid Empty") {
    SetInputGridEmptyPreview()
        .background(Color.btBG)
}

private struct SetInputGridPreview: View {
    @State private var sets: [DrillSetData] = [
        DrillSetData(id: 1, madeBalls: 15, targetBalls: 15, isCompleted: true),
        DrillSetData(id: 2, madeBalls: 12, targetBalls: 15, isCompleted: true),
        DrillSetData(id: 3, madeBalls: 14, targetBalls: 15),
        DrillSetData(id: 4, targetBalls: 15),
        DrillSetData(id: 5, targetBalls: 15),
    ]

    var body: some View {
        BTSetInputGrid(
            sets: $sets,
            onAddSet: { sets.append(DrillSetData(id: sets.count + 1, targetBalls: 15)) },
            onComplete: { sets[$0].isCompleted.toggle() }
        )
        .padding(Spacing.lg)
    }
}

private struct SetInputGridEmptyPreview: View {
    @State private var sets: [DrillSetData] = []

    var body: some View {
        BTSetInputGrid(
            sets: $sets,
            onAddSet: { sets.append(DrillSetData(id: 1, targetBalls: 15)) },
            onComplete: { _ in }
        )
        .padding(Spacing.lg)
    }
}
