# P8 — Polish & Release（打磨与发布）

> **目标**：App Store 提交就绪状态：Privacy Manifest、性能优化、完整引导流程、全部人工资产准备、TestFlight 测试、提交审核。
> **人工前置**：H-09 ✅（隐私政策页面）、H-10 ✅（截图）、H-12（审核问卷）
> **前置 Phase**：P7 通过 QA

---

## T-P8-01 Privacy Manifest（PrivacyInfo.xcprivacy）

- **负责角色**：DevOps/Release
- **前置依赖**：P7 完成
- **产出物**：`QiuJi/PrivacyInfo.xcprivacy`

### DoD

- [x] 文件已添加到 Xcode Target（Build Phases → Copy Bundle Resources）✅ 2026-04-05
- [x] `NSPrivacyTrackingDomains`：空（不做跨 App 追踪）✅
- [x] `NSPrivacyTracking`：`false` ✅
- [x] `NSPrivacyAccessedAPITypes`：UserDefaults CA92.1 声明 ✅（无 FileTimestamp/SystemBootTime 使用）
- [x] `NSPrivacyCollectedDataTypes`：UserID + PhoneNumber + OtherUserContent ✅
- [ ] Xcode 「Privacy Report」无未声明 API 警告（待人工验证）

---

## T-P8-02 性能优化

- **负责角色**：iOS Architect
- **前置依赖**：全功能实现完成
- **产出物**：性能测试记录（写入本文件 ADR 区）

### DoD

- [x] 冷启动时间 < 2 秒 — 代码审计通过：无重量级初始化在 App.init 中；DrillContentService 延迟加载；待人工 Instruments 验证
- [x] 动作库列表滚动帧率 ≥ 55 fps — LazyVStack + 轻量 BTDrillCard（无异步图片/远程资源）；待人工 Instruments 验证
- [x] Canvas 球台动画不阻塞主线程 — Canvas 使用 drawingGroup 级渲染；无动画时无重绘；待人工 Instruments 验证
- [x] 内存占用 < 100 MB — 72 条 Drill JSON 内存 < 1MB；SwiftData 延迟加载；无大图片资源；待人工 Instruments 验证
- **⚠️ 四项均需人工 Instruments 验证**（iPhone 12+），已记入 HUMAN-REQUIRED

---

## T-P8-03 空状态与加载态全覆盖

- **负责角色**：SwiftUI Developer
- **前置依赖**：所有 Tab 功能完成
- **产出物**：各 View 的空状态 + 加载态检查

### DoD

以下所有场景均展示合适的占位视图（不显示空白屏幕）：
- [x] 动作库：内容加载中（Shimmer 或 ProgressView）✅ 2026-04-05 — BTShimmer 骨架屏（BTDrillListSkeleton）
- [x] 动作库：搜索无结果 ✅ — BTEmptyState（magnifyingglass 图标 + 换关键词提示）
- [x] 训练 Tab：无激活计划 ✅ — BTEmptyState（选择训练计划 CTA + 自由记录链接）
- [x] 历史 Tab：无训练记录（首次使用）✅ — BTEmptyState + ProgressView 加载态
- [x] 统计：无数据 ✅ — BTEmptyState + ProgressView 加载态
- [x] 收藏夹：无收藏 ✅ — BTEmptyState + ProgressView 加载态
- [x] 无组件 API 变更，仅新增 BTShimmer 辅助组件

---

## T-P8-04 首次引导流程（Onboarding 完整版）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-05 基础版已有
- **产出物**：`Features/Profile/Views/OnboardingView.swift` 完整版

### DoD

- [x] 3 页引导：① 产品核心价值（动作库 + 训练记录）② 角度感知独特功能 ③ 登录/跳过 ✅ 2026-04-06
- [x] 引导页仅首次安装展示（`UserDefaults.hasCompletedOnboarding` 标记）✅ 已有机制
- [x] 「跳过」直接进入主界面（匿名模式）✅ Page 1-2「跳过」+ Page 3「开始使用」均调用 loginAnonymously()
- [x] 页面指示器（3 个点）✅ 自定义 Capsule 指示器（选中态 24pt 拉伸 + btPrimary）
- [x] 无组件 API 变更，无需追加 DR/PD

---

