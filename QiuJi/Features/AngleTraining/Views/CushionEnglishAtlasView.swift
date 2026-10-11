import SwiftUI
import SceneKit

/// Eight real side-spin cushion trajectories in the shared daily teaching shell.
struct CushionEnglishAtlasView: View {
    @StateObject private var vm = CushionEnglishAtlasViewModel()

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "加塞吃库图谱", identifier: "cushionEnglishAtlas",
            velocity: $vm.velocity, spinHeight: $vm.spinY,
            teachingNote: CushionEnglishAtlasViewModel.honestyFootnote,
            information: teachingInformation, usesStandardTitle: true,
            title: { EmptyView() },
            leftContent: { size in
                VStack(spacing: 4) {
                    VStack(spacing: 2) {
                        Text("切角").font(.btCaption2).foregroundStyle(.white.opacity(0.6))
                        Text(vm.selectedTargetKey == nil ? "—" : "\(Int(vm.cutAngleDegrees.rounded()))°")
                            .font(.btFootnote.weight(.medium).monospacedDigit())
                    }.accessibilityElement(children: .combine)
                        .accessibilityIdentifier("cushionEnglishAtlas.metrics")
                    CushionEnglishAtlasSpinLegend(spinY: vm.spinY, enabledTracks: vm.enabledTracks, onToggle: vm.toggleTrack)
                    Text("\(vm.enabledTracks.count)/8").font(.btCaption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .accessibilityIdentifier("cushionEnglishAtlas.trackCount")
                }.frame(height: min(size.height, 320)).foregroundStyle(.white)
            }, status: { EmptyView() }, onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
            .onChange(of: vm.velocity) { _, _ in vm.onVelocityChanged() }
            .onChange(of: vm.spinY) { _, _ in vm.onCueHeightChanged() }
            .overlay(alignment: .bottom) {
                if ProcessInfo.processInfo.arguments.contains("-w2.uiHooks") {
                    HStack {
                        Button("高杆") { vm.spinY = 0.3 }.accessibilityIdentifier("w2.bumpCueHeight")
                        Button("高力度") { vm.velocity = 5.5 }.accessibilityIdentifier("w2.bumpPower")
                        Text(String(format: "%.1f", vm.lastParallelSimMs)).accessibilityIdentifier("w2.parallelSimMs")
                    }.font(.btCaption)
                }
            }
            .background(Color.clear.accessibilityIdentifier("cushionEnglishAtlas.root"))
    }
    private var teachingInformation: [BTTeachingInformation] {
        guard let text = vm.statusText, !vm.isComputing else { return [] }
        return [.init(text: text, identifier: "cushionEnglishAtlas.status")]
    }

}

// MARK: - Left-edge 8 mini spin pads (horizontal english)

/// 左缘竖列 8 个迷你打点盘：每档一点、与 `trackColors`/spinX 档一一对应。
/// 点落在当前高低杆的打滑弦上（高杆点偏上、弦更短）。
/// 纯左塞（index 0）在上 → 纯右塞（index 7）在下；点选开关对应色轨迹。
private struct CushionEnglishAtlasSpinLegend: View {
    let spinY: Double
    let enabledTracks: Set<Int>
    let onToggle: (Int) -> Void

    private var levels: [Float] {
        CushionEnglishAtlasGeometry.spinXLevels(spinY: Float(spinY))
    }
    private let pull = Double(CuePhysics.tipContactPullFactor)
    private let miscue = Double(CuePhysics.miscueLimitFraction)

    var body: some View {
        GeometryReader { geo in
            let count = levels.count
            let spacing: CGFloat = 2
            let rowHeight = min(32, max(16, (geo.size.height - spacing * CGFloat(count - 1)) / CGFloat(count)))
            VStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    miniPad(index: i, size: min(28, rowHeight), rowHeight: rowHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cushionEnglishAtlas.spinLegend")
        .accessibilityLabel("8 档左右塞色序，点选开关轨迹，左塞在上右塞在下，至少留一档")
    }

    private func miniPad(index: Int, size: CGFloat, rowHeight: CGFloat) -> some View {
        let sx = Double(levels[index])
        let placeX = sx / pull
        let placeY = spinY / pull
        let ballR = size / 2 - 1
        let placementLimit = miscue / pull
        // spinX 正 = 左塞 → 屏上向左（负 x）；spinY 正 = 高杆 → 屏上向上（负 y）。
        let dx = -CGFloat(placeX) * ballR
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
                    .fill(Color(uiColor: CushionEnglishAtlasGeometry.trackColor(at: index)))
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 0.8))
                    .frame(width: max(size * 0.22, 4), height: max(size * 0.22, 4))
                    .offset(x: dx, y: dy)
            }
            .frame(width: size, height: size)
            .frame(width: 44, height: rowHeight)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cushionEnglishAtlas.spinLegend.\(index)")
        .accessibilityLabel("左右塞第\(index + 1)档")
        .accessibilityAddTraits(enabled ? .isSelected : [])
        .accessibilityValue(enabled ? "已选" : "未选")
    }
}

#Preview("Light") { NavigationStack { CushionEnglishAtlasView() } }
#Preview("Dark") { NavigationStack { CushionEnglishAtlasView() }.preferredColorScheme(.dark) }
