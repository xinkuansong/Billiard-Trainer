# P1 — Foundation（项目骨架）

> **目标**：可编译运行的 iOS 17 项目，包含 5 Tab 导航骨架、Design System Token、三种登录流程。
> **人工前置**：H-01（Apple Developer 账号）、H-02 ✅、H-08（Sign in with Apple 能力）
> **建议时长**：3–5 天

---

## T-P1-01 Xcode 项目初始化

- **负责角色**：DevOps/Release
- **人工前置**：H-01 ✅, H-02 ✅
- **产出物**：`QiuJi.xcodeproj`（或 `.xcworkspace`）

### DoD

- [ ] Bundle ID 格式：`com.<yourname>.billiardtrainer`，与 Apple Developer Portal App ID 一致
- [ ] Deployment Target：iOS 17.0
- [ ] 包含 `Config/` 目录，`Debug.xcconfig` 和 `Release.xcconfig` 已创建
- [ ] `.gitignore` 包含：`*.p12`、`*.mobileprovision`、`Config/Secrets.xcconfig`、`build/`、`.DS_Store`
- [ ] `scripts/Makefile` 中 `make build` 可成功编译（Debug）
- [ ] Swift Package Manager 已初始化（Package 索引可用）

---

## T-P1-02 SPM 依赖初始配置

- **负责角色**：iOS Architect
- **前置依赖**：T-P1-01
- **产出物**：`Package.swift` 或 Xcode SPM 依赖列表更新

### DoD

- [ ] LeanCloud Swift SDK 已通过 SPM 添加（`https://github.com/leancloud/swift-sdk`）
- [ ] 编译通过，无报错
- [ ] `tasks/dependencies.md` 中 LeanCloud SDK 版本已记录

---

## T-P1-03 Design System Token

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-01
- **产出物**：`QiuJi/Core/DesignSystem/Colors.swift`、`Typography.swift`、`Spacing.swift`

### DoD

- [ ] `Color` extension 包含全部 Token（见 `swiftui-design-system` Skill）：主色、辅色、背景、文字、球台色系
- [ ] 所有颜色在 `Assets.xcassets` 中定义 Light + Dark 变体（不硬编码 hex）
- [ ] `Font` extension 包含全部 Token：btLargeTitle / btTitle / btBody / btCallout / btFootnote / btCaption
- [ ] `BTSpacing` enum 包含 xs/sm/md/lg/xl/xxl/xxxl
- [ ] `#Preview` 可预览所有颜色 Token，Light + Dark 均无白色硬编码块

---

## T-P1-04 5 Tab 导航骨架

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-03
- **产出物**：`App/QiuJiApp.swift`、`App/ContentView.swift`、`App/AppRouter.swift`

### DoD

- [ ] 5 个 Tab 按顺序：训练 / 动作库 / 角度 / 历史 / 我的，Tab 图标使用 SF Symbols
- [ ] 每个 Tab 有占位 View（可显示 Tab 名称，非空白）
- [ ] `NavigationStack` 已在各 Tab 内包裹
- [ ] `AppRouter` 支持跨 Tab 跳转（至少定义接口，实现可后续完善）
- [ ] Dark Mode 下 Tab Bar 样式正常（无白色色块）
- [ ] `#Preview` 可运行

---

## T-P1-05 登录流程 UI

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P1-04
- **产出物**：`Features/Profile/Views/LoginView.swift`、`OnboardingView.swift`

### DoD

- [ ] 首次启动引导页（Onboarding）：展示产品核心价值，有「开始使用」和「已有账号，登录」入口
- [ ] 登录选项页包含：微信登录（首位）、手机号登录、Sign in with Apple
- [ ] 手机号登录页：输入框 + 发送验证码按钮 + 验证码输入 + 确认按钮
- [ ] 未登录时可「跳过」进入主界面（匿名模式）
- [ ] 所有 UI 使用 Design Token，Dark Mode 正常
- [ ] `#Preview` 覆盖 Light + Dark

