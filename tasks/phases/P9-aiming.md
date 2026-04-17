# P9 — Aiming Feature Expansion（瞄准功能全面升级）

> **目标**：将角度 Tab（Tab 3）从 3 个子功能扩展到 7 个子功能模块，引入 SceneKit + TaiQiuZhuo.usdz 统一 2D/3D 角度预测。
> **特点**：纯本地计算，零网络依赖，离线完整可用；SceneKit 2D 俯视（正交投影）与 3D 透视共用同一场景。
> **前置 Phase**：P5 已完成，P8 进行中（不阻塞本 Phase）
> **建议时长**：10-14 个会话（含 UI 设计）
> **参考资源**：
> - `Billiard-Aiming-Trainer`（Web/JS，已克隆至 `/Users/song/projects/Billiard-Aiming-Trainer`）
> - `01.billiard_app/BilliardTrainer`（iOS/SceneKit，`/Users/song/projects/01.billiard_app/BilliardTrainer`）
> - `lecepin` 假想球页面（`https://lecepin.github.io/billiard-aim-calculation/imaginary-ball.html`）
> **瞄准原理权威规则**：`.cursor/rules/45-aiming-principles.mdc`（所有公式、术语、代码命名以此为准）
> **设计参考源**（优先级顺序）：
> 1. `tasks/UI-IMPLEMENTATION-SPEC.md`（合并后的实施规范，活跃文档）
> 2. 本 Phase 产出的 `ui_design/tasks/P9-xx/stitch_task_*/screen.png`（视觉参考）
> 3. 本 Phase 产出的 `ui_design/tasks/P9-xx/stitch_task_*/code.html`（HTML 原型）
> 4. 现有角度页面设计：`ui_design/tasks/P0-07/`（AngleTestView）、`ui_design/tasks/P1-05/`（AngleHomeView + ContactPointTableView）

---

## 通用 DoD 条目（适用于本 Phase 所有 UI 任务）

> 每个 UI 实现任务除自身 DoD 外，还须满足以下条目：
>
> - [ ] 使用 R0 BT* 组件，不自建临时组件
> - [ ] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
> - [ ] Light + Dark `#Preview` 通过视觉检查
> - [ ] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog
>
> **设计参考三步流程（每个 UI 任务必执行）**：
> 1. `screen.png` — 整体视觉印象与布局结构
> 2. `code.html` — 提取精确布局数值（间距、字号、排列方式、固定/滚动行为）
> 3. `UI-IMPLEMENTATION-SPEC.md` — Token 与组件 API（与截图/HTML 冲突时以本文件为准）

---

## 架构决策：2D/3D 统一方案

**结论**：2D 和 3D 角度预测共用同一 SceneKit 场景（`AngleTrainingScene`），通过 `CameraMode` 切换视角：
- **2D 模式**：正交投影 + 俯视相机（pitch -90°），与参考 app 的 `topDown2D` 一致
- **3D 模式**：透视投影 + `CameraRig` 轨道控制（zoom/yaw/pitch），支持 pinch 缩放 + 旋转

参考实现：`01.billiard_app` 的 `BilliardScene.setCameraMode(.topDown2D)` 使用 `usesOrthographicProjection = true`，两相动画过渡（perspective → orthographic）。

**共享层**：
- `AngleTrainingScene`：SceneKit 场景，管理球台模型、球节点、瞄准线/幽灵球节点、相机
- `TableModelLoader`：加载 `TaiQiuZhuo.usdz`，缩放对齐，提取台面高度
- `CameraRig`：zoom/yaw 轨道控制（3D 模式），正交缩放/平移（2D 模式）
- `AngleCalculator`：扩展 `generateQuestion3D()` 输出 `SCNVector3` 坐标

**差异层**：
- 2D：禁用 `CameraRig` 轨道，使用正交 pan/pinch；HUD 覆盖角度输入
- 3D：启用 `CameraRig`，用户可自由旋转/缩放观察球台后输入角度

---

## Phase P9-D：UI 设计任务（Design Phase）

> 遵循与 Phase A-E 相同的设计流程：Stitch 生成 → 审查 → 迭代 → APPROVED.md 签收。
> 每个设计任务产出：`stitch_task_*/screen.png` + `code.html` + `DESIGN.md`，并在 `APPROVED.md` 中记录最终帧路径和关键决策。
> 完成后更新 `tasks/UI-IMPLEMENTATION-SPEC.md` 第四章页面-组件映射表，新增对应行。

---

### T-P9-D-01 AngleHomeView 重设计

- **负责角色**：SwiftUI Developer（设计 + 实现一体）
- **前置依赖**：T-P9-00
- **产出物**：`ui_design/tasks/P9-01/`
- **参考**：现有 `ui_design/tasks/P1-05/`（AngleHomeView v1）、训记主页 `ref-screenshots/01-training-home/`

#### 设计要求

