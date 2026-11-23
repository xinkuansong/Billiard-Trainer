import ImageIO
import UniformTypeIdentifiers
import UIKit
import Darwin

/// 把一组帧编码成 GIF（ADR-P11-01，走位序列分享用）。
enum GIFEncoder {

    enum GIFError: Error {
        case cannotCreateDestination
        case finalizeFailed
    }

    /// 把 `frames` 写成 GIF。`frameDelay` 为每帧停留秒数（建议 1/12 ~ 1/15）。
    static func encode(frames: [CGImage], to url: URL, frameDelay: Double = 1.0 / 12.0, loop: Int = 0) throws {
        try encode(frameCount: frames.count, to: url, frameDelay: frameDelay, loop: loop) { frames[$0] }
    }

    /// The producer can decode one frame at a time instead of retaining a movie.
    static func encode(frameCount: Int, to url: URL, frameDelay: Double = 1.0 / 12.0,
                       loop: Int = 0, frame: (Int) throws -> CGImage) throws {
        let directory = url.deletingLastPathComponent().appendingPathComponent(".qiuji-gif-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let temporary = directory.appendingPathComponent("output.gif")
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { NSLog("GIF cleanup failed: %@", String(describing: error)) }
        }
        try autoreleasepool {
            try write(frameCount: frameCount, to: temporary, frameDelay: frameDelay, loop: loop, frame: frame)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: url)
        }
    }

    private static func write(frameCount: Int, to temporary: URL, frameDelay: Double,
                              loop: Int, frame: (Int) throws -> CGImage) throws {
        guard frameCount > 0,
              let destination = CGImageDestinationCreateWithURL(
                temporary as CFURL, UTType.gif.identifier as CFString, frameCount, nil
              ) else { throw GIFError.cannotCreateDestination }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFLoopCount: loop]] as CFDictionary)
        let properties = [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFDelayTime: frameDelay]] as CFDictionary
        for index in 0..<frameCount {
            try Task.checkCancellation()
            try autoreleasepool {
                // ImageIO keeps inputs until finalize. Give it read-only file-backed
                // provider bytes, not a decoded movie in private anonymous memory.
                // Keep the SAME multi-frame destination so palette quantization,
                // transparency, frame timing and output colours remain unchanged.
                let image = try frame(index)
                let rawURL = temporary.deletingLastPathComponent().appendingPathComponent("frame-\(index).raw")
                let mapped = try fileBackedImage(image, at: rawURL)
                CGImageDestinationAddImage(destination, mapped, properties)
            }
        }
        try Task.checkCancellation()
        guard CGImageDestinationFinalize(destination) else { throw GIFError.finalizeFailed }
    }

    /// Preserve CGImage's original representation; PNG round-trips can change it.
    /// Read-only mappings are reclaimable file-backed pages, with no decoded-frame
    /// array. Provider destruction unmaps them before the task directory is removed.
    private static func fileBackedImage(_ image: CGImage, at url: URL) throws -> CGImage {
        guard !image.isMask, let space = image.colorSpace, let raw = image.dataProvider?.data else {
            throw GIFError.cannotCreateDestination
        }
        let count = CFDataGetLength(raw)
        guard count >= image.bytesPerRow * image.height else { throw GIFError.cannotCreateDestination }
        try (raw as Data).write(to: url)
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw GIFError.cannotCreateDestination }
        let address = mmap(nil, count, PROT_READ, MAP_PRIVATE, descriptor, 0)
        close(descriptor)
        guard let address, address != MAP_FAILED else { throw GIFError.cannotCreateDestination }
        guard let provider = CGDataProvider(dataInfo: nil, data: address, size: count, releaseData: { _, data, size in
            munmap(UnsafeMutableRawPointer(mutating: data), size)
        }) else {
            munmap(address, count)
            throw GIFError.cannotCreateDestination
        }
        guard let mapped = CGImage(width: image.width, height: image.height,
            bitsPerComponent: image.bitsPerComponent, bitsPerPixel: image.bitsPerPixel,
            bytesPerRow: image.bytesPerRow, space: space, bitmapInfo: image.bitmapInfo,
            provider: provider, decode: image.decode, shouldInterpolate: image.shouldInterpolate,
            intent: image.renderingIntent) else { throw GIFError.cannotCreateDestination }
        return mapped
    }

}


