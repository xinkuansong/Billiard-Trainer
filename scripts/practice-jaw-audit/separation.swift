import Foundation
import SceneKit

@testable import QiuJi

@main
struct SeparationAudit {
  struct Entry: Codable {
    let board: String
    let axes: Int
    let seed: UInt64
    let result: String
    var minimum: Float?
    var original: SeparationInput?
    var answer: SeparationInput?
    var jawCount: Int?
    var rmsCM: Double?
  }
  static func main() throws {
    let args = CommandLine.arguments
    let lane = Int(args[1])!
    let lanes = Int(args[2])!
    let root = URL(fileURLWithPath: args[3])
    let grid = try TrainingBankStore.load()
    let profile = AccuracyTipSelector.renderedProfile()
    let groups = grid.pools.enumerated().flatMap { code, pool in
      stride(from: 0, to: pool.count, by: 16).map { (code, $0, min($0 + 16, pool.count)) }
    }
    let end = args.count > 4 ? min(Int(args[4])!, groups.count) : groups.count
    for index in stride(from: lane, to: end, by: lanes) {
      let file = root.appendingPathComponent("sep-\(index).json")
      if FileManager.default.fileExists(atPath: file.path) { continue }
      let (code, start, end) = groups[index]
      var rows = [Entry]()
      for position in start..<end {
        try autoreleasepool {
          let ref = grid.pools[code][position]
          let board = grid.board(reference: ref, combination: code)
          var audit = SeparationQuestionGenerator.Audit()
          let minimum = try SeparationQuestionGenerator.minimumCenterSpeed(
            board: board, profile: profile, audit: &audit)
          for axes in 0..<4 {
            let seed = UInt64(ref) * 4 + UInt64(axes) + 20_261_106
            var config = SceneTrainingConfiguration()
            config.allowsVerticalSpin = axes & 1 != 0
            config.allowsSideSpin = axes & 2 != 0
            var random = SceneTrainingGenerator.SeededRandom(state: seed)
            guard let minimum,
              let question = try SeparationQuestionGenerator.generateAnswer(
                board: board, configuration: config,
                profile: profile, random: &random, minimum: minimum, audit: audit, started: Date())
            else {
              rows.append(
                Entry(
                  board: board.id, axes: axes, seed: seed,
                  result: minimum == nil ? "noMinimum" : "generationBudget", minimum: minimum))
              continue
            }
            let restored = try JSONDecoder().decode(
              SeparationQuestion.self, from: JSONEncoder().encode(question))
            let shot = try restored.demonstrationShot(surfaceY: BTTablePhysics.surfaceY)
            let hits = ShotPredictor.bankPocketContactCount(events: shot.prediction().events)
            let original = question.audit.sampledInputs.last!
            let adjusted = original != question.answer
            guard shot.specifiedPocket, let rms = shot.score?.distanceCM, rms <= 0.5,
              !adjusted || hits == 0
            else { throw NSError(domain: "invalid separation replay " + board.id, code: axes) }
            rows.append(
              Entry(
                board: board.id, axes: axes, seed: seed,
                result: adjusted ? "adjusted" : (hits == 0 ? "clean" : "review"),
                minimum: minimum, original: original, answer: question.answer, jawCount: hits,
                rmsCM: rms))
          }
        }
      }
      try JSONEncoder().encode(rows).write(to: file, options: .atomic)
    }
  }
}
