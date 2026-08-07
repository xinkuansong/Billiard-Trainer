import SwiftUI
import UIKit
import AVKit

/// 运行时加载图文精讲配图（`Resources/DrillTutorials/<name>.png`）。内存缓存，缺图回退占位。
enum DrillTutorialImageStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png",
                                        subdirectory: "DrillTutorials"),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}

struct DrillTutorialView: View {
    let drill: DrillContent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFormation = 0
    @State private var viewer: TutorialMediaViewer.Presentation?

    /// 把单球形 `sections` 与多球形 `formations` 统一成同一渲染模型。
    private var formations: [ResolvedFormation] {
        guard let tutorial = drill.tutorial else { return [] }
        if let fs = tutorial.formations, !fs.isEmpty {
            return fs.map { ResolvedFormation(id: $0.id, title: $0.title, sections: $0.sections) }
        }
        if let sections = tutorial.sections, !sections.isEmpty {
            return [ResolvedFormation(id: "default", title: nil, sections: sections)]
        }
        return []
    }

    private var currentSections: [TutorialSection] {
        guard formations.indices.contains(selectedFormation) else {
            return formations.first?.sections ?? []
        }
        return formations[selectedFormation].sections
    }

    /// 当前球形可全屏浏览的图集（仅含能成功加载海报的 section）。
    private var currentMediaItems: [TutorialMediaItem] {
        Self.mediaItems(for: currentSections)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, Spacing.xl)

