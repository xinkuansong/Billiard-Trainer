# CuePhys Apple 组织迁移与首发方案

> 本文件是本轮 Apple 事项的需求真源。版本 v3，2026-11-23（北京时间）建立。它在 v2 的基础上评估“CuePhys 全量标识迁移”方案。外部后台状态以实际页面和回执为准，代码状态以本文件列出的仓库锚点为准。当前处于方案和映射确认阶段，尚未执行代码改名，也未授权提交审核或发布。

## 一、当前已确认

| 对象 | 已确认结果 | 证据与边界 |
|---|---|---|
| Apple 会员主体 | 已转为组织 `Wuxi Youqiu Technology Co., Ltd`，Team ID `KWH2GRNSKG`，续订日 2027-03-28，页面显示年费 RMB 688 | Apple Developer 账户页与 11/23 邮件。迁移期间出现的停用提示已结束。 |
| App Store Connect App | 现有 App「球迹」，App ID `6761309682`，iOS 1.0 为「准备提交」，版本页尚未上传 build | 11/23 Edge 实查。页面仍显示“从多种工具中选取一种来上传你的构建版本”。按 Apple 规则，当前可优先在现有 App 记录内切换 Bundle ID。 |
| 产品公开名 | 产品决定为 CuePhys，说明性标题可用「CuePhys：台球训练」 | 需要在 App Store Connect 核公开名称、卖方和商店文案，尚未提交审核。代码侧改名只在方案确认后执行。 |
| App 内显示名 | `CFBundleName` 与 `CFBundleDisplayName` 已为 `CuePhys` | `QiuJi/Resources/Info.plist:5-20`。这是客户端显示名。 |
| 既有技术标识 | 将按新旧映射分批切换，持久化和购买兼容键在迁移窗口保留 | 主 Bundle ID、Swift 模块、StoreKit 新商品 ID、测试宿主、后端配置和当前构建入口统一改为 CuePhys。SwiftData schema 名称、旧商品 ID、旧账号令牌命名空间和历史数据库名作为兼容读取或回滚锚点保留，不做无证据的删除。 |
| Apple 登录客户端 | Apple 授权请求、回调、绑定和注销链路已实现，正式请求要求安全 API 地址 | `QiuJi/Data/Services/AuthService.swift:45-155`，`QiuJi/Core/Extensions/AppConfig.swift:4-39`。 |
| Apple 登录服务端 | 使用 Bundle ID 校验 `aud`，授权码换取 Apple refresh token，并加密保存后支持撤销 | `backend/src/config/index.js:26-45`，`backend/src/services/appleGrant.js:9-62`，`backend/src/routes/auth.js:17-139`。 |
| 生产配置 | Release 仅接受 `https://cuephys.com` 或其子域名。当前私有配置仍是 HTTP IP 占位，不能进行正式登录联调 | `Config/Secrets.xcconfig:4-7`，`QiuJi/Core/Extensions/AppConfig.swift:16-32`。 |
| 中国大陆商店合规 | App Store Connect 页面提示需要安全评估证明和 AIGC 服务声明 | 11/23 App Store Connect 页面提示。按实际功能和主管部门要求填，不凭猜测选择不适用。 |
| 网站 | `https://youbilliards.com/` 已上线，网站服务备案号为 `苏ICP备2026091631号-1` | 网站备案不能替代 App 备案。App 备案仍单独跟踪。 |
| 微信 | 企业认证已付款，移动应用正式 AppID、Universal Links 和回调实测仍未闭合 | `Config/Debug.xcconfig:14-16` 仍是占位。 |

## 二、全量标识迁移的可行性与风险

用户倾向在首发前把公开品牌和技术标识全部统一为 CuePhys。这个方向可以做，但需要先通过一个 Apple 后台门槛，再按新 App 标识迁移处理。

### 1. 先核实现有 App 是否已经上传过 build

- Apple 文档说明，现有 App 记录如果还没有上传 build，可以在 App Store Connect 中改选新的 Bundle ID。
- 一旦已有 build 上传，Bundle ID 就不能在该 App 记录中修改，需要创建新的 App 记录。
- 当前页面显示 iOS 1.0「准备提交」，尚未在本轮核到“是否已上传 build”的明确证据。这个状态必须在 App Store Connect 的版本页确认后再决定路线。

### 2. 全量改名会遇到的问题

| 风险项 | 影响 | 处理要求 |
|---|---|---|
| Bundle ID 与 App ID | 新 Bundle ID 会改变 Apple 对应用的唯一身份。已有 build 时需要新 App 记录，旧记录不能直接变成同一个应用。 | 先核 build 状态。若需要新记录，旧「球迹」记录保留归档，不删除、不提交。 |
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
2. 在 Apple Developer 中登记新的显式 App ID，并在现有 App 记录中改选该 Bundle ID。新标识暂拟 `com.youbilliards.cuephys`，已打开登记入口，当前页面仍在加载，登记结果待回填。
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
5. 首发只销售一次性永久会员。月付和年付不进入首发商品选择，商品价格以 App Store Connect 当前中国区后台为准，历史代码商品 ID 不变。
6. 游客仍可进行本机基础训练。账号、同步和购买需要真实 HTTPS 服务与年龄声明链路。

