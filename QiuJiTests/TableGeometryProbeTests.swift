//
//  TableGeometryProbeTests.swift
//  QiuJiTests
//
//  P10 物理标定 · Track B-1：jaw↔洞心对齐（USDZ 单一真源）。
//
//  目的：从 `TaiQiuZhuo.usdz` 网格**直接实测**球台几何，作为 jaw 圆弧 / jaw 直线段 /
//  袋口洞心的单一真源，消除现状「jaw 取 CAD 坐标、袋心取 USDZ」之间残留的 ~17mm 错位。
//
//  本文件分两步：
//  1. `test_probe_A_dumpStructure`：转储 USDZ 节点 / 材质 / 顶点分布，供分析模型结构。
//  2. `test_probe_B_measurePocketGeometry`：按台呢平面 + 库鼻接触高度带实测 6 袋口开口
//     与各角袋 jaw 尖端，打印「实测 vs 现 CAD vs 现 USDZ」对照表（写 PHYSICS-PROBE.md）。
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
//      -only-testing:QiuJiTests/TableGeometryProbeTests
//

import XCTest
import SceneKit
@testable import QiuJi

final class TableGeometryProbeTests: XCTestCase {

    private let ballNames: Set<String> = [
        "_0", "BaiQiu",
        "_1", "_2", "_3", "_4", "_5", "_6", "_7",
        "_8", "_9", "_10", "_11", "_12", "_13", "_14", "_15"
    ]

    // MARK: - A. 结构转储

    func test_probe_A_dumpStructure() throws {
        let model = try loadModelOrSkip()
        print("\n===PROBE-STRUCTURE===")
        print(String(format: "surfaceY(model)=%.4f  appliedScale=%.5f",
                     model.surfaceY, model.appliedScale.x))

        var geomNodes: [SCNNode] = []
        collectGeometryNodes(model.visualNode, isUnderBall: false, into: &geomNodes)
        print("几何节点数（含球）= \(allGeometryNodeCount(model.visualNode))；非球几何节点 = \(geomNodes.count)")

        // 每个非球几何节点：名称 / 材质名 / 顶点数 / 世界包围盒。
        print("\n节点  | 材质 | 顶点 | worldBBox(x:[..],y:[..],z:[..])")
        for node in geomNodes {
            let verts = worldVertices(of: node)
            guard !verts.isEmpty else { continue }
            let bbox = boundingBox(verts)
            let matNames = (node.geometry?.materials.compactMap { $0.name }.joined(separator: ",")) ?? ""
            print(String(format: "%@ | %@ | %d | x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]",
                         node.name ?? "(nil)", matNames.isEmpty ? "(nil)" : matNames, verts.count,
                         bbox.minX, bbox.maxX, bbox.minY, bbox.maxY, bbox.minZ, bbox.maxZ))
        }

        // 全部非球顶点的 Y 直方图（找出台面 / 库鼻接触带高度）。
        var allVerts: [SCNVector3] = []
        for node in geomNodes { allVerts.append(contentsOf: worldVertices(of: node)) }
        print("\n非球总顶点 = \(allVerts.count)")
        let contactY = model.surfaceY + BallPhysics.radius
        print(String(format: "台面 surfaceY=%.4f  库鼻接触高度 surfaceY+R=%.4f", model.surfaceY, contactY))
        printYHistogram(allVerts, around: model.surfaceY)
        print("===END-PROBE-STRUCTURE===\n")
    }

    // MARK: - A2. 按材质拆解 + Leather 聚类（袋心）+ TaiNi 库鼻剖面

    func test_probe_A2_materialBreakdown() throws {
        let model = try loadModelOrSkip()
        var geomNodes: [SCNNode] = []
        collectGeometryNodes(model.visualNode, isUnderBall: false, into: &geomNodes)
        guard let node = geomNodes.first else { return XCTFail("无几何节点") }

        print("\n===PROBE-MATERIAL===")
        let byMat = worldVerticesByMaterial(of: node)
        print("材质 | 去重顶点 | x[min,max] z[min,max] | 质心(x,z)")
        for (mat, verts) in byMat {
            let dedup = dedupeXZ(verts)
            guard !dedup.isEmpty else {
                print("\(mat) | 0 | - | -"); continue
            }
            let b = boundingBox(dedup)
            let cx = dedup.reduce(Float(0)) { $0 + $1.x } / Float(dedup.count)
            let cz = dedup.reduce(Float(0)) { $0 + $1.z } / Float(dedup.count)
            print(String(format: "%@ | %d | x[%.3f,%.3f] z[%.3f,%.3f] | (%.4f,%.4f)",
                         mat, dedup.count, b.minX, b.maxX, b.minZ, b.maxZ, cx, cz))
        }

        // Leather → 6 聚类（袋口洞心候选）。
        if let leather = byMat.first(where: { $0.material.contains("Leather") })?.verts {
            let dedup = dedupeXZ(leather)
            let clusters = clusterXZ(dedup, threshold: 0.18)
            print("\nLeather 聚类（阈值 0.18m）：\(clusters.count) 簇")
            print("  簇 | n | 质心(x,z) | x[min,max] z[min,max]")
            for (i, c) in clusters.sorted(by: { centroidXZ($0).0 < centroidXZ($1).0 }).enumerated() {
                let (cx, cz) = centroidXZ(c)
                let b = boundingBox(c)
                print(String(format: "  %d | %d | (%.4f,%.4f) | x[%.3f,%.3f] z[%.3f,%.3f]",
                             i, c.count, cx, cz, b.minX, b.maxX, b.minZ, b.maxZ))
            }
        }

        // TaiNi 台呢库鼻剖面：上/下长库（z 极值 vs x）、左/右短库（x 极值 vs z）。
        if let cloth = byMat.first(where: { $0.material.contains("TaiNi") })?.verts {
            let band = cloth.filter { abs($0.y - model.surfaceY) < 0.006 }
            print("\nTaiNi 台呢（rel±6mm）顶点 = \(band.count)")
            railNoseProfileLong(band, edgeSign: 1)   // 上长库 z>0
            railNoseProfileLong(band, edgeSign: -1)  // 下长库 z<0
            railNoseProfileShort(band, edgeSign: 1)  // 右短库 x>0
            railNoseProfileShort(band, edgeSign: -1) // 左短库 x<0
        }
        print("===END-PROBE-MATERIAL===\n")
    }

