import XCTest
import SceneKit
@testable import QiuJi

/// Geometry-only inventory. Deliberately has no ShotPredictor or tip/power search.
/// X/Z metres, Y up. P=aim point, O=object, G=ghost, C=cue.
private struct GridGeometry {
    typealias V = SIMD2<Double>
    let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
    let radius = Double(BallPhysics.radius)
    let epsilon = Double(SceneTrainingRailGeometry.contactRoundoff)
    func vector(_ p: SCNVector3) -> V { V(Double(p.x), Double(p.z)) }
    func scene(_ p: V) -> SCNVector3 { SCNVector3(Float(p.x), 0, Float(p.y)) }
    func dot(_ a: V, _ b: V) -> Double { a.x*b.x+a.y*b.y }
    func length(_ p: V) -> Double { sqrt(dot(p,p)) }
    func unit(_ p: V) -> V { p/length(p) }
    func rotate(_ p: V, _ degrees: Double) -> V {
        let a = degrees * .pi/180
        return V(p.x*cos(a)-p.y*sin(a), p.x*sin(a)+p.y*cos(a))
    }
    /// Sampling anchors, not the physical capture centres. Inset corners once;
    /// middle anchors stay on the midpoint of the long-side cushion baseline.
    func generationAnchor(_ pocket: Int) -> V {
        let center = vector(table.pockets[pocket].center)
        let halfLength = Double(TablePhysics.innerLength)/2
        let halfWidth = Double(TablePhysics.innerWidth)/2
        return V(pocket < 4 ? (center.x < 0 ? -1:1)*(halfLength-radius):0,
                 (center.y < 0 ? -1:1)*(halfWidth-(pocket < 4 ? radius:0)))
    }
    func arcContains(_ arc: CircularCushionSegment, _ point: V) -> Bool {
        // Same angular tolerance as the native collision primitive.
        arc.isAngleInRange(Float(atan2(point.y-Double(arc.center.z), point.x-Double(arc.center.x))))
    }
    func segmentDistance(_ p: V, _ a: V, _ b: V) -> Double {
        let d = b-a
        let t = max(0,min(1,dot(p-a,d)/dot(d,d)))
        return length(p-a-d*t)
    }
    func validPosition(_ p: V) -> Bool {
        // Broad enclosing box only; it does NOT close the actual pocket openings.
        let limitX = table.pockets.map { abs(Double($0.center.x))+Double($0.radius) }.max()!
        let limitZ = table.pockets.map { abs(Double($0.center.z))+Double($0.radius) }.max()!
        guard abs(p.x) <= limitX, abs(p.y) <= limitZ,
              !table.pockets.contains(where: { $0.containsCapture(scene(p)) }),
              EngineNumerics.planarIntrusions(position: scene(p), geometry: table)
                .allSatisfy({ Double($0.depth) <= epsilon }) else { return false }
        // All finite segments, including throat/back walls and segment endpoints.
        for line in table.linearCushions {
            if segmentDistance(p,vector(line.start),vector(line.end)) < radius-epsilon { return false }
        }
        for arc in table.circularCushions {
            let center = vector(arc.center), r = Double(arc.radius)
            if arcContains(arc,p), length(p-center) < r+radius-epsilon { return false }
            for angle in [arc.startAngle,arc.endAngle] {
                let end = center+r*V(cos(Double(angle)),sin(Double(angle)))
                if length(p-end) < radius-epsilon { return false }
            }
        }
        return true
    }
    /// First inward intersection with a circle for a unit ray. Tangency is legal.
    func circleHit(_ origin: V, _ direction: V, _ center: V, _ r: Double) -> Double? {
        let d = origin-center, b = dot(d,direction), c = dot(d,d)-r*r
        let discriminant = b*b-c
        guard discriminant > 1e-14 else { return nil }
        let t = -b-sqrt(discriminant)
        guard t >= -epsilon, dot(d+direction*max(0,t),direction) < -1e-10 else { return nil }
        return max(0,t)
    }
    func solidLimit(_ origin: V, _ direction: V, maximum: Double) -> Double {
        var limit = maximum
        for line in table.linearCushions {
            let a = vector(line.start), b = vector(line.end), edge = b-a, n = unit(V(-edge.y,edge.x))
            let offset = dot(origin-a,n), speed = dot(direction,n)
            if abs(speed) > 1e-12 {
                for sign in [-1.0,1.0] where sign*speed < 0 {
                    let t = (sign*radius-offset)/speed
                    if t >= -epsilon && t < limit {
                        let q = origin+direction*max(0,t), u = dot(q-a,edge)/dot(edge,edge)
                        if u >= 0 && u <= 1 { limit = max(0,t) }
                    }
                }
            }
            for endpoint in [a,b] {
                if let t = circleHit(origin,direction,endpoint,radius), t < limit { limit = t }
            }
        }
        for arc in table.circularCushions {
            let center = vector(arc.center), r = Double(arc.radius)
            if let t = circleHit(origin,direction,center,r+radius),
               t < limit, arcContains(arc,origin+direction*t) { limit = t }
            for angle in [arc.startAngle,arc.endAngle] {
                let end = center+r*V(cos(Double(angle)),sin(Double(angle)))
                if let t = circleHit(origin,direction,end,radius), t < limit { limit = t }
            }
        }
        return limit
    }
    func captureLimit(_ origin: V, _ direction: V, maximum: Double, excluding: Int? = nil) -> Double {
        var result = maximum
        for (i,pocket) in table.pockets.enumerated() where i != excluding {
            if let time = pocket.entryTime(position: scene(origin), velocity: scene(direction),
                acceleration: SCNVector3Zero, maxTime: Float(maximum)) {
                result = min(result,Double(time))
            }
        }
        return result
    }
    func cueLimit(_ ghost: V, _ backwards: V, maximum: Double = 1.8001) -> Double {
        min(solidLimit(ghost,backwards,maximum: maximum),
            captureLimit(ghost,backwards,maximum: maximum))
    }
    func cleanObjectPath(_ object: V, _ aim: V, pocket: Int) -> Bool {
        let direction = unit(aim-object)
        // P may be inside the playfield. Continue the ray beyond P through the
        // actual mouth; reaching P is neither a capture nor a stop condition.
        let extent = 2*hypot(Double(TablePhysics.innerLength),Double(TablePhysics.innerWidth))
        guard let entry = table.pockets[pocket].entryTime(position: scene(object), velocity: scene(direction),
            acceleration: SCNVector3Zero, maxTime: Float(extent)) else { return false }
        let t = Double(entry)
        return solidLimit(object,direction,maximum: t+0.01)+epsilon >= t
            && captureLimit(object,direction,maximum: t+0.01,excluding: pocket)+epsilon >= t
    }
    func railGap(_ p: V) -> Double {
        table.linearCushions.prefix(6).map { segmentDistance(p,vector($0.start),vector($0.end))-radius }.min()!
    }
}

