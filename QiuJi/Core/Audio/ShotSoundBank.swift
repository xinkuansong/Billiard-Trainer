//
//  ShotSoundBank.swift
//  QiuJi
//
//  击球音效资源/引擎层：AVAudioEngine + 多 AVAudioPlayerNode 池。
//
//  设计要点
//  --------
//  1. 多 player 池（默认 12 个）支持开球瞬间多次碰撞「同时发声」——
//     单个 SystemSound / 单 player 做不到重叠。
//  2. 缺资源优雅降级：Bundle 中没有对应音频文件时，`play` 静默 no-op，
//     不影响功能与构建（音频资产可后续补入，详见 Resources/Audio/CREDITS.md）。
//  3. AVAudioSession 用 `.ambient + .mixWithOthers`：尊重硬件静音键、
//     永不打断其他音频，与休息计时器的后台保活（`.playback`，仅组间休息阶段）
//     时段不重叠，安全共存。
//  4. 真实感：仅按力度调音量，**不做变调**（避免单样本拉伸的游戏味），
//     当前试听采用每类一个底样，力度连续控制音量。
//

import AVFoundation
import SceneKit
import UIKit

@MainActor
final class ShotSoundBank {
    static let shared = ShotSoundBank()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var voiceEnds = Array(repeating: 0.0, count: 12)
    private var voiceWeights = Array(repeating: Float(0), count: 12)
    private var bufferPeaks: [ObjectIdentifier: Float] = [:]

    /// 每种事件的样本池（已转为统一画布格式）。
    private var buffers: [ShotSoundKind: [AVAudioPCMBuffer]] = [:]

    /// 统一画布格式：44.1kHz 立体声 float32。所有样本在加载时转换到此格式，
    /// 以便所有 player node 用同一连接格式接入 mixer。
    private let canonicalFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

    private let poolSize = 12
    private var isPrepared = false
    private let controlPlayer = AVAudioPlayerNode()
    private var controlBuffers: [Control: AVAudioPCMBuffer] = [:]
    private var lastControlTickTime: TimeInterval?

    private init() {}

    // MARK: - Lifecycle