    /// 长库（上/下）库鼻剖面：按 x 分箱，取该列最靠库（|z| 最大）的台呢顶点，揭示袋口缺口。
    private func railNoseProfileLong(_ verts: [SCNVector3], edgeSign: Float) {
        let label = edgeSign > 0 ? "上长库 z>0" : "下长库 z<0"
        let half = verts.filter { edgeSign > 0 ? $0.z > 0.3 : $0.z < -0.3 }
        let binW: Float = 0.05
        var profile: [(x: Float, z: Float)] = []
        var x: Float = -1.30
        while x <= 1.30 {
            let col = half.filter { $0.x >= x && $0.x < x + binW }
            if let edge = (edgeSign > 0 ? col.max(by: { $0.z < $1.z }) : col.min(by: { $0.z < $1.z })) {
                profile.append((x + binW / 2, edge.z))
            } else {
                profile.append((x + binW / 2, Float.nan))
            }
            x += binW
        }
        print("[\(label)] 库鼻 z(x) 剖面（nan=该列无台呢=袋口缺口）：")
        print("  " + profile.map { p in p.z.isNaN ? String(format: "%.2f:gap", p.x) : String(format: "%.2f:%.3f", p.x, p.z) }.joined(separator: " "))
    }

    /// 短库（左/右）库鼻剖面：按 z 分箱，取该行最靠库（|x| 最大）的台呢顶点。
    private func railNoseProfileShort(_ verts: [SCNVector3], edgeSign: Float) {
        let label = edgeSign > 0 ? "右短库 x>0" : "左短库 x<0"
        let half = verts.filter { edgeSign > 0 ? $0.x > 0.8 : $0.x < -0.8 }
        let binW: Float = 0.05
        var profile: [(z: Float, x: Float)] = []
        var z: Float = -0.65
        while z <= 0.65 {
            let row = half.filter { $0.z >= z && $0.z < z + binW }
            if let edge = (edgeSign > 0 ? row.max(by: { $0.x < $1.x }) : row.min(by: { $0.x < $1.x })) {
                profile.append((z + binW / 2, edge.x))
            } else {
                profile.append((z + binW / 2, Float.nan))
            }
            z += binW
        }
        print("[\(label)] 库鼻 x(z) 剖面：")
        print("  " + profile.map { p in p.x.isNaN ? String(format: "%.2f:gap", p.z) : String(format: "%.2f:%.3f", p.z, p.x) }.joined(separator: " "))
    }

    // MARK: - A3. 库鼻窗内边界点（精确定位 jaw 尖端 / 袋口喉部）

    func test_probe_A3_noseEdges() throws {
        let model = try loadModelOrSkip()
        var geomNodes: [SCNNode] = []
        collectGeometryNodes(model.visualNode, isUnderBall: false, into: &geomNodes)
        guard let node = geomNodes.first else { return XCTFail("无几何节点") }
        let byMat = worldVerticesByMaterial(of: node)
        guard let cloth = byMat.first(where: { $0.material.contains("TaiNi") })?.verts else {
            return XCTFail("无 TaiNi 台呢")
        }
        let band = cloth.filter { abs($0.y - model.surfaceY) < 0.008 }

        print("\n===PROBE-NOSE-EDGES===")
        // 长库库鼻窗：z∈[0.60,0.66]（避开 z>0.68 的皮革凸起）。列出去重(5mm) x 排序。
        let topNose = dedupeXZ(band.filter { $0.z >= 0.600 && $0.z <= 0.665 }).sorted { $0.x < $1.x }
        print("上长库 库鼻窗 z∈[0.600,0.665] 点（x:z，5mm 去重，找 x 缺口=袋口）：")
        printPointRun(topNose, axis: .x)

        // 短库库鼻窗：x∈[1.24,1.30]。列出去重 z 排序。
        let rightNose = dedupeXZ(band.filter { $0.x >= 1.235 && $0.x <= 1.300 }).sorted { $0.z < $1.z }
        print("\n右短库 库鼻窗 x∈[1.235,1.300] 点（z:x，找 z 缺口=袋口）：")
        printPointRun(rightNose, axis: .z)

        // 中袋口（上）：长库 z≈0.635 在 x≈0 的缺口边缘。
        let midTop = dedupeXZ(band.filter { $0.z >= 0.600 && $0.z <= 0.665 && abs($0.x) < 0.20 }).sorted { $0.x < $1.x }
        print("\n上中袋附近 z∈[0.600,0.665] |x|<0.20 点（x:z）：")
        printPointRun(midTop, axis: .x)

        // RU 角袋细节：x∈[1.10,1.30] 且 z∈[0.55,0.68] 全点（找两条 jaw 尖端最内点）。
        let ruRegion = dedupeXZ(band.filter { $0.x >= 1.10 && $0.z >= 0.55 }).sorted {
            ($0.x + $0.z) < ($1.x + $1.z)
        }
        print("\nRU 角袋区域 x≥1.10 & z≥0.55 点（按 x+z 升序，前若干=最内 jaw 尖端）：")
        printPointRun(Array(ruRegion.prefix(24)), axis: .none)
        print("===END-PROBE-NOSE-EDGES===\n")
    }

    // MARK: - A4. 库冠脊线连续段 → jaw 尖端 + 袋口喉部（最终测量）

    func test_probe_A4_jawTips() throws {
        let model = try loadModelOrSkip()
        var geomNodes: [SCNNode] = []
        collectGeometryNodes(model.visualNode, isUnderBall: false, into: &geomNodes)
        guard let node = geomNodes.first else { return XCTFail("无几何节点") }
        let byMat = worldVerticesByMaterial(of: node)
        guard let cloth = byMat.first(where: { $0.material.contains("TaiNi") })?.verts else {
            return XCTFail("无 TaiNi")
        }
        let sY = model.surfaceY
        // 库冠脊线带：台面以上 28~40mm（库顶内缘）。
        let crown = cloth.filter { ($0.y - sY) >= 0.028 && ($0.y - sY) <= 0.041 }

        print("\n===PROBE-JAW-TIPS===")
        print(String(format: "库冠带顶点 = %d（rel+28~41mm）", crown.count))

        // 长库（上 z>0 / 下 z<0）：沿 x 分段，每段端点=jaw 尖端，段内 |z| 中位=库鼻线。
        analyzeLongRail(crown, edgeSign: 1)
        analyzeLongRail(crown, edgeSign: -1)
        // 短库（右 x>0 / 左 x<0）：沿 z 分段。
        analyzeShortRail(crown, edgeSign: 1)
        analyzeShortRail(crown, edgeSign: -1)

        print("===END-PROBE-JAW-TIPS===\n")
    }