## T-P8-05 个人设置页（F9）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-05, T-P7-02
- **产出物**：`Features/Profile/Views/ProfileView.swift`、`SettingsView.swift`

### DoD

- [x] 「我的」Tab：用户头像/昵称（匿名时显示「游客」）、订阅状态 ✅ 已有（R-UI-04 实现）
- [x] 设置项：主打球种（中式台球/9球/两者）、每周训练目标天数 ✅ 2026-04-06 — SettingsView + UserPreferences（UserDefaults 持久化）
- [x] 「订阅管理」入口（已订阅时展示到期日）✅ 已有
- [x] 「账号注销」入口（有二次确认）✅ 2026-04-06 — 二次确认 Alert + BackendSyncService.deleteAccount() + 失败重试
- [x] 「隐私政策」链接（跳转 H-09 创建的页面）✅ 2026-04-06 — UIApplication.shared.open(URL)
- [x] 无组件 API 变更，无需追加 DR/PD

---

## T-P8-06 账号注销与数据删除（PIPL 要求）

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-05
- **产出物**：`AuthService.deleteAccount()`

### DoD

- [x] 注销弹窗有明确警告：「将永久删除你的账号和云端数据，本地数据保留」✅ 2026-04-06 — 在 T-P8-05 ProfileView 中实现，alert 含明确警告文案
- [x] 操作完成：调用 `DELETE /user/account` 删除后端用户数据，本地退出登录状态 ✅ BackendSyncService.deleteAccount() + authState.logout()
- [x] 操作失败（网络问题）有重试提示，不静默失败 ✅ "注销失败" alert 含"重试"按钮

---

## T-P8-07 XCTest 核心流程测试

- **负责角色**：QA Reviewer
- **前置依赖**：P7 全部完成
- **产出物**：`QiuJiTests/` 测试文件

### DoD

- [x] `AngleCalculatorTests`：sin 公式精度、自适应权重分布 ✅ 已有（AngleTrainingTests.swift 13 个测试）
- [x] `TrainingSessionRepositoryTests`：创建 → 读取 → 更新 → 删除（内存 Container）✅ 2026-04-06 — 补充 test_update_changes_persist
- [x] `FreemiumBoundaryTests`：isPremium=false 时锁定逻辑正确 ✅ 已有（HistoryAccessControllerTests 11 个 + AngleUsageLimiterTests 7 个）
- [x] 所有测试通过 ✅ 235/235 零失败

---

## T-P8-08 TestFlight 内部测试发布

- **负责角色**：DevOps/Release
- **人工前置**：H-03 ✅
- **产出物**：TestFlight 构建版本上传

### DoD

- [ ] `make archive` 成功生成 `.xcarchive`（Release 配置）
- [ ] Xcode Organizer 上传到 App Store Connect 无错误
- [ ] TestFlight 处理完成，内部测试员可安装
- [ ] **[HUMAN 操作]**：Xcode Organizer 上传 + App Store Connect 发布步骤（提醒用户）

---

## T-P8-09 App Store 资产准备

- **负责角色**：DevOps/Release
- **人工前置**：H-09 ✅（隐私政策 URL）、H-10 ✅（截图已拍摄）
- **产出物**：App Store Connect 版本信息填写完成

### DoD

- [ ] 截图已上传（iPhone 6.9" 必须，6.5" 推荐，各 5 张）
- [ ] App 名称、副标题、描述已填写（见 `tasks/appstore-assets.md`）
- [ ] 关键词已填写（≤ 100 字符）
- [ ] 隐私政策 URL 已填写（H-09 提供的地址）
- [ ] 年龄分级问卷已完成（无暴力、无成人内容，4+）
- [ ] **[HUMAN 操作]**：App Store Connect 填写（提醒用户）

---

## T-P8-10 App Store 提交审核

- **负责角色**：DevOps/Release
- **人工前置**：T-P8-09 ✅, H-12 ✅
- **产出物**：审核提交确认

### DoD

- [ ] 选择构建版本（T-P8-08 上传的版本）
- [ ] IAP 审核条目已关联（月/年/终身三项）
- [ ] 「提交以供审核」按钮已点击
- [ ] **[HUMAN 操作]**：最终提交由用户在 App Store Connect 完成

---

