# CuePhys Apple 组织迁移与首发方案

> 本文件是本轮 Apple 事项的需求真源。版本 v2，2026-11-23（北京时间）建立。它把 Apple 个人会籍转组织后的商店、品牌改名、合规、登录、内购和首发工作拆成可独立执行的会话批次。外部后台状态以实际页面和回执为准，代码状态以本文件列出的仓库锚点为准。当前处于方案确认阶段，未以本文件作为提交审核或发布授权。

## 一、当前已确认

| 对象 | 已确认结果 | 证据与边界 |
|---|---|---|
| Apple 会员主体 | 已转为组织 `Wuxi Youqiu Technology Co., Ltd`，Team ID `KWH2GRNSKG`，续订日 2027-03-28，页面显示年费 RMB 688 | Apple Developer 账户页与 11/23 邮件。迁移期间出现的停用提示已结束。 |
| App Store Connect App | 现有 App「球迹」，App ID `6761309682`，iOS 1.0 为「准备提交」 | 11/23 Edge 实查。不能新建第二个 App 来代替现有记录，除非另有明确产品决定。 |
| 产品公开名 | 产品决定为 CuePhys，说明性标题可用「CuePhys：台球训练」 | 需要在 App Store Connect 核公开名称、卖方和商店文案，尚未提交审核。代码侧改名只在方案确认后执行。 |
| App 内显示名 | `CFBundleName` 与 `CFBundleDisplayName` 已为 `CuePhys` | `QiuJi/Resources/Info.plist:5-20`。这是客户端显示名。 |
| 既有技术标识 | `com.xinkuan.qiuji` Bundle ID、StoreKit 商品 ID、Swift 模块 `QiuJi`、后端默认数据库名和钥匙串键继续保留 | 这些标识关系到现有 App、内购、测试宿主和本地数据连续性。首发不因改品牌而直接改名。 |
| Apple 登录客户端 | Apple 授权请求、回调、绑定和注销链路已实现，正式请求要求安全 API 地址 | `QiuJi/Data/Services/AuthService.swift:45-155`，`QiuJi/Core/Extensions/AppConfig.swift:4-39`。 |
| Apple 登录服务端 | 使用 Bundle ID 校验 `aud`，授权码换取 Apple refresh token，并加密保存后支持撤销 | `backend/src/config/index.js:26-45`，`backend/src/services/appleGrant.js:9-62`，`backend/src/routes/auth.js:17-139`。 |
| 生产配置 | Release 仅接受 `https://cuephys.com` 或其子域名。当前私有配置仍是 HTTP IP 占位，不能进行正式登录联调 | `Config/Secrets.xcconfig:4-7`，`QiuJi/Core/Extensions/AppConfig.swift:16-32`。 |
| 中国大陆商店合规 | App Store Connect 页面提示需要安全评估证明和 AIGC 服务声明 | 11/23 App Store Connect 页面提示。按实际功能和主管部门要求填，不凭猜测选择不适用。 |
| 网站 | `https://youbilliards.com/` 已上线，网站服务备案号为 `苏ICP备2026091631号-1` | 网站备案不能替代 App 备案。App 备案仍单独跟踪。 |
| 微信 | 企业认证已付款，移动应用正式 AppID、Universal Links 和回调实测仍未闭合 | `Config/Debug.xcconfig:14-16` 仍是占位。 |

## 二、已经拍板的产品与账号规则

1. 正式产品名使用 CuePhys，商店显示名、客户端公开文案、法律页面和备案材料保持一致。
2. 保留现有 App Store Connect App 记录、App ID、Bundle ID 和既有 StoreKit 商品标识，避免破坏已建商品和历史安装连续性。
3. 首发登录包含 Apple 和微信。两种登录身份可以绑定同一个 CuePhys 账号。
4. 如果两个独立登录身份已经各有训练记录，首发保留两个账号及各自记录，提示用户走原账号或绑定路径，不自动合并训练数据。
5. 首发只销售一次性永久会员。月付和年付不进入首发商品选择，商品价格以 App Store Connect 当前中国区后台为准，历史代码商品 ID 不变。
6. 游客仍可进行本机基础训练。账号、同步和购买需要真实 HTTPS 服务与年龄声明链路。

