# 人工操作清单（HUMAN REQUIRED）

> Orchestrator 每次会话开始时读取本文件。
> **你完成操作后，将对应项的状态从 `⏳ 待完成` 改为 `✅ 已完成`。**

---

## [BLOCKING] H-01 — Apple Developer 账号激活

- **状态**：✅ 已完成
- **做什么**：登录 developer.apple.com，确认账号状态为 Active（有效期内）
- **在哪里**：[https://developer.apple.com/account](https://developer.apple.com/account)
- **预计时长**：5 分钟（已有账号）/ 最长 48 小时（新注册需等待审核）
- **影响任务**：T-P1-01（Xcode 项目初始化必须有有效开发者账号签名）
- **完成标志**：将本条状态改为 ✅

---

## [BLOCKING] H-02 — Xcode 安装 + iOS 17 Simulator

- **状态**：✅ 已完成
- **做什么**：确认 Xcode 已安装且包含 iOS 17 Simulator
- **验证方式**：`xcodebuild -version` 返回 Xcode 15+ 版本
- **影响任务**：P1 全部任务

---

## [BLOCKING] H-03 — App Store Connect 创建 App 记录

- **状态**：✅ 已完成
- **做什么**：
  1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
  2. 点击「我的 App」→「+」→「新建 App」
  3. 填写：名称（球迹）、Bundle ID（与 Xcode 一致）、SKU（自定义唯一字符串）
  4. 选择平台：iOS
- **在哪里**：[https://appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)
- **预计时长**：30 分钟
- **影响任务**：T-P7-01（StoreKit 2 需要 App 记录关联 IAP 产品）
- **前置条件**：H-01 完成

---

## [BLOCKING] H-04 — IAP 产品在 App Store Connect 创建

- **状态**：✅ 已完成
- **做什么**：在 App Store Connect → App → 内购买项目中创建以下 3 个产品：
  | 类型 | 产品 ID | 参考价格 |
  |------|---------|---------|
  | 自动续期订阅（月度） | `com.yourname.billiardtrainer.premium.monthly` | ¥18/月 |
  | 自动续期订阅（年度） | `com.yourname.billiardtrainer.premium.yearly` | ¥88/年 |
  | 非消耗型（终身） | `com.yourname.billiardtrainer.premium.lifetime` | ¥198 |
- **注意**：产品 ID 需与代码中 `StoreKit` 配置一致；定价需在 App Store Connect 价格表中选择
- **在哪里**：App Store Connect → 你的 App → 内购买项目
- **预计时长**：1 小时
- **影响任务**：T-P7-01（StoreKit 2 Product 加载依赖真实产品 ID）
- **前置条件**：H-03 完成

---

## [BLOCKING] H-05 — 微信开放平台申请移动应用资质

- **状态**：⏳ 待完成
- **做什么**：
  1. 注册/登录 [微信开放平台](https://open.weixin.qq.com)
  2. 创建移动应用（填写 App 名称、简介、图标）
  3. 提交审核（需要：App Store 链接或 TestFlight 链接/截图，目前可先提交 TestFlight 内测截图）
  4. 审核通过后获得 **AppID** 和 **AppSecret**
- **在哪里**：[https://open.weixin.qq.com](https://open.weixin.qq.com)
- **预计时长**：提交 15 分钟，等待 1–3 个工作日
- **影响任务**：T-P1-08（微信登录集成需要 AppID）
- **完成后**：将 AppID 填入 `Config/Debug.xcconfig` 的 `WECHAT_APP_ID` 字段

---

## [BLOCKING] H-06 — ~~LeanCloud 账号注册~~（已取消）

- **状态**：✅ 已取消（ADR-001，2026-03-29）
- **原因**：LeanCloud 停止国内新用户注册；已改用自建 REST API 后端（见 H-14 ~ H-16）

---

## [BLOCKING] H-07 — CloudKit 容器创建 + Schema 初始化

- **状态**：⏳ 待完成
- **做什么**：
  1. 登录 [Apple Developer Portal](https://developer.apple.com/account)
  2. Certificates, Identifiers & Profiles → Identifiers → 选择你的 App ID
  3. 确认 **iCloud** 能力已开启，勾选「CloudKit」
  4. 登录 [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
  5. 选择你的 CloudKit 容器
  6. 在「Schema」中创建 Record Type：
     - `DrillContent`：字段见 `docs/06-技术架构.md` § 4.2
     - `OfficialPlan`：字段同上
  7. 点击「Deploy to Production」（开发测试完成后）
- **在哪里**：
  - Developer Portal: [https://developer.apple.com/account](https://developer.apple.com/account)
  - CloudKit Dashboard: [https://icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard)
- **预计时长**：20 分钟
- **影响任务**：T-P2-03（CloudKit 内容拉取）

---

## [BLOCKING] H-08 — Sign in with Apple 能力开启

- **状态**：✅ 已完成
- **做什么**：
  1. Developer Portal → Identifiers → 你的 App ID
  2. 勾选「Sign In with Apple」→ Save
  3. 在 Xcode → Target → Signing & Capabilities → 添加「Sign In with Apple」
- **预计时长**：10 分钟
- **影响任务**：T-P1-06（Sign in with Apple 实现）
- **前置条件**：H-01 完成、T-P1-01 完成

---

## 非阻塞操作

以下操作不阻塞当前 Phase，但需在标注的节点前完成：

---

### H-09 — 隐私政策页面创建

- **状态**：⏳ 待完成（P8 前）
- **做什么**：创建一个可公开访问的隐私政策网页（必须包含中英双语，说明数据收集/使用/删除政策）
- **推荐方式**：GitHub Pages（免费）或任何静态托管
- **参考内容**：数据收集范围见 `tasks/compliance-checklist.md`
- **预计时长**：1 小时
- **影响任务**：T-P8-10（App Store 提交必须提供隐私政策 URL）

---

### H-10 — App Store 截图拍摄

- **状态**：⏳ 待完成（P8 前）
- **做什么**：在 iOS 模拟器（iPhone 16 Pro Max / 6.9"）上截取5张核心功能截图
- **截图内容**：见 `tasks/appstore-assets.md`
- **工具**：`xcrun simctl io booted screenshot screenshot.png`（可脚本化）或 `make screenshot`
- **预计时长**：2 小时（含文案设计）

---

### H-11 — Drill 内容技术验证

- **状态**：⏳ 待完成（P3 每批 Drill 完成后）
- **做什么**：由你（熟悉台球技术）核查每批 Drill 内容的技术准确性：
  - 动作描述是否正确（高杆/低杆/加塞定义）
  - 达标标准是否合理（进球数参照）
  - Canvas 示意图坐标是否合理
- **预计时长**：每批约 30–60 分钟
- **影响任务**：Content Engineer 等待验证通过后再生产下一批

---

### H-12 — App Store 审核问卷填写

- **状态**：⏳ 待完成（P8）
- **做什么**：App Store Connect 提交审核时填写：
  - 内容权利（IAP 订阅说明）
  - 年龄分级问卷
  - 隐私数据声明（按实际收集填写）
  - 中国区内容合规说明（如适用）
- **预计时长**：1 小时
- **前置条件**：H-09 完成（需要隐私政策 URL）

---

### H-13 — 微信 SDK Universal Links 域名部署

- **状态**：⏳ 待完成（P2 前，与 H-05 配合）
- **做什么**：
  1. 准备一个可 HTTPS 访问的域名
  2. 在域名根目录部署 `apple-app-site-association` 文件（微信 iOS 回调要求）
  3. 在微信开放平台填写 Universal Links 地址
- **注意**：若暂时没有域名，可先使用 URL Scheme 方式（`wx{AppID}://`）作为临时方案，Universal Links 在 App Store 版本前补充
- **预计时长**：视域名情况，30 分钟 – 2 小时

---

## [BLOCKING] H-14 — 腾讯云轻量服务器购买与初始化

- **状态**：✅ 已完成（2026-03-29）
- **做什么**：
  1. 登录 [腾讯云控制台](https://console.cloud.tencent.com)
  2. 购买「轻量应用服务器」（推荐：2核2G，香港节点或上海节点，约 ¥50/月）
  3. 选择镜像：Ubuntu 22.04 LTS（或 Node.js 应用镜像）
  4. 配置安全组：开放 80、443、22 端口
  5. 绑定已备案域名（或先用 IP 开发）
- **在哪里**：[https://console.cloud.tencent.com/lighthouse](https://console.cloud.tencent.com/lighthouse)
- **预计时长**：30 分钟
- **完成后**：将服务器 IP / 域名填入 `Config/Debug.xcconfig` 的 `API_BASE_URL` 字段
- **影响任务**：T-P2-05（后端同步服务）

---

## [BLOCKING] H-15 — 腾讯云短信服务申请

- **状态**：⏳ 待完成（P2 前）
- **做什么**：
  1. 腾讯云控制台 → 短信 SMS → 开通服务
  2. 创建「国内短信」签名（签名内容：球迹）
  3. 创建验证码模板（内容：「您的验证码为 {1}，5分钟内有效。」）
  4. 提交审核（通常 2 小时内通过）
  5. 获取 SDK AppID 和 AppKey
- **在哪里**：[https://console.cloud.tencent.com/smsv2](https://console.cloud.tencent.com/smsv2)
- **预计时长**：30 分钟（审核需 2 小时）
- **完成后**：将 SMS AppID / AppKey / 签名 / 模板 ID 填入后端 `.env` 文件
- **影响任务**：T-P1-07（手机验证码登录）

---

## [BLOCKING] H-16 — 腾讯云 MongoDB 数据库创建

- **状态**：⏳ 待完成（P2 前）
- **做什么**：
  1. 腾讯云控制台 → 云数据库 TencentDB for MongoDB
  2. 购买「副本集实例」（推荐：1核2G，与服务器同地域，约 ¥50/月）
  3. 创建数据库用户（设置强密码）
  4. 配置白名单（允许轻量服务器内网 IP 访问）
  5. 获取连接字符串（MongoDB URI）
- **在哪里**：[https://console.cloud.tencent.com/mongodb](https://console.cloud.tencent.com/mongodb)
- **预计时长**：20 分钟
- **完成后**：将 MongoDB URI 填入后端 `.env` 文件
- **影响任务**：T-P2-05（用户数据持久化）
