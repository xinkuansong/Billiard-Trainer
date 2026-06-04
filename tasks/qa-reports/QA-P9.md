# QA-P9 验收报告 — Aiming Feature Expansion

- **角色**：QA Reviewer
- **日期**：2026-06-02
- **范围**：P9 角度训练 Tab 扩展（7 子功能 + SceneKit 2D/3D + 数据层 quizType + 历史筛选）
- **结论**：✅ **通过**（2 项缺口已当场修复 + 回归；人工功能验收由用户确认通过）

---

## 一、验收方式

| 维度 | 方式 | 结果 |
|------|------|------|
| 编译 | `make build`（iPhone 17 Pro / iOS 26.2 SDK） | ✅ BUILD SUCCEEDED |
| 自动化测试 | `xcodebuild test -only-testing:QiuJiTests` | ✅ **241/241 通过** |
| 代码侧逐条复核 | 对照 P9 phase 卡 DoD + 设计 APPROVED | 见下表 |
| 运行时功能（SceneKit 加载 / 2D↔3D / 角度计算 / 断网 / Dark Mode） | **用户人工验收** | ✅ 用户确认通过 |

> 注：本次同时修复了让整套 `QiuJiTests` 命令行从未跑通的测试宿主/模块名配置（见 PD-007），P9 之外的历史单测也一并恢复绿灯。

---

## 二、QA 验收要点逐条

| # | 验收要点 | 结论 | 证据 / 备注 |
|---|----------|------|-------------|
| 1 | 纯离线：7 子功能零网络依赖 | ✅ | 页面/VM 无 URLSession/APIClient；答题持久化仅本地 `LocalAngleTestRepository.save` → `SyncQueueManager.enqueue`（离线入队、联网后台同步），不阻塞功能 |
| 2 | SceneKit 加载 USDZ 无崩溃 | ✅（用户验收） | `TableModelLoader.loadTable()` Bundle 加载 + Z-up→Y-up + surfaceY 推算；`TaiQiuZhuo.usdz` 已登记 `project.yml`/`pbxproj` resources |
| 3 | 2D/3D 切换流畅、正交无变形 | ✅（用户验收） | `AngleTrainingScene.setCameraMode` 两相过渡；`SceneAngleViewModel.toggleCameraMode` |
| 4 | 角度计算一致（2D/3D 同题同解） | ✅ | `AngleSceneCalculator.normalizedToScene/sceneToNormalized` **往返精度 < 0.001**，新增 6 条 XCTest 全通过 |
| 5 | 数据迁移 quizType 默认 table2D | ✅ | `AngleTestResult.quizType: String = "table2D"`（非可选 + init 默认），历史页向后兼容旧数据归入「球台 2D」 |
| 6 | Freemium 免费 20 题/天 | ✅（**修复后**） | Scene 页原已生效；**几何页缺 UI 阻断 → FL-016 已修复**（剩余指示 + 限额卡 + 解锁入口 + 按钮禁用） |
| 7 | Dark Mode 全页正确（BT* Token） | ✅ | 文档/列表页用 BT Token；Scene/全屏 HUD 沿用黑底白字叠加层惯例（设计 APPROVED 认可）；对照表曲线标记点硬编码 `.red` → 改 `.btAccent` |
| 8 | 对照表数值与 2sin(θ) 一致 | ✅ | `d/R = 2.0 * sin`、`d(mm) = d/R × R`、正弦曲线 `2sin(θ)`、19×5° + 48.6° 高亮行 |
| 9 | 教学内容台球技术准确 | ✅（用户抽查） | 瞄准原理/浅淡球感公式遵循 `45-aiming-principles.mdc` |

---

## 三、本次发现并处理的缺口

### 缺口 1（P1，已修复）— 几何训练 Freemium 闸门缺失 → **FL-016**
几何角度训练只计数不阻断，免费用户可无限刷题。已对齐 `SceneAnglePredictionView` 范式补齐 UI 阻断 + 升级入口。

### 缺口 2（已补）— `AngleSceneCalculator` 往返映射无测试 → T-P9-02 DoD
补 6 条 XCTest（往返精度 < 0.001 / 中心映射原点 / 满台跨度 / 2sinα / 幽灵球 / 直球 0°），全通过。

### DoD 与设计的核对（非缺陷）
- **对照表球种切换**：T-P9-09 任务卡 DoD 列了「斯诺克/中八/美式」切换，但 **P9-05 设计迭代 APPROVED 明确决定移除球种切换、固定中八（R=28.575mm）**。现有实现遵循**已签收的设计**，判定为符合预期；任务卡 DoD 以设计 APPROVED 为准（见 DR 备注）。
- **对照表行数**：DoD 写「19 行每 5°」，实现为 19×5° + 48.6°(3/4 球) 共 20 行，特例行更精确，判定通过。

### 测试基建修复 → **PD-007**
`TEST_HOST` 指向 `QiuJi.app` 而产物是 `球迹.app`，且缺 `PRODUCT_MODULE_NAME` 致 `@testable import QiuJi` 失败 → 整套 `QiuJiTests` 命令行从未跑通。已在 `project.yml` + `pbxproj` 双向钉死，恢复 241/241。

---

## 四、遗留（非阻塞，转后续轨道）

| 项 | 处置 |
|----|------|
| `TableModelLoader` 无单测（需 Bundle/模拟器宿主） | 转 Test Engineer backlog；运行时由用户人工验收覆盖 |
| Scene/全屏页大量 `.white`/`.black` 叠加层 | 属 SceneKit HUD 叠加惯例，设计 APPROVED 认可，保留 |
| 3D 帧率 ≥30fps（iPhone 12） | 真机/TestFlight 补测（与 P6/P8 同批待测项一致） |

---

## 五、签收

P9 实现任务（T-P9-01~11）DoD 满足；QA-P9 验收要点全部通过（含修复项回归）。**QA-P9：✅ 通过**。
