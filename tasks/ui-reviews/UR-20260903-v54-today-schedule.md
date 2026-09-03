# UR-20260903-v54 — 官方主线与今日编排

## 范围与结论

- 范围：计划详情四种 CTA 与“编排今天”、训练首页六种今日状态、历史来源存在/已删除。
- 结论：模拟器自动截图范围内未见文字遮挡、主 CTA 冲突、Light/Dark 对比度异常或 iPad sheet 无法到达。来源已删除态保留冻结文字并显著降低可操作感，符合只读语义。
- 边界：本报告不代替真实长按拖动、最大辅助字号、VoiceOver、减弱动态效果和跨零点/时区验收；这些统一记入 H-27。

## 自动用例矩阵

| 设备 | 外观 | 用例 | 截图 | 结果 |
|---|---|---:|---:|---|
| iPhone 17 Pro | Light | 3/3 | 13 | PASS |
| iPhone 17 Pro | Dark | 3/3 | 13 | PASS |
| iPad | Light | 3/3 | 13 | PASS |
| iPad | Dark | 3/3 | 13 | PASS |
| **合计** | — | **12/12** | **52** | **PASS** |

## 主要取证点

1. 计划页：开始、切换、当前编排、完成后复练四态分离；编排 sheet 默认选中当前课，底部摘要显示加入数与最大可推进数。
2. 首页：无安排、只有建议、官方+模版+动作混合、部分完成、全完成、昨日未完六态可区分；队列来源以图标和内容副标题表达，未堆叠彩色标签。
3. 历史：源存在时面包屑可操作；源已删除时保留同一冻结标题但禁用导航。
4. 响应式：iPhone 队列保持单列和底部入口；iPad 编排 sheet 保持集中宽度，背景课程结构仍可辨识。

## 证据

- 根目录：`build/ui-reviews/v54/`
- 代表图：
  - `iphone-light/plan-current-composer.png`
  - `iphone-dark/today-mixed.png`
  - `ipad-light/today-yesterday.png`
  - `ipad-dark/plan-current-composer.png`
  - `iphone-light/history-source-deleted.png`
- UI 用例：`QiuJiUITests/V54ScheduleUITests.swift`
- 人工后续：`tasks/test-plans/TP-P8-v54-今日编排与主线计划.md`、`tasks/HUMAN-REQUIRED.md` H-27
