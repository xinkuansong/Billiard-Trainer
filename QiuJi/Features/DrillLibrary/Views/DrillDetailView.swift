import SwiftUI
import SwiftData
import AVKit

struct DrillDetailView: View {
    let drillId: String

    @State private var drill: DrillContent?
    @State private var animationProgress: CGFloat = 0
    @State private var showSubscription = false
    @State private var showTutorial = false
    @State private var playingVideo: DrillVideo?
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private var isFavorited: Bool {
        favorites.contains { $0.drillId == drillId }
    }

    private var isLocked: Bool {
        guard let drill else { return false }
        return drill.isPremium && !subscriptionManager.isPremium
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                if let drill {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        tableSection(drill)

                        Text(drill.nameZh)
                            .font(.btTitle)
                            .foregroundStyle(.btText)
                            .padding(.horizontal, Spacing.lg)

                        actionIconRow
                        tagsRow(drill)

                        notesCard

                        if isLocked {
                            BTPremiumLock(mode: .progressive(visibleItems: 1), onSubscribeTap: {
                                showSubscription = true
                            }) {
                                coachingSection(drill)
                            }
                        } else {
                            coachingSection(drill)
                            criteriaSection(drill)
                            dimensionsSection(drill)
                            videoSection(drill)
                        }
                    }
                    .padding(.bottom, 100)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .background(.btBG)

            if drill != nil {
                bottomBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(drill?.nameZh ?? "")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorited ? .btAccent : .btTextSecondary)
                }
            }
        }
        .task {
            await loadDrill()
            withAnimation(.easeInOut(duration: 1.4)) {
                animationProgress = 1
            }
        }
        .navigationDestination(isPresented: $showTutorial) {
            if let drill {
                DrillTutorialView(drill: drill)
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
        .sheet(item: $playingVideo) { video in
            DrillVideoPlayerSheet(drillId: drillId, video: video)
        }
    }

    // MARK: - Table Canvas

    private func tableSection(_ drill: DrillContent) -> some View {
        Group {
            if BTDrillPreviewPlayer.hasAssets(for: drill.id) {
                BTDrillPreviewPlayer(drillId: drill.id, mode: .animated, showsReplayButton: false)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            } else {
                ZStack(alignment: .bottom) {
                    BTBilliardTable(animation: drill.animation, animationProgress: $animationProgress)

                    HStack {
                        Button {
                            animationProgress = 0
                            withAnimation(.easeInOut(duration: 1.4)) {
                                animationProgress = 1
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.btFootnote14)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }

                        Spacer()
                    }
                    .padding(Spacing.md)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Action Icon Row (gray, not green)

    private var actionIconRow: some View {
        HStack(spacing: Spacing.xxl) {
            actionIcon(symbol: "list.bullet", label: "要点")
            actionIcon(symbol: "clock.arrow.circlepath", label: "历史")
            actionIcon(symbol: "chart.line.uptrend.xyaxis", label: "图表")
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func actionIcon(symbol: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 44, height: 44)
                .background(.btBGTertiary)
                .clipShape(Circle())

            Text(label)
                .font(.btCaption2)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Tags Row

    private static let ballTypeDisplayNames: [String: String] = [
        "chinese8": "中式台球",
        "8ball": "中式台球",
        "snooker": "斯诺克",
        "nineBall": "9球",
        "pool9": "9球",
        "9ball": "9球",
        "universal": "通用",
    ]

    private func tagsRow(_ drill: DrillContent) -> some View {
        HStack(spacing: Spacing.sm) {
            ForEach(drill.ballType, id: \.self) { ball in
                Text(Self.ballTypeDisplayNames[ball] ?? ball)
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(.btBGTertiary)
                    .clipShape(Capsule())
            }

            Text(DrillCategory(rawValue: drill.category)?.nameZh ?? drill.category)
                .font(.btCaption2)
                .foregroundStyle(.btTextSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(.btBGTertiary)
                .clipShape(Capsule())

            BTLevelBadge(level: DrillLevel(rawValue: drill.level) ?? .L0)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Coaching Points

    private func coachingSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练要点")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(drill.coachingPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("\(index + 1)")
                            .font(.btCaption2)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(.btPrimary)
                            .clipShape(Circle())

                        Text(point)
                            .font(.btCallout)
                            .foregroundStyle(.btText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if drill.tutorial != nil {
                Button {
                    showTutorial = true
                } label: {
                    Text("查看精讲")
                }
                .buttonStyle(BTButtonStyle.primary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Standard Criteria

    private func criteriaSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("达标标准")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            HStack(spacing: Spacing.md) {
                Image(systemName: "target")
                    .font(.btTitle)
                    .foregroundStyle(.btPrimary)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(drill.standardCriteria)
                        .font(.btBodyMedium)
                        .foregroundStyle(.btText)

                    Text("默认 \(drill.sets.defaultSets) 组 × \(drill.sets.defaultBallsPerSet) 球")
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "square.and.pencil")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            Text("点击此处输入备注")
                .font(.btCallout)
                .foregroundStyle(.btTextTertiary)

            Spacer()
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Training Dimensions

    private func dimensionsSection(_ drill: DrillContent) -> some View {
        let dims = trainingDimensions(for: drill)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练维度")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            VStack(spacing: Spacing.md) {
                ForEach(dims, id: \.name) { dim in
                    VStack(spacing: Spacing.xs) {
                        HStack {
                            Text(dim.name)
                                .font(.btFootnote)
                                .foregroundStyle(.btTextSecondary)
                            Spacer()
                            Text("\(Int(dim.value * 100))%")
                                .font(.btCaption)
                                .foregroundStyle(.btTextSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.btBGTertiary)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.btPrimary)
                                    .frame(width: geo.size.width * dim.value, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }

            if let primary = dims.max(by: { $0.value < $1.value }) {
                Text("此 Drill 主要训练\(primary.name)能力")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    private struct DimensionData {
        let name: String
        let value: CGFloat
    }

    private func trainingDimensions(for drill: DrillContent) -> [DimensionData] {
        let cat = drill.category
        let diff = CGFloat(drill.difficulty) / 5.0

        var accuracy: CGFloat = 0.3
        var forceCtrl: CGFloat = 0.3
        var positioning: CGFloat = 0.2
        var cueSkill: CGFloat = 0.2
        var mental: CGFloat = 0.1

        switch cat {
        case "accuracy":
            accuracy = 0.7 + diff * 0.2
            forceCtrl = 0.3 + diff * 0.1
        case "fundamentals":
            accuracy = 0.5; forceCtrl = 0.3; cueSkill = 0.2
        case "cueAction":
            cueSkill = 0.7 + diff * 0.2
            forceCtrl = 0.5 + diff * 0.1
        case "separation":
            positioning = 0.6 + diff * 0.2
            cueSkill = 0.5
        case "positioning":
            positioning = 0.7 + diff * 0.2
            accuracy = 0.4
        case "forceControl":
            forceCtrl = 0.7 + diff * 0.2
            cueSkill = 0.4
        case "specialShots":
            cueSkill = 0.6 + diff * 0.2
            mental = 0.4 + diff * 0.1
        case "combined":
            accuracy = 0.5 + diff * 0.15
            forceCtrl = 0.5 + diff * 0.1
            positioning = 0.5 + diff * 0.1
            cueSkill = 0.4 + diff * 0.1
            mental = 0.3 + diff * 0.15
        default: break
        }

        return [
            DimensionData(name: "准度", value: min(accuracy, 1.0)),
            DimensionData(name: "力量控制", value: min(forceCtrl, 1.0)),
            DimensionData(name: "走位判断", value: min(positioning, 1.0)),
            DimensionData(name: "杆法技巧", value: min(cueSkill, 1.0)),
            DimensionData(name: "心理素质", value: min(mental, 1.0)),
        ]
    }

    // MARK: - Video Section

    @ViewBuilder
    private func videoSection(_ drill: DrillContent) -> some View {
        let videos = drill.videos ?? []
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("视频示范")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Spacer()
                if !videos.isEmpty {
                    Text("\(videos.count) 段")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
            }

            if videos.isEmpty {
                emptyVideoPlaceholder
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                            videoThumbnail(video: video, index: index)
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    private var emptyVideoPlaceholder: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    ZStack {
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(Color.btBGTertiary)
                        Image(systemName: "play.slash.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.btTextTertiary)
                    }
                    .frame(width: 96, height: 64)
                }
                Text("即将上线")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .padding(.horizontal, Spacing.sm)
            }
        }
    }

    private func videoThumbnail(video: DrillVideo, index: Int) -> some View {
        Button {
            playingVideo = video
        } label: {
            VStack(spacing: Spacing.xs) {
                VideoThumbnailView(drillId: drillId, file: video.file)
                    .frame(width: 96, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))

                Text("第 \(index + 1) 段")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: Spacing.md) {
            if isLocked {
                Button { showSubscription = true } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "crown.fill")
                            .font(.btFootnote14)
                        Text("解锁 Pro")
                    }
                }
                .buttonStyle(GoldFilledButtonStyle())
            } else {
                Button { dismiss() } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "xmark")
                            .font(.btFootnote14)
                        Text("关闭")
                    }
                }
                .buttonStyle(BTButtonStyle.darkPill)
                .frame(width: 100)

                Button {
                    // TODO: Add to active training
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.btFootnote14)
                        Text("加入训练")
                    }
                }
                .buttonStyle(BTButtonStyle.primary)
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.md)
        .background(Color.btBG.opacity(0.8))
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func loadDrill() async {
        let service = DrillContentService.shared
        drill = await service.loadDrillFromBundle(id: drillId)
    }

    private func toggleFavorite() {
        if let existing = favorites.first(where: { $0.drillId == drillId }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(DrillFavorite(drillId: drillId))
        }
    }
}

// MARK: - Video Thumbnail (first-frame extraction with cache)

private actor VideoThumbnailCache {
    static let shared = VideoThumbnailCache()

    private var cache: [String: UIImage] = [:]
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    func thumbnail(for url: URL) async -> UIImage? {
        let key = url.absoluteString
        if let cached = cache[key] {
            return cached
        }
        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 320)

            return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                let time = CMTime(seconds: 0.1, preferredTimescale: 600)
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
                    if let cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        inflight[key] = task
        let image = await task.value
        inflight[key] = nil
        if let image {
            cache[key] = image
        }
        return image
    }
}

private struct VideoThumbnailView: View {
    let drillId: String
    let file: String

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.btBGTertiary)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.35)],
                startPoint: .center,
                endPoint: .bottom
            )

            Image(systemName: failed ? "play.slash.fill" : "play.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        }
        .task(id: "\(drillId)/\(file)") {
            guard image == nil,
                  let url = DrillContentService.shared.videoURL(drillId: drillId, file: file)
            else {
                failed = (image == nil)
                return
            }
            let result = await VideoThumbnailCache.shared.thumbnail(for: url)
            await MainActor.run {
                if let result {
                    image = result
                } else {
                    failed = true
                }
            }
        }
    }
}

// MARK: - Video Player Sheet

private struct DrillVideoPlayerSheet: View {
    let drillId: String
    let video: DrillVideo

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.yellow)
                    Text("视频暂不可用")
                        .font(.btBody)
                        .foregroundStyle(.white)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(Spacing.md)
                    }
                }
                Spacer()
            }
        }
        .task {
            if let url = DrillContentService.shared.videoURL(drillId: drillId, file: video.file) {
                player = AVPlayer(url: url)
            }
        }
    }
}

private struct GoldFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.btFootnote14)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(configuration.isPressed ? Color.btAccent.opacity(0.8) : Color.btAccent)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Light") {
    NavigationStack {
        DrillDetailView(drillId: "drill_c001")
    }
    .modelContainer(for: DrillFavorite.self, inMemory: true)
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    NavigationStack {
        DrillDetailView(drillId: "drill_c001")
    }
    .modelContainer(for: DrillFavorite.self, inMemory: true)
    .environmentObject(SubscriptionManager.shared)
    .preferredColorScheme(.dark)
}
