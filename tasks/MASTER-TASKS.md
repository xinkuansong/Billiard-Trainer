# 功能清单与任务总索引（MASTER TASKS）

> **权威来源**：`docs/04-功能规划.md`（F1–F11）、`docs/07-路线图与MVP.md`（Phase 定义）
> **任务详情**：见 `tasks/phases/Pn-*.md`、`tasks/phases/R0-design-system.md`、`tasks/phases/R-UI-alignment.md`
> **当前进度**：见 `tasks/PROGRESS.md`

---

## 功能模块索引（F1–F11）

| ID | 功能 | 优先级 | 所在 Phase | 状态 |
|----|------|--------|-----------|------|
| F1 | 动作库：浏览与查看 Drill | P0 | P3 | ✅ |
| F2 | 动作库：Drill 收藏 | P1 | P3 | ✅ |
| F3 | 训练计划：选择与使用官方计划 | P0 | P4 | 🔄 |
| F4 | 训练计划：自定义计划 | P1 | P4 | ⏳ 待开始 |
| F5 | 训练记录：开始并完成一次训练 | P0 | P4 | 🔄 |
| F6 | 历史：日历视图与训练详情 | P0 | P6 | ⏳ 待开始 |
| F7 | 统计：训练数据分析 | P1 | P6 | ⏳ 待开始 |
| F8 | 账号：登录与数据同步 | P0 | P1 + P2 | 🔄 |
| F9 | 个人设置：球种偏好与训练目标 | P1 | P1 | ⏳ 待开始 |
| F10 | 角度感知：角度测试 | P0 | P5 | ⏳ 待开始 |
| F11 | 角度感知：进球点对照表 | P0 | P5 | ⏳ 待开始 |

---

## Phase 任务总览

### P1 — Foundation（项目骨架）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P1-01 | Xcode 项目初始化（Bundle ID、Target、xcconfig） | DevOps | H-01, H-02 | ✅ |
| T-P1-02 | SPM 依赖初始配置（无第三方 SPM 依赖，URLSession + 系统库） | Architect | — | ✅ |
| T-P1-03 | 设计系统 DesignSystem（颜色/字体/间距 Token） | SwiftUI Dev | — | ✅ |
| T-P1-04 | 5 Tab 导航骨架（AppRouter + ContentView） | SwiftUI Dev | — | ✅ |
| T-P1-05 | 登录流程 UI（三种登录选项 + 引导页） | SwiftUI Dev | — | ✅ |
| T-P1-06 | Sign in with Apple 功能实现 | Data Eng | H-08 | ✅ |
| T-P1-07 | REST API 初始化 + 手机验证码登录 | Data Eng | H-14, H-15 | ⏳ |
| T-P1-08 | 微信登录集成 | Data Eng | H-05, H-13 | ⏳ |
| T-P1-09 | AppConfig（xcconfig 注入密钥） + .gitignore | DevOps | — | ✅ |
| **QA-P1** | **P1 验收** | QA | — | ⏳ |

### P2 — Data Layer（数据层）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P2-01 | SwiftData Schema（所有实体 + ModelContainer） | Data Eng | — | ✅ |
| T-P2-02 | LocalRepository 实现（TrainingSession CRUD） | Data Eng | — | ✅ |
| T-P2-03 | ~~CloudKit 公开库~~ Drill 内容 OTA（并入自建 API；ADR-002 取消独立任务） | Data Eng | — | ✅ 已取消 |
| T-P2-04 | Bundle fallback JSON 结构（drills_index.json） | Content Eng | — | ✅ |
| T-P2-05 | 后端用户数据同步（REST API 上传/增量拉取） | Data Eng | H-14, H-16 | ✅ |
| T-P2-06 | 匿名用户本地模式 + 登录后迁移 | Data Eng | — | ✅ |
| T-P2-07 | SyncQueue（后台同步队列） | Data Eng | — | ✅ |
| **QA-P2** | **P2 验收** | QA | — | 🔄 |

### P3 — Drill Library（动作库）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P3-01 | Drill JSON Schema 定稿 + index.json 结构 | Content Eng | — | ✅ |
| T-P3-02 | Drill 内容生产 Batch 1（fundamentals + accuracy，10条） | Content Eng | — | ✅ |
| T-P3-03 | Drill 内容生产 Batch 2（cueAction + separation，10条） | Content Eng | H-11 验证 Batch1 | ✅ |
| T-P3-04 | Drill 内容生产 Batch 3（positioning + forceControl，10条） | Content Eng | H-11 验证 Batch2 | ✅ |
| T-P3-05 | Drill 内容生产 Batch 4–7（remaining，每批10条） | Content Eng | H-11 轮次验证 | ✅ |
| T-P3-06 | DrillLibrary Tab — 分类列表 UI（BTDrillCard） | SwiftUI Dev | — | ✅ |
| T-P3-07 | Drill 详情页（Canvas 动画 + 图文） | SwiftUI Dev | — | ✅ |
| T-P3-08 | BTBilliardTable Canvas 组件（路径动画） | SwiftUI Dev | — | ✅ |
| T-P3-09 | 球种筛选 + 搜索功能（F1） | SwiftUI Dev | — | ✅ |
| T-P3-10 | Drill 收藏功能（F2） | Data Eng + SwiftUI Dev | — | ✅ |
| T-P3-11 | Freemium 锁定（BTPremiumLock 遮罩） | SwiftUI Dev | — | ✅ |
| **QA-P3** | **P3 验收** | QA | H-11 | 🔄 |

