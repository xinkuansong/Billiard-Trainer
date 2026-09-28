# v47 生产路由与页面覆盖

机器可读真源为 `route-coverage.csv`。当前登记 70 个页面：每行必须具备 View、页面族、批次、状态、截图、测试、可达范围和源码锚点；`verify_v47_ui_baseline.py` 会验证必需页面、源码声明与路由表层签名。

## 可达性入口

- `RootView`：首次引导 / 已完成引导主界面；其余 `-deeplink.*`、`-w29.*` 仅为 UITest 取证宿主，不算生产路由。
- `MainTabView`：训练、动作库、练习、记录、我的五个生产根页；`AngleRoute` 的学 / 理 / 练 / 打 / 解目的地在同文件 switch 注册。
- 页面内导航：扫描 `NavigationLink`、`navigationDestination`、`sheet`、`fullScreenCover` 的所有生产文件。
- Batch 三层：`BatchDrillStudioView` → `BatchBallExtractionView` → `BatchAuthoringView`，明确标为 `simulator-only`，归 W14a；不得与普通用户生产入口混淆。

## v47.2 补漏确认

| 页面 | 真实入口 | 批次 | 证据 |
|---|---|---|---|
| `RootView` | App 启动 | W10a | 首次引导、已完成引导恢复测试 |
| `AngleSessionDetailView` | 历史日历认知训练行 Sheet | W9 | 新增认知详情聚焦测试 |
| `TheoryIndexView` | 练习 Tab「理」入口 | W12a | `V30W0TheoryIndexUITests` |
| `BatchDrillStudioView` | 模拟器专用「批量出片台」 | W14a | 新增 Batch 三层页面测试 |
| `BatchBallExtractionView` | Batch Studio 内导航 | W14a | 新增 Batch 三层页面测试 |
| `BatchAuthoringView` | Batch Extraction 内导航 | W14a | 新增 Batch 三层页面测试 |

## 门禁机制

`route-surface-signatures.sha256` 不对整个 Swift 文件做哈希，而只对路由操作、路由 enum case、UITest 深链及其后续上下文做规范化签名。因此普通视觉实现不会无意义触发；新增/删除/改写路由会失败并要求：

1. 先判断生产可达、模拟器专用或纯 UITest；
2. 更新 `route-coverage.csv` 的批次、状态、截图与测试；
3. 人工复核后刷新路由表层签名；
4. 重跑 `make -f scripts/Makefile verify-gate`。

文件名差集只作线索；私有子 View 不按独立页面凑数。CSV 中标为 `planned:*` 或 `new-v47-*` 的证据必须在对应批次落地，W15a 不得保留计划占位符。

## v54 路由与状态补充

- `TrainingHomeView`：登记无安排、只有官方建议、混合来源、部分完成、全完成和昨日未完 6 态。
- `PlanDetailView`：登记开始、切换、编排、完成后复练 4 种主 CTA，以及阶段/课程选择 sheet。
- `DrillDetailView` 和 `CustomPlanBuilderView`：登记“加入今日安排”路径，不再经由模版激活/替换官方主线。
- `TrainingDetailView`：登记来源存在可跳转与源已删除只读两态。
- 自动截图真源为 `build/ui-reviews/v54/`：iPhone / iPad × Light / Dark，共 52 张；动态字体、VoiceOver 和真实长按拖动仍由 H-27 人工验收。

## 2026-09-27 每日3D测量接入审计

本轮 FreePlayView 仅增加显式 `-daily3D.diagnostics` 的阶段标记与生命周期回调，既有导航、sheet目的地、玩法和存档入口保留。签名差异来自sheet后7行窗口中的 `updateDaily3DPlaybackDiagnostics()`，已与冻结源码逐行核对（`build/daily-3d-20260927/route-signature-review.patch`）；只刷新该文件签名。CSV补充普通及诊断开关的idle回归状态；测试校准当前横屏状态标识、窗口坐标和上手杆数语义，不改生产规则。验收见 `tasks/DAILY-CLEARANCE-3D-20260927.md`，模拟器证据不代表真机性能完成。

## 2026-09-24 每日交互与规则路由审计

FreePlay既有玩法/开球sheet保留；每日重开改成同页双操作浮层，规则裁决也是同页状态，不增加生产目的地。签名漂移来自sheet后7行采样包含的开球镜头onChange调整，已对照本轮baseline核实后仅刷新FreePlay签名。RootView新增dailyInteraction.sharedPage是DEBUG启动参数取证入口；batch额外限制targetEnvironment(simulator)，不进入真机。覆盖状态已追加CSV；本轮证据见tasks/每日清台交互规则_交付验收.md。
