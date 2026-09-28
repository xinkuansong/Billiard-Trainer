# 每日清台 3D 优化与真机验收

日期：2026-09-27。状态：进行中，A1/B真机采集已保存，用户反馈明显发热后停止负载并取消A2，离线分析已完成，两组不满足可比条件；目标未完成。当前会话目标是需求真源；本文件记录执行与证据。沿用现有 2D／3D 共享架构，首个完整对象为每日清台 3D；2D 仅做受影响回归。

## 目标与验收

保留目前认可的画面质感和物理表现，改善首次操作、连续瞄准、转动镜头、满台开球和持续使用。减少实际计算与重复更新，以稳定 60 FPS 为首轮基准；最终进入普通启动配置，并通过完整页面真机对照。

| 要求 | 证明方式 | 当前状态 |
|---|---|---|
| 球体、号码、台呢、主要反光及接触阴影保持；低机位、贴库、运动无新增瑕疵 | 当前基线与候选同机位图、局部图、动态同帧球影；实际手机审看 | 四机位模拟器静态等价通过；动态/手机未完成 |
| 代表操作至少 95% 实际呈现帧间隔 ≤20 ms | 归属本进程/本渲染表面的 present 事件；按操作窗口统计，静止窗口单列 | 未完成 |
| 首次唤醒、开球峰值单独检查 | 输入/阶段标记到可见响应及最长帧，不以平均FPS代替 | 未完成 |
| 动态场景每帧 GPU 耗时争取降低25% | 同盘面/相机/分辨率/画质/帧率，基线-候选-基线配对，记录漂移与分布 | 未完成 |
| 10分钟正常使用温升改善，后半程流畅度不退化 | 同设备/亮度/操作节奏，未充电、冷却后对照；系统热状态与表面温感分列 | 未完成 |
| 普通配置生效、证据及剩余问题完整 | 源码/二进制指纹、默认入口、Release构建与最终手机普通启动核验 | 未完成 |

目标未满足时保留实测差距和剩余瓶颈，不能降低验收线、用模拟器或固定场景替代完整手机页面，也不能把实验版收益归给正式默认。GPU 25%是争取目标，其他体验验收仍必须逐项完成。

## 基线与测量口径

- 本轮从现有脏工作区继续，所有原修改保留。源码快照、SHA256清单、Git差异和HEAD：`build/daily-3d-20260927/baseline/`。快照不等于提交。
- 基线正常每日配置：R预积分反射、原直接球影、PBR台呢、当前材质/曝光/镜头；无S或clothPrototype参数。
- 独立基线真机包：`build/daily-3d-20260927/baseline-device/`，Debug优化编译`-O`、coverage关闭，仅为诊断基线；最终另验普通Release配置。
- 发现设备：iPhone 16 Pro / iOS27.0，devicectl已核实localNetwork。尚待本轮未充电、正常温度与可解锁确认，未启动真机负载。
- 独立模拟器：`QiuJi-Daily3D-20260927` / iOS26.3，UDID `A0739BE3-7536-40F0-A9BA-36645B27CFBE`。
- CADisplayLink、SceneKit didRender、GPU执行与屏幕present是不同指标。历史trace仅用于验证表结构，绝不回填当前结果。缺present归属或样本时明确未验证。
- 先验证短采集可导出且归属正确，再做长测；硬件分析与低扰动温升采样分开。出现明显发烫停止加压。

## 执行顺序

1. 冻结基线与测量口径，补完整页面的阶段标记和实际呈现证据。
2. 等价台呢计算候选与稳定相机重复写入优化，各自可归因验证。
3. 根据剩余GPU瓶颈推进台呢/球影候选；旧S条带影不直接恢复。低机位与运动图审先行。
4. 集中真机短对照筛选；通过者进入完整页面10分钟对照及普通默认交付。

## 本轮记录

