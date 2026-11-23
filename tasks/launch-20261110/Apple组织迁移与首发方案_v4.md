# CuePhys Apple 组织迁移与首发方案

> 本文件是本轮 Apple 事项的需求真源。版本 v4.4，2026-11-23（北京时间）建立。它在 v4.3 的基础上补齐外部阻塞、域名职责、Apple 登录密钥、微信凭据和正式商品的配置时机。外部后台状态以实际页面和回执为准，代码状态以本文件列出的仓库锚点为准。当前已完成外部身份准备，尚未执行代码改名、App Store Connect Bundle ID 切换、提交审核或发布。

## 一、当前已确认

| 对象 | 已确认结果 | 证据与边界 |
|---|---|---|
| Apple 会员主体 | 已转为组织 `Wuxi Youqiu Technology Co., Ltd`，Team ID `KWH2GRNSKG`，续订日 2027-03-28，页面显示年费 RMB 688 | Apple Developer 账户页与 11/23 邮件。迁移期间出现的停用提示已结束。 |
| App Store Connect App | 现有 App「球迹」，App ID `6761309682`，SKU `QJ-001`，iOS 1.0 为「准备提交」，版本页尚未上传 build | 11/23 Edge 实查。App 信息页显示 SKU `QJ-001`；版本页仍显示“从多种工具中选取一种来上传你的构建版本”。按 Apple 规则，当前可优先在现有 App 记录内切换 Bundle ID。 |
| Apple Developer 新 App ID | 已登记显式 App ID `com.youbilliards.cuephys`，描述为 `CuePhys` | 11/23 Edge 实查登记结果。已启用 `Associated Domains` 和 `Sign in with Apple`；未启用推送等未核实能力。 |
| 产品公开名 | 产品决定为 CuePhys，说明性标题可用「CuePhys：台球训练」 | 需要在 App Store Connect 核公开名称、卖方和商店文案，尚未提交审核。代码侧改名只在方案确认后执行。 |
| App 内显示名 | `CFBundleName` 与 `CFBundleDisplayName` 已为 `CuePhys` | `QiuJi/Resources/Info.plist:5-20`。这是客户端显示名。 |
| 既有技术标识 | 将按新旧映射分批切换，持久化和购买兼容键在迁移窗口保留 | 主 Bundle ID、Swift 模块、StoreKit 新商品 ID、测试宿主、后端配置和当前构建入口统一改为 CuePhys。SwiftData schema 名称、旧商品 ID、旧账号令牌命名空间和历史数据库名作为兼容读取或回滚锚点保留，不做无证据的删除。 |
| Apple 登录客户端 | Apple 授权请求、回调、绑定和注销链路已实现，正式请求要求安全 API 地址 | `QiuJi/Data/Services/AuthService.swift:45-155`，`QiuJi/Core/Extensions/AppConfig.swift:4-39`。 |
| Apple 登录服务端 | 使用 Bundle ID 校验 `aud`，授权码换取 Apple refresh token，并加密保存后支持撤销 | `backend/src/config/index.js:26-45`，`backend/src/services/appleGrant.js:9-62`，`backend/src/routes/auth.js:17-139`。 |
| 生产配置 | Release 仅接受 `https://cuephys.com` 或其子域名。当前私有配置仍是 HTTP IP 占位，不能进行正式登录联调 | `Config/Secrets.xcconfig:4-7`，`QiuJi/Core/Extensions/AppConfig.swift:16-32`。 |
| 中国大陆商店合规 | App Store Connect 页面提示需要安全评估证明和 AIGC 服务声明 | 11/23 App Store Connect 页面提示。按实际功能和主管部门要求填，不凭猜测选择不适用。 |
| 网站 | `https://youbilliards.com/` 已上线，网站服务备案号为 `苏ICP备2026091631号-1` | 网站备案不能替代 App 备案。App 备案仍单独跟踪。 |
| 微信 | 企业认证已付款，移动应用正式 AppID、Universal Links 和回调实测仍未闭合 | `Config/Debug.xcconfig:14-16` 仍是占位。 |

## 九-B、外部阻塞与配置时机（v4.4）

