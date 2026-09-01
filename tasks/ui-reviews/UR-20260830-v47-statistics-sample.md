# UI 审阅报告：v47 W8 Statistics 样板 D

> 日期：2026-08-30
> 角色：Orchestrator → SwiftUI Developer → UI Reviewer
> 状态：**待用户裁定；默认字号、Light/Dark、Free 门槛、紧凑空态和交互通过，AX Large 图表标签重叠未闭合**

## 一、范围与改动预算

- 主要构图区：把首屏「训练概况」重排为数据优先摘要，先回答训练天数、总时长和训练组数，再区分球台训练、屏内练习与不计训练量的工具使用。
- 局部精修 1：周期选择下补「统计区间 + 日期」，周/月/年切换后上下文不再只靠按钮状态推断。
- 局部精修 2：移除卡片绿色侧轨和重复迷你柱图，普通图表卡退为中性表层；只在摘要区保留一处低强度球路工程签名。
- 未改：历史/统计入口、周/月/年语义、统计 ViewModel、训练量/准确率口径、Charts 数据、Free/Pro 门控、Tab Bar、共享组件默认值。

## 二、视觉证据

Before：`tmp/designer-screenshots/41-history-statistics.png`。

After：

- Light 首屏：`build/v47-samples/statistics/light/01-statistics-top.png`
- Light 底部：`build/v47-samples/statistics/light/02-statistics-bottom.png`
- Dark 首屏：`build/v47-samples/statistics/dark/01-statistics-top.png`
- Dark 底部：`build/v47-samples/statistics/dark/02-statistics-bottom.png`
- Free 门槛：`build/v47-samples/statistics/free/01-statistics-free-gate.png`
- 375pt 紧凑空态：`build/v47-samples/statistics/compact/01-statistics-compact.png`
- AX Large 取证：`build/v47-samples/statistics/ax-large/01-statistics-ax-large.png`
- 交互录屏（18.005 秒）：`build/v47-samples/statistics/interaction.mp4`
- 录屏接触表：`build/v47-samples/statistics/interaction-contact-sheet.png`

## 三、样板硬标准

| 标准 | 结果 | 证据 |
|---|---|---|
| 3 秒内回答练了多少 | ✅ | 首屏以 `2 天 / 5 分钟 / 108 组` 为主指标，标签和分类降权 |
| 周/月/年上下文清楚 | ✅ | 独立显示「统计区间」与日期；18.005 秒录屏覆盖月、年、周切换 |
| 趋势与分类不再同权大卡主导 | ✅ | 摘要是唯一强调表层；时长、分类、球袋和角度继续独立承载各自语义，但去掉装饰侧轨 |
| 数据口径不变 | ✅ | 球台/屏内分列；工具使用明确标注「不计训练量与成绩」；未修改 ViewModel |
| Free/Pro 门控可理解 | ✅ | 原入口和半透明内容预览保留，锁层清楚说明 Pro 权益与解锁动作 |
| Light / Dark | ✅ | 两套首屏与底部截图目视通过；暗色下摘要和普通卡有稳定层级 |
| 不同尺寸 / 空态 | ✅ | iPhone 17 Pro 数据态 + iPhone SE 375pt 无数据态，空态 CTA 与 Tab Bar 均完整 |
| 15–30 秒交互证据 | ✅ | 18.005 秒成片覆盖入口、周期切换、趋势下滚与回滚 |
| Dynamic Type | ❌ | 系统回读 `accessibility-large` 后，图表 Y 轴与星期标签显著放大并重叠；不能宣称 AX 可用 |
| 用户明确确认 | ⏳ | 本报告交付后等待「通过/调整」；未确认前不扩 HistoryCalendar |

## 四、测试结果

- `make -f scripts/Makefile build`：`BUILD SUCCEEDED`。
- `testV47StatisticsSample`：最终 Light 1/0，Dark 1/0。Dark 首跑因测试仍断言旧标签「总时长」失败，更新为新标签「分钟 · 总时长」后通过；生产界面无返工。
- `testV47StatisticsSampleAccessibilitySize`：1/0；仅证明页面和核心元素可达，截图审阅判定图表布局不通过。
- `testV47StatisticsFreeGateSample`：1/0。
- `testV47StatisticsCompactSample`：1/0；独立 iPhone SE fixture 为无训练数据空态。
- `testV47StatisticsInteractionEvidence`：最终 1/0。首次录像发现未强制 Pro、实际停留在锁层，测试补 `-forcePremium` 后重录有效成片；失败录像保留为 `interaction-free-gate-debug.mp4`。
- `git diff --check`：通过。

## 五、审阅结论

默认字号下，样板已经把统计页从「同权白卡堆叠」调整为「周期上下文 → 核心读数 → 趋势/分类明细」，且没有修改业务或统计口径。Light、Dark、Free 门槛、紧凑空态和真实交互均建议视觉裁定为「通过」。

AX Large 暴露了明确的 P1 可读性问题：图表轴标签发生重叠。它与 TrainingHome 已确认的固定字号 Token 缺口属于同一共享辅助能力问题，不能在 Statistics 内以硬编码缩小或隐藏标签绕过。按 D-v47-3 / D-v47-13，两个样板经用户确认后进入 W2b，新增显式 opt-in 的可缩放 Typography/Chart 适配能力；在此之前 W8 不扩到 HistoryCalendar，W15a 也不能宣称辅助功能收官。
