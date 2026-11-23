import XCTest
@testable import QiuJi

/// 问题集合 v3 批次 S3 — G1 瞄准点几何金标准。
///
/// G1 定义：瞄准点 = 瞄准线与「过目标球中心且垂直于瞄准线的直线」的交点（垂足），
/// 参考目标球定义，不等于假想球心。覆盖：穿球 / 不穿球两种情形的交点计算、
/// d = 2R·sin(θ) 数值关系、左右切方向口径（P8.4）。
final class AimPointGeometryTests: XCTestCase {

    private let R: CGFloat = 0.028575  // 中八球半径（米）

    // MARK: - 交点计算（穿球 / 不穿球）

    /// 穿球情形：瞄准线穿过目标球（垂距 < R）⇒ 瞄准点在球内；
    /// 正确瞄准 θ=20°（sin20°≈0.342，2R·sin < R）时垂距 = 2R·sin(θ)。
    func test_aimPoint_lineThroughBall_footInsideBall() {
        let theta: CGFloat = 20 * .pi / 180
        let layout = makeCutLayout(theta: theta)
        let foot = AimPointGeometry.aimPoint(lineOrigin: layout.cue,
                                             direction: layout.aimDir,
                                             targetCenter: layout.target)
        let dist = hypot(foot.x - layout.target.x, foot.y - layout.target.y)
        XCTAssertEqual(dist, 2 * R * sin(theta), accuracy: 1e-9)
        XCTAssertLessThan(dist, R, "θ<30° 时瞄准点应在目标球内")
        // 垂足在瞄准线上：foot−cue 与 aimDir 共线（叉积 ≈ 0）。
        let cross = (foot.x - layout.cue.x) * layout.aimDir.y
                  - (foot.y - layout.cue.y) * layout.aimDir.x
        XCTAssertEqual(cross, 0, accuracy: 1e-9)
        // 垂直性：foot−target ⊥ aimDir。
        let dot = (foot.x - layout.target.x) * layout.aimDir.x
                + (foot.y - layout.target.y) * layout.aimDir.y
        XCTAssertEqual(dot, 0, accuracy: 1e-9)
    }

    /// 不穿球情形：瞄准线从目标球侧面经过（θ>30° ⇒ 垂距 = 2R·sin(θ) > R）⇒ 瞄准点在球外。
    func test_aimPoint_lineMissesBall_footOutsideBall() {
        let theta: CGFloat = 50 * .pi / 180
        let layout = makeCutLayout(theta: theta)
        let foot = AimPointGeometry.aimPoint(lineOrigin: layout.cue,
                                             direction: layout.aimDir,
                                             targetCenter: layout.target)
        let dist = hypot(foot.x - layout.target.x, foot.y - layout.target.y)
        XCTAssertEqual(dist, 2 * R * sin(theta), accuracy: 1e-9)
        XCTAssertGreaterThan(dist, R, "θ>30° 时瞄准点应在目标球外")
    }

    /// 边界：θ=30° 时垂距恰为 R（瞄准点在球面上）；正对直球垂距 = 0（瞄准点=球心）。
    func test_aimPoint_boundaryAngles() {
        let layout30 = makeCutLayout(theta: 30 * .pi / 180)
        XCTAssertEqual(AimPointGeometry.offsetDistance(lineOrigin: layout30.cue,
                                                       direction: layout30.aimDir,
                                                       targetCenter: layout30.target),
                       R, accuracy: 1e-9)

        let straight = makeCutLayout(theta: 0)
        let foot = AimPointGeometry.aimPoint(lineOrigin: straight.cue,
                                             direction: straight.aimDir,
                                             targetCenter: straight.target)
        XCTAssertEqual(foot.x, straight.target.x, accuracy: 1e-9)
        XCTAssertEqual(foot.y, straight.target.y, accuracy: 1e-9)
    }

    /// 瞄准点比假想球心沿瞄准方向前移 2R·cos(θ)（G1 ≠ 旧口径的直接量化证据）。
    func test_aimPoint_differsFromGhostCenter() {
        let theta: CGFloat = 32 * .pi / 180
        let layout = makeCutLayout(theta: theta)
        let foot = AimPointGeometry.aimPoint(lineOrigin: layout.cue,
                                             direction: layout.aimDir,
                                             targetCenter: layout.target)
        let advance = (foot.x - layout.ghost.x) * layout.aimDir.x
                    + (foot.y - layout.ghost.y) * layout.aimDir.y
        XCTAssertEqual(advance, 2 * R * cos(theta), accuracy: 1e-9)
    }

    // MARK: - 有符号偏移（误差口径）