| 外部项 | 是什么／在哪里用 | 当前状态 | 合适的配置时机 | 负责人和边界 |
|---|---|---|---|---|
| API 域名 | App 访问后端的 HTTPS 地址，例如 `https://api.cuephys.com`。它不是 iOS App 的 Bundle ID，也不是 App Store 的公开名称 | 当前 Release 仍是 HTTP IP 占位；DNS、证书、反向代理和 CORS 未闭合。若 API 放在中国大陆服务器，`cuephys.com` 还要单独办理或接入网站服务备案，不能直接沿用 `youbilliards.com` 的备案号 | 在代码改名完成前先确定主机名；在 Apple／微信真实登录联调前必须完成 HTTPS 健康检查和域名备案核验 | 我准备服务器和客户端配置；域名 DNS、证书、备案和生产密钥按部署权限操作 |
| App 产品域名 | 官网、法律页、客服和品牌入口。当前已备案并上线的是 `youbilliards.com`；已购买的 `cuephys.com` 可以作为产品域名或 API 根域名 | 两个域名都存在，但用途尚未冻结 | 现在冻结职责，不必等 Apple 或微信审核；不把官网域名和 API 域名混成一个地址 | 建议 `api.cuephys.com` 只作 API，`youbilliards.com` 继续作公司官网、法律页和备案展示；是否让 `cuephys.com` 做跳转或产品落地页另行决定 |
| Apple 登录密钥 | Apple Developer 组织 Team 下创建的 Sign in with Apple `.p8` 私钥。服务器用它生成 client secret JWT、交换授权码、刷新或撤销 token | 尚未创建；当前不能做生产 Apple 登录联调 | Bundle ID 切换、HTTPS 主机和 `APPLE_BUNDLE_ID` 冻结后，再创建并立即放入受控服务器密钥目录 | 用户本人在 Apple Developer 创建并下载；我负责服务端配置、自检和脱敏联调；私钥不进仓库、聊天或截图 |
| 微信 AppID | 微信开放平台“移动应用”的公开标识。客户端发起微信授权、Universal Link 和回调配置都使用它 | 企业认证已付款，移动应用 AppID 尚未核实到位 | 微信企业认证完成并确定正式 Bundle ID、HTTPS 回调域名后配置；可先准备字段，不先写生产值 | 用户在微信开放平台查看／创建移动应用；我负责客户端、服务端和 AASA 接入 |
| 微信 AppSecret | 与 AppID 配对的服务端密钥。后端用授权临时 `code` 换 access token、openid／unionid；不能放进 App 包 | 尚未配置 | 与 AppID 同批，在 HTTPS 和回调域名完成后配置；先做受控环境联调，再写生产环境 | 用户提供给受控服务器配置，不在聊天中发送；我负责读取校验和日志脱敏 |
| 正式商品状态 | App Store Connect 内永久会员商品的类型、ID、价格、中国区销售范围、税务／银行状态和可售状态；本地 `Products.storekit` 不代表正式状态 | 方案已确定一次性永久会员，但正式商品状态和通知 URL 尚未核对 | 现在可以只读核对现有商品；等名称、Pro 权益、价格、Bundle ID 和购买归属冻结后，再创建／启用新 CuePhys 商品；必须早于 TestFlight 购买验收和提审 | 我整理商品与权益核对表；用户最终确认价格、地区和付费协议；不提前创建重复商品或停用旧商品 |

这里的“外部阻塞”不等于现在不能继续开发：在产品内容未完全准备好之前，可以完成工程盘点、迁移兼容、UI 文案、测试夹具、HTTPS 方案和商品核对表；只有真实登录、正式购买、TestFlight 和提审依赖的凭据与后台配置暂不落生产。

## 九-A、全量覆盖审计（v4.3）

“全都改掉”按当前构建、当前线上服务和当前公开资料执行；历史证据、SwiftData 版本类型、旧商品交易读取和旧账号数据字段不做破坏性改名。以下项目是本轮审计补出的容易漏项：

| 覆盖域 | 必须处理的内容 | 处理方式 | 当前状态／缺口 |
|---|---|---|---|
| 工程文件与生成入口 | `project.yml`、`QiuJi.xcodeproj`、共享 scheme、`QiuJi/`、`QiuJiTests/`、`QiuJiUITests/`、`QiuJiLiveActivity/` 目录、target 名、`@testable import`、`TEST_HOST`、产物路径 | 当前构建和测试统一切 CuePhys；历史归档路径保留，不重写证据 | 待 B1/C0 执行 |
| Bundle 与 entitlement | 主 App、Live Activity、单测、UI 测试 Bundle ID；Associated Domains、URL scheme、App Group、Live Activity、推送等实际 entitlement | 逐个解包检查；只登记实际使用的能力；旧描述文件保留回滚 | 新 App ID 已登记，工程尚未切换 |
| Apple 登录与身份映射 | 客户端 `aud`、服务端 `APPLE_BUNDLE_ID`、Team/Key/Service ID、授权撤销、Apple `sub` 旧新映射 | 新值生产使用；旧 `sub` 只作迁移兼容；私钥不进仓库 | HTTPS 和 Apple Key 待办 |
| 微信登录与回调 | `WECHAT_APP_ID/SECRET`、Universal Link、AASA、回调域、微信 entitlements、已安装／未安装微信路径 | 企业认证完成后写入受控配置并真机验证 | AppID、AASA 和回调未闭合 |
| StoreKit 与 App Store Server Notifications | 旧／新商品 ID、`Products.storekit`、永久会员权益、恢复购买、`appAccountToken`、生产／沙盒通知 URL、交易校验 | 正式商品身份以后台为准；旧商品只兼容读取；通知 URL 和交易服务一起切换 | 商品后台、通知 URL 和测试待核 |
| 本地数据与账号 | Keychain 服务名和键、UserDefaults suite、SwiftData schema、游客／登录 owner、注销状态、绑定关系 | 新写入、旧读取迁移；`QiuJiSchemaV1-V6` 和注销审计字段保留 | 待 C2/D2 实施与恢复验证 |
| 后端部署与备份 | npm 包名、`/opt/qiuji-backend`、systemd 服务、Mongo `qiuji`、头像目录、恢复备份脚本和告警标签 | 生产迁移用别名／迁移脚本；systemd、备份与恢复演练同步更新；旧密文可回放 | 当前仍有旧目录和数据库名，待 D0/D2 |
| 日志、分析与通知 | Logger subsystem、分析事件前缀、`qiuji.training.daily-reminder` 等通知标识、调试窗口标识 | 当前构建和新事件切 CuePhys；旧事件和通知标识保留兼容读取或查询映射 | 已发现多处旧值，待 E1/D2 |
| API 与域名 | Release API、CORS、健康检查、法律页、AASA、证书和 DNS；`cuephys.com` 与 `youbilliards.com` 的用途 | 先冻结职责：建议 `api.cuephys.com` 仅作 App API，`youbilliards.com` 保留公司官网与备案法律页；不把两个域名互相批量替换 | API 主机和证书尚未最终确定 |
| 公开商店与素材 | App Store Connect 名称、卖方、简介、截图、预览、审核备注、隐私标签、年龄分级、AIGC／安全评估材料、支持邮箱和法律链接 | 当前公开内容全部用 CuePhys；旧球迹只留历史资料和兼容说明 | 商店公开资料待核，未提交 |
| 官网、邮件与知识产权 | 官网产品名、支持入口、法律页、商标使用说明、客服邮箱、备案／公安联网备案展示 | 对外新文案统一 CuePhys；公司主体、备案号和历史收文不改 | 官网已上线，CuePhys 域名与邮箱职责仍需明确 |
| 设备、脚本与文档 | simulator matrix、Makefile、安装／归档／截图脚本、人工测试计划、当前台账和发布包路径 | 当前入口改 CuePhys；历史报告、研究和失败记录保留原文 | 已完成盘点，待 E1 和文档收口 |

