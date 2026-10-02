import ImageIO
import UniformTypeIdentifiers
import UIKit

/// 把一组帧编码成 GIF（ADR-P11-01，走位序列分享用）。
enum GIFEncoder {

    enum GIFError: Error {
        case cannotCreateDestination
        case finalizeFailed
    }

    /// 把 `frames` 写成 GIF。`frameDelay` 为每帧停留秒数（建议 1/12 ~ 1/15）。
    static func encode(frames: [CGImage], to url: URL, frameDelay: Double = 1.0 / 12.0, loop: Int = 0) throws {
        try? FileManager.default.removeItem(at: url)
        guard !frames.isEmpty,
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
              ) else {
            throw GIFError.cannotCreateDestination
        }

        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loop
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GIFError.finalizeFailed
        }
    }
}