- 在现有 3 入口基础上扩展为 **分组卡片布局**（7 个功能 + 1 个历史入口）
- **学习区** Section 标题 + 3 张卡片行：瞄准原理、角度与打点、浅淡球感
- **训练区** Section 标题 + 3 张卡片行：几何角度训练、球台角度预测（2D/3D 统一入口）、现有角度测试（保留兼容）
- **工具区**：进球点对照表
- **底部**：测试历史行（保留现有样式）
- 卡片样式沿用现有 FeatureCard 模式（浅绿底圆形图标 + 标题/副标题 + chevron）
- 球台角度预测卡片需标注"2D/3D"标签或 badge
- Light + Dark 各出 1 帧

#### DoD

- [ ] 帧 1（Light）：`stitch_task_p9_01_anglehome/screen.png` + `code.html`
- [ ] 帧 2（Dark）：`stitch_task_p9_01_anglehome_dark/screen.png`
- [ ] `APPROVED.md` 签收
- [ ] `UI-IMPLEMENTATION-SPEC.md` Tab 3 映射表更新

---

### T-P9-D-02 AimingPrincipleView 设计

- **负责角色**：SwiftUI Developer
- **前置依赖**：无
- **产出物**：`ui_design/tasks/P9-02/`
- **参考**：`ui_design/tasks/P1-05/`（ContactPointTableView 的卡片+滚动布局模式）

#### 设计要求

- 纯教学内容页，ScrollView 长页面
- Section 1：切球角示意 Canvas（顶视球台局部 + 三点标注）
- Section 2：核心公式卡片（monospace 公式 + 30 度交互示例）
- Section 3：假想球法分步图解（3 步 Canvas + 半透明幽灵球）
- Section 4：厚薄球概念（4 个 Canvas 小图横排）
- 页面风格：工具子页面模式（返回箭头 + 中文标题，无底部 Tab 栏），与 ContactPointTableView 一致
- Light 出 1 帧（内容完整），Dark 出 1 帧（验证适配）

#### DoD

- [ ] 帧 1（Light）：`stitch_task_p9_02_aimingprinciple/screen.png` + `code.html`
- [ ] 帧 2（Dark）：`stitch_task_p9_02_aimingprinciple_dark/screen.png`
- [ ] `APPROVED.md` 签收

---

### T-P9-D-03 AngleDynamicView 设计

- **负责角色**：SwiftUI Developer
- **前置依赖**：无
- **产出物**：`ui_design/tasks/P9-03/`
- **参考**：Billiard-Aiming-Trainer 的 aimView（球台 + 第一人称重叠视图）

#### 设计要求

- 上方：交互式球台 Canvas（目标球 + 袋口 + 母球可拖 + 幽灵球 + 瞄准线 + 角度扇形 + 接触点）
- 中间：第一人称重叠视图 Canvas（假想球紫色 + 目标球红色 + d/R 数值 + 厚薄分类标签）
- 下方：数值面板（角度、sin(α)、偏移%、d/R、通称）
- 底部 Slider（0-85°）或拖动母球两种交互方式
- 袋口可点击切换（选中金色环）
- Light + Dark 各 1 帧

#### DoD

- [ ] 帧 1（Light，母球在某位置）：`stitch_task_p9_03_angledynamic/screen.png` + `code.html`
- [ ] 帧 2（Dark）：`stitch_task_p9_03_angledynamic_dark/screen.png`
- [ ] `APPROVED.md` 签收

---

### T-P9-D-04 GeometricAngleQuizView 设计

- **负责角色**：SwiftUI Developer
- **前置依赖**：无
- **产出物**：`ui_design/tasks/P9-04/`
- **参考**：Billiard-Aiming-Trainer 的 angleCanvas（坐标系 + 随机角度线 + 统计面板）

#### 设计要求

- 帧 1（答题中）：绿色背景坐标系 Canvas（原点/X轴/Y轴/角度线/扇形）+ 数字输入框 + 确认按钮 + 底部统计面板
- 帧 2（结果反馈）：同上 + 显示实际角度 + 误差 + 判定 chip + 参考角度网格（可选开关）
- 控制按钮行："生成随机角度" / "显示参考角度" / "重置统计"
- 统计面板：练习次数、正确次数、正确率、平均误差
- 整体风格匹配 App 内卡片式布局

#### DoD

- [ ] 帧 1（Light，答题中）：`stitch_task_p9_04_geometricquiz/screen.png` + `code.html`
- [ ] 帧 2（Light，结果反馈 + 参考线）：`stitch_task_p9_04_geometricquiz_result/screen.png` + `code.html`
- [ ] `APPROVED.md` 签收

---

### T-P9-D-05 SceneAnglePredictionView 设计

- **负责角色**：SwiftUI Developer
- **前置依赖**：无
- **产出物**：`ui_design/tasks/P9-05/`
- **参考**：现有 `ui_design/tasks/P0-07/`（AngleTestView）+ 01.billiard_app 的 3D 球台截图

#### 设计要求