域名边界是当前唯一需要产品决定的架构项：App 本身没有“App 域名”，它只访问 API 主机；`cuephys.com` 可以作为 API 或产品域名，但公司官网目前使用已备案的 `youbilliards.com`。如果选 `api.cuephys.com` 承载中国大陆 API，还要单独核对该域名的备案接入。在没有决定前，不把官网地址、API 地址、法律页地址和微信 Universal Link 混成一个域名。

## 二、全量标识迁移的可行性与风险

用户倾向在首发前把公开品牌和技术标识全部统一为 CuePhys。这个方向可以做，但需要先通过一个 Apple 后台门槛，再按新 App 标识迁移处理。

### 1. 先核实现有 App 是否已经上传过 build

- Apple 文档说明，现有 App 记录如果还没有上传 build，可以在 App Store Connect 中改选新的 Bundle ID。
- 一旦已有 build 上传，Bundle ID 就不能在该 App 记录中修改，需要创建新的 App 记录。
- 当前页面显示 iOS 1.0「准备提交」，版本页构建区域仍显示上传入口，已确认没有上传 build。因此采用现有 App 记录切换 Bundle ID 的路线。在切换完成并完成候选包验收前，禁止上传任何新 build。

### 2. 全量改名会遇到的问题

| 风险项 | 影响 | 处理要求 |
|---|---|---|
| Bundle ID 与 App ID | 新 Bundle ID 会改变 Apple 对应用的唯一身份。已有 build 时需要新 App 记录，旧记录不能直接变成同一个应用。 | 先核 build 状态。若需要新记录，旧「球迹」记录保留归档，不删除、不提交。 |
| App Store Connect 固定身份 | 数字 App ID `6761309682`、SKU `QJ-001` 和 App 记录属于后台固定身份，不能按品牌批量改名。 | 继续使用现有 App 记录，公开名称和 Bundle ID 单独处理；SKU 只作记录，不改写。 |
| Apple 登录 | 原生 Apple 登录的 client ID、JWT `aud`、entitlement 和服务端校验都依赖 Bundle ID。新 Bundle ID 可能让同一 Apple 用户在服务端呈现新的应用范围身份。 | 更新 `QiuJi/Data/Services/AuthService.swift:45-155`、`backend/src/config/index.js:26-45`、`backend/src/services/appleGrant.js:31-62`，为测试用户建立新旧身份映射策略。 |
| Apple 登录密钥 | 新 App ID 需要重新核对 Sign in with Apple 能力、Key、Service ID 和回调配置。 | 新标识确认后再创建或重配密钥，不能用旧配置直接冒充新 App。 |
| StoreKit 商品 ID | Apple 不允许修改已保存的 Product ID，也不能在同一 App 中复用已删除的旧 Product ID。 | 若全部统一命名，创建新的 CuePhys 商品 ID，重新核类型、价格、地区和审核资料。旧商品记录保留证据，不直接删除。来源为 Apple 官方商品信息文档。 |
| 会员归属与恢复购买 | 新商品 ID 会影响已购买会员的读取和恢复。当前代码按商品 ID及 `appAccountToken`判断归属。 | 更新 `QiuJi/Data/Services/StoreKitService.swift:52-83` 与 `SubscriptionManager.swift:324-349`，对旧商品做兼容读取或明确首发前无正式购买迁移。 |
| 本地 Keychain 与 UserDefaults | Bundle ID、访问组或命名空间变化可能使测试安装读不到旧登录状态、年龄声明和本地训练设置。 | 建立旧键读取和新键写入的迁移期，或在首发前明确清空测试数据并重新登录。不能直接改名后假定数据仍可读。 |
| 后端数据与日志 | 数据库名、集合名、日志 subsystem、分析事件和账号字段改名会影响脚本、查询和历史报表。 | 先做兼容别名和迁移脚本，迁移完成后再清理旧名称。生产数据库不能靠文件名批量替换。 |
| 微信登录 | AppID、Universal Links、AASA、微信后台回调和服务器域名需要完全一致。 | 更新 `QiuJi/Core/Extensions/AppConfig.swift:41-50`、`Config/WeChat.entitlements`、服务端 `wechatLogin.js` 和 AASA 文件，重新做未安装微信、取消、回调中断和重试测试。 |
| 推送、Live Activity 与扩展 | 相关 entitlement、App Group、推送环境和扩展 Bundle ID 可能跟随主 Bundle ID变化。 | 逐项重建标识和描述文件，覆盖通知、Live Activity、系统设置显示和卸载重装。 |
| TestFlight 与审核资料 | 如果走新 App 记录，测试组、审核历史、截图、隐私标签、合规问卷和审核备注都要重新准备。 | 旧记录只保留为证据，所有提交资料按 CuePhys 新记录重新核对。 |
| 数据和测试成本 | 当前没有正式用户和正式销售，风险明显较低，但已有本地测试账号、模拟器数据和后端测试数据。 | 先备份测试数据，完成迁移或明确重置，再开始新标识联调。 |