    /// 长库：取该半侧库冠点，沿 x 排序找连续段（间断 >3cm 视为袋口），打印每段端点 + 库鼻 z。
    private func analyzeLongRail(_ crown: [SCNVector3], edgeSign: Float) {
        let label = edgeSign > 0 ? "上长库(z>0)" : "下长库(z<0)"
        let side = crown.filter { edgeSign > 0 ? $0.z > 0.45 : $0.z < -0.45 }
        // 用最靠库内的脊线点：按 x 分 5mm 箱，取 |z| 最小（最内）的点。
        var binMap: [Int: SCNVector3] = [:]
        for v in side {
            let b = Int((v.x / 0.005).rounded())
            if let cur = binMap[b] {
                if abs(v.z) < abs(cur.z) { binMap[b] = v }
            } else { binMap[b] = v }
        }
        let ridge = binMap.values.sorted { $0.x < $1.x }
        printSegments(ridge, along: .x, label: label)
    }

    private func analyzeShortRail(_ crown: [SCNVector3], edgeSign: Float) {
        let label = edgeSign > 0 ? "右短库(x>0)" : "左短库(x<0)"
        let side = crown.filter { edgeSign > 0 ? $0.x > 0.9 : $0.x < -0.9 }
        var binMap: [Int: SCNVector3] = [:]
        for v in side {
            let b = Int((v.z / 0.005).rounded())
            if let cur = binMap[b] {
                if abs(v.x) < abs(cur.x) { binMap[b] = v }
            } else { binMap[b] = v }
        }
        let ridge = binMap.values.sorted { $0.z < $1.z }
        printSegments(ridge, along: .z, label: label)
    }

    /// 找连续段（沿 along 轴相邻点间断 >3cm 断开），打印每段 [起点..终点] 与库鼻坐标中位。
    private func printSegments(_ ridge: [SCNVector3], along axis: SortAxis, label: String) {
        guard !ridge.isEmpty else { print("[\(label)] 无脊线点"); return }
        func coord(_ v: SCNVector3) -> Float { axis == .x ? v.x : v.z }
        var segments: [[SCNVector3]] = []
        var cur: [SCNVector3] = [ridge[0]]
        for i in 1..<ridge.count {
            if coord(ridge[i]) - coord(ridge[i - 1]) > 0.03 {
                segments.append(cur); cur = [ridge[i]]
            } else { cur.append(ridge[i]) }
        }
        segments.append(cur)
        print("[\(label)] 连续段=\(segments.count)（端点=jaw 尖端）：")
        for (i, seg) in segments.enumerated() {
            guard let a = seg.first, let b = seg.last else { continue }
            let noseVals = seg.map { axis == .x ? $0.z : $0.x }.sorted()
            let med = noseVals[noseVals.count / 2]
            print(String(format: "  段%d: 起(%.4f,%.4f) 终(%.4f,%.4f) 库鼻%@中位=%.4f n=%d",
                         i, a.x, a.z, b.x, b.z, axis == .x ? "z" : "x", med, seg.count))
        }
    }

    private enum SortAxis { case x, z, none }

    private func printPointRun(_ pts: [SCNVector3], axis: SortAxis) {
        let strs = pts.map { p -> String in
            switch axis {
            case .x: return String(format: "%.3f:%.3f", p.x, p.z)
            case .z: return String(format: "%.3f:%.3f", p.z, p.x)
            case .none: return String(format: "(%.3f,%.3f)", p.x, p.z)
            }
        }
        // 每行 8 个，便于阅读。
        var line: [String] = []
        for s in strs {
            line.append(s)
            if line.count == 8 { print("  " + line.joined(separator: " ")); line.removeAll() }
        }
        if !line.isEmpty { print("  " + line.joined(separator: " ")) }
    }

    // MARK: - Helpers · 按材质拆顶点

    /// 返回 (材质名, 该材质 element 引用到的世界坐标顶点)。
    private func worldVerticesByMaterial(of node: SCNNode) -> [(material: String, verts: [SCNVector3])] {
        guard let geom = node.geometry else { return [] }
        let allVerts = worldVertices(of: node)
        var out: [(String, [SCNVector3])] = []
        for (i, element) in geom.elements.enumerated() {
            let matName = i < geom.materials.count ? (geom.materials[i].name ?? "mat\(i)") : "mat\(i)"
            let idxs = vertexIndices(of: element)
            var verts: [SCNVector3] = []
            verts.reserveCapacity(idxs.count)
            for idx in idxs where idx >= 0 && idx < allVerts.count { verts.append(allVerts[idx]) }
            out.append((matName, verts))
        }
        return out
    }

