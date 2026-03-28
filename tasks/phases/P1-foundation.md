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

- [x] 零第三方 SPM 依赖（LeanCloud 已于 ADR-001 移除）
- [x] 编译通过，无报错
- [x] `tasks/dependencies.md` 已记录：当前无第三方依赖

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
- **前置依赖**：T-P1-05, T-P1-07（REST API 初始化须先完成）
- **产出物**：`Data/Services/AuthService.swift`（Apple 登录部分）

### DoD

- [x] `AuthService.loginWithApple()` 可调用，无编译错误
- [x] 登录成功后更新 `AuthState`（用户信息存入 UserDefaults/Keychain）
- [x] 登录失败时 `AppError.authFailed` 正确抛出并在 UI 显示中文提示
- [x] Token 不明文存储（使用 Keychain）

---

## T-P1-07 REST API 初始化 + 手机验证码登录

- **负责角色**：Data Engineer
- **人工前置**：H-14 ✅（服务器已部署）、H-15 ✅（腾讯云短信已申请）
- **前置依赖**：T-P1-01
- **产出物**：`Data/Services/APIClient.swift`、`Data/Services/AuthService.swift`（SMS 部分）、`Core/Extensions/AppConfig.swift` 更新

### DoD

- [ ] `APIClient` 使用 `URLSession` + `async/await` 实现，`baseURL` 通过 `xcconfig` 注入
- [ ] `KeychainService` 负责 Access Token / Refresh Token 的安全存储与读取
- [ ] `AppConfig.apiBaseURL` 从 `Bundle.main.infoDictionary` 读取，不硬编码
- [ ] `AuthService.sendSMSCode(phone:)` 调用 `POST /auth/send-sms`，不崩溃
- [ ] `AuthService.loginWithSMS(phone:code:)` 登录成功后 JWT 存入 Keychain，`AuthState.currentUser` 更新
- [ ] 错误场景（验证码错误、网络失败）抛出 `AppError` 并在 UI 显示中文提示

---

## T-P1-08 微信登录集成

- **负责角色**：Data Engineer
- **人工前置**：H-05 ✅（微信 AppID 已获取）、H-13 ✅（Universal Links 或 URL Scheme 已配置）
- **前置依赖**：T-P1-07
- **产出物**：`Data/Services/AuthService.swift`（微信部分）、`Info.plist` 更新

### DoD

- [ ] 微信 SDK 已集成（见 `tasks/dependencies.md` 集成方式）
- [ ] `Info.plist` 包含：`LSApplicationQueriesSchemes`（weixin、weixinULAPI）、`CFBundleURLSchemes`（wx${WECHAT_APP_ID}）
- [ ] `AppDelegate` 中 `onResp` 正确接收微信授权 code
- [ ] `AuthService.loginWithWechat(code:)` 调用 `POST /auth/login-wechat { code }`（AppSecret 在服务端，不在客户端）
- [ ] 登录成功后 JWT 存入 Keychain，`AuthState.currentUser` 更新
- [ ] 点击「微信登录」能唤起微信 App（真机测试；模拟器可 mock）

---

## T-P1-09 AppConfig + .gitignore 完善

- **负责角色**：DevOps/Release
- **前置依赖**：T-P1-01
- **产出物**：`Config/AppConfig.swift`、`.gitignore`

### DoD

- [ ] `AppConfig` 通过 `Bundle.main.infoDictionary` 读取所有敏感配置（API Base URL、微信 AppID 等）
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

### ADR-001：用户认证与数据同步后端选型变更

- **日期**：2026-03-29
- **状态**：已决策
- **决策者**：产品负责人

#### 背景

原架构（v0.3）选用 LeanCloud 作为用户认证（微信/短信/Apple）和私有数据同步的托管服务。
P1 开发期间确认：**LeanCloud 已停止国内新用户注册**（H-06 阻塞无法解除）。

同时，产品路线图包含 **Android 版本**，要求后端方案跨平台可用。

#### 评估的方案

| 方案 | 描述 | 排除原因 |
|------|------|---------|
| A：CloudKit 私有库 | 用 CloudKit 替代 LeanCloud | Android 不支持 CloudKit |
| B²：TDS | LeanCloud 继任服务 | 面向游戏，长期不确定性高 |
| E：先 CloudKit 后迁移 | iOS 先用 CloudKit，Android 时重建 | 用户数据迁移成本高，体验差 |
| **D：极简自建后端** | 腾讯云轻量服务器 Node.js + MongoDB | **选定** |

#### 决策

采用 **方案 D：极简自建 REST API 后端**。

**技术栈**：
- **服务器**：腾讯云轻量应用服务器（约 ¥50/月）
- **运行时**：Node.js（Express）
- **数据库**：腾讯云 TencentDB for MongoDB（或 MongoDB Atlas 中国节点）
- **短信**：腾讯云短信服务（国内通道）
- **认证**：JWT（Access Token 1h + Refresh Token 30d）
- **微信 OAuth**：AppSecret 存服务器，App 只传 code，服务器完成换取

**API 端点规划（~20 个）**：

```
POST /auth/send-sms        发送验证码
POST /auth/login-sms       手机验证码登录/注册
POST /auth/login-wechat    微信 code 换取 token
POST /auth/login-apple     Apple identity token 验证
POST /auth/refresh         刷新 JWT
DELETE /auth/logout

GET    /user/profile        获取用户信息
PUT    /user/profile        更新用户信息
DELETE /user/account        注销账号

GET    /training-sessions          列表（支持分页/日期筛选）
POST   /training-sessions          创建
PUT    /training-sessions/:id      更新
DELETE /training-sessions/:id      删除
POST   /training-sessions/batch    批量上传（匿名转登录时迁移）

GET    /angle-tests                列表
POST   /angle-tests                创建
```

**iOS 客户端影响**：
- 移除 LeanCloud Swift SDK（减少 ~5MB 包体积）
- 使用 `URLSession` + `async/await` 构建 `APIClient`（无需额外依赖）
- `AppConfig` 新增 `apiBaseURL` 字段
- `AuthService` 改为调用自建 API，逻辑基本不变

**Android 影响**：
- 直接复用同一套 REST API，无需适配

#### 后果

- ✅ iOS 和 Android 共用一套后端，长期架构清晰
- ✅ 完全掌控认证逻辑和数据，无第三方服务不确定性
- ✅ 腾讯云短信通道稳定，微信 OAuth 安全
- ⚠️ 需要维护后端代码（成本：约每季度 1 次升级维护）
- ⚠️ 新增人工项：服务器购买、部署、SMS 申请（见 HUMAN-REQUIRED H-14 ~ H-16）
