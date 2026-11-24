# CuePhys 全量标识迁移映射

> 2026-11-24 更新：改名整改以 [方案 v1.3](CuePhys改名完整整改方案_v1.md) 与 [执行入口](cuephys-rename/CURRENT.md) 为准。用户确认尚未上线，取消复杂历史用户数据迁移。下方历史执行记录按原时间保留，不作为当前阻塞；不得再按旧记录重做已完成的 ASC 切换。

> 建立时间：2026-11-23（北京时间），2026-11-23 追加外部身份实查结果
> 
> 目的：在现有 App Store Connect 记录尚未上传 build 的前提下，把首发候选包的公开品牌和当前构建标识统一为 CuePhys。旧值只在稳定 schema、已有读取边界和历史证据处保留；首发不开发跨旧 App 数据迁移。具体会话批次以 [Apple组织迁移与首发方案 v4](Apple组织迁移与首发方案_v4.md) 为准。

## 当前冻结值

| 类别 | 新值 | 旧值 | 处理 | 状态 |
|---|---|---|---|---|
| App Store Connect App 记录 | 现有 App `6761309682` | App 名「球迹」 | 保留现有记录，公开名后续改为 CuePhys | 待用户核对后台并提交公开资料 |
| App Store Connect SKU | `QJ-001` | 旧 SKU | 作为固定后台身份保留，不能按品牌批量替换 | 已读取（App Store Connect App 信息页） |
| 主 Bundle ID | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 当前主 App 身份 | ASC 已切换并保存，见首发方案 v4 最新回执；当前新Release签名身份已核；真实业务与商店分发待验 |
| 主产品名 | `CuePhys` | `球迹` | 当前构建产物和显示名 | 当前Release显示名/产物名已核；最终商店包待外部条件 |
| 主源码目录 | `CuePhys/` | `QiuJi/` | 当前源码、资源、Info.plist 和 entitlements 的路径统一切换，历史 schema 类型名单独保留 | 已完成 |
| Swift 模块 | `CuePhys` | `QiuJi` | 当前主 target、测试导入和测试宿主统一切换 | 已完成 |
| Live Activity Bundle ID | `com.youbilliards.cuephys.liveactivity` | `com.xinkuan.qiuji.liveactivity` | 新建扩展标识并更新 entitlements、描述文件 | 当前Release签名Team+Bundle及有效profile已核；真机系统交互待验 |
| 单元测试 Bundle ID | `com.youbilliards.cuephys.tests` | `com.xinkuan.qiuji.tests` | 仅测试产物使用新命名 | 已完成 |
| UI 测试 Bundle ID | `com.youbilliards.cuephys.uitests` | `com.xinkuan.qiuji.uitests` | 仅测试产物使用新命名 | 已完成 |
| StoreKit 商品 ID | `com.youbilliards.cuephys.premium.lifetime` 等 | `com.xinkuan.qiuji.premium.*` | 新商品先在本地目录和代码中统一，正式后台商品先核商品状态再创建 | 本地已完成，正式后台待配置 |
| Apple 登录受众 | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 服务端 `APPLE_BUNDLE_ID` 与新 App ID 一致 | Bundle 已切换；本地严格启动预检/受控联调通过，真实生产授权待验 |
| Apple 登录密钥 | 组织 Team 下新建 Key ID 与 `.p8` 私钥 | 旧 Team／旧配置 | 只在服务端生成 client secret、交换和撤销 token；私钥不进客户端和仓库 | 身份已冻结；真实组织私钥/服务端配置待齐备 |
| 微信移动应用凭据 | 企业认证后的 AppID，AppSecret 仅服务端保存 | 当前 `YOUR_WECHAT_APP_ID_HERE` 等占位 | AppID 进客户端授权配置，Secret 只进受控服务端；与 Universal Link／AASA 成套验证 | AASA/Apple CDN 已核一致；审核与真实凭据/真机回跳待验 |
| 后端数据库 | `qiuji`（内部稳定名） | `qiuji` | 保持现有数据库，不为品牌重建/改名 | 无数据库迁移任务；隔离当前读写、真实备份恢复与注销重放已验，未触碰生产库 |
| 新 Keychain 命名空间 | `com.youbilliards.cuephys.*` | `com.qiuji.app.*` | 当前新写入；已有旧键回退只在当前可访问范围生效 | 不开发跨 App 访问组迁移，不声称一次性搬迁已完成 |
| StoreKit 账号令牌命名空间 | `CuePhys/StoreKit/account/v1/` | 同左 | 保持当前稳定算法 | v2 提议撤销；当前商品本地 StoreKit 流程已验，正式沙盒待验 |
| 日志 subsystem | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 当前构建日志切到新 subsystem，历史日志查询保留旧过滤条件 | 已完成 |
| 模拟器与脚本 Bundle ID | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 当前 Makefile、设备清单、安装脚本和 UI 巡游统一切换 | 当前门禁脚本已完成，历史脚本保留 |
| Apple 能力与描述文件 | 新 App ID 下已启用 Sign in with Apple、Associated Domains；Live Activities 和推送按实际 entitlement 另行核对 | 旧 App ID 能力 | 新 App ID 已登记，描述文件和证书在工程改名后重建，旧描述文件暂留回滚 | App ID 已登记，能力已实查 |
| 工程文件与生成入口 | `CuePhys/`、`CuePhysTests/`、`CuePhysUITests/`、`CuePhysLiveActivity/`、CuePhys scheme 与 target | `QiuJi/`、`QiuJiTests/`、`QiuJiUITests/`、`QiuJiLiveActivity/`、QiuJi scheme 与 target | 当前工程、xcodegen、测试宿主和产物路径统一改名；旧路径只在历史归档保留 | 已完成 |
| URL scheme 与通知标识 | 已获批微信AppID对应的wx scheme、官网AASA微信路径、`cuephys.training.daily-reminder` | 旧通知前缀 | 当前App仅接微信URL回调；提醒独立路由；不虚构通用深链或跨App迁移 | 当前接线已核；真实微信配置/回跳和真机通知仍待验 |
| 后端部署与备份 | 保留现有部署根、头像根和备份标识 | `/opt/qiuji-backend`、Mongo `qiuji` | 内部名不为品牌修改 | 隔离环境真实备份恢复已通过，不新增改名迁移 |
| 日志与分析 | `com.youbilliards.cuephys` subsystem、CuePhys 事件前缀 | `com.xinkuan.qiuji`、`com.billiardtrainer` 和旧事件名 | 当前编译代码和新事件切换，旧查询映射保留 | 当前代码已完成；历史查询映射仍保留 |
| App Store Server Notifications | 当前未实现通知端点 | 旧计划中的通知配置提议 | 首发沿用客户端已验证StoreKit权益、交易更新、启动/前台刷新与账号归属；本轮不新增服务端支付系统 | D04/I22已明确；本地46/46，正式沙盒/退款/换设备仍待验 |
| API 与域名职责 | `api.cuephys.com` 为 App API；`youbilliards.com` 为官网/法律/支持及微信回调 | 历史 IP 占位 | 沿当前域名分工 | 2026-11-24 HTTPS健康、法律页、AASA源站与Apple CDN均已重验；真实授权另列 |
| 公开商店与官网素材 | CuePhys 名称、截图、预览、审核备注、支持邮箱、法律页和商标使用说明 | 球迹公开文案及历史素材 | 当前发布资料全部统一，历史证据保留 | 待 E0/E2 |
| SwiftData schema 类型名 | 保持现有 `QiuJiSchemaV*` | 同左 | 这是持久化迁移锚点，不随品牌批量改名 | 保留 |
| 历史研究、报告、截图 | 原路径和原值 | 同左 | 作为证据保留，不纳入当前构建扫描 | 保留 |

