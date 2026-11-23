import XCTest
import SwiftUI
@testable import QiuJi

final class TrainingAtmosphereTests: XCTestCase {
    func testLocalTimeBoundariesAndMidnight() throws {
        for zone in ["Asia/Shanghai", "America/Los_Angeles"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            let cases: [(Int, Int, TrainingDaypart)] = [
                (0, 0, .evening), (5, 59, .evening), (6, 0, .morning),
                (10, 59, .morning), (11, 0, .day), (17, 59, .day),
                (18, 0, .evening), (23, 59, .evening)
            ]
            for (hour, minute, expected) in cases {
                let date = try XCTUnwrap(calendar.date(from: DateComponents(
                    year: 2026, month: 9, day: 9, hour: hour, minute: minute)))
                XCTAssertEqual(TrainingDaypart.resolve(at: date, calendar: calendar), expected,
                               "\(zone) \(hour):\(minute)")
            }
        }
    }

    @MainActor
    func testEveryDefaultGameHasCorrectTerminalBallAndBundledArt() {
        for game in DailyClearanceGame.allCases {
            let expected = game == .chineseEightBall ? "profileBall8" : "profileBall9"
            XCTAssertEqual(BTProfileGameBall.assetName(for: game), expected)
            XCTAssertNotNil(UIImage(named: expected))
        }
        for part in TrainingDaypart.allCases {
            XCTAssertNotNil(UIImage(named: part.assetName))
        }
        XCTAssertNotNil(UIImage(named: "profileCrown"))
    }

    func testProfileBallFollowsMainSportEvenWhenDailyGameWasOverridden() {
        XCTAssertEqual(BTProfileGameBall.assetName(for: .chinese8, fallback: .nineBall), "profileBall8")
        XCTAssertEqual(BTProfileGameBall.assetName(for: .nineBall, fallback: .chineseEightBall), "profileBall9")
        XCTAssertEqual(BTProfileGameBall.assetName(for: .both, fallback: .nineBall), "profileBall9")
        XCTAssertEqual(BTProfileGameBall.assetName(for: .both, fallback: .chineseEightBall), "profileBall8")
    }

    @MainActor
    func testCrownedBallsMatchChosenScaleWithoutClipping() throws {
        for sport in [PreferredSport.chinese8, .nineBall] {
            var bounds: [ClosedRange<Int>] = []
            for premium in [false, true] {
                // Include the card's optical overflow when inspecting rendered ink.
                let renderer = ImageRenderer(content: BTProfileGameBall(sport: sport, isPremium: premium).padding(8))
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                let cg = try XCTUnwrap(image.cgImage)
                XCTAssertEqual(cg.width, 228)
                XCTAssertEqual(cg.height, 228)
                var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
                let visibleRows: [Int] = try bytes.withUnsafeMutableBytes { buffer in
                    let ctx = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                        bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
                    return (0..<cg.height).filter { y in
                        (0..<cg.width).contains { x in buffer[(y * cg.width + x) * 4 + 3] > 8 }
                    }
                }
                bounds.append(try XCTUnwrap(visibleRows.first)...XCTUnwrap(visibleRows.last))
                XCTAssertGreaterThan(try XCTUnwrap(visibleRows.first), 0)
                XCTAssertLessThan(try XCTUnwrap(visibleRows.last), cg.height - 1)
                let shot = XCTAttachment(image: image)
                shot.name = "profile-ball-\(sport.rawValue)-\(premium ? "pro" : "free")"
                shot.lifetime = .keepAlways
                add(shot)
            }
            // User approved a taller crown on 2026-10-19: retain ball size and crown aspect.
            XCTAssertTrue((212...224).contains(bounds[1].count), "Pro art must match the selected visual scale")
            XCTAssertTrue((148...157).contains(bounds[0].count), "Free ball retains its original visible size")
        }
    }

    @MainActor
    func testProUnlockTextContrastInBothAppearances() throws {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let linear = [r, g, b].map { value -> Double in
                let v = Double(value)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return zip(linear, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
        }
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: appearance)
            let foreground = try XCTUnwrap(UIColor(named: "btProButtonForeground")).resolvedColor(with: traits)
            let background = try XCTUnwrap(UIColor(named: "btProButtonBackground")).resolvedColor(with: traits)
            let f = luminance(foreground), b = luminance(background)
            XCTAssertGreaterThanOrEqual((max(f, b) + 0.05) / (min(f, b) + 0.05), 4.5)
        }
    }

    @MainActor
    func testProUnlockNativeSurfaceGallery() throws {
        func capture<V: View>(_ view: V, name: String, scheme: ColorScheme) throws {
            let renderer = ImageRenderer(content: view.frame(width: 360).padding(16)
                .background(Color.btBGSecondary).environment(\.colorScheme, scheme))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = "pro-unlock-" + name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        for scheme in [ColorScheme.light, .dark] {
            let name = scheme == .light ? "light" : "dark"
            try capture(VStack(spacing: 16) {
                Button {} label: { BTProUnlockLabel() }.buttonStyle(BTButtonStyle.goldFilled)
                BTAdaptiveToolLimitGate(onUnlock: {})
                BTAdaptiveToolLimitGate(compact: true, onUnlock: {})
                BTPremiumLock(mode: .fullMask) { Color.clear.frame(height: 320) }
                Button {} label: {
                    HStack { BTProfileCrown(width: 32); Text("解锁 Pro · ¥128.00 / 每年") }
                }.buttonStyle(ProBrandButtonStyle())
            }, name: "document-" + name, scheme: scheme)
            try capture(VStack(spacing: 16) {
                BTDailyLimitGate(onUnlock: {})
                BTDailyLimitGate(onUnlock: {}, compact: true)
            }.padding(12).background(Color.black), name: "scene-" + name, scheme: scheme)
        }
    }

}
