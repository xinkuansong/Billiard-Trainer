# CuePhys 全量标识迁移映射

> 建立时间：2026-11-23（北京时间），2026-11-23 追加外部身份实查结果
> 
> 目的：在现有 App Store Connect 记录尚未上传 build 的前提下，把首发候选包的公开品牌和当前构建标识统一为 CuePhys。旧值只在需要兼容本地数据、购买恢复、SwiftData schema 和历史证据的地方保留。具体会话批次以 [Apple组织迁移与首发方案 v4](Apple组织迁移与首发方案_v4.md) 为准。

## 当前冻结值

| 类别 | 新值 | 旧值 | 处理 | 状态 |
|---|---|---|---|---|
| App Store Connect App 记录 | 现有 App `6761309682` | App 名「球迹」 | 保留现有记录，公开名后续改为 CuePhys | 待用户核对后台并提交公开资料 |
| App Store Connect SKU | `QJ-001` | 旧 SKU | 作为固定后台身份保留，不能按品牌批量替换 | 已读取（App Store Connect App 信息页） |
| 主 Bundle ID | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 新建显式 App ID，注册成功后切换现有 App 记录 | 已登记；App Store Connect 记录尚未切换 |
| 主产品名 | `CuePhys` | `球迹` | 作为当前构建产物、系统显示名和商店草稿名 | 代码已有部分显示名，构建标识待改 |
| 主源码目录 | `CuePhys/` | `QiuJi/` | 当前源码、资源、Info.plist 和 entitlements 的路径统一切换，历史 schema 类型名单独保留 | 待执行 |
| Swift 模块 | `CuePhys` | `QiuJi` | 当前主 target、测试导入和测试宿主统一切换 | 待执行 |
| Live Activity Bundle ID | `com.youbilliards.cuephys.liveactivity` | `com.xinkuan.qiuji.liveactivity` | 新建扩展标识并更新 entitlements、描述文件 | 待执行 |
| 单元测试 Bundle ID | `com.youbilliards.cuephys.tests` | `com.xinkuan.qiuji.tests` | 仅测试产物使用新命名 | 待执行 |
| UI 测试 Bundle ID | `com.youbilliards.cuephys.uitests` | `com.xinkuan.qiuji.uitests` | 仅测试产物使用新命名 | 待执行 |
| StoreKit 商品 ID | `com.youbilliards.cuephys.premium.lifetime` 等 | `com.xinkuan.qiuji.premium.*` | 新商品先在本地目录和代码中统一，正式后台商品先核商品状态再创建 | 待执行 |
| Apple 登录受众 | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 服务端 `APPLE_BUNDLE_ID` 与新 App ID 一致 | 待 Bundle ID 切换和服务端联调 |
| Apple 登录密钥 | 组织 Team 下新建 Key ID 与 `.p8` 私钥 | 旧 Team／旧配置 | 只在服务端生成 client secret、交换和撤销 token；私钥不进客户端和仓库 | 待 Bundle ID、HTTPS 和受众冻结 |
| 微信移动应用凭据 | 企业认证后的 AppID，AppSecret 仅服务端保存 | 当前 `YOUR_WECHAT_APP_ID_HERE` 等占位 | AppID 进客户端授权配置，Secret 只进受控服务端；与 Universal Link／AASA 成套验证 | 待企业认证结果和回调域名 |
| 后端数据库 | `cuephys` | `qiuji` | 生产迁移采用别名或迁移脚本，禁止直接改默认值后丢数据 | 待生产迁移方案 |
| 新 Keychain 命名空间 | `CuePhys/Auth/v2` | 既有 QiuJi 键 | 新写入，旧键只读迁移一次 | 待实现 |
| StoreKit 账号令牌命名空间 | `CuePhys/StoreKit/account/v2/` | `CuePhys/StoreKit/account/v1/` | 购买归属兼容读取旧 v1，首发新写 v2 前先确认购买策略 | 待实现 |
| 日志 subsystem | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 当前构建日志切到新 subsystem，历史日志查询保留旧过滤条件 | 待执行 |
| 模拟器与脚本 Bundle ID | `com.youbilliards.cuephys` | `com.xinkuan.qiuji` | 当前 Makefile、设备清单、安装脚本和 UI 巡游统一切换 | 待执行 |
| Apple 能力与描述文件 | 新 App ID 下已启用 Sign in with Apple、Associated Domains；Live Activities 和推送按实际 entitlement 另行核对 | 旧 App ID 能力 | 新 App ID 已登记，描述文件和证书在工程改名后重建，旧描述文件暂留回滚 | App ID 已登记，能力已实查 |
| 工程文件与生成入口 | `CuePhys/`、`CuePhysTests/`、`CuePhysUITests/`、`CuePhysLiveActivity/`、CuePhys scheme 与 target | `QiuJi/`、`QiuJiTests/`、`QiuJiUITests/`、`QiuJiLiveActivity/`、QiuJi scheme 与 target | 当前工程、xcodegen、测试宿主和产物路径统一改名；旧路径只在历史归档保留 | 待 B1/C0 |
| URL scheme 与通知标识 | CuePhys URL scheme、Associated Domains、AASA、`cuephys.training.daily-reminder` 等当前标识 | `qiuji` URL／通知前缀 | 新写入和当前构建使用 CuePhys；旧通知和深链保留兼容迁移窗口 | 已发现旧值，待 B2/E1 |
| 后端部署与备份 | `cuephys-backend`、新数据库别名、头像目录和备份标签 | `/opt/qiuji-backend`、Mongo `qiuji`、旧头像／备份标签 | 用迁移脚本和别名切换；旧密文可回放，注销记录不可丢失 | 待 D0/D2 |
| 日志与分析 | `com.youbilliards.cuephys` subsystem、CuePhys 事件前缀 | `com.xinkuan.qiuji`、`com.billiardtrainer` 和旧事件名 | 当前构建和新事件切换，旧查询映射保留 | 待 E1 |
| App Store Server Notifications | CuePhys 生产／沙盒通知 URL及交易校验标识 | 旧 App 记录通知配置 | 与 StoreKit 商品和服务端交易校验一起切换，不能只改客户端商品 ID | 待 A1/D0 |
| API 与域名职责 | 建议 `api.cuephys.com` 为 App API；`youbilliards.com` 为官网、法律页和备案展示 | 当前 HTTP IP 占位及混用域名 | DNS、HTTPS、CORS、AASA、法律链接分别核验；若 API 使用中国大陆服务器，单独核验 `cuephys.com` 的备案接入 | 待 A3/D1 |
| 公开商店与官网素材 | CuePhys 名称、截图、预览、审核备注、支持邮箱、法律页和商标使用说明 | 球迹公开文案及历史素材 | 当前发布资料全部统一，历史证据保留 | 待 E0/E2 |
| SwiftData schema 类型名 | 保持现有 `QiuJiSchemaV*` | 同左 | 这是持久化迁移锚点，不随品牌批量改名 | 保留 |
| 历史研究、报告、截图 | 原路径和原值 | 同左 | 作为证据保留，不纳入当前构建扫描 | 保留 |

