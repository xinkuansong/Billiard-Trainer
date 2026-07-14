import SwiftUI
import SwiftData
import AVKit

struct DrillDetailView: View {
    let drillId: String

    @State private var drill: DrillContent?
    @State private var showSubscription = false
    @State private var showTutorial = false
    /// 「上手试打」push（试打模式方案 §1.6：入口直进试打页，不做预览页）。
    @State private var showTryout = false
    /// 试打球形集合（D4，与视频示范同源；空 = 无序列，回退 shotIntent 球局）。
    @State private var tryoutFormations: [DrillTryoutFormation] = []
    /// 选中的试打球形（nil = shotIntent 兜底路径）。
    @State private var selectedFormation: DrillTryoutFormation?
    /// 多球形选择 sheet（>1 个球形时弹出，单球形直进）。
    @State private var showFormationPicker = false
    @State private var playingVideo: DrillVideo?
    @Query private var favorites: [DrillFavorite]
    @Environment(\.modelContext) private var modelContext
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

                        // F-DD-01：露出 Bundle 已有 description（转化页信息权重）。
                        Text(drill.description)
                            .font(.btCallout)
                            .foregroundStyle(.btTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Spacing.lg)

                        tagsRow(drill)

                        if isLocked {
                            // F-DD-04/09：锁态紧凑预览、不露假「查看精讲」；不改 isPremium 门槛。
                            BTPremiumLock(mode: .progressive(visibleItems: 1), onSubscribeTap: {
                                showSubscription = true
                            }) {
                                coachingSection(drill, includeTutorialCTA: false, maxPoints: 2)
                            }
                        } else {
                            coachingSection(drill, includeTutorialCTA: true)
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
        // 固定顶栏始终显示材质背景，避免滚动内容穿透状态栏/标题（UR-20260529 U-06）。
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: isFavorited)
                }
                .accessibilityLabel(isFavorited ? "取消收藏" : "收藏")
            }
        }
        .task {
            await loadDrill()
        }
        .navigationDestination(isPresented: $showTutorial) {
            if let drill {
                DrillTutorialView(drill: drill)
            }
        }
        .navigationDestination(isPresented: $showTryout) {
            if let drill {
                PositionPlayComposerView(sourceDrill: drill, tryoutFormation: selectedFormation)
            }
        }
        .sheet(isPresented: $showFormationPicker) {
            formationPickerSheet
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
        // 留一点点横向内边距（8pt），露出的是页面浅灰背景而非球台绿边——
        // 绿边已由 DrillSceneView 的相框比例(1.81)+取景(0.77)消除，与此 padding 无关。
        // 「上手试打」（试打模式方案 §1.6）：Premium 锁定态带皇冠、点击弹订阅（Freemium 钩子）；
        // 解锁态直进试打页（复用 showTutorial 同 push 模式）。
        DrillSceneView(
            drill: drill,
            tryoutLocked: isLocked,
            onTryoutTap: {
                if isLocked { showSubscription = true } else { startTryout() }
            }
        )
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Tryout entry（D4：球形与视频示范同源）

    /// 解锁态入口：>1 个球形弹选择，单球形/无序列直进。
    private func startTryout() {
        tryoutFormations = DrillTryoutBoardStore.formations(for: drillId)
        if tryoutFormations.count > 1 {
            showFormationPicker = true
        } else {
            selectedFormation = tryoutFormations.first
            showTryout = true
        }
    }

    /// 多球形选择 sheet：球形名 + 杆数，选中即进试打页（暗材质，与试打页衔接）。
    private var formationPickerSheet: some View {
        NavigationStack {
            List(Array(tryoutFormations.enumerated()), id: \.element.id) { index, formation in
                Button {
                    selectedFormation = formation
                    showFormationPicker = false
                    showTryout = true
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text("\(index + 1)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.btPrimary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.btPrimary.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formation.title)
                                .font(.btBody)
                                .foregroundStyle(.primary)
                            Text("\(formation.stepCount) 杆 · \(formation.objectBallCount) 球")
                                .font(.btCaption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.btCaption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("tryoutFormation_\(index)")
            }
            .navigationTitle("选择球形")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
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

    /// - Parameters:
    ///   - includeTutorialCTA: 解锁态才露「查看精讲」（F-DD-04：锁态不露假按钮）。
    ///   - maxPoints: 锁态 progressive 预览收束点数（F-DD-09）；`nil` = 全部。
    private func coachingSection(
        _ drill: DrillContent,
        includeTutorialCTA: Bool,
        maxPoints: Int? = nil
    ) -> some View {
        let points: [(offset: Int, element: String)] = {
            let enumerated = Array(drill.coachingPoints.enumerated())
            if let maxPoints { return Array(enumerated.prefix(maxPoints)) }
            return enumerated
        }()

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练要点")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(points, id: \.offset) { index, point in
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

            if includeTutorialCTA, drill.tutorial != nil {
                Button {
                    showTutorial = true
                } label: {
                    Text("查看精讲")
                }
                .buttonStyle(BTButtonStyle.primary)
            }
        }
        .padding(includeTutorialCTA ? Spacing.lg : Spacing.md)
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
                Image(systemName: BTIcon.target)
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
                            // F-DD-02：定性呈现，避免伪精度百分数。
                            Text(Self.dimensionWeightLabel(dim.value))
                                .font(.btCaption)
                                .foregroundStyle(.btTextSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: BTRadius.xxs)
                                    .fill(Color.btBGTertiary)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: BTRadius.xxs)
                                    .fill(Color.btPrimary)
                                    .frame(width: geo.size.width * dim.value, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }

            if let primary = dims.max(by: { $0.value < $1.value }) {
                Text("此 Drill 主要训练\(primary.name)能力（示意倾向，非测评数据）")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    /// F-DD-02：启发式权重 → 定性档，不用伪装百分数。
    private static func dimensionWeightLabel(_ value: CGFloat) -> String {
        switch value {
        case 0.65...: return "重点"
        case 0.4..<0.65: return "中等"
        default: return "辅助"
        }
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
        // F-DD-03：紧凑空态，不去铺三枚幽灵封面。
        HStack(spacing: Spacing.sm) {
            Image(systemName: BTIcon.playSlashed)
                .font(.btTitle2)
                .foregroundStyle(.btTextTertiary)
            Text("视频示范即将上线")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.sm)
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
        // F-DD-06：缩略图按压反馈。
        .buttonStyle(BTPressableStyle.row)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: Spacing.md) {
            if isLocked {
                Button { showSubscription = true } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: BTIcon.crown)
                            .font(.btFootnote14)
                        Text("解锁 Pro")
                    }
                }
                .buttonStyle(GoldFilledButtonStyle())
            } else {
                // F-DL-02：隐藏空 CTA「加入训练」；底栏单钮全宽「上手试打」。
                Button { startTryout() } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: BTIcon.playCircleFilled)
                            .font(.btFootnote14)
                        Text("上手试打")
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
        // F-DD-07：收藏切换短过渡。
        withAnimation(BTMotion.easeFast) {
            if let existing = favorites.first(where: { $0.drillId == drillId }) {
                modelContext.delete(existing)
            } else {
                modelContext.insert(DrillFavorite(drillId: drillId))
            }
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
                .font(.btTitle)
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
                // 可缩放（ADR-P12-02）：捏合/双击放大、放大后拖动平移；保留系统播放控件。
                ZoomableContainer {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                        .onDisappear { player.pause() }
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: BTIcon.warningTriangle)
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
                        Image(systemName: BTIcon.closeFilled)
                            .font(.btTitle)
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