### R0 — Design System Upgrade（设计系统升级）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-R0-01 | 创建 UI-IMPLEMENTATION-SPEC.md | Architect | — | ✅ |
| T-R0-02 | Token 值审计 | SwiftUI Dev | — | ⏳ |
| T-R0-03 | BTButton 补全 7 种样式 | SwiftUI Dev | — | ⏳ |
| T-R0-04 | 新建组件 Batch 1（导航/布局） | SwiftUI Dev | — | ⏳ |
| T-R0-05 | 新建组件 Batch 2（训练） | SwiftUI Dev | — | ⏳ |
| T-R0-06 | 新建组件 Batch 3（反馈/分享） | SwiftUI Dev | — | ⏳ |
| T-R0-07 | 校验与更新已有组件 | SwiftUI Dev | — | ⏳ |
| **QA-R0** | **R0 验收** | QA | — | ⏳ |

### P4 — Training Log（训练记录）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P4-01 | 官方训练计划 JSON 生产（6套） | Content Eng | — | ✅ |
| T-P4-02 | 训练 Tab — 今日计划视图 + 空状态（F3） | SwiftUI Dev | — | ✅ |
| T-P4-03 | 官方计划列表与详情页（F3） | SwiftUI Dev | — | ✅ |
| T-P4-04 | 开始训练流程（按计划/自由记录，F5） | SwiftUI Dev | — | ✅ |
| T-P4-05 | 训练中 Drill 记录界面（数字键盘输入进球数，F5） | SwiftUI Dev | — | ⏳ |
| T-P4-06 | 心得备注输入（F5） | SwiftUI Dev | — | ⏳ |
| T-P4-07 | 训练完成总结页（时长/项目数/成功率，F5） | SwiftUI Dev | — | ⏳ |
| T-P4-08 | TrainingSession 持久化（SwiftData + 同步，F5） | Data Eng | — | ⏳ |
| T-P4-09 | 自定义训练计划（F4） | SwiftUI Dev + Data Eng | — | ⏳ |
| T-P4-10 | TrainingShareView | SwiftUI Dev | — | ⏳ |
| **QA-P4** | **P4 验收** | QA | — | ⏳ |

### P5 — Angle Training（角度感知）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P5-01 | 角度计算引擎（sin 公式 + 自适应权重算法） | Architect | — | ⏳ |
| T-P5-02 | 角度测试出题 UI（球台随机题目，F10） | SwiftUI Dev | — | ⏳ |
| T-P5-03 | 答案动画（路径高亮 + 接触点标注，F10） | SwiftUI Dev | — | ⏳ |
| T-P5-04 | 角度测试历史记录（误差趋势，F10） | Data Eng + SwiftUI Dev | — | ⏳ |
| T-P5-05 | 进球点对照表（交互滑块 + 完整表格，F11） | SwiftUI Dev | — | ⏳ |
| T-P5-06 | Freemium 每日次数限制（20次/天） | Data Eng | — | ⏳ |
| **QA-P5** | **P5 验收** | QA | — | ⏳ |

### P6 — History（历史与统计）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P6-01 | 历史 Tab — 日历视图（有记录日期高亮，F6） | SwiftUI Dev | — | ⏳ |
| T-P6-02 | 训练详情页（Drill 列表 + 各组成绩 + 心得，F6） | SwiftUI Dev | — | ⏳ |
| T-P6-03 | 统计视图（周/月/年切换，F7） | SwiftUI Dev | — | ⏳ |
| T-P6-04 | 训练频率折线图（Swift Charts，F7） | SwiftUI Dev | — | ⏳ |
| T-P6-05 | 各类别成功率雷达图（F7） | SwiftUI Dev | — | ⏳ |
| T-P6-06 | Freemium 历史查看限制（免费 60 天，F6） | Data Eng | — | ⏳ |
| **QA-P6** | **P6 验收** | QA | — | ⏳ |

### P7 — Subscription（订阅与 IAP）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P7-01 | StoreKit 2 集成（Product 加载 + 购买流程） | Data Eng | H-03, H-04 | ⏳ |
| T-P7-02 | 订阅状态管理（SubscriptionManager） | Data Eng | H-04 | ⏳ |
| T-P7-03 | 订阅页 UI（月/年/终身，BTPremiumLock 引导） | SwiftUI Dev | — | ⏳ |
| T-P7-04 | 恢复购买功能 | Data Eng | — | ⏳ |
| T-P7-05 | Freemium 边界逻辑集成（全功能内容门禁） | Data Eng | — | ⏳ |
| **QA-P7** | **P7 验收** | QA | — | ⏳ |

