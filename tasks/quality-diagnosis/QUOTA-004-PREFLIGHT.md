# SC32 最后一题至本地 Pro 额度绕过预飞

2026-09-08，Test Engineer；仅新增本文件及 `QuotaBoundaryDiagnosticUITests.swift`。未注册、构建、运行、操作设备；`xcrun swiftc -frontend -parse` 退出 0 仅为语法解析。

唯一 selector：`QiuJiUITests/QuotaBoundaryDiagnosticUITests/testLastFreeAnswerExhaustsQuotaThenLocalMonthlyPurchaseAllowsNextAnswerWithoutRestart`。

## 原范围与旧测试审核

已读 `PLAN-v2.md` 的诊断/修复分离、证据分层和 B6 独立复核要求；`COVERAGE-PLAN.md:38` SC32 包括 Free/Pro 各类入口、到期及额度跨日。本条仅补**剩一题实际消耗→当日满额→同进程正常本地购买后继续提交**；不是完成 SC32 全范围，也不重复已有三类门控/恢复或到期链。当前独立审计入口为 `B6-COVERAGE-AUDIT-004.md`；本条同时依照该审计与原 SC32 门控范围，只补额度消耗与本地 Pro 绕过分支，不核销其他必要子项。

旧 `snapshot-004/QiuJiUITests/W7_DailyLimitUITests.swift` 输出硬编码 `/Users/song/projects/13.billiard_trainer-w7/build/w7-screenshots`，`try?` 写证据，continueAfterFailure=true；输入/提交多处 if 存在才执行，back 可能静默跳过，固定 sleep，多次 launchNear 会重置额度。不能直接复用或把截图方法当正常购买绕过已验。本草稿不复制这些行为。

## 完整读源与预期依据

冻结根 `build/quality-diagnosis/snapshot-004/QiuJi/`：

- `Features/AngleTraining/AngleUsageLimiter.swift` 全文：dailyLimit20，shared 初始化一次才应用 `-w7.forceDailyLimitNear`，写当日 count19；recordQuestion 每提交+1；isLimitReached 为 !isPremium && count>=20。**前19次是夹具，只有后两次是真实 UI 提交**；不称连续手答20题或额度磁盘迁移测试。
- `GeometricAngleQuizView.swift`：正常页 configure/generate、onReceive subscriptionManager.isPremium 更新 shared limiter、当前页 sheet SubscriptionView；次数/剩余 BTReadout，满额时换题 disabled、答题不出现、结果区 compact gate 代替下一题。购买回到该结果页应出现下一题，Pro 隐藏剩余指标。
- `ViewModels/GeometricAngleViewModel.swift:48–72,98–99`：随机角 1..<90，正常输入30合法；submitAnswer 追加 sessionResults、recordQuestion、异步持久化并 showResult，nextQuestion 生成新题。答案不要求正确、不注入角度、不做几何正确率断言。
- `NumericKeypadHUD.swift`：数字按钮3/0、非空提交；草稿每步必须存在唯一可点控件，结果必须含“你答了…30°”，次数从0到1再到2。
- `Core/Components/BTDailyLimitGate.swift` 全文：满额文案及唯一“解锁 Pro”进入订阅；不能从设置 Debug Pro 开关代替购买。
- `Core/Components/BTReadout.swift`：独立 label/value Text，无专用 AX ID。既有 `formal-004-cognitive-cancel-001/screenshots/*角度预测-question-unsubmitted*.txt:49–54` 实际分开显示次数/0、正确率/0%、平均/0.0°；那次是 Pro，**没有 Free 剩余节点实测证据**。本草稿按真实标签右侧、垂直相交最近数字文本读取；不用全局“1”（球面也有1）。当前 Free AX 若不同须保留失败后有限适配，不编造剩余专用 ID。
- `Features/Profile/Views/SubscriptionView.swift:308` 成功 purchase 后 dismiss；完整参照现有 `EntitlementBoundaryDiagnosticUITests` 的 bundled Products.storekit、真实 monthly ID、selection、purchase、transaction 检验及测量滚动 helper。未复制三类门控或到期。
- `Data/Services/APIClient.swift:116–129` DEBUG authenticatedProfileFixture 在取token/buildRequest/perform前 throw notConnectedToInternet。固定合成身份检查精确“个人信息，服务端球友”；不真实登录，不以账户模拟状态触发真实认证调用。此 guard 仍须主控核实际安装输入，不是网络抓包或全 App 零网络证明。

## 授权与隔离前置

1. 新专用本地 StoreKit 模拟器，由主控保存设备/空库身份/实际安装和 runner catalog 哈希。只允许本地 Xcode 交易，不真实付款。
2. env（direct / TEST_RUNNER_ 均支持）：
   - `QD_QUOTA_AUTHORIZATION=NEW_DEDICATED_LOCAL_STOREKIT_NEAR_LIMIT_OFFLINE_FIXTURE`
   - `QD_EXPECTED_DEVICE_UDID` 合法 UUID 且与实际 SIMULATOR_UDID 一致。
   - `QD_ACCOUNT_API_GUARD=SNAPSHOT004_REQUESTDATA_PRETRANSPORT_THROW_VERIFIED`
   - `QD_SHOT_DIR` 绝对根，内部新 UUID 目录、不覆盖。
3. Runner bundle 必须真正包含 `Products.storekit`。SKTestSession reset/clear只作用此授权本地环境；disableDialogs=true、askToBuy=false、realTime，purchase/load/sync模拟错误均nil，初始交易0。
4. 只 launch 一次：中文、`-resetDebugPremium`（清本地Debug override）、固定离线身份、inMemory训练库、`-w7.forceDailyLimitNear`。不使用forcePremium/forceNonPremium、直接购买API、深链或角度fixture。额度本身仍写该专用App的标准UserDefaults，不证明磁盘训练库持久化。

## 最小流程和停止边界

Free合成身份 → 练习/练/角度预测正常入口 → 次数0/剩余1 → 正常答题3、0、提交 → 结果30°、次数1/剩余0、满额文案、换题disabled且答题/下一题不存在 → 当前compact gate解锁 → 正常选择本地月订阅、purchase CTA明确每月 → 点击一次 → sheet消失，原结果次数仍1、下一题恢复、剩余消失 → 下一题 → 再正常答30提交 → 次数2、可再下一题、无满额 → 本地仍仅原一笔purchased月交易。

同日检查在两次提交前及终态；唯一launch无恢复重启，防止夹具重写19或日期跨日冒充Pro绕过。若 sheet回归触发题面重置导致原结果不保留，会保留失败，不擅自改用离页重入实现较弱替代。

每阶段完整PNG→AX→交易/uptime/date证据，失败先取证，teardown 再取证后 terminate、清理本地 StoreKit transaction、reset本地配置；不删沙盒、不重置系统日期、不改业务。主控归档后可保留设备用于独立观测。数据保存为异步，本方法不以UI次数宣称SQL已写两条；认知数据库持久化沿用既有分层证据。无真实付款、服务端订阅、续订到期、跨日或所有测验页额度结论。
