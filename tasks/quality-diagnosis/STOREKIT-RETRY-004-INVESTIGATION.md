# recovery001：清除购买错误后再次购买失败的有界调查

2026-09-08，Test Engineer。只读核归档、冻结业务源与本机 SDK；未构建、运行测试、操作设备或修改其他文件。结论：**已证实第二次实际购买失败，根因仍未定位；优先做直接 Product.purchase 的两条小对照，不重跑整个购买→恢复长流程。**

## 本次已见事实

归档：`archive/quality-diagnosis/runs/formal-004-storekit-recovery-001`。读取tested-sources完整Swift、inputs.config、exit、make/xcode-test日志、交易和AX；实际view_image审查purchase-network-error及purchase-retry-success-one-purchased两张PNG。

- 精确一个方法，188.331秒失败，make_exit=2（xcodebuild 65）。设备 C836D71E-1ED9-455A-92BD-4F6B38DA6B63，storekit004-DerivedData。
- t25.43s第一次tap购买；13:19:07证据为 **NSURLErrorDomain错误-1009**，月度交易id0、state2、pending=false、purchasedCount0。
- 源码随后 `setSimulatedError(nil, forAPI:.purchase)`、读回及XCTAssertNil，再正常重新打开套餐并选月度。日志未在该断言报告失败；**没有额外序列化这个读回值的文本附件**，应区分“经过读回断言”与“留有值/时间原始日志”。
- t50.01s第二次tap；15秒等会员标记失败，首报错是源码74行。13:20:11的所谓purchase-retry-success-one-purchased图实际仍是**购买失败 / 无法完成请求**，月度仍选中；交易为id0、id1两笔state2，purchased0。
- 两次文案不同。不能说旧的-1009消息原样留在UI；但“无法完成请求”没有domain/code/underlying，不能据中文文案把它认成某个特定SKError或服务端错误。
- 脚本虽continueAfterFailure=false，首断言失败后仍继续执行后续源路径，产生success/restored阶段名的截图并尝试重启。日志最终有XCTest `_caughtUnhandledDeveloperExceptionPermittingControlFlowInterruptions` assertion。阶段名不是成功证据；后段并没有建立真实购买成功前置，不能用来评价恢复错误重试。
- final交易仍两笔failed，没有purchased。未见该归档普通make/xcode-test文本提供第二次购买的底层NSError链；不能据此断言“底层没有报错”。

邻近对照只读了pending001的config/exit/交易：同UDID、同DerivedData，13:18:07 make0终态；批准后/terminal为月度id0、state1、pending=false。它证明这份环境刚能取得本地购买/权益，不证明普通无Ask-to-Buy购买或错误注入清除完全正常。recovery001起始断言交易0、askToBuy=false、load/sync错误nil，削弱“上一笔pending根本没清”的解释；仍不能由clearTransactions推断所有StoreKit daemon状态都已完全清空。

## 业务源与SDK给出的约束

- 冻结 `SubscriptionManager.purchase` 每次先令errorMessage=nil，然后调用service.purchase；一般catch才写本次localizedDescription。`StoreKitService.purchase`直接 `Product.purchase()`，success verified才finish；pending/验证错误/unknown分别有独立中文文案，都不是本次第二个“无法完成请求”。因此**仅UI旧错误未清、成功了但会员UI没刷**不足以解释新增第二笔failed交易。
- AuthState fixture bootstrap正常直接建立服务端球友身份，未带explicitLogin；AccountDataCoordinator push/pull对该fixture返回。截图账号身份仍在。购买已经走到StoreKit并生成本地交易，不像被manager“请先登录”guard挡住。无证据支持改登录/同步代码或换真实账户试买。
- 旧 `OnboardingProUITests.testStoreKitPurchaseAndRestore` 的session同样Products URL初始化、reset、disableDialogs=true、clearTransactions；首次正常UI月购买，无purchase注入。它是普通成功路径参考，后半preview恢复与此故障判别无关，不需要复跑全部旅游/P7。
- `V53ProfilePreferencesTests`多数现存成功交易由 `session.buyProduct`直接建立。这不是同一个 `Product.purchase()` 调用入口，**不能用它成功来排除客户端购买API失败**。
- 本机 StoreKitTest swiftinterface的 `.purchase` setSimulatedError/simulatedError可用；header有resetToDefaultState、clearTransactions、deleteTransaction(identifier:)，以及独立的askToBuyEnabled/disableDialogs、realTime。header只说reset清property overrides，没有声明nil读回等同于清失败交易、刷新App缓存Product、重新建立跨进程商店连接。
- `.failed`对应state2，`.purchased`对应state1。SKTestTransaction公开属性不含失败NSError，allTransactions能证明失败发生，不能直接解释原因。不要编造transaction.error API。

## 假说排序（不是根因结论）

