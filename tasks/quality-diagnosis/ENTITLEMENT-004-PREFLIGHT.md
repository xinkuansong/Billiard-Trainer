# EntitlementBoundary004 只读预飞

2026-09-08；已全文读取待审草稿及定向冻结源、现有归档AX。未改测试、运行/构建或操作模拟器；只写本文。精确selector：`QiuJiUITests/EntitlementBoundaryDiagnosticUITests/testLocalMonthlyUnlocksThreeCategoriesAndExpiryRelocksWithoutRestart`（1方法）。本预飞不构成测试通过。

结论：**c039收费/单球形、plan_positioning收费及确认文案、图谱门控及track值都有依据，没有发现这些业务预期选错。** 发现一处已有实测依据的前置遗漏：新设备搜索首次键盘引导未处理；另有几处断言证据边界/待现场AX，不能按未知直接判代码错。

## 四个重点核查

| 项目 | 实际核查 | 判定与最小建议 |
|---|---|---|
| c039收费与试打分支 | 冻结 `QiuJi/Resources/Drills/positioning/drill_c039.json:3,12` 为“直线球组合走位”/isPremium=true。DrillBoards仅一份c039文件，JSON实读8steps，首杆before为母球+1…8共9球。`Core/PositionPlay/DrillTryoutBoardStore.swift:64–84` 正常Bundle加载每份非空序列作一个formation；`DrillDetailView.swift:204–211` 仅formations>1弹选择，否则直接试打。 | 单球形断言合理，但**单球形不等于单球或单杆**。草稿没有错误地要求单球。仅文件存在仍不保证当前宿主解码成功，正式运行须保留真实试打图；若回退路径也有重摆，不得据CTA独自证明确实加载8杆那份内容。 |
| c039免费/Pro CTA | `DrillDetailView.swift:496–527` locked分支仅unlockProButton，解锁分支addToTrainingButton/bottomTryoutButton。`PositionPlayComposerView.swift:188–202` tryout.rearrange正常重摆，不弹确认。 | 草稿进入Pro试打、点重摆、返回详情路径有源依据；未操作盘面前点重摆只能证明操作可用，不证明重摆真的恢复了被改盘面。门控包足够，不要扩大成物理/8杆内容通过。Free可额外以!tryout.exists代替仅!isHittable的更强源预期，但本稿不改断言。 |
| plan_positioning | JSON:3,7为“走位Ⅰ·短距到一库”、isPremium=true；`PlanDetailView.swift:147–156` alert“激活训练计划”，无active时message含准确计划名，取消/确定激活。`:245–260` Pro有planDetail.primaryCTA，Free仅解锁此计划。 | 新内存空库且草稿只打开alert后取消，下一轮仍“开始此计划”合理。若已有active，message不含计划名，但那是草稿隔离前提失败，不应放宽文字匹配。实际归档 `formal-004-plan-continuation-001/...-saved-returned-home.txt:159` 有planPoster-plan_positioning、同标题、value未解锁；这只证明货架身份，不是该付费计划确认alert已经现场验过。 |
| 分离角图谱 | `AngleHomeView.swift:162` isPremium=true，正常“学”入口；`SeparationAngleAtlasView.swift:329–331` spinLegend.0及已选/未选、selected trait。`formal-004-storekit-pending-001/screenshots/...approved-real-atlas-open-AX.txt:286` 初态已选Selected；hidden-AX:265未选；restored-AX:286已选Selected。 | 草稿track值和trait切换都有真实AX支持，可直接保持；不需要换成只看按钮存在。另一次门控批准图谱已通过不代替本批动作/计划两类别，到期同例重锁有独立价值。 |

上述冻结源路径相对 `archive/quality-diagnosis/snapshot-004/source/`。c039 Bundle枚举与JSON计数是本次只读检查，不是Swift解码或UI执行。

## 有证据的准备遗漏及最小适配

