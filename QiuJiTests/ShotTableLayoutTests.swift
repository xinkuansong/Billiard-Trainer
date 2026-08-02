import XCTest
import CoreGraphics
@testable import QiuJi

/// 击打页共享布局几何单测（问题集合 v3 §S1）。
///
/// 验证 `ShotTableLayout.tableRect` 与相机取景 `CameraRig.fitRotatedTable` 同源、
/// 且满足「居中 / 完整可见 / 取景 scale 分支正确」不变量（geometry-spatial-reasoning §5）。
final class ShotTableLayoutTests: XCTestCase {

    private let halfL = ShotTableLayout.defaultHalfLength   // 1.4055
    private let halfW = ShotTableLayout.defaultHalfWidth    // 0.7995

    // MARK: - 取景 scale 分支

    func test_scale_unifiedGovernsOnTypicalPhone() {
        // 常规手机竖屏视口：统一 scale(1.50) 兜底应生效（H/W < 1.854）。
        let s = ShotTableLayout.orthographicScale(
            containerSize: CGSize(width: 402, height: 560),
            halfLength: halfL, halfWidth: halfW
        )
        XCTAssertEqual(s, CameraRig.rotatedUnifiedScale, accuracy: 1e-9,
                       "常规视口下统一 scale 兜底生效")
    }

    func test_scale_horizontalFitGovernsOnNarrowTallViewport() {
        // 极窄高视口：横轴约束 halfW·margin·(H/W) 超过统一 scale。
        let W: CGFloat = 300, H: CGFloat = 800
        let s = ShotTableLayout.orthographicScale(
            containerSize: CGSize(width: W, height: H),
            halfLength: halfL, halfWidth: halfW
        )
        let expected = halfW * CameraRig.rotatedFitMargin * Double(H / W)
        XCTAssertEqual(s, expected, accuracy: 1e-9, "窄高视口下横轴约束主导")
        XCTAssertGreaterThan(s, CameraRig.rotatedUnifiedScale)
    }

    // MARK: - 球桌矩形数值（手算金标准）

    func test_tableRect_matchesHandComputedOnTypicalPhone() {
        let size = CGSize(width: 402, height: 560)
        let rect = ShotTableLayout.tableRect(in: size, halfLength: halfL, halfWidth: halfW)
        // scale=1.50 ⇒ tableH = halfL·H/scale、tableW = halfW·H/scale。
        let expectedH = CGFloat(halfL) * size.height / CGFloat(CameraRig.rotatedUnifiedScale)
        let expectedW = CGFloat(halfW) * size.height / CGFloat(CameraRig.rotatedUnifiedScale)
        XCTAssertEqual(rect.height, expectedH, accuracy: 0.01)
        XCTAssertEqual(rect.width, expectedW, accuracy: 0.01)
        XCTAssertEqual(rect.height, 524.72, accuracy: 0.1)
        XCTAssertEqual(rect.width, 298.48, accuracy: 0.1)
        XCTAssertEqual(rect.minX, 51.76, accuracy: 0.1)
        XCTAssertEqual(rect.minY, 17.64, accuracy: 0.1)
    }

    // MARK: - 不变量：居中 + 完整可见

    func test_invariants_centeredAndWithinBounds() {
        let sizes = [CGSize(width: 402, height: 560),
                     CGSize(width: 390, height: 700),
                     CGSize(width: 430, height: 620),
                     CGSize(width: 300, height: 800),
                     CGSize(width: 500, height: 500)]
        for size in sizes {
            let r = ShotTableLayout.tableRect(in: size, halfLength: halfL, halfWidth: halfW)
            // 居中
            XCTAssertEqual(r.midX, size.width / 2, accuracy: 0.01, "水平居中 \(size)")
            XCTAssertEqual(r.midY, size.height / 2, accuracy: 0.01, "竖直居中 \(size)")
            // 完整可见（不出容器）
            XCTAssertGreaterThanOrEqual(r.minX, -0.01, "左不出界 \(size)")
            XCTAssertGreaterThanOrEqual(r.minY, -0.01, "上不出界 \(size)")
            XCTAssertLessThanOrEqual(r.maxX, size.width + 0.01, "右不出界 \(size)")
            XCTAssertLessThanOrEqual(r.maxY, size.height + 0.01, "下不出界 \(size)")
            // 长宽比 = 外框长宽比（rotated：竖轴=长、横轴=宽）
            XCTAssertEqual(r.height / r.width, CGFloat(halfL / halfW), accuracy: 1e-3,
                           "屏幕长宽比 = 外框长宽比 \(size)")
        }
    }

    func test_tableRect_zeroForInvalidSize() {
        XCTAssertEqual(ShotTableLayout.tableRect(in: .zero), .zero)
    }

    // MARK: - 击球区内框（库边内侧）

