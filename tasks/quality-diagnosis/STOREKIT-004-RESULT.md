# StoreKit004 诊断结果（进行中）

## 商品失败与恢复 catalog001

2026-09-08，snapshot004，新专用 iPhone17Pro/iOS26.2，light/large。本地Products.storekit + SKTestSession，无真实Apple账号/付款。正式运行 `formal-004-storekit-catalog-001`：1方法失败，41.513秒，make2/xcode65。实际xcresult `Test-QiuJi-2026.09.08_13-09-55-+0800.xcresult`，1505文件归档于 `archive/quality-diagnosis/runs/formal-004-storekit-catalog-001`。

失败位于测试69行，期待“加载失败：”不存在。实际截图/AX显示“模拟器未注入商店配置，无法购买。请点下方「模拟器解锁 Pro」。”。已实际读回loadProducts注入非nil，页面无商品、购买disabled、重试可用、交易0；清除错误读回nil→点重试→三商品恢复，默认年度/月度/终身单选切换与购买CTA启用、关闭后仍Free且交易0均执行完成。主控已目视错误、恢复年度、终身三张图。不能以这些局部成功覆盖整项失败。

源码核对：SubscriptionManager.loadProducts的loaded.isEmpty分支显示该模拟器配置文案；catch才显示加载失败。这次环境实际落在空商品分支，不证明catch分支已验，也不能断言所有网络错误均被吞掉。原测试和失败保持，不删除断言或扩大匹配。Release/真机的空商品else分支还含Xcode配置指令，需在Release诊断时核销面向用户错误说明；当前截图只是Debug模拟器证据。

XCTest在异步断言失败后仍继续后续操作，末尾报告IssueHandling内部assert并自动启动一个0方法空suite。不能把后者0失败当通过，也不据此认定宿主App崩溃。

## 后续

付款弹框观察001已启动，仅采集实际系统界面/交易信息，不确认或取消，不预支取消通过。Pending和Recovery草稿已注册但未执行；完整SC33仍未完成。


## 付款观察001终态与取消测试准备

观察方法1/1通过38.763秒、make0，实际13-13-13 xcresult，133文件已归档。主控实际查看10秒PNG：Xcode本地月度付款弹框，明确testing only/no charge，交易0。SpringBoard AX中dismiss=关闭、footer=订阅，另有Xcode及球迹Pro月度文本；App自己的subscription.close为不同按钮。未确认/未取消，不能算取消通过。

基于上述实测控件新增独立Cancellation类，原Observer保留。测试先验证Xcode/测试声明/月度产品/关闭控件身份，再只点SpringBoard dismiss；要求付款弹框消失、原月度仍选中、购买按钮恢复、无购买失败alert、成功交易0、正常关订阅页返回服务端球友且仍Free。取消001已启动，尚无终态。注册只4行，scheme保持，源码解析通过但不代替运行。


### 取消付款001终态

取消001实际1/1通过38.607秒，make0/xcode0，13-15-16 xcresult及117文件已归档。主控目视付款弹框、取消后月度选择与启用CTA、返回Free三图；没有购买成功交易。仅本地StoreKit，不证明真实商店取消。Pending001现已启动，Recovery仍未执行。


### Pending001终态

Pending001实际1/1通过77.775秒，make0/xcode0；13-16-26 xcresult及1393文件已归档。待批准月度交易id0/state非purchased且pending=true，Free及图谱门控保持；批准同一id0后同进程无重启/恢复调用，实时出现Pro，交易恰1/state1/pending=false。正常进入实际分离角图谱并切换轨迹已选→未选→已选、返回仍Pro。主控目视pending提示、实时Pro、实际图谱三图。提示标题“购买失败”与正文“处理中”矛盾另记QD025，不因测试通过而认可文案。Recovery001已启动，尚无终态。


### Recovery001运行中已观察到的失败（非终态）

第二次正常购买仍失败：测试74行15秒内未出现会员。主控实际打开名称为purchase-retry-success-one-purchased.png的附件，画面是“购买失败 / 无法完成请求”；交易摘要实际transactionCount=2、purchasedCount=0、id0/1均state2/pending=false。**附件阶段名称是测试预设，不是成功结论**。本地purchase错误已被清除并读回nil，但这次没有成功交易；不得把后续恢复步骤当具有合法已购前置。原因未定，不归为重复扣款或已确认App缺陷。

异步XCTest再次在首个失败后继续执行；后续需要为关键依赖加入显式throw中止以避免误导性阶段附件，但本次选定源在终态归档前保持不动。新增保护不得删除任何原失败断言。


