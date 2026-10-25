// Port of the validated 2026-10-22 research. Inputs are physical X/Z centimetres.
import Foundation
enum SeparationTrajectoryMetric {
    typealias Point = SIMD2<Double>
    enum Failure: Error { case invalidInput, invalidAnchor }
    struct Distances {
        let frechetCM: Double
        let meanDTWCM: Double
        let chamferCM: Double
        let matchingLength: Int
    }
    static func distance(_ a: Point, _ b: Point) -> Double { hypot(a.x-b.x,a.y-b.y) }
    static func validate(_ p: [Point]) throws {
        guard !p.isEmpty, p.allSatisfy({$0.x.isFinite && $0.y.isFinite}) else {throw Failure.invalidInput}
    }
    // Inputs already in the same physical centimetre coordinate frame.
    static func compare(_ p: [Point], _ q: [Point]) throws -> Distances {
        try validate(p);try validate(q)
        var previousF = Array(repeating: Double.infinity, count:q.count+1)
        var previousD = previousF
        var previousL = Array(repeating:0,count:q.count+1)
        previousF[0]=0;previousD[0]=0
        var closestQ=Array(repeating:Double.infinity,count:q.count),sumP=0.0
        for a in p {
            try Task.checkCancellation()
            var f=Array(repeating:Double.infinity,count:q.count+1)
            var d=f,l=Array(repeating:0,count:q.count+1),closestP=Double.infinity
            for j in q.indices {
                let cost=distance(a,q[j]),k=j+1
                closestP=min(closestP,cost);closestQ[j]=min(closestQ[j],cost)
                f[k]=max(cost,min(previousF[k],previousF[k-1],f[k-1]))
                // Tie order: up, diagonal, left; equal cost prefers fewer matches.
                var best = (previousD[k], previousL[k])
                let diagonal = (previousD[k-1], previousL[k-1])
                if diagonal.0 < best.0 || (diagonal.0 == best.0 && diagonal.1 < best.1) { best = diagonal }
                let left = (d[k-1], l[k-1])
                if left.0 < best.0 || (left.0 == best.0 && left.1 < best.1) { best = left }
                d[k]=best.0+cost;l[k]=best.1+1
            }
            previousF=f;previousD=d;previousL=l;sumP+=closestP
        }
        return Distances(frechetCM:previousF.last!,meanDTWCM:previousD.last!/Double(previousL.last!),chamferCM:0.5*(sumP/Double(p.count)+closestQ.reduce(0,+)/Double(q.count)),matchingLength:previousL.last!)
    }
    // Keep endpoints and mandatory event vertices; the returned count may exceed budget.
    static func resample(_ input:[Point],budget:Int=512,mandatory:Set<Int>=[]) throws -> [Point] {
        try validate(input)
        guard budget>=2 else {throw Failure.invalidInput}
        guard mandatory.allSatisfy({input.indices.contains($0)}) else {throw Failure.invalidAnchor}
        var lengths=[0.0]
        for i in 1..<input.count {lengths.append(lengths.last!+distance(input[i-1],input[i]))}
        let total=lengths.last!
        if total==0 {return [input[0]]}
        let locations=Set((0..<budget).map{total*Double($0)/Double(budget-1)}+mandatory.map{lengths[$0]}).sorted()
        var index=0,result:[Point]=[]
        for s in locations {
            while index+1<input.count && lengths[index+1]<=s {index+=1}
            if index==input.count-1 {result.append(input[index]);continue}
            let u=(s-lengths[index])/(lengths[index+1]-lengths[index])
            result.append(input[index]+(input[index+1]-input[index])*u)
        }
        return result
    }
    // Exploratory scale, not a validated training grade or probability.
    static func score(distanceCM:Double,halfScoreDistanceCM:Double) throws -> Double {
        guard distanceCM.isFinite,distanceCM>=0,halfScoreDistanceCM.isFinite,halfScoreDistanceCM>0 else {throw Failure.invalidInput}
        return 100*exp(-log(2)*distanceCM/halfScoreDistanceCM)
    }
}

/// Full, order-preserving arc-length RMS distance. Coordinates are physical X/Z centimetres.
/// The 1 cm midpoint grid is the same numerical approximation reviewed in the research atlas.
enum SeparationArcRMSMetric {
    typealias Point = SIMD2<Double>
    struct Cell { let midpoint: Point; let end: Point; let length: Double }
    struct Path { let start: Point; let cells: [Cell]; let length: Double }

    static func sample(_ points: [Point]) throws -> Path {
        try Task.checkCancellation()
        try SeparationTrajectoryMetric.validate(points)
        var lengths = [0.0]
        for i in 1..<points.count {
            lengths.append(lengths.last! + SeparationTrajectoryMetric.distance(points[i - 1], points[i]))
        }
        let total = lengths.last!
        guard total.isFinite, ceil(total) < Double(Int.max) else { throw SeparationTrajectoryMetric.Failure.invalidInput }
        if total == 0 { return .init(start: points[0], cells: [], length: 0) }
        var cursor = 0
        func at(_ s: Double) -> Point {
            while cursor + 1 < points.count && lengths[cursor + 1] <= s { cursor += 1 }
            if cursor == points.count - 1 { return points[cursor] }
            let u = (s - lengths[cursor]) / (lengths[cursor + 1] - lengths[cursor])
            return points[cursor] + (points[cursor + 1] - points[cursor]) * u
        }
        var cells: [Cell] = []
        cells.reserveCapacity(Int(ceil(total)))
        // Integer-indexed sampling avoids a non-advancing floating-point loop.
        for i in 0..<Int(ceil(total)) {
            try Task.checkCancellation()
            let lo = Double(i), hi = min(lo + 1, total)
            cells.append(.init(midpoint: at((lo + hi) / 2), end: at(hi), length: hi - lo))
        }
        return .init(start: points[0], cells: cells, length: total)
    }

