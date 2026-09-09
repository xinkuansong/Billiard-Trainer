# snapshot004 本地 StoreKit 边界测试准备

2026-09-08，Test Engineer。仅写本文件；未访问真实商店、未创建交易、未操作设备、未运行构建/测试、未改snapshot/工程/生产或共享台账。此文件给可直接转成方法级测试的执行设计，不冒充已运行Swift草稿。

## 当前可复用配置与隔离依据

实际读取snapshot004：`QiuJiUITests/OnboardingProUITests.swift`、`QiuJiTests/V53ProfilePreferencesTests.swift`、`QiuJi/Resources/Products.storekit`、`project.yml`、`StoreKitService.swift`、`SubscriptionManager.swift`、`SubscriptionView.swift`、`AuthState.swift`与`AccountDataCoordinator.swift`相关分支。

- `project.yml:210–213` 已把唯一Products.storekit作为UI测试runner资源；QiuJi scheme的Run配置显式引用同一文件。UI与单测均已有 `import StoreKitTest` 编译依赖消费，不需引入SDK包。框架由当前Xcode iPhoneSimulator SDK提供。现存引用不等于本次新增测试已编译通过。
- 配置版本4.0，三个本地产品：`com.xinkuan.qiuji.premium.monthly` 自动续订P1M、yearly P1Y、lifetime NonConsumable。测试目录不得另造同ID假目录替换真实产品定义。
- `OnboardingProUITests.storeSession()` 从 **UI测试bundle** 读取Products URL，`SKTestSession(contentsOf:)` 后reset、clearTransactions，并disableDialogs=true。这是明确本地交易环境；如果初始化失败必须停在失败，不回退真实购买。
- 真实业务要求登录会话才能购买/恢复与呈现Pro；游客购买CTA会先弹登录。正常Pro入口为“我的→订阅管理”，并非必须走subscription.preview。
- 本地UI用已存在 `-v53.authenticatedProfileFixture -v50.inMemoryStore -v51.followSystemAppearance`，以及launchClean原有 `-resetDebugPremium`；**不传forcePremium或forceNonPremium**，不点“模拟器解锁Pro”。否则权益观察分别被强制通过或强制清空。
- fixture是身份替身，不是真Apple授权。AuthState:177–205在bootstrap建立该身份后直接return，无远端凭证校验、头像revision=nil；AccountDataCoordinator:139/156对该fixture短路上传/下载。使用新专用诊断沙盒、空本地交易、无真实账号；不带syncChoice.explicitLogin，不打开云同步。运行时仍查日志异常，禁止因401把等待加长掩盖环境污染。

## 已有测试可用程度

| 精确选择器 | 实际证据范围/复用方式 |
|---|---|
| `QiuJiUITests/OnboardingProUITests/testStoreKitPurchaseAndRestore` | 真正常我的→订阅管理→月度产品选中→购买→profile.membershipSummary含Pro会员，并核SK本地月度交易恰1；重启后restore走subscription.preview、确认恢复成功文案。可复用为一条本地购买/重启恢复对照，但后半不是正常入口，dialogs被禁用；未覆盖取消/pending/失败。仅附件截图，无本次独立PNG目录，runner若需要截图manifest须由独立overlay捕获或导出附件，不能当无截图。 |
| `QiuJiUITests/OnboardingProUITests/testTourAndProPresentation` | 四页介绍和套餐选择；游客购买后取消的是登录页面，不是StoreKit付款取消。范围混合且使用preview，不为本次订阅边界整组复跑。 |
| `QiuJiTests/V53ProfilePreferencesTests/testStoreKitConfigurationLoadsMonthlyYearlyAndLifetimeProducts` | 实际Product.products集合与type检查，适合作一次本地商店前置。 |
| `.../testStoreKitLocalSubscriptionsPurchaseAndExpire` | SKTestSession直接buy月/expire/买年，StoreKitService实际currentEntitlements检查；不走SubscriptionManager.purchase或UI。历史已验，不为凑数量全重跑。 |
| `.../testStoreKitLocalLifetimePurchaseSurvivesRestore` | 非消耗型实际本地权益+AppStore.sync读回，不是恢复按钮。 |
| `.../testRestoreLoadingTransitionsPreserveExistingEntitlementLabel` | 已买终身后manager恢复，收isLoading [true,false]且状态标签永久有效保持。可复用错误恢复旁证，仍非UI。 |