1. **首次键盘intro未处理。** 草稿threeCategories里tap(search)后直接typeText（约143–156行），没有当前其他新设备方法使用的 `Speed up your typing`→唯一Continue→消失等待。实际原件 `archive/quality-diagnosis/runs/formal-004-account-failure-001/screenshots/account-failure-8198E190-C258-4816-A6A8-12112453D61D-3-terminal-unclassified.txt:101` 记录该首次系统引导；Library/Template已有有界适配。建议仅首次输入前等intro最多2秒，若出现核唯一Continue后点、消失最多8秒；输入后核精确search.value和键盘消失，再查c039。此为已知环境前置，不预判本设备一定弹出，不修改正常搜索字面值。
2. 当前草稿输入后只靠找到c039，**没有核输入全文及keyboard消失**。这不会自动导致假绿，但若系统吞部分输入或视口被键盘遮挡，会先变成无关reveal失败；最小补精确query读回和正常Return后的键盘消失，与已有LibraryBoundary一致。
3. 工具/计划入口控件仍有未观测处：c039实际tryout返回栏、付费计划alert在此空库身份下的AX、planPoster长滚动后的容器唯一性、Pro首次图谱加载均需首轮原图/AX。不建议提前猜坐标、换任意firstMatch或放宽完整frame条件。可在进入每页后加身份证据图帮助失败定位，但本审计不改源。

## 到期后的交易历史断言

- 本地SDK头文件实际存在 `expireSubscription(productIdentifier:)` 和 `allTransactions()`；冻结 `V53ProfilePreferencesTests.swift:335–349` 已用expireSubscription后等待current entitlement消失。它**没有**断言allTransactions必须仍恰一条原ID。
- 草稿购买后要求一条monthly/state purchased/pending=false，并记ID，是正确的本次唯一正常购买证据。到期后`unchangedTransactionHistory`不要求state仍purchased，也没有把历史purchased当当前Pro，这点合理。
- 但“到期后必须恰一条、ID集合完全不变”是**较强的本地SDK历史形态约束**。本次所读头文件没有对过期后历史条目形态的文字保证，旧Restore001证明的是恢复链同笔历史，不能自动移作expire链证明。当前没有足够证据说这条必错，也没有证据把它当产品合规条件。
- 最小处理建议：可保留该严格观察护栏，若仅此失败，先保存全部id/original/product/state摘要，归因SDK历史形态，不能直接记App重复购买或削弱后续权益重锁；或者在主控审后将“无第二次正常purchase操作/原始购买溯源仍可解释”作为产品结论，历史总数另列观察。不得删掉原始交易证据或把多交易自动当通过。
- 活跃权益消失应以同进程profile Free以及三类重新受限为核心；SubscriptionManager.swift:327–334监听Transaction.updates并checkEntitlements，属于本次可检验的业务链。20秒只是有界等待，不是已批准到期SLA。若listener没有更新，属于待取证结果，不应加重启绕过“withoutRestart”。

## 其余护栏与结论范围

草稿单次launch、空本地SKsession/errors nil/realTime、无forcePremium/forceNonPremium、固定离线身份，购买一次后不激活计划，语义吻合原包6范围。运行前主控仍需核APIClient的fixture前置throw在**实际安装Debug输入**生效；inMemory本身不是网络隔离。只检查profile label contains服务端球友的强度小于AccountFailure exactheader，但本批已有显式fixture与新设备约束，建议沿旧身份经验准确核对，不凭相似昵称替代。

teardown在截图/交易摘要后才clearTransactions/reset、终止App；这保证失败证据先存，不会把清理后的空历史当结果。capture当前PNG→交易文本→AX，与“先PNG再AX”总体目的不冲突，但若交易读取异常会缺AX，可在诊断实现审查时考虑先落AX再查交易；本审计未发现此处实际失败。

本轮预飞没有实际到期、没有执行任何selector，也没有新SDK调用结果。建议主控优先补搜索已知引导/精确输入前置，其余业务预期保持，首轮有界运行后按真实图/AX与交易结果适配；不因未知控件先改成弱断言。
