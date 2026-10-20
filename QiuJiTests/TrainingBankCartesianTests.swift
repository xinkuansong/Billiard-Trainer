import XCTest
import SceneKit
@testable import QiuJi

/// Explicit offline job. Independent candidates/solves run concurrently; only
/// the coordinator mutates the family index or writes shard checkpoints.
final class TrainingBankCartesianTests: XCTestCase {
    struct Request: Codable {
        let sourceFingerprint: String
        let seed: UInt64
        let targetPerCell: Int
        let attemptsPerCell: Int
        let workers: Int
        let seconds: Double
        let resume: Bool
        let revalidate: Bool?
        let cellIDs: [String]
    }
    struct Shard: Codable {
        let cell: TrainingInventoryCell
        var sourceFingerprint: String
        var runtimeFingerprint: String?
        let dedupVersion: String
        let seed: UInt64
        var attempts = 0
        var geometryMisses = 0
        var proofMisses = 0
        var duplicates = 0
        var boards: [TrainingBankBoard] = []
        var proofs: [TrainingPotProof] = []
        var fastProofs: Int?
    }
    struct Candidate {
        let cell: TrainingInventoryCell
        let board: TrainingBankBoard?
        let proofs: [TrainingPotProof]
        var fastProofs = 0
    }
    struct Hint {
        let board: TrainingBankBoard
        let proof: TrainingPotProof
    }
    private let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("output/accuracy-bank-cartesian-20261021")