## 三、批次表

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

## 四、依赖图

```text
A0 身份与命名冻结
 ├──> A1 商务协议与商品 ──┐
 ├──> A2 中国大陆合规 ────┼──> A6 CuePhys 候选包 ──> A7 真机与 TestFlight ──> A8 提审发布
 └──> A3 HTTPS 与法律页 ──┘
          ├──> A4 Apple 登录密钥 ──┘
          └──> A5 微信登录 ───────┘
```

## 五、各批次执行细则

### A0 身份与命名冻结

- 在 App Store Connect 继续使用 App ID `6761309682`。核 App 信息页的公开名称、卖方、Bundle ID 和当前版本，不新建第二条产品记录。
- 把公开名称改为 CuePhys 的动作留在用户确认后执行。公开名称会影响商店展示，不能由代码改名替代。
- 改名清单分四层执行。第一层是用户可见文案，包括 App Store Connect 名称、App 内标题、关于页、登录页、会员页、Pro 权益、帮助页、通知、Live Activity、权限说明、客服和法律页。第二层是发布产物，包括 `CFBundleDisplayName`、`CFBundleName`、`PRODUCT_NAME`、测试宿主、scheme、扩展显示名、截图和 TestFlight 名称。第三层是活动脚本和验收脚本中的产物路径、测试按钮文案和构建参数。第四层是外部资料，包括网站、备案材料、微信开放平台移动应用资料、Apple 审核备注和商标使用说明。
- 技术连续性清单固定不改。`com.xinkuan.qiuji` Bundle ID、`com.xinkuan.qiuji.premium.lifetime` 商品 ID、Swift 模块 `QiuJi`、后端数据库名、钥匙串键、API 路径和历史数据字段继续保留。它们不属于公开品牌名。
- 历史研究脚本、历史截图、归档日志中出现的旧产物路径只作为证据保留。执行脚本和当前候选包检查不能继续引用旧产物路径，改名批次要把两类逐项分开登记。
- 当前只完成了方案盘点。代码侧和 App Store Connect 公开名的改动均不以未验收工作区状态作为完成依据。
- `com.xinkuan.qiuji`、`com.xinkuan.qiuji.premium.lifetime` 和后端 `APPLE_BUNDLE_ID` 继续保持一致。它们是连续性标识，不是公开品牌名。

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

## 六、需要用户本人操作的节点

1. App Store Connect「商务」页若有待接受的付费应用协议，由用户本人阅读并接受。
2. 在 App Store Connect 确认公开名称改为 CuePhys，并核对卖方、价格和销售范围。
3. 在组织 Team 下创建 Apple 登录密钥，并把 Key ID、私钥文件通过受控方式放到服务器配置位置，不在聊天中发送私钥内容。
4. 对安全评估证明和 AIGC 服务声明的实际选项作最终确认。需要上传的官方文件由用户提供或按官方流程取得。
5. TestFlight 和审核提交前，用户确认最终公开名称、价格、地区和发布时点。

## 七、当前最先做什么

1. 先确认本方案的改名边界和清单，当前不提交审核、不改 App Store Connect 公开资料。
2. 用户在 App Store Connect「商务」查看付费应用协议并处理待签事项。
3. 由我按四层改名清单核对源码、资源、脚本、测试、商店文案和网站发布清单，输出逐项变更表。
4. 你确认变更表后，再执行代码侧改名和候选包验证，不改变 Bundle ID、商品 ID 或账号数据格式。
5. 服务器 HTTPS 主机确定后，再创建 Apple 登录密钥并做真实登录联调。微信认证完成后接入第二条真实登录链路。

## 八、版本记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1 | 2026-11-23 | 根据组织迁移完成回执、App Store Connect 实查、CuePhys 代码标识盘点和生产配置现状，重组 Apple 首发任务，明确保留技术标识、改公开名称的边界以及用户操作节点。 |
| v2 | 2026-11-23 | 按用户要求先写方案再执行，补充 CuePhys 四层改名清单、历史证据边界、逐项扫描和候选包验收标准，明确当前未授权发布且代码改动不作为方案完成证据。 |

