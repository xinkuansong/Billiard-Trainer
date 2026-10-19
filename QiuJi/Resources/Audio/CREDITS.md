# 击球回放音效资产（Audio）

本目录存放随 App 安装包分发的击球回放音效。2026-10-19 已将用户选定的本地试听样本原样接入，普通启动无需额外导入或试听参数。

> 加载逻辑见 `QiuJi/Core/Audio/ShotSoundBank.swift`，事件调度见 `ShotAudioScheduler.swift`。
> **自行实录方案**（场地/器材/逐类要求/后期规范）见本目录 `RECORDING-PLAN.md`。

## 命名约定

每个事件类型对应一个「样本池」：单样本用 `<prefix>.caf`，多样本（推荐，提升真实感）
追加序号 `<prefix>_1.caf` … `<prefix>_6.caf`，按撞击力度从弱到强排列。

| 事件 | 文件名前缀 | 说明 |
|------|-----------|------|
| 杆击母球 | `sfx_cue_strike` | 钝、短促 |
| 球-球碰撞 | `sfx_ball_hit` | 清脆「啪」，**建议放 3–4 个不同力度样本** |
| 吃库 | `sfx_cushion` | 较闷的「噗」 |
| 落袋 | `sfx_pocket` | 木质「咚」+ 滚落 |

支持格式：`.caf`（推荐，低延迟）/ `.wav` / `.m4a` / `.mp3` / `.aiff`。
加载时统一转 44.1kHz 立体声 float32，无需手动统一格式。

### 转码示例（其他格式 → caf）

```bash
afconvert -f caff -d LEI16@44100 input.wav sfx_ball_hit_1.caf
# 或用 ffmpeg 先切片再转：
ffmpeg -i source.wav -ss 1.20 -t 0.30 -ar 44100 -ac 2 clip.wav
afconvert -f caff -d LEI16@44100 clip.wav sfx_ball_hit_2.caf
```

## 真实感要求（重要）

本项目需要**真实球桌实录**，而非 AI 合成 / 游戏化处理的音效。挑选时避开：
- AI 生成（如标注 "AI-Generated"）；
- 加了重压缩 / 效果的「游戏化」素材；
- 用单一样本大幅变调（代码已**刻意不做变调**，力度差异靠多样本池表现）。

## 推荐来源（免费 · 真实录音 · 授权清晰）

均为 **CC0（公有领域，免署名、可商用）**。下载需登录各站账号（这是免费素材站的通用要求）：

- 球-球：Freesound `juskiddink` #108615《Billiard balls single hit-dry.wav》
  https://freesound.org/people/juskiddink/sounds/108615/ （真实近距干声，公认很真）
- 更多 CC0 真实台球音（含击球/吃库/落袋，逐个确认 license 图标为 **CC0**）：
  https://freesound.org/search/?q=billiard&f=license:%22creative+commons+0%22
- 落袋实录：Freesound「Pool ball falling into pocket」（Yarmonics 库，CC0）

> ⚠️ 上架商用前，确认每个文件来源页 license 确为 CC0；本文件登记每个采用文件的
> 来源 URL 与许可，便于合规留痕（见下表）。

## 已采用文件登记

| 文件名 | 来源 URL | 作者 | 许可 | 采用日期 |
|--------|----------|------|------|----------|
| _（待填）_ | | | CC0 | |

## 2026-09-30 本地试听包

四个处理后样本由 Debug 参数从 Documents/ShotAudioPreview 导入，不在此发行资源目录。来源及 SHA-256 见 `output/shot-audio-preview-20260930/manifest.json`；三类来自已登记的视频裁切换色，碰库为已认可极柔设计。未登记为自录或 CC0，原发行资产清单保持待补。

## 2026-10-01 操作控件金属声（DR-336 r5，历史版本）