### 3. 建议路线

我建议在首发前做全量统一，但采用“先确认后台条件，再一次性迁移”的顺序。

1. 已在 11/23 Edge 实查版本页，当前没有上传 build。
2. Apple Developer 已登记新的显式 App ID `com.youbilliards.cuephys`（描述 `CuePhys`），并启用 Associated Domains、Sign in with Apple。下一步是在现有 App 记录 `6761309682` 中改选该 Bundle ID；当前尚未切换。
3. 若已有 build，创建新的 CuePhys App 记录。旧记录保留，不再提交。
4. 冻结新的 Bundle ID、Swift 模块名、StoreKit 商品 ID、Keychain 命名空间和数据库迁移策略。
5. 先更新开发配置和测试环境，完成 Apple、微信、内购、恢复购买、注销和数据迁移验证。
6. 通过 TestFlight 验收后，再补齐 App Store Connect 商店资料并提交审核。

这条路线能把长期维护名称统一，同时把现有记录和测试证据保留下来。任何删除旧记录、停用旧商品或切换生产登录配置的动作，都放在新标识验证完成之后。

Apple 依据链接为 [Changing the bundle identifier](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier)、[App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information) 和 [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)。

## 三、已经拍板的产品与账号规则

1. 正式产品名使用 CuePhys，商店显示名、客户端公开文案、法律页面和备案材料保持一致。
2. 公开名称和当前构建技术标识统一使用 CuePhys。旧标识只保留在迁移兼容、SwiftData schema、历史证据和回滚配置中。
3. 首发登录包含 Apple 和微信。两种登录身份可以绑定同一个 CuePhys 账号。
4. 如果两个独立登录身份已经各有训练记录，首发保留两个账号及各自记录，提示用户走原账号或绑定路径，不自动合并训练数据。
5. 首发只销售一次性永久会员。月付和年付不进入首发商品选择。新候选包使用 CuePhys 商品 ID，旧商品 ID 仅用于恢复兼容，正式商品是否新建要先核对 App Store Connect 现有商品状态和历史交易。
6. 游客仍可进行本机基础训练。账号、同步和购买需要真实 HTTPS 服务与年龄声明链路。

## 四、批次表

| 批次 | 范围 | 量级 | 依赖 | 一次会话完成标准 |
|---|---|---:|---|---|
| A0 身份与命名冻结 | 核组织卖方、App ID、Bundle ID、公开名 CuePhys、App 内显示名和技术旧标识边界 | S | 已完成外部身份准备 | 已记录组织 Team、现有 App ID/SKU、新 App ID、能力开关和名称决策；App Store Connect 公开名称与 Bundle ID 切换仍待候选包前执行。 |
| A1 商务协议与商品 | 核「商务」里的付费应用协议、银行税务状态、永久会员商品状态、中国区价格、销售范围和恢复购买 | M | A0 | 付费协议状态有截图或明确待办。永久会员商品 ID、类型、价格、可售状态和审核资料形成一页核对表。月付、年付不会被误选进首发。 |
| A2 中国大陆合规 | 核 App 备案、App Store Connect 安全评估证明、AIGC 服务声明、隐私标签、年龄分级和账号访问说明 | M | A0、A1 的实际功能资料 | 每项填报都有依据、回执或明确待补文件。安全评估和 AIGC 选项不以“没有身份证”作为不适用理由。 |
| A3 生产 HTTPS 与法律页 | 选择 `api.cuephys.com` 或 CuePhys 域名下的 API 主机，配置证书、反向代理、健康检查、法律 URL、CORS 与生产密钥 | L | 网站域名和服务器可控 | `https://` API 实际返回健康结果，登录路径拒绝明文，法律页匿名可访问，证书链、到期提醒和回滚记录齐全。生产 JWT 和 Apple token 加密密钥不写入仓库。 |
| A4 Apple 登录密钥 | 在组织 Team 下创建 Sign in with Apple 私钥，配置 `APPLE_TEAM_ID`、`APPLE_KEY_ID`、私钥路径和 `APPLE_BUNDLE_ID`，部署后验证授权码交换及撤销 | M | A0、A3 | 组织后台的 Key 记录由用户保管。服务器日志只留脱敏结果。首次登录、再次登录、取消重试、隐藏邮箱、退出重登和注销撤销均有真实结果。 |
| A5 微信登录 | 完成企业认证后的移动应用 AppID、AppSecret、Universal Links、AASA、SDK 配置和回调，接入同一 CuePhys 账号绑定规则 | L | 微信认证结果、A3、App 公开域名 | 真机覆盖已安装和未安装微信、拒绝、回调中断、重试、绑定冲突和退出重登。AppSecret 只在受控服务端保存。 |
| A6 CuePhys 候选包 | 统一 App Store 资料、Bundle 显示、Pro 文案、法律链接、权限文案、构建产物、entitlements、扩展和内购 | L | A1-A5 中需要进入候选包的部分 | Archive、签名、entitlements、App ID、Info.plist、Release API、内购商品和 dSYM 全部可追溯。公开名称、测试宿主、脚本和截图文案同步，不能只改一处显示名。 |
| A7 TestFlight 与真机验收 | 内测上传、处理完成、安装、主链路、登录、绑定、同步、购买、恢复、注销、隐私和弱网 | L | A6 | 同一 build 通过 iPhone 与 iPad 代表路径。真实 Apple 登录、永久会员沙盒购买／恢复和账号冲突都有证据。游客路径仍可用。 |
| A8 提审与发布 | 完成审核备注、审核账号或游客访问说明、地区、价格、合规附件、提交审核和发布策略 | M | A7、A2 | 用户确认后再点提交。保留提交时间、build、审核状态、补件和发布放行人。 |