    private func vertexIndices(of element: SCNGeometryElement) -> [Int] {
        let bpi = element.bytesPerIndex
        guard bpi == 1 || bpi == 2 || bpi == 4 else { return [] }
        let data = element.data
        let n = data.count / bpi
        var result = [Int]()
        result.reserveCapacity(n)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            for i in 0..<n {
                let p = base.advanced(by: i * bpi)
                switch bpi {
                case 1: result.append(Int(p.loadUnaligned(fromByteOffset: 0, as: UInt8.self)))
                case 2: result.append(Int(p.loadUnaligned(fromByteOffset: 0, as: UInt16.self)))
                default: result.append(Int(p.loadUnaligned(fromByteOffset: 0, as: UInt32.self)))
                }
            }
        }
        return result
    }

    /// XZ 去重（1mm 网格），剔除重复共享顶点。
    private func dedupeXZ(_ verts: [SCNVector3]) -> [SCNVector3] {
        var seen = Set<Int64>()
        var out: [SCNVector3] = []
        for v in verts {
            let kx = Int64((v.x * 1000).rounded())
            let kz = Int64((v.z * 1000).rounded())
            let key = kx &* 100_000 &+ kz
            if seen.insert(key).inserted { out.append(v) }
        }
        return out
    }

    /// 贪心 XZ 聚类：每点归入最近且距离 < threshold 的簇，否则新建簇。
    private func clusterXZ(_ verts: [SCNVector3], threshold: Float) -> [[SCNVector3]] {
        var clusters: [[SCNVector3]] = []
        var centers: [(Float, Float)] = []
        for v in verts {
            var best = -1
            var bestD = Float.greatestFiniteMagnitude
            for (i, c) in centers.enumerated() {
                let d = (v.x - c.0) * (v.x - c.0) + (v.z - c.1) * (v.z - c.1)
                if d < bestD { bestD = d; best = i }
            }
            if best >= 0 && bestD < threshold * threshold {
                clusters[best].append(v)
                let n = Float(clusters[best].count)
                centers[best] = (centers[best].0 + (v.x - centers[best].0) / n,
                                 centers[best].1 + (v.z - centers[best].1) / n)
            } else {
                clusters.append([v])
                centers.append((v.x, v.z))
            }
        }
        return clusters
    }

    private func centroidXZ(_ verts: [SCNVector3]) -> (Float, Float) {
        guard !verts.isEmpty else { return (0, 0) }
        let cx = verts.reduce(Float(0)) { $0 + $1.x } / Float(verts.count)
        let cz = verts.reduce(Float(0)) { $0 + $1.z } / Float(verts.count)
        return (cx, cz)
    }

    // MARK: - B. 进球覆盖诊断（求解器在多袋/多力度下能否真进）

    func test_probe_B_pottingCoverage() {
        let sY = BTTablePhysics.surfaceY
        let r = AngleSceneCalculator.ballRadius
        print("\n===PROBE-POTTING===")
        print(String(format: "落袋孔窗（球心需进入袋心 %.1fmm 内，= 物理落袋孔半径−R；rattle 由喉腔库边产生）",
                     (AngleSceneCalculator.pocketDropRadius(index: 1) - r) * 1000))

        // 1) 复现 drill_c002（近直球 bottomRight）。
        let c002cue = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: 0.3, y: 0.25), surfaceY: sY)
        let c002tgt = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: 0.75, y: 0.4), surfaceY: sY)
        report("c002 bottomRight v3.3", cue: c002cue, target: c002tgt, pocketIndex: 3, velocity: 3.3, spinX: 0, spinY: 0)

        // 2) 角袋(右上 idx1=(+1.30,-0.665)) 近直球，多距离/力度。
        //    idx1 在 -z 侧，故 cue 在 +z 侧、target 在两者之间，朝 -z/+x 推。
        for (cz, tz, tx, lbl) in [(0.10, -0.20, 0.6, "近"), (0.25, -0.35, 0.2, "中"), (0.35, -0.45, -0.2, "远")] as [(Float,Float,Float,String)] {
            let tgt = SCNVector3(tx, sY + r, tz)
            let cue = SCNVector3(tx - 0.35, sY + r, cz)
            for v in [Float(2.4), 3.3, 4.4] {
                report(String(format: "角袋idx1\(lbl)直 v%.1f", v), cue: cue, target: tgt, pocketIndex: 1, velocity: v, spinX: 0, spinY: 0)
            }
        }

        // 3) 中袋（下中 idx5=(0,+0.688)）正确摆位：cue 在 -z、target 居中、朝 +z 推。
        let tgtMid5 = SCNVector3(0.0, sY + r, 0.30)
        let cueMid5 = SCNVector3(0.0, sY + r, -0.20)
        for v in [Float(1.6), 2.4, 3.3, 4.4, 5.8] {
            report(String(format: "中袋idx5直 v%.1f", v), cue: cueMid5, target: tgtMid5, pocketIndex: 5, velocity: v, spinX: 0, spinY: 0)
        }
        // 上中 idx4=(0,-0.688)：cue 在 +z、target 居中、朝 -z 推。
        let tgtMid4 = SCNVector3(0.0, sY + r, -0.30)
        let cueMid4 = SCNVector3(0.0, sY + r, 0.20)
        for v in [Float(2.4), 3.3, 4.4] {
            report(String(format: "中袋idx4直 v%.1f", v), cue: cueMid4, target: tgtMid4, pocketIndex: 4, velocity: v, spinX: 0, spinY: 0)
        }

        // 4) 中袋切角（idx5，目标球偏一侧）。
        let tgtMidCut = SCNVector3(0.20, sY + r, 0.30)
        let cueMidCut = SCNVector3(-0.25, sY + r, -0.10)
        for v in [Float(2.4), 3.3, 4.4] {
            report(String(format: "中袋idx5切角 v%.1f", v), cue: cueMidCut, target: tgtMidCut, pocketIndex: 5, velocity: v, spinX: 0, spinY: 0)
        }
        print("===END-PROBE-POTTING===\n")
    }

    func test_probe_C_esolverLayout() {
        let sY = BTTablePhysics.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let target = SCNVector3(0.2, sY + r, -0.05)
        let pocketIndex = 1
        print("\n===PROBE-ESOLVER===")
        for cutDeg in [Float(0), 15, 30, 45, 55] {
            var row = String(format: "cut%2.0f° ", cutDeg)
            for v in [Float(2.4), 3.3, 4.4, 5.8] {
                let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
                let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: r)
                let pdx = pocket.x - target.x, pdz = pocket.z - target.z
                let pl = sqrtf(pdx * pdx + pdz * pdz)
                let pd = SCNVector3(pdx / pl, 0, pdz / pl)
                let th = cutDeg * .pi / 180
                let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0, pd.x * sinf(th) + pd.z * cosf(th))
                let cue = SCNVector3(ghost.x - strikeDir.x * 0.4, sY + r, ghost.z - strikeDir.z * 0.4)
                let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                                      velocity: v, spinX: 0, spinY: 0, surfaceY: sY)
                let pred = ShotPredictor.predict(input)
                row += String(format: "| v%.1f:%@", v, pred.simObjectPotted ? "进" : "✗")
            }
            print(row)
        }
        print("===END-PROBE-ESOLVER===\n")
    }

    // MARK: - D. 贴库球真实半径管道（球心线不扎库）

    /// 目标球贴库/准贴库时，`effectivePocketAimPoint` 允许相切，但管道半径不得小于球半径：
    /// 进球线必须存在且**不穿过所贴的库边**（沿库滚进袋是零余量合法物理）；
    /// 远离库的球仍用标准 3mm 余量，行为不变（正对袋心干净可过 ⇒ 进球点 = 袋心）。
    func test_probe_D_railFrozenAimClearance() {
        let sY = BTTablePhysics.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: sY)
        // 下长库击球面 z = +0.635，右下角袋 index 3。
        let railZ: Float = 0.635

        /// target→aim 线段与所贴库边内沿（z = railZ, x ∈ [0.073, 1.1671]）是否相交（扎库）。
        func crossesRail(target: SCNVector3, aim: SCNVector3) -> Bool {
            let dz = aim.z - target.z
            guard abs(dz) > 1e-7 else { return false }
            let t = (railZ - target.z) / dz
            guard t > 0, t < 1 else { return false }
            let x = target.x + t * (aim.x - target.x)
            return x > 0.073 && x < 1.1671
        }

        for (label, gap) in [("紧贴库", Float(0)), ("距库1.5mm", Float(0.0015))] {
            let target = SCNVector3(0.5, sY + r, railZ - r - gap)
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target, pocketIndex: 3, surfaceY: sY
            )
            let dPocket = hypotf(aim.x - pockets[3].x, aim.z - pockets[3].z)
            print(String(format: "PROBE-D %@: aim=(%.4f, %.4f) 距袋心=%.1fmm 扎库=%@",
                         label, aim.x, aim.z, dPocket * 1000,
                         crossesRail(target: target, aim: aim) ? "Y" : "N"))
            XCTAssertFalse(crossesRail(target: target, aim: aim),
                           "\(label)：进球线不得穿过所贴库边（应沿库滑入袋口）")
            // 进球点应落在袋口区域（喉口半幅 ~42mm + 孔半径），而非螺旋搜索被推远。
            XCTAssertLessThan(dPocket, 0.09, "\(label)：进球点被余量判定推离袋口过远")
        }

        // 控制组：远离库 + 正对下中袋（index 5）的干净直线球，标准余量行为不变 ⇒ 进球点 = 袋心。
        let free = SCNVector3(0.0, sY + r, 0.3)
        let aimFree = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: free, pocketIndex: 5, surfaceY: sY
        )
        XCTAssertLessThan(hypotf(aimFree.x - pockets[5].x, aimFree.z - pockets[5].z), 1e-4,
                          "远离库的球不应受贴库豁免影响")
    }

    private func report(_ label: String, cue: SCNVector3, target: SCNVector3, pocketIndex: Int,
                        velocity: Float, spinX: Float, spinY: Float) {
        let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                              velocity: velocity, spinX: spinX, spinY: spinY, surfaceY: BTTablePhysics.surfaceY)
        let pred = ShotPredictor.predict(input)
        // objMinDist：目标球轨迹到袋心最近距离（mm）——< 13.4mm 才算真进。
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: BTTablePhysics.surfaceY)[pocketIndex]
        var minD = Float.greatestFiniteMagnitude
        if let rec = pred.recorder, let frames = rec.framesByBallName[ShotInput.targetBallName] {
            for f in frames {
                let dx = f.position.x - pocket.x, dz = f.position.z - pocket.z
                minD = min(minD, sqrtf(dx * dx + dz * dz))
            }
        }
        print(String(format: "%@ | feasible=%@ simPotted=%@ cut=%.1f° objMinDist=%.1fmm cuePot=%@",
                     label, pred.feasible ? "Y" : "N", pred.simObjectPotted ? "Y" : "N",
                     pred.cutAngleDeg ?? -1, minD * 1000, pred.cuePocketed ? "Y" : "N"))
    }

    // MARK: - Helpers · 模型加载

    private func loadModelOrSkip() throws -> TableModelLoader.TableModel {
        guard let model = TableModelLoader.loadTable() else {
            throw XCTSkip("无法加载 TaiQiuZhuo.usdz（检查 Bundle 资源）")
        }
        return model
    }

    // MARK: - Helpers · 网格遍历

    private func allGeometryNodeCount(_ node: SCNNode) -> Int {
        var n = node.geometry != nil ? 1 : 0
        for c in node.childNodes { n += allGeometryNodeCount(c) }
        return n
    }

    /// 收集所有「非球」几何节点（球节点及其子树跳过）。
    private func collectGeometryNodes(_ node: SCNNode, isUnderBall: Bool, into result: inout [SCNNode]) {
        let underBall = isUnderBall || (node.name.map { ballNames.contains($0) } ?? false)
        if node.geometry != nil, !underBall { result.append(node) }
        for c in node.childNodes {
            collectGeometryNodes(c, isUnderBall: underBall, into: &result)
        }
    }

    /// 读取某几何节点的顶点并转换到世界坐标。
    private func worldVertices(of node: SCNNode) -> [SCNVector3] {
        guard let geometry = node.geometry,
              let source = geometry.sources(for: .vertex).first else { return [] }
        let count = source.vectorCount
        guard count > 0, source.componentsPerVector >= 3 else { return [] }
        let stride = source.dataStride
        let offset = source.dataOffset
        let bpc = source.bytesPerComponent
        let data = source.data

        var local = [SCNVector3]()
        local.reserveCapacity(count)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            for i in 0..<count {
                let p = base.advanced(by: offset + i * stride)
                if bpc == 4 {
                    let x = p.loadUnaligned(fromByteOffset: 0, as: Float32.self)
                    let y = p.loadUnaligned(fromByteOffset: 4, as: Float32.self)
                    let z = p.loadUnaligned(fromByteOffset: 8, as: Float32.self)
                    local.append(SCNVector3(x, y, z))
                } else if bpc == 8 {
                    let x = p.loadUnaligned(fromByteOffset: 0, as: Float64.self)
                    let y = p.loadUnaligned(fromByteOffset: 8, as: Float64.self)
                    let z = p.loadUnaligned(fromByteOffset: 16, as: Float64.self)
                    local.append(SCNVector3(Float(x), Float(y), Float(z)))
                }
            }
        }

        let wt = node.worldTransform
        return local.map { v in
            SCNVector3(
                wt.m11 * v.x + wt.m21 * v.y + wt.m31 * v.z + wt.m41,
                wt.m12 * v.x + wt.m22 * v.y + wt.m32 * v.z + wt.m42,
                wt.m13 * v.x + wt.m23 * v.y + wt.m33 * v.z + wt.m43
            )
        }
    }

    private struct BBox {
        var minX, maxX, minY, maxY, minZ, maxZ: Float
    }

    private func boundingBox(_ verts: [SCNVector3]) -> BBox {
        var b = BBox(minX: .greatestFiniteMagnitude, maxX: -.greatestFiniteMagnitude,
                     minY: .greatestFiniteMagnitude, maxY: -.greatestFiniteMagnitude,
                     minZ: .greatestFiniteMagnitude, maxZ: -.greatestFiniteMagnitude)
        for v in verts {
            b.minX = min(b.minX, v.x); b.maxX = max(b.maxX, v.x)
            b.minY = min(b.minY, v.y); b.maxY = max(b.maxY, v.y)
            b.minZ = min(b.minZ, v.z); b.maxZ = max(b.maxZ, v.z)
        }
        return b
    }

    private func printYHistogram(_ verts: [SCNVector3], around surfaceY: Float) {
        // 在 surfaceY ± 0.1m 范围内以 5mm 分箱统计顶点数。
        let lo = surfaceY - 0.06
        let hi = surfaceY + 0.10
        let binW: Float = 0.005
        let bins = Int(((hi - lo) / binW).rounded(.up))
        var counts = [Int](repeating: 0, count: max(bins, 1))
        for v in verts where v.y >= lo && v.y < hi {
            let idx = min(counts.count - 1, max(0, Int((v.y - lo) / binW)))
            counts[idx] += 1
        }
        print("Y 直方图（surfaceY-0.06 .. +0.10，5mm/箱，仅打印非空箱）：")
        for (i, c) in counts.enumerated() where c > 0 {
            let yLo = lo + Float(i) * binW
            print(String(format: "  y=[%.3f,%.3f)  rel=%+.3f  n=%d", yLo, yLo + binW, yLo - surfaceY, c))
        }
    }
}