- 帧 1（2D 俯视 — 答题中）：顶部 BTSegmentedTab（"俯视 2D" / "3D 视角"）+ SceneKit 球台俯视渲染区 + 底部 HUD（题号进度 + 角度输入 + 确认按钮）
- 帧 2（2D 俯视 — 结果）：球台叠加结果线（绿色击球线 + 橙色用户线 + 红色接触点 + 黄色幽灵球 + 角度扇形）+ 底部结果面板（误差 + 判定 chip + 下一题按钮）+ 内嵌第一人称重叠视图
- 帧 3（3D 视角 — 答题中）：透视球台 + 同样底部 HUD
- 帧 4（3D 视角 — 结果）：3D 空间中的结果线/幽灵球 + 底部结果面板
- 帧 5（训练设置）：训练类型 Picker 面板 / 模式选择（20 题 / 自由练习）
- 帧 6（总结页）：复用现有 AngleTestView 总结样式（检查/题数/平均误差/精准数）
- 底部 HUD 覆盖在 SceneKit 视图上，使用毛玻璃背景
- Light + Dark 至少帧 1、帧 2 出 Dark 版

#### DoD

- [ ] 帧 1-6（Light）+ 帧 1-2（Dark）：`stitch_task_p9_05_sceneprediction_*/screen.png` + `code.html`
- [ ] `APPROVED.md` 签收
- [ ] `UI-IMPLEMENTATION-SPEC.md` Tab 3 映射表新增 SceneAnglePredictionView 行

---

### T-P9-D-06 ContactPointTableView 增强设计

- **负责角色**：SwiftUI Developer
- **前置依赖**：无
- **产出物**：`ui_design/tasks/P9-06/`
- **参考**：现有 `ui_design/tasks/P1-05/`（ContactPointTableView v1）+ Billiard-Aiming-Trainer 的对照表 + 正弦曲线

#### 设计要求

- 帧 1：在现有基础上增加——
  - 顶部 BTSegmentedTab（斯诺克 / 中八 / 美式）球种切换
  - 交互式滑块增加 d/R 数值显示
  - 静态表扩展为 19 行（每 5 度），新增 d/R 列 + 实际 d(mm) 列
  - 通称扩展（1/4 球、1/3 球等）
- 帧 2：新增正弦曲线图 Section（Canvas 绘制 `2sin(θ)` vs 角度，标注特殊角度点）
- Light + Dark 各 1 帧

#### DoD

- [ ] 帧 1-2（Light）：`stitch_task_p9_06_contactpoint_*/screen.png` + `code.html`
- [ ] 帧 1（Dark）：`stitch_task_p9_06_contactpoint_dark/screen.png`
- [ ] `APPROVED.md` 签收
- [ ] `UI-IMPLEMENTATION-SPEC.md` ContactPointTableView 行更新

---

### T-P9-D-07 BallFeelView 设计

- **负责角色**：SwiftUI Developer
- **前置依赖**：无
- **产出物**：`ui_design/tasks/P9-07/`
- **参考**：AimingPrincipleView 同风格（教学内容页）

#### 设计要求

- 纯教学内容长页面
- Section 1：什么是球感（图文，概念引入）
- Section 2：4 个 Canvas 小图（全球/半球/3/4 球/薄球从母球视角的视觉印象）
- Section 3：训练建议（推荐使用路径：原理→几何→2D→3D→实战）
- Section 4：2D vs 3D 视角对比 Canvas（同一球形的俯视 vs 站位视角）
- Light 1 帧（完整内容）

#### DoD

- [ ] 帧 1（Light）：`stitch_task_p9_07_ballfeel/screen.png` + `code.html`
- [ ] `APPROVED.md` 签收

---

### T-P9-D-REVIEW 设计一致性审查

- **负责角色**：QA Reviewer
- **前置依赖**：T-P9-D-01 ~ T-P9-D-07 全部完成
- **产出物**：`ui_design/tasks/P9-REVIEW/consistency-review.md`

#### DoD

- [ ] 全部 7 个设计任务帧通过一致性审查（字体/间距/颜色/图标风格与现有页面一致）
- [ ] Dark Mode 帧使用正确的 BT* Token
- [ ] 与现有 AngleTestView / ContactPointTableView 视觉连续性无断裂
- [ ] 审查报告记录所有偏差，区分 P1（必修）/ P2（改进）

---

## Phase P9：实现任务（Implementation Phase）

---

## T-P9-00 UI 设计交付文档更新

- **负责角色**：Content Engineer
- **前置依赖**：无（Phase 首任务）
- **产出物**：更新 `ui_design/09-UI设计交付文档.md` § 3.3 角度训练 部分

### DoD

- [ ] 在 `09-UI设计交付文档.md` § 3.3 新增以下页面规格：
  - `3.3.6 AimingPrincipleView — 瞄准原理`
  - `3.3.7 AngleDynamicView — 角度与打点动态关系`
  - `3.3.8 GeometricAngleQuizView — 纯几何角度预测训练`
  - `3.3.9 SceneAnglePredictionView — 球台角度预测（2D/3D）`
  - `3.3.10 BallFeelView — 浅淡球感`
