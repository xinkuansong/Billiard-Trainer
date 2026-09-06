import XCTest
import AVFoundation

/// Read-only packaged-resource diagnosis. Does not start an engine or audio session.
final class AudioResourceDiagnosticTests: XCTestCase {
    private let prefixes = ["sfx_cue_strike", "sfx_ball_hit", "sfx_cushion", "sfx_pocket"]
    private let extensions = ["caf", "wav", "m4a", "mp3", "aiff"]

    private func candidates(prefix: String) -> [URL] {
        ([prefix] + (1...6).map { "\(prefix)_\($0)" }).compactMap { name in
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                    ?? Bundle.main.url(forResource: name, withExtension: ext) { return url }
            }
            return nil
        }
    }
    func testFourEventPoolsHaveAtLeastOnePackagedSample() {
        for prefix in prefixes {
            let files = candidates(prefix: prefix)
            XCTAssertFalse(files.isEmpty, "Missing packaged sound pool: \(prefix); graceful no-op is not sound delivery")
        }
    }
    func testPackagedAudioSamplesDecodeToNonemptyPCM() throws {
        let urls = prefixes.flatMap { candidates(prefix: $0) }
        XCTAssertFalse(urls.isEmpty, "No audio samples: decoding coverage cannot pass vacuously")
        guard !urls.isEmpty else { return }
        for url in urls {
            let file = try AVAudioFile(forReading: url)
            XCTAssertGreaterThan(file.length, 0, url.lastPathComponent)
            XCTAssertGreaterThan(file.processingFormat.sampleRate, 0)
            XCTAssertGreaterThan(file.processingFormat.channelCount, 0)
            let chunk = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096))
            var decoded: AVAudioFramePosition = 0
            while file.framePosition < file.length {
                try file.read(into: chunk, frameCount: chunk.frameCapacity)
                XCTAssertGreaterThan(chunk.frameLength, 0, "Decoder made no progress: \(url.lastPathComponent)")
                if chunk.frameLength == 0 { break }
                decoded += AVAudioFramePosition(chunk.frameLength)
            }
            XCTAssertEqual(decoded, file.length, "Incomplete PCM decode: \(url.lastPathComponent)")
        }
    }
}
