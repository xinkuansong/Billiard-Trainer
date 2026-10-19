import SwiftUI
import SceneKit

struct AngleDynamicView: View {
    @StateObject private var vm = AngleDynamicViewModel()
    private var is3D: Bool { vm.cameraMode == .perspective3D }

    /// 首拖提示（T-P18-51）：首次进页不知道球能拖，提示常驻到第一次拖动为止（跨启动记忆）。
    @AppStorage(PracticeStorageKey.angleDynamicHasDraggedOnce) private var hasDraggedOnce = false

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "角度与瞄准", identifier: "angleDynamic", preferencePage: .angleDynamic,
            leftControlGroup: .information,
            displayMenuItems: [
                .init(id: "angleDynamic.aimLine", title: "瞄准线", selected: vm.showsAimLine,
                      action: { vm.showsAimLine.toggle() }),
                .init(id: "angleDynamic.potLine", title: "进球线", selected: vm.showsPotLine,
                      action: { vm.showsPotLine.toggle() }),
                .init(id: "angleDynamic.ghost3D", title: "3D 假想球", selected: vm.showsGhost3D,
                      action: { vm.showsGhost3D.toggle() }),
                .init(id: "angleDynamic.aimPipe", title: "瞄准管道", selected: vm.showsAimPipe,
                      action: { vm.showsAimPipe.toggle() }),
                .init(id: "angleDynamic.potPipe", title: "进球管道", selected: vm.showsPotPipe,
                      action: { vm.showsPotPipe.toggle() })
            ],
            information: teachingInformation, usesStandardTitle: true,
            title: { EmptyView() }, leftContent: { _ in primaryMetricChip }, status: { EmptyView() },
            onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) },
            onFirstDrag: { hasDraggedOnce = true })
        #if DEBUG
        .overlay(alignment: .bottom) {
            if DailyLayoutProbe.enabled {
                Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
                    .accessibilityElement().accessibilityIdentifier("angleDynamic.layoutState")
                    .accessibilityValue("target=\(vm.selectedTargetKey ?? "none") pocket=\(vm.selectedPocketIndex) aim=\(vm.showsAimLine) pot=\(vm.showsPotLine) ghost=\(vm.showsGhost3D) aimPipe=\(vm.showsAimPipe) potPipe=\(vm.showsPotPipe)")
            }
        }
        #endif
    }

    /// Teaching guidance remains visible for its underlying state; changing its
    /// placement must not turn first-drag guidance into a timed toast.
    private var teachingInformation: [BTTeachingInformation] {
        guard let text = statusText else { return [] }
        return [.init(text: text, identifier: "angleDynamic.status")]
    }

    // MARK: - Primary metric chip (常驻：角度 / 厚度图示 / d/R / 横移 / 偏移 一排展示)

    private var primaryMetricChip: some View {
        let enabled = vm.selectedTargetKey != nil && vm.selectedPocketIndex >= 0
        return VStack(spacing: 14) {
            teachingReadout("切角", value: enabled ? "\(Int(vm.cutAngleDegrees.rounded()))°" : "—")
            VStack(spacing: 3) {
                ThicknessOverlapIcon(cutAngle: enabled ? vm.cutAngleDegrees : 0).frame(width: 26, height: 14)
                Text(enabled ? vm.thicknessName : "—").font(.btCaption)
            }
            teachingReadout("d/R", value: enabled ? String(format: "%.2f", vm.dOverR) : "—")
            teachingReadout("横移", value: enabled ? String(format: "%.1fmm", vm.displacementMM) : "—")
            teachingReadout("偏移", value: enabled ? String(format: "%.0f%%", vm.offsetPercent) : "—")
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("angleDynamic.metrics")
    }

    private func teachingReadout(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.btCaption2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.btFootnote.weight(.medium).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.8)
        }.accessibilityElement(children: .combine)
    }

    private var statusText: String? {
        if vm.isDragging { return nil }
        if !hasDraggedOnce && !is3D { return "母球和目标球都可以拖动，指标实时联动" }
        if vm.selectedPocketIndex < 0 { return "点击袋口选择目标" }
        if !vm.isFeasible { return vm.infeasibleReason }
        return nil
    }

}


#Preview("Light") { NavigationStack { AngleDynamicView() } }
#Preview("Dark") { NavigationStack { AngleDynamicView() }.preferredColorScheme(.dark) }