旧 `P7_SubscriptionUITests` 多处guard return、if入口存在才做和仅前台不崩溃断言，不可单独满足可靠性；不建议执行来补覆盖计数。

## 已核本地SDK接口（不凭记忆编造）

Xcode根 `/Applications/Xcode.app/Contents/Developer`。以下源于 iPhoneSimulator.sdk 的 Developer/Library/Frameworks/StoreKitTest.framework：

- `Modules/StoreKitTest.swiftmodule/arm64-apple-ios-simulator.swiftinterface:234–241`：iOS17+ `setSimulatedError<API>(_ error: API.Failure?, forAPI api: API) async throws`，`simulatedError(forAPI:) async`。`StoreKitLoadProductsAPI`、`StoreKitPurchaseAPI`、`StoreKitAppStoreSyncAPI` 均存在，分别可用`.loadProducts`/`.purchase`/`.appStoreSync`；错误类型有`.generic(StoreKitError)`。
- `Headers/SKTestSession.h`：`askToBuyEnabled`、`disableDialogs`、`approveAskToBuyTransaction(identifier:)`、`declineAskToBuyTransaction(identifier:)`、`clearTransactions()`、`resetToDefaultState()`。
- `Headers/SKTestTransaction.h`：`identifier`、`productIdentifier`、`pendingAskToBuyConfirmation`、`state`，可断言待批准真实本地交易及批准后的状态。
- SDK System/Library/Frameworks/StoreKit.framework 的Swift接口：StoreKitError有unknown、userCancelled、networkError(URLError)。**禁止使用已被标记“No longer supported”的failTransactionsEnabled/failureError来伪造有效注入**。

已核签名的Swift操作示例（不是已执行代码）：

```swift
try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
let installed = await session.simulatedError(forAPI: .loadProducts)
XCTAssertNotNil(installed)
try await session.setSimulatedError(nil, forAPI: .loadProducts)
session.askToBuyEnabled = true
// 购买必须由实际App的subscription.purchase触发，不能用session.buyProduct替代该UI操作。
let pending = session.allTransactions().filter { $0.pendingAskToBuyConfirmation }
try session.approveAskToBuyTransaction(identifier: pending[0].identifier)
```

实际使用前先断言pending.count==1及productIdentifier再索引；每个异步操作错误不得try?吞掉。resetToDefaultState不应发生在购买与恢复之间，否则会破坏被测历史。

## 最小分批方法设计

建议首批四个独立方法，全部正常“我的→订阅管理”，有完整前置/退出/状态断言。每方法独立SKTestSession、起始空交易与无权益、唯一截图目录、失败截图/AX；方法名是**待新增设计，不是现存可选selector**。

### A 商品加载失败→正常重试

候选名 `testProductLoadFailureShowsRetryAndRecoversLocalCatalog`。

1. 建本地session，设loadProducts networkError，读回注入非nil；再启动App正常打开订阅页。必须在App启动前注入，以防共享manager提前cache products。
2. 等subscription.retry可见且可操作，错误说明包含加载失败/超时语义（系统localizedDescription随Runtime变化，不能硬写整句英文）；购买按钮不能在无商品时可用。截图错误页；核本地交易0，不把失败伪装为空成功。
3. 仅清除loadProducts注入并读回nil，点真实subscription.retry。
4. 三个product按钮出现，默认yearly选中；明确monthly/lifetime可选、purchase启用；retry和加载错误消失。正常返回我的，会员仍未Pro，交易仍0。

### B 付款取消（真实本地弹框）

候选名 `testLocalPaymentDialogCancelKeepsFreeEntitlementAndSelectedProduct`。

1. session.disableDialogs=false；正常已登录fixture进入月度产品，先截图选中与CTA。
2. 点purchase，必须捕获本地StoreKit付款弹层实际AX与PNG，再用**实际暴露的取消/关闭控件**点击；不能把登录取消或subscription关闭当付款取消。
3. 回原订阅页，月度仍选中、purchase恢复可用、没有成功跳回我的、没有已解锁会员；本地无purchased交易/无有效权益。关闭订阅页后profile.membershipSummary不含Pro会员。

本机尚未观察该Runtime付款弹框AX，**取消控件准确selector还未定**。执行时先一条观察方法取真实元素，依元素标识实现，禁止猜屏幕坐标或不存在就return。可另用`.purchase` generic userCancelled作为传输错误分支测试，但不能冒充真实取消UI；StoreKitService对`.userCancelled`结果映射CancellationError，而泛型抛出StoreKitError.userCancelled可能走manager一般错误catch，两条不是先验等价。

