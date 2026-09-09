import XCTest
import SceneKit
@testable import QiuJi

/// Draft, no test execution claimed. Angular contact-ray coverage, not rendered pixel occlusion.
@MainActor
final class HalfOcclusionDiagnosticTests: XCTestCase {
    private struct Stop: Error { let reason: String }
    private struct Interval {
        let lower: Double
        let upper: Double
        var length: Double { upper - lower }
    }
    private func require(_ condition: Bool, _ reason: String) throws {
        if !condition { throw Stop(reason: reason) }
    }

    func testSameTargetFullHalfAndClearAngularCoverageMatchesIndependentIntervals() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { environment[key] ?? environment["TEST_RUNNER_" + key] }
        try require(setting("QD_HALF_OCCLUSION_AUTH") == "NEW_EMPTY_MEMORY_HOST", "Dedicated no-credential memory host required")
        guard let expected = setting("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              setting("SIMULATOR_UDID")?.lowercased() == expected.lowercased() else { throw Stop(reason: "Dedicated device must match runner") }
        let args = ProcessInfo.processInfo.arguments
        try require(args.contains("-v50.inMemoryStore"), "Host must select memory mode before App initialization")
        try require(!args.contains("-v53.authenticatedProfileFixture") && !args.contains("-forcePremium") && !args.contains("-forceNonPremium"), "No identity/premium fixture")
        guard let root = setting("QD_SHOT_DIR"), root.hasPrefix("/"), root != "/" else { throw Stop(reason: "Absolute dedicated evidence root required") }
        let directory = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("half-occlusion-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: directory.path), "New evidence leaf required")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Independent literal contract; fail drift instead of silently adapting the golden input.
        let radius = 0.028575, expanded = 2 * radius
        try require(abs(Double(BallPhysics.radius) - radius) < 1e-8 && abs(Double(AngleSceneCalculator.ballRadius) - radius) < 1e-8, "Frozen 57.15mm diameter contract mismatch")
        let surfaceY = BTTablePhysics.surfaceY
        let centerY = surfaceY + Float(radius)
        let cue = SCNVector3(0, centerY, 0)
        let target = SCNVector3(1, centerY, 0)
        // Tangent triangle: half angle atan2(expanded radius, tangent length).
        // Does not call production asin/coverage/region helpers to derive expectations.
        func interval(x: Double, z: Double) -> Interval {
            let distanceSquared = x*x + z*z
            let tangentLength = sqrt(distanceSquared - expanded*expanded)
            let half = atan2(expanded, tangentLength)
            let direction = atan2(z, x)
            return Interval(lower: direction-half, upper: direction+half)
        }
        let targetInterval = interval(x: 1, z: 0)
        let cases: [(String, Double, Double, Double, Double)] = [
            ("full", 0.5, 0, 1, 3.2870128935063865),
            ("half", sqrt(0.25-expanded*expanded), expanded, 0.5, -3.2762388852634463),
            ("clear", 0.5, 0.2, 0, -18.985668467844892)
        ]
        var evidence: [[String: Any]] = []
        var failures: [String] = []
        for (name, x, z, expectedFraction, goldenMargin) in cases {
            let shadow = interval(x: x, z: z)
            let overlap = max(0, min(targetInterval.upper, shadow.upper) - max(targetInterval.lower, shadow.lower))
            let fraction = overlap / targetInterval.length
            // Signed containment slack is independent of the clipped intersection length.
            let margin = min(targetInterval.lower-shadow.lower, shadow.upper-targetInterval.upper) * 180 / Double.pi
            let blocker = SCNVector3(Float(x), centerY, Float(z))
            let actual = AngleSceneCalculator.snookerCoverage(cue: cue, snookered: target, blocker: blocker)
            let multi = AngleSceneCalculator.snookerCoverageMulti(cue: cue, snookered: target, blockers: [(key: "_2", pos: blocker)])
            let defense = AngleSceneCalculator.defenseCoverage(cueFinal: cue, opponents: [(key: "_9", pos: target)], nonCueBalls: [(key: "_9", pos: target), (key: "_2", pos: blocker)], surfaceY: surfaceY)
            let expectedFull = name == "full"
            func check(_ valid: Bool, _ reason: String) { if !valid { failures.append(name + ": " + reason) } }
            check(hypot(x,z) < 1 && hypot(x,z) > expanded && hypot(1-x,z) > expanded, "Blocker must be nearer, distinct and non-touching")
            check(abs(fraction-expectedFraction) < 1e-12, "Independent clipped angular fraction must match literal golden")
            check(abs(margin-goldenMargin) < 1e-10, "Independent interval margin must match precomputed literal")
            if name == "half" {
                check(overlap > 0 && overlap < targetInterval.length, "Half case must have both blocked and visible angular intervals")
                check(abs(shadow.lower) < 1e-12 && shadow.upper > targetInterval.upper, "Half shadow boundary must split same target at its central ray")
            }
            // 1e-4 degrees tolerates Float conversion/trigonometry, far below class separation.
            check(actual.blockerCloser && actual.isFullSnooker == expectedFull, "Actual full/closer classification mismatch")
            check(abs(Double(actual.marginDegrees)-goldenMargin) < 1e-4, "Actual signed margin mismatch")
            check(abs(Double(actual.visibleHalfAngleDegrees)-3.2762388852634463) < 1e-4, "Same target half-angle must remain unchanged")
            check(multi.blockerCloser && multi.isFullSnooker == expectedFull && abs(Double(multi.marginDegrees)-goldenMargin) < 1e-4, "Actual one-blocker multi path mismatch")
            check(defense.count == 1 && defense.first?.key == "_9", "Defense must preserve target identity")
            if let row = defense.first {
                check(row.blocked == expectedFull && abs(Double(row.coverageMarginDeg)-goldenMargin) < 1e-4, "Defense mapping must preserve angular result")
            }
            evidence.append([
                "case": name, "cueXZ": [0,0], "targetXZ": [1,0], "blockerXZ": [x,z],
                "targetIntervalRad": [targetInterval.lower,targetInterval.upper],
                "blockerIntervalRad": [shadow.lower,shadow.upper],
                "independentBlockedAngularFraction": fraction, "independentMarginDeg": margin,
                "actualMarginDeg": Double(actual.marginDegrees), "actualTargetHalfAngleDeg": Double(actual.visibleHalfAngleDegrees),
                "actualFull": actual.isFullSnooker, "actualCloser": actual.blockerCloser,
                "multiMarginDeg": Double(multi.marginDegrees), "defenseCount": defense.count,
                "defense": defense.map { ["key": $0.key, "blocked": $0.blocked, "marginDeg": Double($0.coverageMarginDeg)] as [String: Any] }
            ])
        }
        // All three independent rows are always retained before an assertion failure is raised.
        let payload: [String: Any] = ["device": expected, "radiusMeters": radius, "coordinateContract": "SceneKit XZ horizontal; Y up; metres; bearing atan2(z,x)", "rows": evidence, "failures": failures, "productionHasFractionField": false]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("three-interval-comparison.json"), options: .withoutOverwriting)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "half-occlusion-three-interval-comparison"; attachment.lifetime = .keepAlways; add(attachment)
        print("[QD-HalfOcclusion] evidence=\(directory.path); rows=3 failures=\(failures.count)")
        try require(failures.isEmpty, failures.joined(separator: "; "))
    }
}
