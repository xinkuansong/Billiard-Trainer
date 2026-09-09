# SC33：snapshot004 本地付款弹框观察设计

2026-09-08，Test Engineer。状态：只读准备，未注册、编译或执行。主控的 template007 仍占用 UI；catalog 草稿已审未跑。本文只为下一批取得真实付款弹框 PNG/AX，**不构成付款取消通过**。

## 本次核对依据

冻结源均位于 `build/quality-diagnosis/snapshot-004/`：

- `QiuJiUITests/OnboardingProUITests.swift:74–123`：已有正常“我的→订阅管理→月度→购买”路径、本地 `SKTestSession(contentsOf:)` 初始化；旧方法 `disableDialogs=true`，不能提供真实付款弹框证据。其游客介绍路径取消的是登录，不能复用为本场景的取消结论。
- `QiuJi/Features/Profile/Views/ProfileView.swift`：免费订阅入口是无 identifier 的 Button，内含真实静态文案“订阅管理”；账号头 `profile.accountHeader`，会员标记 `profile.membershipSummary` 为组合节点，查询 `.any`，不假定 staticText。
- `QiuJi/Features/Profile/Views/SubscriptionView.swift`：真实 `subscription.product.com.xinkuan.qiuji.premium.monthly`、`subscription.purchase`、`subscription.close`。未登录点购买转登录；已登录进入 manager.purchase，成功才 dismiss。不能以关闭此订阅页冒充取消付款。
- `QiuJi/Data/Services/StoreKitService.swift:42–52`：真正 `Product.purchase()` 返回 `.userCancelled` 才映射 CancellationError；模拟 `.purchase` 抛出 generic userCancelled 不是已证明等价的 UI 取消。
- `project.yml:210–213`：UI runner 资源引用正式 `QiuJi/Resources/Products.storekit`，不需要另造目录。正常 App Scheme 同样指向它。
- 本机 SDK `iPhoneSimulator.sdk/Developer/Library/Frameworks/StoreKitTest.framework/Headers/SKTestSession.h:40–48`：askToBuyEnabled、disableDialogs 是可读写 BOOL，默认 NO；clearTransactions/resetToDefaultState 可用。Swift interface 的 `simulatedError(forAPI:)` 可检查 `.loadProducts` / `.purchase` 未注入错误。禁止使用已不支持的 failTransactionsEnabled。
- 当前 `tasks/quality-diagnosis/StoreKitCatalogDiagnosticUITests.swift` 的 capture helper：全屏截图、App AX、当地交易摘要，UUID+阶段，QD_SHOT_DIR 或 TEST_RUNNER_QD_SHOT_DIR，附件 keepAlways，文件 withoutOverwriting，terminal 先捕获再 terminate/clear/reset。**App AX 不保证包含系统商店弹框，观察批必须扩充证据面。**

## 最小独立观察方法

待新增名称：`StoreKitPaymentObservationUITests/testObserveLocalMonthlyPaymentDialogWithoutConfirmingOrCancelling`。只一个方法。此处是实现合同，尚无已注册选择器；不直接复跑旧购买方法。

1. 主控先结束当前 UI 批，分配全新本地诊断 simulator UDID 和独立 DerivedData、输出目录。全机 UI 串行；不使用模糊按设备名称目标。记录 Runtime、设备、字号、snapshot004、方法名。通过 runner 环境 `QD_STOREKIT_PAYMENT_OBSERVATION_AUTH=DEDICATED_LOCAL_STOREKIT_SIMULATOR`（兼容 TEST_RUNNER_ 前缀）及非空 QD_SHOT_DIR 做硬断言；参数不是设备隔离证明，UDID 与沙盒仍由主控核实。
2. 从 `Bundle(for: Self.self)` 获取 Products.storekit URL，XCTUnwrap 后 `try SKTestSession(contentsOf: url)`。任何失败直接 fail/throw，禁止 fallback 到不带 session 的购买。持有 session 到取证结束；resetToDefaultState、clearTransactions，显式 `disableDialogs=false`、`askToBuyEnabled=false`，读回两个属性均 false，交易 count==0。读回 `.loadProducts`/`.purchase` simulatedError 均 nil；不注入取消/错误、不调用 buyProduct、不预建交易。
3. `launchClean` 增加 `-v53.authenticatedProfileFixture -v50.inMemoryStore -v51.followSystemAppearance`；其自带 resetDebugPremium。不得 forcePremium/forceNonPremium、subscription.preview、syncChoice.explicitLogin。fixture 当前 bootstrap 直接建立隔离身份，AccountDataCoordinator 同步分支对该 fixture 返回，不能用真实登录补救。断言正常我的账号头含“服务端球友”、无 membershipSummary；先保存 profile-free PNG/AX。
4. 点击正常“订阅管理”行。等月度 product 按钮出现，在真实 subscription.scroll 内有界滚动到按钮完整露出且高于底部 purchase frame，再选中，断言 isSelected 和 purchase enabled。readonly 文案只验证存在；商品 query.count 用 XCUIElementQuery，避免元素/容器重复计数。保存 before-purchase PNG/AX/交易0。记录所选真实产品ID、选中态、CTA label。
5. **只点击一次 `subscription.purchase`**。不注册自动点“允许/继续/完成”的通用 interruption handler，不确认付款，不点任意系统或 App 的取消/关闭，不用坐标盲点。随后有界分阶段取证：点击后立即、约2秒、约5秒；若仍只见加载，最后约10秒一次。时间是观察采样预算，不是“等够就通过”的 oracle；AX 查询实际可能超时，主控保留 xcresult 时间线，不无限延长。
6. 每阶段先保存 `XCUIScreen.main.screenshot()` 的 PNG，再收宿主 App.debugDescription 与 `XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription`（只查询，不 launch/activate/tap）。分别命名 app-AX、springboard-AX，并记录两者 state 与 session.allTransactions 的 id/product/state/pending。SpringBoard 是系统界面诊断面，不预设它一定拥有 StoreKit sheet；它无相关节点时不能声称弹框不存在，也不猜商店代理 bundle ID 来操作。
7. 最末状态取证后终止宿主 App，再清本地交易/reset，并由主控关闭/隔离该专用 simulator；系统弹框是否仍在也需记录，不通过未知关闭按钮清场。所有失败分支先保留 terminal PNG，再尝试 AX/交易，清理放 defer；AX 出错也不能丢掉已保存 PNG。不把强制终止作为用户取消或成功退回 App。

