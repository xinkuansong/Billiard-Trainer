import SwiftUI
import UIKit

/// The floor is drawn in the physical display's portrait coordinate space. Only
/// the transparent table and its controls inherit the phone's orientation.
struct ScreenAnchoredCarpet: UIViewControllerRepresentable {
    let style: RoomStyle
    let pointsPerMetre: CGFloat
    let scene: AngleTrainingScene
    static var applies: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.bind(scene)
        controller.setStyle(style, pointsPerMetre: pointsPerMetre)
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.detach()
    }

    final class Controller: UIViewController {
        private let carpet = UIImageView()
        private weak var scene: AngleTrainingScene?

        private var initialPointsPerMetre: CGFloat?
        private var portraitTableLength: CGFloat?
        private static let owners = NSMapTable<UIWindow, Controller>.weakToWeakObjects()
        private weak var registeredWindow: UIWindow?
        private var hold: PhysicalPortraitHold?
        private var backing: UIView?
        private weak var movingRoot: UIView?
        private var waiting = false
        private var afterPortraitPresented: (() -> Void)?
        private var displayLink: CADisplayLink?
        private var hasDisplayTick = false

        private var lastStyle: RoomStyle?

        func bind(_ scene: AngleTrainingScene) {
            self.scene = scene
            scene.usesScreenCarpet = true
        }

        func detach() {
            endTurn()
            scene?.usesScreenCarpet = false
            if let registeredWindow, Self.owner(in: registeredWindow) === self {
                Self.owners.removeObject(forKey: registeredWindow)
            }
        }

        static func owner(in window: UIWindow?) -> Controller? {
            guard let window else { return nil }
            return owners.object(forKey: window)
        }

        var needsLandscapeFrame: Bool { waiting }

        func prepareTurn(in window: UIWindow, onPortraitPresented: @escaping () -> Void) -> Bool {
            guard window.bounds.height > window.bounds.width, hold == nil,
                  let root = window.rootViewController?.view,
                  let snapshot = window.snapshotView(afterScreenUpdates: false) else { return false }
            let cover = PhysicalPortraitHold(frame: window.bounds)
            cover.picture = snapshot
            cover.addSubview(snapshot)
            cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            cover.accessibilityElementsHidden = true
            cover.isUserInteractionEnabled = false
            window.addSubview(cover)
            cover.layoutIfNeeded()
            hold = cover
            let floor = UIImageView(image: carpet.image)
            floor.isUserInteractionEnabled = false
            floor.accessibilityElementsHidden = true
            window.insertSubview(floor, at: 0)
            backing = floor
            movingRoot = root
            if let scene = window.windowScene {
                NotificationCenter.default.addObserver(self, selector: #selector(cancelForDeactivation),
                                                       name: UIScene.willDeactivateNotification, object: scene)
            }
            waiting = true
            afterPortraitPresented = onPortraitPresented
            hasDisplayTick = false
            let link = CADisplayLink(target: self, selector: #selector(portraitDisplayTick))
            displayLink = link
            link.add(to: .main, forMode: .common)
            positionCarpet()
            return true
        }

        @objc private func portraitDisplayTick() {
            // One presentation interval lets the window show the portrait snapshot
            // before UIKit can resize the live SceneKit surface underneath it.
            guard hasDisplayTick else { hasDisplayTick = true; return }
            displayLink?.invalidate()
            displayLink = nil
            let request = afterPortraitPresented
            afterPortraitPresented = nil
            request?()
        }

        func notePortraitTable(length: CGFloat) {
            if length.isFinite, length > 1 { portraitTableLength = length }
        }

        func finishTurn(tableLength: CGFloat) {
            guard waiting, let hold, let root = movingRoot else { return }
            waiting = false
            positionCarpet()
            let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.32
            let angle = -CGFloat.pi / 2
            if duration > 0 {
                func animate(_ layer: CALayer, rotation: CGFloat, scale: CGFloat, compensating: Bool = false) {
                    let turn = CABasicAnimation(keyPath: "transform.rotation.z")
                    turn.fromValue = rotation
                    turn.toValue = 0
                    turn.isAdditive = true
                    let fit = CAKeyframeAnimation(keyPath: "transform.scale")
                    fit.values = (0...60).map { sample in
                        let value = scale + (1 - scale) * CGFloat(sample) / 60
                        return compensating ? 1 / value : value
                    }
                    let group = CAAnimationGroup()
                    group.animations = [turn, fit]
                    group.duration = duration
                    group.timingFunction = .init(name: .easeInEaseOut)
                    layer.add(group, forKey: "tableEntryTurn")
                }
                // Scale the actual table from its measured portrait projection once.
                // Keep the floor at unit scale by drawing it below the moving page.
                let scale = tableLength.isFinite && tableLength > 1 ? (portraitTableLength ?? tableLength) / tableLength : 1
                CATransaction.begin()
                CATransaction.setCompletionBlock { [weak self, weak hold] in
                    guard let self, let hold, self.hold === hold else { return }
                    self.endTurn()
                }
                animate(root.layer, rotation: angle, scale: scale)
                animate(carpet.layer, rotation: -angle, scale: scale, compensating: true)
                hold.removeFromSuperview()
                CATransaction.commit()
            } else { endTurn() }
        }

        @objc private func cancelForDeactivation() {
            // Before the request, the display link resumes with the window. Dropping
            // that callback would leave the orientation owner waiting for a request.
            if afterPortraitPresented == nil { endTurn() }
        }

        func endTurn() {
            NotificationCenter.default.removeObserver(self, name: UIScene.willDeactivateNotification, object: nil)
            displayLink?.invalidate()
            displayLink = nil
            afterPortraitPresented = nil
            waiting = false
            hold?.removeFromSuperview()
            backing?.removeFromSuperview()
            movingRoot?.layer.removeAnimation(forKey: "tableEntryTurn")
            carpet.layer.removeAnimation(forKey: "tableEntryTurn")
            hold = nil
            backing = nil
            movingRoot = nil
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            endTurn()
            if let registeredWindow, Self.owner(in: registeredWindow) === self {
                Self.owners.removeObject(forKey: registeredWindow)
            }
        }

        private final class PhysicalPortraitHold: UIView {
            var picture: UIView?
            override func layoutSubviews() {
                super.layoutSubviews()
                guard let fixed = window?.windowScene?.screen.fixedCoordinateSpace, let picture else { return }
                Controller.place(picture, in: self, fixed: fixed, size: fixed.bounds.size)
            }
        }

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
            view.accessibilityElementsHidden = true
            view.addSubview(carpet)
        }

        func setStyle(_ style: RoomStyle, pointsPerMetre: CGFloat) {
            loadViewIfNeeded()
            if initialPointsPerMetre == nil, pointsPerMetre > 0 {
                initialPointsPerMetre = pointsPerMetre
            }
            guard style != lastStyle || carpet.image == nil else { return }
            lastStyle = style
            renderCarpetIfPossible()
        }

        private func renderCarpetIfPossible() {
            guard let screen = view.window?.windowScene?.screen,
                  let lastStyle, let initialPointsPerMetre else { return }
            let size = screen.fixedCoordinateSpace.bounds.size
            let side = ceil(hypot(size.width, size.height))
            let floor = DailyCarpetBackground(style: lastStyle, pointsPerMetre: initialPointsPerMetre)
                .frame(width: side, height: side)
            carpet.image = ImageRenderer(content: floor).uiImage
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            positionCarpet()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            positionCarpet()
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: { [weak self] _ in self?.positionCarpet() },
                                completion: { [weak self] _ in self?.positionCarpet() })
        }

        private func positionCarpet() {
            guard let window = view.window, let screen = window.windowScene?.screen else { return }
            if carpet.image == nil { renderCarpetIfPossible() }
            if Self.owner(in: window) !== self {
                Self.owners.setObject(self, forKey: window)
                registeredWindow = window
            }
            let fixed = screen.fixedCoordinateSpace
            let side = ceil(hypot(fixed.bounds.width, fixed.bounds.height))
            let size = CGSize(width: side, height: side)
            Self.place(carpet, in: view, fixed: fixed, size: size)
            if let backing { Self.place(backing, in: window, fixed: fixed, size: size) }
        }

        private static func place(_ child: UIView, in parent: UIView, fixed: UICoordinateSpace, size: CGSize) {
            let center = CGPoint(x: fixed.bounds.midX, y: fixed.bounds.midY)
            let origin = parent.convert(center, from: fixed)
            let right = parent.convert(CGPoint(x: center.x + 1, y: center.y), from: fixed)
            child.bounds = CGRect(origin: .zero, size: size)
            child.center = origin
            child.transform = CGAffineTransform(rotationAngle: atan2(right.y - origin.y, right.x - origin.x))
        }
    }
}
