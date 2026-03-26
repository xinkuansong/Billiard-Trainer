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

- [ ] 文件已添加到 Xcode Target（Build Phases → Copy Bundle Resources）
- [ ] `NSPrivacyTrackingDomains`：空（不做跨 App 追踪）
- [ ] `NSPrivacyTracking`：`false`
- [ ] `NSPrivacyAccessedAPITypes`：仅包含实际使用的 API（如 `NSPrivacyAccessedAPICategoryFileTimestamp` 若使用文件访问时间）
- [ ] `NSPrivacyCollectedDataTypes`：按实际收集声明（见 `tasks/compliance-checklist.md`）
- [ ] Xcode 「Privacy Report」无未声明 API 警告

---

## T-P8-02 性能优化

- **负责角色**：iOS Architect
- **前置依赖**：全功能实现完成
- **产出物**：性能测试记录（写入本文件 ADR 区）

### DoD

- [ ] 冷启动时间 < 2 秒（Instruments Time Profiler 验证，iPhone 12 及以上）
- [ ] 动作库列表滚动帧率 ≥ 55 fps（无明显卡顿）
- [ ] Canvas 球台动画不阻塞主线程（非动画期间无 CPU 峰值）
- [ ] 内存占用在主流使用场景下 < 100 MB

---

## T-P8-03 空状态与加载态全覆盖

- **负责角色**：SwiftUI Developer
- **前置依赖**：所有 Tab 功能完成
- **产出物**：各 View 的空状态 + 加载态检查

### DoD

以下所有场景均展示合适的占位视图（不显示空白屏幕）：
- [ ] 动作库：内容加载中（Shimmer 或 ProgressView）
- [ ] 动作库：搜索无结果
- [ ] 训练 Tab：无激活计划
- [ ] 历史 Tab：无训练记录（首次使用）
- [ ] 统计：无数据
- [ ] 收藏夹：无收藏

---

## T-P8-04 首次引导流程（Onboarding 完整版）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-05 基础版已有
- **产出物**：`Features/Profile/Views/OnboardingView.swift` 完整版

### DoD

- [ ] 3 页引导：① 产品核心价值（动作库 + 训练记录）② 角度感知独特功能 ③ 登录/跳过
- [ ] 引导页仅首次安装展示（`UserDefaults.hasCompletedOnboarding` 标记）
- [ ] 「跳过」直接进入主界面（匿名模式）
- [ ] 页面指示器（3 个点）

---

## T-P8-05 个人设置页（F9）

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-05, T-P7-02
- **产出物**：`Features/Profile/Views/ProfileView.swift`、`SettingsView.swift`

### DoD

- [ ] 「我的」Tab：用户头像/昵称（匿名时显示「游客」）、订阅状态
- [ ] 设置项：主打球种（中式台球/9球/两者）、每周训练目标天数
- [ ] 「订阅管理」入口（已订阅时展示到期日）
- [ ] 「账号注销」入口（有二次确认）
- [ ] 「隐私政策」链接（跳转 H-09 创建的页面）

---

## T-P8-06 账号注销与数据删除（PIPL 要求）

- **负责角色**：Data Engineer
- **前置依赖**：T-P2-05
- **产出物**：`AuthService.deleteAccount()`

### DoD

- [ ] 注销弹窗有明确警告：「将永久删除你的账号和云端数据，本地数据保留」
- [ ] 操作完成：LeanCloud 用户对象及关联数据删除，本地退出登录状态
- [ ] 操作失败（网络问题）有重试提示，不静默失败

---

## T-P8-07 XCTest 核心流程测试

- **负责角色**：QA Reviewer
- **前置依赖**：P7 全部完成
- **产出物**：`QiuJiTests/` 测试文件

### DoD

- [ ] `AngleCalculatorTests`：sin 公式精度、自适应权重分布
- [ ] `TrainingSessionRepositoryTests`：创建 → 读取 → 更新 → 删除（内存 Container）
- [ ] `FreemiumBoundaryTests`：isPremium=false 时锁定逻辑正确
- [ ] 所有测试通过（`make test` 零失败）

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
