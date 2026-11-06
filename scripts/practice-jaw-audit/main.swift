import Foundation
import SceneKit

@testable import QiuJi

// One simulator process owns a disjoint stripe. Commit each group atomically.
let args = CommandLine.arguments
let family = args[1]
let lane = Int(args[2])!
let lanes = Int(args[3])!
let directory = URL(fileURLWithPath: args[4], isDirectory: true)
let y = BTTablePhysics.surfaceY
let profile = AccuracyTipSelector.renderedProfile()
let target = ShotInput.targetBallName

struct ResultRow: Codable {
  let key: String
  let state: String
  var hits: Int?
  var input: SeparationInput?
  var dir: [Float]?
  var rms: Double?
  var effort: Double?
  var reason: String?
  init(_ key: String, _ state: String, hits: Int? = nil, reason: String? = nil) {
    self.key = key
    self.state = state
    self.hits = hits
    self.reason = reason
  }
}
func candidate(_ key: String, _ hits: Int, _ input: SeparationInput, _ dir: SCNVector3) -> ResultRow
{
  var r = ResultRow(key, "adjusted", hits: hits)
  r.input = input
  r.dir = [dir.x, dir.z]
  return r
}
func group(_ index: Int, run: () throws -> [ResultRow]) throws {
  let dest = directory.appendingPathComponent("\(family)-\(index).json")
  if FileManager.default.fileExists(atPath: dest.path) { return }
  let rows = try autoreleasepool(invoking: run)
  try JSONEncoder().encode(rows).write(to: dest, options: .atomic)
}
func hitCount(_ p: ShotPrediction) -> Int { ShotPredictor.bankPocketContactCount(events: p.events) }
func nearby(_ i: SeparationInput, originalZeroAxes: Bool = true, fine: Bool = false) -> [SeparationInput] {
  var result = fine ? [] : [i]
  let deltas: [Float] = fine ? [0.0025, 0.005, 0.015, 0.03] : [0.01, 0.02, 0.04, 0.08, 0.15, 0.25, 0.4]
  for delta in deltas {
    for d in [delta, -delta] {
      var n = i
      n.velocity += d
      result.append(n)
      if delta <= 0.15 {
        if !originalZeroAxes || i.spinX != 0 {
          n = i
          n.spinX += d
          result.append(n)
        }
        if !originalZeroAxes || i.spinY != 0 {
          n = i
          n.spinY += d
          result.append(n)
        }
      }
    }
  }
  return result.filter {
    $0.isValid && (0.6...4.5).contains($0.velocity)
      && $0.spinX * $0.spinX + $0.spinY * $0.spinY <= 0.25
  }
}
// Cache only the exact same object center and pocket, never quantize a near-tangent origin.
struct Origin: Hashable {
  let x, z: Float
  let pocket: Int
}
var windows = [Origin: Bool]()
func eligible(_ p: ShotPrediction, pocket: Int, bank: Bool = false) -> Bool {
  guard let rec = p.recorder, let first = rec.firstBallContacts[target],
    let frames = rec.framesByBallName[target]
  else { return false }
  let rails = p.events.filter {
    if case .ballCushion(let b) = $0.kind { return b == target }
    return false
  }
  let main = rails.filter { (0..<6).contains($0.cushionIndex ?? -1) }
  guard bank ? !main.isEmpty : main.isEmpty else { return false }
  let t = main.last?.time ?? first.time
  let center = TableGeometry.chineseEightBallQiuJi(surfaceY: y).pockets[pocket].center
  for e in rails where (e.cushionIndex ?? -1) >= 6 {
    guard e.time >= t, let f = frames.last(where: { abs($0.time - e.time) < 0.00001 }),
      f.position.distanceXZ(to: center) < 0.18
    else { return false }
  }
  guard let pos = frames.last(where: { abs($0.time - t) < 0.00001 })?.position else { return false }
  let key = Origin(x: pos.x, z: pos.z, pocket: pocket)
  if let cached = windows[key] { return cached }
  let raw = AngleSceneCalculator.defenseCleanWindow(pos, pocketIndex: pocket, stepDegrees: 0.025)
  let result = (raw["intervals"] as? [[String: Any]] ?? []).contains {
    ($0["rightDegrees"] as? Double ?? 0) > ($0["leftDegrees"] as? Double ?? 0)
  }
  windows[key] = result
  return result
}
func runBank(_ s: BankPracticeBankQuestion) throws -> ResultRow {
  let q = BankQuestion(id: UUID(), source: s)
  let old = try BankQuestionPreparer.solve(
    question: q, input: s.input, direction: s.direction.vector, surfaceY: y, profile: profile)
  let hits = hitCount(old)
  let rules = BankJudgement.evaluate(old, question: s, surfaceY: y)
  if hits == 0 {
    return ResultRow(
      s.id, rules.failures.isEmpty ? "clean" : "baselineFailure", hits: 0,
      reason: rules.failures.first?.rawValue)
  }
  guard eligible(old, pocket: s.pocket, bank: true) else {
    return ResultRow(s.id, "geometryReview", hits: hits, reason: rules.failures.first?.rawValue)
  }
  let angle = atan2(Double(s.direction.z), Double(s.direction.x))
  for dv: Float in [0, 0.05, -0.05, 0.1, -0.1, 0.2, -0.2] {
    var n = s.input
    n.velocity += dv
    guard n.isValid else { continue }
    for offset in [
      0.0, 0.01, -0.01, 0.02, -0.02, 0.04, -0.04, 0.07, -0.07, 0.11, -0.11, 0.18, -0.18, 0.28,
      -0.28, 0.4, -0.4, 0.7, -0.7,
    ] where dv != 0 || offset != 0 {
      let a = angle + offset * .pi / 180
      let d = SCNVector3(Float(cos(a)), 0, Float(sin(a)))
      guard
        let pred = try? BankQuestionPreparer.solve(
          question: q, input: n, direction: d, surfaceY: y, profile: profile),
        hitCount(pred) == 0, BankJudgement.evaluate(pred, question: s, surfaceY: y).failures.isEmpty
      else { continue }
      return candidate(s.id, hits, n, d)
    }
  }
  return ResultRow(s.id, "searchReview", hits: hits, reason: rules.failures.first?.rawValue)
}
func runK(_ l: KBallBankLayout, _ b: TrainingBankBoard, _ s: KBallBankQuestion) throws -> ResultRow
{
  let i = SeparationInput(spinX: Float(s.sx), spinY: Float(s.sy), velocity: Float(s.v))
  let old = try KBallQuestionPreparer.solve(
    layout: l, question: s, input: i, surfaceY: y, profile: profile, reference: true)
  let hits = hitCount(old)
  let fail = KBallJudgement.failure(
    old, pocket: b.pocketIndex, question: s, requiresReferenceTiming: true)
  if hits == 0 {
    return ResultRow(
      s.id, fail == nil ? "clean" : "baselineFailure", hits: 0, reason: fail?.rawValue)
  }
  guard eligible(old, pocket: b.pocketIndex) else {
    return ResultRow(s.id, "geometryReview", hits: hits, reason: fail?.rawValue)
  }
  for n in nearby(i) {
    guard
      let p = try? KBallQuestionPreparer.solve(
        layout: l, question: s, input: n, surfaceY: y, profile: profile),
      hitCount(p) == 0, let d = p.strikeDirection,
      KBallJudgement.failure(p, pocket: b.pocketIndex, question: s, requiresReferenceTiming: true)
        == nil
    else { continue }
    return candidate(s.id, hits, n, d)
  }
  return ResultRow(s.id, "searchReview", hits: hits, reason: fail?.rawValue)
}
func runTwo(
  _ b: TrainingBankBoard, _ cell: TwoBallParameterQuestion, _ r: TwoBallParameterRoute,
  _ pocket: Int, _ rank: Int, fine: Bool = false, options: [SeparationInput]? = nil
) throws -> ResultRow {
  let key = "\(b.id)#\(cell.id)/\(r.id)"
  let second = TrainingBankPoint(SCNVector3(Float(cell.p[0]), 0, Float(cell.p[1])))
  let old = try TwoBallQuestionPreparer.solve(
    board: b, second: second, input: r.input, surfaceY: y, profile: profile, direction: r.direction)
  let hits = hitCount(old)
  guard
    let base = try TwoBallQuestionPreparer.materialize(
      board: b, second: second, parameter: r, pocket: pocket, rank: rank, profile: profile)
  else { return ResultRow(key, "filtered", hits: hits) }
  var result = ResultRow(key, "clean", hits: hits)
  result.effort = base.source.executionDifficulty?.effort
  if hits == 0 { return result }
  guard eligible(old, pocket: b.pocketIndex) else {
    return ResultRow(key, "geometryReview", hits: hits)
  }
  for n in options ?? nearby(r.input, fine: fine) {
    guard
      let p = try? TwoBallQuestionPreparer.solve(
        board: b, second: second, input: n, surfaceY: y, profile: profile), hitCount(p) == 0,
      TwoBallQuestionPreparer.failure(p, pocket: b.pocketIndex) == nil, let d = p.strikeDirection,
      let score = try SeparationTrajectoryScore.evaluate(
        target: base.source.trajectory2mm.trajectory, actual: SeparationTrajectory.extract(p)),
      score.distanceCM <= 0.5
    else { continue }
    let route = TwoBallParameterRoute(
      id: r.id, v: Double(n.velocity), sx: Double(n.spinX), sy: Double(n.spinY), dir: [d.x, d.z],
      rails: r.rails)
    guard
      let made = try? TwoBallQuestionPreparer.materialize(
        board: b, second: second, parameter: route, pocket: pocket, rank: rank, profile: profile)
    else { continue }
    let q = TwoBallQuestion(id: UUID(), board: b, cellID: cell.id, second: second, routes: [base])
    guard let shot = try? TwoBallShot(question: q, input: n, prediction: p, surfaceY: y),
      shot.failure == nil, shot.continuationUnavailable == false
    else { continue }
    var row = candidate(key, hits, n, d)
    row.rms = score.distanceCM
    row.effort = made.source.executionDifficulty?.effort
    return row
  }
  return ResultRow(key, "searchReview", hits: hits)
}
struct SettingResult: Codable {
  var tried = 0
  var choices = [String: [ResultRow]]()
  var originalEfforts = [String: Double]()
}
func settingsInputs(_ r: TwoBallParameterRoute, axis: Int) -> [SeparationInput] {
  var result = [SeparationInput]()
  for h: Float in [0.01, 0.02, 0.04, 0.08, 0.15, 0.0025, 0.005, 0.015, 0.03] {
    for sign: Float in [1, -1] {
      var n = r.input
      if axis & 1 != 0 { n.spinY = h * sign }
      if axis & 2 != 0 { n.spinX = h * sign }
      if n.isValid && n.spinX*n.spinX + n.spinY*n.spinY <= 0.25 { result.append(n) }
      if axis == 3 {
        n.spinX = -n.spinX
        if n.isValid && n.spinX*n.spinX + n.spinY*n.spinY <= 0.25 { result.append(n) }
      }
    }
  }
  return result
}
func settingsLayout(_ store: TwoBallBankStore, _ i: Int, _ prior: URL) throws {
  let file = directory.appendingPathComponent("settings-\(i).json")
  if FileManager.default.fileExists(atPath:file.path) { return }
  let before = try JSONDecoder().decode([ResultRow].self, from:Data(contentsOf:prior.appendingPathComponent("two-\(i).json")))
  let previous = Dictionary(uniqueKeysWithValues:before.map { ($0.key,$0) })
  let layout = try store.layout(store.index.layouts[i])
  let board = try store.board(for:layout)
  let lookup = Dictionary(uniqueKeysWithValues:layout.routes.map { ($0.id,$0) })
  var result = SettingResult()
  for cell in layout.questions {
    var affected = false
    func key(_ id: Int) -> String { "\(board.id)#\(cell.id)/\(id)" }
    for (rank, pair) in cell.refs.enumerated() {
      let id=key(pair[0]), r=lookup[pair[0]]!
      guard previous[id]?.state == "searchReview" else { continue }
      var axes=[Int]()
      if r.sy==0 { axes.append(1) }
      if r.sx==0 && !r.rails.isEmpty { axes.append(2) }
      guard !axes.isEmpty else { continue }
      result.tried += 1
      if axes.count==2 { axes.append(3) }
      var answers=[ResultRow]()
      for axis in axes {
        if axis==3 && !answers.isEmpty { break }
        let row = try autoreleasepool {
          try runTwo(board,cell,r,pair[1],rank,options:settingsInputs(r,axis:axis))
        }
        guard row.hits==previous[id]?.hits && ["adjusted","searchReview"].contains(row.state) else {
          throw NSError(domain:"Setting replay diverged: "+id,code:axis)
        }
        if row.state=="adjusted" { answers.append(row) }
      }
      if !answers.isEmpty {
        result.choices[id]=answers
        affected=true
      }
    }
    if affected {
      let second = TrainingBankPoint(SCNVector3(Float(cell.p[0]),0,Float(cell.p[1])))
      for (rank,pair) in cell.refs.enumerated() {
        let id=key(pair[0])
        guard let baseline=previous[id], baseline.effort==nil,
              ["searchReview","geometryReview"].contains(baseline.state) else { continue }
        let route = try TwoBallQuestionPreparer.materialize(board:board,second:second,
              parameter:lookup[pair[0]]!,pocket:pair[1],rank:rank,profile:profile)
        guard let effort=route?.source.executionDifficulty?.effort else {
          throw NSError(domain:"Missing setting reference effort: "+id,code:1)
        }
        result.originalEfforts[id]=effort
      }
    }
  }
  try JSONEncoder().encode(result).write(to:file,options:.atomic)
}
func perRow(_ key: String, _ operation: () throws -> ResultRow) -> ResultRow {
  do { return try autoreleasepool(invoking: operation) } catch {
    return ResultRow(key, "baselineFailure", reason: String(describing: error))
  }
}
do {
  if family == "bank" {
    let questions = try BankPracticeBankStore.load().questions
    let size = 16
    for i in stride(from: lane, to: (questions.count + size - 1) / size, by: lanes) {
      try group(i) {
        questions[(i * size)..<min((i + 1) * size, questions.count)].map { s in
          perRow(s.id) { try runBank(s) }
        }
      }
    }
  } else if family == "kball" {
    let store = try KBallBankStore.load()
    for i in stride(from: lane, to: store.index.layouts.count, by: lanes) {
      try group(i) {
        let l = try store.layout(store.index.layouts[i])
        let b = try KBallQuestionPreparer.board(l)
        return l.questions.map { s in perRow(s.id) { try runK(l, b, s) } }
      }
    }
  } else if family == "two-settings" {
    let store=try TwoBallBankStore.load()
    let prior=URL(fileURLWithPath:args[6])
    for i in stride(from:lane,to:min(Int(args[5])!,store.index.layouts.count),by:lanes) {
      try autoreleasepool { try settingsLayout(store,i,prior) }
    }
  } else if family == "two" {
    let store = try TwoBallBankStore.load()
    let end = args.count > 5 ? min(Int(args[5])!, store.index.layouts.count) : store.index.layouts.count
    for i in stride(from: lane, to: end, by: lanes) {
      try group(i) {
        let l = try store.layout(store.index.layouts[i])
        let b = try store.board(for: l)
        let lookup = Dictionary(uniqueKeysWithValues: l.routes.map { ($0.id, $0) })
        let source = args.count > 6 ? URL(fileURLWithPath: args[6]).appendingPathComponent("two-\(i).json") : nil
        let previous: [String: ResultRow]? = try source.map { url in
          let rows = try JSONDecoder().decode([ResultRow].self, from: Data(contentsOf: url))
          return Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0) })
        }
        return try l.questions.flatMap { c in
          try c.refs.enumerated().map { rank, ref in
            let key = "\(b.id)#\(c.id)/\(ref[0])"
            if let previous {
              guard let original = previous[key] else { throw NSError(domain: "Missing first-pass " + key, code: 1) }
              if original.state != "searchReview" { return original }
              let refined = try runTwo(b,c,lookup[ref[0]]!,ref[1],rank,fine:true)
              guard refined.hits == original.hits, ["searchReview","adjusted"].contains(refined.state) else {
                throw NSError(domain:"First-pass replay diverged " + key,code:1)
              }
              return refined
            }
            return perRow(key) { try runTwo(b, c, lookup[ref[0]]!, ref[1], rank) }
          }
        }
      }
    }
  } else {
    fatalError("unknown family")
  }
} catch {
  fputs("audit failed: \(error)\n", stderr)
  exit(1)
}