- [ ] 更新 `3.3.1 AngleHomeView` 为 7 功能入口分组布局
- [ ] 更新 `3.3.3 ContactPointTableView` 增加 19 行 + d/R + 球种切换 + 正弦曲线
- [ ] 每个新页面规格含：文件路径、功能描述、页面元素、交互说明、Freemium 限制
- [ ] 在 § 2.3 导航树中更新 Tab 3 子页面
- [ ] 在 § 7.5 设计交付物清单中新增 P9 行

---

## T-P9-01 SceneKit 场景基础设施

- **负责角色**：iOS Architect
- **前置依赖**：无
- **产出物**：
  - `QiuJi/Core/Scene/TableModelLoader.swift`
  - `QiuJi/Core/Scene/AngleTrainingScene.swift`
  - `QiuJi/Core/Scene/CameraRig.swift`
  - `QiuJi/Core/Scene/AngleSceneView.swift`（`UIViewRepresentable` 封装 `SCNView`）
  - `QiuJi/Resources/TaiQiuZhuo.usdz`（加入 Xcode Target）
- **参考代码**：`01.billiard_app/BilliardTrainer/Core/Scene/` 下 `TableModelLoader.swift`、`BilliardScene.swift`、`CameraRig.swift`、`BilliardSceneView.swift`

### DoD

- [ ] `TableModelLoader.loadTable()` 从 Bundle 加载 `TaiQiuZhuo.usdz`，返回 `TableModel`（visualNode + appliedScale + surfaceY）
- [ ] USDZ Z-up → Y-up 处理：检测模型坐标系，必要时对 container 施加绕 X 轴 -90° 旋转
- [ ] 统一缩放：按模型 bounding box 与目标台面尺寸（中式八球 2.54m x 1.27m 内框）计算 uniform scale，居中到原点
- [ ] `surfaceY` 从库顶 bounding 推算台面高度
- [ ] 模型内相机/灯光节点移除，物理体禁用（视觉与物理分离）
- [ ] `AngleTrainingScene` 继承 `SCNScene`：
  - `setupTable()`：调用 `TableModelLoader`，`yOffset` 对齐
  - `setupCamera()`：创建 `SCNCamera` + `cameraNode`，初始化 `CameraRig`
  - `setupLighting()`：环境光 + 定向光（简化版，非全物理光照）
  - `CameraMode` enum：`.topDown2D` / `.perspective3D`
  - `setCameraMode(_:animated:)`：正交/透视切换，含两相过渡动画（参考 `transitionToTopDownTwoPhase`）
- [ ] `CameraRig`：
  - `zoom` 0-1 插值控制 radius/height/pitch/FOV
  - `handleHorizontalSwipe` / `handleVerticalSwipe` / `handlePinch`
  - `update(deltaTime:)` 阻尼平滑
  - 2D 模式下 `applyCameraPan` + `applyTopDownAreaZoom`（锚点缩放）
- [ ] `AngleSceneView`（`UIViewRepresentable`）：
  - `makeUIView`：创建 `SCNView`，绑定场景，`allowsCameraControl = false`
  - 手势注册：单指拖动（3D 旋转 / 2D 平移）、pinch（3D/2D 缩放）、tap（袋口选择）
  - `CADisplayLink` 渲染循环：2D 跳过 CameraRig，3D 调用 `CameraRig.update`
- [ ] `TaiQiuZhuo.usdz` 已加入 Xcode Target `QiuJi`，`project.yml` 更新 resources 节
- [ ] XCTest：`TableModelLoader.loadTable()` 返回非 nil，`surfaceY` > 0
- [ ] **ADR-P9-01**：记录 SceneKit 引入决策（系统框架，非第三方 SPM；视觉与物理分离；包体积影响）

---

## T-P9-02 数据层扩展

- **负责角色**：Data Engineer
- **前置依赖**：无（可并行 T-P9-01）
- **产出物**：
  - 更新 `QiuJi/Data/Models/AngleTestResult.swift`
  - `QiuJi/Core/Scene/AngleSceneCalculator.swift`（3D 坐标映射）

### DoD

- [ ] `AngleTestResult` 新增 `quizType: String` 属性，默认值 `"table2D"`，可选值：`"geometric"` / `"table2D"` / `"scene2D"` / `"scene3D"`
- [ ] SwiftData 轻量级迁移：新增可选字段 + 默认值，不破坏现有数据
- [ ] XCTest：旧数据（无 quizType 字段）加载后自动补 `"table2D"`
- [ ] `AngleSceneCalculator`：
  - `normalizedToScene(point:tableSize:surfaceY:)` → `SCNVector3`：将 AngleCalculator 归一化坐标 (0-1, 0-0.5) 映射到 SceneKit 世界坐标
  - `sceneToNormalized(position:tableSize:)` → `CGPoint`：反向映射
  - `ghostBallPosition(targetBall:pocket:ballRadius:)` → `SCNVector3`：幽灵球位置
- [ ] XCTest：坐标映射往返精度 < 0.001

---

## T-P9-03 AngleHomeView 导航重构

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P9-D-01（设计签收）
- **产出物**：更新 `QiuJi/Features/AngleTraining/Views/AngleHomeView.swift`，更新 `QiuJi/App/MainTabView.swift`
- **设计参考**：`ui_design/tasks/P9-01/stitch_task_p9_01_anglehome/screen.png`