    /// 懒加载：装载样本、搭建引擎、启动 player 池。重复调用安全（仅首次生效）。
    /// 任意环节失败都降级为「无声」，不抛出。
    func prepare() {
        guard !isPrepared else { startEngineIfNeeded(); return }
        isPrepared = true   // 资源和节点只建一次；音频会话失败可在回前台时重试

        loadBuffers()
        for control in Control.allCases {
            guard let url = Self.controlResourceURL(for: control) else {
                print("[ShotSoundBank] missing control sample: \(control.assetName)")
                continue
            }
            if let buffer = loadCanonicalBuffer(url: url) { controlBuffers[control] = buffer }
        }
        engine.attach(controlPlayer)
        engine.connect(controlPlayer, to: engine.mainMixerNode, format: canonicalFormat)

        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: canonicalFormat)
            players.append(node)
        }

        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning, UIApplication.shared.applicationState == .active else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "shotAudioPreviewEnabled") {
                NSLog("[ShotSoundBank] engine ready volume=%.2f route=%@", session.outputVolume, session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ","))
            }
            #endif
        } catch {
            print("[ShotSoundBank] start failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Playback

    /// Shared ruler feedback uses its own voice so it cannot replace a ball impact.
    /// Detents decide when to tick; this final limiter also covers boundary/repeated gestures.
    enum Control: String, CaseIterable {
        case aim, power
        var assetName: String { "ui_\(rawValue)_metal" }
    }

    /// Operation samples always come from the App, including physics-audio audition mode.
    static func controlResourceURL(for control: Control) -> URL? {
        Bundle.main.url(forResource: control.assetName, withExtension: "wav", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: control.assetName, withExtension: "wav")
    }

    func playControlTick(intensity: Double, control: Control) {
        guard UserPreferences.shared.soundEffectsEnabled,
              UIApplication.shared.applicationState == .active,
              intensity.isFinite, intensity > 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard lastControlTickTime.map({ now - $0 >= ShotDragDetents.soundMinimumInterval }) ?? true else { return }
        prepare()
        guard engine.isRunning, let controlBuffer = controlBuffers[control] else { return }
        lastControlTickTime = now
        let strength = min(1, max(0, (intensity - 0.60) / 0.40))
        controlPlayer.volume = Float(0.68 + 0.24 * strength)
        controlPlayer.scheduleBuffer(controlBuffer, at: nil, options: .interrupts)
        if !controlPlayer.isPlaying { controlPlayer.play() }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "shotAudioPreviewEnabled") {
            NSLog("[ShotSoundBank] control %@ tick sample=%@ gain=%.3f frames=%u", control.rawValue,
                  control.assetName, controlPlayer.volume, controlBuffer.frameLength)
        }
        #endif
    }

    /// 播放一次音效。speed 是接触法向速度（m/s），按接触类型标定音量。
    func play(kind: ShotSoundKind, speed: Float) {
        guard UserPreferences.shared.soundEffectsEnabled, speed.isFinite, speed > 0 else { return }
        guard isPrepared else { return }
        guard let pool = buffers[kind], !pool.isEmpty else { return }   // 缺资源 → no-op

        // 来电或启动时未获准激活后，重新激活 session 再启动引擎。
        startEngineIfNeeded()
        guard engine.isRunning else { return }

        let gain = Self.gain(for: kind, speed: speed)
        guard gain > 0 else { return }
        let buffer = selectSample(from: pool, intensity: min(1, speed / (kind.speedGainPoints.last?.0 ?? 6)))
        let now = ProcessInfo.processInfo.systemUptime
        let weight = gain * (bufferPeaks[ObjectIdentifier(buffer)] ?? 1)
        guard let index = Self.voiceIndex(ends: voiceEnds, weights: voiceWeights, now: now, incoming: weight) else { return }
        let node = players[index]
        let duration = Double(buffer.frameLength) / buffer.format.sampleRate
        voiceEnds[index] = now + duration
        voiceWeights[index] = weight
        node.volume = gain
        updateHeadroom()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in self?.updateHeadroom() }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "shotAudioPreviewEnabled") {
            NSLog("[ShotSoundBank] play %@ gain=%.3f frames=%u", kind.rawValue, node.volume, buffer.frameLength)
        }
        #endif
        // `.interrupts`：复用到同一 node 时立即替换上一段，保持低延迟、不堆积。
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    // MARK: - Sample selection & gain

    /// 兼容旧分档资源；无序号底样存在时只装载该底样，连续调音量。
    private func selectSample(from pool: [AVAudioPCMBuffer], intensity: Float) -> AVAudioPCMBuffer {
        guard pool.count > 1 else { return pool[0] }
        let idx = min(pool.count - 1, Int(intensity * Float(pool.count)))
        return pool[idx]
    }

    /// Compatibility for normalized callers/tests; runtime uses contact speed directly.
    static func gain(for kind: ShotSoundKind, intensity: Float) -> Float {
        guard intensity.isFinite else { return 0 }
        return gain(for: kind, speed: max(0, min(1, intensity)) * (kind.speedGainPoints.last?.0 ?? 6))
    }

    static func gain(for kind: ShotSoundKind, speed: Float) -> Float {
        guard speed.isFinite, speed > 0 else { return 0 }
        let points = kind.speedGainPoints
        for i in 1..<points.count where speed < points[i].0 {
            let a = points[i-1], b = points[i]
            let u = max(0, min(1, (speed-a.0)/(b.0-a.0)))
            let smooth = u*u*(3-2*u)
            return (a.1 + (b.1-a.1)*smooth) * kind.outputGainScale
        }
        return (points.last?.1 ?? 0) * kind.outputGainScale
    }

    /// Free voice first; only replace a quieter active voice, never a stronger impact with a weak one.
    static func voiceIndex(ends: [Double], weights: [Float], now: Double, incoming: Float) -> Int? {
        guard ends.count == weights.count, !ends.isEmpty else { return nil }
        if let free = ends.firstIndex(where: { $0 <= now }) { return free }
        guard let weakest = weights.indices.min(by: { weights[$0] < weights[$1] }), incoming > weights[weakest] else { return nil }
        return weakest
    }

    private func updateHeadroom() {
        let now = ProcessInfo.processInfo.systemUptime
        let sum = voiceWeights.indices.reduce(Float(0)) { $0 + (voiceEnds[$1] > now ? voiceWeights[$1] : 0) }
        // Conservative sum of source peaks: retain overlap without digital clipping.
        engine.mainMixerNode.outputVolume = min(1, 0.85 / max(0.85, sum))
    }

    func stopAll() {
        players.forEach { $0.stop() }
        controlPlayer.stop()
        lastControlTickTime = nil
        voiceEnds = Array(repeating: 0, count: poolSize)
        voiceWeights = Array(repeating: 0, count: poolSize)
        engine.mainMixerNode.outputVolume = 1
    }

    // MARK: - Loading

    private func loadBuffers() {
        for kind in ShotSoundKind.allCases {
            var pool: [AVAudioPCMBuffer] = []
            // 优先单底样；没有时兼容历史分档样本（_1.._6）。
            let candidates = resourceURL(name: kind.assetPrefix) != nil
                ? [kind.assetPrefix]
                : (1...6).map { "\(kind.assetPrefix)_\($0)" }
            for name in candidates {
                guard let url = resourceURL(name: name) else { continue }
                if let buf = loadCanonicalBuffer(url: url) {
                    pool.append(buf)
                    if let channels = buf.floatChannelData {
                        var peak: Float = 0
                        for channel in 0..<Int(buf.format.channelCount) {
                            for frame in 0..<Int(buf.frameLength) { peak = max(peak, abs(channels[channel][frame])) }
                        }
                        bufferPeaks[ObjectIdentifier(buf)] = peak
                    }
                }
            }
            if !pool.isEmpty { buffers[kind] = pool }
            NSLog("[ShotSoundBank] loaded %@: %d", kind.rawValue, pool.count)
        }
    }

    private func resourceURL(name: String) -> URL? {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "shotAudioPreviewEnabled") {
            let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ShotAudioPreview").appendingPathComponent(name + ".caf")
            return FileManager.default.fileExists(atPath: file.path) ? file : nil
        }
        #endif
        for ext in ["caf", "wav", "m4a", "mp3", "aiff"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// 读取音频文件并转换为统一画布格式的 PCM buffer。
    private func loadCanonicalBuffer(url: URL) -> AVAudioPCMBuffer? {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) }
        catch { print("[ShotSoundBank] decode \(url.lastPathComponent): \(error)"); return nil }
        let srcFormat = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0 else { return nil }

        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frames) else { return nil }
        do { try file.read(into: srcBuffer) } catch { print("[ShotSoundBank] read \(url.lastPathComponent): \(error)"); return nil }

        // 已是画布格式（罕见）则直接用，否则转换。
        if srcFormat == canonicalFormat { return srcBuffer }

        guard let converter = AVAudioConverter(from: srcFormat, to: canonicalFormat) else { return nil }
        let ratio = canonicalFormat.sampleRate / srcFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(frames) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: canonicalFormat, frameCapacity: outCapacity) else { return nil }

        var fed = false
        let status = converter.convert(to: outBuffer, error: nil) { _, inputStatus in
            if fed {
                inputStatus.pointee = .endOfStream
                return nil
            }
            fed = true
            inputStatus.pointee = .haveData
            return srcBuffer
        }
        return status == .error || outBuffer.frameLength == 0 ? nil : outBuffer
    }
}