- 已完成：当前源码重核、772份源码/配置快照；连接/系统版本核验；独立基线真机包构建成功（未安装）。
- 模拟器等价验证：相机6项、台呢1项、已有相机9项，共16项通过。台呢三种候选在overview/low-aim/pocket/top-down四个静态机位逐RGB通道差为0；截图及comparison.json位于 `build/daily-3d-20260927/cloth-visuals/`。已人工查看overview与low-aim；这不证明动态画面或真机收益。
- 相机稳定时跳过重复写入已接入每日清台；DEBUG `-daily3D.cameraReference` 可恢复参考行为。台呢候选仍由DEBUG `-daily3D.mergeClothSupport` / `-daily3D.factorClothBRDF` 分别启用，普通启动保持原台呢。尚无本轮手机性能结论。
- 已准备：完整页面阶段与SceneKit encoder标记，以及本轮手机诊断包；手机实际present归属预检尚待启动。
- 呈现分析：`scripts/research/analyze_daily_3d_frames.py` 通过16项构造性测试，严格关联专用encoder标记→command buffer→present request→display swap；拒绝SwiftUI刷新混入、错PID、缺阶段或截断窗口。尚未用本轮手机trace闭合这条链。阶段源哈希不能代替人工核对signpost时钟与窗口含义。
- 只读设备状态：本轮08:40的lockState查询返回passcodeRequired=false、unlockedSinceBoot=true。该状态不说明电源连接或机身温度。
- 后备研究：分段球影积分的2880例复现、来源哈希与局限已保存至 `build/daily-3d-20260927/shadow-research/`，未接入生产，不能计入当前性能或画质验收。
- 尚未实施：物理、画质/分辨率/抗锯齿/帧率降低、2D分离、提交或发布。

### 电脑端验证收尾

- **23项单元/图像测试通过**：相机6、台呢1、诊断生命周期7、已有相机9。新增红色台呢控制图确认截图响应真实shader修改，恢复后逐像素回到参考；已查看控制图，日志无shader编译错误。四机位三候选RGB差仍为0。
- **6项完整页面回归通过**：普通与诊断模式各自瞄准唤醒/击球回到idle，加手动满台开球、镜头拖拽/缩放/选球/击球/2D往返。两个瞄准用例见 `page-regression-stale-assertions.log`，其余四个最终复验见 `page-regression-r3-test-results.log`；两轮均在专用模拟器，不能作为手机帧率结论。
- 初轮UI有4个失败：旧HUD标识、旧瞄准按钮、全屏球坐标与中间stage尺寸混用、shotCount与新版playedVisitCount混用。已按当前源码修正测试入口/坐标/精确业务字段并验证合法1号球和相机数值；保留真实击球、undo从禁用到启用、结算后持续idle断言。未更改生产规则或页面来迎合测试。原失败日志与xcresult均保留。
- 初轮诊断编译失败来自iOS不支持的8X/16X抗锯齿枚举，已按iPhoneOS SDK修正；保留 `diagnostics-first-build-failure.log`。真机Debug优化诊断包随后构建通过。
- 诊断App：`build/daily-3d-20260927/instrumented-device/DerivedData/Build/Products/Debug-iphoneos/球迹.app`。manifest.json保存二进制/源码/资源SHA256；检查1157份图像、USDZ、HDR、JSON等资源，与冻结基线无差异。最终检查生产源码与构建时清单一致。尚未安装到手机。
- 呈现分析器16项Python测试通过；路由/写盘门禁为66截图、81路由、161写盘面、FAIL0。FreePlay路由签名漂移仅来自sheet邻近7行中的诊断调用，已对照冻结源码审计后更新签名与覆盖表。
- 普通Release构建通过：`release-device/test-results.log`为`BUILD SUCCEEDED`，原bundle ID `com.xinkuan.qiuji`，`-O`+whole-module optimization、无DEBUG编译条件；未安装或启动。`release-device/manifest.json`记录二进制SHA256 `84a77fd86f97ec830690359a5b01a71fbb38634a6ad7ed33472ceed1488e03f2`；生产源码与诊断构建一致，1157份资源哈希也一致。构建通过不代替普通启动的真机验收。

### 下一步与当前缺口

待用户确认本轮手机未充电、恢复正常温感并可解锁使用后，先做短录制验证encoder→实际显示事件的归属，再做同盘面/机位/60FPS的参考→候选→参考对照。参考可由同一诊断包加 `-daily3D.cameraReference` 恢复；两种台呢flag分别验证再组合。启动参数及实际帧率/抗锯齿/渲染比例有配置signpost。