                if formations.count > 1 {
                    LazyVStack(alignment: .leading, spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                        Section {
                            // F-DL-05：球形切换短 opacity 过渡。
                            // 行 id 必须绑定 selectedFormation（见 sectionList）：LazyVStack 对
                            // 已实例化行只按 ForEach id 复用，容器级 .id 在 iOS 26 上不触发行重建
                            // （切换球形正文不刷新，B4 发现的存量缺陷）。
                            sectionList
                                .transition(.opacity)
                        } header: {
                            formationPicker
                        }
                    }
                    .animation(BTMotion.easeFast, value: selectedFormation)
                } else {
                    LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                        sectionList
                    }
                }
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(.btBG)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("精讲")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
        }
        .fullScreenCover(item: $viewer) { presentation in
            TutorialMediaViewer(items: presentation.items, startIndex: presentation.startIndex)
        }
    }

    @ViewBuilder
    private var sectionList: some View {
        // id 复合 selectedFormation：保证切换球形时 LazyVStack 行重建（而非按 offset 复用旧行）。
        ForEach(Array(currentSections.enumerated()), id: \.offset) { index, section in
            sectionCard(section, index: index)
                .id("\(selectedFormation)-\(index)")
        }
    }

    // MARK: - Formation Picker (multi-formation only, sticky)

    private var formationPicker: some View {
        Picker("球形", selection: $selectedFormation) {
            ForEach(Array(formations.enumerated()), id: \.offset) { i, formation in
                Text(formation.title ?? "球形 \(i + 1)").tag(i)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(.btBG)
    }

    // MARK: - Header

    /// F-DD-05：详情页已露 description / 分类等级；精讲头去重，只保留标题 + 阅读定位副文。
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(drill.nameZh)
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text(Self.headerSubtitle(for: drill.tutorial?.tutorialKind))
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private static func headerSubtitle(for kind: DrillTutorialKind?) -> String {
        switch kind {
        case .singleShot: return "单杆技术课"
        case .ruleset: return "规则流程课"
        case .multiShot, .none: return "图文分步精讲"
        }
    }

    // MARK: - Section Card

    private static var sectionIcons: [String: String] { DrillTutorialSectionChrome.icons }
    private static var sectionColors: [String: Color] { DrillTutorialSectionChrome.colors }

    /// 条目标签配色（ADR-P11-15「应用课」模板：为什么/怎么打/自检；其余标签用中性色）。
    private static let itemLabelColors: [String: Color] = [
        "为什么": .blue,
        "怎么打": .btPrimary,
        "自检": .orange,
    ]

    /// F-TU-06：「第N杆 / 开局…」主结构识别（不重开 DR-019 色议题）。
    private static func isShotStructureTitle(_ title: String) -> Bool {
        if title.contains("开局") { return true }
        return title.hasPrefix("第") && title.contains("杆")
    }

    /// 解析「第3杆」「第一杆」中的杆序号；解析失败返回 nil（仍走阶梯字号）。
    private static func shotStructureIndex(from title: String) -> Int? {
        guard title.hasPrefix("第"),
              let end = title.firstIndex(of: "杆") else { return nil }
        let raw = String(title[title.index(after: title.startIndex)..<end])
        if let n = Int(raw) { return n }
        let cn: [Character: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
        ]
        if raw.count == 1, let n = cn[raw.first!] { return n }
        if raw == "十" { return 10 }
        if raw.hasPrefix("十"), raw.count == 2, let ones = cn[raw.last!] {
            return 10 + ones
        }
        if raw.hasSuffix("十"), raw.count == 2, let tens = cn[raw.first!] {
            return tens * 10
        }
        return nil
    }

    private func sectionCard(_ section: TutorialSection, index: Int) -> some View {
        let isShot = Self.isShotStructureTitle(section.title)
        let icon = isShot
            ? (section.title.contains("开局") ? "flag.fill" : "number.circle.fill")
            : (Self.sectionIcons[section.title] ?? "doc.text.fill")
        let accentColor = Self.sectionColors[section.title] ?? .btPrimary
        let shotIndex = Self.shotStructureIndex(from: section.title)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                if isShot, let shotIndex {
                    Text("\(shotIndex)")
                        .font(.btCaption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.btText.opacity(0.85))
                        .clipShape(Circle())
                } else {
                    Image(systemName: icon)
                        .font(.btFootnote14)
                        .foregroundStyle(isShot ? Color.btText : accentColor)
                        .frame(width: 28, height: 28)
                        .background((isShot ? Color.btText : accentColor).opacity(0.12))
                        .clipShape(Circle())
                }

                Text(section.title)
                    .font(isShot ? .btTitle2 : .btHeadline)
                    .foregroundStyle(.btText)
            }

            if !section.content.isEmpty {
                paragraphs(section.content)
            }

            if let params = section.params {
                paramsRow(params)
            }

            if let items = section.items {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(items) { item in
                        itemRow(item)
                    }
                }
            }

            // F-TU-01: `image != nil` 但加载失败时显示弱占位（失败 chrome），图注仍可出现。
            if let imageName = section.image {
                let uiImage = DrillTutorialImageStore.image(named: imageName)
                let hasClip = section.clip.flatMap {
                    DrillContentService.shared.tutorialClipURL(named: $0)
                } != nil
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let uiImage {
                        Button {
                            openViewer(at: imageName)
                        } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: BTRadius.sm)
                                        .stroke(.btSeparator, lineWidth: 0.5)
                                )
                                .overlay {
                                    if hasClip {
                                        playBadge
                                    } else {
                                        // F-TU-04：静态配图弱放大角标。
                                        staticExpandBadge
                                    }
                                }
                        }
                        .buttonStyle(BTPressableStyle.row)
                        .accessibilityIdentifier("tutorialPoster_\(imageName)")
                    } else {
                        missingImagePlaceholder
                    }

                    if let caption = section.caption {
                        Text(caption)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Section building blocks

    /// 正文：按空行分段渲染，段内支持 inline markdown（**加粗** 等）。
    private func paragraphs(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(content.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, para in
                Text(Self.inlineMarkdown(para))
                    .font(.btCallout)
                    .foregroundStyle(.btText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
            }
        }
    }

    private static func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    /// 「标签 + 正文」条目行：彩色小标签胶囊 + 段落。
    private func itemRow(_ item: TutorialItem) -> some View {
        let color = Self.itemLabelColors[item.label] ?? Color.btTextSecondary
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Text(item.label)
                .font(.btCaption2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                .padding(.top, 1)

            Text(Self.inlineMarkdown(item.text))
                .font(.btCallout)
                .foregroundStyle(.btText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(5)
        }
    }

    /// 击球参数行：打点小图标（真实比例，与导出 HUD 同口径）+ 打点读数 + 力度胶囊。
    private func paramsRow(_ params: TutorialShotParams) -> some View {
        HStack(spacing: Spacing.sm) {
            BTSpinMiniIcon(spinX: params.spinX, spinY: params.spinY,
                           diameter: 40, trueScale: true)

            paramChip(SpinDisplay.readout(spinX: params.spinX, spinY: params.spinY))
            paramChip("\(PowerDisplay.name(params.velocity)) · \(String(format: "%.1f", params.velocity)) m/s")

            Spacer(minLength: 0)
        }
    }

    private func paramChip(_ text: String) -> some View {
        Text(text)
            .font(.btCaption)
            .monospacedDigit()
            .foregroundStyle(.btText)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(.btBGTertiary)
            .clipShape(Capsule())
    }

    // MARK: - Media (poster + optional motion clip)

    /// 动态片段的播放角标（海报上居中），点击进全屏循环播放（决策 poster_tap）。
    private var playBadge: some View {
        Image(systemName: "play.circle.fill")
            .font(.btDisplay)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black.opacity(0.35))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
    }

    /// F-TU-04：静态配图可放大弱角标（右下，不抢 clip 播放标）。
    private var staticExpandBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.btCaption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(Spacing.xs)
                    .background(.black.opacity(0.45), in: Circle())
                    .padding(Spacing.sm)
            }
        }
        .allowsHitTesting(false)
    }

    /// F-TU-01：配图字段存在但 Bundle 加载失败时的弱占位（不进 Viewer）。
    private var missingImagePlaceholder: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "photo")
                .font(.btTitle)
                .foregroundStyle(.btTextTertiary)
            Text("配图暂缺")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
        .background(.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .stroke(.btSeparator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("配图暂缺")
    }

    private func openViewer(at imageName: String) {
        let items = currentMediaItems
        guard let start = items.firstIndex(where: { $0.id == imageName }) else { return }
        viewer = TutorialMediaViewer.Presentation(items: items, startIndex: start)
    }

    /// 收集一组 section 里可全屏浏览的视觉素材（按出现顺序，仅含海报可加载者）。
    static func mediaItems(for sections: [TutorialSection]) -> [TutorialMediaItem] {
        sections.compactMap { section in
            guard let imageName = section.image,
                  let poster = DrillTutorialImageStore.image(named: imageName) else { return nil }
            let clipURL = section.clip.flatMap { DrillContentService.shared.tutorialClipURL(named: $0) }
            return TutorialMediaItem(id: imageName, poster: poster,
                                     clipURL: clipURL, caption: section.caption)
        }
    }
}