### DoD

- [ ] 布局对照设计稿，遵循三步参考流程
- [ ] `AngleRoute` enum 新增：`.aimingPrinciple` / `.angleDynamic` / `.geometricQuiz` / `.scenePrediction` / `.ballFeel`
- [ ] `MainTabView` 的 `angleDestination` 注册所有新路由
- [ ] AngleHomeView 布局改为分组（对照设计帧 1）：
  - **学习** Section（标题 + 3 张卡片）：瞄准原理、角度与打点、浅淡球感
  - **训练** Section（标题 + 3 张卡片）：几何角度训练、球台角度预测（2D/3D 统一入口）、现有角度测试（保留兼容）
  - **工具** Section：进球点对照表
  - **底部**：测试历史（保留现有样式）
- [ ] 每张卡片使用现有 `FeatureCard` 组件，icon 使用 SF Symbols
- [ ] 球台角度预测卡片标注"2D/3D"badge
- [ ] `UI-IMPLEMENTATION-SPEC.md` Tab 3 映射表更新

---

## T-P9-04 瞄准原理页

- **负责角色**：SwiftUI Developer + Content Engineer
- **前置依赖**：T-P9-03（路由注册），T-P9-D-02（设计签收）
- **产出物**：`QiuJi/Features/AngleTraining/Views/AimingPrincipleView.swift`
- **设计参考**：`ui_design/tasks/P9-02/stitch_task_p9_02_aimingprinciple/screen.png`

### DoD

- [ ] 纯 SwiftUI ScrollView 页面，`.navigationTitle("瞄准原理")`，隐藏 tabBar
- [ ] **Section 1 — 什么是切球角**：
  - Canvas 顶视图示意（btTableFelt 背景）：母球、目标球、袋口三点 + 标注切球角 α
  - 文字说明：进球线 = 目标球中心→袋口；击球线 = 白球中心→幽灵球中心；切球角 α = 两者夹角
  - **术语与公式遵循 `.cursor/rules/45-aiming-principles.mdc`**
- [ ] **Section 2 — 核心公式**：
  - 主公式展示：`d = 2R × sin(α)`（横移量），monospace 字体，btPrimary 色
  - 派生公式：`接触点偏移 = R × sin(α)`，明确标注为派生量
  - 30° 交互示例：Canvas 绘制目标球 + 幽灵球偏移 d/R = 1.0，接触点偏移 50%
  - 附加说明：sin(30°) = 0.5，横移量 d = 2R × 0.5 = R（即幽灵球中心偏移一个球半径）
- [ ] **Section 3 — 假想球法（Ghost Ball）**：
  - Canvas 分步图解：
    1. 确定进球线：目标球中心→袋口方向
    2. 定位幽灵球：目标球中心沿进球线反向偏移 2R（`ghostBallCenter = targetCenter - 2R × normalize(pocket - targetCenter)`）
    3. 确定击球线：白球中心→幽灵球中心，白球沿此线运动
    4. 接触瞬间：白球与目标球连心线与进球线重合，目标球沿进球线入袋
  - 半透明黄色假想球叠加渲染
- [ ] **Section 4 — 厚薄球概念**：
  - 4 个 Canvas 小图：全球(0°)、半球(30°)、3/4 球(48.6°)、极薄球(90°)
  - 每个配通称 + 偏移百分比

---

## T-P9-05 角度与打点动态关系页

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P9-03（路由注册），T-P9-D-03（设计签收）
- **产出物**：`QiuJi/Features/AngleTraining/Views/AngleDynamicView.swift`
- **设计参考**：`ui_design/tasks/P9-03/stitch_task_p9_03_angledynamic/screen.png`
- **参考代码**：`Billiard-Aiming-Trainer/script.js` 的 `drawAimingLines()`、`drawAngleIndicators()`、`drawFirstPersonOverlap()`

### DoD

- [ ] `.navigationTitle("角度与打点")`，隐藏 tabBar
- [ ] **上方 — 交互式球台 Canvas**（复用 `TableRender` 常量）：
  - 固定目标球 + 袋口（初始随机或可选）
  - 用户可通过 **Slider**（0-85°）或 **DragGesture 拖动母球** 实时调整切球角
  - 实时渲染：
    - 目标球→袋口白色虚线（进球线）
    - 幽灵球位置（半透明黄色，`ghostBallCenter = targetCenter - 2R × normalize(pocket - targetCenter)`）
    - 母球→幽灵球蓝色虚线（击球线）
    - 切球角扇形标注（黄色半透明弧 + 角度数值）
    - 接触点红点（目标球表面，从母球方向）
    - 过目标球中心垂直于瞄准线的黄色辅助线
  - 袋口可点击切换（选中金色环，其他绿色虚线环）
- [ ] **下方 — 第一人称重叠视图** Canvas：
  - 从母球视角看，两个圆（假想球紫色 + 目标球红色）的重叠关系
  - `d/R = 2sin(θ)` 实时数值显示
  - 厚薄球分类标签（≤1/4, (1/4,1/3], (1/3,1/2], (1/2,1], >1）