手机操作不使用这些模拟器测试的launchClean/resetState夹具，避免清理现有用户草稿。需要确定性盘面时另准备保留用户数据的测量流程。`daily3D.wake/firstRender`仅代表调度/提交阶段，不代表实际显示，也不单独证明输入到可见响应的耗时。

### 手机预检的数据边界

- 已重新核实设备配对、开发服务和`localNetwork/connected`，连接可用；电源与温感确认仍未收到，未安装、启动或录制。
- 首段归属预检沿用普通页面与当前配置，无需测试夹具。存在今日草稿则恢复；没有今日草稿或完成记录时，正常入口会自动开球，跨日草稿会按产品规则清除。因此不能承诺进入即静止，也不能承诺普通使用完全不写数据。
- 离页/失活会保存草稿用时；页面停留满5秒会保存工具使用时长，已开启账号云同步时可能上传。保留这些正常使用记录，不自动清理或修改统计逻辑。
- 固定盘面反复重开不能直接使用正式容器的`resetState`、`fixture`或`fixtureSettled`。若后续确需独立测试App，主App与Live Activity须分别使用匹配的新bundle ID，并验证签名后的Keychain/App Group边界；该方案尚未创建、签名或安装。
- 普通Release的固定草稿/60FPS启动参数注入目前只有本机Foundation探针依据，iOS未验证，不能算作已可用流程。独立容器对照也不能替代原bundle普通启动的最终真机验收。本轮未增加业务隔离代码。

当前没有本轮手机CPU/GPU、实际呈现间隔、10分钟温升数据。普通Release已构建，最终手机普通启动、画质与交互验收仍未完成。目标未完成。

### 阻塞审计

同一手机测试条件连续三轮待确认。上一轮有实质进展：普通Release构建、资源一致性验证及数据写入边界审查。本轮复核基线/诊断/Release构建成功记录，诊断与Release源码清单均无漂移；没有新的手机条件确认。当前可独立完成的测量准备和定向回归已完成，继续确定优化收益及下一处瓶颈需要本轮真机数据，不能以额外模拟器测试代替。

目标标记阻塞。恢复条件：用户确认手机未接有线/无线充电、恢复正常温感并可保持解锁使用。收到确认后，从普通页面短采集及实际显示事件归属预检继续，再进行同条件对照；全部原验收标准保留。

11:21恢复后的首轮审计：goal工具已返回active，但没有新增手机条件确认，阻塞计数重新开始。检查无需主动操作的静态附加路径：devicectl连接可用；进程列表经URL解码后仅有`QiuJiLiveActivityExtension`（PID36521），没有球迹主App进程，不能用扩展PID替代3D渲染进程。因此未启动App、安装或采集。旧构建静态trace即使存在，也只能验证导出/表结构，不能补齐专用encoder标签、操作阶段、GPU收益或温升验收。

恢复后第三轮审计：上一轮仅报告待确认状态，无实质进展。本轮重新查询设备及进程，仍为connected且仅有Live Activity扩展PID36521，没有可附加的主App；对话中仍无测试条件确认。同一条件已连续三轮未解决，亦无新的独立工作可推进，目标再次标记blocked。原验收标准及未完成项保留。

### 手机条件已确认，继续执行

用户回复“手机现在一切正常”，沿用上下文中的未充电、正常温感及可操作确认，不重复询问。已重新核实局域网连接并开始安装诊断包，确认记录为`device-preflight/readiness.json`。预检审查发现旧SCNView拆卸误关闭共享页面诊断gate，已移除该错误状态写入，新增两种实际拆卸顺序回归；等待9项诊断单测和新真机包验证。原阻塞条件已解除，以上阻塞审计仅为历史记录。

### 真机工具预检与诊断修复结果

