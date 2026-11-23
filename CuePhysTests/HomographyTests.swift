//
//  HomographyTests.swift
//  QiuJiTests
//
//  P15 拍照建球形——单应变换坐标契约护栏。
//

import XCTest
import CoreGraphics
@testable import QiuJi

final class HomographyTests: XCTestCase {

    private let table = Homography.tableCorners  // 左上/右上/右下/左下

    /// 恒等：源四角 == 台面四角时，任意点原样映射。
    func test_identityWhenSourceEqualsTable() throws {
        let h = try XCTUnwrap(Homography.solve(source: table, dest: table))
        for p in [CGPoint(x: 0.3, y: 0.2), CGPoint(x: 0.7, y: 0.45), CGPoint(x: 0.5, y: 0.25)] {
            let m = h.apply(p)
            XCTAssertEqual(m.x, p.x, accuracy: 1e-9)
            XCTAssertEqual(m.y, p.y, accuracy: 1e-9)
        }
    }

    /// 四角精确落位：源四角必映射到目标四角（残差 ≈ 0）。
    func test_cornersMapExactly() throws {
        // 一个典型「斜拍」梯形：上边窄、下边宽（远端被透视压缩）。
        let src = [
            CGPoint(x: 0.30, y: 0.18),  // 左上
            CGPoint(x: 0.72, y: 0.18),  // 右上
            CGPoint(x: 0.92, y: 0.88),  // 右下
            CGPoint(x: 0.08, y: 0.88)   // 左下
        ]
        let h = try XCTUnwrap(Homography.solve(source: src, dest: table))
        XCTAssertLessThan(h.cornerResidual(source: src, dest: table), 1e-9)
    }

    /// 往返：H 与 H⁻¹ 复合后回到原点（精度 < 1e-9）。
    func test_roundTripThroughInverse() throws {
        let src = [
            CGPoint(x: 0.25, y: 0.20),
            CGPoint(x: 0.80, y: 0.15),
            CGPoint(x: 0.95, y: 0.90),
            CGPoint(x: 0.10, y: 0.82)
        ]
        let h = try XCTUnwrap(Homography.solve(source: src, dest: table))
        let inv = h.inverse
        for p in src + [CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.6, y: 0.33)] {
            let back = inv.apply(h.apply(p))
            XCTAssertEqual(back.x, p.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, p.y, accuracy: 1e-9)
        }
    }

    /// 透视单调性：源四边形内部中点映射应落在台面矩形内 [0,1]×[0,0.5]。
    func test_midpointStaysInsideTable() throws {
        let src = [
            CGPoint(x: 0.30, y: 0.18),
            CGPoint(x: 0.72, y: 0.18),
            CGPoint(x: 0.92, y: 0.88),
            CGPoint(x: 0.08, y: 0.88)
        ]
        let h = try XCTUnwrap(Homography.solve(source: src, dest: table))
        // 源四边形的形心。
        let cx = src.map(\.x).reduce(0, +) / 4
        let cy = src.map(\.y).reduce(0, +) / 4
        let m = h.apply(CGPoint(x: cx, y: cy))
        XCTAssertGreaterThanOrEqual(m.x, 0)
        XCTAssertLessThanOrEqual(m.x, 1)
        XCTAssertGreaterThanOrEqual(m.y, 0)
        XCTAssertLessThanOrEqual(m.y, 0.5)
    }

    /// 退化四边形（三点共线）应返回 nil，而非产出垃圾矩阵。
    func test_degenerateQuadReturnsNil() {
        let collinear = [
            CGPoint(x: 0.1, y: 0.1),
            CGPoint(x: 0.2, y: 0.2),
            CGPoint(x: 0.3, y: 0.3),   // 与前两点共线
            CGPoint(x: 0.0, y: 0.5)
        ]
        XCTAssertNil(Homography.solve(source: collinear, dest: table))
    }
}