- [ ] **底部 — 数值面板**：当前角度、sin(α)、偏移百分比、d/R、通称
- [ ] Canvas 渲染帧率 >= 30fps（Slider 拖动时无卡顿）

---

## T-P9-06 纯几何角度预测训练

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P9-02（quizType 字段），T-P9-03（路由注册），T-P9-D-04（设计签收）
- **产出物**：
  - `QiuJi/Features/AngleTraining/Views/GeometricAngleQuizView.swift`
  - `QiuJi/Features/AngleTraining/ViewModels/GeometricAngleViewModel.swift`
- **设计参考**：`ui_design/tasks/P9-04/stitch_task_p9_04_geometricquiz/screen.png`
- **参考代码**：`Billiard-Aiming-Trainer/script.js` 的 `drawAngleCanvas()`、`generateRandomAngle()`、`submitAngleGenPrediction()`

### DoD

- [ ] `.navigationTitle("角度预测")`，隐藏 tabBar
- [ ] **角度显示 Canvas**（btTableFelt 背景，类球台绿色）：
  - 坐标原点在左下，X 轴（0° 方向）+ Y 轴（90° 方向），白色实线
  - 随机角度线：从原点出发，白色粗线，长度为 Canvas 对角 × 0.8
  - 角度扇形：原点处小半径半透明白色填充
  - 可选参考角度网格：15/30/45/60/75° 虚线（浅绿色），同心弧辅助线
  - 原点实心白色圆点
- [ ] **交互流程**：
  - "生成随机角度" 按钮（btPrimary）→ 生成 0-90° 连续随机角
  - 数字键盘 TextField（0-90），"确认" 按钮
  - 结果判定：误差 ≤3° = 精准（btSuccess）/ 3-10° = 接近（btWarning）/ >10° = 偏差大（btDestructive）
  - 显示实际角度 + 误差
  - 可选"显示/隐藏参考角度"切换
- [ ] **统计面板**（底部卡片）：
  - 练习次数、正确次数（≤3°）、正确率、平均误差
  - "重置统计" 按钮
- [ ] 每次提交保存 `AngleTestResult`（quizType = "geometric"）
- [ ] Freemium：复用 `AngleUsageLimiter`，免费 20 题/天

---

## T-P9-07 SceneKit 角度预测页（2D/3D 统一）

- **负责角色**：SwiftUI Developer + iOS Architect
- **前置依赖**：T-P9-01（SceneKit 基础设施），T-P9-02（数据层），T-P9-D-05（设计签收）
- **产出物**：
  - `QiuJi/Features/AngleTraining/Views/SceneAnglePredictionView.swift`
  - `QiuJi/Features/AngleTraining/ViewModels/SceneAngleViewModel.swift`
- **设计参考**：`ui_design/tasks/P9-05/stitch_task_p9_05_sceneprediction_*/screen.png`（帧 1-6）
- **参考代码**：
  - `01.billiard_app` 的 `BilliardSceneView`（UIViewRepresentable + 手势）、`BilliardScene`（setCameraMode）
  - 现有 `AngleTestView` + `AngleTestViewModel`（流程逻辑）

### DoD

- [ ] `.navigationTitle("球台角度预测")`，隐藏 tabBar
- [ ] **SceneKit 球台渲染**：
  - `AngleSceneView`（UIViewRepresentable）占据上半屏
  - 加载 `TaiQiuZhuo.usdz` 球台模型
  - 程序化创建母球（白色 `SCNSphere`）和目标球（红/黄色 `SCNSphere`），贴台面高度
  - 6 个袋口位置标记（可选高亮）
- [ ] **2D/3D 视角切换**：
  - 顶部 `BTSegmentedTab`（"俯视 2D" / "3D 视角"）或浮动按钮
  - 2D 模式：正交投影，相机 Y 轴向下看，禁用轨道旋转，支持 pan 平移 + pinch 缩放
  - 3D 模式：透视投影，CameraRig 轨道（单指水平旋转/垂直 zoom，pinch 缩放）
  - 模式切换带两相过渡动画（0.4s，perspective↔orthographic）
- [ ] **出题逻辑**：
  - 复用 `AngleCalculator.generateQuestion()`，通过 `AngleSceneCalculator.normalizedToScene()` 映射到 3D 坐标
  - 随机球位生成后，母球/目标球节点 `SCNAction.move` 动画到位
  - 袋口金色高亮环标记目标袋
- [ ] **角度输入**：
  - 底部 HUD 覆盖在 SceneKit 视图上：题号进度 + 数字键盘 TextField + "确认" 按钮
  - 确认后 SceneKit 视图暂停手势
- [ ] **结果展示**（SceneKit 内渲染）：
  - 正确击球路线：绿色 `SCNCylinder`（scale.y 拉伸），母球→目标球→袋口
  - 用户估计路线：橙色虚线效果（`SCNCylinder` + dash 材质或分段圆柱）
  - 接触点：红色小 `SCNSphere` 贴在目标球表面
  - 3D 模式下可旋转观察结果
