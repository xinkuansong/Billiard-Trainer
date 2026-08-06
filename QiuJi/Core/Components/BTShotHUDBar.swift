import SwiftUI

/// 本杆击球参数 HUD 条：打点（`BTSpinMiniIcon` 同款球面，无卡片底）+ 百分比读数 +
/// 力度水位条 + 档名/数值（ADR-P11-13）。
///
/// **单一真源**：离线出片（`SequenceVideoExporter` 底部 HUD 条）与 App 内 live 预览
/// （`DrillSceneView` 球桌下方）共用本组件，杜绝两处样式漂移。
///
/// 设计基准 80pt 条高，`k` 为等比系数：
/// - 导出：`k = hudStripHeight / 80`，`powerBarWidth = 220 * k`，`fixedWidth = true`
///   （`ImageRenderer` 离屏渲染需按理想宽度展开，否则文本被压窄竖排折行）。
/// - App 内窄容器：`powerBarWidth = nil` 让力度条占满剩余宽度，`fixedWidth = false`。
struct BTShotHUDBar: View {
    /// +左塞 / −右塞
    let spinX: Double
    /// +高杆 / −低杆
    let spinY: Double
    /// 杆头速度 m/s
    let velocity: Double
    var k: CGFloat = 1
    /// 力度条宽度；`nil` = 占满剩余宽度。
    var powerBarWidth: CGFloat? = 220
    var fixedWidth: Bool = true

    var body: some View {
        if fixedWidth {
            content.fixedSize()
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 28 * k) {
            HStack(spacing: 12 * k) {
                // 真实比例（ADR-P11-13）：教学素材上的打点可照搬到真球，
                // 红斑位置/大小与打点盘同一几何，含打滑极限虚线圈。
                BTSpinMiniIcon(spinX: spinX, spinY: spinY, diameter: 56 * k, trueScale: true)
                // 打点/力度 = 方案量值 → 金（HUD 仪表玻璃语法，T-P18-45）。
                Text(SpinDisplay.readout(spinX: spinX, spinY: spinY))
                    .font(.system(size: 20 * k, weight: .bold, design: .rounded))
                    .foregroundStyle(HUDStyle.valueAdjustable)
                    .monospacedDigit()
            }
            HStack(spacing: 12 * k) {
                powerBar
                Text("\(PowerDisplay.name(velocity)) \(String(format: "%.1f", velocity)) m/s")
                    .font(.system(size: 20 * k, weight: .bold, design: .rounded))
                    .foregroundStyle(HUDStyle.valueAdjustable)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .padding(.horizontal, 24 * k)
        .frame(height: 80 * k)
    }

    @ViewBuilder
    private var powerBar: some View {
        if let width = powerBarWidth {
            // 固定宽度路径（导出）：不经 GeometryReader，离屏渲染尺寸稳定。
            Capsule()
                .fill(.white.opacity(0.16))
                .frame(width: width, height: 8 * k)
                .overlay(alignment: .leading) {
                    // 刻度语法：力度水位 = 金色填充。
                    Capsule()
                        .fill(HUDStyle.tickIndicator)
                        .frame(width: width * powerFraction)
                }
        } else {
            Capsule()
                .fill(.white.opacity(0.16))
                .frame(height: 8 * k)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(HUDStyle.tickIndicator)
                            .frame(width: geo.size.width * powerFraction)
                    }
                    .frame(height: 8 * k)
                }
        }
    }

    /// 填充比例与编排台力度滑条同量程（`ShotTuning.velocityRange` 单一真源）。
    private var powerFraction: CGFloat {
        let r = ShotTuning.velocityRange
        return CGFloat(min(max((velocity - r.lowerBound) / (r.upperBound - r.lowerBound), 0), 1))
    }
}