    func test_signedOffset_signFollowsNormalSide() {
        let theta: CGFloat = 25 * .pi / 180
        let layout = makeCutLayout(theta: theta)
        let foot = AimPointGeometry.aimPoint(lineOrigin: layout.cue,
                                             direction: layout.aimDir,
                                             targetCenter: layout.target)
        let normal = CGPoint(x: foot.x - layout.target.x, y: foot.y - layout.target.y)
        let s = AimPointGeometry.signedOffset(lineOrigin: layout.cue,
                                              direction: layout.aimDir,
                                              targetCenter: layout.target,
                                              positiveNormal: normal)
        XCTAssertEqual(s, 2 * R * sin(theta), accuracy: 1e-9)
        // 反向法向 ⇒ 符号翻转（瞄错侧为负的机制）。
        let sFlipped = AimPointGeometry.signedOffset(
            lineOrigin: layout.cue, direction: layout.aimDir,
            targetCenter: layout.target,
            positiveNormal: CGPoint(x: -normal.x, y: -normal.y))
        XCTAssertEqual(sFlipped, -2 * R * sin(theta), accuracy: 1e-9)
    }

    // MARK: - 左右切口径（P8.4）

    /// 「向左切」= 目标球向左移动 ⇒ 母球应打目标球右侧 ⇒ 瞄准点在目标球右侧。
    /// 视图系（x 右、y 下）构造：瞄准方向朝上（0,−1），进球方向偏左。
    func test_cutDirection_targetMovesLeft_aimPointOnRightSide() {
        let theta: CGFloat = 30 * .pi / 180
        let target = CGPoint.zero
        // 目标球向左上移动（左切）：进球方向 = 瞄准方向 (0,−1) 向左偏 θ。
        let potDir = CGPoint(x: -sin(theta), y: -cos(theta))
        let ghost = CGPoint(x: target.x - 2 * R * potDir.x,
                            y: target.y - 2 * R * potDir.y)
        XCTAssertGreaterThan(ghost.x, target.x, "左切 ⇒ 假想球在目标球右侧")
        let aimDir = CGPoint(x: 0, y: -1)
        let cue = CGPoint(x: ghost.x, y: ghost.y + 0.4)  // 母球在假想球正下方
        let foot = AimPointGeometry.aimPoint(lineOrigin: cue, direction: aimDir,
                                             targetCenter: target)
        XCTAssertGreaterThan(foot.x, target.x, "左切 ⇒ 瞄准点在目标球右侧")
        // 右侧为正法向时偏移为正，量值 = 2R·sin(θ)。
        let s = AimPointGeometry.signedOffset(lineOrigin: cue, direction: aimDir,
                                              targetCenter: target,
                                              positiveNormal: CGPoint(x: 1, y: 0))
        XCTAssertEqual(s, 2 * R * sin(theta), accuracy: 1e-9)
    }

    /// 瞄准点训练 VM 口径：向右切（cutsRight）⇒ 正确 φ < 0（假想球在目标球左侧）；
    /// 用户拖到正确位置时 userOffsetMM == correctOffsetMM，拖错侧时为负。
    @MainActor
    func test_trainingVM_cutDirectionConvention() {
        let vm = AimPointTrainingViewModel(limiter: AngleUsageLimiter())
        let q = AimPointTrainingViewModel.Question(angleDegrees: 30, cutsRight: true)

        // 借 nextQuestion 不可控随机，直接验证纯函数口径。
        XCTAssertEqual(vm.correctOffsetMM(for: q),
                       2 * AimPointTrainingViewModel.ballRadiusMM * 0.5,
                       accuracy: 1e-9)

        // 图形系 φ>0 = 假想球在目标球右侧。向右切 ⇒ 正确在左侧（φ<0）。
        vm.setQuestionForTesting(q)
        XCTAssertLessThan(vm.correctPhi, 0, "向右切 ⇒ 假想球应在目标球左侧")

        vm.userPhi = vm.correctPhi
        XCTAssertEqual(vm.userOffsetMM, vm.correctOffsetMM(for: q), accuracy: 1e-9)

        vm.userPhi = -vm.correctPhi   // 拖错侧
        XCTAssertEqual(vm.userOffsetMM, -vm.correctOffsetMM(for: q), accuracy: 1e-9)

        // 向左切镜像口径。
        let qL = AimPointTrainingViewModel.Question(angleDegrees: 30, cutsRight: false)
        vm.setQuestionForTesting(qL)
        XCTAssertGreaterThan(vm.correctPhi, 0, "向左切 ⇒ 假想球应在目标球右侧")
    }

    // MARK: - Helpers

    /// 标准切球布局（平面系无关）：目标球在原点，进球方向 +x，
    /// 假想球 = target − 2R·potDir，瞄准方向 = potDir 旋 θ，母球在瞄准线后方。
    private func makeCutLayout(theta: CGFloat)
        -> (cue: CGPoint, target: CGPoint, ghost: CGPoint, aimDir: CGPoint) {
        let target = CGPoint.zero
        let potDir = CGPoint(x: 1, y: 0)
        let ghost = CGPoint(x: target.x - 2 * R * potDir.x,
                            y: target.y - 2 * R * potDir.y)
        let aimDir = CGPoint(x: cos(theta), y: sin(theta))
        let cue = CGPoint(x: ghost.x - aimDir.x * 0.5, y: ghost.y - aimDir.y * 0.5)
        return (cue, target, ghost, aimDir)
    }
}
