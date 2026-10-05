// Research only: production recommendation, analytic aim and full-fidelity prediction.
final class CueScratchResearchTests: XCTestCase {
    private let root = "/Users/song/projects/13.billiard_trainer/build/cue-scratch-research-20261004"
    private let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
    private let y = BTTablePhysics.surfaceY
    private var radius: Float { BallPhysics.radius }
    struct Job: Codable {
        var id: String
        var layout: Int
        var cue: [Float]
        var object: [Float]
        var speed: Float
        var mode: String = "probe"
        var offset: Float? = nil
    }
    struct Config: Decodable {
        var batch: String
        var workers: Int
        var seconds: Double
        var start: Int
        var count: Int
        var mode: String
        var jobs: [Job]?
    }
    func point(_ a: [Float]) -> SCNVector3 { SCNVector3(a[0], y + radius, a[1]) }
    func vec(_ p: SCNVector3) -> [Float] { [p.x, p.z] }
    func halton(_ n: Int, _ b: Int) -> Float {
        var n = n + 1; var f: Float = 1; var v: Float = 0
        while n > 0 { f /= Float(b); v += f * Float(n % b); n /= b }; return v
    }
    func generated(_ n: Int, speed: Float, ordinal: Int) -> Job {
        let hx = TablePhysics.innerLength / 2 - radius - 0.001
        let hz = TablePhysics.innerWidth / 2 - radius - 0.001
        var c = [(-1 + 2 * halton(n + 104729, 2)) * hx, (-1 + 2 * halton(n + 104729, 3)) * hz]
        var o = [(-1 + 2 * halton(n + 104729, 5)) * hx, (-1 + 2 * halton(n + 104729, 7)) * hz]
        // 60% full table, 20% near rail, 20% close balls; all six pockets remain free to recommendation.
        if n % 10 == 6 || n % 10 == 7 {
            let gap = radius * 2 * halton(n, 11)
            if n % 10 == 6 { o[1] = (n % 20 < 10 ? -1 : 1) * (hz - gap) }
            else { c[0] = (n % 20 < 10 ? -1 : 1) * (hx - gap) }
        } else if n % 10 >= 8 {
            let angle = halton(n, 13) * 2 * Float.pi
            let d = 2 * radius + 0.001 + 0.22 * halton(n, 17)
            c = [o[0] + d * cos(angle), o[1] + d * sin(angle)]
        }
        return Job(id: "g\(n)-\(ordinal)", layout: n, cue: c, object: o, speed: speed)
    }
    func legal(_ p: SCNVector3, geometry: TableGeometry) -> Bool {
        guard abs(p.x) <= TablePhysics.innerLength/2-radius,
              abs(p.z) <= TablePhysics.innerWidth/2-radius,
              !geometry.pockets.contains(where: { $0.containsCapture(p) }) else { return false }
        for segment in geometry.linearCushions {
            if ShotPredictor.segmentPointDistanceXZ(a: segment.start, b: segment.end, p: p) < radius - 0.000001 { return false }
        }
        // Restrictive safety margin around rounded jaws. This excludes some legal boundary placements.
        for arc in geometry.circularCushions {
            if hypot(p.x-arc.center.x,p.z-arc.center.z) < radius + arc.radius { return false }
        }
        return true
    }
    func classify(_ prediction: ShotPrediction) -> [String: Any] {
        var timeline: [[String: Any]] = []
        var contacts = 0; var before = 0; var cueJaw = 0; var objectJaw = 0; var objectRail = 0
        var rails: [Int] = []; var cuePocket = ""; var objectPocket = ""
        var uncertain = false; var previousRailTime: Float = -100
        for e in prediction.events {
            var row: [String: Any] = ["t": e.time]
            switch e.kind {
            case let .ballBall(a,b):
                contacts += 1; row["kind"] = "ball"; row["a"] = a; row["b"] = b
            case let .ballCushion(ball):
                row["kind"] = "rail"; row["ball"] = ball
                let i = e.cushionIndex ?? -1; row["segment"] = i
                if let normal = e.contactNormal { row["normal"] = vec(normal) }
                if let p = prediction.recorder?.stateAt(ballName: ball, time: e.time)?.position { row["p"] = vec(p) }
                if i < 0 { uncertain = true }
                if ball == ShotInput.cueBallName && cuePocket.isEmpty {
                    if contacts == 0 { before += 1 }
                    else if i >= 0 && i < 6 {
                        if e.time - previousRailTime < 0.0001 { uncertain = true }
                        rails.append(i); previousRailTime = e.time
                    } else { cueJaw += 1 }
                }
                if ball == ShotInput.targetBallName && objectPocket.isEmpty {
                    if i >= 0 && i < 6 { objectRail += 1 } else { objectJaw += 1 }
                }
            case let .pocket(ball,pocket):
                row["kind"] = "pocket"; row["ball"] = ball; row["pocket"] = pocket
                if ball == ShotInput.cueBallName { cuePocket = pocket }
                if ball == ShotInput.targetBallName { objectPocket = pocket }
            }
            timeline.append(row)
        }
        let clean = prediction.hasResolvedSearchState && prediction.objectPocketed && !cuePocket.isEmpty && contacts == 1 && before == 0 && cueJaw == 0 && objectJaw == 0 && objectRail == 0 && rails.count <= 3 && !uncertain && (prediction.cutAngleDeg ?? 0) > 1
        return ["events": timeline, "contacts": contacts, "preRails": before, "cueJaws": cueJaw,
                "objectJaws": objectJaw, "objectRails": objectRail, "rails": rails,
                "cuePocket": cuePocket, "objectPocket": objectPocket, "uncertain": uncertain,
                "hit": clean, "resolved": prediction.hasResolvedSearchState,
                "targetPot": prediction.objectPocketed, "cuePot": prediction.cuePocketed,
                "termination": String(describing: prediction.termination), "duration": prediction.duration]
    }
    func run(_ job: Job, trace: Bool = false) throws -> [String: Any] {
        let start = ProcessInfo.processInfo.systemUptime
        let c = point(job.cue), o = point(job.object)
        var row = try JSONSerialization.jsonObject(with: JSONEncoder().encode(job)) as! [String: Any]
        guard legal(c, geometry: geometry), legal(o, geometry: geometry), hypot(c.x-o.x,c.z-o.z) > 2*radius+0.000001 else { row["reject"] = "layout"; return row }
        let candidates = (0..<6).compactMap { AngleSceneCalculator.dailyPocketCandidate(cue: c, target: o, targetKey: "object", pocketIndex: $0, obstacles: [], surfaceY: y) }
        guard let rec = AngleSceneCalculator.easiestDailyPocket(candidates) else { row["reject"] = "recommendation"; return row }
        row["pocket"] = rec.pocketIndex; row["score"] = rec.score; row["cut"] = rec.cutDegrees
        let input = ShotInput(cueBall: c, targetBall: o, pocketIndex: rec.pocketIndex, velocity: job.speed, spinX: 0, spinY: 0, surfaceY: y)
        var seed = ShotPrediction()
        guard let context = ShotPredictor.prepareAim(input, into: &seed) else { row["reject"] = "aimGeometry"; return row }
        let offset = job.offset ?? ShotPredictor.positionAimOffset(input: input, context: context)
        let full = job.mode == "full"
        let p = ShotPredictor.predictForPositionSolve(input, aimOffset: full ? nil : offset, maxEvents: 1000, maxTime: 30,
                                                    includePresentation: full || trace)
        row.merge(classify(p), uniquingKeysWith: { _, new in new })
        row["offset"] = p.aimOffsetUsed; row["aim"] = vec(p.aimDirection)
        row["elapsed"] = ProcessInfo.processInfo.systemUptime - start
        row["aimPolicy"] = full ? "production-full" : "production-first-offset"
        // Geometry clearance flag, not a claim of real cue accessibility.
        row["cueClearance"] = min(TablePhysics.innerLength/2-abs(c.x), TablePhysics.innerWidth/2-abs(c.z))-radius
        var near: Float = 10
        if p.objectPocketed, let recorder = p.recorder {
            for frame in recorder.framesByBallName[ShotInput.cueBallName] ?? [] where frame.time > 0 && frame.state != .pocketed {
                for pocket in geometry.pockets {
                    if hypot(frame.position.x-pocket.center.x,frame.position.z-pocket.center.z) > 0.25 { continue }
                    let lip = pocket.captureLip
                    for i in lip.indices {
                        let a = lip[i], b = lip[(i+1)%lip.count]
                        let d = ShotPredictor.segmentPointDistanceXZ(a: SCNVector3(Float(a.x),y,Float(a.y)), b: SCNVector3(Float(b.x),y,Float(b.y)), p: frame.position)
                        near = min(near, d)
                    }
                }
            }
        }
        row["nearLip"] = near // Heuristic only; does not establish a legal approach channel.
        if trace || (row["hit"] as? Bool == true) {
            var paths: [String: [[Float]]] = [:]
            if let recorder = p.recorder {
                for name in [ShotInput.cueBallName, ShotInput.targetBallName] {
                    let entry = recorder.pocketEntries.first { $0.ball.name == name }
                    let end = entry?.time ?? Float.greatestFiniteMagnitude
                    paths[name] = (recorder.framesByBallName[name] ?? []).filter { $0.time <= end && $0.state != .pocketed }.sorted { $0.time < $1.time }.map { [$0.time,$0.position.x,$0.position.z,$0.velocity.x,$0.velocity.z] }
                    if let entry { paths[name,default:[]].append([entry.time,entry.ball.position.x,entry.ball.position.z,entry.ball.velocity.x,entry.ball.velocity.z]) }
                }
            }
            row["paths"] = paths
        }
        return row
    }
    func canonical(_ row: [String: Any]) throws -> Data {
        let ignored: Set<String> = ["elapsed", "paths", "mode", "aimPolicy", "id"]
        return try JSONSerialization.data(withJSONObject: row.filter { !ignored.contains($0.key) }, options: [.sortedKeys])
    }
    func test_runResearchBatch() throws {
        executionTimeAllowance = 1900
        let cfg = try JSONDecoder().decode(Config.self, from: Data(contentsOf: URL(fileURLWithPath: root + "/config.json")))
        let dest = root + "/" + cfg.batch + ".jsonl"
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest))
        FileManager.default.createFile(atPath: dest, contents: nil)
        let file = try FileHandle(forWritingTo: URL(fileURLWithPath: dest))
        defer { try? file.close() }
        let lock = NSLock(); var next = 0; var count = 0; var failure: Error?
        let start = ProcessInfo.processInfo.systemUptime
        let deadline = start + cfg.seconds
        let q = OperationQueue(); q.maxConcurrentOperationCount = cfg.workers
        func emit(_ row: [String: Any]) throws {
            var d = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]); d.append(10)
            lock.lock(); defer { lock.unlock() }; try file.write(contentsOf: d); count += 1
        }
        for _ in 0..<cfg.workers {
            q.addOperation {
                while ProcessInfo.processInfo.systemUptime < deadline {
                    lock.lock(); let i = next; next += 1; let failed = failure != nil; lock.unlock()
                    if failed || i >= cfg.count { break }
                    do {
                        try autoreleasepool {
                            if let jobs = cfg.jobs { try emit(self.run(jobs[i], trace: cfg.mode == "verify")) }
                            else {
                                let n = cfg.start + i
                                let speeds: [Float] = n % 5 == 0 ? [0.5,0.8,6.8,8] : [1.1,2,3.3,5.7]
                                for (j,v) in speeds.enumerated() {
                                    if ProcessInfo.processInfo.systemUptime >= deadline { break }
                                    try emit(self.run(self.generated(n, speed: v, ordinal: j)))
                                }
                            }
                        }
                    } catch { lock.lock(); if failure == nil { failure = error }; lock.unlock(); break }
                }
            }
        }
        q.waitUntilAllOperationsAreFinished()
        try file.synchronize()
        if let failure { throw failure }
        let summary: [String:Any] = ["batch":cfg.batch,"rows":count,"claimed":min(next,cfg.count),"seconds":ProcessInfo.processInfo.systemUptime-start,"workers":cfg.workers,"finished":true]
        try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath: root+"/"+cfg.batch+"-summary.json"), options: .atomic)
        print("[SCRATCH-SUMMARY]", summary)
    }
    func test_parallelAndPresentationParity() throws {
        var jobs: [Job] = []
        for n in 1...20 { for (j,v) in [Float(1.1),3.3,8].enumerated() { jobs.append(generated(n, speed:v, ordinal:j)) } }
        let serial = try jobs.map { job in try autoreleasepool { try run(job) } }
        var timings: [[String:Any]] = []
        for width in [1,6,8,12] {
            let q = OperationQueue(); q.maxConcurrentOperationCount = width
            let lock = NSLock(); var rows = Array<[String:Any]?>(repeating:nil,count:jobs.count); var failure: Error?
            let t = ProcessInfo.processInfo.systemUptime
            for i in jobs.indices { q.addOperation { do { let r = try autoreleasepool { try self.run(jobs[i]) }; lock.lock(); rows[i] = r; lock.unlock() } catch { lock.lock(); failure = error; lock.unlock() } } }
            q.waitUntilAllOperationsAreFinished(); if let failure { throw failure }
            for i in jobs.indices { XCTAssertEqual(try canonical(serial[i]), try canonical(XCTUnwrap(rows[i])), "width=\(width) case=\(i)") }
            timings.append(["workers":width,"trials":jobs.count,"seconds":ProcessInfo.processInfo.systemUptime-t])
        }
        // Fixed offset replay must preserve terminal outcomes and raw contact IDs.
        for i in jobs.indices where serial[i]["offset"] != nil {
            var job = jobs[i]; job.offset = (serial[i]["offset"] as! NSNumber).floatValue
            let full = try run(job, trace:true)
            for key in ["hit","rails","cuePocket","objectPocket","contacts","preRails","cueJaws","objectJaws","objectRails"] {
                let a = try JSONSerialization.data(withJSONObject:["v":serial[i][key]!],options:[.sortedKeys])
                let b = try JSONSerialization.data(withJSONObject:["v":full[key]!],options:[.sortedKeys])
                XCTAssertEqual(a,b,"presentation parity: \(key)")
            }
        }
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY:y)
        let geo: [String:Any] = ["length":TablePhysics.innerLength,"width":TablePhysics.innerWidth,"radius":radius,
            "rails":geometry.linearCushions.enumerated().map { ["id":$0.offset,"a":vec($0.element.start),"b":vec($0.element.end)] as [String:Any] },
            "pockets":geometry.pockets.map { ["id":$0.id,"center":vec($0.center),"radius":$0.radius,"lip":$0.captureLip.map{[$0.x,$0.y]}] as [String:Any] }]
        try JSONSerialization.data(withJSONObject:geo,options:[.sortedKeys]).write(to:URL(fileURLWithPath:root+"/geometry.json"))
        try JSONSerialization.data(withJSONObject:timings,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:root+"/preflight-timings.json"))
        print("[SCRATCH-PARITY]",timings)
    }
}
