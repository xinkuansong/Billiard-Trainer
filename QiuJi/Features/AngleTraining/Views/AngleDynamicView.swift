import SwiftUI
import SceneKit

struct AngleDynamicView: View {
    @StateObject private var vm = AngleDynamicViewModel()
    private var is3D: Bool { vm.cameraMode == .perspective3D }

    /// 首拖提示（T-P18-51）：首次进页不知道球能拖，提示常驻到第一次拖动为止（跨启动记忆）。
    @AppStorage(PracticeStorageKey.angleDynamicHasDraggedOnce) private var hasDraggedOnce = false

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "角度与瞄准", identifier: "angleDynamic",
            title: {
                BTTeachingFiveCharacterTitle(words: "角度\n瞄准", middleCharacter: "与", identifier: "angleDynamic")
            }, leftContent: { _ in primaryMetricChip }, status: { overlayLayer },
            onFirstDrag: { hasDraggedOnce = true })
    }

    // MARK: - Floating overlays (status banner only — all metrics live in the top chip)

    /// F-OV-03 / OV-疑3: bottom HUD status is a **persistent teaching state**,
    /// not an ephemeral flash. Do **not** migrate to shared `BTToast` (top capsule).
    private var overlayLayer: some View {
        VStack {
            Spacer()
            if let banner = statusBannerText {
                statusBanner(text: banner.0, icon: banner.1, tint: banner.2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .animation(BTMotion.easeInOutChrome, value: statusBannerKey)
        .allowsHitTesting(false)
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

    // MARK: - Status banner (bottom)

    private var statusBannerKey: String {
        if vm.isDragging { return "drag" }
        if !hasDraggedOnce { return "firstDrag" }
        if vm.selectedPocketIndex < 0 { return "hint" }
        if !vm.isFeasible { return "infeasible:\(vm.infeasibleReason)" }
        return ""
    }

    /// Returns text/icon/tint when a banner should appear; nil otherwise.
    private var statusBannerText: (String, String, Color)? {
        if vm.isDragging {
            return ("拖动中…", "hand.draw.fill", .btPrimary)
        }
        if !hasDraggedOnce && !is3D {
            return ("母球和目标球都可以拖动，指标实时联动", "hand.draw", .btPrimary)
        }
        if vm.selectedPocketIndex < 0 {
            return ("点击袋口选择目标", "scope", .white.opacity(0.7))
        }
        if !vm.isFeasible {
            return (vm.infeasibleReason, "exclamationmark.triangle.fill", .btDestructive)
        }
        return nil
    }

    private func statusBanner(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
            Text(text)
                .font(.btSubheadlineMedium)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }
}


#Preview("Light") { NavigationStack { AngleDynamicView() } }
#Preview("Dark") { NavigationStack { AngleDynamicView() }.preferredColorScheme(.dark) }
