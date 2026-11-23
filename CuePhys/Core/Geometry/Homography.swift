//
//  Homography.swift
//  QiuJi
//
//  平面单应变换（projective transform）：把「图像里台面平面上的点」映射到
//  归一化台面系（CanvasPoint x∈[0,1] 左→右、y∈[0,0.5] 上→下，俯视 2:1）。
//
//  坐标契约（P15 / ADR-P15-01）：
//  - **源系**：图像归一化 uv ∈ [0,1]×[0,1]（占图比例，与显示尺寸无关）。
//  - **目标系**：归一化台面系（与 `CanvasPoint` / `table-geometry.md` 一致）。
//  - 四点对应顺序固定：`[对应单位方块 (0,0),(1,0),(1,1),(0,1)]`，即
//    **台面左上 → 右上 → 右下 → 左下**。
//
//  方法：Heckbert「Projective Mappings for Image Warping」square→quad 闭式解，
//  H = squareToQuad(dest) · squareToQuad(src)⁻¹。无需 SVD/迭代，只用 3×3 求逆。
//  H 只对**台面平面上的点**精确——球心高出台面 28.575mm，斜拍下存在视差，
//  调用方须用「球底接触点」而非「球图像圆心」过 H（见 P15 阶段 2 备注）。
//

import CoreGraphics
import simd

/// 平面单应变换。`matrix` 把源系齐次点 (x,y,1) 映到目标系齐次点。
struct Homography {
    let matrix: simd_double3x3

    /// 单位方块四角对应「目标系矩形」的顺序：左上/右上/右下/左下。
    /// = 归一化台面四角（2:1 俯视，y 上限 0.5）。
    static let tableCorners: [CGPoint] = [
        CGPoint(x: 0, y: 0),       // 左上
        CGPoint(x: 1, y: 0),       // 右上
        CGPoint(x: 1, y: 0.5),     // 右下
        CGPoint(x: 0, y: 0.5)      // 左下
    ]

    /// 应用变换：源系点 → 目标系点（含透视除法）。
    func apply(_ p: CGPoint) -> CGPoint {
        let v = matrix * simd_double3(Double(p.x), Double(p.y), 1)
        guard abs(v.z) > 1e-12 else { return .zero }
        return CGPoint(x: CGFloat(v.x / v.z), y: CGFloat(v.y / v.z))
    }

    /// 逆变换（目标系 → 源系），用于把识别结果回投到照片上绘制。
    var inverse: Homography { Homography(matrix: matrix.inverse) }

    /// 四点对应求解。`source[i]` → `dest[i]`，顺序须为对应单位方块
    /// (0,0),(1,0),(1,1),(0,1)（即左上/右上/右下/左下）。
    /// 任一四边形退化（三点共线 / 自交致不可逆）时返回 nil。
    static func solve(source: [CGPoint], dest: [CGPoint]) -> Homography? {
        guard source.count == 4, dest.count == 4,
              let hs = squareToQuad(source), let hd = squareToQuad(dest),
              abs(simd_determinant(hs)) > 1e-12 else { return nil }
        return Homography(matrix: hd * hs.inverse)
    }

    /// 单位方块 (0,0),(1,0),(1,1),(0,1) → 任意四边形 `q` 的单应矩阵。
    private static func squareToQuad(_ q: [CGPoint]) -> simd_double3x3? {
        let x0 = Double(q[0].x), y0 = Double(q[0].y)
        let x1 = Double(q[1].x), y1 = Double(q[1].y)
        let x2 = Double(q[2].x), y2 = Double(q[2].y)
        let x3 = Double(q[3].x), y3 = Double(q[3].y)

        let dx1 = x1 - x2, dx2 = x3 - x2, sx = x0 - x1 + x2 - x3
        let dy1 = y1 - y2, dy2 = y3 - y2, sy = y0 - y1 + y2 - y3

        let a, b, c, d, e, f, g, h: Double
        if abs(sx) < 1e-12 && abs(sy) < 1e-12 {
            // 仿射特例（四边形是平行四边形）。
            a = x1 - x0; b = x2 - x1; c = x0
            d = y1 - y0; e = y2 - y1; f = y0
            g = 0; h = 0
        } else {
            let denom = dx1 * dy2 - dx2 * dy1
            guard abs(denom) > 1e-12 else { return nil }
            g = (sx * dy2 - dx2 * sy) / denom
            h = (dx1 * sy - sx * dy1) / denom
            a = x1 - x0 + g * x1
            b = x3 - x0 + h * x3
            c = x0
            d = y1 - y0 + g * y1
            e = y3 - y0 + h * y3
            f = y0
        }
        // 行式 [a b c; d e f; g h 1] 作用于 (u,v,1)；simd 列主序逐列填入。
        return simd_double3x3(
            simd_double3(a, d, g),
            simd_double3(b, e, h),
            simd_double3(c, f, 1)
        )
    }

    // MARK: - 自检不变量（坐标契约护栏）

    /// 把源四角用本变换映回目标系，与期望目标点的最大残差（用于标定质量自检）。
    func cornerResidual(source: [CGPoint], dest: [CGPoint]) -> CGFloat {
        guard source.count == dest.count else { return .greatestFiniteMagnitude }
        var maxErr: CGFloat = 0
        for (s, d) in zip(source, dest) {
            let m = apply(s)
            maxErr = max(maxErr, hypot(m.x - d.x, m.y - d.y))
        }
        return maxErr
    }
}