## 四、批次表

| 批次 | 范围 | 量级 | 依赖 | 一次会话完成标准 |
|---|---|---:|---|---|
| A0 身份与命名冻结 | 核组织卖方、App ID、Bundle ID、公开名 CuePhys、App 内显示名和技术旧标识边界 | S | 已完成迁移 | 台账记录组织 Team、App ID、卖方和名称决策。确认 App Store Connect 公开名称改为 CuePhys，并冻结改名清单。 |
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

- 在 App Store Connect 核 App ID `6761309682` 的版本页是否已经上传 build。未上传时优先在原记录内切换 Bundle ID，已上传时建立 CuePhys 新记录。确认前不新建、删除或提交任何记录。
- 把公开名称改为 CuePhys 的动作留在用户确认后执行。公开名称会影响商店展示，不能由代码改名替代。
- 改名清单分四层执行。第一层是用户可见文案，包括 App Store Connect 名称、App 内标题、关于页、登录页、会员页、Pro 权益、帮助页、通知、Live Activity、权限说明、客服和法律页。第二层是发布产物，包括 `CFBundleDisplayName`、`CFBundleName`、`PRODUCT_NAME`、测试宿主、scheme、扩展显示名、截图和 TestFlight 名称。第三层是活动脚本和验收脚本中的产物路径、测试按钮文案和构建参数。第四层是外部资料，包括网站、备案材料、微信开放平台移动应用资料、Apple 审核备注和商标使用说明。
- 全量路线建立新旧标识映射和迁移窗口后切换。`com.xinkuan.qiuji`、现有商品 ID、Swift 模块 `QiuJi`、后端数据库名、钥匙串键、API 路径和历史数据字段逐项处理，只有需要连续性的持久化标识保留兼容读取。
- 历史研究脚本、历史截图、归档日志中出现的旧产物路径只作为证据保留。执行脚本和当前候选包检查不能继续引用旧产物路径，改名批次要把两类逐项分开登记。
- 当前只完成了方案盘点。代码侧和 App Store Connect 公开名的改动均不以未验收工作区状态作为完成依据。
- 新构建采用 `com.youbilliards.cuephys`、`CuePhys` 模块和 CuePhys 商品 ID。旧商品、旧 Bundle ID、旧钥匙串命名空间和历史 schema 只在兼容迁移代码中保留，并在候选包完成恢复购买与旧数据验证后再决定是否下线。

### A1 商务协议与商品

- 由账号持有人打开 App Store Connect「商务」，查看是否有待接受的付费应用协议。涉及法律接受的按钮由用户本人操作。
- 核永久会员 `com.xinkuan.qiuji.premium.lifetime` 的商品类型为非消耗型，代码加载和购买只接受该商品，见 `QiuJi/Data/Services/StoreKitService.swift:52-83`。
- 核后台商品的中国区价格、可售状态、税务和银行状态。代码中的 `Products.storekit` 只能作为本地测试配置，不能证明正式价格或正式可售。
- 核恢复购买和账号归属。`SubscriptionManager.swift:324-349` 已按 CuePhys 账号的稳定 `appAccountToken` 区分购买归属，另一个账号的永久会员会提示按购买账号恢复。

### A2 中国大陆合规

- 网站备案号 `苏ICP备2026091631号-1` 只用于网站。App 备案单独办理，并在 App Store Connect 的 App 信息里按实际回执填写。
- 对安全评估证明和 AIGC 服务声明分别建状态。先核 App 是否使用生成式内容、智能生成文案、生成图片或外部生成式服务，再按真实情况准备声明和证明。
- 隐私标签按真实字段和接收方填写，至少覆盖 Apple 登录身份凭据、微信授权码、账号资料、头像、生日或年龄段、训练记录、购买信息和注销记录。
- 审核备注必须给出游客路径、Apple 登录路径、永久会员入口、恢复购买和注销路径。审核访问不得依赖个人 Apple 账号。

### A3 生产 HTTPS 与法律页

- Release 配置必须把 `API_BASE_URL` 换成 CuePhys 域名下的 HTTPS 地址。当前 `Config/Secrets.xcconfig:4` 仍是 `http://106.54.3.210:3000` 占位，正式包会因 `AppConfig.validatedAPIBaseURL(..., release: true)` 拒绝该值。
- 服务器端保留 `APPLE_BUNDLE_ID=com.xinkuan.qiuji`，并用独立随机的 `JWT_SECRET`、`JWT_REFRESH_SECRET` 和 64 位十六进制 `APPLE_TOKEN_ENCRYPTION_KEY`。
- 法律页使用已上线网站的 HTTPS 路径，并在匿名设备上逐个打开。未发布或占位 URL 继续保持空值，避免把错误链接打进候选包。

