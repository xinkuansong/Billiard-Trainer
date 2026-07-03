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