### R-UI — Existing Page Alignment（已有页面对齐）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-RUI-01 | TrainingHomeView 对齐 | SwiftUI Dev | — | ⏳ |
| T-RUI-02 | DrillListView + DrillDetailView 对齐 | SwiftUI Dev | — | ⏳ |
| T-RUI-03 | ActiveTrainingView 对齐 | SwiftUI Dev | — | ⏳ |
| T-RUI-04 | ProfileView + LoginView 对齐 | SwiftUI Dev | — | ⏳ |
| T-RUI-05 | OnboardingView 对齐 | SwiftUI Dev | — | ⏳ |
| **QA-RUI** | **R-UI 验收** | QA | — | ⏳ |

### P8 — Polish & Release（打磨与发布）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P8-01 | Privacy Manifest（PrivacyInfo.xcprivacy） | DevOps | — | ⏳ |
| T-P8-02 | 性能优化（启动时间、列表流畅度） | Architect | — | ⏳ |
| T-P8-03 | 空状态与加载态全覆盖检查 | SwiftUI Dev | — | ⏳ |
| T-P8-04 | 首次引导流程（Onboarding） | SwiftUI Dev | — | ⏳ |
| T-P8-05 | 个人设置页（球种偏好/训练目标/通知，F9） | SwiftUI Dev | — | ⏳ |
| T-P8-06 | 账号注销与数据删除（PIPL 要求） | Data Eng | — | ⏳ |
| T-P8-07 | XCTest 核心流程测试（训练记录、角度计算） | QA | — | ⏳ |
| T-P8-08 | TestFlight 内部测试发布 | DevOps | H-02 | ⏳ |
| T-P8-09 | App Store 资产准备（截图 + 元数据） | DevOps | H-09, H-10 | ⏳ |
| T-P8-10 | App Store 提交审核 | DevOps | H-12 | ⏳ |
| T-P8-11 | Dark Mode 全面通刷 | SwiftUI Dev | — | ⏳ |
| T-P8-12 | 人工测试计划更新与执行 | Test Eng + QA | — | ⏳ |
| **QA-P8** | **P8 最终验收** | QA | — | ⏳ |

### P9 — Aiming Feature Expansion（瞄准功能全面升级）

| 任务 ID | 任务名 | 角色 | 人工前置 | 状态 |
|---------|--------|------|---------|------|
| T-P9-00 | UI 设计交付文档更新（09-UI设计交付文档.md § 3.3） | Content Eng | — | ⏳ |
| T-P9-D-01 | AngleHomeView 重设计 | SwiftUI Dev | — | ⏳ |
| T-P9-D-02 | AimingPrincipleView 设计 | SwiftUI Dev | — | ⏳ |
| T-P9-D-03 | AngleDynamicView 设计 | SwiftUI Dev | — | ⏳ |
| T-P9-D-04 | GeometricAngleQuizView 设计 | SwiftUI Dev | — | ⏳ |
| T-P9-D-05 | SceneAnglePredictionView 设计（6 帧，2D/3D） | SwiftUI Dev | — | ⏳ |
| T-P9-D-06 | ContactPointTableView 增强设计 | SwiftUI Dev | — | ⏳ |
| T-P9-D-07 | BallFeelView 设计 | SwiftUI Dev | — | ⏳ |
| T-P9-D-REVIEW | 设计一致性审查 | QA | — | ⏳ |
| T-P9-01 | SceneKit 场景基础设施（TableModelLoader + Scene + CameraRig） | Architect | — | ⏳ |
| T-P9-02 | 数据层扩展（quizType 字段 + AngleSceneCalculator） | Data Eng | — | ⏳ |
| T-P9-03 | AngleHomeView 导航重构（7 功能分组 + 路由注册） | SwiftUI Dev | — | ⏳ |
| T-P9-04 | 瞄准原理页 AimingPrincipleView | SwiftUI Dev + Content Eng | — | ⏳ |
| T-P9-05 | 角度与打点动态关系页 AngleDynamicView | SwiftUI Dev | — | ⏳ |
| T-P9-06 | 纯几何角度预测训练 GeometricAngleQuizView | SwiftUI Dev | — | ⏳ |
| T-P9-07 | SceneKit 角度预测页 SceneAnglePredictionView（2D/3D 统一） | SwiftUI Dev + Architect | — | ⏳ |
| T-P9-08 | SceneKit 角度预测增强（幽灵球/瞄准线/训练类型/自由练习） | SwiftUI Dev | — | ⏳ |
| T-P9-09 | 进球点对照表增强（19 行 + d/R + 球种切换 + 正弦曲线） | SwiftUI Dev + Content Eng | — | ⏳ |
| T-P9-10 | 浅淡球感页 BallFeelView | Content Eng + SwiftUI Dev | — | ⏳ |
| T-P9-11 | AngleHistoryView 增强（quizType 筛选） | SwiftUI Dev + Data Eng | — | ⏳ |
| **QA-P9** | **P9 验收** | QA | — | ⏳ |

---

## 状态说明

- ⏳ 待开始
- 🔄 进行中
- ✅ 已完成（DoD 全部满足）
- 🚫 阻塞（详见 `tasks/PROGRESS.md`）