## 五、依赖图

```text
A0 身份与命名冻结
 ├──> A1 商务协议与商品 ──┐
 ├──> A2 中国大陆合规 ────┼──> A6 CuePhys 候选包 ──> A7 真机与 TestFlight ──> A8 提审发布
 └──> A3 HTTPS 与法律页 ──┘
          ├──> A4 Apple 登录密钥 ──┘
          └──> A5 微信登录 ───────┘
```

## 六、各批次执行细则

### A0 身份与命名冻结

- App Store Connect App ID `6761309682` 已核实没有上传 build，SKU 为 `QJ-001`。Apple Developer 新 App ID `com.youbilliards.cuephys` 已登记并启用 Associated Domains、Sign in with Apple。下一步是在现有 App 记录内切换 Bundle ID；切换完成、候选包归档和签名检查完成前，不上传 build，不新建、删除或提交其他 App 记录。
- 把公开名称改为 CuePhys 的动作留在用户确认后执行。公开名称会影响商店展示，不能由代码改名替代。
- 改名清单分四层执行。第一层是用户可见文案，包括 App Store Connect 名称、App 内标题、关于页、登录页、会员页、Pro 权益、帮助页、通知、Live Activity、权限说明、客服和法律页。第二层是发布产物，包括 `CFBundleDisplayName`、`CFBundleName`、`PRODUCT_NAME`、测试宿主、scheme、扩展显示名、截图和 TestFlight 名称。第三层是活动脚本和验收脚本中的产物路径、测试按钮文案和构建参数。第四层是外部资料，包括网站、备案材料、微信开放平台移动应用资料、Apple 审核备注和商标使用说明。
- 全量路线还会把当前主源码目录 `QiuJi/`、测试目录和 Live Activity 目录改为 CuePhys 命名，并同步工程、脚本和文档路径。`QiuJiSchemaV1` 至 `QiuJiSchemaV6`、迁移计划和历史证据文件名保留为持久化兼容锚点。
- 全量路线建立新旧标识映射和迁移窗口后切换。`com.xinkuan.qiuji`、现有商品 ID、Swift 模块 `QiuJi`、后端数据库名、钥匙串键、API 路径和历史数据字段逐项处理，只有需要连续性的持久化标识保留兼容读取。
- 历史研究脚本、历史截图、归档日志中出现的旧产物路径只作为证据保留。执行脚本和当前候选包检查不能继续引用旧产物路径，改名批次要把两类逐项分开登记。
- 当前只完成了方案盘点。代码侧和 App Store Connect 公开名的改动均不以未验收工作区状态作为完成依据。
- 新构建采用 `com.youbilliards.cuephys`、`CuePhys` 模块和 CuePhys 商品 ID。旧商品、旧 Bundle ID、旧钥匙串命名空间和历史 schema 只在兼容迁移代码中保留，并在候选包完成恢复购买与旧数据验证后再决定是否下线。

### A1 商务协议与商品

- 由账号持有人打开 App Store Connect「商务」，查看是否有待接受的付费应用协议。涉及法律接受的按钮由用户本人操作。
- 核现有永久会员商品的正式状态、商品类型和历史交易。候选包目标商品 ID 暂拟 `com.youbilliards.cuephys.premium.lifetime`，代码加载和购买只接受新商品，旧商品 ID进入兼容权益读取集合，见 `QiuJi/Data/Services/StoreKitService.swift:52-83`。
- 核后台商品的中国区价格、可售状态、税务和银行状态。代码中的 `Products.storekit` 只能作为本地测试配置，不能证明正式价格或正式可售。
- 核恢复购买和账号归属。`SubscriptionManager.swift:324-349` 已按 CuePhys 账号的稳定 `appAccountToken` 区分购买归属，另一个账号的永久会员会提示按购买账号恢复。

### A2 中国大陆合规

- 网站备案号 `苏ICP备2026091631号-1` 只用于网站。App 备案单独办理，并在 App Store Connect 的 App 信息里按实际回执填写。
- 对安全评估证明和 AIGC 服务声明分别建状态。先核 App 是否使用生成式内容、智能生成文案、生成图片或外部生成式服务，再按真实情况准备声明和证明。
- 隐私标签按真实字段和接收方填写，至少覆盖 Apple 登录身份凭据、微信授权码、账号资料、头像、生日或年龄段、训练记录、购买信息和注销记录。
- 审核备注必须给出游客路径、Apple 登录路径、永久会员入口、恢复购买和注销路径。审核访问不得依赖个人 Apple 账号。

