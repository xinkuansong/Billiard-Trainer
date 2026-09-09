# snapshot004：本地购买与恢复失败后的重试

2026-09-08，Test Engineer。仅草稿准备，未注册、编译、执行或操作设备。产物 `StoreKitRecoveryDiagnosticUITests.swift` 精确一方法：`testLocalPurchaseFailureRetryThenRestartRestoreFailureRetryKeepsOnePurchase`。

## 核源后的关键路径修正

冻结 `QiuJi/Data/Services/SubscriptionManager.swift:280–321`：purchase networkError由一般catch写入localizedDescription、返回false并结束loading；恢复错误固定“恢复购买失败，请稍后重试”，catch不清既有权益。`SubscriptionView.swift:306–319`实际购买alert标题“购买失败”、按钮“确定”；恢复成功文案“已恢复购买，Pro 功能已解锁”。

**有Pro后正常我的→订阅管理进入的是 SubscriptionStatusView，不是订阅套餐sheet。** `ProfileView.swift`按isPremium选择NavigationLink，`SubscriptionStatusView.swift`已全文核读：恢复按钮为真实Button文案“恢复购买”，没有 `subscription.restore` identifier；无subscription.close，应走导航返回。草稿因此不用preview，也不猜一个不存在的status恢复ID。

状态页“Pro会员”标题是恒定Text，不能独自证明权益保留；“月度订阅”由purchasedProductIDs推导。草稿在恢复失败与成功后均核动态月度状态，再返回我的核仅isPremium为真才存在的 `profile.membershipSummary` 与原身份；不把一直留在状态页当作仍有权益的证明。没有点击“管理订阅”（会打开真实外部商店URL）。

本机SDK已核 `.purchase`/`.appStoreSync` 的setSimulatedError、simulatedError及generic networkError；`SKTestSession.h`显式声明timeRate默认realTime，草稿仍设 `.realTime` 且读回，避免加速月续订制造额外交易。所有错误set/clear均try await并读回非nil/nil；不使用已废弃failTransactionsEnabled。

## 单方法范围

1. 全新专用本地模拟器，runner `QD_STOREKIT_RECOVERY_AUTH=DEDICATED_LOCAL_STOREKIT_SIMULATOR`、QD_SHOT_DIR，支持TEST_RUNNER_前缀。UI runner正式Products.storekit URL unwrap→SKTestSession初始化，reset/clear交易，disableDialogs=true、askToBuy=false、realTime读回；交易0，loadProducts/appStoreSync错误nil。
2. 启动前注入purchase networkError并读回；已存在的authenticatedProfileFixture+inMemoryStore+followSystemAppearance，launchClean自带resetDebugPremium。真实我的身份服务端球友且无会员标记，正常订阅入口选择月度，点击购买一次。
3. 必须出现购买失败alert及非空实际错误说明（不钉Runtime翻译，不接受pending文案），无purchased交易；关闭错误后月度仍选中、购买按钮恢复可用。正常关闭订阅页，个人页仍免费，取证。
4. 清purchase错误且读回nil，再正常订阅入口选择月度，仅重试购买一次。成功回我的且Pro，所有purchased交易恰1并是月度；保存成功交易identifier集合。允许失败记录留在allTransactions，不把它计成重复成功购买。
5. 正常terminate/launch App，同一个SKTestSession不reset/clear/re建、不删交易、不preview。核重启后同身份已恢复Pro，成功ID集合不变。正常进入订阅状态页，月度订阅。
6. 注入appStoreSync networkError读回非nil，点真实“恢复购买”按钮。必须出现“恢复购买”alert+“恢复购买失败，请稍后重试”，成功ID集合未增。关提示，动态月度状态保持；返回我的实际Pro标记仍存在。
7. 清sync错误读回nil，正常再进入订阅状态页重试恢复一次；明确成功提示，动态月度状态及返回我的Pro保持，成功交易ID集合始终等于原集合。

所有关键阶段PNG先落盘，再交易摘要和App AX；UUID命名、withoutOverwriting、附件keepAlways。terminal取证在terminate/clear/reset之前，错误不try?吞掉。UI可点击元素以真实frame+window完整包含+TabBar/底部purchase边界检查，按上下越界决定有界滚动方向。

## Oracle与限制

- 成功交易筛选 `state == .purchased`，初次购买失败要求此集合空；成功后要求集合恰1且产品是月度；重启/恢复前后精确比较identifier集合，避免只检查总数或把失败记录计成重复购买。摘要同时记录所有state、originalTransactionIdentifier、pending。若Runtime恢复改变历史state表示，保留原失败后审交易事实，不能自动放宽断言。
- 恢复失败阶段只验证失败提示后以及回我的时权益保持；不宣称已逐帧证明loading期间毫无闪烁。此瞬态有既有manager加载状态测试可旁证，本次静态截图不能替代连续观察。
- 购买错误系统localizedDescription随Runtime变化：草稿只要求“购买失败”中的真实非空错误消息且非pending文案，最终须审AX具体文本和注入读回，不能用一张任意alert截图当网络错误完整证明。
- fixture隔离真实账号认证/同步；不传forcePremium/forceNonPremium、不使用真实商店/真实登录、不调用session.buyProduct直接造成功。disableDialogs=true所以本批不覆盖真实付款确认/取消。
- 本地购买、进程启动恢复、恢复失败重试仅属于Xcode StoreKit环境；不代表跨账号归属、服务端收据、真实Sandbox或生产商店恢复均通过。

主控须全文审核Swift草稿后才在snapshot004注册/编译/执行，并按实际输出补结论；本文与草稿不计通过数量，不更新共享台账。
