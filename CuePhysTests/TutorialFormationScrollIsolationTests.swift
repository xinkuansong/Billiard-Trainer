import XCTest
import SwiftUI
@testable import QiuJi

/// DR-076：多球形精讲分段在滚动外；单球形不出分段。
/// 滚动隔离本身靠各球形自带 ScrollView（退出即清），此处锁住「分段是否上屏」这条布局契约。
final class TutorialFormationScrollIsolationTests: XCTestCase {

    @MainActor
    func test_multiFormation_showsSegmentedPickerOnFirstPaint() {
        let host = hosted(DrillTutorialView(drill: Self.twoFormationDrill()))
        let picker = Self.firstSegmentedControl(in: host.view)
        XCTAssertNotNil(picker, "多球形精讲必须在首屏画出球形分段（不得埋进未访问页的 ScrollView）")
        XCTAssertEqual(picker?.numberOfSegments, 2)
        XCTAssertEqual(
            Self.hostingScrollViewCount(in: host.view), 1,
            "首访只建当前球形的 ScrollView；未打开过的不预建"
        )
    }

    @MainActor
    func test_singleFormation_hidesSegmentedPicker() {
        let host = hosted(DrillTutorialView(drill: Self.singleFormationDrill()))
        XCTAssertNil(
            Self.firstSegmentedControl(in: host.view),
            "单球形精讲不应出现球形分段"
        )
        XCTAssertEqual(Self.hostingScrollViewCount(in: host.view), 1)
    }

    @MainActor
    private func hosted<V: View>(_ view: V) -> UIHostingController<V> {
        let host = UIHostingController(rootView: view)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 1200)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        return host
    }

    private static func firstSegmentedControl(in view: UIView) -> UISegmentedControl? {
        if let control = view as? UISegmentedControl { return control }
        for child in view.subviews {
            if let found = firstSegmentedControl(in: child) { return found }
        }
        return nil
    }

    private static func hostingScrollViewCount(in view: UIView) -> Int {
        let here = String(describing: type(of: view)).contains("HostingScrollView") ? 1 : 0
        return here + view.subviews.reduce(0) { $0 + hostingScrollViewCount(in: $1) }
    }

    private static func twoFormationDrill() -> DrillContent {
        fixture(tutorial: DrillTutorial(
            tutorialKind: .multiShot,
            formations: [
                TutorialFormation(
                    id: "f1", title: "球形 1",
                    sections: [TutorialSection(title: "第1杆·球形1独有", content: "球形1开篇")]
                ),
                TutorialFormation(
                    id: "f2", title: "球形 2",
                    sections: [TutorialSection(title: "第1杆·球形2独有", content: "球形2开篇")]
                ),
            ]
        ))
    }

    private static func singleFormationDrill() -> DrillContent {
        fixture(tutorial: DrillTutorial(
            tutorialKind: .multiShot,
            sections: [TutorialSection(title: "单球形正文", content: "只有一页")]
        ))
    }

    private static func fixture(tutorial: DrillTutorial) -> DrillContent {
        DrillContent(
            id: "drill_test_formation_scroll",
            nameZh: "滚动隔离夹具",
            nameEn: "Scroll Isolation Fixture",
            category: "accuracy",
            subcategory: "straight",
            ballType: ["chinese8"],
            level: "L0",
            difficulty: 1,
            isPremium: false,
            description: "test",
            coachingPoints: ["test"],
            standardCriteria: "test",
            sets: .init(defaultSets: 1, defaultBallsPerSet: 1),
            animation: DrillAnimation(
                cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: []),
                targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: []),
                pocket: "bottomCenter",
                cueDirection: CanvasPoint(x: 0.5, y: 0.0)
            ),
            tutorial: tutorial
        )
    }
}
