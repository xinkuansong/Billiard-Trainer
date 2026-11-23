import XCTest
import SceneKit
@testable import QiuJi

final class TrainingLayoutDiversityTests: XCTestCase {
    private func board(cue: SCNVector3, target: SCNVector3, pocket: Int) -> TrainingBankBoard {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: 0)
        let angle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim)
        func band(_ value: Float) -> SceneTrainingConfiguration.Distance {
            value <= 0.6 ? .short : value <= 1.2 ? .middle : .long
        }
        let q = AngleQuestion(targetBall: AngleSceneCalculator.sceneToNormalized(position: target),
            cueBall: AngleSceneCalculator.sceneToNormalized(position: cue), pocket: AngleCalculator.pockets[pocket],
            actualAngle: angle, pocketType: pocket < 4 ? .corner : .side, pocketIndex: pocket)
        return .init(question: .init(id: UUID(), geometry: q, side: 1,
            cueBand: band(hypot(cue.x-target.x, cue.z-target.z)),
            pocketBand: band(hypot(target.x-aim.x, target.z-aim.z))), seed: 1)
    }
    private func same(_ a: TrainingBankBoard, _ b: TrainingBankBoard) -> Bool {
        let index = TrainingLayoutFamilyIndex(); index.insert(a)
        return index.duplicate(of: b) != nil
    }
    func testAll270InventoryCellsAreUniqueAndRandomIsNotACell() {
        XCTAssertEqual(TrainingInventoryCell.all.count, 270)
        XCTAssertEqual(Set(TrainingInventoryCell.all.map(\.id)).count, 270)
        XCTAssertTrue(TrainingInventoryCell.all.allSatisfy { $0.cueBand != .mixed && $0.pocketBand != .mixed })
    }
    func testExactMirrorAndSmallTranslationAreSameFamily() {
        let a = board(cue: SCNVector3(0.3,0,0.3), target: SCNVector3(-0.4,0,-0.1), pocket: 0)
        XCTAssertTrue(same(a,a))
        let mirror = board(cue: SCNVector3(-0.3,0,0.3), target: SCNVector3(0.4,0,-0.1), pocket: 1)
        XCTAssertTrue(same(a,mirror))
        let moved = board(cue: a.cue.vector+SCNVector3(0.001,0,0), target: a.target.vector+SCNVector3(0.001,0,0), pocket: 0)
        XCTAssertTrue(same(a,moved))
    }
    func testCrossDistanceBoundaryDoesNotCreateNewFamily() {
        let target = SCNVector3(-0.4,0,-0.1), pocket = 0
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: 0)
        let backward = (target-aim).normalized()
        let a = board(cue: target+backward*0.599, target: target, pocket: pocket)
        let b = board(cue: target+backward*0.601, target: target, pocket: pocket)
        XCTAssertNotEqual(a.cueBand,b.cueBand)
        XCTAssertTrue(same(a,b))
    }
    func testAngleChangeWithinThreeCentimetresMustSurvive() {
        let target = SCNVector3(-0.4,0,-0.1), pocket = 0
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: 0)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: BallPhysics.radius)
        let backward = (target-aim).normalized()
        let a = board(cue: ghost+backward*0.3, target: target, pocket: pocket)
        let b = board(cue: ghost+backward.rotatedY(3 * .pi / 180)*0.3, target: target, pocket: pocket)
        XCTAssertLessThan(hypot(a.cue.x-b.cue.x,a.cue.z-b.cue.z), 0.03)
        XCTAssertFalse(same(a,b))
    }
    func testFrozenAndNearMustNotMerge() {
        let a = board(cue: SCNVector3(0.2,0,0.2), target: SCNVector3(-0.6,0,-0.635+BallPhysics.radius), pocket: 0)
        let b = board(cue: a.cue.vector, target: a.target.vector+SCNVector3(0,0,0.001), pocket: 0)
        XCTAssertEqual(TrainingLayoutFeatures.railClass(TrainingLayoutFeatures(a).targetGap), 2)
        XCTAssertEqual(TrainingLayoutFeatures.railClass(TrainingLayoutFeatures(b).targetGap), 1)
        XCTAssertFalse(same(a,b))
    }
    func testIndexMatchesBruteForceAcrossBucketBoundaries() throws {
        let bank = try JSONDecoder().decode(TrainingQuestionBank.self,
            from: Data(contentsOf: try XCTUnwrap(Bundle.main.url(forResource: "training-question-bank", withExtension: "json"))))
        let index = TrainingLayoutFamilyIndex()
        var retained: [TrainingBankBoard] = []
        for b in bank.boards {
            let brute = retained.contains { old in
                [(Float(1),Float(1)),(-1,1),(1,-1),(-1,-1)].contains { sx,sz in
                    TrainingLayoutFeatures(b,sx:sx,sz:sz).isNear(TrainingLayoutFeatures(old))
                }
            }
            XCTAssertEqual(index.duplicate(of:b) != nil, brute)
            if !brute { index.insert(b); retained.append(b) }
        }
        XCTAssertGreaterThan(retained.count,0)
    }
    func testExportReviewPairsAndCurrentInventory() throws {
        struct Pair: Codable {
            let title: String
            let note: String
            let a: TrainingBankBoard
            let b: TrainingBankBoard
            let sameFamily: Bool
            let featuresA: TrainingLayoutFeatures
            let featuresB: TrainingLayoutFeatures
        }
        struct Rail: Codable { let start: TrainingBankPoint; let end: TrainingBankPoint }
        struct Review: Codable {
            let ruleVersion: String
            let radius: Float
            let length: Float
            let width: Float
            let pockets: [TrainingBankPoint]
            let rails: [Rail]
            let pairs: [Pair]
            let inventory: [String:Int]
        }
        let bank = try JSONDecoder().decode(TrainingQuestionBank.self,
            from: Data(contentsOf: try XCTUnwrap(Bundle.main.url(forResource: "training-question-bank", withExtension: "json"))))
        var pairs: [Pair] = []
        func add(_ title: String, _ note: String, _ a: TrainingBankBoard, _ b: TrainingBankBoard) {
            pairs.append(.init(title:title,note:note,a:a,b:b,sameFamily:same(a,b),
                               featuresA:.init(a),featuresB:.init(b)))
        }
        let a = board(cue: SCNVector3(0.3,0,0.3), target: SCNVector3(-0.4,0,-0.1), pocket: 0)
        add("完全相同／仅改打点或参考力度","球形身份不读取打点或力度；它们属于解的版本。",a,a)
        add("双球平移 1 mm","合成去重对照，未做进球资格验证。",a,
            board(cue:a.cue.vector+SCNVector3(0.001,0,0),target:a.target.vector+SCNVector3(0.001,0,0),pocket:0))
        add("左右镜像","同一家族；镜像版本的打点和进球资格须独立验证。",a,
            board(cue:SCNVector3(-0.3,0,0.3),target:SCNVector3(0.4,0,-0.1),pocket:1))
        let target = a.target.vector
        let backward = (target-a.effectiveAim.vector).normalized()
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall:target,pocket:a.effectiveAim.vector,ballRadius:BallPhysics.radius)
        add("母球距离跨档：59.9 → 60.1 cm","跨分类边界也去重，避免分档制造新题。",
            board(cue:target+backward*0.599,target:target,pocket:0),
            board(cue:target+backward*0.601,target:target,pocket:0))
        add("母球挪动不足 3 cm，切角变化 3°","短距离下小位移也可能明显改变瞄准，应保留。",
            board(cue:ghost+backward*0.3,target:target,pocket:0),
            board(cue:ghost+backward.rotatedY(3 * .pi / 180)*0.3,target:target,pocket:0))
        add("切角相同，母球距离明显不同","距离差异影响瞄准要求，不按参考力度区分。",
            board(cue:target+backward*0.4,target:target,pocket:0),
            board(cue:target+backward*0.9,target:target,pocket:0))
        let frozen = board(cue:SCNVector3(0.2,0,0.2),target:SCNVector3(-0.6,0,-0.635+BallPhysics.radius),pocket:0)
        add("贴库 → 离库 1 mm","贴库状态发生变化，保留。两图是合成判据样例，未验证可进性。",
            frozen,board(cue:frozen.cue.vector,target:frozen.target.vector+SCNVector3(0,0,0.001),pocket:0))
        add("切角变化 0.5°","阈值附近的合并样例：普通角度初稿容差 0.75°。",
            board(cue:ghost+backward.rotatedY(20 * .pi / 180)*0.6,target:target,pocket:0),
            board(cue:ghost+backward.rotatedY(20.5 * .pi / 180)*0.6,target:target,pocket:0))
        add("切角变化 1°","阈值外保留；实际阈值仍待看图校准。",
            board(cue:ghost+backward.rotatedY(20 * .pi / 180)*0.6,target:target,pocket:0),
            board(cue:ghost+backward.rotatedY(21 * .pi / 180)*0.6,target:target,pocket:0))
        add("极薄球变化 0.5°","极薄球初稿使用更小的 0.35° 容差，保留。",
            board(cue:ghost+backward.rotatedY(75 * .pi / 180)*0.6,target:target,pocket:0),
            board(cue:ghost+backward.rotatedY(75.5 * .pi / 180)*0.6,target:target,pocket:0))
        let index = TrainingLayoutFamilyIndex()
        let eligible = Set(bank.variants.map(\.boardID))
        var inventory = Dictionary(uniqueKeysWithValues: TrainingInventoryCell.all.map { ($0.id,0) })
        for b in bank.boards where eligible.contains(b.id) {
            if index.duplicate(of:b) == nil {
                index.insert(b)
                let cell = try XCTUnwrap(TrainingInventoryCell.all.first { $0.contains(b) })
                inventory[cell.id,default:0] += 1
            }
        }
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY:0)
        let result = Review(ruleVersion:TrainingLayoutFeatures.version,radius:BallPhysics.radius,
            length:AngleSceneCalculator.innerLength,width:AngleSceneCalculator.innerWidth,
            pockets:geometry.pockets.map { .init($0.center) },
            rails:geometry.linearCushions.prefix(6).map { .init(start:.init($0.start),end:.init($0.end)) },
            pairs:pairs,inventory:inventory)
        let directory = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/accuracy-dedup-review-20261021")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(result).write(to:directory.appendingPathComponent("review.json"),options:.atomic)
        print("DIVERSITY review pairs=\(pairs.count) existingFamilies=\(inventory.values.reduce(0,+)) occupiedCells=\(inventory.values.filter { $0>0 }.count)/270")
    }
}