- [ ] **结果面板**（底部 HUD）：
  - 用户答案 vs 正确答案 vs 误差
  - 评级 chip（精准/接近/偏差较大，复用现有样式）
  - "下一题" / "查看总结" 按钮
- [ ] 每次提交保存 `AngleTestResult`（quizType = "scene2D" 或 "scene3D"，按当前视角模式）
- [ ] 20 题制 + Freemium 限制（复用 `AngleUsageLimiter`）
- [ ] 3D 渲染帧率 >= 30fps（iPhone 12 及以上）

---

## T-P9-08 SceneKit 角度预测增强

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P9-07（基础页面可用）
- **产出物**：更新 `SceneAnglePredictionView` + `SceneAngleViewModel` + `AngleTrainingScene`
- **参考代码**：`Billiard-Aiming-Trainer/script.js` 的 `drawAimingLines()`、`drawFirstPersonOverlap()`、训练类型配置

### DoD

- [ ] **幽灵球**（提交后渲染）：半透明黄色 `SCNSphere`，位于目标球→袋口反方向 2R 处
- [ ] **瞄准线**（提交后渲染）：母球→幽灵球蓝色半透明 `SCNCylinder`（scale.y 变长度，避免每帧重建 geometry）
- [ ] **角度扇形**（提交后渲染）：目标球处黄色半透明扇形（`SCNShape` 或 `SCNGeometry` 自定义）标注切球角
- [ ] **第一人称重叠视图**：结果面板内嵌 SwiftUI Canvas，显示假想球/目标球重叠 + d/R 数值
- [ ] **训练类型选择**（进入前或顶部设置）：
  - 下拉/Picker：随机模式、近台直球、近台小角度、中台直球、中台小角度、远台中角度、远台大角度、中袋专项、角袋专项
  - 配置参考 `Billiard-Aiming-Trainer` 的 `trainingTypes`（距离 × 角度范围组合）
  - 影响 `AngleCalculator.generateQuestion()` 的约束参数
- [ ] **自由练习模式**：
  - 进入时可选"20 题模式"或"自由练习"
  - 自由练习不限题数，无总结页，底部始终显示"下一题"
  - 统计独立于 20 题模式（或合并，按 session 区分）
- [ ] **袋口切换**：tap 袋口标记切换目标袋（3D 中通过 hitTest，2D 通过 tap 位置映射）

---

## T-P9-09 进球点对照表增强

- **负责角色**：SwiftUI Developer + Content Engineer
- **前置依赖**：T-P9-03（路由注册），T-P9-D-06（设计签收）
- **产出物**：更新 `QiuJi/Features/AngleTraining/Views/ContactPointTableView.swift`
- **设计参考**：`ui_design/tasks/P9-06/stitch_task_p9_06_contactpoint_*/screen.png`
- **参考代码**：`Billiard-Aiming-Trainer/index.html` 对照表 + `script.js` 的 `drawSineCurve()`

### DoD

- [ ] **球种切换**（顶部 `BTSegmentedTab`）：斯诺克(R=26.25mm) / 中八(R=28.575mm) / 美式(R=28.575mm)
- [ ] **交互式滑块** 保留现有功能，增加 d/R 数值显示：`d/R = 2sin(α)`
- [ ] **静态表扩展为 19 行**（0-90° 每 5°）：
  - 列：切球角 / sin(α) / d/R / 偏移% / 实际 d(mm) / 通称
  - 实际 d(mm) = `2 × sin(α) × R`，按球种动态计算
  - 通称扩展：全球(0°) / 1/4球(~7.5°) / 1/3球(~10°) / 半球(30°) / 3/4 点(48.6°) / 极薄球(90°)
  - 有通称行高亮（btPrimaryMuted 背景）
- [ ] **正弦曲线图** 新增 Section：
  - Canvas 绘制 `2sin(θ)` vs 角度（0-90°）
  - X 轴标记 0/15/30/45/60/75/90°
  - Y 轴标记 0/0.5/1.0/1.5/2.0
  - 曲线 btPrimary 色，特殊角度标记点（红色小圆 + 数值标签）
  - 网格虚线辅助
- [ ] **原理说明**保留并补充 d/R 含义解释

---

## T-P9-10 浅淡球感页

- **负责角色**：Content Engineer + SwiftUI Developer
- **前置依赖**：T-P9-03（路由注册），T-P9-D-07（设计签收）
- **产出物**：`QiuJi/Features/AngleTraining/Views/BallFeelView.swift`
- **设计参考**：`ui_design/tasks/P9-07/stitch_task_p9_07_ballfeel/screen.png`

### DoD

- [ ] 纯 SwiftUI ScrollView 页面，`.navigationTitle("浅淡球感")`，隐藏 tabBar
- [ ] **Section 1 — 什么是球感**：图文说明，从理性分析到直觉判断的认知过程
- [ ] **Section 2 — 视觉锚点**：
  - 4 个 Canvas 小图展示全球/半球/3/4 球/薄球的"从母球看过去"视觉印象
  - 配合通称与角度数值