### A3 生产 HTTPS 与法律页

- Release 配置必须把 `API_BASE_URL` 换成 CuePhys 域名下的 HTTPS 地址。当前 `Config/Secrets.xcconfig:4` 仍是 `http://106.54.3.210:3000` 占位，正式包会因 `AppConfig.validatedAPIBaseURL(..., release: true)` 拒绝该值。
- 在 Apple App ID 切换前，服务器仍临时保留旧的 `APPLE_BUNDLE_ID` 以支持现有测试。切换完成后必须同步为 `com.youbilliards.cuephys`，并用独立随机的 `JWT_SECRET`、`JWT_REFRESH_SECRET` 和 64 位十六进制 `APPLE_TOKEN_ENCRYPTION_KEY`。两套配置不得同时作为生产默认值。
- 法律页使用已上线网站的 HTTPS 路径，并在匿名设备上逐个打开。未发布或占位 URL 继续保持空值，避免把错误链接打进候选包。

### A4 Apple 登录密钥

- 组织 Team 下创建密钥时记录 Key ID 和创建时间，私钥只下载一次并放在受控密钥目录。不要把 `.p8`、服务器 `.env` 或完整 JWT 放进仓库、聊天或截图。
- 服务端现有 `appleGrant.js:31-49` 使用 Team ID、Key ID、私钥路径生成 client secret，并向 Apple 换取 token。部署前先做配置自检，再用一次性授权码做真实交换。
- 测试顺序固定为首次授权、再次授权、取消、网络失败重试、隐藏邮箱、退出重登、账号绑定、注销后旧令牌拒绝和 Apple 授权撤销。每次只记录脱敏账号别名和 HTTP 结果。
- 新 App ID 登记后先核对 Sign in with Apple 能力，再核对组织 Team 下的 Key、Service ID、回调地址和描述文件。只有当客户端 `aud`、服务端 `APPLE_BUNDLE_ID` 和 Apple 后台标识完全一致时，才进入真实授权码交换。

### A5 微信登录

- 等企业认证结果和移动应用 AppID 到位后，再把 `WECHAT_APP_ID`、`WECHAT_UNIVERSAL_LINK` 和 `WECHAT_LINK_HOST` 写入 Release 私有配置。当前 `Config/Debug.xcconfig:14-16` 是占位，不能拿来做正式登录。
- Universal Links 必须和 AASA、服务器 HTTPS、微信开放平台配置中的域名完全一致。微信登录回调成功后仍由服务端唯一索引和绑定接口决定账号归属，不以昵称、头像或邮箱自动合并。

### A6-A8 候选包、验收和提交

- 先生成一个改名候选包，检查桌面图标、系统设置、关于页、登录页、会员页、Pro 权益、帮助页、通知、Live Activity、扩展、系统权限提示和 TestFlight 显示名。
- 用 `rg` 对源码、资源、脚本、测试、App Store 文案草稿和网站发布清单做一次旧品牌扫描。每个命中项标记为公开文案、当前构建路径、技术连续性标识或历史证据，并在验收记录中说明处理结果。
- 运行 `verify-gate`、受影响的 StoreKit、登录、账号绑定、注销、同步和 App Store UI 测试。测试结果必须同时写明模拟器、真机、版本和 build。
- 上传后等待 App Store Connect 处理完成，再在 TestFlight 安装同一 build。用户验收通过后才提交审核。

### 5. 锚点索引（核对日期 2026-11-23）

| 领域 | 当前锚点 | 本轮需要核对的附加项 |
|---|---|---|
| 工程生成 | `project.yml:44-321` | target 名、scheme、主 App、Live Activity、单测和 UI 测试 Bundle ID，`TEST_HOST`、导出产物名和 `QiuJi/` 源码路径 |
| 当前构建配置 | `Config/Debug.xcconfig`、`Config/Release.xcconfig`、`Config/Secrets.xcconfig` | `CUEPHYS_ENTITLEMENTS`、API 地址、法律 URL、微信占位配置和 Release 私密配置来源 |
| App 权限和扩展 | `QiuJi/Resources/Info.plist`、`QiuJi/QiuJi.entitlements`、`QiuJiLiveActivity/Info.plist`、`Config/WeChat.entitlements` | Associated Domains、Live Activities、实际启用的推送能力、URL scheme、应用组和扩展嵌套关系 |
| Apple 登录 | `QiuJi/Data/Services/AuthService.swift`、`backend/src/config/index.js`、`backend/src/services/appleGrant.js`、`backend/src/routes/auth.js` | 新 Bundle ID 的 `aud`、组织 Team、Key、私钥路径、撤销与身份映射 |
| StoreKit | `QiuJi/Data/Services/StoreKitService.swift`、`SubscriptionManager.swift`、`QiuJi/Resources/Products.storekit` | 新旧商品 ID、非消耗型类型、购买归属、恢复购买和正式商品状态 |
| 本地数据 | `QiuJi/Data/Models/ModelContainerFactory.swift`、`QiuJi/Data/Services/FirstRunProfileFlow.swift`、Keychain 服务 | 旧安装迁移、年龄段和训练记录、注销状态、旧 Keychain 读取与新键写入 |
| 服务端和脚本 | `backend/src/config/index.js`、`backend/src/scripts/seedDrills.js`、`scripts/Makefile`、`scripts/simulator-preview/devices.json`、`scripts/native-atlas/` | 默认数据库名、日志 subsystem、模拟器 Bundle ID、产物路径、当前脚本与历史研究脚本边界 |
| 外部资料 | App Store Connect、Apple Developer、微信开放平台、备案台账、官网法律页 | 公开名称、卖方、App 备案、网站备案、AppID、Universal Links、价格、隐私和审核备注 |