## 当前执行与验收

唯一执行顺序、逐批证据与未完成项见 [EXECUTION](cuephys-rename/EXECUTION.md)，不再按 11 月 23 日旧顺序重复切换 ASC 或开发旧数据迁移。

- App、扩展、测试与导入工具均按当前 CuePhys 路径验证；模型必须是完整 USDZ，不能是 Git LFS 指针。
- 当前游客存储/重启、账号 owner 隔离与同步恢复需有真实执行结果；不迁移旧安装、不重建数据库、不清理用户资料。
- schema 类型、内部字体名、共享模拟器租约根、稳定交易令牌和历史证据保留。
- 新签名候选必须通过身份、URL、资源及配置门禁；外部真实登录、购买、恢复与注销另附实证。
- 生产数据库、systemd 路径和加密密钥不为品牌重命名。本轮后端配置预检不等于已部署。

## 本轮执行记录（2026-11-23）

- **分支**：`codex/cuephys-full-rename`，用于把代码侧全量改名与外部 Apple 后台切换隔离审阅。
- **已完成**：`CuePhys/`、`CuePhysTests/`、`CuePhysUITests/`、`CuePhysLiveActivity/`、`CuePhys.xcodeproj` 与当前 target/scheme 生成入口；主 App、扩展、单测和 UI 测试 Bundle ID 均使用 `com.youbilliards.cuephys…` 命名空间。
- **已完成**：本地商品、日志 subsystem、当前模拟器/题库校验脚本使用 CuePhys；旧 StoreKit 商品 ID 只保留读取兼容，SwiftData 历史 schema 和历史研究路径不改。 当前台球几何工厂函数与训练提醒写入前缀也已切到 CuePhys，通知点击与清理保留旧前缀兼容。
- **已完成**：Keychain 新写入使用 CuePhys 命名空间，读取和清理兼容旧 `com.qiuji.app.*` 键，避免升级安装丢失会话；后端 npm 包元数据和当前并发队列标签已切到 CuePhys，生产目录与数据库名保留迁移别名。
- **验证**：`xcodegen generate`、生产资源校验、题库校验、Debug 模拟器构建及 `build-for-testing` 均通过。
- **阻塞**：App Store Connect 现有 App `6761309682` 的 Bundle ID 外部切换尚未完成；已用连接的 iPhone 16 Pro 真机构建、安装并启动新包，签发开发 profile `com.youbilliards.cuephys`，但新旧页面会话读取“套装 ID”下拉，唯一选项仍为旧值 `QiuJi App - com.xinkuan.qiuji`。本轮未点击保存、未上传 build、未创建生产 Apple 登录密钥、未创建/启用正式商品。
- **待下一批**：空闲模拟器租约释放后运行受影响 XCTest/UI 测试；完成 ASC Bundle ID 切换后核对 entitlements、服务端 `APPLE_BUNDLE_ID`、HTTPS 与 Apple 登录密钥，再生成候选包。

### 真机验证补充

- 连接的 iPhone 16 Pro 已完成 `com.youbilliards.cuephys` 安装与启动；定向真机 XCTest `APIClientProfileTests/testReleaseAPIConfigurationOnlyAllowsCompanyHTTPS` 通过（1/1，0 failures）。
- 该结果收口了本地真机配置门禁，不替代 ASC Bundle ID 切换、生产 Apple 登录联调、微信登录联调或候选包上传。

### ASC 与归档补充

- 用户截图确认 ASC Bundle ID 菜单已出现 `CuePhys - com.youbilliards.cuephys`；选择并保存后才算外部切换完成，旧值和下方实验 Bundle ID 不选。
- 使用临时校验地址 `https://validation.cuephys.com/api` 完成未签名 Release 归档，`xcodebuild` 成功；归档包 Bundle ID 与显示名分别为 `com.youbilliards.cuephys` 和 `CuePhys`。未上传 build，生产归档等待实际 API HTTPS、法律 URL 和正式凭据。
