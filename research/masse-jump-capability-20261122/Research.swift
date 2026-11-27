/// CB-01 research-only XCTest. It is appended to an isolated PhysicsEngineTests
/// snapshot and never enters the production target.
final class CB01CapabilityResearchTests: XCTestCase {
    private let output = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/masse-jump-capability-20261122")
    private let surfaceY = BTTablePhysics.surfaceY
    private let radius = BallPhysics.radius

    private var requestFileName: String {
        ProcessInfo.processInfo.environment["CB01_REQUEST_FILE"] ?? "request.json"
    }

    private var resultFileName: String {
        ProcessInfo.processInfo.environment["CB01_RESULT_FILE"] ?? "e1-results.json"
    }

    private func read(_ name: String) throws -> [String: Any] {
        let bundled = Bundle(for: Self.self).resourceURL!.appendingPathComponent(name)
        let url = FileManager.default.fileExists(atPath: bundled.path) ? bundled : output.appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func jsonSafe(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return dict.mapValues { jsonSafe($0) }
        }
        if let array = value as? [Any] {
            return array.map { jsonSafe($0) }
        }
        if let number = value as? NSNumber {
            let doubleValue = number.doubleValue
            return doubleValue.isFinite ? value : NSNull()
        }
        if let doubleValue = value as? Double {
            return doubleValue.isFinite ? value : NSNull()
        }
        if let floatValue = value as? Float {
            return floatValue.isFinite ? value : NSNull()
        }
        return value
    }