| 待判别层 | 支持/反证 | 最小判别信号 |
|---|---|---|
| 本地StoreKit客户端/服务的注入清除生命周期、失败交易后状态 | API读回nil后新请求仍failed且错误改变；尚无原始NSError | 同App宿主中直接Product.purchase也出现注入清除后失败，则无需App UI/manager即可复现 |
| 跨UI runner→App注入作用域或缓存Product对象 | UI runner设错，App共享manager缓存Product；SDK内部行为未见 | hosted同进程重试成功而UI重试失败；后续只变更重新Product.products获取对象或同历史重启作对照 |
| 前一pending批留下非交易的环境状态 | 同设备相邻；起始交易0、askToBuy=false且此前本地Pro成功 | 新专用设备上无注入普通购买基线，再作同样错误重试；不直接清整机状态归因 |
| App认证/权益逻辑 | identity未丢；有实际failed交易，尚无success | 若直接API与正常UI无注入均成功、仅App错误后失败，再看具体调用上下文；当前不足以改产品 |
| 测试控制流/成功命名 | 已证实失败后仍流入后续步骤 | 新对照关键前置XCTAssert之外显式throw，截图使用observation/result阶段名 |

## 最小执行方案：先2个hosted SDK方法，按结果最多加1条分支

以下都是**待新增方法设计，不是当前可选selector**。建议新增 `QiuJiTests/StoreKitPurchaseErrorLifecycleDiagnosticTests.swift`（此交付未写入）。主控审核后注册，宿主是snapshot004 QiuJiTests，UI暂停后串行在专用设备执行；不在UI runner的另一bundle里直接购买来冒充App产品环境。读取与宿主现有V53测试一致的Products配置，显式session成功后才允许任何purchase。

### L0 `testLocalProductPurchaseWithoutInjectedError`

1. 独立本地session，reset/clear，disableDialogs=true、askToBuy=false、realTime，逐项读回。读回purchase/loadProducts/appStoreSync error为nil；保存配置来源、bundleID、时间和交易0。
2. **真实 `Product.products(for:[monthlyID])`，unwrap恰1后 `try await product.purchase()`**。不调用session.buyProduct，不调用SubscriptionManager，不启动业务UI，不需要真实账号。
3. success必须verification verified，先记录transaction ID/product/状态、再finish；assert本地purchased恰1及当前有效权益包含月度。pending/userCancelled/unverified都是基线失败，保留具体分支，明确throw停止。

这条用于判定普通Product.purchase能否在本地宿主工作；不能省略后直接只跑注入。

### L1 `testLocalProductPurchaseInjectedErrorThenClearRetrySameProduct`

1. 新session及同L0前置；获取一个Product实例。设purchase generic networkError(-1009)，把设前/设后 `String(reflecting: simulatedError)`及时间记录到附件/JSON。注入readback必须非nil。
2. 第一次Product.purchase预期throw：捕获**实际Error动态类型、String(reflecting:error)、NSError.domain/code/localizedDescription、底层NSUnderlyingErrorKey递归链**（有界如4层）；并保存所有交易状态。仅捕获预期API异常，不catch整个方法吞XCTFail。若成功/pending/userCancelled，记录偏差、失败并throw停止；不要继续当已注入失败。
3. 不reset、不clear/delete失败交易、不重建Product。`setSimulatedError(nil,.purchase)`，明确读回nil并持久化结果。立即对**同Product实例**第二次purchase，记录同样结果。
4. 第二次需verified success、finish、本地purchased恰1；允许第一笔failed留存。若throw，先保留NSError链和全部状态，再throw令selector失败；不进入恢复功能。

两条合计最多3次本地Product购买调用，不跑UI/真实商店，不带账号凭据。正常完成即可停止本轮定位，无需原188秒整流程。每方法终态先取证再清理；任何关键precondition用 `guard ... else { XCTFail(...); throw DiagnosticFailure... }` 明确终止，避免本Runtime continueAfterFailure异常导致伪阶段记录。

### 按结果只选一个后续对照

- **L0失败**：先定位第二个真实NSError与本地配置/session/进程作用域；无需跑L1长链或动App业务。若需新设备对照，只跑一次L0，保留旧环境失败证据。
- **L0成功，L1同样清除后失败**：已隔离到无需App业务也可复现的本地SDK调用链。下一条仅 `testLocalProductRetryAfterClearWithRefetchedProduct`：同L1，但清注入后重新Product.products获得对象再重试；其余历史不变。成功提示Product/客户端缓存相关，失败则更偏向服务/失败交易状态，但均不是Apple缺陷最终认证。
- **L0/L1均成功**：只加短的正常UI月度基线（沿OnboardingPro前半，购买成功即结束、不做preview恢复），同fixture与同专用设备。如果此基线成功，最小下一步才是UI错误重试并增强底层App日志，或在保留同SKsession/失败交易下仅重启App后重试；每个分支单变因，不能同时重建session、清交易、换设备后声称找到了原因。

如果L1及refetch都失败，随后才考虑单独“保存失败交易→只delete该failed identifier→读回消失→重试”或“reset overrides而保留交易→重新确认disableDialogs等”对照，**本轮不同时展开**。这类删除只针对专用本地测试数据，是SDK环境判别，不能当产品应该清交易的修复方案，更不能替换原真实失败后正常重试验收。

## 回到SC33的条件

先有无注入真实UI购买成功前置，再执行独立“既有Pro→恢复失败→正常重试恢复”即可诊断恢复分支，不必每次重新制造同一个purchase故障。原recovery001的购买失败保留；拆分恢复不代表修复或消除原失败。

本次不提供未经编译的额外Swift文件；以上两条方法合同和停止/分支规则足以让主控下一批实现最小SDK对照。最重要的新增证据是**第二次Error类型/domain/code/underlying与注入读回时间**，不是再延长会员标记等待。当前不确定点仍为SDK注入生命周期、客户端缓存/失败交易/跨进程环境；尚无依据归因到某一项。
