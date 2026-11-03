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


## 2026-10-30 App 全部可听音频统一提高 3 dB

用户确认网易云同时播放时击球声被掩盖，要求提高 App 实际声音，并明确包含背景音乐及操作提示。对现有 11 个包内音频统一施加 +3 dB 线性增益（幅度约 ×1.41254），包括击球/碰撞、滑尺、背景音乐、休息倒计时与结束提示。没有重新选音色、变调、EQ、压缩或修改播放力度曲线、偏好默认值、静音/混播策略。rail/railStop 仍受原零增益规则控制；后台静音保活文件不属于可听音频，不变。

以上历史 SHA/峰值为当时版本；当前资源以本表为准。来源和许可保持原记录。Apple AVFoundation 全量解码、逐样本增益/量化误差和格式核验通过；所有资源峰值 <0.85，单资源无削波。参考混音与密集音效池核验见本轮报告，真机最终混音及耳机听感待验。显式启用的 Documents/ShotAudioPreview 仍可覆盖包内击球样本，本次没有改写用户试听覆盖文件。

| 当前文件 | +3 dB 后 SHA-256 |
|---|---|
| `Music/quiet_table.caf` | `ed64e83145eb361985c3a4b2bb48066fa42dc218548636ecb4d97b3450f0bd10` |
| `RestTimer/complete.wav` | `239e84f8d7f292aec68088a42ba8d93ac6ade1a373f5497c97fc35a6efd52975` |
| `RestTimer/countdown.wav` | `4be8dcdc2b7ee702432b9a6a4d4baf6905f30acc98b6cee9fec1b9fdda9c6f22` |
| `sfx_ball_hit.caf` | `bda9e5f1cb69bc8cd192851e78fcd4c9ee07654f8370d84c75b6961b7541e333` |
| `sfx_cue_strike.caf` | `5f1f69049c820ea03e4d2445a357b8d914de7ddf7cb8a70749ee4e369aa7b20b` |
| `sfx_cushion.caf` | `00f6ac7dbc33ce1430a98f00bf34a9dd4e9ebe24245ba9a17e292a3e75571c6e` |
| `sfx_jaw.caf` | `00f6ac7dbc33ce1430a98f00bf34a9dd4e9ebe24245ba9a17e292a3e75571c6e` |
| `sfx_pocket.caf` | `3f65410cb5ad27421df0a91fac4422ab1eed97d211f812cecd3f7204cf4bb6d5` |
| `sfx_rail.caf` | `00f6ac7dbc33ce1430a98f00bf34a9dd4e9ebe24245ba9a17e292a3e75571c6e` |
| `ui_aim_metal.wav` | `a2c0d534f428656de881b85dbd329b892cc4c6a2e7eb77f3ee9af97c635b8908` |
| `ui_power_metal.wav` | `7e079e604665b07ee41915f51ab839e9e7cf0cd0c17d3ec8c24cfd3fca57fb04` |

原件、原/新 SHA、原生逐样本结果及试听对照：`output/app-audio-gain-20261030/`；任务记录：`tasks/APP-AUDIO-GAIN-20261030.md`。


## 2026-10-30 r2 · 用户反馈仍偏小，目标提高至 +6 dB（当前）

以最初原件重新制作，避免对上一轮量化结果重复放大。目标 +6 dB；每个资源用同一线性系数放大完整波形，系数上限取原峰值到 0.95 的余量。没有削波、压缩、变调或 EQ。9 个资源达到 +6 dB；背景音乐 +3.9918 dB、进袋 +5.2586 dB。操作声峰值约 0.49881。最终 16 bit 量化使 0.95 附近峰值为 0.950012，仍低于满幅。前节 +3 dB 表作为历史，现行以本表为准。

| 当前文件 | 相对原版实测增益 | SHA-256 |
|---|---:|---|
| `Music/quiet_table.caf` | 3.9918 dB | `cffda0e644824c9afec175105f38e5c3bf4ce82d65954312d05c87f05ad34129` |
| `RestTimer/complete.wav` | 6.0000 dB | `7688176658ca9132db8576004a4470f4d2d2fc89a480cb90d769514e1976516b` |
| `RestTimer/countdown.wav` | 6.0000 dB | `0ee07e686cc60d92a21c74849e32dd41e1994605e9ae011061f189277cefd96a` |
| `sfx_ball_hit.caf` | 6.0000 dB | `dfa489b64c921da313fe37520a137a400a235753fdf23950691e702a0e0577f0` |
| `sfx_cue_strike.caf` | 6.0000 dB | `9f1d2ebc0cd648c075ac9eaeb554ce86373984e52cd3ad006b61fbfb0cae9989` |
| `sfx_cushion.caf` | 6.0000 dB | `ac7d1ed35f9b3b4e64d53d78a0e308a5e0414ac114ce8087c20bfdd43659011c` |
| `sfx_jaw.caf` | 6.0000 dB | `ac7d1ed35f9b3b4e64d53d78a0e308a5e0414ac114ce8087c20bfdd43659011c` |
| `sfx_pocket.caf` | 5.2586 dB | `95587ea22bd85e7db583d7617f06fddb41ee164346e8f1ebadb61a5063e7ec4a` |
| `sfx_rail.caf` | 6.0000 dB | `ac7d1ed35f9b3b4e64d53d78a0e308a5e0414ac114ce8087c20bfdd43659011c` |
| `ui_aim_metal.wav` | 5.9999 dB | `e5c5971ec5f23c480c43f8ad8a8533745198903d98c442ed21372caa7a283396` |
| `ui_power_metal.wav` | 6.0000 dB | `20b65d908f3b15acf262746dbeaceefe5b43dca52f9b456156ab77c521a70a6b` |

原生资产核验、原/+3/r2同段试听及原始验证日志见 `output/app-audio-gain-20261030/r2/` 和任务卡 r2 节。未安装真机；设备混音与听感仍待验。
