# 击球回放音效资产（Audio）

本目录存放击球回放音效。**代码已就绪**：放入符合下方命名约定的音频文件后，
重新构建即可生效；目录为空时 App 自动静音（功能不受影响）。

> 加载逻辑见 `QiuJi/Core/Audio/ShotSoundBank.swift`，事件调度见 `ShotAudioScheduler.swift`。

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