### StoreKit004本轮检查点（2026-09-08）

Recovery001实际1方法失败188.331秒，make2/xcode65，13-18-31 xcresult及1434文件归档。第一笔注入失败后Free保留；清除错误读回nil再买仍失败，两笔state2、成功0。后续重启/恢复缺已购前置，不计有效验证；异步断言继续与runner内部assert保留，不解释为宿主App崩溃。五run共5个方法次，3通过（其中1仅观察）/2失败；无业务改动。

有效新增：正常本地付款取消、pending保持Free→批准同进程解锁实际图谱；QD025待批准文案状态矛盾。商品空态重试有局部证据，但预期错误分支未命中；恢复购买仍缺有效成功前置。详见[StoreKit004结果](STOREKIT-004-RESULT.md)。下一步先对重试失败做隔离本地SDK对照/采集真实错误，再单独正常成功购买与重启恢复，保留原失败；原38场景其余缺口仍按覆盖检查点，整体诊断未完成。


### Hosted L0最小基线通过

formal-004-storekit-lifecycle-l0-001实际1/1通过0.879秒，make0，13-34-19 QiuJiDiagnosticMemoryHost xcresult/64文件归档。主控逐份读5个JSON：host com.xinkuan.qiuji/主bundle Products、本地dialogs disabled/askfalse/realtime/错误nil/初始交易权益0；Product.purchase verified success，id0/state1/有效月度权益，finish后及cleanup前保持。仅直接API宿主层，不是正常购买UI；据此选择同Product注入清除重试L1，现已启动。


### Hosted L1-001错误观察器失败及002

L1-001实际1方法失败1.181秒，make2，13-35-45 xcresult/1311文件归档。注入读回非nil且首笔failed，但NSError桥只得到StoreKit.StoreKitError/code0/描述含-1009；原NSUnderlyingErrorKey链无法展开Swift networkError关联URLError，严格断言失败并throw停止，未进行清除后重试。002仅增强errorChain跟随实际StoreKitError.networkError关联值，最多4层不打印userInfo，原-1009及成功交易断言保持；正在执行，不把观察器修正当产品修复。


### Hosted L1-002真正复现清除后重试失败

1方法失败1.403秒，13-36-43 xcresult/1312文件归档；首错链StoreKit.StoreKitError→NSURLErrorDomain -1009，clear-readback-before-retry持久化purchaseErrorIsNil=true，第二次StoreKit.StoreKitError code2/无法完成请求，两failed/purchased0。绕开UI和SubscriptionManager的直接Product.purchase仍复现，与recovery001同层结果一致；不能归咎仅UI未刷新，也不等于真实Apple商店固有缺陷。按调查合同仅增加一次refetch商品对象的L2对照，保持同session/failed交易/其余配置，之后转独立正常购买与恢复分支。


### StoreKit错误重试最小对照收口

Hosted L2 refetch仅变因对照实际1方法失败1.388秒，make2，13-38-04 xcresult/1315文件归档。明确首笔-1009→清nil→重新获取Product→第二笔StoreKit.StoreKitError code2/无法完成请求，两failed0purchased。与L1-002一致；无需业务UI/manager也会发生，refetch未消除。不称真实Apple服务缺陷或单纯App根因；本轮停止此SDK细分，转独立无注入正常UI购买+恢复分支。原失败不关闭。

## Restore001：正常购买、进程重启、恢复失败重试通过

2026-09-08 13:48，formal-004-storekit-restore-001实际1/1通过75.497秒，make0/xcode0；xcresult Test-QiuJi-2026.09.08_13-47-14-+0800及113文件已归档。独立本地SKsession空交易，无purchase/loadProducts/appStoreSync注入，正常选择月度购买后Pro；实际PID41432终止→41514重新启动，仍Pro；仅注入appStoreSync网络错误出现“恢复购买失败，请稍后重试”，退出状态页仍Pro；清除错误readback为nil后重试出现“已恢复购买，Pro功能已解锁”，最终Pro。全部10份交易摘要已读：起始0，购买后始终同一id0/original0/月度/state1/pendingfalse，没有新增成功交易。主控目视重启Pro、恢复失败、恢复成功三张完整图。

这补足独立恢复链，不改变recovery001及SDK L1/L2购买重试失败结论；本地StoreKit真实API和正常业务UI，资料身份为受控fixture/内存库，没有真实Apple账号/付款/Sandbox或云同步证据。原件archive/quality-diagnosis/runs/formal-004-storekit-restore-001；选定测试源、输入、日志、退出码和图/AX/交易摘要均在档案。
