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

- **状态**：🔜 推迟至 App 主体开发完成后（用户决定，2026-03-29）
- **做什么**：
  1. 注册/登录 [微信开放平台](https://open.weixin.qq.com)
  2. 创建移动应用（填写 App 名称、简介、图标）
  3. 提交审核（需要：App Store 链接或 TestFlight 链接/截图，目前可先提交 TestFlight 内测截图）
  4. 审核通过后获得 **AppID** 和 **AppSecret**
- **在哪里**：[https://open.weixin.qq.com](https://open.weixin.qq.com)
- **预计时长**：提交 15 分钟，等待 1–3 个工作日
- **影响任务**：T-P1-08（微信登录集成需要 AppID）
- **完成后**：将 AppID 填入 `Config/Debug.xcconfig` 的 `WECHAT_APP_ID` 字段
- **备注**：已有 Sign in with Apple，微信登录为增强功能，推迟不影响核心开发

---

## [BLOCKING] H-06 — ~~LeanCloud 账号注册~~（已取消）

- **状态**：✅ 已取消（ADR-001，2026-03-29）
- **原因**：LeanCloud 停止国内新用户注册；已改用自建 REST API 后端（见 H-14 ~ H-16）

---

## [BLOCKING] H-07 — ~~CloudKit 容器创建 + Schema 初始化~~（已取消）

- **状态**：✅ 已取消（ADR-002，2026-03-29）
- **原因**：公开 Drill / 官方计划内容改由 **Bundle 离线保底 + 自建 REST API OTA**（如 `GET /drills`）提供；不再使用 CloudKit 公开库，避免双云栈与额外人工配置。

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

#### Batch 1 ✅ 已验证（2026-03-29）
- **fundamentals**（5 条）：drill_c006 握杆稳定性、drill_c007 站位对齐、drill_c008 手架练习、drill_c009 直线出杆检验、drill_c010 中杆定杆
- **accuracy**（5 条）：drill_c001 半台直线球、drill_c002 斜角入底角袋、drill_c011 近台底袋直线、drill_c012 中袋直线入袋、drill_c013 底袋小角度入袋
- 全部 L0 级别，`isPremium: false`
- 坐标自检通过 ✅
- 人工内容核查通过 ✅（2026-03-29）

#### Batch 2 ⏳ 待验证
- **cueAction**（8 条）：drill_c014 中杆定杆基础（L0）、drill_c015 高杆远台跟进（L1）、drill_c016 斯登角度停球（L1）、drill_c017 低杆远台缩杆（L2）、drill_c018 左塞一库变线（L2）、drill_c019 右塞一库变线（L2）、drill_c020 高杆加塞走位（L2）、drill_c021 低杆加塞回位（L3）
- **fundamentals**（2 条）：drill_c022 远台直线出杆检验（L1）、drill_c023 五分点瞄准线练习（L1）
- 级别分布：L0 ×1、L1 ×4、L2 ×4、L3 ×1
- `isPremium` 分布：free ×6（L0–L1 全免费 + L2 ×1）、paid ×4（L2 ×3 + L3 ×1）
- 坐标自检通过 ✅
- 人工内容核查：⏳ 待验证

#### Batch 3–7 ⏳ 待验证（52 条，2026-03-29 一次性生成）
- **Batch 3** · separation 8 + accuracy 2：drill_c024–c033
- **Batch 4** · positioning 9 + fundamentals 1：drill_c034–c043
- **Batch 5** · forceControl 8 + accuracy 2：drill_c044–c053
- **Batch 6** · specialShots 8 + accuracy 2：drill_c054–c063
- **Batch 7** · combined 8 + accuracy 1：drill_c064–c072
- 级别分布：L1 ×11、L2 ×24、L3 ×11、L4 ×1（不含 Batch 2 的 5 条 L1）
- `isPremium` 分布：free ×15、paid ×37
- 坐标自检通过 ✅（全部 52 条）
- 人工内容核查：⏳ 待验证

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

## H-15 — 腾讯云短信服务申请

- **状态**：🔜 推迟至 App 主体开发完成后（用户决定，2026-03-29）
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
- **备注**：已有 Sign in with Apple，短信登录为增强功能，推迟不影响核心开发

---

## [BLOCKING] H-16 — MongoDB 数据库安装（同机部署）

- **状态**：✅ 已完成（2026-03-29）
- **方案变更**：取消独立 TencentDB for MongoDB（节省 ¥50/月），改为在已有轻量服务器上同机安装
- **已完成操作**：
  1. 在 106.54.3.210（Ubuntu 22.04）上安装 MongoDB 7.0.31（官方 APT 源）
  2. 创建管理员用户 `qiujiAdmin`（admin 库）
  3. 创建应用用户 `qiujiApp`（qiuji 库，readWrite 权限）
  4. 开启 `security.authorization: enabled`
  5. 仅监听 `127.0.0.1:27017`，不暴露公网
  6. 设为开机自启（`systemctl enable mongod`）
- **连接字符串**：`mongodb://qiujiApp:<password>@127.0.0.1:27017/qiuji?authSource=qiuji`
- **影响任务**：T-P2-05（用户数据持久化）— 阻塞已解除
