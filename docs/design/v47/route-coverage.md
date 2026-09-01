# v47 生产路由与页面覆盖

机器可读真源为 `route-coverage.csv`。当前登记 69 个页面：每行必须具备 View、页面族、批次、状态、截图、测试、可达范围和源码锚点；`verify_v47_ui_baseline.py` 会验证必需页面、源码声明与路由表层签名。

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
