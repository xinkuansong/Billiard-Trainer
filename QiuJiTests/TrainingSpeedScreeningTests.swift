import XCTest
import SceneKit
import CryptoKit
@testable import QiuJi

/// Opt-in experiment: fixed C->G strike direction, each fixed tip independent,
/// speed only. Existence screening is NOT a nine-point accuracy qualification.
final class TrainingSpeedScreeningTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private struct Request: Codable {
        let sourceFingerprint: String
        let gallerySHA256: String
        let inventorySHA256: String
    }
    private struct Point: Codable {
        let x: Double; let z: Double
        var vector: SCNVector3 { SCNVector3(Float(x), 0, Float(z)) }
    }
    private struct Sample: Codable {
        let cellID: String; let pocket: Int; let signedAngle: Int
        let cue: Point; let target: Point; let ghost: Point
        let aim: Point
    }
    private struct Gallery: Codable {
        let sourceFingerprint: String
        let samples: [Sample]
    }
    private struct Trial: Codable {
        let speed: Float
        let seconds: Double
        let settled: Bool
        let targetPotted: Bool
        let accuracyOutcome: String
    }
    private struct Proof: Codable {
        let speed: Float; let direction: TrainingBankPoint
        let spinX: Float; let spinY: Float
        let settled: Bool; let accuracyOutcome: String
        let events: [TrainingProofEvent]
    }
    private struct Job {
        let sampleIndex: Int; let sample: Sample; let tip: TrainingFixedTip
        let direction: SCNVector3; let accessible: Bool
    }
    private struct Result: Codable {
        let sampleIndex: Int; let cellID: String; let pocket: Int; let tip: TrainingFixedTip
        let accessible: Bool; let elapsedSeconds: Double
        let trials: [Trial]; let proof: Proof?
    }
    private struct Phase: Codable {
        let method: String; let wallSeconds: Double; let results: [Result]
    }

    private struct CenterTrial: Codable {
        let speed: Float; let seconds: Double; let settled: Bool
        let targetPotted: Bool; let cuePocketed: Bool
        let feedback: String; let minimumAnchorDistance: Float
        let maximumForwardTravel: Float; let targetCushions: Int
        var routeAccepted: Bool? = nil
        var routeReason: String? = nil
    }
    private struct CenterResult: Codable {
        let sampleIndex: Int; let cellID: String; let pocket: Int
        let elapsedSeconds: Double
        let trials: [CenterTrial]; let proof: Proof?
    }

    private func simulateCenter(_ sample: Sample, _ speed: Float) -> ShotPrediction {
        let direction = (sample.ghost.vector-sample.cue.vector).normalized()
        return ShotPredictor.simulateFree(cueBall:sample.cue.vector,aimDir:direction,velocity:speed,
            spinX:0,spinY:0,surfaceY:0,
            balls:[.init(name:ShotInput.targetBallName,position:sample.target.vector)],
            recordedStrikeDirection:direction)
    }

    private func runCenter(_ index: Int, _ sample: Sample, directOnly: Bool = false) -> CenterResult {
        let low = Float(ShotTuning.velocityRange.lowerBound)
        let high = Float(ShotTuning.velocityRange.upperBound)
        let started = ProcessInfo.processInfo.systemUptime
        var a = low, b = high
        var trials: [CenterTrial] = []
        var proof: Proof?
        let target = sample.target.vector, anchor = sample.aim.vector
        let forward = (anchor-target).normalized()
        let requiredTravel = (anchor-target).length()
        for _ in 0..<5 {
            let speed = (a+b)/2
            let callStart = ProcessInfo.processInfo.systemUptime
            let p = simulateCenter(sample,speed)
            let seconds = ProcessInfo.processInfo.systemUptime-callStart
            // An observed target pocket event is irreversible. Cue rest/scratch
            // is deliberately irrelevant to this initial existence screen.
            let entered = p.events.contains {
                if case let .pocket(ball,id) = $0.kind {
                    return ball == ShotInput.targetBallName && id == "pocket_\(sample.pocket)"
                }
                return false
            }
            let targetCushions = p.events.filter {
                if case let .ballCushion(ball) = $0.kind { return ball == ShotInput.targetBallName }
                return false
            }.count
            // simulateFree exposes the target under extraBallPaths, not objectPath.
            // Sampled segments are only search feedback; actual pocket events
            // remain the sole pass criterion.
            let path = p.extraBallPaths[ShotInput.targetBallName] ?? [target]
            var minimumDistance = Float.greatestFiniteMagnitude
            var maximumForward: Float = 0
            // Ignore Y: recorded centers are R above the cloth.
            for k in path.indices {
                let point = SCNVector3(path[k].x,0,path[k].z)
                maximumForward = max(maximumForward,(point-target).dot(forward))
                minimumDistance = min(minimumDistance,(point-anchor).length())
                if k > 0 {
                    let previous = SCNVector3(path[k-1].x,0,path[k-1].z)
                    let delta = point-previous, squared = delta.dot(delta)
                    if squared > 0 {
                        let t = max(0,min(1,(anchor-previous).dot(delta)/squared))
                        minimumDistance = min(minimumDistance,(previous+delta*t-anchor).length())
                    }
                }
            }
            let routeReason = directOnly ? directRoute(p, pocket: sample.pocket) : nil
            let accepted = entered && (!directOnly || routeReason == "direct-pot")
            let feedback: String
            if accepted {
                feedback = "pot"
                proof = .init(speed:speed,direction:.init((sample.ghost.vector-sample.cue.vector).normalized()),
                    spinX:0,spinY:0,settled:p.hasFinalTableState,
                    accuracyOutcome:AccuracyShotJudgement.evaluate(p,pocketIndex:sample.pocket).rawValue,
                    events:p.events.map(TrainingProofEvent.init))
                if directOnly {
                    struct ReviewPath: Codable {
                        let cue: [TrainingBankPoint]; let target: [TrainingBankPoint]
                        let route: String; let speed: Float; let cuePocketed: Bool
                    }
                    let review = ReviewPath(cue:p.cuePath.map(TrainingBankPoint.init),
                        target:(p.extraBallPaths[ShotInput.targetBallName] ?? []).map(TrainingBankPoint.init),
                        route:routeReason!,speed:speed,cuePocketed:p.cuePocketed)
                    do {
                        try JSONEncoder().encode(review).write(to:root.appendingPathComponent("output/accuracy-middle-direct-v4-20261021/review-paths/\(index).json"),options:.atomic)
                    } catch { XCTFail("Review path write failed: \(error)") }
                }
            } else if !p.hasFinalTableState {
                feedback = "incomplete-stop"
            } else if entered && directOnly {
                feedback = "indirect-probe-lower"
                b = speed
            } else if minimumDistance <= 2*BallPhysics.radius {
                // One ball diameter around P is the explicit experimental
                // mouth-neighborhood threshold, not a capture boundary.
                feedback = "mouth-miss-decrease"
                b = speed
            } else if targetCushions > 0 || maximumForward >= requiredTravel {
                // Deflection is ambiguous: probe lower, without claiming that
                // excessive speed was proved to be the cause.
                feedback = "deflection-probe-lower"
                b = speed
            } else {
                feedback = "short-increase"
                a = speed
            }
            trials.append(.init(speed:speed,seconds:seconds,settled:p.hasFinalTableState,
                targetPotted:entered,cuePocketed:p.cuePocketed,feedback:feedback,
                minimumAnchorDistance:minimumDistance,maximumForwardTravel:maximumForward,
                targetCushions:targetCushions,routeAccepted:directOnly ? accepted : nil,routeReason:routeReason))
            if accepted || !p.hasFinalTableState { break }
        }
        return .init(sampleIndex:index,cellID:sample.cellID,pocket:sample.pocket,
            elapsedSeconds:ProcessInfo.processInfo.systemUptime-started,trials:trials,proof:proof)
    }

    /// Route qualification is independent of cue scratch. Stop at the first target pot.
    /// Main-rail compression is permitted only while a ball initially frozen there
    /// has not departed; own-pocket jaws/throat contacts are ordinary pocket entry.
    private func directRoute(_ p: ShotPrediction, pocket: Int) -> String {
        guard p.hasFinalTableState else { return "incomplete" }
        var contacts = 0
        for event in p.events {
            switch event.kind {
            case let .ballBall(a,b):
                guard Set([a,b]) == Set([ShotInput.cueBallName,ShotInput.targetBallName]) else { return "other-ball" }
                contacts += 1
                if contacts > 1 { return "second-contact" }
            case let .ballCushion(ball):
                if ball == ShotInput.cueBallName && contacts == 0 { return "cue-bank" }
                if ball == ShotInput.targetBallName {
                    guard contacts == 1, let index = event.cushionIndex else { return "unknown-contact" }
                    if (0..<6).contains(index) {
                        guard initialFrozenCompression(p,event:event,index:index) else { return "target-bank" }
                    } else if AccuracyShotJudgement.mouthOwner(cushionIndex:index) != pocket {
                        return "other-pocket-mouth"
                    }
                }
            case let .pocket(ball,id):
                if ball == ShotInput.targetBallName {
                    return id == "pocket_\(pocket)" && contacts == 1 ? "direct-pot" : "wrong-pocket-or-contact"
                }
            }
        }
        return "missed"
    }

    private func initialFrozenCompression(_ p: ShotPrediction, event: ShotEvent, index: Int) -> Bool {
        guard let frames = p.recorder?.framesByBallName[ShotInput.targetBallName],
              let first = frames.first, first.time <= 0.00001 else { return false }
        let rail = TableGeometry.chineseEightBallQiuJi(surfaceY:0).linearCushions[index]
        let delta = rail.end-rail.start
        let length2 = delta.x*delta.x+delta.z*delta.z
        let u = ((first.position.x-rail.start.x)*delta.x+(first.position.z-rail.start.z)*delta.z)/length2
        guard (0...1).contains(u),
              abs((first.position-rail.start).dot(rail.normal)-BallPhysics.radius) <= SceneTrainingRailGeometry.contactRoundoff else { return false }
        return frames.filter { $0.time <= event.time }.allSatisfy {
            ($0.position-rail.start).dot(rail.normal)-BallPhysics.radius <= 0.0001
        }
    }

    /// Initial layout screen only. Scratch and other tip variants have no gate here.
    /// Feedback is a bounded search heuristic, not a monotonicity/no-solution proof.
    @MainActor func testCenterFiveAttemptScreening() throws {
        let output = root.appendingPathComponent("output/accuracy-center-five-20261021")
        let requestURL = output.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else {
            throw XCTSkip("Explicit center-only screening request required")
        }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        try FileManager.default.removeItem(at: requestURL)
        let inputs = root.appendingPathComponent("output/accuracy-grid-anchor-v2-20261021")
        let galleryData = try Data(contentsOf: inputs.appendingPathComponent("render-samples.json"))
        let inventoryData = try Data(contentsOf: inputs.appendingPathComponent("inventory.json"))
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        XCTAssertEqual(digest(galleryData),request.gallerySHA256)
        XCTAssertEqual(digest(inventoryData),request.inventorySHA256)
        guard digest(galleryData) == request.gallerySHA256,
              digest(inventoryData) == request.inventorySHA256 else { return }
        let gallery = try JSONDecoder().decode(Gallery.self,from:galleryData)
        XCTAssertEqual(gallery.samples.count,30)
        let low = Float(ShotTuning.velocityRange.lowerBound)
        let high = Float(ShotTuning.velocityRange.upperBound)
        _ = simulateCenter(try XCTUnwrap(gallery.samples.first),2)
        let start = ProcessInfo.processInfo.systemUptime
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 4
        let lock = NSLock()
        var results: [Int:CenterResult] = [:]
        for (index,sample) in gallery.samples.enumerated() {
            queue.addOperation {
                let result = self.runCenter(index,sample)
                lock.lock(); results[index] = result; lock.unlock()
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        let wall = ProcessInfo.processInfo.systemUptime-start
        let ordered = gallery.samples.indices.map { results[$0]! }
        struct Report: Codable {
            let sourceFingerprint: String; let gallerySHA256: String; let inventorySHA256: String
            let workers: Int; let wallSeconds: Double; let results: [CenterResult]
            let policy: String
        }
        let report = Report(sourceFingerprint:request.sourceFingerprint,gallerySHA256:request.gallerySHA256,
            inventorySHA256:request.inventorySHA256,workers:4,wallSeconds:wall,results:ordered,
            policy:"center only; fixed C->G; at most 5 midpoint trials in 0.5...8 m/s; specified target pocket event passes; cue scratch ignored; incomplete misses remain unknown")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(report).write(to:output.appendingPathComponent("results.json"),options:.atomic)
        XCTAssertEqual(ordered.count,30)
        for result in ordered {
            XCTAssertTrue((1...5).contains(result.trials.count))
            XCTAssertTrue(result.trials.allSatisfy { $0.speed >= low && $0.speed <= high })
            XCTAssertEqual(result.proof != nil,result.trials.contains { $0.targetPotted })
            if let proof = result.proof {
                XCTAssertEqual(proof.spinX,0); XCTAssertEqual(proof.spinY,0)
                XCTAssertTrue(result.trials.last!.targetPotted)
            }
        }
        print("CENTER_FIVE layouts=\(ordered.count) passed=\(ordered.filter{$0.proof != nil}.count) calls=\(ordered.reduce(0){$0+$1.trials.count}) wall=\(wall)")
    }

    /// Full v3 middle-pocket inventory; bounded batches keep memory and evidence manageable.
    @MainActor func testV3MiddleFullScreening() throws {
        let output = root.appendingPathComponent("output/accuracy-middle-v3-20261021")
        struct Batch: Codable { let file: String; let sha256: String; let count: Int; let offset: Int }
        struct FullRequest: Codable {
            let sourceFingerprint: String; let inventorySHA256: String
            let workers: Int; let total: Int; let batches: [Batch]
        }
        struct Checkpoint: Codable {
            let sourceFingerprint: String; let inventorySHA256: String
            let workers: Int; let total: Int; let done: Int; let passed: Int; let calls: Int
            let wallSeconds: Double; let complete: Bool
        }
        let requestURL = output.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath:requestURL.path) else {
            throw XCTSkip("Explicit v3 full middle screening request required")
        }
        let request = try JSONDecoder().decode(FullRequest.self,from:Data(contentsOf:requestURL))
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let inventory = try Data(contentsOf:root.appendingPathComponent("output/accuracy-grid-staggered-v3-20261021/inventory.json"))
        guard digest(inventory) == request.inventorySHA256, request.workers == 18,
              request.total == 272710, request.batches.reduce(0, { $0+$1.count }) == request.total else {
            throw TrainingQuestionBank.Failure.invalid("Full middle input contract changed")
        }
        try FileManager.default.moveItem(at:requestURL,to:output.appendingPathComponent("consumed-request.json"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let start = ProcessInfo.processInfo.systemUptime
        var done = 0, passed = 0, calls = 0
        for (batchIndex,batch) in request.batches.enumerated() {
            try autoreleasepool {
                let input = try Data(contentsOf:output.appendingPathComponent(batch.file))
                guard digest(input) == batch.sha256, batch.offset == done else {
                    throw TrainingQuestionBank.Failure.invalid("Batch input changed: \(batch.file)")
                }
                let gallery = try JSONDecoder().decode(Gallery.self,from:input)
                guard gallery.samples.count == batch.count,
                      gallery.samples.allSatisfy({ $0.pocket == 4 || $0.pocket == 5 }) else {
                    throw TrainingQuestionBank.Failure.invalid("Middle batch count or pocket mismatch")
                }
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = request.workers
                let lock = NSLock()
                var results: [Int:CenterResult] = [:]
                for (local,sample) in gallery.samples.enumerated() {
                    let index = batch.offset+local
                    queue.addOperation {
                        let result = autoreleasepool { self.runCenter(index,sample) }
                        lock.lock(); results[index] = result; lock.unlock()
                    }
                }
                queue.waitUntilAllOperationsAreFinished()
                let ordered = (batch.offset..<(batch.offset+batch.count)).map { results[$0]! }
                for result in ordered {
                    XCTAssertTrue((1...5).contains(result.trials.count))
                    XCTAssertEqual(result.proof != nil,result.trials.contains { $0.targetPotted })
                    if let proof = result.proof {
                        XCTAssertEqual(proof.spinX,0); XCTAssertEqual(proof.spinY,0)
                        XCTAssertTrue(result.trials.last!.targetPotted)
                    }
                }
                try encoder.encode(ordered).write(to:output.appendingPathComponent(String(format:"results-%03d.json",batchIndex)),options:.atomic)
                done += ordered.count
                passed += ordered.filter { $0.proof != nil }.count
                calls += ordered.reduce(0) { $0+$1.trials.count }
            }
            let checkpoint = Checkpoint(sourceFingerprint:request.sourceFingerprint,
                inventorySHA256:request.inventorySHA256,workers:request.workers,total:request.total,
                done:done,passed:passed,calls:calls,
                wallSeconds:ProcessInfo.processInfo.systemUptime-start,complete:done == request.total)
            try encoder.encode(checkpoint).write(to:output.appendingPathComponent("progress.json"),options:.atomic)
            print("MIDDLE_V3 done=\(done)/\(request.total) passed=\(passed) calls=\(calls) wall=\(checkpoint.wallSeconds)")
        }
        XCTAssertEqual(done,request.total)
    }

    /// Full v3 middle-pocket inventory; bounded batches keep memory and evidence manageable.
    @MainActor func testV3MiddleDirectCorrection() throws {
        let output = root.appendingPathComponent("output/accuracy-middle-direct-v4-20261021")
        struct Batch: Codable { let file: String; let sha256: String; let count: Int; let offset: Int }
        struct FullRequest: Codable {
            let sourceFingerprint: String; let inventorySHA256: String
            let workers: Int; let total: Int; let batches: [Batch]
        }
        struct Checkpoint: Codable {
            let sourceFingerprint: String; let inventorySHA256: String
            let workers: Int; let total: Int; let done: Int; let passed: Int; let calls: Int
            let wallSeconds: Double; let complete: Bool
        }
        let requestURL = output.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath:requestURL.path) else {
            throw XCTSkip("Explicit v3 full middle screening request required")
        }
        let request = try JSONDecoder().decode(FullRequest.self,from:Data(contentsOf:requestURL))
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let inventory = try Data(contentsOf:root.appendingPathComponent("output/accuracy-grid-staggered-v3-20261021/inventory.json"))
        guard digest(inventory) == request.inventorySHA256, request.workers == 18,
              request.total > 0, request.batches.reduce(0, { $0+$1.count }) == request.total else {
            throw TrainingQuestionBank.Failure.invalid("Full middle input contract changed")
        }
        try FileManager.default.moveItem(at:requestURL,to:output.appendingPathComponent("consumed-request.json"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let start = ProcessInfo.processInfo.systemUptime
        var done = 0, passed = 0, calls = 0
        for (batchIndex,batch) in request.batches.enumerated() {
            try autoreleasepool {
                let input = try Data(contentsOf:output.appendingPathComponent(batch.file))
                guard digest(input) == batch.sha256, batch.offset == done else {
                    throw TrainingQuestionBank.Failure.invalid("Batch input changed: \(batch.file)")
                }
                let gallery = try JSONDecoder().decode(Gallery.self,from:input)
                guard gallery.samples.count == batch.count,
                      gallery.samples.allSatisfy({ $0.pocket == 4 || $0.pocket == 5 }) else {
                    throw TrainingQuestionBank.Failure.invalid("Middle batch count or pocket mismatch")
                }
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = request.workers
                let lock = NSLock()
                var results: [Int:CenterResult] = [:]
                for (local,sample) in gallery.samples.enumerated() {
                    let index = batch.offset+local
                    queue.addOperation {
                        let result = autoreleasepool { self.runCenter(index,sample,directOnly:true) }
                        lock.lock(); results[index] = result; lock.unlock()
                    }
                }
                queue.waitUntilAllOperationsAreFinished()
                let ordered = (batch.offset..<(batch.offset+batch.count)).map { results[$0]! }
                for result in ordered {
                    XCTAssertTrue((1...5).contains(result.trials.count))
                    XCTAssertEqual(result.proof != nil,result.trials.contains { $0.routeAccepted == true })
                    if let proof = result.proof {
                        XCTAssertEqual(proof.spinX,0); XCTAssertEqual(proof.spinY,0)
                        XCTAssertTrue(result.trials.last!.routeAccepted == true)
                    }
                }
                try encoder.encode(ordered).write(to:output.appendingPathComponent(String(format:"results-%03d.json",batchIndex)),options:.atomic)
                done += ordered.count
                passed += ordered.filter { $0.proof != nil }.count
                calls += ordered.reduce(0) { $0+$1.trials.count }
            }
            let checkpoint = Checkpoint(sourceFingerprint:request.sourceFingerprint,
                inventorySHA256:request.inventorySHA256,workers:request.workers,total:request.total,
                done:done,passed:passed,calls:calls,
                wallSeconds:ProcessInfo.processInfo.systemUptime-start,complete:done == request.total)
            try encoder.encode(checkpoint).write(to:output.appendingPathComponent("progress.json"),options:.atomic)
            print("MIDDLE_V3 done=\(done)/\(request.total) passed=\(passed) calls=\(calls) wall=\(checkpoint.wallSeconds)")
        }
        XCTAssertEqual(done,request.total)
        let regression = try JSONDecoder().decode(Gallery.self,from:Data(contentsOf:output.appendingPathComponent("regression-inputs.json")))
        XCTAssertEqual(regression.samples.count,2)
        for sample in regression.samples {
            let p = simulateCenter(sample,4.25)
            XCTAssertNotEqual(directRoute(p,pocket:sample.pocket),"direct-pot")
            XCTAssertTrue(p.events.contains { if case let .pocket(ball,id) = $0.kind { return ball == ShotInput.targetBallName && id == "pocket_\(sample.pocket)" }; return false })
        }
    }

    /// Review-only replay at a proven speed; raw frames stop at target capture.
    /// Presentation polylines contain post-pot ball-collection animation and are not evidence.
    @MainActor func testV4DirectReviewTrajectories() throws {
        let output = root.appendingPathComponent("output/accuracy-middle-direct-v4-20261021")
        let requestURL = output.appendingPathComponent("review-request.json")
        guard FileManager.default.fileExists(atPath:requestURL.path) else { throw XCTSkip("Explicit direct review request required") }
        struct Replay: Codable { let sample: Sample; let speed: Float; let nativeIndex: Int }
        struct Frame: Codable { let time: Float; let x: Float; let y: Float; let z: Float }
        struct Review: Codable { let target: [Frame]; let speed: Float; let cuePocketed: Bool; let captureTime: Float; let route: String }
        let items = try JSONDecoder().decode([Replay].self,from:Data(contentsOf:requestURL))
        try FileManager.default.moveItem(at:requestURL,to:output.appendingPathComponent("review-consumed-request.json"))
        XCTAssertEqual(items.count,20)
        for item in items {
            let p = simulateCenter(item.sample,item.speed)
            XCTAssertEqual(directRoute(p,pocket:item.sample.pocket),"direct-pot")
            let capture = try XCTUnwrap(p.events.first { if case let .pocket(ball,_) = $0.kind { return ball == ShotInput.targetBallName }; return false })
            let frames = try XCTUnwrap(p.recorder?.framesByBallName[ShotInput.targetBallName])
            let recorded = frames.filter { $0.time <= capture.time }.map { Frame(time:$0.time,x:$0.position.x,y:$0.position.y,z:$0.position.z) }
            XCTAssertGreaterThan(recorded.count,1)
            let review = Review(target:recorded,speed:item.speed,cuePocketed:p.cuePocketed,captureTime:capture.time,route:"direct-pot")
            try JSONEncoder().encode(review).write(to:output.appendingPathComponent("review-native-paths/\(item.nativeIndex).json"),options:.atomic)
        }
    }

    @MainActor func testMiddleConcurrencyBenchmark() throws {
        let output = root.appendingPathComponent("output/accuracy-middle-benchmark-20261021")
        let requestURL = output.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath:requestURL.path) else {
            throw XCTSkip("Explicit 5000-layout concurrency benchmark request required")
        }
        let request = try JSONDecoder().decode(Request.self,from:Data(contentsOf:requestURL))
        try FileManager.default.removeItem(at:requestURL)
        let sampleData = try Data(contentsOf:output.appendingPathComponent("samples.json"))
        let inventoryData = try Data(contentsOf:root.appendingPathComponent("output/accuracy-grid-anchor-v2-20261021/inventory.json"))
        func digest(_ data: Data) -> String {
            SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
        }
        guard digest(sampleData) == request.gallerySHA256,
              digest(inventoryData) == request.inventorySHA256 else {
            throw TrainingQuestionBank.Failure.invalid("Benchmark input changed")
        }
        let gallery = try JSONDecoder().decode(Gallery.self,from:sampleData)
        XCTAssertEqual(gallery.samples.count,5000)
        XCTAssertTrue(gallery.samples.allSatisfy { $0.pocket == 4 || $0.pocket == 5 })
        for sample in gallery.samples.prefix(20) { _ = simulateCenter(sample,2) }
        // Compare the refactored runner to the previous 30-case native evidence
        // before performance measurement; timestamps are deliberately excluded.
        struct Previous: Decodable { let results: [CenterResult] }
        let previous = try JSONDecoder().decode(Previous.self,from:Data(contentsOf:
            root.appendingPathComponent("output/accuracy-center-five-20261021/results.json")))
        let previousGallery = try JSONDecoder().decode(Gallery.self,from:Data(contentsOf:
            root.appendingPathComponent("output/accuracy-grid-anchor-v2-20261021/render-samples.json")))
        func signature(_ results: [CenterResult]) throws -> String {
            let stable = results.map { r in
                CenterResult(sampleIndex:r.sampleIndex,cellID:r.cellID,pocket:r.pocket,
                    elapsedSeconds:0,trials:r.trials.map { t in
                        CenterTrial(speed:t.speed,seconds:0,settled:t.settled,targetPotted:t.targetPotted,
                            cuePocketed:t.cuePocketed,feedback:t.feedback,
                            minimumAnchorDistance:t.minimumAnchorDistance,
                            maximumForwardTravel:t.maximumForwardTravel,targetCushions:t.targetCushions)
                    },proof:r.proof)
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            return digest(try encoder.encode(stable))
        }
        let replayed = previousGallery.samples.enumerated().map { runCenter($0.offset,$0.element) }
        XCTAssertEqual(try signature(replayed),try signature(previous.results),"30-case algorithm regression")
        struct Phase: Codable {
            let workers: Int; let wallSeconds: Double; let writeSeconds: Double
            let passed: Int; let calls: Int; let resultSignature: String
            let thermalStart: Int; let thermalEnd: Int
        }
        struct Report: Codable {
            let sourceFingerprint: String; let gallerySHA256: String; let inventorySHA256: String
            let sampleCount: Int; let order: [Int]; let phases: [Phase]
        }
        let order = [4,6,8,12,18]
        var phases: [Phase] = []
        var baselineSignature: String?
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        for workers in order {
            let thermalStart = ProcessInfo.processInfo.thermalState.rawValue
            let start = ProcessInfo.processInfo.systemUptime
            let queue = OperationQueue(); queue.maxConcurrentOperationCount = workers
            let lock = NSLock()
            var results: [Int:CenterResult] = [:]
            for (index,sample) in gallery.samples.enumerated() {
                queue.addOperation {
                    let result = self.runCenter(index,sample)
                    lock.lock()
                    results[index] = result
                    let count = results.count
                    lock.unlock()
                    if count % 1000 == 0 {
                        print("MIDDLE_PROGRESS workers=\(workers) done=\(count)/5000")
                    }
                }
            }
            queue.waitUntilAllOperationsAreFinished()
            let wall = ProcessInfo.processInfo.systemUptime-start
            let thermalEnd = ProcessInfo.processInfo.thermalState.rawValue
            let ordered = gallery.samples.indices.map { results[$0]! }
            let resultSignature = try signature(ordered)
            if let baselineSignature {
                XCTAssertEqual(resultSignature,baselineSignature,"Concurrency changed physical results")
            } else { baselineSignature = resultSignature }
            for result in ordered {
                XCTAssertTrue((1...5).contains(result.trials.count))
                XCTAssertEqual(result.proof != nil,result.trials.contains { $0.targetPotted })
            }
            let writeStart = ProcessInfo.processInfo.systemUptime
            try encoder.encode(ordered).write(to:output.appendingPathComponent("results-\(workers).json"),options:.atomic)
            let phase = Phase(workers:workers,wallSeconds:wall,
                writeSeconds:ProcessInfo.processInfo.systemUptime-writeStart,
                passed:ordered.filter { $0.proof != nil }.count,
                calls:ordered.reduce(0) { $0+$1.trials.count },resultSignature:resultSignature,
                thermalStart:thermalStart,thermalEnd:thermalEnd)
            phases.append(phase)
            try encoder.encode(Report(sourceFingerprint:request.sourceFingerprint,
                gallerySHA256:request.gallerySHA256,inventorySHA256:request.inventorySHA256,
                sampleCount:ordered.count,order:order,phases:phases))
                .write(to:output.appendingPathComponent("benchmark.json"),options:.atomic)
            print("MIDDLE_BENCH workers=\(workers) passed=\(phase.passed) calls=\(phase.calls) wall=\(wall) thermal=\(thermalStart)->\(thermalEnd)")
        }
        XCTAssertEqual(phases.count,5)
    }

    @MainActor func testFixedDirectionSpeedScreening() throws {
        let output = root.appendingPathComponent("output/accuracy-speed-screening-20261021")
        let requestURL = output.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else {
            throw XCTSkip("Explicit speed screening experiment request required")
        }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        try FileManager.default.removeItem(at: requestURL)
        let inventoryDirectory = root.appendingPathComponent("output/accuracy-grid-anchor-v2-20261021")
        let galleryData = try Data(contentsOf: inventoryDirectory.appendingPathComponent("render-samples.json"))
        let inventoryData = try Data(contentsOf: inventoryDirectory.appendingPathComponent("inventory.json"))
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined() }
        guard digest(galleryData) == request.gallerySHA256,
              digest(inventoryData) == request.inventorySHA256 else {
            throw TrainingQuestionBank.Failure.invalid("Screening input changed")
        }
        let gallery = try JSONDecoder().decode(Gallery.self, from: galleryData)
        XCTAssertEqual(gallery.samples.count, 30)
        let model = try XCTUnwrap(TableModelLoader.loadTable(includeVisual:false))
        let profile = CueStick(modelCueStickNode:try XCTUnwrap(model.cueStickNode)).clearanceProfile
        let jobs = gallery.samples.enumerated().flatMap { index, s in
            TrainingFixedTip.allCases.map { tip in
                let direction = (s.ghost.vector-s.cue.vector).normalized()
                let access = CueStrikeAccess(cue:SCNVector3(s.cue.vector.x,BallPhysics.radius,s.cue.vector.z),
                    aim:direction,obstacles:[SCNVector3(s.target.vector.x,BallPhysics.radius,s.target.vector.z)],
                    surfaceY:0,profile:profile).isAvailable(spinX:Double(tip.x),spinY:Double(tip.y))
                return Job(sampleIndex:index,sample:s,tip:tip,direction:direction,accessible:access)
            }
        }
        let low = Float(ShotTuning.velocityRange.lowerBound)
        let high = Float(ShotTuning.velocityRange.upperBound)
        func simulate(_ job: Job, speed: Float) -> ShotPrediction {
            ShotPredictor.simulateFree(cueBall:job.sample.cue.vector,aimDir:job.direction,velocity:speed,
                spinX:job.tip.x,spinY:job.tip.y,surfaceY:0,
                balls:[.init(name:ShotInput.targetBallName,position:job.sample.target.vector)],
                recordedStrikeDirection:job.direction)
        }
        // Warm static physics setup separately from measured experiment phases.
        if let warmup = jobs.first(where: { $0.accessible }) { _ = simulate(warmup,speed:2) }
        func run(_ job: Job, method: String) -> Result {
            let started = ProcessInfo.processInfo.systemUptime
            var trials: [Trial] = []
            var proof: Proof?
            func evaluate(_ speed: Float) -> Bool {
                let start = ProcessInfo.processInfo.systemUptime
                let p = simulate(job,speed:speed)
                let seconds = ProcessInfo.processInfo.systemUptime-start
                let entered = p.events.contains { event in
                    if case let .pocket(ball,id) = event.kind {
                        return ball == ShotInput.targetBallName && id == "pocket_\(job.sample.pocket)"
                    }
                    return false
                }
                let outcome = AccuracyShotJudgement.evaluate(p,pocketIndex:job.sample.pocket).rawValue
                let success = p.hasFinalTableState && entered
                trials.append(.init(speed:speed,seconds:seconds,settled:p.hasFinalTableState,
                    targetPotted:success,accuracyOutcome:outcome))
                if success && proof == nil {
                    proof = .init(speed:speed,direction:.init(job.direction),spinX:job.tip.x,spinY:job.tip.y,
                        settled:p.hasFinalTableState,accuracyOutcome:outcome,events:p.events.map(TrainingProofEvent.init))
                }
                return success
            }
            if job.accessible {
                switch method {
                case "single-branch-increase-on-miss":
                    // Explicit experimental assumption, NOT a general valid bisection:
                    // on miss, discard every weaker speed; stop on first pot.
                    var a = low
                    for _ in 0..<7 {
                        let mid = (a+high)/2
                        if evaluate(mid) { break }
                        a = mid
                    }
                case "two-sided-midpoint-subdivision":
                    // Breadth-first dyadic subdivision; no monotonicity assumption.
                    // Fifteen interior points plus endpoints, stop on first pot.
                    var ranges: [(Float,Float)] = [(low,high)]
                    var cursor = 0
                    while cursor < 15 {
                        let (a,b) = ranges[cursor], mid = (a+b)/2
                        cursor += 1
                        if evaluate(mid) { break }
                        ranges.append((a,mid));ranges.append((mid,b))
                    }
                    if proof == nil && !evaluate(low) { _ = evaluate(high) }
                case "reference-uniform-0.1":
                    // Independent finite reference, not a proof of continuous no-solution.
                    for k in 0...75 { _ = evaluate(low+Float(k)*0.1) }
                default: preconditionFailure("Unknown speed screening method")
                }
            }
            return .init(sampleIndex:job.sampleIndex,cellID:job.sample.cellID,pocket:job.sample.pocket,
                tip:job.tip,accessible:job.accessible,elapsedSeconds:ProcessInfo.processInfo.systemUptime-started,
                trials:trials,proof:proof)
        }
        var phases: [Phase] = []
        for method in ["single-branch-increase-on-miss","two-sided-midpoint-subdivision","reference-uniform-0.1"] {
            let started = ProcessInfo.processInfo.systemUptime
            let queue = OperationQueue();queue.maxConcurrentOperationCount = 4
            let lock = NSLock()
            var results: [Int:Result] = [:]
            for (index,job) in jobs.enumerated() {
                queue.addOperation {
                    let result = run(job,method:method)
                    lock.lock();results[index] = result;lock.unlock()
                }
            }
            queue.waitUntilAllOperationsAreFinished()
            let phase = Phase(method:method,wallSeconds:ProcessInfo.processInfo.systemUptime-started,
                              results:jobs.indices.map { results[$0]! })
            phases.append(phase)
            print("SPEED method=\(method) jobs=\(phase.results.count) proofs=\(phase.results.filter{$0.proof != nil}.count) calls=\(phase.results.reduce(0){$0+$1.trials.count}) wall=\(phase.wallSeconds)")
            // Persist each finished phase; no recorded frames or paths.
            struct Report: Codable {
                let sourceFingerprint: String; let inventorySourceFingerprint: String
                let gallerySHA256: String; let inventorySHA256: String
                let workers: Int; let directionPolicy: String; let successPolicy: String
                let phases: [Phase]
            }
            let report = Report(sourceFingerprint:request.sourceFingerprint,
                inventorySourceFingerprint:gallery.sourceFingerprint,
                gallerySHA256:request.gallerySHA256,inventorySHA256:request.inventorySHA256,
                workers:4,directionPolicy:"Exact fixed C-to-G direction; fixed tip for each independent job; speed 0.5...8 m/s",
                successPolicy:"Settled and target in specified pocket; scratch/indirect recorded separately; NOT accuracy-qualified",
                phases:phases)
            let encoder = JSONEncoder();encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(report).write(to:output.appendingPathComponent("results.json"),options:.atomic)
        }
        XCTAssertEqual(phases.count,3)
        for phase in phases {
            XCTAssertEqual(phase.results.count,270)
            for result in phase.results {
                XCTAssertTrue(result.trials.allSatisfy { $0.speed >= low && $0.speed <= high })
                if result.proof != nil { XCTAssertTrue(result.trials.contains { $0.targetPotted }) }
            }
        }
    }
}