- 诊断生命周期9项通过（含两种真实`dismantleUIView`顺序）；日志`lifecycle-simulator-test-results.log`。新诊断包build-for-testing通过，`instrumented-device/build-r2.log`；二进制SHA256 `e65dd80665b3e81e4e86b22e314640663b88d05e1450681558facfcd52e6eb95`，1157份资源与r1一致。`install-r2.json`确认安装，`direct-launch-r2.json`确认PID36701、诊断/60FPS参数启动。未使用重置草稿夹具。
- 新增显式opt-in真机UI采集用例，默认跳过；白名单参数、正常完整页面、2D准备→3D瞄准/相机→2D收尾，只存XCTest附件和stdout。写盘登记后v47门禁为66截图/81路由/162写盘面、FAIL0。
- 自动点击工具两次都在**用例执行前**连接失败：runner分别PID36672/36699，exit74，`dtxproxy:XCTestDriverInterface:XCTestManager_IDEInterface`通道被拒绝。无页面测试步骤执行，不算App崩溃或UI回归失败。失败日志与xcresult保留在`device-preflight/runner-failure-r1.log`、`runner-diagnostics-r1/`及`device-preflight-r2/ui-test-results.log`。本机Xcode26.2、手机iOS27.0；版本差异是排查线索，尚未证明为根因，不自动升级系统或开发工具。
- 直接启动App及15秒Metal System Trace录制成功，源trace `device-preflight/direct-static.trace`，PID36676。该次为静止2D、r2显式安装前，不计候选收益。TOC及四表5次导出全部exit0，解析器所需schema/列/XML引用/整数纳秒匹配。报告`direct-static-export/structure-preflight.json`。
- 目标PID有239个通用Metal标签，但没有专用SceneKit标签、目标GPU interval或present request。其他进程的6条interval/185条request及961条surface swap不能补给球迹。当前仅证明录制→导出→结构读取，3D encoder→实际呈现归属仍待有操作的新trace；未生成阶段manifest或运行最终framegate。
- 已发出手动采集配合问题：先停留每日清台2D，等录制确认启动后再切3D、微调瞄准和切镜头，约45秒。此问题用于同步操作，不重复询问已确认的电源与温感条件。普通Release正在更新为诊断生命周期修复后的源码。

### 手动3D归属短采集

- 用户确认已在每日清台2D页面并可操作。附加已核实的r2主App PID36701，不重启App；以`notifyutil`接收`xctrace --notify-tracing-started`通知后才提示操作。
- 65秒`Metal System Trace`加`os_signpost`、`Thermal State`，录制exit0、已保存：`device-manual-preflight/manual-114828.trace`。命令及开始通知状态见同目录`manual-record.json`。
- 指导顺序：2D→3D静止约8秒→微调瞄准约10秒→切换镜头并静止→2D。未要求击球或重开盘面；时限到后明确提示停止操作。实际各阶段以同trace内App标记核对，不用口述秒数构造测量窗口。
- 用户结束后反馈“操作顺畅，温感正常”。这是本轮短操作的主观结果，不能替代实际呈现/GPU对照或10分钟温升验收。
- 当前正在导出并核对SceneKit标记→command buffer→present request→display swap。该段未包含开球，不生成完整帧间隔验收通过结论。
- 普通Release r2构建与清单复核完成：`release-device/build-r2.log`为`BUILD SUCCEEDED`，无DEBUG、`-O`与whole-module优化；二进制SHA256 `6e614812a7791b7fa95b04570fc741734de5e26405cb52b098a2c20bc2d44cf5`。357项源码/工程、1157项既定扩展名资源与instrumented r2一致；资源核对不含Assets.car/音频/plist等全bundle文件。r1清单/日志保留。Release尚未安装或真机验收。

### 真机归属复核与数字撤回

