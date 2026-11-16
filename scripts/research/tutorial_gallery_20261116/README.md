# 精讲图集手势诊断与验证（2026-11-16）

结果、设备边界与原始失败见 `tasks/table-page-adaptation/TUTORIAL-GALLERY-20261116.md`。

- `prepare.py`：通过local_test_lifecycle在隔离副本冻结当前工作源码，输出baseline和注入清单；UI-only scheme去除不相关单元测试target，正式scheme不变。`--diagnosis`只适用于修复前仍含`dragGesture`的源码，用于历史同构建A/B；现已修复的源码会主动assert拒绝，不应为重跑诊断而回退共享工作区。
- `diagnosis.swift`：历史原版/禁用内层drag对照，按真实详情→精讲→图片进入。
- `pan-surface.swift`、`apply_candidate.py`：本轮候选及一次性迁移记录；正式实现以`DrillTutorialView.swift`为准，不重复执行。
- `regression.swift`：本轮回归模板，正式测试以`QiuJiUITests/V49W12CopyEvidenceUITests.swift`中的`TutorialGalleryGestureUITests`为准。
- `analyze.py`：在受管work目录clone xcresult后读取/导出，避免较新xcresulttool升级原件数据库。原始回传receipt必须保留且不可改写。

远端执行统一走`mac_mini_queue.py`，使用模拟器生命周期；所有本轮临时工作目录由`local_test_lifecycle.py`管理。不改变用户设备或正式内容。
