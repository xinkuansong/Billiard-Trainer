# Stitch 修正指令 — E-01 帧3 v2: ActiveTrainingView 单项记录 Dark Mode

> 任务 ID: E-01 | 帧: 3/5 | 版本: v2 | 日期: 2026-04-05
> 审核问题: P3-1 网格布局重构 / P3-2 底部栏错误 / P3-3 头部结构偏差 / P3-4 多余元素
> 修正策略: 在 Stitch 同一会话中发送追加修正指令

---

## Stitch 修正指令（在帧3同一对话中追加以下消息）

I need major corrections. The current design has completely changed the layout from the light mode reference. **This must be a pixel-identical color remap — the ONLY thing that should change is colors.** Please look at the attached light mode screenshot again very carefully and fix these issues:

### Fix 1: RESTORE the BTSetInputGrid 5-column table layout

The current design replaced the 5-column data grid with simplified card rows. This is WRONG. Restore the **exact grid layout from the light mode screenshot**:

- A white card (now `#1C1C1E` in dark mode) containing a **5-column table grid**:
  - Column headers: 组 | 进球 | 总球 | 完成 | (overflow ⋯)
  - Headers in `rgba(235,235,240,0.3)` 12pt
- **5 data rows**, each 48pt tall, 8pt spacing:
  - **Row 1 (Warmup, completed)**: Orange `#F5A623` badge with white "热" text | input box "8" | input box "10" | green `#25A25A` filled checkmark circle | ⋯ overflow. **Entire row has dark green tint background `rgba(37,162,90,0.10)`**
  - **Row 2 (Set 1, completed)**: Number "1" in white bold | "15" | "18" | green checkmark | ⋯. Same dark green tint background.
  - **Row 3 (Set 2, CURRENT ACTIVE)**: Number "2" in `#25A25A` green bold | input box "13" with **2pt solid `#25A25A` border** | input box "18" with same green border | hollow circle `#3A3A3C` border | ⋯. No tint — green borders are the active indicator.
  - **Row 4 (Set 3, not started)**: Gray "3" in `rgba(235,235,240,0.6)` | empty input box `#2C2C2E` fill with `#3A3A3C` border | same style | hollow circle | ⋯
  - **Row 5 (Set 4, not started)**: Same as Row 4 with "4"
- Input boxes: 44×44pt, corner radius 8pt
- Below the grid: centered text button **"+ 添加一组"** in `#25A25A`

### Fix 2: REPLACE the bottom tab bar with the custom 5-item toolbar

Remove the 5-tab bar at the bottom entirely. This is a **full-screen modal** (fullScreenCover) — it does NOT have the standard iOS tab bar.

Instead, render this custom bottom toolbar (identical layout to the training overview in Frame 2):
- Background: `#1C1C1E`, top border 0.5pt `#38383A`
- 5 equally spaced items, each with icon (24pt) + label (10pt) stacked:
  1. minimize icon + "最小化" in `rgba(235,235,240,0.6)`
  2. ellipsis.circle + "更多" in `rgba(235,235,240,0.6)`
  3. **CENTER: large 56pt green circle (`#25A25A` solid fill) with white "+" icon (28pt bold), rising 12pt above toolbar** + "添加" label in `#25A25A` below
  4. square.and.pencil + "心得" in `rgba(235,235,240,0.6)`
  5. list.bullet + "切换" in `rgba(235,235,240,0.6)`

### Fix 3: RESTORE the fixed timer header (identical to Frame 2)

Remove the back arrow "←" at top-left. Remove the "RECORDING SESSION" text.

Replace the top area with the **exact same fixed timer header as Frame 2**:
- **Timer row**: Left side `00:12:34` in 28pt Bold monospace `#25A25A`. Right side: 4 icon buttons (alarm, clock, sort, checkmark) in `rgba(235,235,240,0.6)`, 24pt each
- **Info row** (4pt below): Left "基础直球训练" 17pt Semibold `#FFFFFF` + pencil icon. Right "8/15 组  2/4 项目" 13pt `rgba(235,235,240,0.6)`

### Fix 4: Keep everything else from the current design

The drill header area (thumbnail + "五分点直球" + score), the notes input row, the rest/settings row, the mode toggle chips, and the billiard table section at the bottom are all fine — keep those unchanged.

**Summary: The ONLY layout changes needed are: (1) restore the 5-column grid, (2) replace tab bar with custom toolbar, (3) restore the full timer header. Everything else stays as-is.**

---

## 推荐操作

1. 在帧3 的 Stitch **同一对话**中发送以上修正消息
2. **再次附加** `tasks/P0-04/stitch_task_p0_04_04/screen.png` 并说 "Please match this layout exactly, only changing colors to dark mode"
3. 导出保存到 `tasks/E-01/`
4. 完成后继续修改帧4