- 本轮短采真实包含3D页面、5.566秒瞄准、6.719秒镜头操作及三个idle区间；page配置为cameraReference=false、两项台呢候选false、selectedFPS=60，活动scheduledFPS=60、idle调度30，MSAA4、contentScale3.0。系统热状态0–66.300秒为Nominal，用户主观顺畅/温感正常。调度目标不等于实际显示帧率。
- 712个精确SceneKit encoder可对应712个唯一command buffer及712条present request。原解析器把标签时间视为encoder内部时间，真实导出却把全部标签时间锚在CB root开始；已改为嵌套精确标签、PID、类型、唯一encoder/CB root及包含关系，不采用时间容差。
- 初步按“同surface在显示前最后一条请求”推得698帧及瞄准58.24%/镜头97.19%的≤20ms比例。GPU交叉检查发现30处显示时间早于所关联CB的GPU结束，最大相差54.622ms，证明该关联规则不成立。**上述698帧及全部比例/首帧延迟已撤回，不能作为有效验收结果。**原始计算与反例保留于`manual-114828-export/partial-attribution.json`、`partial-attribution-status.json`、`gpu-attribution-audit.json`。已向用户明确更正。
- 有效GPU证据：按同trace内阶段与CPU root开始归属，瞄准268个CB的GPU Active区间并集均值27.005ms、p95 31.894ms，镜头401个CB分别16.569/28.798ms；这是标记CB的记录区间，非硬件利用率、整帧独占执行时间或优化前后对照。两阶段镜头不同，不能用其差值推断优化收益。见`GPU-ATTRIBUTION-REPORT.md`及复算脚本。
- 呈现解析器目前强制证据不完整、帧门禁false、exit2，不会因候选统计看似流畅而通过。开球、真实呈现间隔、10分钟温升、普通配置最终验收仍未完成。
- 用户已同意继续三轮固定全桌镜头微调瞄准的GPU对照：参考A1→相机缓存和两项台呢等价计算B→参考A2。保持同一已安装r2二进制，通过进程参数切换；不要求击球或重开盘面。该组只验证GPU候选成本与漂移，不绕过未闭合的实际显示证据。

### GPU对照因发热中止

- A1：PID36714，cameraReference=true、台呢两flag关闭；B：PID36774，相机缓存开启、mergeClothSupport/factorClothBRDF开启。两次55秒录制均exit0，原始trace/launch参数/record通知记录保存于`device-paired-gpu/A1/`与`B/`，使用同一已安装r2二进制。收到真实开始通知后才分别指导用户操作，时间到均提示停止。
- B后用户反馈“出现明显发热”。立即停止后续负载，取消尚未启动的A2并让手机回桌面自然冷却；之后只分析离线文件。进程查询`processes-after-B.json`已不含主App，只有Live Activity扩展；不能据此推断退出原因。没有再次启动App。
- B画面一致性问题未得到肯定回复，不能将发热选项算作视觉通过。系统Nominal若存在也不能覆盖用户温感。未完成A2意味着缺少前后基线漂移检查，这组数据只能描述A1/B，不能确认候选因果收益或温升改善，也不能通过原GPU/流畅度/10分钟目标。
- 协议及停止原因已保存`device-paired-gpu/protocol-and-stop.json`。呈现解析器29项回归通过、所有未验证统计改用candidate前缀，每阶段和整体均不放行；日志`device-manual-preflight/parser-regression-results.log`。

### A1/B离线结果与本轮结论

- 两组原始trace及六张GPU/阶段/热状态表已读取；导出初版漏设已验证的`LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`导致宿主崩溃，不能写成该绕过失效。补回后串行导出完成。A1标签表曾通过仅宿主NSZombie特例导出，其余恢复使用strict设置；各表环境、失败文件和日志保留于export-manifest。已向用户说明额外等待原因。被测App未添加这些宿主环境变量。
- 分析前固定口径为最长完整aim区间的第2–22秒。A1有23.485秒完整段，可用20秒窗口1177个CB：GPU Active区间并集均值14.076ms、p95 21.155ms；仅为该组标记CB指标，不是完整显示帧GPU成本。A1全trace前54.142秒Nominal，最后约1.968秒Fair；分析窗口内Nominal。
- B只有7.633秒完整aim段；最后一段从42.769秒至trace末56.053秒截断，不能替代完整阶段。B没有合格20秒窗口，不能临时拼接/缩窗以凑对照，**不计算A1/B收益百分比**。B记录热状态全段Nominal，但用户反馈明显发热；两者分别保留，不以系统状态否认温感。
- A2因用户发热未启动，缺少回归基线漂移；画面一致性未获确认，真实呈现关联尚未闭合，10分钟正常使用未完成。本轮不认定GPU降低25%、稳定60FPS或温升改善。两项台呢候选仍在DEBUG实验参数内；没有把它们提升为普通默认。
- 后续应在手机恢复正常温感后，先准备同盘面、全桌固定镜头，再安排足够完整的操作窗口；先完成可比GPU对照和真实呈现测量，再决定候选及持续测试。现有原始数据不丢弃，用户无需重做本轮工具预检。

## 完成审计

以上六项验收全部得到对应范围的当前证据，才可标记目标完成。构建、单测、模拟器图片、真机短测分别报告；未完成项持续保留。
