import SwiftUI

struct PocketToleranceView: View {
    @StateObject private var vm = PocketToleranceViewModel()
    @State private var orientation = PocketDisplay.Orientation(portrait: false)

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: "进球容错角", identifier: "pocketTolerance", preferencePage: .pocketTolerance,
            leftControlGroup: .information,
            information: vm.message.isEmpty ? [] : [.init(text: vm.message, identifier: "pocketTolerance.status")],
            usesStandardTitle: true,
            objectObservationOnly: true, allows3DPaletteEditing: true, onPaletteTap: vm.paletteTapped,
            onPocketOrientationChange: { orientation = $0 },
            title: { EmptyView() }, leftContent: { _ in metrics }, status: { EmptyView() },
            onPalettePlace: { vm.placeFromPalette($0, atWorld: $1) })
        #if DEBUG
        .overlay(alignment: .bottom) {
            if ProcessInfo.processInfo.arguments.contains("-pocketTolerance.probe") {
                Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
                    .accessibilityElement().accessibilityIdentifier("pocketTolerance.probe")
                    .accessibilityValue("target=\(vm.selectedTargetKey ?? "none") pocket=\(vm.selectedPocketIndex) count=\(vm.onTableKeys.count) edges=\(vm.boundaryCount) angle=\(vm.angleText)")
            }
        }
        #endif
    }
    private var metrics: some View {
        VStack(spacing: 14) {
            readout("目标球", value: vm.selectedTargetKey.flatMap { PositionPlayBall.number(for: $0) }.map { "\($0)号" } ?? "—", id: "ball")
            readout("目标袋", value: vm.selectedPocketIndex < 0 ? "—" : PocketDisplay.name(index: vm.selectedPocketIndex, orientation: orientation), id: "pocket")
            readout("容错角", value: vm.angleText, id: "angle")
        }.foregroundStyle(.white)
    }
    private func readout(_ label: String, value: String, id: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.btCaption2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.btFootnote.weight(.medium).monospacedDigit()).lineLimit(1)
        }.accessibilityElement(children: .combine).accessibilityIdentifier("pocketTolerance." + id)
            .accessibilityValue(value)
    }
}