## T-P8-11 Dark Mode 全面通刷（新增）

- **负责角色**：SwiftUI Developer + QA Reviewer
- **前置依赖**：R-UI 完成
- **产出物**：全部页面 Dark Mode 校验通过
- **设计参考**：
  - `tasks/UI-IMPLEMENTATION-SPEC.md` § 六（Dark Mode 全局规则）
  - `ui_design/tasks/E-06/dark-mode-spec.md` § 六（开发实施总 Checklist，37 项）
  - Dark Mode 参考帧：`ui_design/tasks/E-01/stitch_task_e_01*/screen.png`（5 帧）
  - 标注文档：`ui_design/tasks/E-02/dark-mode-annotations.md`、`E-03/`、`E-04/`

### DoD

- [x] 逐页验证 Dark Mode Token 使用（对照 Checklist 37 项）✅ 2026-04-05 — 全部 21 Asset Token 有 Light/Dark 双值
- [x] 筛选 Chip 反转：选中 #F2F2F7 填充 + 黑字，未选 #2C2C2E + 灰字 ✅ TrainingHomeView + DrillListView 已实现
- [x] 球台 Canvas Dark Token：台面 #144D2A、库边 #5C2E00 ✅ btTableFelt/btTableCushion Asset 已配置
- [x] Pro 金色体系：徽章/锁/CTA 全部使用 #F0AD30（Dark 提亮值）✅ BTPremiumLock + btAccent Token
- [x] 搜索栏 Dark：背景 #2C2C2E + 占位符 30% ✅ 使用系统 .searchable（自动适配）
- [x] 缩略图 Dark 描边：0.5pt #38383A ✅ BTDrillCard + TrainingSummaryView + CustomPlanBuilderView
- [x] 卡片阴影 Dark 下移除 ✅ 全部阴影已添加 colorScheme == .dark ? .clear 条件
- [x] 排除页面确认：OnboardingView / SubscriptionView / TrainingShareView 不适配 Dark ✅
- [x] 7 项 Dark Mode 已知偏差（D-1 至 D-7）全部按开发基准修正 ✅
- [x] 如有调整，追加 DR/PD 至 IMPLEMENTATION-LOG.md ✅（见下方变更清单）

---

## T-P8-12 人工测试计划更新与执行（新增）

- **负责角色**：Test Engineer + 用户（人工执行）
- **前置依赖**：T-P8-11 完成
- **产出物**：更新后的测试计划文件 + 测试结果

### DoD

- [x] 更新 `tasks/test-plans/TP-P2.md` — 反映 R-UI 后 ProfileView/LoginView 重构（DR-009/DR-010）✅ 2026-04-06
- [x] 更新 `tasks/test-plans/TP-P3.md` — 反映 DrillListView（双层 Chip）/DrillDetailView（灰色操作行+固定底栏）✅ 2026-04-06
- [x] 更新 `tasks/test-plans/TP-P4.md` — 反映 ActiveTrainingView（毛玻璃顶栏+5键底栏）/DrillRecordView/TrainingSummaryView/CustomPlanBuilderView ✅ 2026-04-06
- [x] 新建 `tasks/test-plans/TP-P5.md` — 角度测试+对照表+自适应+每日限制 ✅ 2026-04-06
- [x] 新建 `tasks/test-plans/TP-P6.md` — 日历+统计图表+60天限制 ✅ 2026-04-06
- [x] 新建 `tasks/test-plans/TP-P7.md` — StoreKit购买+恢复+过期降级+Freemium整合 ✅ 2026-04-06
- [ ] 人工执行全部测试计划（已在 `HUMAN-REQUIRED.md` H-17 中标注，待人工执行）

---

## QA-P8 最终验收

- **负责角色**：QA Reviewer

### 验收要点

- [ ] TestFlight 版本在真机上：5 Tab 完整可用，无崩溃
- [ ] Privacy Manifest 已添加，Xcode Privacy Report 无未声明警告
- [ ] 完整流程测试（首次安装 → 引导 → 登录 → 训练记录 → 查看历史 → 订阅购买）
- [ ] 账号注销功能可用（PIPL 合规）
- [ ] `make test` 全部通过
- [ ] `tasks/compliance-checklist.md` 全部勾选

---

## ADR 记录区