## 实施顺序

1. Apple Developer 新 App ID 已登记并记录能力开关；旧 App ID 不删除。下一步在 App Store Connect 现有 App `6761309682` 内切换 Bundle ID。
2. Bundle ID 切换完成后，改 `project.yml`、xcodeproj、scheme、当前 target、Bundle ID、产品名、模块名和测试宿主。
3. 由 xcodegen 生成工程，检查主 App、Live Activity、单测和 UI 测试的 Bundle ID、产物名、URL scheme 和 entitlement。
4. 改 StoreKit 本地目录、代码商品常量、正式商品映射、App Store Server Notifications 和测试夹具，增加旧商品读取兼容，避免恢复购买回退。
5. 改 Apple 服务端受众、生产环境模板和配置自检。Apple App ID 切换前保留旧测试配置，切换后统一使用新受众。真实私钥不进入仓库。
6. 改 Keychain、UserDefaults、通知标识和账号令牌的迁移读写，先验证旧数据，再切新写入。
7. 改后端包名、systemd／服务器路径、数据库别名、头像目录、备份与恢复脚本、日志 subsystem 和分析事件；保留旧密文和历史查询映射。
8. 改当前脚本、测试、截图巡游、官网／法律页和商店资料中的公开名称与产物路径。历史报告与研究目录单独标记，不批量重写。
9. Apple Developer 能力和 App Store Connect Bundle ID 切换完成后，再生成候选包。构建、单测、UI 定向测试、登录／购买／恢复／注销和签名检查通过后，才允许上传 build。

## 不允许直接批量替换的项目

- `QiuJiSchemaV1` 至 `QiuJiSchemaV6` 以及迁移计划类型
- 已有 StoreKit 交易恢复所需的旧商品 ID
- 旧 Keychain 和 UserDefaults 的读取键
- 旧数据库、训练记录和注销备份的历史字段
- 历史证据、失败记录、研究报告和已发布包的校验值

## 验收门槛

- 新构建的 Bundle ID、模块名、扩展 Bundle ID 和测试宿主全部为 CuePhys 命名。
- Apple Developer 的新 App ID、能力开关、证书和描述文件均能对应新 Bundle ID。
- App Store Connect 现有 App 记录仍可关联新 Bundle ID，且没有创建重复 App 记录。
- 游客本机训练、Apple 登录、微信登录、账号绑定、注销、训练记录同步、永久会员购买和恢复购买分别有结果。
- 旧安装数据和旧购买凭据经过迁移验证后仍能得到预期状态。
- 生产服务器的 Apple `aud`、API HTTPS、Universal Links 和 StoreKit 商品配置一致。

