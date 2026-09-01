# UI 审阅报告：v47 W3 TrainingHome 样板 R

> 日期：2026-08-30
> 角色：Orchestrator → SwiftUI Developer → UI Reviewer
> 状态：**待用户裁定；默认字号、Light/Dark、紧凑尺寸和交互通过，Dynamic Type 能力缺口未闭合**

## 一、范围与改动预算

- 主要构图区：把「今日安排」重排为首屏状态区，突出计划、完成数和球路工程签名。
- 局部精修 1：根页顶部从孤立按钮行改为小型训练状态行，不恢复大标题或气氛顶带。
- 局部精修 2：补足底部滚动余量；卡内 `GO!` 降为「当前」状态，右下训练按钮成为唯一主 CTA。
- 未改：路由、数据、训练剂量、Tab Bar、共享组件默认值、`BTPlanCover`、逐卡封面与球桌缩略图。

## 二、视觉证据

Before：`tmp/designer-screenshots/01-training-home.png`。

After：

- Light 首屏：`build/v47-samples/training-home/light/01-training-home-top.png`
- Light 底部：`build/v47-samples/training-home/light/02-training-home-bottom.png`
- Dark 首屏：`build/v47-samples/training-home/dark/01-training-home-top.png`
- Dark 底部：`build/v47-samples/training-home/dark/02-training-home-bottom.png`
- 375pt 紧凑空态：`build/v47-samples/training-home/compact/01-training-home-compact-top.png`
- 375pt 紧凑底部：`build/v47-samples/training-home/compact/02-training-home-compact-bottom.png`
- AX Large 取证：`build/v47-samples/training-home/ax-large/01-training-home-ax-large.png`
- 交互录屏（16.76 秒）：`build/v47-samples/training-home/interaction.mp4`
- 录屏接触表：`build/v47-samples/training-home/interaction-contact-sheet.png`

## 三、样板硬标准

| 标准 | 结果 | 证据 |
|---|---|---|
| 3 秒内识别当前状态 | ✅ | 顶部「今日训练进行中/待安排」；今日计划、0/3 和当前项目在首屏 |
| 只有一个主 CTA | ✅ | UI 测试精确断言 `开始训练 == 1`；空态断言 `开始训练/自由记录` 合计为 1 |
| 不恢复根页大标题 | ✅ | `navigationBars[训练]` 不存在；只保留 14pt 状态行 |
| 次级信息降权 | ✅ | 周/天/分钟与计划主题合并为辅助行；当前项目改为低强调状态 Chip |
| 最后一项不被 Tab Bar 遮挡 | ✅ | iPhone 17 Pro 与 iPhone SE 底部截图中第 12 期卡片完整可见 |
| Light / Dark | ✅ | 两套首屏与底部截图目视通过 |
| 不同尺寸 | ✅ | iPhone 17 Pro 402pt 与 iPhone SE 375pt；后者同时覆盖无活跃计划空态 |
| 15–30 秒交互证据 | ✅ | 16.76 秒录屏覆盖滚动、回滚和官方/我的模版切换 |
| Dynamic Type | ⚠️ | 模拟器回读为 `accessibility-large`，但截图字体与默认字号相同；全局 Typography Token 为固定 point size |
| 用户明确确认 | ⏳ | 本报告交付后等待「通过/调整」；未确认前不扩 PlanList |

## 四、测试结果

- `make -f scripts/Makefile build`：`BUILD SUCCEEDED`。
- `testV47TrainingHomeSample`：Light 1/0，Dark 1/0。
- `testV47TrainingHomeSampleAccessibilitySize`：1/0；仅证明布局未坏和关键元素可达，不证明字体已缩放。
- `testV47TrainingHomeInteractionEvidence`：1/0。
- `testV47TrainingHomeCompactSample`：首次因独立模拟器没有活跃计划而按错误 fixture 口径失败；改为状态感知断言后 1/0。没有生产代码返工。
- `git diff --check`：通过。

## 五、审阅结论

样板相对 before 明确改善了首屏任务感、数据层级、唯一主动作和底部安全区，且没有恢复用户撤回的大标题/顶带，也没有触碰 v46 封面。默认字号下建议视觉裁定为「通过」。

但全局字体 Token 不响应 Dynamic Type 是已确认的跨页 P2 能力缺口。它不是本次样板引入的回归，也不适合在 W3 单页内用硬编码字体绕过。按 D-v47-3，先在数据样板 D 或品牌样板 B 复核；第二个样板确认同一缺口后，再进入 W2b 设计显式 opt-in 的可缩放字体能力。W15a 在该缺口闭合前不得宣称辅助功能收官。
