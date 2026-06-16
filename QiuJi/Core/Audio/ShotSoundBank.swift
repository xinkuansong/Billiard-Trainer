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
//     力度差异由多样本资源池表现。
//

import AVFoundation
import SceneKit

@MainActor
final class ShotSoundBank {
    static let shared = ShotSoundBank()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0

    /// 每种事件的样本池（已转为统一画布格式）。
    private var buffers: [ShotSoundKind: [AVAudioPCMBuffer]] = [:]

    /// 统一画布格式：44.1kHz 立体声 float32。所有样本在加载时转换到此格式，
    /// 以便所有 player node 用同一连接格式接入 mixer。
    private let canonicalFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

    private let poolSize = 12
    private var isPrepared = false

    private init() {}

    // MARK: - Lifecycle

    /// 懒加载：装载样本、搭建引擎、启动 player 池。重复调用安全（仅首次生效）。
    /// 任意环节失败都降级为「无声」，不抛出。
    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true   // 即便失败也只尝试一次，避免反复抛错

        loadBuffers()

        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: canonicalFormat)
            players.append(node)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            players.forEach { $0.play() }
        } catch {
            print("[ShotSoundBank] prepare failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Playback

    /// 播放一次音效。`intensity` ∈ [0,1]（撞击力度归一化），决定样本选档与音量。
    func play(kind: ShotSoundKind, intensity: Float) {
        guard UserPreferences.shared.soundEffectsEnabled else { return }
        guard isPrepared else { return }
        guard let pool = buffers[kind], !pool.isEmpty else { return }   // 缺资源 → no-op

        // 引擎可能被系统中断（来电等）停掉，播放前兜底重启。
        if !engine.isRunning {
            try? engine.start()
            guard engine.isRunning else { return }
        }

        let clamped = max(0, min(1, intensity))
        let buffer = selectSample(from: pool, intensity: clamped)

        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count

        node.volume = gain(for: kind, intensity: clamped)
        // `.interrupts`：复用到同一 node 时立即替换上一段，保持低延迟、不堆积。
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    // MARK: - Sample selection & gain

    /// 按力度选样本档：弱→池前段，强→池后段；同档内用 player 轮换天然带来轻微差异。
    private func selectSample(from pool: [AVAudioPCMBuffer], intensity: Float) -> AVAudioPCMBuffer {
        guard pool.count > 1 else { return pool[0] }
        let idx = min(pool.count - 1, Int(intensity * Float(pool.count)))
        return pool[idx]
    }

    /// 力度→音量映射。sqrt 贴近响度感知（弱碰也听得到）；吃库更闷、落袋较稳。
    private func gain(for kind: ShotSoundKind, intensity: Float) -> Float {
        let base = 0.2 + 0.8 * sqrtf(intensity)
        let kindScale: Float
        switch kind {
        case .cushion: kindScale = 0.6
        case .pocket:  kindScale = 0.85
        case .cueStrike, .ballHit: kindScale = 1.0
        }
        return base * kindScale
    }

    // MARK: - Loading

    private func loadBuffers() {
        for kind in ShotSoundKind.allCases {
            var pool: [AVAudioPCMBuffer] = []
            // 单样本（无序号）+ 多样本（_1.._6），存在哪个就装哪个。
            let candidates = [kind.assetPrefix] + (1...6).map { "\(kind.assetPrefix)_\($0)" }
            for name in candidates {
                guard let url = bundleURL(name: name) else { continue }
                if let buf = loadCanonicalBuffer(url: url) { pool.append(buf) }
            }
            if !pool.isEmpty { buffers[kind] = pool }
        }
    }

    private func bundleURL(name: String) -> URL? {
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
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let srcFormat = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0 else { return nil }

        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frames) else { return nil }
        do { try file.read(into: srcBuffer) } catch { return nil }

        // 已是画布格式（罕见）则直接用，否则转换。
        if srcFormat == canonicalFormat { return srcBuffer }

        guard let converter = AVAudioConverter(from: srcFormat, to: canonicalFormat) else { return nil }
        let ratio = canonicalFormat.sampleRate / srcFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(frames) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: canonicalFormat, frameCapacity: outCapacity) else { return nil }

        var fed = false
        let status = converter.convert(to: outBuffer, error: nil) { _, inputStatus in
            if fed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            inputStatus.pointee = .haveData
            return srcBuffer
        }
        return status == .error ? nil : outBuffer
    }
}
