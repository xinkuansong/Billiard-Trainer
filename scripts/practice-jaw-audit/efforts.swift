import Foundation
import SceneKit

@testable import QiuJi

@main struct OrderingAudit {
  struct Row: Decodable {
    let key, state: String
    let effort: Double?
  }
  static func main() throws {
    let args = CommandLine.arguments
    let folder = URL(fileURLWithPath: args[1])
    let store = try TwoBallBankStore.load()
    let profile = TwoBallQuestionPreparer.renderedProfile()
    var measured = [String: Double]()
    for (i, entry) in store.index.layouts.enumerated() {
      let data = try Data(contentsOf: folder.appendingPathComponent("rows/two-\(i).json"))
      let rows = try JSONDecoder().decode([Row].self, from: data)
      let byKey = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0) })
      guard rows.contains(where: { $0.state == "adjusted" }) else { continue }
      try autoreleasepool {
        let layout = try store.layout(entry)
        let board = try store.board(for: layout)
        let lookup = Dictionary(uniqueKeysWithValues: layout.routes.map { ($0.id, $0) })
        for cell in layout.questions {
          func key(_ ref: [Int]) -> String { "\(layout.id)#\(cell.id)/\(ref[0])" }
          guard cell.refs.contains(where: { byKey[key($0)]?.state == "adjusted" }) else { continue }
          let second = TrainingBankPoint(SCNVector3(Float(cell.p[0]), 0, Float(cell.p[1])))
          for (rank, ref) in cell.refs.enumerated() {
            let id = key(ref)
            let row = byKey[id]!
            guard row.effort == nil && ["geometryReview", "searchReview"].contains(row.state) else {
              continue
            }
            guard
              let baseline = try TwoBallQuestionPreparer.materialize(
                board: board, second: second,
                parameter: lookup[ref[0]]!, pocket: ref[1], rank: rank, profile: profile),
              let effort = baseline.source.executionDifficulty?.effort
            else {
              throw NSError(domain: "baseline no longer admitted " + id, code: 1)
            }
            measured[id] = effort
          }
        }
      }
    }
    try JSONEncoder().encode(measured).write(
      to: folder.appendingPathComponent("two-extra-efforts.json"), options: .atomic)
  }
}