extension TableGeometryProbeTests {
    private func bedContains(_ point: SIMD2<Double>, surface: TableAssistSurface) -> Bool {
        surface.triangles.contains { t in
            let c = (0..<3).map { i -> Double in
                let d = t[(i+1)%3]-t[i], v = point-t[i]
                return d.x*v.y-d.y*v.x
            }
            return c.allSatisfy { $0 >= -1e-12 } || c.allSatisfy { $0 <= 1e-12 }
        }
    }

    @MainActor
    func testMeasuredCaptureLipMatchesExposedCloth() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let surface = try TableAssistSurface.load(from: scene)
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: scene.surfaceY)
        for pocket in geometry.pockets {
            XCTAssertGreaterThan(pocket.captureLip.count, 10)
            for i in pocket.captureLip.indices {
                let a = pocket.captureLip[i], b = pocket.captureLip[(i+1)%pocket.captureLip.count]
                let d = b-a, length = sqrt(d.x*d.x+d.y*d.y), mid = (a+b)/2
                let n = SIMD2(-d.y/length,d.x/length)
                // The single back chord closes the collector inside the opening.
                if length > 0.04 { continue }
                XCTAssertFalse(bedContains(mid+n*0.00002, surface: surface), "\(pocket.id) edge \(i) inside must be open")
                XCTAssertTrue(bedContains(mid-n*0.00002, surface: surface), "\(pocket.id) edge \(i) outside must be cloth")
            }
        }
    }

    @MainActor
    func testSlowRollAcrossClothLipPotsButSupportedStopDoesNot() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let surface = try TableAssistSurface.load(from: scene)
        let sy = scene.surfaceY, r = BallPhysics.radius
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sy)
        for (index, pocket) in geometry.pockets.enumerated() {
            for angle:Float in [-5,0,5] {
            let inward = SCNVector3(index < 4 ? (pocket.center.x > 0 ? -1:1):0, 0,
                                   pocket.center.z > 0 ? -1:1).normalized().rotatedY(angle * .pi / 180)
            func radial(_ d: Float) -> SCNVector3 {
                SCNVector3(pocket.center.x+inward.x*d, sy+r, pocket.center.z+inward.z*d)
            }
            var lo: Float = 0, hi: Float = 0.2
            for _ in 0..<28 {
                let m=(lo+hi)/2, p=radial(m)
                if bedContains(SIMD2(Double(p.x),Double(p.z)),surface:surface) { hi=m } else { lo=m }
            }
            let edge=(lo+hi)/2
            for overshoot: Float in [-0.002,0.002,0.012,0.05] {
                for dense in [false,true] {
                    let speed=sqrtf(2*SpinPhysics.rollingFriction*9.81*(0.05+overshoot))
                    let v=inward * -speed
                    let engine=EventDrivenEngine(tableGeometry:geometry)
                    engine.setBall(BallState(position:radial(edge+0.05),velocity:v,
                        angularVelocity:SCNVector3(0,1,0).cross(v)*(1/r),state:.rolling,name:"object"))
                    XCTAssertEqual(engine.simulatePrediction(model:.appDefault,maxEvents:500,maxTime:15,highFidelityBounds:dense),.settled)
                    let ball=try XCTUnwrap(engine.getBall("object"))
                    XCTAssertEqual(ball.isPocketed,overshoot>0,"\(pocket.id) overshoot \(overshoot), dense \(dense)")
                    if overshoot>0 {
                        let entry=try XCTUnwrap(engine.getTrajectoryRecorder().pocketEntries.first)
                        XCTAssertEqual(entry.pocketID,pocket.id)
                        XCTAssertEqual(engine.getTrajectoryRecorder().pocketEntries.count,1)
                        let entryD=hypotf(entry.ball.position.x-pocket.center.x,entry.ball.position.z-pocket.center.z)
                        XCTAssertEqual(entryD,edge,accuracy:0.00001)
                        let playback=TrajectoryPlayback(recorder:engine.getTrajectoryRecorder(),surfaceY:sy+r)
                        let falling=try XCTUnwrap(playback.stateAt(ballName:"object",time:entry.time+0.08))
                        XCTAssertLessThan(falling.position.y,sy+r-0.001,"Captured ball must visibly descend")
                    }
                }
            }
            }
        }
    }
}

