//
//  ShotSound.swift
//  QiuJi
//
//  击球回放音效的事件分类与资源命名约定。
//
//  真实感策略（详见 ADR）：每个事件类型对应一个「多样本」资源池
//  （<prefix>.caf / <prefix>_1.caf / <prefix>_2.caf …），播放时按撞击力度
//  选档 + 轮换，几乎不做变调——真实球桌「同种碰撞每次都略不同」靠的是
//  多样本轮换，而非对单一样本拉伸（后者会产生电子/游戏味）。
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
    /// 落袋。
    case pocket

    /// Bundle 资源文件名前缀。约定：单样本用 `<prefix>.caf`；
    /// 多样本追加序号 `<prefix>_1.caf` … `<prefix>_6.caf`。
    var assetPrefix: String {
        switch self {
        case .cueStrike: return "sfx_cue_strike"
        case .ballHit:   return "sfx_ball_hit"
        case .cushion:   return "sfx_cushion"
        case .pocket:    return "sfx_pocket"
        }
    }
}