/// Task-owned, lossless pixel spool. PNG can convert SceneKit's colour space or
/// pixel representation, so retain the original small format descriptors and
/// store LZFSE-compressed provider bytes instead. No decoded frame is retained.
/// Removed on success, error and cancellation when its scope ends.
final class LosslessFrameSpool {
    enum SpoolError: Error { case cannotWriteFrame, cannotReadFrame }
    let directory: URL
    private(set) var count = 0
    // A render context normally uses one or two formats (raw/composited). Bound
    // descriptor retention as well; frame indices live in each file's header.
    private var formats: [FrameFormat] = []
    private static let maximumFormats = 16
    private struct FrameFormat {
        let width: Int, height: Int, bits: Int, pixelBits: Int, rowBytes: Int
        let space: CGColorSpace
        let bitmap: CGBitmapInfo
        let decode: [CGFloat]?
        let interpolate: Bool
        let intent: CGColorRenderingIntent
        init(_ image: CGImage) throws {
            guard !image.isMask, let space = image.colorSpace else { throw SpoolError.cannotWriteFrame }
            width = image.width; height = image.height; bits = image.bitsPerComponent
            pixelBits = image.bitsPerPixel; rowBytes = image.bytesPerRow
            self.space = space; bitmap = image.bitmapInfo
            decode = image.decode.map { Array(UnsafeBufferPointer(start: $0, count: space.numberOfComponents * 2)) }
            interpolate = image.shouldInterpolate; intent = image.renderingIntent
        }
        func matches(_ other: FrameFormat) -> Bool {
            width == other.width && height == other.height && bits == other.bits
                && pixelBits == other.pixelBits && rowBytes == other.rowBytes
                && CFEqual(space, other.space) && bitmap == other.bitmap
                && decode == other.decode && interpolate == other.interpolate && intent == other.intent
        }
        func image(provider: CGDataProvider) -> CGImage? {
            func make(_ decode: UnsafePointer<CGFloat>?) -> CGImage? {
                CGImage(width: width, height: height, bitsPerComponent: bits,
                    bitsPerPixel: pixelBits, bytesPerRow: rowBytes, space: space,
                    bitmapInfo: bitmap, provider: provider, decode: decode,
                    shouldInterpolate: interpolate, intent: intent)
            }
            if let decode { return decode.withUnsafeBufferPointer { make($0.baseAddress) } }
            return make(nil)
        }
    }
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("qiuji-frames-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    deinit {
        do { try FileManager.default.removeItem(at: directory) }
        catch { NSLog("Frame spool cleanup failed at %@: %@", directory.path, String(describing: error)) }
    }
    private func url(_ index: Int) -> URL { directory.appendingPathComponent("\(index).frame") }
    func append(_ image: CGImage) throws {
        let format = try FrameFormat(image)
        guard let raw = image.dataProvider?.data,
              CFDataGetLength(raw) >= format.rowBytes * format.height else { throw SpoolError.cannotWriteFrame }
        let index: Int
        if let found = formats.firstIndex(where: { $0.matches(format) }) { index = found }
        else {
            guard formats.count < Self.maximumFormats else { throw SpoolError.cannotWriteFrame }
            index = formats.count; formats.append(format)
        }
        let compressed = try (raw as Data as NSData).compressed(using: .lzfse) as Data
        var header = UInt32(index).littleEndian
        var file = withUnsafeBytes(of: &header) { Data($0) }
        file.append(compressed)
        try file.write(to: url(count))
        count += 1
    }
    func image(at index: Int) throws -> CGImage {
        guard (0..<count).contains(index) else { throw SpoolError.cannotReadFrame }
        let file = try Data(contentsOf: url(index))
        guard file.count > 4 else { throw SpoolError.cannotReadFrame }
        let formatIndex = file.prefix(4).enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
        guard formats.indices.contains(formatIndex) else { throw SpoolError.cannotReadFrame }
        let raw = try (Data(file.dropFirst(4)) as NSData).decompressed(using: .lzfse) as Data
        let format = formats[formatIndex]
        guard raw.count >= format.rowBytes * format.height,
              let provider = CGDataProvider(data: raw as CFData),
              let image = format.image(provider: provider) else { throw SpoolError.cannotReadFrame }
        return image
    }
    func sampledImages(frameCount: Int) throws -> [CGImage] {
        // Preserve the existing API's all-frames behavior for frameCount < 2.
        // The normal card recipe requests 12 and only decodes those 12 images.
        let indices = count > frameCount && frameCount >= 2
            ? (0..<frameCount).map { $0 * (count - 1) / (frameCount - 1) }
            : Array(0..<count)
        return try indices.map { try image(at: $0) }
    }
}