extension TableGeometryProbeTests {
    func testTouchingRailContactResolvesAtZeroWithoutReflectingSeparatingBall() throws {
        let r=Double(BallPhysics.radius)
        let n=SCNVector3(0,0,-1), offset=Double(-Float(0.635))
        let p=SCNVector3(0.5,0.828575,Float(0.635)-BallPhysics.radius)
        let incoming=CollisionDetector.ballLinearCushionTime(p:p,v:SCNVector3(1,0,0.024540592),a:SCNVector3Zero,
            lineNormal:n,lineOffset:offset,R:r,maxTime:1)
        XCTAssertEqual(try XCTUnwrap(incoming),0)
        XCTAssertNil(CollisionDetector.ballLinearCushionTime(p:p,v:SCNVector3(1,0,-0.024540592),a:SCNVector3Zero,
            lineNormal:n,lineOffset:offset,R:r,maxTime:1))
        XCTAssertNil(CollisionDetector.ballLinearCushionTime(p:p,v:SCNVector3(1,0,0),a:SCNVector3Zero,
            lineNormal:n,lineOffset:offset,R:r,maxTime:1))
        let delayed=CollisionDetector.ballLinearCushionTime(p:SCNVector3(p.x,p.y,p.z-0.00001),v:SCNVector3(1,0,0.024540592),a:SCNVector3Zero,
            lineNormal:n,lineOffset:offset,R:r,maxTime:1)
        XCTAssertGreaterThan(try XCTUnwrap(delayed),0.0003)
        // Double inputs keep real sub-microsecond roots instead of rounding them to zero.
        let exact=CollisionDetector.ballLinearCushionTime(p:SIMD3(0,0,r+1e-9),v:SIMD3(0,0,-0.02),a:.zero,
            lineNormal:SIMD3(0,0,1),lineOffset:0,R:r,maxTime:1)
        XCTAssertEqual(Double(try XCTUnwrap(exact)),5e-8,accuracy:1e-12)
    }

