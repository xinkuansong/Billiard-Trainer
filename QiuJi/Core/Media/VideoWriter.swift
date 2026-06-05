import AVFoundation
import CoreGraphics
import UIKit

/// 极简 H.264 MP4 逐帧写入器（ADR-P11-01）。
///
/// 从 `QiuJiTests/DrillShotReconstructionTests` 的 `AVAssetWriter` 原型抽出到 app 模块：
/// 创建 → 逐帧 `append(_:)`（按固定帧率推进 PTS）→ `finish()`。供走位序列视频导出复用。
final class VideoWriter {

    enum WriterError: Error {
        case cannotCreateWriter
        case cannotCreatePixelBuffer
        case appendFailed
    }

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let size: CGSize
    private let fps: Int32
    private var frameIndex: Int64 = 0

    init(url: URL, size: CGSize, fps: Int = 30) throws {
        self.size = size
        self.fps = Int32(max(1, fps))

        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(url: url, fileType: .mp4) else {
            throw WriterError.cannotCreateWriter
        }
        self.writer = writer

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        self.input = input

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input, sourcePixelBufferAttributes: attrs
        )

        guard writer.canAdd(input) else { throw WriterError.cannotCreateWriter }
        writer.add(input)
        guard writer.startWriting() else { throw WriterError.cannotCreateWriter }
        writer.startSession(atSourceTime: .zero)
    }

    /// 追加一帧（按固定帧率推进时间戳）。
    func append(_ image: CGImage) throws {
        guard let pool = adaptor.pixelBufferPool else { throw WriterError.cannotCreatePixelBuffer }

        var pixelBufferOut: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferOut)
        guard let pixelBuffer = pixelBufferOut else { throw WriterError.cannotCreatePixelBuffer }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { throw WriterError.cannotCreatePixelBuffer }

        context.draw(image, in: CGRect(origin: .zero, size: size))

        // 等待 input 就绪（同步导出，逐帧 busy-wait）。
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.005)
        }
        let pts = CMTime(value: frameIndex, timescale: fps)
        guard adaptor.append(pixelBuffer, withPresentationTime: pts) else {
            throw WriterError.appendFailed
        }
        frameIndex += 1
    }

    /// 结束写入并返回输出 URL。
    func finish() async throws {
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status == .failed {
            throw writer.error ?? WriterError.appendFailed
        }
    }
}