final class TrainingGridInventoryTests: XCTestCase {
    private let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("output/accuracy-grid-anchor-v2-20261021")
    private struct Request: Codable { let sourceFingerprint: String }
    private struct Point: Codable {
        let x: Double; let z: Double
        init(_ v: SIMD2<Double>) { x = v.x; z = v.y }
    }
    private struct Sample: Codable {
        let pocket: Int; let angle: Int; let source: String
        let cue: Point; let target: Point; let ghost: Point; let aim: Point
        let cueDistance: Double; let objectDistance: Double; let gap: Double
        let clean: Bool
    }
    private struct Cell: Codable {
        let cell: TrainingInventoryCell
        var gridPlacement = 0; var gridClean = 0
        var boundaryPlacement = 0; var boundaryClean = 0
        var samples: [Sample] = []
    }
    private struct Target: Codable {
        let pocket: Int; let source: String; let bearing: Double; let pg: Double
        let object: Point; let ghost: Point; let aim: Point
        let clean: Bool
        // Bit i indexes inventory.distanceSamples (legacy: GC=(3+i)*0.1). Index j is signed cut=j-85.
        let masks: [UInt16]
        var cutPhaseBase: Int? = nil
    }
    private struct Geometry: Codable {
        struct Line: Codable { let start: Point; let end: Point; let normal: Point }
        struct Arc: Codable { let center: Point; let radius: Double; let start: Double; let end: Double }
        struct PocketShape: Codable { let center: Point; let radius: Double; let lip: [Point] }
        let radius: Double; let length: Double; let width: Double
        let lines: [Line]; let arcs: [Arc]; let pockets: [PocketShape]
    }
    private struct Inventory: Codable {
        let version: String; let sourceFingerprint: String; let seconds: Double
        let gridAngleDegrees: Int; let gridDistanceMetres: Double
        let rawGridCandidates: Int; let targetsConsidered: Int; let targetsRejected: Int
        let geometry: Geometry; let cells: [Cell]; let targets: [Target]
        let outsideClassification: Int; let mirrorPolicy: String; let solved: Bool
        var distanceSamples: [Double]? = nil
        var angleSampling: String? = nil
    }
    private func distanceBand(_ d: Double, cue: Bool) -> Int? {
        guard d >= (cue ? 0.30 : 0.25)-1e-6, d <= 1.80+1e-6 else { return nil }
        return d <= 0.60+1e-6 ? 0 : d <= 1.20+1e-6 ? 1 : 2
    }
    func testGeometryPredicates() {
        let g = GridGeometry()
        let hx = Double(TablePhysics.innerLength)/2, hz = Double(TablePhysics.innerWidth)/2
        for i in 0..<6 {
            let p = g.generationAnchor(i)
            XCTAssertEqual(abs(p.x),i < 4 ? hx-g.radius:0,accuracy:1e-10)
            XCTAssertEqual(abs(p.y),i < 4 ? hz-g.radius:hz,accuracy:1e-10)
            if i < 4 {
                let alongLongRail = p+GridGeometry.V(p.x < 0 ? 0.6:-0.6,0)
                XCTAssertTrue(g.validPosition(alongLongRail))
                XCTAssertEqual(g.railGap(alongLongRail),0,accuracy:g.epsilon)
                XCTAssertEqual(g.unit(p-alongLongRail).y,0,accuracy:1e-10)
            }
        }
        // A central diagonal passes the new corner P before actual capture.
        let origin = GridGeometry.V.zero, corner = g.generationAnchor(0)
        let direction = g.unit(corner-origin)
        let entry = g.table.pockets[0].entryTime(position:g.scene(origin),
            velocity:g.scene(direction),acceleration:SCNVector3Zero,maxTime:3)
        XCTAssertNotNil(entry)
        if let entry { XCTAssertGreaterThan(Double(entry),g.length(corner-origin)) }
        XCTAssertTrue(g.cleanObjectPath(origin,corner,pocket:0))
        XCTAssertTrue(g.validPosition(.zero))
        XCTAssertFalse(g.validPosition(.init(1.30,0)))
        for pocket in g.table.pockets { XCTAssertFalse(g.validPosition(g.vector(pocket.center))) }
        let frozen = GridGeometry.V(0.5,-0.635+g.radius)
        XCTAssertTrue(g.validPosition(frozen))
        XCTAssertLessThan(g.cueLimit(frozen,.init(0,-1)),1e-5)
        XCTAssertGreaterThan(g.cueLimit(frozen,.init(-1,0)),0.1)
        // A real middle opening must not be closed by an infinite rectangular rail.
        let nearMouth = GridGeometry.V(0,-0.60)
        XCTAssertTrue(g.validPosition(nearMouth))
        XCTAssertTrue(g.cleanObjectPath(nearMouth,g.vector(g.table.pockets[4].center),pocket:4))
        XCTAssertGreaterThan(g.solidLimit(nearMouth,.init(0,-1),maximum:0.2),0.02)
        // Analytic ray clipping must agree with actual native planar predicates.
        var count = 0
        for ix in -4...4 { for iz in -2...2 {
            let start = GridGeometry.V(Double(ix)*0.23,Double(iz)*0.22)
            guard g.validPosition(start) else { continue }
            for degree in stride(from:0,to:360,by:7) {
                let direction = g.rotate(.init(1,0),Double(degree))
                let limit = g.cueLimit(start,direction)
                for fraction in [0.25,0.75,0.999] {
                    XCTAssertTrue(g.validPosition(start+direction*(limit*fraction)))
                    count += 1
                }
            }
        }}
        print("GRID predicates verified \(count) clipped samples; no physics simulation")
    }
    func testProduceGeometryInventory() throws {
        try produceInventory(directory:directory,staggered:false)
    }
    func testProduceStaggeredGeometryInventory() throws {
        try produceInventory(directory:directory.deletingLastPathComponent()
            .appendingPathComponent("accuracy-grid-staggered-v3-20261021"),staggered:true)
    }
    private func produceInventory(directory: URL, staggered: Bool) throws {
        let requestURL = directory.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath:requestURL.path) else { throw XCTSkip("Explicit geometry inventory request required") }
        let request = try JSONDecoder().decode(Request.self,from:Data(contentsOf:requestURL))
        try FileManager.default.removeItem(at:requestURL)
        let started = Date(), g = GridGeometry()
        let step = staggered ? 0.15:0.1
        let distances: [Double]
        if staggered {
            distances = (0...10).map { (index: Int) -> Double in 0.30 + Double(index) * 0.15 }
        } else {
            distances = (3...18).map { (index: Int) -> Double in Double(index) * 0.1 }
        }
        var rawCandidates = 0
        var cells = Dictionary(uniqueKeysWithValues:TrainingInventoryCell.all.map { ($0.id,Cell(cell:$0)) })
        var targets: [Target] = []
        var considered = 0, rejected = 0, outside = 0
        var targetKeys: Set<String> = []
        func process(pocket: Int, source: String, aim: GridGeometry.V,
                     object: GridGeometry.V, ghost: GridGeometry.V, bearing: Double, pg: Double) {
            considered += 1
            guard g.validPosition(object),g.validPosition(ghost) else { rejected += 1; return }
            // Only eliminate exact duplicate target/contact configurations. Mirrors remain.
            let key = "\(pocket):\(Int((object.x*1e7).rounded())):\(Int((object.y*1e7).rounded())):\(Int((ghost.x*1e7).rounded())):\(Int((ghost.y*1e7).rounded()))"
            guard targetKeys.insert(key).inserted else { return }
            let base = g.unit(ghost-object), objectDistance = g.length(aim-object)
            let clean = g.cleanObjectPath(object,aim,pocket:pocket), gap = g.railGap(object)
            let rail = TrainingLayoutFeatures.railClass(gap)
            // Canonical phase from target geometry also applies to boundary supplements,
            // so exact target dedup never discards a second source's different phase.
            let local = GridGeometry.V(pocket<4 && aim.x>0 ? -base.x:base.x,aim.y>0 ? -base.y:base.y)
            let localBearing = atan2(local.y,local.x)*180/Double.pi
            let pgLayer = Int(((pg-0.30)/step).rounded())
            let phaseBase = ((pgLayer+Int(localBearing.rounded())/2)%2+2)%2
            var masks = [UInt16](repeating:0,count:171)
            for beta in -85...85 {
                let backwards = g.rotate(base,Double(beta)), limit = g.cueLimit(ghost,backwards)
                let angle = abs(beta)
                let ai = TrainingInventoryCell.angles.firstIndex(where: { $0.contains(angle) })!
                for (distanceIndex,length) in distances.enumerated() {
                    if staggered && angle != 0 && angle != 85 && angle%2 != (phaseBase+distanceIndex)%2 { continue }
                    // Strictly before capture/contact; tangent-to-rail rays remain available.
                    guard length < limit-g.epsilon else { continue }
                    let cue = ghost+backwards*length, cueDistance = g.length(cue-object)
                    guard cueDistance >= 2*g.radius-g.epsilon else { continue }
                    guard let ci = distanceBand(cueDistance,cue:true),
                          let oi = distanceBand(objectDistance,cue:false) else { outside += 1; continue }
                    let cell = TrainingInventoryCell(angleIndex:ai,pocketType:pocket<4 ? 0:1,cueIndex:ci,objectIndex:oi,railIndex:rail)
                    masks[beta+85] |= UInt16(1) << distanceIndex
                    if source == "grid" {
                        cells[cell.id]!.gridPlacement += 1
                        if clean { cells[cell.id]!.gridClean += 1 }
                    } else {
                        cells[cell.id]!.boundaryPlacement += 1
                        if clean { cells[cell.id]!.boundaryClean += 1 }
                    }
                    if cells[cell.id]!.samples.count < 3 {
                        cells[cell.id]!.samples.append(.init(pocket:pocket,angle:angle,source:source,
                            cue:.init(cue),target:.init(object),ghost:.init(ghost),aim:.init(aim),
                            cueDistance:cueDistance,objectDistance:objectDistance,gap:gap,clean:clean))
                    }
                }
            }
            targets.append(.init(pocket:pocket,source:source,bearing:bearing,pg:pg,
                object:.init(object),ghost:.init(ghost),aim:.init(aim),clean:clean,masks:masks,cutPhaseBase:staggered ? phaseBase:nil))
        }
        for pocket in 0..<6 {
            let p = g.generationAnchor(pocket)
            let maximum = pocket<4 ? 90:180
            for (pgIndex,pg) in distances.enumerated() {
                let degrees = (0...maximum).filter { !staggered || $0 == 0 || $0 == maximum || $0%2 == pgIndex%2 }
                for degree in degrees {
                    let a = Double(degree)*Double.pi/180
                    let local = GridGeometry.V(cos(a),sin(a))
                    let direction = GridGeometry.V(pocket<4 && p.x>0 ? -local.x:local.x,p.y>0 ? -local.y:local.y)
                    if staggered {
                        for ci in distances.indices {
                            rawCandidates += (-85...85).filter { abs($0)==0 || abs($0)==85 || abs($0)%2 == (pgIndex+degree/2+ci)%2 }.count
                        }
                    } else { rawCandidates += distances.count*171 }
                    let ghost = p+direction*pg, object = ghost-direction*(2*g.radius)
                    process(pocket:pocket,source:"grid",aim:p,object:object,ghost:ghost,bearing:Double(degree),pg:pg)
                }
            }
            // Boundary stratum: exactly frozen O at the configured steps along finite main
            // cushions (plus endpoints). Same anchor as the regular grid; PG and
            // bearing remain off-grid in this explicitly separate supplement.
            for rail in g.table.linearCushions.prefix(6) {
                let start = g.vector(rail.start), end = g.vector(rail.end), d = end-start, n = g.vector(rail.normal)
                let length = g.length(d)
                var distances = (0...Int(floor(length/step))).map { Double($0)*step }
                if abs((distances.last ?? 0)-length)>1e-8 { distances.append(length) }
                for s in distances {
                    let object = start+d*(s/length)+n*g.radius
                    guard g.validPosition(object) else { continue }
                    let aim = p
                    let backwards = g.unit(object-aim), ghost = object+backwards*(2*g.radius)
                    process(pocket:pocket,source:"frozen-boundary",aim:aim,object:object,ghost:ghost,
                        bearing:atan2(backwards.y,backwards.x)*180/Double.pi,pg:g.length(aim-ghost))
                }
            }
            print("GRID pocket=\(pocket) targets=\(targets.count) classified=\(cells.values.reduce(0){$0+$1.gridPlacement+$1.boundaryPlacement}) elapsed=\(Date().timeIntervalSince(started))")
        }
        let geometry = Geometry(radius:g.radius,length:Double(AngleSceneCalculator.innerLength),
            width:Double(AngleSceneCalculator.innerWidth),
            lines:g.table.linearCushions.map { .init(start:.init(g.vector($0.start)),end:.init(g.vector($0.end)),normal:.init(g.vector($0.normal))) },
            arcs:g.table.circularCushions.map { .init(center:.init(g.vector($0.center)),radius:Double($0.radius),start:Double($0.startAngle),end:Double($0.endAngle)) },
            pockets:g.table.pockets.map { .init(center:.init(g.vector($0.center)),radius:Double($0.radius),lip:$0.captureLip.map { .init($0) }) })
        let result = Inventory(version:staggered ? "pg-gc-grid-v3-15cm-2deg-staggered":"pg-gc-grid-v2-inset-corner-middle-baseline",sourceFingerprint:request.sourceFingerprint,
            seconds:Date().timeIntervalSince(started),gridAngleDegrees:staggered ? 2:1,gridDistanceMetres:step,
            rawGridCandidates:rawCandidates,targetsConsidered:considered,targetsRejected:rejected,
            geometry:geometry,cells:TrainingInventoryCell.all.map { cells[$0.id]! },targets:targets,
            outsideClassification:outside,mirrorPolicy:"retain; exact same coordinates only removed",solved:false,
            distanceSamples:distances,
            angleSampling:staggered ? "bearing parity=PG layer%2; abs(cut) parity=(round((PG-.30)/.15)+round(localBearing)/2+GC layer)%2; always retain bearing endpoints, cut 0 and +/-85; frozen rail step .15 plus endpoints":nil)
        let encoder = JSONEncoder();encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(result).write(to:directory.appendingPathComponent("inventory.json"),options:.atomic)
        XCTAssertEqual(result.cells.count,270)
        XCTAssertEqual(targets.reduce(0){$0+$1.masks.reduce(0){$0+$1.nonzeroBitCount}},
            result.cells.reduce(0){$0+$1.gridPlacement+$1.boundaryPlacement})
        print("GRID DONE placement=\(result.cells.reduce(0){$0+$1.gridPlacement+$1.boundaryPlacement}) clean=\(result.cells.reduce(0){$0+$1.gridClean+$1.boundaryClean}); no solutions produced")
    }

    /// Separate opt-in phase, only after the complete 270-cell geometry inventory.
    /// One representative per angle/rail stratum; not a success-rate estimate and
    /// not the later 500-per-cell production job.
    @MainActor func testValidateInventoryPilot() throws {
        let requestURL = directory.appendingPathComponent("validation-request.json")
        guard FileManager.default.fileExists(atPath:requestURL.path) else { throw XCTSkip("Explicit validation pilot required") }
        let request = try JSONDecoder().decode(Request.self,from:Data(contentsOf:requestURL))
        try FileManager.default.removeItem(at:requestURL)
        let inventory = try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:directory.appendingPathComponent("inventory.json")))
        guard inventory.sourceFingerprint == request.sourceFingerprint else {
            throw TrainingQuestionBank.Failure.invalid("Geometry inventory sources changed")
        }
        let model = try XCTUnwrap(TableModelLoader.loadTable(includeVisual:false))
        let profile = CueStick(modelCueStickNode:try XCTUnwrap(model.cueStickNode)).clearanceProfile
        var chosen: [(Cell,Sample)] = []
        for angle in 0..<5 { for rail in 0..<3 {
            let options = inventory.cells.filter { $0.cell.angleIndex == angle && $0.cell.railIndex == rail }
                .flatMap { cell in cell.samples.map { (cell,$0) } }
            let clean = options.filter { $0.1.clean }
            let pool = clean.isEmpty ? options:clean
            if !pool.isEmpty { chosen.append(pool[pool.count/2]) }
        }}
        struct Result: Codable {
            let cellID: String
            let referenceRouteClean: Bool
            let board: TrainingBankBoard
            let proof: TrainingPotProof?
            let status: String
        }
        func board(_ cell: Cell, _ s: Sample) throws -> TrainingBankBoard {
            let cx = Float(s.cue.x), cz = Float(s.cue.z), tx = Float(s.target.x), tz = Float(s.target.z)
            let incoming = SIMD2(s.ghost.x-s.cue.x,s.ghost.z-s.cue.z)
            let outgoing = SIMD2(s.aim.x-s.target.x,s.aim.z-s.target.z)
            let id = TrainingBankIdentity.hash("board-v1:\(cx.bitPattern):\(cz.bitPattern):\(tx.bitPattern):\(tz.bitPattern):\(s.pocket)")
            // Decode explicit geometry; the legacy random constructor recomputes
            // the aim point and would silently change this grid's P/G contract.
            let raw: [String:Any] = ["id":id,"seed":0,
                "cue":["x":cx,"z":cz],"target":["x":tx,"z":tz],
                "effectiveAim":["x":Float(s.aim.x),"z":Float(s.aim.z)],
                "pocketIndex":s.pocket,"angle":Double(s.angle),
                "side":incoming.x*outgoing.y-incoming.y*outgoing.x >= 0 ? 1:-1,
                "cueBand":cell.cell.cueBand.rawValue,"pocketBand":cell.cell.pocketBand.rawValue]
            return try JSONDecoder().decode(TrainingBankBoard.self,from:JSONSerialization.data(withJSONObject:raw))
        }
        func verify(_ b: TrainingBankBoard, _ tip: TrainingFixedTip, _ direction: SCNVector3, _ speed: Float) -> TrainingPotProof? {
            guard CueStrikeAccess(cue:SCNVector3(b.cue.x,BallPhysics.radius,b.cue.z),aim:direction,
                obstacles:[SCNVector3(b.target.x,BallPhysics.radius,b.target.z)],surfaceY:0,profile:profile)
                .isAvailable(spinX:Double(tip.x),spinY:Double(tip.y)) else { return nil }
            func shot(_ a: Float,_ v: Float) -> ShotPrediction {
                let d = direction.rotatedY(a * .pi/180)
                return ShotPredictor.simulateFree(cueBall:b.cue.vector,aimDir:d,velocity:speed+v,
                    spinX:tip.x,spinY:tip.y,surfaceY:0,
                    balls:[.init(name:ShotInput.targetBallName,position:b.target.vector)],recordedStrikeDirection:d)
            }
            let nominal = shot(0,0)
            guard nominal.hasFinalTableState,AccuracyShotJudgement.evaluate(nominal,pocketIndex:b.pocketIndex) == .success else { return nil }
            var samples: [TrainingToleranceSample] = []
            for a: Float in [-TrainingPotProof.angleRadius,0,TrainingPotProof.angleRadius] {
                for v: Float in [-TrainingPotProof.speedRadius,0,TrainingPotProof.speedRadius] {
                    let result = a == 0 && v == 0 ? nominal:shot(a,v)
                    let outcome = AccuracyShotJudgement.evaluate(result,pocketIndex:b.pocketIndex)
                    guard result.hasFinalTableState,outcome == .success else { return nil }
                    samples.append(.init(angleDeltaDegrees:a,velocityDelta:v,outcome:outcome))
                }
            }
            return .init(board:b,prediction:nominal,velocity:speed,tip:tip,samples:samples)
        }
        let fixtures = try chosen.map { (cell,sample) in (cell,sample,try board(cell,sample)) }
        let queue = OperationQueue();queue.maxConcurrentOperationCount = 4
        let lock = NSLock()
        var results: [Int:Result] = [:]
        for (index,fixture) in fixtures.enumerated() {
            queue.addOperation {
                let (cell,sample,b) = fixture
                let ghost = AngleSceneCalculator.ghostBallPosition(targetBall:b.target.vector,pocket:b.effectiveAim.vector,ballRadius:BallPhysics.radius)
                var found: TrainingPotProof?
                search: for tip in TrainingFixedTip.allCases {
                    for speed: Float in [1.5,2.5,3.5,0.8,5] {
                        if let p = verify(b,tip,(ghost-b.cue.vector).normalized(),speed) { found=p;break search }
                        let input = ShotInput(cueBall:b.cue.vector,targetBall:b.target.vector,pocketIndex:b.pocketIndex,
                            velocity:speed,spinX:tip.x,spinY:tip.y,surfaceY:0)
                        let suggestion = ShotPredictor.predictForPositionSolve(input,includePresentation:false)
                        if suggestion.feasible,let p = verify(b,tip,suggestion.aimDirection,speed) { found=p;break search }
                    }
                }
                let result = Result(cellID:cell.cell.id,referenceRouteClean:sample.clean,board:b,proof:found,
                    status:found == nil ? "no-stable-proof-in-finite-search":"verified-nine-point-proof")
                lock.lock();results[index]=result;lock.unlock()
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        let ordered = fixtures.indices.map { results[$0]! }
        struct Pilot: Codable {
            let sourceFingerprint: String
            let scope: String
            let results: [Result]
        }
        let encoder = JSONEncoder();encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(Pilot(sourceFingerprint:request.sourceFingerprint,
            scope:"One representative per populated angle/rail stratum, first stable tip only; not 500/cell and not a success-rate estimate",
            results:ordered)).write(to:directory.appendingPathComponent("validation-pilot.json"),options:.atomic)
        XCTAssertEqual(ordered.count,15)
        XCTAssertTrue(ordered.contains { $0.proof?.qualifiesForAccuracy == true })
        XCTAssertTrue(ordered.compactMap(\.proof).allSatisfy(\.qualifiesForAccuracy))
        print("GRID VALIDATION pilot boards=\(ordered.count) verified=\(ordered.filter{$0.proof != nil}.count); finite failures do not prove no solution")
    }
}