// MARK: - Resolved Formation (unified single/multi-formation model)

private struct ResolvedFormation: Identifiable {
    let id: String
    /// nil 表示单球形（合成的默认球形），不显示分段标签。
    let title: String?
    let sections: [TutorialSection]
}

// MARK: - Tutorial Media Item

struct TutorialMediaItem: Identifiable {
    /// 用 section 的 image 名做稳定标识。
    let id: String
    let poster: UIImage
    /// 非空表示这是动态演示（mp4），全屏时循环播放；nil 则为可缩放静态图。
    let clipURL: URL?
    let caption: String?
}

// MARK: - Fullscreen Media Viewer (gallery paging + zoom + swipe-to-dismiss)

struct TutorialMediaViewer: View {
    struct Presentation: Identifiable {
        let id = UUID()
        let items: [TutorialMediaItem]
        let startIndex: Int
    }

    let items: [TutorialMediaItem]
    @State private var index: Int
    /// F-TU-10：fullScreenCover 进场短 opacity/scale 过渡。
    @State private var entranceReady = false
    @Environment(\.dismiss) private var dismiss

    init(items: [TutorialMediaItem], startIndex: Int) {
        self.items = items
        _index = State(initialValue: max(0, min(startIndex, items.count - 1)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    TutorialMediaPage(item: item, isActive: i == index, onDismiss: { dismiss() })
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            topBar
        }
        .statusBarHidden()
        .opacity(entranceReady ? 1 : 0)
        .scaleEffect(entranceReady ? 1 : 0.98)
        .onAppear {
            withAnimation(BTMotion.springPanel) {
                entranceReady = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            if items.count > 1 {
                // F-TU-07：保留 n/N，关闭系统页点，避免双重进度。
                Text("\(index + 1) / \(items.count)")
                    .font(.btFootnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(.black.opacity(0.35), in: Capsule())
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    // F-TU-08：关闭钮收编 Font.bt*。
                    .font(.btDisplaySmall)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
}

/// 单页媒体：媒体 + caption 共享下滑偏移（F-TU-03）。
private struct TutorialMediaPage: View {
    let item: TutorialMediaItem
    let isActive: Bool
    let onDismiss: () -> Void

    @State private var dismissDrag: CGFloat = 0

    private var dismissOpacity: Double {
        Double(max(0.4, 1.0 - abs(dismissDrag) / 400.0))
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let clipURL = item.clipURL {
                ZoomableContainer(
                    swipeToDismiss: true,
                    onDismiss: onDismiss,
                    dismissDrag: $dismissDrag
                ) {
                    LoopingPlayerView(url: clipURL, isActive: isActive)
                }
            } else {
                ZoomableContainer(
                    swipeToDismiss: true,
                    onDismiss: onDismiss,
                    dismissDrag: $dismissDrag
                ) {
                    Image(uiImage: item.poster)
                        .resizable()
                        .scaledToFit()
                }
            }

            if let caption = item.caption {
                Text(caption)
                    .font(.btCaption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        // F-TU-03：caption 与媒体一体跟手下滑 / 淡出。
        .offset(y: dismissDrag)
        .opacity(dismissOpacity)
    }
}

// MARK: - Zoomable Container (reusable: pinch + double-tap zoom, drag pan, optional swipe-down dismiss)

/// 通用「可缩放容器」（ADR-P12-02）：把任意内容（图片 / 视频播放层）包成可捏合/双击放大、
/// 放大后拖动平移；`swipeToDismiss` 开启时未放大状态下纵向下滑关闭（横向留给 TabView 翻页）。
/// 内部不依赖内容类型，故精讲静态图、精讲 clip、详情页示范视频可共用同一套缩放逻辑。
struct ZoomableContainer<Content: View>: View {
    private let swipeToDismiss: Bool
    private let onDismiss: (() -> Void)?
    /// When non-nil, parent owns dismiss offset/opacity (F-TU-03); this view only drives the binding.
    private let externalDismissDrag: Binding<CGFloat>?
    private let content: Content

    init(swipeToDismiss: Bool = false,
         onDismiss: (() -> Void)? = nil,
         dismissDrag: Binding<CGFloat>? = nil,
         @ViewBuilder content: () -> Content) {
        self.swipeToDismiss = swipeToDismiss
        self.onDismiss = onDismiss
        self.externalDismissDrag = dismissDrag
        self.content = content()
    }

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var internalDismissDrag: CGFloat = 0

    private let maxScale: CGFloat = 4
    private let dismissThreshold: CGFloat = 120

    private var dismissDragValue: CGFloat {
        externalDismissDrag?.wrappedValue ?? internalDismissDrag
    }

    private func setDismissDrag(_ value: CGFloat) {
        if let externalDismissDrag {
            externalDismissDrag.wrappedValue = value
        } else {
            internalDismissDrag = value
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(scale)
            // Parent applies dismiss offset when `externalDismissDrag` is set (F-TU-03).
            .offset(
                x: offset.width,
                y: offset.height + (externalDismissDrag == nil ? dismissDragValue : 0)
            )
            .opacity(
                swipeToDismiss && scale <= 1 && externalDismissDrag == nil
                    ? Double(max(0.4, 1.0 - abs(dismissDragValue) / 400.0))
                    : 1.0
            )
            // simultaneous 让多图 TabView 翻页 / 视频自带控件不被吞掉；本手势只处理缩放后平移 + 纵向下滑关闭。
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnification)
            .onTapGesture(count: 2) { toggleZoom() }
            // F-TU-02：不对手势 onChanged 驱动值挂隐式 animation；松手/双击才用 spring。
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scale = min(max(lastScale * value, 1), maxScale)
                }
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation(.interactiveSpring()) { resetPan() }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if scale > 1 {
                        offset = CGSize(width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height)
                    } else if swipeToDismiss, abs(value.translation.height) > abs(value.translation.width) {
                        // 仅纵向拖动触发下滑关闭；横向 / 缩放=1 时不拦截（交给 TabView / 视频控件）。
                        setDismissDrag(value.translation.height)
                    }
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else if swipeToDismiss,
                          abs(value.translation.height) > dismissThreshold,
                          abs(value.translation.height) > abs(value.translation.width) {
                    onDismiss?()
                } else {
                    withAnimation(.interactiveSpring()) {
                        setDismissDrag(0)
                    }
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.interactiveSpring()) {
            if scale > 1 {
                scale = 1; lastScale = 1; resetPan()
            } else {
                scale = 2.5; lastScale = 2.5
            }
        }
    }

    private func resetPan() {
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Looping Player (muted, no controls, auto loop)

private struct LoopingPlayerView: UIViewRepresentable {
    let url: URL
    let isActive: Bool

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        if isActive { uiView.play() } else { uiView.pause() }
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.pause()
    }
}

private final class LoopingPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func play() { queuePlayer.play() }
    func pause() { queuePlayer.pause() }
}

#Preview("Light") {
    NavigationStack {
        DrillTutorialView(drill: DrillContent(
            id: "drill_c001",
            nameZh: "半台直线球",
            nameEn: "Half-Table Straight Shot",
            category: "accuracy",
            subcategory: "straight",
            ballType: ["chinese8"],
            level: "L0",
            difficulty: 1,
            isPremium: false,
            description: "将目标球从半台距离沿直线打入右侧中袋，训练基础瞄准稳定性与出杆方向。",
            coachingPoints: ["保持出杆方向与瞄准线严格一致"],
            standardCriteria: "15球进10球",
            sets: .init(defaultSets: 3, defaultBallsPerSet: 15),
            animation: DrillAnimation(
                cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: []),
                targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: []),
                pocket: "bottomCenter",
                cueDirection: CanvasPoint(x: 0.5, y: 0.0)
            ),
            tutorial: DrillTutorial(
                tutorialKind: .multiShot,
                sections: [
                TutorialSection(title: "技术原理", content: "示例内容"),
                TutorialSection(title: "动作要领", content: "示例内容"),
                TutorialSection(title: "常见错误与纠正", content: "示例内容"),
                TutorialSection(title: "进阶练习", content: "示例内容"),
            ])
        ))
    }
}

/// Shared section title → icon/color maps for `DrillTutorialView` (v26 W0).
/// Extracted so unit tests can assert ruleset titles have dedicated chrome
/// (not the `doc.text.fill` / `.btPrimary` fallback).
enum DrillTutorialSectionChrome {
    static let icons: [String: String] = [
        "技术原理": "lightbulb.fill",
        "动作要领": "scope",
        "常见错误与纠正": "exclamationmark.triangle.fill",
        "进阶练习": "arrow.up.right.circle.fill",
        // ruleset template (tutorial-migration SKILL §C)
        "怎么摆": "square.grid.3x3.fill",
        "怎么计分": "list.number",
        "失败判定": "xmark.octagon.fill",
        "进阶变体": "arrow.triangle.branch",
    ]

    static let colors: [String: Color] = [
        "技术原理": .blue,
        "动作要领": .btPrimary,
        "常见错误与纠正": .orange,
        "进阶练习": .purple,
        // ruleset template (tutorial-migration SKILL §C)
        "怎么摆": .teal,
        "怎么计分": .indigo,
        "失败判定": .red,
        "进阶变体": .mint,
    ]

    static let rulesetTitles = ["怎么摆", "怎么计分", "失败判定", "进阶变体"]

    static let fallbackIcon = "doc.text.fill"
}