    private func write(_ name: String, _ value: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: jsonSafe(value), options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent(name), options: .atomic)
    }

    private func point(_ value: [String: Any]) -> SCNVector3 {
        SCNVector3(Float(value["x"] as! Double), 0, Float(value["z"] as! Double))
    }

    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Double {
        hypot(Double(a.x - b.x), Double(a.z - b.z))
    }

    private func unit(_ value: SCNVector3) -> SCNVector3 {
        let length = hypotf(value.x, value.z)
        return SCNVector3(value.x / length, 0, value.z / length)
    }

    private func crossDistance(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Double {
        let segment = SCNVector3(b.x - a.x, 0, b.z - a.z)
        let length2 = segment.x * segment.x + segment.z * segment.z
        let t = max(0, min(1, ((p.x - a.x) * segment.x + (p.z - a.z) * segment.z) / length2))
        let q = SCNVector3(a.x + t * segment.x, 0, a.z + t * segment.z)
        return Double(distance(p, q))
    }

    private func frames(_ prediction: ShotPrediction, _ name: String) -> [BallFrame] {
        prediction.recorder?.framesByBallName[name] ?? []
    }

    private func pathLength(_ values: [BallFrame]) -> Double {
        zip(values, values.dropFirst()).reduce(0) { partial, pair in
            partial + distance(pair.0.position, pair.1.position)
        }
    }

    private func maxHeight(_ values: [BallFrame]) -> Double {
        values.map { Double($0.position.y - surfaceY - radius) }.max() ?? 0
    }

    private func maxVerticalSpeed(_ values: [BallFrame]) -> Double {
        values.map { abs(Double($0.velocity.y)) }.max() ?? 0
    }

    private func firstLanding(_ values: [BallFrame]) -> (time: Double, position: SCNVector3)? {
        let bedY = surfaceY + radius
        for pair in zip(values, values.dropFirst()) {
            let previous = pair.0.position.y - bedY
            let current = pair.1.position.y - bedY
            if previous > 0.0005 && current <= 0.0005 {
                return (Double(pair.1.time), pair.1.position)
            }
        }
        return nil
    }

    private func event(_ prediction: ShotPrediction, _ matches: (ShotEvent.Kind) -> Bool) -> ShotEvent? {
        prediction.events.first { matches($0.kind) }
    }

    private func objectPotted(_ prediction: ShotPrediction, pocket: Int) -> Bool {
        prediction.events.contains { item in
            guard case let .pocket(ball, pocketID) = item.kind else { return false }
            return ball == ShotInput.targetBallName && pocketID == "pocket_\(pocket)"
        }
    }

    private func row(for job: [String: Any]) -> [String: Any] {
        let cue = point(job["cue"] as! [String: Any])
        let target = point(job["target"] as! [String: Any])
        let ghost = point(job["ghost"] as! [String: Any])
        let obstacle = point(job["obstacle"] as! [String: Any])
        let obstacleEnabled = (job["obstacleEnabled"] as? Bool) ?? true
        let aim = unit(SCNVector3(ghost.x - cue.x, 0, ghost.z - cue.z))
        let speed = Float(job["speedMPS"] as! Double)
        let spinX = Float(job["spinX"] as! Double)
        let spinY = Float(job["spinY"] as! Double)
        let elevation = Float(job["elevationDegrees"] as! Double) * .pi / 180
        var balls = [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        if obstacleEnabled {
            balls.append(ObstacleBall(name: "obstacle", position: obstacle))
        }
        var initialSpatialPositions: [String: SCNVector3] = [
            ShotInput.cueBallName: SCNVector3(cue.x, surfaceY + radius, cue.z),
            ShotInput.targetBallName: SCNVector3(target.x, surfaceY + radius, target.z),
        ]
        if obstacleEnabled {
            initialSpatialPositions["obstacle"] = SCNVector3(obstacle.x, surfaceY + radius, obstacle.z)
        }
        var result: [String: Any] = job
        let actualPoint = CueBallStrike.contactCoordinates(spinX: spinX, spinY: spinY, elevation: elevation)
        result["actualContactPoint"] = ["sideOverR": actualPoint.side, "backOverR": actualPoint.back, "upOverR": actualPoint.up]
        let expectedHemisphere = (job["technique"] as! String) == "jump" ? actualPoint.up > 0 : actualPoint.up < 0
        result["contactHemispherePass"] = expectedHemisphere
        guard expectedHemisphere else {
            result["baseSafe"] = false
            result["basePotted"] = false
            result["failure"] = "contactHemisphere"
            return result
        }
        let prediction = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: aim, velocity: speed, spinX: spinX, spinY: spinY,
            surfaceY: surfaceY, balls: balls, maxEvents: 3000, maxTime: 40,
            includePresentation: false, simulationModel: .spatialPractice,
            elevation: elevation, initialSpatialPositions: initialSpatialPositions, buildPolylines: false)
        let cueFrames = frames(prediction, ShotInput.cueBallName)
        let targetFrames = frames(prediction, ShotInput.targetBallName)
        let cueContact = event(prediction) { kind in
            guard case let .ballBall(a, b) = kind else { return false }
            return a == ShotInput.cueBallName && (b == ShotInput.targetBallName || b == "obstacle")
                || b == ShotInput.cueBallName && (a == ShotInput.targetBallName || a == "obstacle")
        }
        let obstacleContact = obstacleEnabled && (event(prediction) { kind in
            guard case let .ballBall(a, b) = kind else { return false }
            return Set([a, b]) == Set([ShotInput.cueBallName, "obstacle"])
        } != nil)
        let cueEscaped = prediction.pocketedBalls.contains(ShotInput.cueBallName)
            || prediction.finalPositions[ShotInput.cueBallName].map {
                !SpatialPracticeGeometry.contains(SIMD3(Double($0.x), Double($0.y), Double($0.z)))
            } ?? false
        let targetEscaped = prediction.pocketedBalls.contains(ShotInput.targetBallName)
            && !objectPotted(prediction, pocket: job["pocket"] as! Int)
            || prediction.finalPositions[ShotInput.targetBallName].map {
                !SpatialPracticeGeometry.contains(SIMD3(Double($0.x), Double($0.y), Double($0.z)))
            } ?? false
        let landing = firstLanding(cueFrames)
        let cuePath = cueFrames.map(\.position)
        let lateral = cuePath.map { crossDistance($0, cue, target) }.max() ?? 0
        let actualGap = obstacleEnabled ? (cuePath.map { distance($0, obstacle) - Double(2 * radius) }.min() ?? 0) : 999.0
        let targetContact = event(prediction) { kind in
            guard case let .ballBall(a, b) = kind else { return false }
            return Set([a, b]) == Set([ShotInput.cueBallName, ShotInput.targetBallName])
        }
        let targetContactTime = targetContact.map { Double($0.time) }
        let targetBeforeLanding = targetContactTime.flatMap { contactTime in
            landing.map { contactTime < $0.time }
        } ?? false
        let intendedJump = (job["technique"] as! String) == "jump"
        let intendedMasse = !intendedJump
        let cueOnCloth = maxHeight(cueFrames) <= 0.001
        let firstContactIsTarget = cueContact.map {
            if case let .ballBall(a, b) = $0.kind { return Set([a, b]) == Set([ShotInput.cueBallName, ShotInput.targetBallName]) }
            return false
        } ?? false
        let baseSafe = prediction.hasFinalTableState && !cueEscaped && !targetEscaped
            && !obstacleContact && prediction.cuePocketed == false
            && (!intendedMasse || cueOnCloth)
            && (!intendedJump || (landing != nil && !targetBeforeLanding))
        let basePotted = baseSafe && objectPotted(prediction, pocket: job["pocket"] as! Int)
        result["termination"] = String(describing: prediction.termination)
        result["settled"] = prediction.hasFinalTableState
        result["cueEscaped"] = cueEscaped
        result["targetEscaped"] = targetEscaped
        result["obstacleContact"] = obstacleContact
        result["obstacleEnabled"] = obstacleEnabled
        result["targetContact"] = targetContact != nil
        result["targetContactTime"] = targetContactTime.map { $0 } ?? NSNull()
        result["firstContactIsTarget"] = firstContactIsTarget
        result["cueMaximumHeightMetres"] = maxHeight(cueFrames)
        result["cueMaximumVerticalSpeedMPS"] = maxVerticalSpeed(cueFrames)
        result["targetMaximumHeightMetres"] = maxHeight(targetFrames)
        result["targetMaximumVerticalSpeedMPS"] = maxVerticalSpeed(targetFrames)
        result["cuePathLengthMetres"] = pathLength(cueFrames)
        result["targetPathLengthMetres"] = pathLength(targetFrames)
        result["cueMaximumLateralOffsetMetres"] = lateral
        result["minimumObstacleClearanceMetres"] = actualGap
        result["landingTime"] = landing.map { $0.time } ?? NSNull()
        result["landingPosition"] = landing.map { ["x": $0.position.x, "z": $0.position.z] } ?? NSNull()
        result["targetBeforeLanding"] = targetBeforeLanding
        result["cueStayedOnCloth"] = cueOnCloth
        result["objectPotted"] = objectPotted(prediction, pocket: job["pocket"] as! Int)
        result["baseSafe"] = baseSafe
        result["basePotted"] = basePotted
        result["failure"] = basePotted ? NSNull() : (cueEscaped ? "cueEscaped" : targetEscaped ? "targetEscaped" : obstacleContact ? "obstacleContact" : prediction.hasFinalTableState ? "notPotted" : "incomplete")
        result["techniqueShapePass"] = intendedJump ? (landing != nil && !targetBeforeLanding) : (intendedMasse && cueOnCloth)
        // This stricter contract only applies to the new bank-candidate search;
        // previous E0/E1/E2 metrics retain their original meaning.
        if job["sampleIndex"] != nil {
            let blocked = obstacleEnabled && crossDistance(obstacle, cue, ghost) < Double(2 * radius) - 0.001
            let cueFinalOnBed = cueFrames.last.map { SpatialPracticeGeometry.isOnBed($0.position) } ?? false
            // The spatial domain includes the floor and room. Never confuse it
            // with the playing surface. Reject even a fly-out that returns.
            let cueLeftTable = cueFrames.contains {
                abs($0.position.x) > TablePhysics.innerLength / 2 + radius ||
                abs($0.position.z) > TablePhysics.innerWidth / 2 + radius ||
                $0.position.y < surfaceY + radius - 0.001
            }
            let strictSafe = baseSafe && firstContactIsTarget && blocked && cueFinalOnBed && !cueLeftTable
            result["directPotLineBlocked"] = blocked
            result["cueFinalOnBed"] = cueFinalOnBed
            result["cueLeftTable"] = cueLeftTable
            result["baseSafe"] = strictSafe
            result["basePotted"] = strictSafe && objectPotted(prediction, pocket: job["pocket"] as! Int)
            if !blocked { result["failure"] = "directPotLineNotBlocked" }
            else if cueLeftTable || !cueFinalOnBed { result["failure"] = "cueOffTable" }
            else if !firstContactIsTarget { result["failure"] = "noTargetFirstContact" }
        }
        return result
    }

    func testCB01OneSolutionSearch() throws {
        let request = try read(requestFileName)
        let jobs = try XCTUnwrap(request["jobs"] as? [[String: Any]])
        let groups = Dictionary(grouping: jobs) { $0["sampleIndex"] as! Int }
        var solved = 0
        for index in groups.keys.sorted() {
            let candidates = groups[index]!
            var attempts: [[String: Any]] = []
            for job in candidates {
                let result = autoreleasepool { row(for: job) }
                attempts.append(result)
                if result["basePotted"] as? Bool == true { solved += 1; break }
            }
            let payload: [String: Any] = [
                "schema": "cb01-one-solution-result-v2", "sampleIndex": index,
                "sourceBankSHA256": request["sourceBankSHA256"]!,
                "requestSHA256": request["requestIdentity"]!,
                "geometryVersion": SpatialPracticeGeometry.version,
                "candidateCount": candidates.count, "rows": attempts,
                "status": attempts.last?["basePotted"] as? Bool == true ? "solved" : "exhausted",
            ]
            let data = try JSONSerialization.data(withJSONObject: jsonSafe(payload), options: [.sortedKeys])
            print("CB01_ONE " + String(decoding: data, as: UTF8.self))
            fflush(stdout)
        }
        print("CB01_ONE_COMPLETE shapes=\(groups.count) solved=\(solved)")
        XCTAssertFalse(groups.isEmpty)
    }

    func testCB01CapabilitySweep() throws {
        let request = try read(requestFileName)
        let jobs = try XCTUnwrap(request["jobs"] as? [[String: Any]])
        let environment = ProcessInfo.processInfo.environment
        let start = max(0, Int(environment["CB01_START"] ?? "0") ?? 0)
        let requestedEnd = Int(environment["CB01_END"] ?? "\(jobs.count)") ?? jobs.count
        let end = min(jobs.count, max(start, requestedEnd))
        let selectedJobs = Array(jobs[start..<end])
        var rows: [[String: Any]] = []
        rows.reserveCapacity(selectedJobs.count)
        for (index, job) in selectedJobs.enumerated() {
            rows.append(row(for: job))
            if index % 250 == 0 { print("CB01 E1 \(start + index)/\(jobs.count)") }
        }
        try write(resultFileName, [
            "schema": "cb01-e1-results-v1",
            "rows": rows,
            "count": rows.count,
            "start": start,
            "end": end,
            "sourceBankSHA256": request["sourceBankSHA256"] as Any,
            "solver": "ShotPredictor.simulateFree:spatialPractice",
            "geometryVersion": SpatialPracticeGeometry.version,
        ])
        XCTAssertEqual(rows.count, selectedJobs.count)
        XCTAssertGreaterThan(rows.count, 0)
        print("CB01 E1 complete rows=\(rows.count)")
    }
}
