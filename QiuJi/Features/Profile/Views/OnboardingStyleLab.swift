#if DEBUG
import SwiftUI
import SceneKit

/// An opt-in design lab. Never advances onboarding or writes profile/table preferences.
struct OnboardingStyleLab: View {
    var showsCloseButton = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @StateObject private var model = IntroLabScene()
    @State private var style = IntroLabStyle.initial
    @State private var sheet: LabSheet?
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 35
    @ScaledMetric(relativeTo: .body) private var bodySize = 15

    private enum LabSheet: String, Identifiable {
        case original, finish
        var id: String { rawValue }
    }
    private var ink: Color { style == .editorial ? Color("introLabInk") : Color("introLabWhite") }
    private var secondary: Color { style == .editorial ? Color("introLabInk").opacity(0.72) : Color("introLabMuted") }

    var body: some View {
        VStack(spacing: 0) {
            comparisonBar.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            HStack {
                Text("涨球记").font(.headline)
                Spacer()
                Button("跳过介绍") { sheet = .finish }
                    .font(.subheadline).frame(minHeight: 44)
                    .accessibilityIdentifier("introLab.skip")
            }
            .padding(.horizontal, 24)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(maxWidth: 1180)

            GeometryReader { available in
                ScrollView {
                    let wide = available.size.width >= 780 && !dynamicType.isAccessibilitySize
                    let height = max(available.size.height, dynamicType.isAccessibilitySize ? titleSize * 10 + bodySize * 12 + 360 : 490)
                    composition(size: CGSize(width: available.size.width, height: height), wide: wide)
                        .frame(height: height)
                }
                .scrollIndicators(.hidden)
            }
            footer
        }
        .foregroundStyle(ink)
        .background(style.background.ignoresSafeArea())
        .preferredColorScheme(style == .editorial ? .light : .dark)
        .background(DailyTableOrientation(landscape: false, allowsTabletRotation: true).frame(width: 0, height: 0))
        .task { await model.prepare() }
        .sheet(item: $sheet) { item in
            if item == .original {
                OnboardingView(onFinish: { sheet = nil })
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    Text("首屏预览结束").font(.title.bold())
                    Text("当前只比较第一张引导页。选定风格后，再延展六个学习主题与资料页。")
                        .font(.body).foregroundStyle(.secondary)
                    Button("继续比较") { sheet = nil }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("introLab.return")
                }
                .padding(32).presentationDetents([.medium])
            }
        }
    }

    private var comparisonBar: some View {
        HStack(spacing: 12) {
            Menu {
                Button("旧 App 原版（历史对照）") { sheet = .original }
                    .accessibilityIdentifier("introLab.original")
                ForEach(IntroLabStyle.allCases) { item in
                    Button {
                        // The single SceneKit view below keeps its scene identity.
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { style = item }
                    } label: {
                        if item == style { Label(item.title, systemImage: "checkmark") }
                        else { Text(item.title) }
                    }
                    .accessibilityIdentifier("introLab.style.\(item.rawValue)")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(style.title).font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down").font(.caption)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityIdentifier("introLab.styles")
            .accessibilityValue(style.rawValue)
            Spacer(minLength: 8)
            Button("r6 基准") { style = .reference }
                .font(.subheadline).frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("introLab.reference")
            if showsCloseButton { Button { dismiss() } label: {
                Image(systemName: "xmark").font(.subheadline).frame(width: 44, height: 44)
            }
            .accessibilityLabel("关闭设计预览") }
        }
        .padding(.leading, 24).padding(.trailing, 12)
        .frame(maxWidth: 1180)
        .foregroundStyle(secondary)
        .background(style.background)
    }

    private func composition(size: CGSize, wide: Bool) -> some View {
        let bounds = CGSize(width: min(size.width, 1180), height: size.height)
        let rect: CGRect = {
            switch style {
            case .minimal: return IntroLabMinimalComposition.sceneRect(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize)
            case .precision: return IntroLabPrecisionComposition.sceneRect(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize)
            case .cinematic: return IntroLabCinematicComposition.sceneRect(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize)
            case .editorial: return IntroLabEditorialComposition.sceneRect(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize)
            case .training: return IntroLabTrainingComposition.sceneRect(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize)
            case .reference: return IntroLabReferenceComposition.sceneRect(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize)
            }
        }()
        return ZStack(alignment: .topLeading) {
            IntroLabRenderer(model: model)
                .frame(width: rect.width, height: rect.height)
                .clipShape(RoundedRectangle(cornerRadius: style == .training || style == .reference ? 16 : 0))
                .position(x: rect.midX, y: rect.midY)
            if !model.ready {
                ProgressView(model.failure ?? "正在准备球桌…")
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            switch style {
            case .minimal: IntroLabMinimalComposition(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize, cutAngle: model.cutAngle, distance: model.distance)
            case .precision: IntroLabPrecisionComposition(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize, cutAngle: model.cutAngle, distance: model.distance)
            case .cinematic: IntroLabCinematicComposition(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize, cutAngle: model.cutAngle, distance: model.distance)
            case .editorial: IntroLabEditorialComposition(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize, cutAngle: model.cutAngle, distance: model.distance)
            case .training: IntroLabTrainingComposition(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize, cutAngle: model.cutAngle, distance: model.distance)
            case .reference: IntroLabReferenceComposition(size: bounds, wide: wide, accessibility: dynamicType.isAccessibilitySize, titleSize: titleSize, bodySize: bodySize, cutAngle: model.cutAngle, distance: model.distance)
            }
        }
        .frame(width: bounds.width, height: bounds.height)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(0..<6) { i in
                    Capsule().fill(i == 0 ? style.accent : secondary.opacity(0.3))
                        .frame(width: i == 0 ? 26 : 14, height: 2)
                }
            }.accessibilityLabel("学习介绍，第1页，共6页")
            Button { sheet = .finish } label: {
                Text("继续").font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(style == .editorial ? Color("introLabWhite") : Color("introLabInk"))
            .background(style.accent, in: RoundedRectangle(cornerRadius: 13))
            .accessibilityIdentifier("introLab.continue")
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(style.background)
    }
}

private enum IntroLabStyle: String, CaseIterable, Identifiable {
    case minimal, precision, cinematic, editorial, training, reference
    var id: String { rawValue }
    var title: String {
        switch self {
        case .reference: return "r6 · 原生基准"
        case .minimal: return "方案一 · 极简沉浸"
        case .precision: return "方案二 · 运动科技"
        case .cinematic: return "方案三 · 电影场景"
        case .editorial: return "方案四 · 杂志编辑"
        case .training: return "方案五 · 系统训练"
        }
    }
    static var initial: Self {
        let value = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("-intro.style=") }?.split(separator: "=").last
        return value.flatMap { Self(rawValue: String($0)) } ?? .minimal
    }
    var background: Color {
        switch self {
        case .minimal, .cinematic, .reference: return Color("introLabBackground")
        case .precision: return Color("introLabTechnical")
        case .editorial: return Color("introLabPaper")
        case .training: return Color("introLabTraining")
        }
    }
    var accent: Color {
        self == .editorial ? Color("introLabEditorialGreen") : (self == .precision ? Color("introLabSignal") : Color("introLabGreen"))
    }
}

/// One scene per lab session; no business view model, UserDefaults write or game controller.
@MainActor
private final class IntroLabScene: ObservableObject {
    let scene = AngleTrainingScene()
    @Published private(set) var ready = false
    @Published private(set) var failure: String?
    @Published private(set) var cutAngle = "—"
    @Published private(set) var distance = "—"
    private var preparing = false

    func prepare() async {
        guard !preparing else { return }
        preparing = true
        await Task.yield()
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        guard scene.cueStick?.applyStyle(.blackGold) == true else {
            failure = "球杆资源加载失败"; return
        }
        scene.applyTableStyle(.charcoal, showsSights: true)
        scene.applyClothColor(.green)
        scene.hideAllBalls(); scene.hideCueStick()
        scene.setupVisualizationNodes(); scene.hideAllVisualization()
        // Same physical fixture as r6: metres, X-Z cloth, Y up, true radius.
        let y = scene.surfaceY + BallPhysics.radius
        let cue = SCNVector3(-0.72, y, -0.1), target = SCNVector3(0.78, y, -0.20)
        let prediction = ShotPredictor.predict(
            ShotInput(cueBall: cue, targetBall: target, pocketIndex: 1, velocity: 2.5,
                      spinX: 0, spinY: 0, surfaceY: scene.surfaceY), maxEvents: 2000, maxTime: 30)
        guard prediction.hasFinalTableState, prediction.objectPocketed else {
            failure = "示例球路未完成求解"; return
        }
        scene.showBall(key: PositionPlayBall.cueKey, scenePosition: cue)
        scene.showBall(key: "_1", scenePosition: target)
        scene.updateVisualization(cueBall: cue, targetBall: target, pocket: prediction.pocketAimPoint,
                                  showAngleAnnotations: false, showOverlapMarkers: false, showLineLabels: false)
        let aim = prediction.aimDirection
        let strike = CueStroke.strikePosition(cue: cue, aim: aim, spinX: 0, spinY: 0)
        guard case .angle(let elevation) = CueStick.requiredElevation(
            cueBallPosition: strike, aimDirection: aim,
            obstacleCenters: scene.cueObstacleCenters(excludingStrikeNear: strike)) else {
            failure = "示例球杆无法安全摆放"; return
        }
        scene.updateCueStick(cueBallPosition: strike, aimDirection: aim, pullBack: 0.02, elevationOverride: elevation)
        scene.setCameraMode(.perspective3D, animated: false)
        scene.cameraNode.position = SCNVector3(cue.x - 0.60 * aim.x, scene.surfaceY + 0.33, cue.z - 0.60 * aim.z)
        scene.cameraNode.look(at: SCNVector3(cue.x + 0.35 * aim.x, scene.surfaceY + 0.03, cue.z + 0.35 * aim.z),
                              up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.cameraNode.camera?.usesOrthographicProjection = false
        scene.cameraNode.camera?.projectionDirection = .vertical
        if let angle = prediction.cutAngleDeg { cutAngle = String(format: "%.1f°", angle) }
        distance = String(format: "%.2f m", AngleSceneCalculator.horizontalDistance(cue, target))
        SCNTransaction.flush()
        ready = true
    }
}

/// Uses the existing native scene/materials with a static on-demand renderer.
/// Keeping this view outside layout branches preserves the renderer across style switches.
private struct IntroLabRenderer: UIViewRepresentable {
    @ObservedObject var model: IntroLabScene
    func makeUIView(context: Context) -> IntroLabViewport {
        let view = IntroLabViewport()
        view.accessibilityIdentifier = "introLab.nativeViewport"
        view.isAccessibilityElement = true
        view.accessibilityLabel = "原生三维瞄准场景"
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = false
        view.rendersContinuously = false
        return view
    }
    func updateUIView(_ view: IntroLabViewport, context: Context) {
        guard model.ready else { return }
        if view.scene !== model.scene {
            view.scene = model.scene
            view.pointOfView = model.scene.cameraNode
            view.delegate = model.scene.contactOcclusion
        }
        view.accessibilityValue = "ready; scene=\(ObjectIdentifier(model.scene)); renderer=\(ObjectIdentifier(view))"
        view.setNeedsLayout()
        view.setNeedsDisplay()
    }
    static func dismantleUIView(_ view: IntroLabViewport, coordinator: ()) {
        view.delegate = nil; view.scene = nil
    }
}
private final class IntroLabViewport: SCNView {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, let camera = pointOfView?.camera else { return }
        // Preserve the r6 horizontal field for tall slots; never stretch the table.
        let aspect = bounds.width / bounds.height
        let baseVertical = 48.0 * Double.pi / 180
        let horizontalTangent = tan(baseVertical / 2) * (1600.0 / 1500.0)
        camera.fieldOfView = max(48, 2 * atan(horizontalTangent / Double(aspect)) * 180 / Double.pi)
        SCNTransaction.flush()
        setNeedsDisplay()
    }
}

#Preview("Dark · native design lab") { OnboardingStyleLab().preferredColorScheme(.dark) }
#Preview("Light · native design lab") { OnboardingStyleLab().preferredColorScheme(.light) }
private struct IntroLabReferenceComposition: View {
    let size: CGSize
    let wide: Bool
    let accessibility: Bool
    let titleSize: CGFloat
    let bodySize: CGFloat
    let cutAngle: String
    let distance: String
    static func sceneRect(size: CGSize, wide: Bool, accessibility: Bool, titleSize: CGFloat, bodySize: CGFloat) -> CGRect {
        let top = accessibility ? titleSize * 5 + 100 : 166.0
        return CGRect(x: 16, y: top, width: max(1, size.width - 32), height: max(1, size.height - top - 8))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("01 / 瞄准").font(.caption).foregroundStyle(Color("introLabGreen"))
            Text("进球，\n从看准开始。")
                .font(.system(size: titleSize, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("introLab.title")
        }
        .padding(.horizontal, 28).padding(.top, 20)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
#endif
