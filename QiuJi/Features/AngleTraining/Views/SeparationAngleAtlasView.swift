import SwiftUI
import SceneKit

/// Eight real post-collision trajectories in the shared daily teaching shell.
struct SeparationAngleAtlasView: View {
    @StateObject private var vm = SeparationAngleAtlasViewModel()

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "分离角图谱", identifier: "separationAngleAtlas",
            velocity: $vm.velocity,
            information: teachingInformation, usesStandardTitle: true,
            title: { EmptyView() },
            leftContent: { size in
                VStack(spacing: 4) {
                    VStack(spacing: 2) {
                        Text("切角").font(.btCaption2).foregroundStyle(.white.opacity(0.6))
                        Text(vm.selectedTargetKey == nil ? "—" : "\(Int(vm.cutAngleDegrees.rounded()))°")
                            .font(.btFootnote.weight(.medium).monospacedDigit())
                    }.accessibilityElement(children: .combine)
                        .accessibilityIdentifier("separationAngleAtlas.metrics")
                    SeparationAngleAtlasSpinLegend(enabledTracks: vm.enabledTracks, onToggle: vm.toggleTrack)
                    Text("\(vm.enabledTracks.count)/8").font(.btCaption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .accessibilityIdentifier("separationAngleAtlas.trackCount")
                }.frame(height: min(size.height, 320)).foregroundStyle(.white)
            }, status: { EmptyView() }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
            .onChange(of: vm.velocity) { _, _ in vm.onVelocityChanged() }
            .overlay(alignment: .bottom) {
                if ProcessInfo.processInfo.arguments.contains("-y3.uiHooks") {
                    HStack {
                        Button("高力度") { vm.velocity = 5.5 }.accessibilityIdentifier("y3.bumpPower")
                        Text(String(format: "%.1f", vm.lastParallelSimMs)).accessibilityIdentifier("y3.parallelSimMs")
                    }.font(.btCaption)
                }
            }
            .background(Color.clear.accessibilityIdentifier("separationAngleAtlas.root"))
    }
    private var teachingInformation: [BTTeachingInformation] {
        guard let text = vm.statusText, !vm.isComputing else { return [] }
        return [.init(text: text, identifier: "separationAngleAtlas.status")]
    }

}

// MARK: - Left-edge 8 mini spin pads (A2 / D-v15-2)

/// 左缘竖列 8 个迷你打点盘：每档一点、与 `trackColors`/spinY 档一一对应。
/// 高杆（index 0）在上 → 低杆（index 7）在下；点选开关对应色轨迹。
private struct SeparationAngleAtlasSpinLegend: View {
    let enabledTracks: Set<Int>
    let onToggle: (Int) -> Void

    private let levels = SeparationAngleAtlasGeometry.spinYLevels()
    private let pull = Double(CuePhysics.tipContactPullFactor)
    private let miscue = Double(CuePhysics.miscueLimitFraction)

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let rowHeight = min(32, max(16, (geo.size.height - spacing * CGFloat(levels.count - 1)) / CGFloat(levels.count)))
            VStack(spacing: spacing) {
                ForEach(0..<levels.count, id: \.self) { i in
                    miniPad(index: i, size: min(28, rowHeight), rowHeight: rowHeight)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("separationAngleAtlas.spinLegend")
        .accessibilityLabel("八档高低杆，高杆在上低杆在下，至少留一档")
    }

    private func miniPad(index: Int, size: CGFloat, rowHeight: CGFloat) -> some View {
        let sy = Double(levels[index])
        let placeY = sy / pull
        let ballR = size / 2 - 1
        let placementLimit = miscue / pull
        let dy = -CGFloat(placeY) * ballR
        let enabled = enabledTracks.contains(index)
        return Button {
            onToggle(index)
        } label: {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(white: 0.86)],
                                         center: .init(x: 0.38, y: 0.34),
                                         startRadius: 1, endRadius: ballR * 2))
                    .overlay(Circle().stroke(.white.opacity(enabled ? 0.45 : 0.22), lineWidth: 0.8))
                Circle()
                    .stroke(.black.opacity(0.28), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
                    .frame(width: ballR * 2 * CGFloat(placementLimit),
                           height: ballR * 2 * CGFloat(placementLimit))
                Circle()
                    .fill(Color(uiColor: SeparationAngleAtlasGeometry.trackColor(at: index)))
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 0.8))
                    .frame(width: max(size * 0.22, 4), height: max(size * 0.22, 4))
                    .offset(y: dy)
            }
            .frame(width: size, height: size)
            .frame(width: 44, height: rowHeight)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("separationAngleAtlas.spinLegend.\(index)")
        .accessibilityLabel("高低杆第\(index + 1)档")
        .accessibilityAddTraits(enabled ? .isSelected : [])
        .accessibilityValue(enabled ? "已选" : "未选")
    }
}

#Preview("Light") { NavigationStack { SeparationAngleAtlasView() } }
#Preview("Dark") { NavigationStack { SeparationAngleAtlasView() }.preferredColorScheme(.dark) }
