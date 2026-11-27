// Appended to an exact copy of the serial search methods by run_masse_parallel.py.
// Each operation owns its counters, probes, predictions and engine instances.
    init(profile: [CueSection]) { cueProfile = profile }
    func solve(_ shape: [String: Any], params: [[Double]]) -> [String: Any] {
        var result = search(shape, params: params)
        result["diagnostics"] = diagnostics
        return result
    }
}

final class CB01MasseParallelTests: XCTestCase {
    func testParallelSearch() throws {
        let name = ProcessInfo.processInfo.environment["CB01_MASSE_REQUEST"] ?? "masse-request.json"
        let url = Bundle(for: Self.self).resourceURL!.appendingPathComponent(name)
        let request = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let shapes = try XCTUnwrap(request["shapes"] as? [[String: Any]])
        let params = try XCTUnwrap(request["parameters"] as? [[Double]])
        let workers = try XCTUnwrap(request["workers"] as? Int)
        XCTAssertTrue((1...8).contains(workers))
        let model = try XCTUnwrap(TableModelLoader.loadTable())
        let cue = try XCTUnwrap(model.cueStickNode)
        let profile = CueStick(modelCueStickNode: cue).clearanceProfile
        XCTAssertFalse(profile.isEmpty)
        // Prewarm SceneKit-backed geometry on the test thread before numeric work.
        _ = try PocketGeometryAsset.load()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = workers
        queue.qualityOfService = .userInitiated
        let lock = NSLock()
        var active = 0, peak = 0, completed = 0
        var failures = [String]()
        let start = ProcessInfo.processInfo.systemUptime
        for shape in shapes {
            queue.addOperation {
                autoreleasepool {
                    lock.lock(); active += 1; peak = max(peak, active); lock.unlock()
                    var result = CB01MasseSearchWorker(profile: profile).solve(shape, params: params)
                    result["runIdentity"] = request["runIdentity"]!
                    do {
                        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
                        // One writer prevents JSON records from different workers interleaving.
                        lock.lock()
                        print("CB01_MASSE " + String(decoding: data, as: UTF8.self)); fflush(stdout)
                        completed += 1; active -= 1
                        lock.unlock()
                    } catch {
                        lock.lock(); failures.append(String(describing: error)); active -= 1; lock.unlock()
                    }
                }
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "; "))
        XCTAssertEqual(completed, shapes.count)
        XCTAssertFalse(shapes.isEmpty)
        let stats: [String: Any] = ["workers": workers, "peakActive": peak, "completed": completed,
            "seconds": ProcessInfo.processInfo.systemUptime - start]
        let data = try JSONSerialization.data(withJSONObject: stats, options: [.sortedKeys])
        print("CB01_PARALLEL_STATS " + String(decoding: data, as: UTF8.self)); fflush(stdout)
    }
}
