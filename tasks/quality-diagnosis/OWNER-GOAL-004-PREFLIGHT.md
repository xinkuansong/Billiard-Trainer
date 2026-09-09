# SC14 owner weekly goal 有界补验草稿

状态：仅准备；`swiftc -frontend -parse` 通过不等于类型检查、注册、运行或产品通过。本次仅新增本说明及 [OwnerGoalBoundaryDiagnosticTests.swift](OwnerGoalBoundaryDiagnosticTests.swift)。主控串行审核执行，不修改业务。

## 精确范围与选择器

`QiuJiTests/OwnerGoalBoundaryDiagnosticTests/testWeeklyGoalsRemainOwnerScopedAcrossSaveSwitchAndStoreRecreation`

一个 hosted async 方法，真实 `OwnerProfileStore` / `AuthState` / `CurrentOwnerContext`，独立 UUID UserDefaults，注入 actor 资料/鉴权 backend 与无凭据实现。无 SwiftData 实体操作，不需要另建无用 ModelContainer；宿主必须在 App 初始化前使用内存 schema。游客正常保存 2；A 请求 4、受控服务端返回 5，断言 Store/Auth/本地键均接受 5；B 保存 6。随后 A→guest→B 正常身份切换，每次新建 Store，先验缓存读回，再 load 对应已提交的服务端资料/游客资料并验不变；重建 CurrentOwnerContext 保持同一游客键。B 的 0、8 各一次必须不改值、不发请求。不扩账号失败、提醒调度或冷进程 UI 矩阵。

原规格与可复用证据：

- [PREFERENCE-REMINDER-004-ORACLE.md](PREFERENCE-REMINDER-004-ORACLE.md)：周目标为 owner 资料；提醒时间为设备偏好，目标变化不等于应重新排通知。本方法不伪造该联系。
- 冻结 `archive/quality-diagnosis/snapshot-004/source/QiuJiTests/V53ProfilePreferencesTests.swift`：`testLoggedInDisplayNameCommitsOnlyServerResponse` 提供真实服务端响应协议用法；游客资料隔离旧测试仅昵称，legacy 目标迁移仅 guest/account 默认差异，不能替代本方法 A/B/guest 目标链。原 B4 profile16 历史范围保留，不因旧原件不足重跑。
- 现有目标 3→5 UI/磁盘/进程重启结果与 QD028 仍按原报告复用。本方法不代替当前主页刷新验收，也不重复该已知问题。

## 宿主、环境与副作用门禁

必须全新专用 Simulator 的全新无凭据 App 安装，串行 `QiuJiDiagnosticMemoryHost` 或同等已审宿主；不要复用账号或 StoreKit UI 设备。没有真实登录、令牌或网络账户输入。运行器必须在 App 初始化前传 `-v50.inMemoryStore`，不能等测试启动后再设置。禁止 `-v53.authenticatedProfileFixture`、`-forcePremium`、`-forceNonPremium`。

三个环境键均实现 direct 优先、`TEST_RUNNER_` 回退，不匹配直接失败/throw，不 skip：

| 键 | 必须值 |
|---|---|
| `QD_OWNER_GOAL_AUTH` | `NEW_EMPTY_MEMORY_HOST`，主控确认新宿主无凭据后才传 |
| `QD_OWNER_GOAL_DEVICE_UDID` | 有效 UUID，严格等于实际 `SIMULATOR_UDID`（忽略大小写） |
| `QD_SHOT_DIR` | 新绝对路径叶目录；非根，存在内容即拒绝 |

执行前代码额外检查 `CurrentOwnerContext.shared` 仍为其 guest owner。此检查及 argv 不能单独证明 Keychain 为空；**新设备无凭据前置必须由主控落实**，不能用 attestation 绕过。

