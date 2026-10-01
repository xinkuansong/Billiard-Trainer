//
//  ShotSound.swift
//  QiuJi
//
//  击球回放音效的事件分类与资源命名约定。
//
//  当前试听：每种事件一个已确认底样，按撞击力度连续调音量，不在运行时变调。
//  仍兼容带序号的历史分档资源；player 轮换用于重叠播放，不代表样本轮换。
//

import Foundation

/// 一次击球回放中可发声的物理事件类型。
enum ShotSoundKind: String, CaseIterable {
    /// 杆击母球（回放起点 t=0）。
    case cueStrike
    /// 球-球碰撞。
    case ballHit
    /// 吃库（球撞库边）。
    case cushion
    /// 袋内衬接触，沿用 pocket 资源名；规则判定进球本身不发声。
    case pocket
    case jaw, rail, railStop, pocketBall

    /// Bundle 资源文件名前缀。约定：单样本用 `<prefix>.caf`；
    /// 多样本追加序号 `<prefix>_1.caf` … `<prefix>_6.caf`。
    var assetPrefix: String {
        switch self {
        case .cueStrike: return "sfx_cue_strike"
        case .ballHit:   return "sfx_ball_hit"
        case .cushion:   return "sfx_cushion"
        case .pocket:    return "sfx_pocket"
        case .jaw: return "sfx_jaw"
        case .rail, .railStop: return "sfx_rail"
        case .pocketBall: return "sfx_ball_hit"
        }
    }
}


extension ShotSoundKind {
    init(surface: ContactSoundEvent.Surface) {
        switch surface {
        case .ball: self = .ballHit
        case .cushion: self = .cushion
        case .jaw: self = .jaw
        case .liner: self = .pocket
        case .rail: self = .rail
        case .railStop: self = .railStop
        case .pocketBall: self = .pocketBall
        }
    }

    /// Listening calibration; scales multiply each kind's speed curve.
    var outputGainScale: Float {
        switch self {
        case .rail, .railStop: return 0
        case .cushion, .jaw: return 0.175
        case .pocket: return 0.25
        case .ballHit: return 0.5
        case .pocketBall: return 0.25
        default: return 1
        }
    }

    /// Audition calibration in metres/second and linear gain, not measured sound pressure.
    var speedGainPoints: [(Float, Float)] {
        switch self {
        case .cueStrike: return [(0,0),(0.15,0.008),(0.5,0.035),(1.5,0.16),(3,0.38),(6,0.7),(10,1)]
        case .ballHit: return [(0,0),(0.03,0),(0.15,0.025),(0.5,0.12),(1.5,0.36),(3,0.6),(6,0.85),(10,1)]
        case .cushion: return [(0,0),(0.04,0),(0.2,0.01),(0.6,0.07),(1.5,0.24),(3,0.4),(6,0.55)]
        case .jaw: return [(0,0),(0.03,0),(0.2,0.015),(0.6,0.1),(1.5,0.33),(3,0.52),(6,0.65)]
        case .pocket: return [(0,0),(0.05,0),(0.2,0.002),(0.6,0.02),(1.5,0.12),(3,0.4),(6,0.7)]
        case .rail: return [(0,0),(0.04,0),(0.2,0.04),(0.6,0.16),(1.5,0.4),(3,0.6),(6,0.7)]
        case .railStop: return [(0,0),(0.04,0),(0.2,0.03),(0.6,0.12),(1.5,0.25),(3,0.35)]
        case .pocketBall: return [(0,0),(0.03,0),(0.2,0.02),(0.6,0.09),(1.5,0.2),(3,0.32),(6,0.45)]
        }
    }
}
