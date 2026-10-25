import Foundation
struct SCNVector3 {var x:Float;var y:Float;var z:Float;init(_ x:Float,_ y:Float,_ z:Float){self.x=x;self.y=y;self.z=z}}
let SCNVector3Zero=SCNVector3(0,0,0)
struct LinearCushionSegment {let start:SCNVector3;let end:SCNVector3}
struct CircularCushionSegment {let center:SCNVector3;let radius:Float;let startAngle:Float;let endAngle:Float
func isAngleInRange(_ angle: Float) -> Bool {
        let twoPi = Float.pi * 2
        var a = angle.truncatingRemainder(dividingBy: twoPi)
        if a < 0 { a += twoPi }
        
        var s = startAngle.truncatingRemainder(dividingBy: twoPi)
        if s < 0 { s += twoPi }
        var e = endAngle.truncatingRemainder(dividingBy: twoPi)
        if e < 0 { e += twoPi }
        
        let eps: Float = 0.01
        if s <= e {
            return a >= s - eps && a <= e + eps
        } else {
            return a >= s - eps || a <= e + eps
        }
    }
}
struct TableGeometry {let pockets:[Pocket];let linearCushions:[LinearCushionSegment];let circularCushions:[CircularCushionSegment]}
enum TablePhysics {static var innerLength:Float=0;static var innerWidth:Float=0}
enum SceneTrainingRailGeometry {static let contactRoundoff:Float=4*Float.ulpOfOne}
enum EngineNumerics {static func smallestPositiveRoot(_ roots: [Double], maxTime: Float) -> Float? {
        let epsilon = 1e-6
        let maxT = Double(maxTime) + 1e-6
        let validRoots = roots.filter { $0 > epsilon && $0 <= maxT && $0.isFinite && !$0.isNaN }
        guard let smallest = validRoots.min() else { return nil }
        return Float(smallest)
    }}
struct Pocket {
    let id: String
    let center: SCNVector3
    let radius: Float
    let isCorner: Bool
    /// Convex CCW polygon of the measured, exposed cloth lip (world XZ metres).
    /// It extends the legacy deep collector toward the actual opening; it does
    /// not move the CAD jaws, the aiming centre, or the rendered leather.
    var captureLip: [SIMD2<Double>] = []

    var captureReachRadius: Float {
        var squared = Double(radius * radius)
        for p in captureLip {
            let dx = p.x - Double(center.x), dz = p.y - Double(center.z)
            squared = max(squared, dx*dx + dz*dz)
        }
        return Float(sqrt(squared))
    }

    func containsLip(_ position: SCNVector3, tolerance: Double = 0) -> Bool {
        guard captureLip.count >= 3 else { return false }
        let p = SIMD2(Double(position.x), Double(position.z))
        return captureLip.indices.allSatisfy { i in
            let a = captureLip[i], e = captureLip[(i + 1) % captureLip.count] - a
            let length = sqrt(e.x * e.x + e.y * e.y)
            return e.x * (p.y - a.y) - e.y * (p.x - a.x) >= -tolerance * length
        }
    }

    func containsCapture(_ position: SCNVector3, tolerance: Double = 0) -> Bool {
        let dx = Double(position.x - center.x), dz = Double(position.z - center.z)
        return dx * dx + dz * dz <= pow(Double(radius) + tolerance, 2)
            || containsLip(position, tolerance: tolerance)
    }

    /// Shared capture CCD for both the event engine and analytic search.
    func entryTime(position: SCNVector3, velocity: SCNVector3,
                   acceleration: SCNVector3, maxTime: Float) -> Float? {
        let dx = position.x-center.x, dz = position.z-center.z
        let vx = velocity.x, vz = velocity.z
        let ax = acceleration.x*0.5, az = acceleration.z*0.5
        let roots = QuarticSolver.solveQuartic(
            a: Double(ax*ax+az*az), b: 2*Double(vx*ax+vz*az),
            c: Double(vx*vx+vz*vz)+2*Double(dx*ax+dz*az),
            d: 2*Double(dx*vx+dz*vz), e: Double(dx*dx+dz*dz)-Double(radius*radius))
        let circle = EngineNumerics.smallestPositiveRoot(roots, maxTime: maxTime)
        let lip = lipEntryTime(position: position, velocity: velocity,
                               acceleration: acceleration, maxTime: maxTime)
        return [circle, lip].compactMap { $0 }.min()
    }

