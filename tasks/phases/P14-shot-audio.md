# P14 — 击球回放音效（Shot Audio）

> 目标：为物理回放加上真实台球音效（杆击母球、球-球碰撞、吃库、落袋），
> 并按用户要求把所有回放/视频导出统一为**原速（1.0）**。

## 范围

- 回放/视频原速化：去除全部人为加速（4 条回放 + GIF 预设）。
- 音效基础设施：事件驱动调度 + 多 player 池 + 力度→音量映射 + 缺资源优雅降级。
- 设置开关：偏好设置「声音 · 击球音效」。
- 音频资产管线：`QiuJi/Resources/Audio/` folder reference + drop-in。

## 任务与状态

| 任务 | 状态 | 说明 |
|------|------|------|
| T-P14-01 全部回放/视频倍速 → 1.0 | ✅ | 4 处回放（角度/Drill/走位编排/思路）+ `SequenceVideoExporter.gif` 1.3→1.0 |
| T-P14-02 `ShotSoundBank`（引擎+池+加载） | ✅ | `QiuJi/Core/Audio/ShotSoundBank.swift` |
| T-P14-03 `ShotAudioScheduler`（事件→时刻调度） | ✅ | `QiuJi/Core/Audio/ShotAudioScheduler.swift` |
| T-P14-04 4 条回放路径接入 + 取消 | ✅ | 起播挂调度，复位/结束 `cancel()` |
| T-P14-05 设置开关 | ✅ | `UserPreferences.soundEffectsEnabled` + `SettingsView` |
| T-P14-06 音频资产管线就绪 | ✅ | folder ref + `CREDITS.md` 清单 |
| T-P14-07 放入真实 CC0 录音 | ⏳ | **人工**（见 H-18）：下载需登录 Freesound |
| T-P14-08 真机听感验收 | ⏳ | 待资产到位后人工 |

## DoD

- [x] `make build` BUILD SUCCEEDED（含新增 `Core/Audio` 与 folder ref）。
- [x] 缺音频文件时 App 正常运行、回放无声、不崩溃（`play` 优雅 no-op）。
- [x] 回放与视频导出全部为原速 1.0。
- [ ] 放入真实 CC0 录音后，4 类事件按真实时刻发声、力度可感（人工听感验收）。

---

## ADR-P14-01 — 击球回放音效架构（AVAudioEngine + 事件驱动调度）

- **状态**：已采纳（2026-06-16，iOS Architect）
- **背景**：物理引擎 `EventDrivenEngine` 已收集结构化事件流
  （`resolvedEvents`/`resolvedEventTimes`，注释明示「for game rules and audio」），
  并经 `ShotPrediction.events`（已剔除无几何语义的 `transition`，带时间戳）暴露到 UI。
  此前无任何碰撞音效基础设施（仅休息计时器用 `AudioServicesPlaySystemSound` + 键盘触觉）。

### 决策

1. **新增独立模块 `Core/Audio`**，两层：
   - `ShotSoundBank`：`AVAudioEngine` + 多 `AVAudioPlayerNode` 池（12）。多 player 支持
     开球瞬间多次碰撞**同时发声**（单 SystemSound / 单 player 做不到）。统一画布格式
     44.1kHz 立体声 float32，加载时用 `AVAudioConverter` 转换，任意源格式可用。
   - `ShotAudioScheduler`：把 `ShotPrediction.events` 按**真实时刻**排程
     （原速回放，事件 `time`(模拟秒) 即真实延迟秒，无倍速换算），用可取消的
     `DispatchWorkItem` 实现；回放打断/复位时 `cancel()`。
2. **音效选 `AVAudioEngine` 而非 `AudioServicesPlaySystemSound`**：后者无法多音重叠、
   无法调音量。
3. **`AVAudioSession` 用 `.ambient + .mixWithOthers`**：尊重硬件静音键、永不打断其他音频。
   与休息计时器后台保活（`.playback`，仅组间休息阶段、与击球回放时段不重叠）安全共存。
4. **真实感策略**：力度→音量映射（`sqrt` 贴近响度感知），**刻意不做变调**——
   单样本大幅变调会产生电子/游戏味；力度差异由「多样本资源池」表现
   （`<prefix>_1..6.caf` 按力度选档 + player 轮换天然带微差）。这与用户「要真实、
   不要游戏音质」的要求一致。
5. **力度估算来自 recorder**（事件时刻相关球速度）——是「听感响度」的**近似**，
   非物理精确撞击冲量；对音效足够。
6. **资产 drop-in + 优雅降级**：`Resources/Audio/` 为 folder reference，放入符合命名
   约定的文件重新构建即生效；缺文件时 `play` 静默 no-op，不影响功能与构建。

### 后果

- 正面：解耦、可测试、缺资产不阻塞、与现有音频流共存、扩展样本零代码改动。
- 负面/遗留：
  - **真实 CC0 录音需人工下载**（Freesound 等优质真实录音站下载均需登录账号；
    免登录站如 SoundDino 疑似 AI 合成、不满足「真实」要求）。见 H-18。
  - 力度为近似估算，如需物理精确可后续给 `ShotEvent` 加 `impactSpeed` 字段（B 方案）。
  - 视频导出音轨（把音效写进导出 mp4）本期未做，仅实时回放发声；调度逻辑已可复用。
  - 滚动/摩擦底噪、停球 settle 声未做（易吵，按需再加）。