## 七、需要用户本人操作的节点

1. App Store Connect「商务」页若有待接受的付费应用协议，由用户本人阅读并接受。
2. 在 App Store Connect 确认公开名称改为 CuePhys，并核对卖方、价格和销售范围。
3. 在组织 Team 下创建 Apple 登录密钥，并把 Key ID、私钥文件通过受控方式放到服务器配置位置，不在聊天中发送私钥内容。
4. 对安全评估证明和 AIGC 服务声明的实际选项作最终确认。需要上传的官方文件由用户提供或按官方流程取得。
5. TestFlight 和审核提交前，用户确认最终公开名称、价格、地区和发布时点。

## 八、当前最先做什么

1. 已确认现有版本页没有 build，且新 App ID 与 SKU 已实查；当前不上传 build、不提交审核。
2. 在现有 App `6761309682` 内把 Bundle ID 从旧值切换到 `com.youbilliards.cuephys`；若页面要求本人验证，停在该具体步骤由用户操作。
3. 用户在 App Store Connect「商务」查看付费应用协议并处理待签事项；同时核对公开名称、卖方、价格和销售范围。
4. 由我按四层改名清单核对源码、资源、脚本、测试、商店文案和网站发布清单，输出逐项变更表，然后执行代码侧改名和候选包验证。持久化兼容键和历史证据保留到迁移验收结束。
5. 服务器 HTTPS 主机确定后，再创建 Apple 登录密钥并做真实登录联调。微信认证完成后接入第二条真实登录链路。

## 九、全量改名执行清单

### 1. 当前构建与 Apple 外部标识

| 批次 | 真实锚点 | 计划变更 | 依赖 | 完成标准 |
|---|---|---|---|---|
| B0 | App Store Connect App `6761309682`，版本页 iOS 1.0 | 现有记录继续使用，改选 `com.youbilliards.cuephys` | Apple Developer 新 App ID 已登记 | App 信息页保存后可见新 Bundle ID，未创建重复 App 记录，旧记录和旧 App ID 仍可追溯 |
| B1 | `project.yml:44-321`、`Config/Debug.xcconfig`、`Config/Release.xcconfig` | 主 target、Live Activity、测试 target、scheme、Bundle ID、产物名和 Swift 模块统一到 CuePhys | B0 设计确认 | xcodegen 后工程可生成，四个产物的 Bundle ID、产品名、宿主和 scheme 全部一致 |
| B2 | `QiuJi/Resources/Info.plist`、`QiuJi/QiuJi.entitlements`、`Config/WeChat.entitlements` | 显示名、URL scheme、Associated Domains、Live Activity 和权限文案按新标识核对 | B1 | 解包检查 Info.plist、entitlements 和扩展嵌套关系，无旧 Bundle ID 的当前构建漏项 |

### 2. 代码模块与测试入口

| 批次 | 真实锚点 | 计划变更 | 依赖 | 完成标准 |
|---|---|---|---|---|
| C0 | `QiuJi/**/*.swift`、`QiuJiTests/**/*.swift`、`QiuJiUITests/**/*.swift` | 当前 target 的 `@testable import`、测试宿主、启动参数和窗口标识改为 CuePhys | B1 | 单测和 UI 测试能找到新模块与新 Bundle ID，旧名称只出现在兼容或历史说明中 |
| C1 | `QiuJi/Data/Services/StoreKitService.swift`、`SubscriptionManager.swift`、`QiuJi/Resources/Products.storekit` | 新商品 ID 进入本地测试与新购买入口，旧商品 ID只做兼容读取 | B0、B1 | 本地购买、当前权益、恢复购买、账号归属和旧交易读取分别通过，不能把旧商品误当成新商品创建成功 |
| C2 | `QiuJi/Data/Models/ModelContainerFactory.swift`、`QiuJiSchemaV1-V6`、`FirstRunProfileFlow.swift`、Keychain 服务 | 新命名空间写入，旧命名空间一次性读取迁移；schema 类型和历史字段保留 | C0 | 干净安装、旧安装、注销后重装三种状态数据边界明确，旧训练记录和注销状态不串号 |

### 3. 服务端与外部登录

| 批次 | 真实锚点 | 计划变更 | 依赖 | 完成标准 |
|---|---|---|---|---|
| D0 | `backend/src/config/index.js`、`backend/src/services/appleGrant.js`、`backend/src/routes/auth.js` | Apple `aud`、环境模板和日志标签切到新 Bundle ID，数据库名通过迁移脚本或别名切换 | B0、C2、HTTPS | 新 Apple token 校验成功，旧数据可读，JWT 和 Apple 私钥不进入仓库 |
| D1 | `QiuJi/Core/Extensions/AppConfig.swift`、`Config/WeChat.entitlements`、微信回调/AASA 配置 | HTTPS、Universal Links、微信 AppID 和回调域名统一 | B1、D0、微信认证结果 | 安装微信和未安装微信两条登录路径、取消、回调中断和重试都有结果 |
| D2 | `backend/src/services/accountDeletion.js`、注销备份与异机恢复脚本 | 注销、恢复和绑定记录的日志与备份标签切到新名称，保留历史回放字段 | C2、D0 | 注销记录不会因改名丢失，恢复演练后旧账号数据仍清零，失败提醒仍可达主开发 Mac 和 Mac mini |

