struct RailBedBVH {
    typealias V = SIMD3<Double>
    struct Triangle {
        let a: V, b: V, c: V
        var lo: V { simd_min(a,simd_min(b,c)) }
        var hi: V { simd_max(a,simd_max(b,c)) }
        var center: V { (a+b+c)/3 }
        func hits(_ p: V,_ d: V) -> Bool {
            let e1=b-a,e2=c-a,h=simd_cross(d,e2),det=simd_dot(e1,h)
            if abs(det)<1e-13 {return false}
            let f=1/det,s=p-a,u=f*simd_dot(s,h)
            if u < -1e-10 || u > 1+1e-10 {return false}
            let q=simd_cross(s,e1),v=f*simd_dot(d,q)
            if v < -1e-10 || u+v > 1+1e-10 {return false}
            let t=f*simd_dot(e2,q)
            return t>1e-8 && t<1-1e-8
        }
    }
    struct Node {let lo:V,hi:V,left:Int,right:Int,start:Int,end:Int}
    let triangles:[Triangle]
    var nodes=[Node](),order=[Int]()
    init(_ triangles:[Triangle]) {
        self.triangles=triangles
        if !triangles.isEmpty {_=build(Array(triangles.indices))}
    }
    mutating func build(_ ids:[Int]) -> Int {
        var lo=V(repeating:Double.infinity),hi=V(repeating:-Double.infinity)
        for i in ids {lo=simd_min(lo,triangles[i].lo);hi=simd_max(hi,triangles[i].hi)}
        let index=nodes.count
        nodes.append(Node(lo:lo,hi:hi,left:-1,right:-1,start:0,end:0))
        if ids.count<=6 {
            let start=order.count;order.append(contentsOf:ids)
            nodes[index]=Node(lo:lo,hi:hi,left:-1,right:-1,start:start,end:order.count)
        } else {
            let span=hi-lo;let axis=span.x>span.y ? (span.x>span.z ? 0:2):(span.y>span.z ? 1:2)
            let sorted=ids.sorted {triangles[$0].center[axis]<triangles[$1].center[axis]}
            let mid=sorted.count/2
            let left=build(Array(sorted[..<mid])),right=build(Array(sorted[mid...]))
            nodes[index]=Node(lo:lo,hi:hi,left:left,right:right,start:0,end:0)
        }
        return index
    }
    func occluded(_ p:V,_ d:V) -> Bool {
        if nodes.isEmpty {return false}
        return hitNode(0,p,d,V(1/d.x,1/d.y,1/d.z))
    }
    func hitNode(_ i:Int,_ p:V,_ d:V,_ inv:V) -> Bool {
        let node=nodes[i];var near=0.0,far=1.0
        for k in 0..<3 {
            if abs(d[k])<1e-14 {
                if p[k]<node.lo[k] || p[k]>node.hi[k] {return false}
            } else {
                let a=(node.lo[k]-p[k])*inv[k],b=(node.hi[k]-p[k])*inv[k]
                near=max(near,min(a,b));far=min(far,max(a,b))
                if near>far {return false}
            }
        }
        if node.left<0 {
            for j in node.start..<node.end where triangles[order[j]].hits(p,d) {return true}
            return false
        }
        return hitNode(node.left,p,d,inv) || hitNode(node.right,p,d,inv)
    }
}