- [ ] **Section 3 — 训练建议**：
  - 角度测试与实战结合的方法论
  - 推荐使用本 App 各功能的路径（原理→几何练习→2D→3D→实战）
- [ ] **Section 4 — 2D 到 3D 的视角差异**：
  - Canvas 对比图：俯视 vs 站位视角下同一球形的感知差异
  - 引导用户使用 3D 模式缩小训练与实战的视角差

---

## T-P9-11 AngleHistoryView 增强

- **负责角色**：SwiftUI Developer + Data Engineer
- **前置依赖**：T-P9-02（quizType 字段），T-P9-06/07 至少一个完成
- **产出物**：更新 `QiuJi/Features/AngleTraining/Views/AngleHistoryView.swift`、`QiuJi/Features/AngleTraining/ViewModels/AngleHistoryViewModel.swift`

### DoD

- [ ] 顶部新增 `BTSegmentedTab`（"全部" / "几何" / "球台 2D" / "场景 2D" / "场景 3D"），按 quizType 筛选
- [ ] 统计卡片数值按筛选类型动态更新
- [ ] 趋势图和角度区间分析按筛选类型动态更新
- [ ] 空状态处理：某类型无数据时显示 `BTEmptyState`
- [ ] 向后兼容：旧数据（无 quizType）在"球台 2D"和"全部"中显示

---

## QA-P9 P9 验收

- **负责角色**：QA Reviewer

### 验收要点

- [ ] **纯离线**：断网状态下全部 7 个子功能完整可用（零网络依赖）
- [ ] **SceneKit 加载**：`TaiQiuZhuo.usdz` 正确加载，无崩溃，球台视觉正确（库边/袋口/台面对齐）
- [ ] **2D/3D 切换**：视角切换动画流畅（无闪烁/跳变），2D 正交投影正确（无透视变形）
- [ ] **角度计算正确**：3D 坐标映射后角度与 2D 一致（同一 question 在 2D/3D 中答案相同）
- [ ] **帧率**：3D 模式 >= 30fps（iPhone 12 Simulator），2D 模式 >= 60fps
- [ ] **手势冲突**：SceneKit 手势与 SwiftUI ScrollView/TabBar 无冲突
- [ ] **数据迁移**：旧版升级后现有 AngleTestResult 数据完整保留，quizType 默认 "table2D"
- [ ] **Freemium**：免费用户在几何训练、场景训练中均受 20 题/天限制
- [ ] **Dark Mode**：全部新页面 Light + Dark 正确（使用 BT* Token）
- [ ] **教学内容**：瞄准原理和浅淡球感内容台球技术准确（人工抽查）
- [ ] **对照表**：19 行数值与 `2sin(θ)` 计算一致，球种切换毫米数正确

---

## 批次执行建议

```
批次 0（文档 + 设计，1-2 个会话）：
  T-P9-00（UI 规格更新）
  → T-P9-D-01 ~ T-P9-D-07（UI 设计出图，可并行）
  → T-P9-D-REVIEW（一致性审查）

批次 1（基础设施，可并行，1-2 个会话）：
  T-P9-01（SceneKit 基础设施）
  T-P9-02（数据层扩展）
  T-P9-03（导航重构）

批次 2（独立页面，可并行，3-4 个会话）：
  T-P9-04（瞄准原理）
  T-P9-05（角度与打点）
  T-P9-06（几何角度训练）
  T-P9-09（对照表增强）
  T-P9-10（浅淡球感）

批次 3（SceneKit 核心，串行，2-3 个会话）：
  T-P9-07（SceneKit 角度预测基础页）
  → T-P9-08（增强：幽灵球 / 瞄准线 / 训练类型 / 自由练习）

批次 4（整合验收，1-2 个会话）：
  T-P9-11（历史增强）
  → QA-P9（全面验收）
```

预估总工作量：10-14 个会话。

---

## ADR 记录区

### ADR-P9-01 — SceneKit 引入决策

- **日期**：2026-04-14
- **状态**：已采纳
- **背景**：角度训练需要 2D 俯视与 3D 透视两种球台视角，用于角度预测训练。
- **决策**：使用 Apple 系统框架 SceneKit（非第三方 SPM），加载 TaiQiuZhuo.usdz 球台模型。
- **理由**：
  - SceneKit 为系统框架，零依赖成本，API 稳定
  - 支持 USDZ 原生加载，正交/透视投影切换
  - 参考项目 `01.billiard_app` 已验证该方案可行性
  - 仅用于视觉渲染，不使用 SceneKit 物理引擎（视觉与物理分离）
- **影响**：
  - 包体积增加 ~85MB（TaiQiuZhuo.usdz）
  - 新增 4 个 Scene 层文件：`TableModelLoader`, `AngleTrainingScene`, `CameraRig`, `AngleSceneView`
  - 最低 iOS 17.0 已满足（SceneKit 自 iOS 8 起可用）
- **替代方案**：纯 SwiftUI Canvas 2D 渲染（已用于现有 AngleTestView），但无法提供 3D 视角