    func test_playingRect_scalesByInnerOuterHalfWidth() {
        let size = CGSize(width: 402, height: 560)
        let outer = ShotTableLayout.tableRect(in: size, halfLength: halfL, halfWidth: halfW)
        let playing = ShotTableLayout.playingRect(outer: outer,
                                                  outerHalfLength: halfL,
                                                  outerHalfWidth: halfW)
        let innerHalfW = Double(AngleSceneCalculator.innerWidth) / 2
        let expectedW = outer.width * CGFloat(innerHalfW / halfW)
        XCTAssertEqual(playing.width, expectedW, accuracy: 0.01)
        XCTAssertEqual(playing.midX, outer.midX, accuracy: 0.01)
        XCTAssertEqual(playing.midY, outer.midY, accuracy: 0.01)
        XCTAssertLessThan(playing.width, outer.width)
        let proxy = ShotStageProxy(sceneSize: size, halfLength: halfL, halfWidth: halfW)
        XCTAssertEqual(proxy.playingRect.width, playing.width, accuracy: 0.01)
        // 打点盘底边贴击球区下沿：padding = sceneHeight − playingRect.maxY。
        XCTAssertEqual(proxy.spinPadBottomPadding,
                       size.height - proxy.playingRect.maxY, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(proxy.spinPadBottomPadding, 0)
    }

    // MARK: - Proxy 贴边定位（G4/G5/G6）

    func test_proxy_edgeAlignment() {
        let proxy = ShotStageProxy(sceneSize: CGSize(width: 402, height: 560),
                                   halfLength: halfL, halfWidth: halfW)
        XCTAssertTrue(proxy.isValid)
        // G4：刻度轮右缘贴球桌左侧；仪表柱左缘贴球桌右侧。
        XCTAssertEqual(proxy.aimWheelFrame().maxX, proxy.tableRect.minX, accuracy: 0.01)
        XCTAssertEqual(proxy.instrumentFrame().minX, proxy.tableRect.maxX, accuracy: 0.01)
        // G5：刻度轮底部 = 力度条本体底部（同 controlBottomY）。
        XCTAssertEqual(proxy.aimWheelFrame().maxY, proxy.controlBottomY, accuracy: 0.01)
        XCTAssertEqual(proxy.instrumentFrame().maxY, proxy.controlBottomY, accuracy: 0.01)
        // G5：等长——刻度轮长 = 仪表柱本体长（总高减顶部固定区）。
        XCTAssertEqual(proxy.aimWheelFrame().height,
                       proxy.instrumentFrame().height - ShotStageMetrics.instrumentTopReserve,
                       accuracy: 0.01)
        // G6：开球按钮 / 动作列底边齐球桌底线。
        XCTAssertEqual(proxy.breakButtonFrame().maxY, proxy.tableRect.maxY, accuracy: 0.01)
        XCTAssertEqual(proxy.actionColumnFrame().maxY, proxy.tableRect.maxY, accuracy: 0.01)
        // 不超出球桌上沿（G6）。
        XCTAssertGreaterThanOrEqual(proxy.instrumentFrame().minY, proxy.tableRect.minY - 0.01)
        // G8：球库宽 = 球桌宽。
        XCTAssertEqual(proxy.libraryWidth, proxy.tableRect.width, accuracy: 0.01)
    }
}

/// 规则引擎「合法目标球」查询单测（问题集合 v3 P10.2）。
@MainActor
final class RulesLegalTargetTests: XCTestCase {

    private var fullTable: Set<String> { Set((1...15).map { "_\($0)" }) }

    func test_eightBall_openTable_excludesEight() {
        let engine = ChineseEightBallRules()
        let legal = engine.legalTargetKeys(tableKeys: fullTable)
        XCTAssertFalse(legal.contains("_8"), "开放局 8 号非法首触")
        XCTAssertTrue(legal.contains("_1"))
        XCTAssertTrue(legal.contains("_9"))
    }

    func test_eightBall_afterGroupAssigned_onlyOwnGroup() {
        let engine = ChineseEightBallRules()
        // A 打进全色 → A 持全色（1–7）。
        engine.judge(ShotFacts(firstContactKey: "_3", pocketedKeys: ["_3"],
                               cuePocketed: false, railOrPocketAfterContact: true,
                               tableKeysBefore: fullTable))
        let table = fullTable.subtracting(["_3"])
        let legal = engine.legalTargetKeys(tableKeys: table)
        XCTAssertTrue(legal.allSatisfy { BallGroup.of($0) == .solid }, "仅本方全色合法")
        XCTAssertFalse(legal.contains("_9"))
        XCTAssertFalse(legal.contains("_8"))
    }

    func test_zhuifen_onlyLowestNumber() {
        let engine = ZhuifenRules()
        let table: Set<String> = ["_2", "_5", "_9"]
        let legal = engine.legalTargetKeys(tableKeys: table)
        XCTAssertEqual(legal, ["_2"], "追分仅最小号合法")
    }
}