    static func distance(_ a: Path, _ b: Path) throws -> Double {
        try Task.checkCancellation()
        if a.length + b.length == 0 { return SeparationTrajectoryMetric.distance(a.start, b.start) }
        func squared(_ p: Point, _ q: Point) -> Double {
            let d = p - q
            return d.x * d.x + d.y * d.y
        }
        var previous = Array(repeating: 0.0, count: b.cells.count + 1), current = previous
        for j in b.cells.indices {
            previous[j + 1] = previous[j] + b.cells[j].length * squared(a.start, b.cells[j].midpoint)
        }
        for p in a.cells {
            try Task.checkCancellation()
            current[0] = previous[0] + p.length * squared(p.midpoint, b.start)
            for j in b.cells.indices {
                let q = b.cells[j]
                current[j + 1] = min(
                    previous[j + 1] + p.length * squared(p.midpoint, q.end),
                    current[j] + q.length * squared(p.end, q.midpoint),
                    previous[j] + (p.length + q.length) * squared(p.midpoint, q.midpoint))
            }
            swap(&previous, &current)
        }
        return sqrt(previous.last! / (a.length + b.length))
    }
}

/// Immutable versioned score; legacy snapshots retain their original distance and grade.
struct SeparationTrajectoryScore: Codable, Equatable {
    static let algorithm = "arc1cm-rms-p2-t20-potgate-v3"
    static let legacyAlgorithm = "arc512-dtw70-frechet30-t20-potgate-v2"
    enum ZeroReason: String, Codable { case cuePocketed, targetNotPotted }
    var zeroReason: ZeroReason? = nil
    let version: String
    let rmsDistanceCM: Double?
    // Only legacy scores carry DTW/Fréchet diagnostics. New scores do not compute them.
    let meanDTWCM: Double?
    let frechetCM: Double?
    let matchingLength: Int?
    let targetSampleCount: Int
    let actualSampleCount: Int
    var distanceCM: Double {
        version == Self.algorithm ? rmsDistanceCM! : 0.7 * meanDTWCM! + 0.3 * frechetCM!
    }
    var value: Double { zeroReason != nil ? 0 : 100 * exp2(-distanceCM / 20) }
    var formatted: String { String(format: "%.1f", value) }

    init(rmsDistanceCM: Double, targetSampleCount: Int, actualSampleCount: Int, zeroReason: ZeroReason? = nil) {
        version = Self.algorithm; self.rmsDistanceCM = rmsDistanceCM; self.zeroReason = zeroReason
        meanDTWCM = nil; frechetCM = nil; matchingLength = nil
        self.targetSampleCount = targetSampleCount; self.actualSampleCount = actualSampleCount
    }

    init(version: String, meanDTWCM: Double, frechetCM: Double, matchingLength: Int,
         targetSampleCount: Int, actualSampleCount: Int) {
        precondition(version != Self.algorithm, "RMS scores require an RMS distance")
        self.version = version; self.meanDTWCM = meanDTWCM; self.frechetCM = frechetCM
        self.matchingLength = matchingLength; rmsDistanceCM = nil
        self.targetSampleCount = targetSampleCount; self.actualSampleCount = actualSampleCount
    }

    private enum CodingKeys: String, CodingKey {
        case zeroReason, version, rmsDistanceCM, meanDTWCM, frechetCM, matchingLength, targetSampleCount, actualSampleCount
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        zeroReason = try c.decodeIfPresent(ZeroReason.self, forKey: .zeroReason)
        targetSampleCount = try c.decode(Int.self, forKey: .targetSampleCount)
        actualSampleCount = try c.decode(Int.self, forKey: .actualSampleCount)
        if version == Self.algorithm {
            rmsDistanceCM = try c.decode(Double.self, forKey: .rmsDistanceCM)
            meanDTWCM = nil; frechetCM = nil; matchingLength = nil
        } else {
            rmsDistanceCM = nil
            meanDTWCM = try c.decode(Double.self, forKey: .meanDTWCM)
            frechetCM = try c.decode(Double.self, forKey: .frechetCM)
            matchingLength = try c.decode(Int.self, forKey: .matchingLength)
        }
        guard distanceCM.isFinite, distanceCM >= 0, targetSampleCount >= 0, actualSampleCount >= 0 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid trajectory score"))
        }
    }

    static func evaluate(target: [SeparationTrajectory.Point], actual: [SeparationTrajectory.Point],
                         cuePocketed: Bool = false, targetPotted: Bool = true) throws -> Self? {
        try Task.checkCancellation()
        if cuePocketed || !targetPotted {
            // No distance comparison is required for a foul, including a scratch without contact.
            // Zero sample counts distinguish these unused distance fields from measured similarity.
            return .init(rmsDistanceCM: 0, targetSampleCount: 0, actualSampleCount: 0,
                         zeroReason: cuePocketed ? .cuePocketed : .targetNotPotted)
        }
        // No contact is not a stationary post-contact path.
        guard !target.isEmpty, !actual.isEmpty else { return nil }
        func sampled(_ line: [SeparationTrajectory.Point]) throws -> SeparationArcRMSMetric.Path {
            let points = line.map { SIMD2(Double($0.position.x) * 100, Double($0.position.z) * 100) }
            // Interpolate on the full original polyline, including unannotated legacy corners.
            return try SeparationArcRMSMetric.sample(points)
        }
        let p = try sampled(target), q = try sampled(actual)
        let distance = try SeparationArcRMSMetric.distance(p, q)
        return .init(rmsDistanceCM: distance, targetSampleCount: p.cells.count, actualSampleCount: q.cells.count)
    }
}
