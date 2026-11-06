// Linked to the built app objects by link_trajectory_audit.py.
import Foundation
import SceneKit

let args = CommandLine.arguments
let entries = try DefenseBankStore.entries(.trajectory)
let lane = Int(args[1])!, lanes = Int(args[2])!
let profile = AccuracyTipSelector.renderedProfile()
var failures = [String:[String]](), routes = 0, completed = 0
let start = Date()
for (i, entry) in entries.enumerated() where i % lanes == lane {
    try autoreleasepool {
        let q = try DefenseBankStore.question(entry, mode: .trajectory)
        for ref in q.references {
            routes += 1
            do { _ = try DefenseQuestionPreparer.verified(source:q, reference:ref, surfaceY:0.8, profile:profile) }
            catch {
                failures[q.id, default: []].append(ref.id)
                print("rejected", q.id, ref.id, error.localizedDescription)
            }
        }
    }
    completed += 1
    if completed % 100 == 0 { print("audited", completed, routes); fflush(stdout) }
}
let report:[String:Any] = ["questions":completed,"routes":routes,"rejected":failures,"seconds":Date().timeIntervalSince(start),"digest":DefenseBankStore.trajectoryDigest]
try JSONSerialization.data(withJSONObject:report).write(to:URL(fileURLWithPath:args[3]),options:.atomic)