    private func forward(_ board: TrainingBankBoard, tip: TrainingFixedTip,
                         direction: SCNVector3, speed: Float) -> ShotPrediction {
        ShotPredictor.simulateFree(cueBall: board.cue.vector, aimDir: direction, velocity: speed,
            spinX: tip.x, spinY: tip.y, surfaceY: 0,
            balls: [.init(name: ShotInput.targetBallName, position: board.target.vector)],
            recordedStrikeDirection: direction)
    }
    private func verify(_ board: TrainingBankBoard, tip: TrainingFixedTip, direction: SCNVector3,
                        speed: Float, profile: [CueSection]) -> TrainingPotProof? {
        guard CueStrikeAccess(cue: SCNVector3(board.cue.x, BallPhysics.radius, board.cue.z), aim: direction,
            obstacles: [SCNVector3(board.target.x, BallPhysics.radius, board.target.z)], surfaceY: 0, profile: profile)
            .isAvailable(spinX: Double(tip.x), spinY: Double(tip.y)) else { return nil }
        let shot = forward(board, tip: tip, direction: direction, speed: speed)
        guard shot.hasFinalTableState,
              AccuracyShotJudgement.evaluate(shot, pocketIndex: board.pocketIndex) == .success else { return nil }
        var samples: [TrainingToleranceSample] = []
        for a: Float in [-TrainingPotProof.angleRadius, 0, TrainingPotProof.angleRadius] {
            for v: Float in [-TrainingPotProof.speedRadius, 0, TrainingPotProof.speedRadius] {
                let result = a == 0 && v == 0 ? shot : forward(board, tip: tip,
                    direction: direction.rotatedY(a * .pi / 180), speed: speed+v)
                let outcome = AccuracyShotJudgement.evaluate(result, pocketIndex: board.pocketIndex)
                guard result.hasFinalTableState, outcome == .success else { return nil }
                samples.append(.init(angleDeltaDegrees: a, velocityDelta: v, outcome: outcome))
            }
        }
        return .init(board: board, prediction: shot, velocity: speed, tip: tip, samples: samples)
    }
    private func geometricDirection(_ board: TrainingBankBoard) -> SCNVector3 {
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: board.target.vector,
            pocket: board.effectiveAim.vector, ballRadius: BallPhysics.radius)
        return (ghost-board.cue.vector).normalized()
    }
    /// Reuse only the angular correction, never the success result. No reflection:
    /// side spin and real pocket geometry must not be silently mirrored.
    private func proposedDirection(_ hint: Hint, for board: TrainingBankBoard) -> SCNVector3 {
        let before = geometricDirection(hint.board), solved = hint.proof.direction.vector
        let correction = atan2(before.x*solved.z-before.z*solved.x, before.x*solved.x+before.z*solved.z)
        return geometricDirection(board).rotatedY(correction)
    }
    private func solve(_ board: TrainingBankBoard, tip: TrainingFixedTip,
                       preferred: TrainingPotProof?, hints: [Hint], profile: [CueSection]) -> (TrainingPotProof?, Bool) {
        // Cheap proposals all pass through the same cue-access + nominal + nine-point
        // verification on this board. Failing proposals fall back to inverse search.
        var proposals: [(SCNVector3, Float)] = []
        if let preferred { proposals.append((preferred.direction.vector, preferred.velocity)) }
        for hint in hints where hint.proof.tip == tip && hint.board.pocketIndex == board.pocketIndex {
            proposals.append((proposedDirection(hint, for: board), hint.proof.velocity))
        }
        proposals.append((geometricDirection(board), 1.5))
        for (direction, speed) in proposals {
            if let proof = verify(board, tip: tip, direction: direction, speed: speed, profile: profile) {
                return (proof, true)
            }
        }
        var speeds = preferred.map { [$0.velocity] } ?? []
        for speed: Float in [1.5, 2.5, 3.5, 0.8, 5] where !speeds.contains(speed) { speeds.append(speed) }
        for speed in speeds {
            let input = ShotInput(cueBall: board.cue.vector, targetBall: board.target.vector,
                pocketIndex: board.pocketIndex, velocity: speed, spinX: tip.x, spinY: tip.y, surfaceY: 0)
            let suggestion = ShotPredictor.predictForPositionSolve(input, includePresentation: false)
            guard suggestion.feasible else { continue }
            if let proof = verify(board, tip: tip, direction: suggestion.aimDirection, speed: speed, profile: profile) {
                return (proof, false)
            }
        }
        return (nil, false)
    }
    private func candidate(cell: TrainingInventoryCell, ordinal: Int, seed: UInt64) -> TrainingBankBoard? {
        // Stable, disjoint random streams. Scheduling/worker count do not seed the generator.
        let cellOrdinal = TrainingInventoryCell.all.firstIndex(of: cell)!
        var rng = SceneTrainingGenerator.SeededRandom(state: seed &+ UInt64(cellOrdinal) &* 0x9e3779b97f4a7c15
            &+ UInt64(ordinal) &* 0xbf58476d1ce4e5b9)
        let generatedSeed = rng.next()
        let angle = Int.random(in: TrainingInventoryCell.angles[cell.angleIndex], using: &rng)
        let pocket = cell.pocketType == 0 ? Int.random(in: 0..<4, using: &rng) : Int.random(in: 4..<6, using: &rng)
        var generator = SceneTrainingGenerator(seed: generatedSeed)
        guard let q = generator.question(angle: angle, side: ordinal % 2 == 0 ? 1 : -1, pocket: pocket,
            cueBand: cell.cueBand, pocketBand: cell.pocketBand, railSelection: cell.railSelection,
            allowsTargetJawContact: true) else { return nil }
        let board = TrainingBankBoard(question: q, seed: generatedSeed)
        return cell.contains(board) ? board : nil
    }
    private func parallel<T, U>(_ items: [T], workers: Int, work: @escaping (T) -> U) -> [U] {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = workers
        let lock = NSLock()
        var results: [Int: U] = [:]
        for (index, item) in items.enumerated() {
            queue.addOperation {
                let value = autoreleasepool { work(item) }
                lock.lock(); results[index] = value; lock.unlock()
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        return items.indices.map { results[$0]! }
    }

    @MainActor func testProduceCartesianShards() throws {
        let requestURL = directory.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else { throw XCTSkip("Explicit Cartesian production request required") }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        try FileManager.default.removeItem(at: requestURL)
        guard request.targetPerCell == 500, (1...8).contains(request.workers), request.seconds > 0,
              request.attemptsPerCell > 0 else { throw TrainingQuestionBank.Failure.invalid("Invalid production budget") }
        let cells = TrainingInventoryCell.all.filter { request.cellIDs.isEmpty || request.cellIDs.contains($0.id) }
        XCTAssertFalse(cells.isEmpty)
        let shardDirectory = directory.appendingPathComponent("shards")
        try FileManager.default.createDirectory(at: shardDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let model = try XCTUnwrap(TableModelLoader.loadTable(includeVisual: false))
        let profile = CueStick(modelCueStickNode: try XCTUnwrap(model.cueStickNode)).clearanceProfile
        let runtimeFingerprint = TrainingBankIdentity.hash(profile.map {
            "\($0.start.bitPattern):\($0.end.bitPattern):\($0.radius.bitPattern)"
        }.joined(separator: "|"))
        var shards: [String: Shard] = [:]
        let families = TrainingLayoutFamilyIndex()
        // Load all existing cells, including those outside the requested work subset.
        for cell in TrainingInventoryCell.all {
            let path = shardDirectory.appendingPathComponent(cell.id+".json")
            if FileManager.default.fileExists(atPath: path.path) {
                guard request.resume else { throw TrainingQuestionBank.Failure.invalid("Existing shards require resume") }
                let shard = try JSONDecoder().decode(Shard.self, from: Data(contentsOf: path))
                guard shard.cell == cell, shard.dedupVersion == TrainingLayoutFeatures.version,
                      shard.seed == request.seed else {
                    throw TrainingQuestionBank.Failure.invalid("Stale shard; replay required")
                }
                guard request.revalidate == true ||
                    (shard.sourceFingerprint == request.sourceFingerprint && shard.runtimeFingerprint == runtimeFingerprint) else {
                    throw TrainingQuestionBank.Failure.invalid("Source or rendered cue profile changed; explicit revalidation required")
                }
                shards[cell.id] = shard
            } else {
                shards[cell.id] = .init(cell: cell, sourceFingerprint: request.sourceFingerprint, runtimeFingerprint: runtimeFingerprint,
                    dedupVersion: TrainingLayoutFeatures.version, seed: request.seed)
            }
        }
        if request.revalidate == true {
            // Replay recorded inputs, without re-aiming or running inverse search.
            // Keep original shards as a recoverable, content-addressed history.
            for cell in TrainingInventoryCell.all {
                var shard = shards[cell.id]!
                let oldData = try encoder.encode(shard)
                let archive = directory.appendingPathComponent("revalidation-history")
                    .appendingPathComponent(TrainingBankIdentity.hash(String(decoding: oldData, as: UTF8.self)))
                try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
                try oldData.write(to: archive.appendingPathComponent(cell.id+".json"), options: .atomic)
                let boardsByID = Dictionary(uniqueKeysWithValues: shard.boards.map { ($0.id, $0) })
                let checked = parallel(shard.proofs, workers: request.workers) { proof -> TrainingPotProof? in
                    guard let board = boardsByID[proof.boardID], cell.contains(board) else { return nil }
                    return self.verify(board, tip: proof.tip, direction: proof.direction.vector,
                        speed: proof.velocity, profile: profile)
                }.compactMap { $0 }
                let validIDs = Set(checked.map(\.boardID))
                let oldCount = shard.boards.count
                shard.boards.removeAll { !validIDs.contains($0.id) }
                shard.proofMisses += oldCount-shard.boards.count
                print("CARTESIAN replay cell=\(cell.id) retained=\(checked.count)/\(shard.proofs.count)")
                shard.proofs = checked
                shard.sourceFingerprint = request.sourceFingerprint
                shard.runtimeFingerprint = runtimeFingerprint
                shards[cell.id] = shard
                try encoder.encode(shard).write(to: shardDirectory.appendingPathComponent(cell.id+".json"), options: .atomic)
            }
        }
        for cell in TrainingInventoryCell.all {
            for board in shards[cell.id]!.boards {
                XCTAssertTrue(cell.contains(board))
                XCTAssertNil(families.duplicate(of: board), "Duplicate retained family")
                families.insert(board)
            }
        }
        let start = Date()
        var waves = 0
        while Date().timeIntervalSince(start) < request.seconds {
            let eligible = cells.filter { shards[$0.id]!.boards.count < request.targetPerCell
                && shards[$0.id]!.attempts < request.attemptsPerCell }
                .sorted { a, b in
                    let left = shards[a.id]!.attempts, right = shards[b.id]!.attempts
                    return left == right ? a.id < b.id : left < right
                }
            if eligible.isEmpty { break }
            let work = eligible.prefix(request.workers).map { cell -> (TrainingInventoryCell, Int) in
                let ordinal = shards[cell.id]!.attempts
                shards[cell.id]!.attempts += 1
                return (cell, ordinal)
            }
            let generated = parallel(work, workers: request.workers) { pair in
                Candidate(cell: pair.0, board: self.candidate(cell: pair.0, ordinal: pair.1, seed: request.seed), proofs: [])
            }
            var toSolve: [Candidate] = []
            for item in generated {
                guard let board = item.board else { shards[item.cell.id]!.geometryMisses += 1; continue }
                if families.duplicate(of: board) != nil { shards[item.cell.id]!.duplicates += 1; continue }
                toSolve.append(item)
            }
            // Snapshot two nearest same-cell, same-pocket solved boards per candidate.
            // Coordinator owns the mutable shards; workers see immutable hints only.
            let solveWork = toSolve.map { item -> (Candidate, [Hint]) in
                let shard = shards[item.cell.id]!, board = item.board!
                func distance(_ old: TrainingBankBoard) -> Float {
                    old.cue.vector.distanceXZ(to: board.cue.vector) + old.target.vector.distanceXZ(to: board.target.vector)
                }
                let nearest = shard.boards.filter { $0.pocketIndex == board.pocketIndex }
                    .sorted { distance($0) < distance($1) }.prefix(2)
                let hints = nearest.flatMap { old in shard.proofs.filter { $0.boardID == old.id }.map { Hint(board: old, proof: $0) } }
                return (item, hints)
            }
            let solved = parallel(solveWork, workers: request.workers) { item, hints in
                let board = item.board!
                var proofs: [TrainingPotProof] = []
                var fastProofs = 0
                // A layout needs one stable solution; center is preferred, not a compulsory
                // admission rule. Unavailable tips simply do not acquire variants.
                for tip in TrainingFixedTip.allCases {
                    let (proof, fast) = self.solve(board, tip: tip, preferred: proofs.first, hints: hints, profile: profile)
                    if let proof { proofs.append(proof); if fast { fastProofs += 1 } }
                }
                return Candidate(cell: item.cell, board: board, proofs: proofs, fastProofs: fastProofs)
            }
            for item in solved {
                guard !item.proofs.isEmpty else { shards[item.cell.id]!.proofMisses += 1; continue }
                let board = item.board!
                if families.duplicate(of: board) != nil { shards[item.cell.id]!.duplicates += 1; continue }
                families.insert(board)
                shards[item.cell.id]!.boards.append(board)
                shards[item.cell.id]!.proofs += item.proofs
                shards[item.cell.id]!.fastProofs = (shards[item.cell.id]!.fastProofs ?? 0)+item.fastProofs
            }
            for (cell, _) in work {
                try encoder.encode(shards[cell.id]!).write(to: shardDirectory.appendingPathComponent(cell.id+".json"), options: .atomic)
            }
            waves += 1
            print("CARTESIAN wave=\(waves) cellsTouched=\(shards.values.filter { $0.attempts > 0 }.count) attempts=\(shards.values.reduce(0) { $0+$1.attempts }) families=\(shards.values.reduce(0) { $0+$1.boards.count }) proofs=\(shards.values.reduce(0) { $0+$1.proofs.count }) elapsed=\(Int(Date().timeIntervalSince(start)))")
        }
        let ordered = TrainingInventoryCell.all.map { shards[$0.id]! }
        // Empty cells are persisted too, so the inventory always exposes all 270 cells.
        for shard in ordered {
            try encoder.encode(shard).write(to: shardDirectory.appendingPathComponent(shard.cell.id+".json"), options: .atomic)
        }
        let boards = ordered.flatMap(\.boards), proofs = ordered.flatMap(\.proofs)
        let bank = TrainingQuestionBank(schemaVersion: TrainingQuestionBank.schema, sourceFingerprint: request.sourceFingerprint,
            boards: boards, proofs: proofs, variants: proofs.map { .init(boardID: $0.boardID, proofID: $0.id, tip: $0.tip) })
        if !boards.isEmpty { try bank.validate(expectedFingerprint: request.sourceFingerprint) }
        try encoder.encode(bank).write(to: directory.appendingPathComponent("candidate-bank.json"), options: .atomic)
        print("CARTESIAN checkpoint families=\(boards.count) variants=\(proofs.count) fullCells=\(ordered.filter { $0.boards.count == 500 }.count)/270; finite budget is not impossibility evidence; candidate NOT published")
    }

    func testParallelForwardReplayMatchesSerial() throws {
        let bank = try JSONDecoder().decode(TrainingQuestionBank.self,
            from: Data(contentsOf: try XCTUnwrap(Bundle.main.url(forResource: "training-question-bank", withExtension: "json"))))
        let byID = Dictionary(uniqueKeysWithValues: bank.boards.map { ($0.id, $0) })
        let fixtures = Array(bank.proofs.filter(\.qualifiesForAccuracy).prefix(12))
        XCTAssertEqual(fixtures.count, 12)
        func digest(_ proof: TrainingPotProof) -> String {
            let board = byID[proof.boardID]!
            let shot = forward(board, tip: proof.tip, direction: proof.direction.vector, speed: proof.velocity)
            let encoded = shot.events.map { "\($0.time):\($0.kind):\($0.cushionIndex ?? -1)" }.joined(separator: "|")
            return "\(shot.hasFinalTableState):\(AccuracyShotJudgement.evaluate(shot, pocketIndex: board.pocketIndex)):"+encoded
        }
        let serial = fixtures.map(digest)
        XCTAssertEqual(parallel(fixtures, workers: 4, work: digest), serial)
        XCTAssertEqual(parallel(Array(fixtures.reversed()), workers: 4, work: digest), Array(serial.reversed()))
    }

    @MainActor func testWarmStartCorrectionAndRejectWrongDirection() throws {
        let bank = try JSONDecoder().decode(TrainingQuestionBank.self,
            from: Data(contentsOf: try XCTUnwrap(Bundle.main.url(forResource: "training-question-bank", withExtension: "json"))))
        let boards = Dictionary(uniqueKeysWithValues: bank.boards.map { ($0.id, $0) })
        for proof in bank.proofs.filter(\.qualifiesForAccuracy).prefix(12) {
            let board = try XCTUnwrap(boards[proof.boardID])
            let proposed = proposedDirection(.init(board: board, proof: proof), for: board)
            XCTAssertEqual(proposed.x, proof.direction.x, accuracy: 0.00001)
            XCTAssertEqual(proposed.z, proof.direction.z, accuracy: 0.00001)
        }
        // A stored direction pointing away cannot acquire a fresh success proof.
        let proof = try XCTUnwrap(bank.proofs.first(where: \.qualifiesForAccuracy))
        let board = try XCTUnwrap(boards[proof.boardID])
        let model = try XCTUnwrap(TableModelLoader.loadTable(includeVisual: false))
        let profile = CueStick(modelCueStickNode: try XCTUnwrap(model.cueStickNode)).clearanceProfile
        let replayed = try XCTUnwrap(verify(board, tip: proof.tip, direction: proof.direction.vector,
            speed: proof.velocity, profile: profile))
        XCTAssertEqual(replayed.boardID, board.id)
        XCTAssertTrue(replayed.qualifiesForAccuracy)
        XCTAssertNil(verify(board, tip: proof.tip, direction: proof.direction.vector * -1,
            speed: proof.velocity, profile: profile))
    }
}