### 4. 文案、资源、脚本和商店资料

| 批次 | 范围 | 计划变更 | 完成标准 |
|---|---|---|---|
| E0 | App 内公开文案、帮助页、登录页、Pro 权益、法律页、通知和 Live Activity | 用户可见的“球迹”统一替换为 CuePhys，训练术语按已确认词表处理 | `rg` 扫描当前构建资源无旧公开品牌命中，历史文档单独列为证据 |
| E1 | `scripts/`、Makefile、截图巡游、测试计划、导出与归档入口 | 当前执行脚本只引用 CuePhys 产物，历史路径不重写 | 归档、导出、安装和 UI 巡游均能定位新产物 |
| E2 | App Store Connect 文案、隐私标签、审核备注、备案和网站发布清单 | 公开 App 名、卖方、法律 URL、支持邮箱和备案信息统一 | 用户核对公开内容后再提交，所有外部资料有时间和回执 |

## 十、必须先解决的问题

1. Apple Developer 新 App ID 已登记，需在工程改名后重新核对 Associated Domains、Sign in with Apple 与实际 entitlements；推送能力只有在功能实际启用时才登记。未核能力前不能生成生产描述文件。
2. 新 Bundle ID 切换前必须核对 Sign in with Apple、Associated Domains、Live Activities，以及当前确实使用的其他 Apple 能力。推送能力只有在功能实际启用时才登记。未核能力前不能生成生产描述文件。
3. StoreKit 新商品 ID 是否新建，取决于正式后台是否已有商品、是否存在沙盒交易和是否需要首发保留购买连续性。不能只改本地字符串。
4. 后端数据库名、Keychain、UserDefaults、SwiftData schema 和 StoreKit 账号令牌的迁移要先写兼容测试，再切换新写入。直接批量替换会造成旧安装读不到数据。
5. Apple 组织会籍、App Store Connect App 记录和网站备案均已存在，但这三者不是同一备案或同一商品身份。每个外部系统单独保留回执。

## 十一、需要用户确认的节点

- 主 Bundle ID `com.youbilliards.cuephys` 和模块名 `CuePhys` 已按用户决定作为最终技术命名；App Store Connect 后台切换仍需保留页面结果。
- 确认首发是否创建新的 CuePhys 商品 ID，还是先兼容原有商品并在后台沿用原商品身份。
- Apple Developer 新 App ID 已完成登记；后续若创建密钥或后台切换出现验证码／安全验证，再由用户本人完成该具体操作。
- App Store Connect 公开名、卖方、价格、地区和审核资料在候选包验收后由用户最终确认。

## 十二、版本记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1 | 2026-11-23 | 根据组织迁移完成回执、App Store Connect 实查、CuePhys 代码标识盘点和生产配置现状，重组 Apple 首发任务，明确保留技术标识、改公开名称的边界以及用户操作节点。 |
| v2 | 2026-11-23 | 按用户要求先写方案再执行，补充 CuePhys 四层改名清单、历史证据边界、逐项扫描和候选包验收标准，明确当前未授权发布且代码改动不作为方案完成证据。 |
| v3 | 2026-11-23 | 用户倾向首发前统一全部名称。补充 Bundle ID、Apple 登录、内购、Keychain、后端、微信和 TestFlight 的影响，增加“是否已上传 build”的路线门槛，形成全量标识迁移评估稿。 |
| v3.1 | 2026-11-23 | Edge 实查确认 App Store Connect 尚未上传 build，采用现有 App 记录切换 Bundle ID 的路线。进入 CuePhys 全量标识实施，补充新旧映射和兼容保留边界。 |
| v4 | 2026-11-23 | 用户要求先完善方案再执行。新增 B0-E2 会话批次、真实代码锚点、外部后台门槛、兼容迁移边界和用户本人操作节点。当前不改代码、不登记新 App ID、不提交审核。 |
| v4.1 | 2026-11-23 | 复核 v4 与当前工程实际引用，修正 build 状态、旧商品和旧 Apple Bundle ID 的残留表述，补充 SKU、源码目录、日志 subsystem、脚本 Bundle ID、Apple 能力和描述文件、App 备案联动及切换前禁止上传 build 的门槛。 |
| v4.2 | 2026-11-23 | Edge 实查完成 Apple Developer 新 App ID `com.youbilliards.cuephys` 登记，启用 Associated Domains 与 Sign in with Apple；App Store Connect 读取 SKU `QJ-001`，确认现有 App `6761309682` 仍无 build。将下一步收敛为现有 App 记录切换 Bundle ID，再进入代码改名。 |
| v4.3 | 2026-11-23 | 完成全量覆盖审计，补齐工程目录与 scheme、后端部署和备份命名、通知与 URL scheme、日志与分析、App Store Server Notifications、API／域名边界、官网与商店素材、设备脚本和文档边界；明确当前改名、兼容迁移和历史保留三种处理方式。 |
| v4.4 | 2026-11-23 | 将外部阻塞正式写入方案：区分 API 域名与官网／产品域名，说明 Apple 登录密钥、微信 AppID／AppSecret 的用途和安全边界，明确凭据创建时机，以及正式商品先核对、后配置、早于 TestFlight 和提审的顺序。 |