    func testFrozenBallRecordsRealRailImpactAndSettles() throws {
        let sy:Float=0.8,r=BallPhysics.radius
        let geo=TableGeometry.chineseEightBallQiuJi(surfaceY:sy)
        for sign:Float in [-1,1] {
            let engine=EventDrivenEngine(tableGeometry:geo)
            let v=SCNVector3(0.3,0,sign*0.024540592)
            engine.setBall(BallState(position:SCNVector3(0.5,sy+r,sign*(0.635-r)),velocity:v,
                angularVelocity:SCNVector3(0,1,0).cross(v)*(1/r),state:.rolling,name:"object"))
            XCTAssertEqual(engine.simulatePrediction(model:.appDefault,maxEvents:500,maxTime:15,highFidelityBounds:true),.settled)
            let hits=zip(engine.resolvedEvents,engine.resolvedEventTimes).filter {
                if case .ballCushion(let ball,let index,_)=$0.0 { return ball=="object" && index<6 }
                return false
            }
            XCTAssertEqual(hits.count,1)
            XCTAssertEqual(try XCTUnwrap(hits.first).1,0)
            let final=try XCTUnwrap(engine.getBall("object"))
            XCTAssertLessThan(abs(final.position.z),0.635-r)
        }
    }
}


extension TableGeometryProbeTests {
    func testFrozenAimKeepsFullRadiusBeforeCapture() throws {
        let sy: Float = 0.8, r = BallPhysics.radius
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: sy)
        for index in 0..<4 {
            let sx: Float = index % 2 == 0 ? -1 : 1
            let sz: Float = index < 2 ? -1 : 1
            for shortRail in [false, true] {
                let origin = shortRail ? SCNVector3(sx*(1.27-r),sy+r,sz*0.2)
                    : SCNVector3(sx*0.5,sy+r,sz*(0.635-r))
                let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall:origin,pocketIndex:index,surfaceY:sy)
                let dir = (aim-origin).normalized()
                let t = (aim-origin).length()
                for i in 0...200 {
                    let p = origin + dir*(t*Float(i)/200)
                    // Main cushion finite extent: outside its end, the jaw handles clearance.
                    if !shortRail && abs(p.x) <= 1.1671 {
                        XCTAssertGreaterThanOrEqual(0.635-abs(p.z),r-0.000001)
                    } else if shortRail && abs(p.z) <= 0.5321 {
                        XCTAssertGreaterThanOrEqual(1.27-abs(p.x),r-0.000001)
                    }
                }
                let v=dir*0.8, engine=EventDrivenEngine(tableGeometry:geometry)
                engine.setBall(BallState(position:origin,velocity:v,
                    angularVelocity:SCNVector3(0,1,0).cross(v)*(1/r),state:.rolling,name:"object"))
                XCTAssertEqual(engine.simulatePrediction(model:.appDefault,maxEvents:500,maxTime:15,highFidelityBounds:true),.settled)
                XCTAssertTrue(try XCTUnwrap(engine.getBall("object")).isPocketed,"pocket \(index), short \(shortRail), aim \(aim)")
                XCTAssertFalse(engine.resolvedEvents.contains {
                    if case .ballCushion(let name,let index,_)=$0 { return name=="object" && index<6 };return false
                },"Straight frozen aim must not hit the main cushion")
            }
        }
    }

    func testPreviouslyMissedFrozenSolverShot() throws {
        let sy:Float=0.8,r=BallPhysics.radius
        let input=ShotInput(cueBall:SCNVector3(0.45,sy+r,0.306425),
            targetBall:SCNVector3(0.95,sy+r,0.635-r),pocketIndex:3,
            velocity:0.8,spinX:0,spinY:0,surfaceY:sy)
        let prediction=ShotPredictor.predictForPositionSolve(input)
        print("FROZEN-SOLVE potted=\(prediction.objectPocketed) offset=\(prediction.aimOffsetUsed) before=\(prediction.cueCushionsBeforeContact)")
        XCTAssertTrue(prediction.objectPocketed)
        XCTAssertEqual(prediction.cueCushionsBeforeContact,0)
    }
}