    /// Earliest inward crossing of a finite lip edge under the same quadratic
    /// motion used by the planar CCD. Tangency and exiting roots are not capture.
    func lipEntryTime(position: SCNVector3, velocity: SCNVector3,
                      acceleration: SCNVector3, maxTime: Float) -> Float? {
        guard captureLip.count >= 3 else { return nil }
        let p = SIMD2(Double(position.x), Double(position.z))
        let v = SIMD2(Double(velocity.x), Double(velocity.z))
        let a = SIMD2(Double(acceleration.x), Double(acceleration.z))
        // Cheap conservative reach bound; no mesh query in the shot search loop.
        let h = Double(maxTime)
        let reach = sqrt(v.x*v.x + v.y*v.y)*h + 0.5*sqrt(a.x*a.x + a.y*a.y)*h*h
        var minX = Double.infinity, maxX = -Double.infinity
        var minZ = Double.infinity, maxZ = -Double.infinity
        for vertex in captureLip {
            minX = min(minX, vertex.x); maxX = max(maxX, vertex.x)
            minZ = min(minZ, vertex.y); maxZ = max(maxZ, vertex.y)
        }
        guard p.x + reach >= minX, p.x - reach <= maxX,
              p.y + reach >= minZ, p.y - reach <= maxZ else { return nil }
        var earliest: Double?
        for i in captureLip.indices {
            let start = captureLip[i], edge = captureLip[(i+1)%captureLip.count] - start
            let length = sqrt(edge.x*edge.x + edge.y*edge.y)
            let n = SIMD2(-edge.y/length, edge.x/length)
            func dot(_ x: SIMD2<Double>, _ y: SIMD2<Double>) -> Double { x.x*y.x + x.y*y.y }
            let c = dot(n, p-start), b = dot(n, v), q = 0.5*dot(n, a)
            for t in QuarticSolver.solveQuadraticPublic(a: q, b: b, c: c) {
                guard t >= 0, t <= h, t.isFinite, b+2*q*t > 0 else { continue }
                let hit = p + v*t + a*(0.5*t*t)
                let u = dot(hit-start, edge)/(length*length)
                guard u >= 0, u <= 1 else { continue }
                // Recheck all halfplanes; an infinite supporting line is not the lip.
                guard containsLip(SCNVector3(Float(hit.x), position.y, Float(hit.y)),
                                  tolerance: Double(Float.ulpOfOne)*2) else { continue }
                if earliest == nil || t < earliest! { earliest = t }
            }
        }
        return earliest.map(Float.init)
    }
}
struct GridGeometry {
    typealias V = SIMD2<Double>
    let table: TableGeometry
    let radius: Double
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

func json(_ p:String)throws->Any {try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:p)))}
let g=try json(CommandLine.arguments[1]) as! [String:Any]
func v(_ x:Any)->SCNVector3 {let p=x as! [String:Double];return SCNVector3(Float(p["x"]!),0,Float(p["z"]!))}
TablePhysics.innerLength=Float(g["length"] as! Double);TablePhysics.innerWidth=Float(g["width"] as! Double)
let pockets=(g["pockets"] as! [[String:Any]]).enumerated().map {i,p in Pocket(id:"pocket_\(i)",center:v(p["center"]!),radius:Float(p["radius"] as! Double),isCorner:i<4,captureLip:(p["lip"] as! [[String:Double]]).map {SIMD2($0["x"]!,$0["z"]!)})}
let lines=(g["lines"] as! [[String:Any]]).map {LinearCushionSegment(start:v($0["start"]!),end:v($0["end"]!))}
let arcs=(g["arcs"] as! [[String:Any]]).map {CircularCushionSegment(center:v($0["center"]!),radius:Float($0["radius"] as! Double),startAngle:Float($0["start"] as! Double),endAngle:Float($0["end"] as! Double))}
let geometry=GridGeometry(table:TableGeometry(pockets:pockets,linearCushions:lines,circularCushions:arcs),radius:g["radius"] as! Double)
struct Input:Decodable {let key:String;let object:[Double];let pocket:Int}
struct Proof:Encodable {let key:String;let object:[Double];let pocket:Int;let aim:[Double];let direction:[Double];let passed:Bool;let captureDistance:Double?;let solidDistance:Double;let otherPocketDistance:Double}
var results:[Proof]=[]
for row in try JSONDecoder().decode([Input].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))) {
 let b=row.object,p=row.pocket,origin=SIMD2(b[0],b[1]),aim=geometry.generationAnchor(p),direction=geometry.unit(aim-origin)
 let extent=2*hypot(Double(TablePhysics.innerLength),Double(TablePhysics.innerWidth))
 let entry=geometry.table.pockets[p].entryTime(position:geometry.scene(origin),velocity:geometry.scene(direction),acceleration:SCNVector3Zero,maxTime:Float(extent))
 let bound=entry.map {Double($0)+0.01} ?? extent
 let solid=geometry.solidLimit(origin,direction,maximum:bound),other=geometry.captureLimit(origin,direction,maximum:bound,excluding:p)
 results.append(Proof(key:row.key,object:b,pocket:p,aim:[aim.x,aim.y],direction:[direction.x,direction.y],passed:geometry.cleanObjectPath(origin,aim,pocket:p),captureDistance:entry.map {Double($0)},solidDistance:solid,otherPocketDistance:other))
}
try JSONEncoder().encode(results).write(to:URL(fileURLWithPath:CommandLine.arguments[3]),options:.atomic)
print("checked \(results.count) B/pocket rays")
