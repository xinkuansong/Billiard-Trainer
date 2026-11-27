import Foundation

/// Shared completion rules, with mode-specific physical technique evidence.
enum SpatialQuizMode: String, Codable, CaseIterable {
    case masse, jump
}

/// Value-only, versioned facts. No rendered paths, recovered balls or reference-answer scores.
struct SpatialQuizFacts: Codable, Equatable {
    enum Role: String, Codable, CaseIterable { case cue, target, obstacle }
    enum Surface: String, Codable { case cushion, cloth, liner, exterior }
    enum EventKind: Codable, Equatable {
        case balls(Role, Role)
        case surface(Role, Surface, approaching: Bool)
        case pocket(Role, id: String)
        case outside(Role)
    }
    struct Event: Codable, Equatable {
        let time: Double
        let kind: EventKind
        let source: String
        /// Mesh solver's Double clock, before projection onto the engine's Float event clock.
        var physicalTime: Double? = nil
    }
    let complete: Bool
    let duration: Double
    let events: [Event]
    let issues: [String]
    // Optional only for frozen v1/v2 archives and isolated completion-rule fixtures.
    // Every production quiz board supplies mode; current records require it.
    var mode: SpatialQuizMode? = nil
    var technique: Technique? = nil
    struct Technique: Codable, Equatable {
        let maximumLift, chordDeviation, chordObstacleClearance: Double
        let jumpedOverObstacle: Bool
        var valid: Bool {
            [maximumLift,chordDeviation,chordObstacleClearance].allSatisfy(\.isFinite) &&
            maximumLift >= 0 && chordDeviation >= 0
        }
    }
}

enum SpatialQuizJudgement {
    static let version = "spatial-quiz-v4"
    // The live bank must have passed the same rule as players. Its manifest
    // retains historical v1 admission under previousAdmission.
    static let referenceAdmissionVersion = version
    // Same Float event grouping contract as SpatialPracticeRecord.firstCueContact.
    static let contactTimeGroup = 1e-6
    enum Completion: String, Codable, CaseIterable {
        case targetPotted, cueCushionAfterContact, targetCushionAfterContact
    }
    enum Failure: String, Codable {
        case cuePotted, cueOutside, targetOutside, obstaclePotted, obstacleOutside
        case wrongFirstContact, obstacleContact, noTargetContact, noCompletion
        case cushionBeforeTarget, noJumpOverObstacle, noMasseAroundObstacle
    }
    enum Outcome: Codable, Equatable {
        case success([Completion])
        case failure(Failure)
        case unconfirmed([String])
        var succeeded: Bool { if case .success = self { return true }; return false }
        var confirmed: Bool { if case .unconfirmed = self { return false }; return true }
    }

    static func evaluate(_ facts: SpatialQuizFacts) -> Outcome {
        guard facts.complete else { return .unconfirmed(["incompleteSimulation"] + facts.issues) }
        guard facts.issues.isEmpty else { return .unconfirmed(facts.issues) }
        guard facts.duration.isFinite, facts.duration >= 0,
              facts.events.allSatisfy({ $0.time.isFinite && $0.time >= 0 &&
                  $0.time <= facts.duration + contactTimeGroup && !$0.source.isEmpty &&
                  ($0.physicalTime.map { $0.isFinite && $0 >= 0 } ?? true) }) else {
            return .unconfirmed(["invalidEventTimeOrSource"])
        }
        for event in facts.events {
            switch event.kind {
            case let .balls(a, b) where a == b: return .unconfirmed(["selfContact"])
            case let .pocket(_, id) where id.isEmpty: return .unconfirmed(["missingPocketID"])
            default: break
            }
        }
        let pockets = Set(facts.events.compactMap { e -> SpatialQuizFacts.Role? in
            if case let .pocket(role, _) = e.kind { return role }; return nil
        })
        let outside = Set(facts.events.compactMap { e -> SpatialQuizFacts.Role? in
            if case let .outside(role) = e.kind { return role }; return nil
        })
        // Evaluate the whole settled stroke, including fouls after an apparent completion.
        if pockets.contains(.cue) { return .failure(.cuePotted) }
        if outside.contains(.cue) { return .failure(.cueOutside) }
        if outside.contains(.target) { return .failure(.targetOutside) }
        if pockets.contains(.obstacle) { return .failure(.obstaclePotted) }
        if outside.contains(.obstacle) { return .failure(.obstacleOutside) }

        let first = facts.events.filter {
            if case let .balls(a, b) = $0.kind { return a == .cue || b == .cue }; return false
        }.map(\.time).min()
        guard let first else { return .failure(.noTargetContact) }
        let group = facts.events.filter { abs($0.time - first) <= contactTimeGroup }
        var connected: Set<SpatialQuizFacts.Role> = [.cue]
        var changed = true
        while changed {
            changed = false
            for event in group {
                guard case let .balls(a, b) = event.kind,
                      connected.contains(a) || connected.contains(b) else { continue }
                if connected.insert(a).inserted { changed = true }
                if connected.insert(b).inserted { changed = true }
            }
        }
        guard connected == [.cue, .target] else { return .failure(.wrongFirstContact) }
        // A later obstacle contact is legal. Keep obstacleContact decodable for
        // frozen v1 history, but do not apply that retired whole-stroke rule.

        if let mode = facts.mode {
            let earlyRail = facts.events.contains {
                if case .surface(.cue, .cushion, approaching: true) = $0.kind {
                    return $0.time < first - contactTimeGroup
                }; return false
            }
            if earlyRail { return .failure(.cushionBeforeTarget) }
            guard let technique = facts.technique, technique.valid else {
                return .unconfirmed(["missingTechniqueEvidence"])
            }
            switch mode {
            case .jump:
                if !technique.jumpedOverObstacle { return .failure(.noJumpOverObstacle) }
            case .masse:
                if technique.jumpedOverObstacle ||
                    technique.chordDeviation <= SpatialQuizTechnique.techniqueTolerance {
                    return .failure(.noMasseAroundObstacle)
                }
            }
        }

        var completed: Set<Completion> = []
        var simultaneousCompletion = false
        for event in facts.events {
            let completion: Completion?
            switch event.kind {
            case .pocket(.target, _): completion = .targetPotted
            case .surface(.cue, .cushion, approaching: true): completion = .cueCushionAfterContact
            case .surface(.target, .cushion, approaching: true): completion = .targetCushionAfterContact
            default: completion = nil
            }
            guard let completion else { continue }
            if event.time > first + contactTimeGroup { completed.insert(completion) }
            else if abs(event.time - first) <= contactTimeGroup { simultaneousCompletion = true }
        }
        // Ordering within a Float-time contact group cannot prove causal order.
        if simultaneousCompletion { return .unconfirmed(["simultaneousCompletionNeedsCausalEvidence"]) }
        guard !completed.isEmpty else { return .failure(.noCompletion) }
        return .success(Completion.allCases.filter { completed.contains($0) })
    }
}
