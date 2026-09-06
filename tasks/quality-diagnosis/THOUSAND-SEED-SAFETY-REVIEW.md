# 千场本地播种：隔离前提复核

2026-09-06，独立只读审计 snapshot-002。未运行宿主、测试、构建或网络，未播种，未改原选项文档/草稿。本记录修正 THOUSAND-UI-FIXTURE-OPTIONS.md 的网络前提判断，不是已执行结果。

## 结论

**“必须全域断网，否则禁止播种”是过度前提。** 本任务已准许专用无真实凭据模拟器普通启动；拟播种是本机 guest SwiftData 对象，不是 authenticated fixture，不调用同步仓储、不插入同步队列。冻结代码有明确游客同步 guard，未发现直接 context.insert/save 自动上传机制。没有全域断网 hook 不足以阻断该路线。

必要条件仍是：专用新设备及当前安装的空 App sandbox；无真实账户/凭据/StoreKit 购买环境；不带虚拟 authenticated 参数；宿主首次启动即内存；精确核对默认磁盘 URL 与现有 guest；不覆盖已有库；串行播种后彻底结束宿主，再同安装正常磁盘启动。原草稿的 OFFLINE 授权字符串应由主控改为符合实际约束的专用 guest 环境声明，不能未断网却填原值作假。本子任务未改它。

## 冻结真实同步边界

路径以下均相对 snapshot-002/QiuJi。

| 入口 | 实际 guard / 副作用 |
|---|---|
| App/QiuJiApp.swift:58–69 启动装配 | SyncQueueManager.configure、SyncRestoreService.configure只保存 context；AccountDataCoordinator.configure另重试本地删号迁移补偿。没有自动上传。CognitiveSessionBackfill是本地回填/偏好标记；内存宿主的这些操作不写待播种默认磁盘库。 |
| Data/Services/AuthState.swift:139–174 bootstrap | 无 refresh credential 时 useGuest；onboarding完成则guest，否则signedOut，直接返回，不 fetchProfile、不发 didCompleteLogin。两种状态 isLoggedIn 均false。绝不能混用 -v53.authenticatedProfileFixture：它置authenticated、account owner并发登录通知。 |
| AccountDataCoordinator.swift:118–128 syncActiveAccount | !isLoggedIn 或无userID即返回；再检查迁移确认。普通guest不进入pushThenPull。 |
| SyncQueueManager.swift:71–88 processQueue | 再次要求isLoggedIn；只取account:userID的队列。configure不process；直接模型insert/save不enqueue。拟1000场guest且0队列不形成上传工作。 |
| SyncRestoreService.swift:129起 restore | 方法自身不是通用guest guard；传expectedOwnerContext才核对account owner。实际App调用先过coordinator的登录/当前owner guard。不能推广为任意直接调用restore都安全；播种不调用它。 |
| AccountDataCoordinator 登录/迁移 | 必须真实authenticated/current user/account owner；有guest内容先给迁移提示，确认才transfer并push。千场巡游不登录、不确认迁移。 |
| AvatarStore.swift:34–49 | 可读本地缓存；anonymous或无revision不请求头像。不要虚构account资料。 |

prepare若指启动“准备”：上述configure、本地迁移和bootstrap才是同步相关路径；Data目录没有另一个统一prepare上传入口。ShotSoundBank.prepare是音频会话初始化，与千场数据上传无关；存在本机系统副作用，不等于向业务后端写数据。

## 可接受查询与真正外部写入

- 普通启动的StoreKit权益读取/交易监听、页面可能触发的公开内容查询属于现有启动行为；不因无法证明“零网络包”新增硬阻碍。不声明已抓包或完全无网络。
- SubscriptionManager.init始终启动Transaction.updates监听；收到verified transaction会finish并刷新权益。这是实际条件性交易状态副作用，不能把整个StoreKit调用都称纯查询。专用新模拟器、无购买账户/待处理交易，不执行购买/恢复，保留本地StoreKit测试配置可降低这一边界；-forceNonPremium只跳过App一处权益task，不关监听。
- 登录凭据恢复会触发profile请求/可能token刷新；登录后的队列会上传/删除，确认guest迁移会把本机数据转为account上传。必要隔离是没有这类身份/操作，不是阻止所有普通请求。
- 本地可写项包括guest ID、onboarding/debug偏好、内存迁移标记、缓存、目标fixture数据库与manifest。任务允许专用沙盒内这些必要写入；它们不等于远端污染。

