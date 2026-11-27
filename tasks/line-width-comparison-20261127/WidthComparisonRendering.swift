import SceneKit
import simd

enum WidthComparisonRendering {
    static var comparisonRadius: Float = TrajectoryStyle.lineMain
    typealias Record = SpatialPracticeRecord
    struct Segment {
        let points: [SCNVector3]
        let dashed: Bool
    }
    /// Shared free-practice/quiz semantics: cue prefix solid, all later motion dashed.
    /// Preserve the recording's actual contact time and XYZ samples.
    static func segments(_ shot:Record.Shot,key:String,detail:TrajectoryDetail) -> [Segment] {
        let points=Record.visibleRoute(shot,key:key,detail:detail)
        guard points.count>1 else { return [] }
        let cue=PositionPlayBall.isCue(key)
        let prefixCount=cue ? Record.visibleRoute(shot,key:key,detail:.minimal).count : 0
        let split=min(points.count,max(0,prefixCount))
        var result:[Segment]=[]
        if split>1 { result.append(.init(points:Array(points.prefix(split)),dashed:false)) }
        let remaining=cue ? Array(points.dropFirst(max(0,split-1))) : points
        if remaining.count>1 { result.append(.init(points:remaining,dashed:true)) }
        return result
    }
    @discardableResult
    static func appendBallRoute(_ shot:Record.Shot,key:String,detail:TrajectoryDetail,
                                to parent:SCNNode,scene:AngleTrainingScene,
                                presentation:TrajectoryStyle.Presentation = .current) -> Bool {
        let pieces=segments(shot,key:key,detail:detail)
        guard !pieces.isEmpty else { return false }
        let material=SCNMaterial();material.lightingModel = .constant
        material.diffuse.contents=presentation.color(PositionPlayBall.isCue(key) ? TrajectoryStyle.aimColor : TrajectoryStyle.potColor(for:key))
        for piece in pieces {
            let node=SCNNode();node.name=piece.dashed ? "spatialRoute.dashed" : "spatialRoute.solid"
            appendRoute(piece.points,dashed:piece.dashed,material:material,to:node,scene:scene)
            parent.addChildNode(node)
        }
        parent.castsShadow=false
        return true
    }
    static func appendRoute(_ samples:[SCNVector3], dashed:Bool, material:SCNMaterial, to parent:SCNNode, scene:AngleTrainingScene) {
        let points=Record.reducedRoute(samples)
        guard points.count>1, let color=material.diffuse.contents as? UIColor else { return }
        let restingY=scene.surfaceY+BallPhysics.radius
        let clothY=scene.tableRouteHeight
        func onCloth(_ point:SCNVector3)->Bool { abs(point.y-restingY)<0.00005 }
        var start=0
        while start<points.count-1 {
            let ground=onCloth(points[start]) && onCloth(points[start+1])
            var end=start+1
            while end+1<points.count, (onCloth(points[end]) && onCloth(points[end+1])) == ground { end+=1 }
            let run=Array(points[start...end])
            if ground {
                var nodes:[SCNNode]=[]
                if dashed {
                    scene.addDashedPolyline(run,color:color,radius:comparisonRadius,placement:.table,into:&nodes)
                } else {
                    scene.addTablePolyline(run,color:color,radius:comparisonRadius,into:&nodes)
                }
                for node in nodes { parent.addChildNode(node) }
            } else {
                let path=run.map { SCNVector3($0.x,clothY+($0.y-restingY),$0.z) }
                parent.addChildNode(Self.routeMesh(path,dashed:dashed,material:material))
            }
            start=end
        }
    }
    /// One batched XYZ tube per stroke style; uses the common radii/dash language.
    /// No .table projection, and no SceneKit node per 240 Hz playback sample.
    private static func routeMesh(_ points:[SCNVector3],dashed:Bool,material:SCNMaterial)->SCNNode {
        var vertices:[SCNVector3]=[],indices:[Int32]=[]
        let radius=comparisonRadius,period=TrajectoryStyle.mainDash+TrajectoryStyle.mainGap
        var arc:Float=0
        func append(_ a:SIMD3<Float>,_ b:SIMD3<Float>) {
            let delta=b-a
            guard simd_length_squared(delta)>1e-12 else { return }
            let tangent=simd_normalize(delta)
            let axis:SIMD3<Float>=abs(tangent.y)<0.9 ? SIMD3(0,1,0) : SIMD3(1,0,0)
            let u=simd_normalize(simd_cross(tangent,axis))*radius,v=simd_cross(tangent,u)
            let base=Int32(vertices.count)
            for end in [a,b] { for i in 0..<6 {
                let angle=Float(i)*(.pi/3),p=end+u*cosf(angle)+v*sinf(angle)
                vertices.append(SCNVector3(p.x,p.y,p.z))
            } }
            for i in 0..<6 { let j=(i+1)%6,a=base+Int32(i),b=base+Int32(j)
                indices += [a,b,a+6,b,b+6,a+6]
            }
        }
        for i in 1..<points.count {
            let a=SIMD3(points[i-1].x,points[i-1].y,points[i-1].z),b=SIMD3(points[i].x,points[i].y,points[i].z)
            let length=simd_distance(a,b)
            guard length>1e-6 else { continue }
            if dashed {
                let first=Int(floor(arc/period)),last=Int(floor((arc+length)/period))
                for k in first...last {
                    let start=max(arc,Float(k)*period),end=min(arc+length,Float(k)*period+TrajectoryStyle.mainDash)
                    if end>start { append(a+(b-a)*((start-arc)/length),a+(b-a)*((end-arc)/length)) }
                }
            } else { append(a,b) }
            arc += length
        }
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        geometry.materials=[material]
        let node=SCNNode(geometry:geometry);node.castsShadow=false
        return node
    }
}