观察代码可复用当前 capture 命名与附件方式，但顺序应改成**先落 PNG 再查询 AX**，避免系统 AX 卡住时丢失弹框图。两份 AX 要分别保存，不能只把 App 的空树当所有系统界面证据。无交易时摘要明确写 count=0，不能只留空串；截图文件失败必须 fail，不能 try? 吞错。

## 观察产物与判定

最少交付：profile-free、before-purchase、after-purchase 阶段 PNG；各阶段 App AX、SpringBoard AX、交易摘要；xcresult、方法实际执行数量、退出码、准确环境与时间线。主控实际 view_image 检查弹框，不以测试方法绿色代替图审。

| 实际结果 | 本批结论与下一步 |
|---|---|
| PNG 清楚显示本地付款弹框，AX 也给出匹配节点 | 观察完成。记录所属查询面、element type、identifier/label、frame、同名节点数量、取消控件实际可点性；据此另写取消测试。 |
| PNG 有付款弹框，App/SpringBoard AX 都没有可操作节点 | 视觉观察完成，取消自动化定位仍阻塞；保留原图和两份AX，再安排单次专项观察，不用猜坐标/进程。 |
| 出现登录页 | 身份前置失败；不是付款取消，不点击登录取消凑证据。核 fixture/启动参数/真实源。 |
| 商品错误或加载一直不结束 | 未到付款弹框。记录为环境或产品诊断分支；不连续点purchase、不改为无弹框购买掩盖。 |
| 自动完成本地交易/直接Pro，未观察弹框 | 本批目标未达；保存本地交易和权益，核 disableDialogs 读回/Runtime。不能称取消通过，也不清历史后假装未买。 |
| 请求真实商店账号、付款来源无法证明本地 | 停在取证，不输凭据、不确认；核 session初始化和配置资源后再决定本地复跑。 |

不应在方法里断言“任何 alert 存在”就通过：登录、错误、权限弹窗都不等于真实付款弹框。付款弹框的实际文案与节点没有本机证据，本文不预填取消 selector；正式取消方法需同时核对弹框身份与局部取消节点。

## 后续取消测试的成功定义（本批不执行）

使用同样新本地 session/免费身份/正常月度入口，捕获已识别付款弹框，点击**已观察到且唯一匹配**的取消控件。之后验证返回原订阅页、月度仍选中、purchase 恢复可用、没有成功跳回个人页，正常关闭订阅页后同身份且无Pro会员；本地无成功购买交易。允许记录失败/取消交易历史，不能错误要求所有 transaction 永远为零。补 PNG 与 App/系统 AX 证明弹框消失，禁止以 app.state==foreground 代替可继续操作。

如系统弹框无稳定AX，则保留该自动化边界并设计基于实际可见控件的受控执行，不能缩为 generic userCancelled 或游客登录取消。以上都仅是 Xcode 本地 StoreKit；不证明真实 Apple 账号、扣款、跨账号权益归属、真实 Sandbox 或生产恢复可靠。

本交付仅此文档，没有新增 Swift 草稿。原因是尚无付款弹框身份与取消节点证据；先由主控按此有界观察合同实现/审核单方法，观察结果再决定正式取消路径，避免把“采样脚本跑完”统计为 SC33 取消通过。
