import XCTest
import SceneKit
import UIKit
@testable import QiuJi

final class BankLessonTests: XCTestCase {
    func testMirrorConstructionAndGhostTangencyAcrossSlider() {
        for index in 0...500 {
            let target = SIMD2<Float>(-0.85 + Float(index) / 1000, BankLessonModel.target.y)
            let g = BankLessonModel.geometry(target: target)
            XCTAssertEqual(g.mirror.x, target.x)
            XCTAssertEqual(g.mirror.y - BankLessonModel.rail, BankLessonModel.rail - target.y, accuracy: 0.000001)
            XCTAssertEqual(g.bounce.y, BankLessonModel.rail, accuracy: 0.000001)
            let incoming = simd_normalize(g.bounce - target)
            let outgoing = simd_normalize(BankLessonModel.pocket - g.bounce)
            XCTAssertEqual(incoming.x, outgoing.x, accuracy: 0.000001)
            XCTAssertEqual(incoming.y, -outgoing.y, accuracy: 0.000001)
            XCTAssertEqual(simd_length(target - g.ghost), 2 * BallPhysics.radius, accuracy: 0.000001)
            XCTAssertGreaterThan(simd_dot(target - g.ghost, g.bounce - target), 0)
        }
        XCTAssertEqual(BankLessonModel.trial(degrees: 0).missMM, 0, accuracy: 0.001)
        XCTAssertEqual(BankLessonModel.trial(degrees: 4).missMM, 36.6, accuracy: 0.5)
    }

    func testAllPowerStepsUseCompleteCurrentPhysicsAndDistinctPaths() throws {
        var ends = Set<String>()
        for index in 6...40 {
            let shot = try BankLessonModel.simulate(speedIndex: index)
            XCTAssertEqual(shot.cue.first?.point, BankLessonModel.cue)
            XCTAssertEqual(shot.object.first?.point, BankLessonModel.target)
            for track in [shot.cue, shot.object] {
                XCTAssertTrue(track.allSatisfy { $0.time.isFinite && $0.point.x.isFinite && $0.point.y.isFinite })
                XCTAssertTrue(zip(track, track.dropFirst()).allSatisfy { $0.time < $1.time })
            }
            ends.insert(shot.object.map { "\($0.time),\($0.point.x),\($0.point.y)" }.joined(separator: ";"))
            if index == 6 { XCTAssertNil(shot.objectPocket); XCTAssertFalse(shot.isOneBank) }
            if index == 15 {
                XCTAssertTrue(shot.isOneBank)
                XCTAssertEqual(try XCTUnwrap(shot.objectPocketTime), 2.610399246, accuracy: 0.001)
                XCTAssertEqual(shot.position(in: shot.object, at: 0), BankLessonModel.target)
                XCTAssertEqual(shot.position(in: shot.object, at: 100), shot.object.last?.point)
            }
            if index == 16 { XCTAssertNil(shot.objectPocket); XCTAssertGreaterThan(shot.jawContacts, 0) }
            if index == 40 { XCTAssertEqual(shot.mainCushions, 3); XCTAssertFalse(shot.isOneBank) }
        }
        XCTAssertEqual(ends.count, 35)
    }

    @MainActor
    func testLessonAssetsAndPublicRoute() throws {
        for name in ["BankLessonTable", "BankLessonCue", "BankLessonOne", "BankLessonGhost", "BankLessonPocket"] {
            let image = try XCTUnwrap(UIImage(named: name))
            XCTAssertGreaterThan(image.size.width, 200)
            XCTAssertNotEqual(try XCTUnwrap(image.cgImage).alphaInfo, CGImageAlphaInfo.none)
        }
        XCTAssertFalse(AngleRoute.oneCushionBankLesson.requiresPremium)
        XCTAssertTrue(PracticeCoverCatalog.officialRoutes.contains(.oneCushionBankLesson))
        XCTAssertTrue(AngleRoute.bankShot.requiresPremium)
    }
}