extension TableGeometryProbeTests {
    func testNarrowRailAimWindowsAndFrozenOffsetReplay() throws {
        let sy:Float=0.8,r=BallPhysics.radius
        let cases:[(Float,Float,Float)]=[(0.17145,0.005,2.4),(0.5,0.0015,0.8),
            (0.95,0,0.8),(0.95,0.0015,2.4),(0.95,0.0015,3.3),
            (0.95,0.005,2.4),(0.95,0.005,3.3)]
        for (x,gap,speed) in cases {
            let target=SCNVector3(x,sy+r,0.635-r-gap)
            let input=ShotInput(cueBall:target+SCNVector3(-0.5,0,-0.3),targetBall:target,
                pocketIndex:3,velocity:speed,spinX:0,spinY:0,surfaceY:sy)
            let solved=ShotPredictor.predictForPositionSolve(input)
            XCTAssertTrue(solved.objectPocketed,"x \(x) gap \(gap) speed \(speed)")
            XCTAssertTrue(solved.hasFinalTableState)
            XCTAssertEqual(solved.cueCushionsBeforeContact,0)
            var seed=ShotPrediction()
            let context=try XCTUnwrap(ShotPredictor.prepareAim(input,into:&seed))
            let initialOffset=ShotPredictor.positionAimOffset(input:input,context:context)
            if solved.aimOffsetUsed != initialOffset {
                XCTAssertTrue(solved.objectRailContacts.isEmpty,"A new fallback must not introduce a bank")
            }
            // 原方向已经真实进袋时不替换它。既有贴库局面可能在真实碰球之后擦库，
            // 这与纯目标球沿理想线发射的几何净空断言是两个不同的测试。
            print("RAIL-REPLAY x=\(x) gap=\(gap) v=\(speed) rails=\(solved.objectRailContacts) adjusted=\(solved.aimOffsetUsed != initialOffset)")
            let offset=try XCTUnwrap(solved.aimOffsetUsed)
            let replay=ShotPredictor.predictForPositionSolve(input,aimOffset:offset)
            XCTAssertTrue(replay.objectPocketed)
            XCTAssertEqual(replay.aimOffsetUsed,offset)
            XCTAssertEqual(replay.duration,solved.duration)
            let scoring=ShotPredictor.predictForPositionSolve(input,aimOffset:offset,includePresentation:false)
            XCTAssertTrue(scoring.objectPocketed)
        }
    }
}

extension TableGeometryProbeTests {
    func testPocketMouthDoesNotReflectAtExtendedMainRail() throws {
        let sy:Float=0.8,r=BallPhysics.radius
        let input=ShotInput(cueBall:SCNVector3(0.17239821,sy+r,0.41960132),
            targetBall:SCNVector3(0.8271203,sy+r,0.50750744),pocketIndex:3,
            velocity:1.8187602,spinX:-0.20291474,spinY:-0.2133288,surfaceY:sy,
            obstacles:[ObstacleBall(name:"_2",position:SCNVector3(0.4836477,sy+r,-0.08534384)),
                       ObstacleBall(name:"_3",position:SCNVector3(-0.53976476,sy+r,0.26544726)),
                       ObstacleBall(name:"_4",position:SCNVector3(-0.48108935,sy+r,0.38356507)),
                       ObstacleBall(name:"_5",position:SCNVector3(0.20803809,sy+r,0.09528941))])
        let offset:Float=0.012629199
        let full=ShotPredictor.predictForPositionSolve(input,aimOffset:offset)
        XCTAssertTrue(full.objectPocketed)
        XCTAssertEqual(full.objectCushionCount,0,"Mouth beyond finite main rail must stay open")
        var seed=ShotPrediction()
        let context=try XCTUnwrap(ShotPredictor.prepareAim(input,into:&seed))
        let fast=AnalyticShotRollout.evaluate(aimDir:context.aimDir.rotatedY(offset),velocity:input.velocity,
            input:input,geometry:context.geometry,ghost:context.ghost)
        XCTAssertFalse(fast.needsFullSim)
        XCTAssertEqual(fast.pottedSelected,full.objectPocketed)
    }
}

extension TableGeometryProbeTests {
    /// Full sphere / production-loaded triangles, including finite arc endpoints.
    /// An asset update must keep this contact envelope aligned with the physics
    /// specification rather than recalibrating physics to a visual import error.
    func testCalibratedCushionWholeSphereContactEnvelope() throws {
        let asset = try PocketGeometryAsset.load()
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: asset.surfaceY)
        let roles = try PocketSurfaceRoles.classify(asset.tablePatches, surfaceY: asset.surfaceY)
        let triangles = asset.tablePatches.indices.filter { roles[$0] != .clothBed }
            .map { asset.tablePatches[$0].triangle }
        let index = PocketContactIndex(triangles: triangles)
        let r = Double(BallPhysics.radius), y = Double(asset.surfaceY) + r
        var count = 0, maximum = 0.0
        func check(_ p: SIMD3<Double>, label: String) {
            let position = SCNVector3(Float(p.x), Float(p.y), Float(p.z))
            guard !geometry.pockets.contains(where: { $0.containsCapture(position) }) else { return }
            // Discard nominal witnesses inside another finite solid: they are
            // not reachable contacts in the shared planar model.
            guard !EngineNumerics.planarIntrusions(position: position, geometry: geometry)
                .contains(where: { $0.depth > 0.000001 }) else { return }
            let pad = SIMD3<Double>(repeating: r + 0.01)
            var distance = Double.infinity
            for i in index.query(low: p - pad, high: p + pad) {
                let d = p - triangles[i].closestPoint(to: p)
                distance = min(distance, sqrt(d.x*d.x + d.y*d.y + d.z*d.z))
            }
            let error = distance - r
            XCTAssertLessThanOrEqual(abs(error), 0.0001, "\(label): \(error * 1000)mm")
            maximum = max(maximum, abs(error)); count += 1
        }
        for (i, arc) in geometry.circularCushions.enumerated() {
            let start = Double(arc.startAngle)
            let end = Double(arc.endAngle) + (arc.endAngle < arc.startAngle ? 2 * Double.pi : 0)
            for k in 0...64 {
                let angle = start + (end - start) * Double(k) / 64
                let n = SIMD3<Double>(cos(angle), 0, sin(angle))
                let center = SIMD3<Double>(Double(arc.center.x), y, Double(arc.center.z))
                check(center + n * (Double(arc.radius) + r), label: "arc \(i), \(k)/64")
            }
        }
        for (i, wall) in geometry.linearCushions.prefix(6).enumerated() {
            let a = SIMD3<Double>(Double(wall.start.x), y, Double(wall.start.z))
            let b = SIMD3<Double>(Double(wall.end.x), y, Double(wall.end.z))
            let n = SIMD3<Double>(Double(wall.normal.x), 0, Double(wall.normal.z))
            for k in 0...20 { check(a + (b-a) * (Double(k)/20) + n*r, label: "main \(i), \(k)/20") }
        }
        XCTAssertGreaterThan(count, 700)
        print("[CALIBRATED-ENVELOPE] supported witnesses=\(count), maximum absolute error=\(maximum*1000)mm")
    }
}