### A4 Apple 登录密钥

- 组织 Team 下创建密钥时记录 Key ID 和创建时间，私钥只下载一次并放在受控密钥目录。不要把 `.p8`、服务器 `.env` 或完整 JWT 放进仓库、聊天或截图。
- 服务端现有 `appleGrant.js:31-49` 使用 Team ID、Key ID、私钥路径生成 client secret，并向 Apple 换取 token。部署前先做配置自检，再用一次性授权码做真实交换。
- 测试顺序固定为首次授权、再次授权、取消、网络失败重试、隐藏邮箱、退出重登、账号绑定、注销后旧令牌拒绝和 Apple 授权撤销。每次只记录脱敏账号别名和 HTTP 结果。

### A5 微信登录

- 等企业认证结果和移动应用 AppID 到位后，再把 `WECHAT_APP_ID`、`WECHAT_UNIVERSAL_LINK` 和 `WECHAT_LINK_HOST` 写入 Release 私有配置。当前 `Config/Debug.xcconfig:14-16` 是占位，不能拿来做正式登录。
- Universal Links 必须和 AASA、服务器 HTTPS、微信开放平台配置中的域名完全一致。微信登录回调成功后仍由服务端唯一索引和绑定接口决定账号归属，不以昵称、头像或邮箱自动合并。

### A6-A8 候选包、验收和提交

- 先生成一个改名候选包，检查桌面图标、系统设置、关于页、登录页、会员页、Pro 权益、帮助页、通知、Live Activity、扩展、系统权限提示和 TestFlight 显示名。
- 用 `rg` 对源码、资源、脚本、测试、App Store 文案草稿和网站发布清单做一次旧品牌扫描。每个命中项标记为公开文案、当前构建路径、技术连续性标识或历史证据，并在验收记录中说明处理结果。
- 运行 `verify-gate`、受影响的 StoreKit、登录、账号绑定、注销、同步和 App Store UI 测试。测试结果必须同时写明模拟器、真机、版本和 build。
- 上传后等待 App Store Connect 处理完成，再在 TestFlight 安装同一 build。用户验收通过后才提交审核。

## 七、需要用户本人操作的节点

1. App Store Connect「商务」页若有待接受的付费应用协议，由用户本人阅读并接受。
2. 在 App Store Connect 确认公开名称改为 CuePhys，并核对卖方、价格和销售范围。
3. 在组织 Team 下创建 Apple 登录密钥，并把 Key ID、私钥文件通过受控方式放到服务器配置位置，不在聊天中发送私钥内容。
4. 对安全评估证明和 AIGC 服务声明的实际选项作最终确认。需要上传的官方文件由用户提供或按官方流程取得。
5. TestFlight 和审核提交前，用户确认最终公开名称、价格、地区和发布时点。

## 八、当前最先做什么

1. 已确认现有版本页没有 build，先完成改名清单和新旧标识映射，当前不提交审核、不改 App Store Connect 公开资料。
2. 用户在 App Store Connect「商务」查看付费应用协议并处理待签事项。
3. 由我按四层改名清单核对源码、资源、脚本、测试、商店文案和网站发布清单，输出逐项变更表。
4. 你确认变更表后，再执行代码侧改名和候选包验证。持久化兼容键和历史证据保留到迁移验收结束。
5. 服务器 HTTPS 主机确定后，再创建 Apple 登录密钥并做真实登录联调。微信认证完成后接入第二条真实登录链路。

## 九、版本记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1 | 2026-11-23 | 根据组织迁移完成回执、App Store Connect 实查、CuePhys 代码标识盘点和生产配置现状，重组 Apple 首发任务，明确保留技术标识、改公开名称的边界以及用户操作节点。 |
| v2 | 2026-11-23 | 按用户要求先写方案再执行，补充 CuePhys 四层改名清单、历史证据边界、逐项扫描和候选包验收标准，明确当前未授权发布且代码改动不作为方案完成证据。 |
| v3 | 2026-11-23 | 用户倾向首发前统一全部名称。补充 Bundle ID、Apple 登录、内购、Keychain、后端、微信和 TestFlight 的影响，增加“是否已上传 build”的路线门槛，形成全量标识迁移评估稿。 |
| v3.1 | 2026-11-23 | Edge 实查确认 App Store Connect 尚未上传 build，采用现有 App 记录切换 Bundle ID 的路线。进入 CuePhys 全量标识实施，补充新旧映射和兼容保留边界。 |

