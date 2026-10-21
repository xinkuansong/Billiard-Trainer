import SwiftUI
import UIKit

/// Decorative balls travel across the full capsule, in front of its title and arrow.
struct DailyClearanceAnimatedLabel: View {
    let title: String
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: DailyClearanceButtonMotion.rackSize,
                              height: DailyClearanceButtonMotion.rackSize)
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                Text(title)
                    .font(.btSubheadlineSemibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "chevron.right")
                    .font(.btCaption2.weight(.bold))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .frame(minHeight: 44)
        .overlay {
            DailyClearanceMotionSurface(
                color: TrainingPhotoStyle.ink,
                isRunning: isActive && isVisible && scenePhase == .active && !reduceMotion
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

private struct DailyClearanceMotionSurface: UIViewRepresentable {
    let color: Color
    let isRunning: Bool

    func makeUIView(context: Context) -> DailyClearanceMotionUIView {
        DailyClearanceMotionUIView()
    }

    func updateUIView(_ view: DailyClearanceMotionUIView, context: Context) {
        view.configure(color: UIColor(color), running: isRunning)
    }

    static func dismantleUIView(_ view: DailyClearanceMotionUIView, coordinator: ()) {
        view.stop()
    }
}

/// Core Animation plays six small position tracks without refreshing the home view each frame.
private final class DailyClearanceMotionUIView: UIView {
    private let balls = (0..<6).map { _ in CAShapeLayer() }
    private let rack = CAShapeLayer()
    private var renderedBounds = CGRect.zero
    private var wantsAnimation = false
    private var motion: DailyClearanceButtonMotion?
    private var ink = UIColor.clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        for ball in balls { layer.addSublayer(ball) }
        layer.addSublayer(rack)
        rack.fillColor = UIColor.clear.cgColor
        rack.lineJoin = .miter
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(color: UIColor, running: Bool) {
        ink = color
        wantsAnimation = running
        setNeedsLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() } else { setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > bounds.height, bounds.height >= 28 else { return }
        let changed = renderedBounds != bounds
        if changed {
            stop()
            renderedBounds = bounds
            motion = DailyClearanceButtonMotion(size: bounds.size)
        }
        guard let motion else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.cornerRadius = bounds.height / 2
        layer.masksToBounds = true
        for (index, ball) in balls.enumerated() {
            ball.path = UIBezierPath(ovalIn: CGRect(x: -motion.radius, y: -motion.radius,
                                                  width: 2 * motion.radius, height: 2 * motion.radius)).cgPath
            ball.fillColor = ink.cgColor
            ball.position = motion.home[index]
        }
        let r = DailyClearanceButtonMotion.rackSize / 2
        let line = DailyClearanceButtonMotion.rackSize * 0.05
        let pathRadius = r - line
        let triangle = UIBezierPath()
        triangle.move(to: CGPoint(x: 0, y: -pathRadius))
        triangle.addLine(to: CGPoint(x: -pathRadius * sqrt(3) / 2, y: pathRadius / 2))
        triangle.addLine(to: CGPoint(x: pathRadius * sqrt(3) / 2, y: pathRadius / 2))
        triangle.close()
        rack.path = triangle.cgPath
        rack.position = CGPoint(x: 8 + r, y: bounds.midY)
        rack.lineWidth = line
        rack.strokeColor = ink.cgColor
        rack.opacity = 0.7
        CATransaction.commit()
        if wantsAnimation && window != nil {
            if rack.animation(forKey: "rackOpacity") == nil { play(motion) }
        } else { stop() }
    }

    func stop() {
        balls.forEach { $0.removeAllAnimations() }
        rack.removeAllAnimations()
    }

    private func play(_ motion: DailyClearanceButtonMotion) {
        let count = Int(DailyClearanceButtonMotion.duration * Double(DailyClearanceButtonMotion.sampleRate))
        let frames = (0...count).map {
            motion.frame(at: Double($0) / Double(DailyClearanceButtonMotion.sampleRate))
        }
        let begin = layer.convertTime(CACurrentMediaTime(), from: nil) + 0.8
        func animation(_ keyPath: String, values: [Any]) -> CAKeyframeAnimation {
            let a = CAKeyframeAnimation(keyPath: keyPath)
            a.values = values
            a.duration = DailyClearanceButtonMotion.duration
            a.repeatCount = .greatestFiniteMagnitude
            a.calculationMode = .linear
            a.beginTime = begin
            a.isRemovedOnCompletion = true
            return a
        }
        for (index, ball) in balls.enumerated() {
            ball.add(animation("position", values: frames.map { NSValue(cgPoint: $0.balls[index]) }),
                     forKey: "ballLoop")
        }
        rack.add(animation("opacity", values: frames.map { NSNumber(value: Double($0.rackOpacity)) }),
                 forKey: "rackOpacity")
        rack.add(animation("transform.translation.y", values: frames.map { NSNumber(value: Double($0.rackLift)) }),
                 forKey: "rackLift")
    }
}

#Preview("Light") {
    DailyClearanceAnimatedLabel(title: "每日清台", isActive: true)
        .foregroundStyle(TrainingPhotoStyle.ink)
        .background(TrainingPhotoStyle.foreground, in: Capsule())
        .padding()
}

#Preview("Dark") {
    DailyClearanceAnimatedLabel(title: "继续清台", isActive: true)
        .foregroundStyle(TrainingPhotoStyle.ink)
        .background(TrainingPhotoStyle.foreground, in: Capsule())
        .padding()
        .preferredColorScheme(.dark)
}