本审计未逐项断言所有框架绝无遥测；在用户已准许正常启动的范围内，这不是播种特有的新风险。若后续改为真实登录/模拟authenticated/创建队列，应重新审查，不能沿用此结论。

## 独立 scheme 与首启参数

冻结project.yml:185–202说明QiuJiTests是App-hosted unit test，TEST_HOST显式为球迹.app/球迹；不是UI runner。冻结QiuJi.xcscheme的TestAction当前shouldUseLaunchSchemeArgsEnv="YES"，TestAction与LaunchAction参数列表都空。因此现有方案**没有自动注入**内存参数。UI测试的XCUIApplication.launchArguments也不影响这种hosted unit test。

主控可在独立诊断装配中复制一个仅QiuJi+QiuJiTests的scheme（不改业务源），禁用并行，只选择probe或seed的精确方法。明确用下列二选一，避免继承歧义：

1. TestAction设shouldUseLaunchSchemeArgsEnv="NO"，直接给其CommandLineArguments配置enabled的-v50.inMemoryStore（以及必要的测试环境变量）。
2. 保持YES，但在独立LaunchAction里配置该参数，让TestAction继承。不要只向xcodebuild shell塞同名环境变量：业务判断是ProcessInfo.arguments.contains。

拟XML关键片段（非已生成/已验证配置）：

```xml
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="NO">
  <!-- 保留正确MacroExpansion与仅QiuJiTests的Testables -->
  <CommandLineArguments>
    <CommandLineArgument argument="-v50.inMemoryStore" isEnabled="YES"/>
  </CommandLineArguments>
</TestAction>
```

装配后静态核对实际生成scheme/测试运行描述中的host路径和参数，不能仅凭project.yml意图判通过；最后由下述宿主probe证明传递确实发生。本文没有调用XcodeGen/构建来验证XML导出效果。

## 可检验前置 probe（仅建议，未新增方法/未执行）

建议单独方法 `QiuJiTests/ThousandSeedPreflightTests/testReportInMemoryHostAndEmptyDefaultStore`，只运行它，不同时选择seed。宿主已在启动初始化，所以probe不是阻止错误宿主启动的保险；执行前必须先静态确认scheme和专用新设备。

probe只读取：

1. `ProcessInfo.processInfo.arguments`：报告必要flag是否存在，拒绝-v53.authenticatedProfileFixture及其他身份/数据/deep-link fixture。仅输出允许列的参数与拒绝flag名称，避免随手输出全部环境或凭据。
2. `Bundle.main.bundleIdentifier`、可执行文件名、`NSHomeDirectory()`：证明位于期望App宿主而不是UI runner/test bundle。
3. `ModelConfiguration(schema: ModelContainerFactory.currentSchema, isStoredInMemoryOnly: false).url`：只构造configuration获取规范化URL，**不构造默认disk ModelContainer**；用FileManager读取store/-wal/-shm存在性，三者均应不存在。
4. 从UserDefaults读取已有`auth.deviceGuestID`，检查非空，并与`CurrentOwnerContext.shared.ownerKey == "guest:" + id`比较。不调用DeviceGuestIdentity.id以避免probe自行创建ID，不setOwnerKey。shared已由App初始化；若身份缺失则失败，不修正。
5. 记录上述证据到XCTest附件/日志，由主控读取后填写精确expected参数。probe不写manifest/database/defaults，不新建AuthState或调用bootstrap，不读取token值。凭据清空保证来自专用新设备/安装流程，guest snapshot不是证明Keychain无凭据的替代物。

只读probe无法直接取得QiuJiApp实例的私有StateObject AuthState；因此它证明实际args/默认URL/当前guest，而不虚报“已证明bootstrap完整结束”。冻结App在stored-property初始化时读取同一ProcessInfo参数，参数存在+默认文件仍不存在是内存首启的可检查证据。主控可等待正常guest界面完成后再确认身份，但不得为探测普通disk启动。

probe通过后保持同安装/guest，不重装；仅跑seed白名单。建议主控给seed增加保存后SyncPendingItem数量为0、全部session.owner匹配的验证（当前草稿尚无这两项），并将验证失败处理为无效样本而非成功manifest。播种后终止整个host；正常冷启动去掉内存参数，按原真实历史/统计路线读回。仅这些实际结果才支持千场UI结论。