### C pending→批准→异步权益刷新

候选名 `testAskToBuyPendingDoesNotUnlockUntilLocalApproval`。

1. 本地session.disableDialogs=true、askToBuyEnabled=true，无注入错误；正常选择月度并点purchase。
2. 应不提前获Pro。StoreKitService当前pending映射StoreError.purchasePending，UI可能显示标题“购买失败”+“购买正在处理中，请稍候”；**记录实际文案，不把这个已实现标题当用户正确预期**。正确性必检为状态明确、无提前解锁、可以离开/返回而交易不会被当成功。
3. session.allTransactions恰一个pendingAskToBuyConfirmation且月度ID；截图待处理状态，关闭说明并正常返回我的，membership不含Pro。
4. 主控对本地pending transaction调用approveAskToBuyTransaction，App保持运行；有界等待profile.membershipSummary变Pro会员，交易不再pending且该购买只1个有效交易。再正常进入一项之前受限的高级入口验证门控真实刷新（具体入口须沿SC32既有入口清单定，不凭Pro角标替代可用性）。
5. 如果批准后App仍未刷新，保留明确问题证据，不重启来冒充Transaction.updates实时刷新；可另重启区分实时/启动恢复，原失败保留。

### D 购买失败→重试成功→正常入口恢复

候选名 `testPurchaseFailureRetryThenNormalRestoreRetainsOneLocalPurchase`。

1. 本地disableDialogs=true，设purchase generic networkError，读回非nil。正常月度点击purchase，断言购买失败说明、仍订阅页、会员未Pro、本地没有成功权益；记录失败交易允许存在，不能错误要求allTransactions总数一定0。
2. 清除purchase注入，关失败弹窗，选中产品保持；再点purchase，等待返回我的Pro会员。检查月度**成功交易**恰1，而不是把失败历史也计重复购买。
3. 终止并正常launch同fixture（不清本地交易、不重建SK session、不使用preview），从我的再次进入订阅管理→subscription.restore。
4. 恢复提示明确成功，Pro会员保持且成功交易数不增加。已有权益在恢复loading时不应突然显示未订阅；用已有manager单测作补充，UI需前后截图。
5. 可在同方法成功购买之后、成功恢复之前注入appStoreSync networkError，点恢复验证明确失败和既有权益仍Pro，再清注入重试恢复成功；若使方法过长则拆成独立restore错误方法，不能省略错误恢复层。

## 独立权益观察与成功定义

UI runner中的 `Transaction.currentEntitlements` 不当然属于宿主App命名空间，不直接当App权益读回。优先App实际profile.membershipSummary+受限入口行为，与SKTestSession实际本地交易记录互证；需要直接manager.isPremium/StoreKitService.currentEntitlements时另用宿主单测，持有本地AuthState绑定并`useDebugOverrides:false`，非UI runner跨bundle误读。

取消/pending必须确认App仍可继续、无有效权益；失败重试必须原错误被显示且解除后正常成功；恢复必须在同份有效本地历史上发生且无新增成功交易。测试总数非零、每选择器/配置/退出码/交易摘要/PNG和AX齐全后才可称通过。

## 运行边界与收尾

只允许主控已隔离的诊断设备+DerivedData+snapshot004，不操作当前模版/认知设备。运行UI全机串行，本说明读取无需设备。SDK接口iOS17+，首批M1/iOS26.2；本地配置不存在或Session创建失败即停止该分支，记录原因，不用真实Sandbox替代。

每方法结束保存交易状态、产品ID、pending/state与测试时间后再清本地测试交易和reset；失败同样先证据后清，清理失败记录不可吞掉。无需真实Apple账户或扣款授权，因为只使用Xcode本地配置；明确不可用于断言Apple登录、真实账户付费归属、服务器收据绑定、真正支付网络、退款/家庭共享或真实Sandbox恢复均可靠。

暂不新建Swift草稿：正常入口与SDK错误API已落实，但真实付款取消AX需一次受控观察，且现有会员页关闭/高级门控精确定位需主控同设备确定。先执行已有月度购买/恢复对照或新增A最小失败重试验证环境，再据实际AX实现B/C/D，优于产出带猜测取消selector的假可执行文件。本准备不减少SC33范围，未跑分支仍待执行。