本节仅用于瞄准条/力度条操作反馈，不作为台球碰撞录音。用户已授权替换前一轮试听：瞄准采用A精密金属滚轮，力度采用B厚重棘轮。两者均由本项目本地数学合成生成，未使用第三方录音或收费服务；从对应4.4秒试听的首个齿声提取，并去除试听0.68增益，重施增益后与原试听误差不超过1个16位PCM量化单位。App按实际位移触发单次齿声，不循环整段试听、不变调。

- `ui_aim_metal.wav`：44.1kHz/16bit/mono，1411帧；源试听`build/control-audio-20261001/metal-precision-preview.wav`；资源SHA-256：`6047bad6e88872f91c7bbfb256f1c339572fb2b4c7eac12d8ee626ab0f9671f6`。
- `ui_power_metal.wav`：44.1kHz/16bit/mono，1764帧；源试听`build/control-audio-20261001/metal-ratchet-preview.wav`；资源SHA-256：`899f4bfe595efe371ce2a928fca85603bfed70197b89d661ba19d156db25497a`。

## 2026-10-01 用户提供两组操作音效（DR-336 r6，当前试用第一版）

用户提供direction.mp3/power.mp3及direction-v2.mp3/power-v2.mp3，要求逐版试用。目前仅第一组进入App；第二组已处理保留，尚未切换。来源为用户提供文件，不推断作者或CC0许可。原文件、处理脚本、切点、增益及SHA-256记录在`output/control-sounds-user-20261001/manifest.json`；前一轮合成资源保留于该目录previous-metal-r5。

- 瞄准：direction.mp3的0.369–0.413秒，1941帧，约44ms，增益-7.03dB。当前资源SHA-256：`8c364f562e8571363801f985c4987fc92d8bb9dfd7bd6414627bea4eda2f0ee9`。
- 力度：power.mp3的0.202–0.246秒，1940帧，约44ms，增益-3.41dB。当前资源SHA-256：`2528c4754ed9333acffdaf461663dd56f8d09412fdc5ffef4c7b707b9dfa0b99`。
- 均为44.1kHz/16bit/stereo，去DC，0.5ms淡入、3ms淡出，峰值0.25；不变调、不加EQ或压缩。每个有效刻度使用一次完整齿声，沿用60ms声音/100ms震动节奏。


## 2026-10-19 已选击球样本随包接入

按用户本轮要求，将 2026-09-30 已选试听样本原样加入 App 的 Audio folder reference（Debug / Release 共用）。旧试听覆盖仍可使用；覆盖文件缺失时回退到包内资源。声音开关保留用户选择，新安装默认关闭；沿用原音色、增益曲线及静音键策略。

| 包内文件 | 已选来源 | SHA-256 |
|---|---|---|
| sfx_cue_strike.caf | C03_明显换色.wav | 9fee8881e4cc35366e68c3e0e6bd34dea71112cc885d34b585060b77d43e5277 |
| sfx_ball_hit.caf | B04_明显换色.wav | b0525e6937dde7c28446bb1935e31193af4c6369d56660ae873c1790fb2e490a |
| sfx_cushion.caf | U02_中.wav | 21a7f3da3423308e876fcce3e92dc73d8b9055d5d48e8479ea6c40fc34685327 |
| sfx_pocket.caf | P03_明显换色.wav | 03b84f0ee9b5f58e16d1694f9d61877dffaa179a5255a424529fab62202b55d5 |
| sfx_jaw.caf | 沿用已选 U02 底样及独立增益 | 21a7f3da3423308e876fcce3e92dc73d8b9055d5d48e8479ea6c40fc34685327 |
| sfx_rail.caf | 沿用试听包 U02 底样；rail/railStop 原增益为零 | 21a7f3da3423308e876fcce3e92dc73d8b9055d5d48e8479ea6c40fc34685327 |

来源详情仍见 `output/shot-audio-preview-20260930/manifest.json`；击杆、碰球、落袋这三种视频裁切换色素材不因本次接入而被重新标注为自录或 CC0。历史“未进入发行资源”是当时状态，以上本轮接入记录取代该使用状态。总计 144372 字节。
