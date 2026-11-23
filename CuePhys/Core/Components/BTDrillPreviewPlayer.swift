import SwiftUI

// MARK: - BTDrillPreviewPlayer
//
// SPIKE: 用预渲染的位图序列替换 procedural Canvas 动画，仅用于 drill_c005 视觉效果验证。
// 资源位于 `Resources/Previews/<drillId>/frame_01..08.png`，4 对（no-path / with-path）共 8 帧。
// TimelineView 驱动帧切换，无第三方依赖；非命中 drill 不创建实例，零侵入。
//
// 验证完成后：保留为长期方案前需评估 Dark Mode、风格统一、包体、ADR（参见 docs/00 讨论记录）。

struct BTDrillPreviewPlayer: View {
    let drillId: String
    var mode: Mode = .animated
    var showsReplayButton: Bool = false

    enum Mode: Equatable {
        case animated
        case still(frame: Int)
    }

    @State private var frames: [UIImage] = []
    @State private var startDate: Date = Date()
    @State private var loaded: Bool = false
    /// F-SC-03：区分加载中 / 失败，避免永久转圈。
    @State private var loadFailed: Bool = false

    private let frameCount: Int = 8
    private let dwellNoPath: TimeInterval = 0.6
    private let dwellWithPath: TimeInterval = 1.5

    var body: some View {
        Group {
            if loaded, !frames.isEmpty {
                playerView
            } else if loadFailed {
                failedPlaceholder
            } else {
                loadingPlaceholder
            }
        }
        .task { await loadFrames() }
    }

    @ViewBuilder
    private var playerView: some View {
        switch mode {
        case .animated:
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let idx = frameIndex(for: context.date)
                imageView(frames[idx])
                    .overlay(alignment: .bottomLeading) {
                        if showsReplayButton {
                            replayButton
                                .padding(Spacing.md)
                        }
                    }
            }
        case .still(let idx):
            let safe = min(max(idx, 0), frames.count - 1)
            imageView(frames[safe])
        }
    }

    private func imageView(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.btTableFelt)
            .aspectRatio(2.0, contentMode: .fit)
            .overlay(ProgressView().tint(.white.opacity(0.6)))
    }

    /// 与 `BTBakedDrillTable` 缺图占位拉齐（F-SC-03）。
    private var failedPlaceholder: some View {
        ZStack {
            Color.btTableFelt
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.white.opacity(0.35))
        }
        .aspectRatio(2.0, contentMode: .fit)
    }

    private var replayButton: some View {
        Button {
            startDate = Date()
        } label: {
            // F-SC-07：台面覆层回放圆钮统一 `play.fill`；击打页右列文字「回放」不动。
            Image(systemName: "play.fill")
                .font(.btFootnote14)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.4))
                .clipShape(Circle())
        }
        .buttonStyle(BTPressableStyle.capsule)
        .accessibilityLabel("回放")
    }

    // MARK: - Frame Loading

    private func loadFrames() async {
        guard !loaded else { return }
        let loadedFrames = await Task.detached(priority: .userInitiated) { () -> [UIImage] in
            (1...frameCount).compactMap { i in
                let name = String(format: "frame_%02d", i)
                guard let url = Bundle.main.url(
                    forResource: name,
                    withExtension: "png",
                    subdirectory: "Previews/\(drillId)"
                ) else { return nil }
                return UIImage(contentsOfFile: url.path)
            }
        }.value
        await MainActor.run {
            self.frames = loadedFrames
            self.startDate = Date()
            self.loaded = true
            self.loadFailed = loadedFrames.isEmpty
        }
    }

    // MARK: - Timing

    private func frameIndex(for date: Date) -> Int {
        let pairCount = frames.count / 2
        guard pairCount > 0 else { return 0 }

        let pairDuration = dwellNoPath + dwellWithPath
        let loopDuration = pairDuration * Double(pairCount)
        let elapsed = date.timeIntervalSince(startDate)
        let t = elapsed.truncatingRemainder(dividingBy: loopDuration)

        let pairIndex = min(Int(t / pairDuration), pairCount - 1)
        let phase = t - Double(pairIndex) * pairDuration
        let isWithPath = phase >= dwellNoPath

        let idx = pairIndex * 2 + (isWithPath ? 1 : 0)
        return min(idx, frames.count - 1)
    }
}

// MARK: - Bundle Probe

extension BTDrillPreviewPlayer {
    static func hasAssets(for drillId: String) -> Bool {
        Bundle.main.url(
            forResource: "frame_01",
            withExtension: "png",
            subdirectory: "Previews/\(drillId)"
        ) != nil
    }
}

// MARK: - Preview

#Preview("Animated") {
    VStack {
        BTDrillPreviewPlayer(drillId: "drill_c005", mode: .animated, showsReplayButton: true)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            .padding()
    }
    .background(.btBG)
}

#Preview("Still (with path)") {
    VStack {
        BTDrillPreviewPlayer(drillId: "drill_c005", mode: .still(frame: 1))
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            .padding()
    }
    .background(.btBG)
}