---

## T-P1-06 Sign in with Apple 功能实现

- **负责角色**：Data Engineer
- **人工前置**：H-08 ✅
- **前置依赖**：T-P1-05, T-P1-07（LeanCloud 初始化须先完成）
- **产出物**：`Data/Services/AuthService.swift`（Apple 登录部分）

### DoD

- [ ] `AuthService.loginWithApple()` 可调用，无编译错误
- [ ] 登录成功后更新 `AuthState`（用户信息存入 UserDefaults/Keychain）
- [ ] 登录失败时 `AppError.authFailed` 正确抛出并在 UI 显示中文提示
- [ ] Token 不明文存储（使用 Keychain）

---

## T-P1-07 LeanCloud 初始化 + 手机验证码登录

- **负责角色**：Data Engineer
- **人工前置**：H-06 ✅（LeanCloud API Key 已获取）
- **前置依赖**：T-P1-02
- **产出物**：`App/QiuJiApp.swift`（初始化）、`AuthService.swift`（SMS 部分）

### DoD

- [ ] `LCApplication.default.set(id:key:serverURL:)` 在 App 启动时正确调用
- [ ] App ID / App Key 通过 `xcconfig` 注入，不硬编码在源码中
- [ ] `sendSMSCode(phone:)` 可调用（真机/模拟器均不崩溃）
- [ ] `loginWithSMS(phone:code:)` 登录成功后 `LCUser.current` 不为 nil
- [ ] 错误场景（验证码错误、网络失败）有中文提示

---

## T-P1-08 微信登录集成

- **负责角色**：Data Engineer
- **人工前置**：H-05 ✅（微信 AppID 已获取）、H-13 ✅（Universal Links 或 URL Scheme 已配置）
- **前置依赖**：T-P1-07
- **产出物**：`Data/Services/AuthService.swift`（微信部分）、`Info.plist` 更新

### DoD

- [ ] 微信 SDK 已集成（见 `tasks/dependencies.md` 集成方式）
- [ ] `Info.plist` 包含：`LSApplicationQueriesSchemes`（weixin、weixinULAPI）、`CFBundleURLSchemes`（wx${WECHAT_APP_ID}）
- [ ] `AppDelegate` 或 `SceneDelegate` 中 `onResp` 正确处理微信回调
- [ ] 点击「微信登录」能唤起微信 App（真机测试；模拟器可 mock）
- [ ] 登录成功后 `LCUser.current` 不为 nil

---

## T-P1-09 AppConfig + .gitignore 完善

- **负责角色**：DevOps/Release
- **前置依赖**：T-P1-01
- **产出物**：`Config/AppConfig.swift`、`.gitignore`

### DoD

- [ ] `AppConfig` 通过 `Bundle.main.infoDictionary` 读取所有敏感配置（LeanCloud Key、微信 AppID 等）
- [ ] `Config/Secrets.xcconfig`（包含真实 key）已加入 `.gitignore`，不会被提交
- [ ] `Config/Debug.xcconfig` 中有带注释的占位符示例，方便新开发者配置
- [ ] `make build` 使用占位值可以编译通过（代码层无硬编码依赖）

---

## QA-P1 P1 验收

- **负责角色**：QA Reviewer
- **前置依赖**：T-P1-01 至 T-P1-09 全部完成

### 验收要点

- [ ] `make build` 零报错、零警告（允许 Xcode 新 API deprecation warning）
- [ ] 模拟器可运行：5 Tab 正常显示，无崩溃
- [ ] Dark Mode 切换：无白色硬编码色块
- [ ] 登录页各入口可点击（功能可以 stub，但 UI 不崩溃）
- [ ] `.gitignore` 已覆盖所有敏感文件
- [ ] `tasks/PROGRESS.md` 已更新 P1 完成状态

---

## ADR 记录区

> 本 Phase 产生的架构决策记录在此追加。