已全文核通知链：冻结 `QiuJi/App/QiuJiApp.swift` 的 `.didCompleteLogin` 订阅将测试发出的 ID 交给 **App 自己的 authState**；`Data/Services/AccountDataCoordinator.swift::handleCompletedLogin` 先 `isCurrent` 身份检查，再要求 `cloudSyncEnabled` 才进入 push/pull。全新 guest 宿主不能匹配合成账号 A/B；本地测试 auth 也始终断言同步关闭，不调用 setCloudSyncEnabled、不发 migration 或 invalidation 通知，不替换 shared backend/context。因此这些正常 login 通知不应激活实际共享用户数据网络。若宿主已有凭据，该推论不成立，必须拒跑。App 自有启动任务/内容加载不等同于本方法 backend ledger；本方法不宣称全进程所有网络为零。

所有资料 Store 显式注入同一受控 actor，不用 BackendSyncService.shared 默认参数。`loginAnonymously` 不调用 logout backend。非预期 fetch/logout 进入 ledger，检查时失败；额外/错误资料请求记录后 throw，业务保存即使捕获该错误也无法把测试算通过。只有两个指定 profile 请求可以成功，游客保存和全部读回不允许新增请求。不访问真实凭据、不调用 Keychain 清理。最后仅删除本方法 UUID defaults domain，证据先保存再清理。

## 五阶段原件与硬断言

`QD_SHOT_DIR` 下恰五个正常阶段 JSON；失败另留 `failure.json`（不保证此前未到达的阶段存在）：

1. `01-initial.json`：三个 Store 默认 3、游客身份、零请求。
2. `02-guest-saved.json`：游客保存 2、owner 键读回、零请求。
3. `03-account-a-saved.json`：请求 4→响应 5，完整 Store/Auth/键值快照。
4. `04-account-b-boundaries.json`：B=6，0/8 拒写后三个值 2/5/6；两个请求。
5. `05-switched-and-rebuilt.json`：三个新 Store 的 beforeLoad/afterLoad 值，当前身份与精确请求 ledger。

每份含 owner、Auth 当前合成 ID/goal、同步开关、三 Store 值/保存状态/错误、三个 owner-prefixed 键及全量请求。所有 JSON 不输出令牌、邮箱、全部 defaults 或 NSError userInfo。请求只有 goal 字段；ledger 精确为 A 的 4→5 与 B 的 6→6，顺序固定，其他 profile 字段必须 nil。backend 请求协议本身不含 owner 参数，因此 ledger 的 responseID 是受控返回 ID，不能冒称 HTTP 认证主体；调用前真实 Auth/owner 与调用后 DTO ID 检查共同限定归属。

失败后先写快照再清 UUID domain；写失败不会吞错。所有依赖断言使用 guard/throw，避免 XCTest 报错后继续后续阶段。actor 无挂起屏障、无无限轮询、无外部 HTTP，有限 5 次 setWeeklyGoalDays 调用（guest/A/B/0/8），因此无需延迟网络超时矩阵。

## 编译前依赖核查

已核冻结实际签名：`UserProfileBackend.updateProfile(UserProfileUpdate) async throws -> UserDTO`；`AuthSessionBackend.fetchProfile/logout`；`AuthCredentialStore.hasRefreshToken/clearAll`；`OwnerProfileStore.init(ownerKey:defaults:backend:)`、`load(from:)`、`setWeeklyGoalDays(_:authState:)`；`AuthState.login(user:)`、`loginAnonymously()`；`CurrentOwnerContext.ownerKey/guestOwnerKey`。DTO 成员初始化含全部 9 个实际字段。原 V53 同 target 已使用这些 internal API 的 `@testable import QiuJi`。

需主控把草稿加入 frozen004 测试 target 后做真实编译，再单选此方法。语法 parse 不检查模块访问或 Swift actor/sendability 类型约束。通过仅说明本地服务/持久键的 owner 隔离及服务端响应真源行为，不证明真实账号 HTTP、跨设备同步、冷进程磁盘持久性或提醒权限。
