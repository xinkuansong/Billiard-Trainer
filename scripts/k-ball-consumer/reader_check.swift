// Compile this with the production KBallBankStore.swift; no replacement decoder.
import Foundation

@main
struct ReaderCheck {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let bank = try KBallBankStore(root: root)
        var count = 0, ids = Set<String>(), layouts = Set<String>()
        var rails: [Int: Int] = [:], timings: [KBallTiming: Int] = [:], grades: [Int: Int] = [:]
        var thirdMiddle = 0
        let thirdMiddleFilter = KBallBankFilter(rail: 3, pocket: .middle)
        for entry in bank.index.layouts {
            let layout = try bank.layout(entry)
            precondition(layouts.insert(layout.id).inserted)
            for q in layout.questions {
                precondition(ids.insert(q.id).inserted)
                precondition(KBallBankFilter().accepts(q, pocketIndex: layout.board.pocket))
                count += 1; rails[q.rail, default: 0] += 1
                timings[q.timing, default: 0] += 1; grades[q.grade, default: 0] += 1
                if thirdMiddleFilter.accepts(q, pocketIndex: layout.board.pocket) { thirdMiddle += 1 }
            }
            precondition(bank.decodedShardCount <= 2)
        }
        precondition(count == bank.index.counts.questions && count == 11458)
        precondition(layouts.count == 4905)
        precondition(rails == [1:3872, 2:7242, 3:344])
        precondition(timings == [.before:8070, .after:3388])
        precondition(grades == [1:4717, 2:5255, 3:1486])
        precondition(thirdMiddle > 0)
        bank.clearCache(); precondition(bank.decodedShardCount == 0)
        let first = try bank.layout(bank.index.layouts[0])
        let data = try JSONEncoder().encode(first)
        let roundTrip = try JSONDecoder().decode(KBallBankLayout.self, from: data)
        let roundTripData = try JSONEncoder().encode(roundTrip)
        precondition(!roundTripData.isEmpty)
        // Corruption is rejected by the actual validation function.
        let original = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        func reject(_ change: (inout [String: Any]) -> Void) throws {
            var modified = original
            change(&modified)
            let raw = try JSONSerialization.data(withJSONObject: modified)
            var rejected = false
            do {
                let row = try JSONDecoder().decode(KBallBankLayout.self, from: raw)
                try KBallBankStore.validate(row, radius: bank.index.geometry.radius)
            } catch { rejected = true }
            precondition(rejected, "Malformed row was accepted")
        }
        try reject { $0["questions"] = [] }
        try reject {
            var board = $0["board"] as! [String: Any]; board["angle"] = 51; $0["board"] = board
        }
        try reject {
            var q = $0["questions"] as! [[String: Any]]; q[0]["rail"] = 0; $0["questions"] = q
        }
        try reject {
            var q = $0["questions"] as! [[String: Any]]; q[0]["timing"] = "unknown"; $0["questions"] = q
        }
        try reject {
            var q = $0["questions"] as! [[String: Any]]; q[0]["dir"] = [0, 0]; $0["questions"] = q
        }
        try reject {
            var q = $0["questions"] as! [[String: Any]]; q[0]["centerRailDistance"] = 0.11; $0["questions"] = q
        }
        try reject {
            var q = $0["questions"] as! [[String: Any]]; q[0]["railsBeforeK"] = [0,1,2,3]; $0["questions"] = q
        }
        try reject {
            var q = $0["questions"] as! [[String: Any]]; q.append(q[0]); $0["questions"] = q
        }
        try reject {
            var q = $0["questions"] as! [[String: Any]]
            q[0]["b"] = ($0["board"] as! [String: Any])["cue"]; $0["questions"] = q
        }
        print("PASS: production reader decoded \(count) questions / \(layouts.count) layouts; all classifications, combined filters, two-shard cache and 9 malformed-row cases")
    }
}
