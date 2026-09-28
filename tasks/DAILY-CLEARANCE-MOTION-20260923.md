# 每日清台无线动态验证 2026-09-23

用户授权开始并要求无线；首次设备只配对未连通，用户解锁并确认同Wi-Fi、未充电、正常温度后，devicectl核实localNetwork和解锁。沿用昨日相同源码与Debug -O/coverage NO构建；普通默认仍A。

## 生产击球 A → RS → A

相同seed52生产盘面，两杆1.5/3.6力度。生产VM、物理求解、SCNAction与SCNView/Coordinator；独立宿主，尚非完整FreePlayView。三项分别实际通过34.983/34.904/34.639秒，共3项0失败。

| 配置 | 第一杆绘制回调Hz | 第二杆绘制回调Hz | 播放CPU占单核百分比 |
|---|---|---|---|
| A1 | 37.08 | 38.98 | 14.41 / 12.89 |
| RS | 59.39 | 60.01 | 23.32 / 22.69 |
| A2 | 38.31 | 38.47 | 13.34 / 12.53 |

每轮4个3秒静止窗口均0重绘，记录阶段末thermal均Nominal。前后A回调速率接近，组合版运动流畅度提升可复现。Hz是绘制回调计数/播放墙钟，不是逐帧屏幕呈现；没有据均值声明每一帧都无卡顿。CPU增长说明增加帧吞吐不是整机功耗下降；固定盘面GPU命令跨度省22.8%也不能直接替代持续温升。没有改物理、帧率或画质。

证据：build/daily-motion-20260923/{A1,RS,A2}/test-results.log与phases.json；motion-summary.json；device-ready.json和session.json。每轮通过后再拉取且独立目录，不以旧文件填候选。

## 下一步

- 按场景实例选择A/RS补瞄准休眠恢复；新测试只改变配置，复用原输入节奏，添加热前置与状态输出。
- 完整每日清台真实操作的呈现帧节奏/持续温升；未确认前不晋级普通默认。

## 组合版休眠瞄准

新增按实例配置A/RS的共用诊断，真机构建成功；`testDailyCombinedAimResumeLatency`实际1项0失败31.317秒，八段记录thermal均Nominal。显式活动的2D间隔中位16.69/16.75ms、3D16.72/16.70ms；3D首绘回调6.83/16.49ms。隐式活动仍约33.3ms，说明内容活动声明与渲染优化两者都需要。未把首绘回调等同手指到屏幕延迟，未改变命中测试或盲目预热。原始samples.json及日志在aim-RS目录。

完整页面已通过仅dailyClearance的Debug参数RS启动（PID17636），无夹具、无resetState、无AX材质扫描；其他页面和普通重启仍A。正在验证短录制导出并等待用户实际操作时间确认。

## 完整页面两分钟真实操作

用户反馈8杆、休眠后第一次拖动/瞄准不卡、手机温热。无线Game Performance Overview记录121.252秒，PID17636，热状态全段Nominal。CPU Time Profiler 25220条running样本、累计权重25.22秒（抽样权重，不冒充Activity Monitor累计CPU时间）。单应用Metal layer 4853372864有468条计数与3744条耗时聚合记录；107个>0.1秒FPS窗口覆盖102.23秒，窗口FPS中位59.43，约66.25秒窗口均值55～65FPS，其余35.98秒混有静止/起停，不能直接算掉帧率。逐帧表为空，没有据聚合值宣称逐帧无卡顿。进程峰值physical footprint指标1240.315MiB，不是纯驻留/纯GPU内存。

短时实际体验通过，不代表持续温升通过；无同条件A两分钟真实操作对照，不按昨天的数据估计温升降幅。证据live/rs-active.trace及active-*.xml、session-result.json、layer-summary.json。导出均沿用仅导出进程的线程池绕过；全仓verify-gate与diff检查通过。

## 20分钟持续体验进行中

用户选择继续，并再次确认已恢复正常温感、未充电；重开daily-only RS，无夹具/数据重置。最初PID附加失败保留日志；通过应用名成功附加PID17676。08:10左右确认采样启动后提示用户按日常节奏3D操作20分钟、明显发烫/卡顿立即停。记录long/rs-20min-r3.trace，结果未出，不提前标通过。无配对20分钟A，模板虽标低开销也不等于无工具开销。

## 持续体验提前停止：发热未解决

用户约5分钟时反馈“温升明显了”，立即提示停止操作，并仅向本轮xctrace进程发送SIGINT，记录正常保存。实际trace320.428秒，PID17676；0～98.719秒Nominal，98.719～320.428秒Fair。计划20分钟没有完成，不标热验收通过；用户进一步的杆数/温热或烫手/卡顿反馈待补。没有因系统未到Serious而要求继续。

CPU running样本56159条、累计权重56.159秒，主线程14.032秒；按调用栈名称包含关系粗分，SceneKit绘制21.788秒、预测2.011秒、主渲染tick1.359秒、命中测试0.051秒、SwiftUI/AttributeGraph4.026秒。类别可重叠且符号归类不完整，不加成100%或当作功耗分摊；现有证据支持继续优先渲染成本，而不是猜测物理预测为主要热源。

GPU聚合表有缺口：部分窗口FPS非零而GPU/命令计数为0，因此不将这些零值视作真实零GPU工作，不使用原始加权均值22.68%作为全段利用率。GPU非零记录仅109窗口合计103.46秒，覆盖分散在18.59～269.02秒之间；该模板GPU Usage定义为GPU active time/frame interval，不等于硬件整体利用率。FPS聚合含停顿/恢复，没有据均值48.16宣布运动掉帧率。逐帧明细缺失仍保留为限制。

原始文件long/rs-20min-r3.trace、toc.xml、device-thermal-state-intervals.xml、time-profile.xml、cpu-summary.json、layer-counts.json、session.json。最初按PID附加失败、随后按名称成功，属于工具发现问题；不能把它写成App崩溃。期间一次PID变化原因未确定，crash-files未发现对应今日App崩溃日志。普通默认仍A，没有为了流畅度通过而跳过热验收。

下一步是对RS组合版重新拆分剩余台呢着色/原生光照与阴影/提交成本，不能直接套用原方案的消融百分比。候选每帧更省同时恢复60帧，未证明单位时间能耗下降；保留60帧目标，不以降帧代替问题解决。手机本轮不再继续负载。


## RS台呢剩余成本：电脑端诊断准备（2026-09-23）

新增 `testCombinedClothResidualCost3D`：在setup前设置场景独立RS，直接走生产材质安装；不套用旧A的shadow/reflection字符串消融。五段为RS基准→仅台呢PBR关闭→RS基准→台呢整套着色关闭→RS基准；固定seed52散球、3D、原分辨率/MSAA4/60请求频率。此两项为嵌套移除账单，不相加、不相减推断函数独占成本，不是可交付候选。

每段检查实际球面预过滤标记、解析球影标记、16球集合、台呢材质模型和修改数量，保存修改前后shader、计量路径drawable及独立snapshot。输出独立 `ab-rs-cloth-*` 前缀，不删除旧A/RS比较文件。分析脚本新增 `--combined-cloth`：要求显式physical-device、RS实际配置、有效修改量、完整drawable、同球形和前后基准漂移≤5%；模拟器数据不会进入手机成本排名。

首轮模拟器实际1项通过（30.154秒），读回实际drawable：PBR关闭后台呢变暗且出现明显亮斑，整套台呢着色关闭后球影消失，与既有不可直接删PBR的结论一致。未改生产shader、画质或默认配置，未安装/运行手机。最终加强断言复验实际1项0失败（28.968秒）；两轮均为模拟器。分析器排除全部模拟器排名，并通过合成有效数据、零修改和错误profile拒绝检查；合成数据未作为实测保存。`verify-gate`通过，`git diff --check`通过。证据 `build/daily-motion-20260923/rs-cloth-local/verified/`。

后续手机只需这组短对照先确认剩余台呢成本；冷却和未充电前置需重新确认。若原生材质项成本很小，停止在该方向投入；若可观，再研究保留视觉的替代并单独验像素/动态与真机净收益。当前尚无RS剩余成本的真机排名，不能宣布新的降温修复。


## RS台呢剩余成本：无线真机短测完成（2026-09-23 17:05）

用户回复“可以开始”“开测”，沿用刚提出的冷却未充电前置；硬件充电遥测未知。实时确认iPhone16 Pro / iOS27.0 24A437、localNetwork、解锁。重编Debug -O、coverage NO后运行 `testCombinedClothResidualCost3D`：实际1项0失败，107.631秒。安装/启动约两分钟，尚未采样期间未宣称开始；五段结束即通知用户休息。无额外用户击球、无数据重置、未跑长测。

| 分项 | 前后RS基准均值 ms | 关闭后 ms | 移除差值 ms | 相对差异 | 基准漂移 |
|---|---:|---:|---:|---:|---:|
| 仅台呢原生材质光照 | 12.2035 | 10.9908 | 1.2126 | 9.9367% | 0.2308% |
| 台呢整套自定义着色及原生光照 | 12.1711 | 8.2913 | 3.8798 | 31.8772% | 0.3007% |

五段各120～121有效帧，原分辨率1206×2622、MSAA4、请求60、16球集合一致、生产RS标记成立，所有起止热状态及每段三个间歇热检查均Nominal。两项各一个前后夹持有效配对，尚无反序重复；亮度/环境温度未知。手机当前外观为灰黑桌框/胡桃木房间，电脑前测外观不同，只在本轮手机内部比较，未混用跨设备绝对数值。实际drawable检查再次确认仅关PBR后台呢变暗和近端异常亮斑，不能直接上线。

结论：原生台呢材质的边际移除成本约1.21ms，足以继续研究保留外观的替代；台呢整套仍有约3.88ms可隔离移除成本。两项嵌套，不加总、不相减当作函数独占时间；这不是优化候选净收益，不是瓦数或降温百分比，也不是20分钟热验收。下一步电脑端研究台呢光照替代并做视觉/动态等价，保留60FPS和原画质；普通默认A仍未晋级。本轮未改生产代码。

证据 `build/daily-motion-20260923/rs-cloth-device/`：session.json含版本/构建/二进制与源码SHA，device.json无线设备核验，build/与run/日志，results/原始程序/帧/图片/冷却数据，analysis.json有效配对。拷回results含此前诊断输出，本次分析仅消费ab-rs-cloth前缀五段与对应本轮冷却文件，不将旧文件当新增实测。


## 台呢保真替代原型与归因修正（2026-09-23 17:29）

用户授权开始替代方案；本轮仅电脑端，新增 `testCombinedClothLightingOutputIsolation` 和测试内原型，未改生产材质/默认配置。按Apple SCNShadable的surface/fragment阶段分离输入与光照输出（官方说明：https://developer.apple.com/documentation/scenekit/scnshadable）。

重要修正：上文1.2126ms/9.94%应解释为PBR→constant配置变更的整段GPU差异，**不能认定原生灯光独占成本或保真替换收益**。运行时对照证明constant下 `_surface.roughness` 为0，而PBR能获得粗糙度；因此原消融同时改变了自定义BRDF输入。整套台呢移除仍为嵌套移除差异，两者不可加减作为函数独占成本。

实验过程保留于 `build/daily-motion-20260923/cloth-output-local/`：
- 首轮输出隔离2D基准重复有17个RGB通道差>1、max3，严格断言失败；3D稳定。随后先预热每种材质管线，再执行完整前后基准，未放宽相等要求；后续基准均完全一致。失败原图/log保留。
- PBR只输出自定义emission时，相对完整RS平均RGB差2D0.00928、3D0.60909（8bit全图尺度）；说明原生输出非零，但大幅变暗不全由移除原生输出导致。
- PBR/constant的AO输出逐像素一致；roughness的平面中心输出从约201变为0（这是已色调映射像素，不把201直接当roughness）。法线输出也有小幅差异。
- 曾从MaterialFactory的非mobile分支误判为标量；运行时guard拒绝该原型，失败保留bound/。实际mobile setup传preservesClothResponse=true，保留USDZ内嵌roughness图片、强度1、UV通道0、线性mip、anisotropy1。已向用户更正；不能引用错误标量说法。
- 纹理绑定原型先暴露自定义属性复用/解码/缺少mip造成的差异，最终显式加载原始粗糙度图片为非sRGB数据纹理并生成mip，保留原变换和强度。仅测试辅助解析USDZ嵌入图片offset/size，不作为正式资源加载接口；生产接入前需可维护的资产接口与生命周期。

最终linear-texture/测试实际1项0失败5.343秒，表示对照采集及稳定性通过，不表示候选像素等价。当前仅一种外观、2D/3D静态盘面。候选对完整RS：2D平均RGB差0.08877/max17，3D0.59883/max15；全图指标含不变区域，不当作台呢局部误差或感知分数。候选对PBR自定义emission：2D平均0.08409/max18，3D0.07117/max13，仍有输入/采样误差；完整输出还缺原生非零贡献。已审comparison.png，异常亮斑消除、外观接近，但未批准保真。

下一步：保持输入与过滤对齐，补足原生剩余光照，验证近景/斜角/六种台呢颜色/真实动态及同帧球影；视觉成立后才测候选GPU净收益。**未测本原型手机性能/功耗/持续温升，9.94%不能移用为候选节省。** 本轮手机未安装或增加负载，普通默认仍A，RS也未被本原型取代。


## 台呢候选已无线安装供用户审图（2026-09-23 17:51）

用户明确要求“弄到手机上，我验证下”。将同一显式粗糙度原型提取为DEBUG辅助函数，增加场景级usesClothLightingPrototype，仅每日清台读取 `-dailyClearance.clothPrototype`；Release无此开关，普通启动仍原版。安装1.0.0(1)、Debug -O/coverage NO，以daily-only RS＋clothPrototype打开每日清台，保留数据，无reset/fixture。已核验localNetwork；控制台明确输出 `[DailyClothPrototype] active: explicit linear roughness, constant emission`，非仅安装成功。

同一辅助函数的模拟器输出隔离测试实际1项0失败3.160秒，全部误差指标与前轮linear-texture完全一致；手机构建通过。粗糙度解码包含范围/长度/格式校验，失败保留PBR并日志说明；临时DEBUG嵌入图片读取不提升为Release资源接口。材质持有MTL纹理，后续重新安装材质仍由场景标志选择；未引入全局渲染开关。

门禁首次命中FreePlayView诊断args.contains导致路由签名变更；已审计仅本页调试材质flag，无导航/入口/页面状态增删，route-coverage.csv现有FreePlay覆盖仍适用，只更新该文件签名。未改其他路由签名。证据 `build/daily-motion-20260923/cloth-phone-preview/`：sim/device构建与测试、device-info.json、install.json、launch.json、console.log、manifest.json。当前等待用户近景/斜角/球影画面反馈，未声称保真或降温通过，不要求长打。


## 用户认可后的候选回归与真机净收益（2026-09-23 18:11）

用户反馈“我觉得还可以”，记为手机外观初步认可，不当作全部视角/颜色像素等价。随后授权开始动态/恢复/耗时验证，并在冷却未充电问题后回答“是的，开始吧”；实时核验localNetwork。继续使用同一份DEBUG台呢粗糙度数据纹理候选，测试新增明确启用/回落守卫，不另换算法。所有结果位于 `build/daily-motion-20260923/cloth-validation/`，session.json记录版本、构建、源码与二进制SHA。

### 已完成

- 模拟器3项0失败63.646秒：瞄准恢复30.090秒、动态同帧球影0.754秒、3D两杆32.802秒。
- 无线真机GPU五段1项0失败106.817秒：RS→候选→RS→候选→RS，120～121有效帧/段，1206×2622/MSAA4/60请求、固定16球、相同相机/房间；全部起止及间歇热检查Nominal。两个夹持对照有效：12.0619→10.9896ms，省1.0723ms/8.8901%；12.0231→11.0123ms，省1.0108ms/8.4074%。配对收益中位8.6488%，前后基准漂移0.7586%/0.1164%。actual drawable已审；候选与基准标记、材质与球形一致性检查通过。分析器新增--cloth-candidate，已验证能拒绝错误候选开关状态。
- 真机3项0失败65.329秒：瞄准恢复31.366秒、动态球影1.038秒、两杆32.926秒。显式唤醒2D回调间隔16.69/16.65ms，3D16.67/16.67ms；3D首个渲染回调14.47/18.23ms。未显式唤醒的控制组仍约33.3ms，此为故意保留对照，不代表正式页面仍走该路径。所有8个瞄准记录点热状态0。
- 两杆实际播放回调59.99/60.05Hz，四个静止窗口0重绘；所有阶段热状态0。播放CPU约24.49%/24.08%单核，没有同期RS CPU配对，不声称CPU下降。场景/VM宿主不等于完整页面手指到屏幕延迟，也不是屏幕逐帧呈现证明。
- 补真实页面2D/3D瞄准轮拖动UI测试：首次旧用例查找dailyClearance.hud失败，现场截图确认当前是dailyClearance.landscape横屏布局，不是候选崩溃/会员页。按现行页面契约更新等待和状态断言，保留旧失败log/截图；复跑实际1项0失败26.561秒，真手势拖动、前后静止状态和2D/3D页面状态通过。此UI测试只在模拟器执行，没有用resetState/fixture重置用户手机。自由摆球的真手指拖动及屏幕延迟不由该瞄准轮用例证明。

手机自动负载结束后，以daily-only RS + clothPrototype重新打开每日清台，无重置用户数据；restored-console.log再次确认active。普通/Release默认仍未变，持续热验收仍未完成。上述8.65%是当前外观/固定3D场景的候选GPU命令跨度净收益，不是功耗/温升比例，不能与之前A→RS收益相加。2D性能、其余颜色/房间、全页多分钟使用仍无本轮匹配对照。后续冷却后进行日常停顿节奏的持续温升验收，明显升温即停，不因这轮Nominal提前宣布解决。

## 每日清台亮度候选（2026-09-23）

用户澄清：最早版本即觉球桌/房间偏暗，需要手机最大亮度才看清；不是这次台呢优化独有的问题。目标改为正常系统亮度下辨识场景，手机视觉确认后再继续持续热测试。

仅DEBUG每日清台新增 `-dailyClearance.exposure -0.1`，输入限定有限值[-0.45,-0.05]；场景在setupCamera阶段应用，早于球体/桌框材质生成，因此现有高光headroom随相机一起计算。候选相对原-0.45提高0.35EV，未增加灯光、采样或后处理遍数；并不代表实测功耗不变，也不等于显示器亮度增幅。普通启动/Release与其他页面不变，未改系统屏幕亮度。

证据 `build/daily-brightness-20260923/`：
- 已采集真实页面改前图page-before.png；同盘面原曝光/候选对照与实页2D/3D图片在verified/。实页testDailyBrightnessAimWheel实际1项0失败20.778秒，2D/3D瞄准轮拖动后回静止。
- 截图初审：候选台面、桌框及房间更亮，台呢仍为绿、阴影和球面明暗保留；手机中等亮度是否足够尚未验收，不能据模拟器证明。
- 初版离屏2D标签图片在逐帧更新中回到透视姿态，不能作2D对照；已修正为2D直接应用相机、不运行3D rig更新，重采集到final-capture/；旧文件保留追溯。
- 真机优化DEBUG build-for-testing成功，iPhone16 Pro局域网安装成功；以RS+clothPrototype+exposure -0.1启动成功，console.log确认clothPrototype生效。版本1.0.0(1)。未执行真机性能或温升负载、未清用户数据。
- 门禁首轮因FreePlayView启动参数后续上下文签名变化失败，审计只有DEBUG场景参数、无路由变化后仅更新该文件签名，verify-gate复跑FAIL0，git diff --check通过。

下一步：用户在正常系统亮度下核对2D/3D暗色球、白球及房间；若仍暗，继续依像素/实机对照调整，不把此候选视为最终亮度或持续温升验收。

最终离屏重采集实际1项0失败2.675秒，已打开final-capture下2D原版/候选原图：俯视姿态正确、台面更亮、白球与暗球阴影仍可辨。真实UI检查与图像采集分别通过，不外推手机主观亮度或热收益。

## FL-083 — 每日清台候选球影分层与横屏透视未充分验收（2026-09-23）
- 用户真机截图指出球影呈波纹、近远球大小差异过强。先前全图均值、固定盘面与性能通过，不证明近景低角度视觉成立。
- 球影重点嫌疑为S的8条Gauss积分，未逐像素证明用户原图的唯一根因；本轮撤出手机S候选，以R恢复原directShadowShader作对照。保留台呢与亮度候选，并明确整套输出不等于早期A。
- 镜头使用每日专属DEBUG配置：FOV40/50改28/32，半径及高度按tan(old/2)/tan(new/2)约1.460/1.626倍后退；默认配置不变。全桌仍按真实viewport拟合；观察入口改为读取实例配置以避免切换跳回旧镜头。
- 模拟器同机位三组对照1项0失败3.691秒；实页2D/3D瞄准轮与休眠1项0失败18.808秒；目视镜头近远差异减小、原影更连续。不是用户原盘面复现，不宣布手机视觉或性能验收。
- 下一步：真机用户确认球影/镜头，再测R+台呢+亮度+镜头组合性能；不得沿用RS的GPU与60Hz结论。
- 规则改进：性能候选必须包含低角度、画面边缘近球及运动球影局部检查；用户视觉打回后冻结晋级、分别对照材质与相机变量。
- 已应用至：`.cursor/rules/55-test-engineer.mdc` §FL-083；`tasks/UI-IMPLEMENTATION-SPEC.md`。

证据build/daily-visual-repair-20260923，保留用户原图user-before.png。同机位current/reference-shadow隔离球影，reference-shadow/narrower隔离镜头；sim/含实际页面截图，device-build构建通过；门禁FAIL0，路由签名仅审计更新DEBUG场景开关上下文。

手机已局域网安装并以R+clothPrototype+exposure -0.1+perspectivePrototype启动，安装/启动JSON及console.log已保存，未重置用户数据、未执行持续温升负载。

### DR-325 — 每日清台有效修改落成正常默认（2026-09-23）
用户要求将迄今有效修改应用到代码。FreePlayView仅每日清台在setupScene前调用configureDailyClearanceRendering：R预过滤反射、原版直接球影、曝光-0.1、每日较窄镜头28/32度及匹配后退。静止休眠/事件唤醒原修复保留。Debug和Release共用入口，其他页面/导出默认不变。

S条带球影不提升；台呢constant/emission替代与嵌入粗糙度读取仍仅DEBUG实验、默认关闭，恢复PBR台呢。亮度/镜头是本轮用户授权落代码的当前配置，不等于持续温升完成；原RS与cloth净收益不能用于当前R+PBR组合。

新增/更新验证：无实验参数实际每日2D/3D瞄准轮与静止休眠；材质实际shader验证R启用、S关闭及独立场景不受影响。Makefile增加TEST_CONFIGURATION默认Debug，非测试build不传coverage参数，用于Release构建检查；前两次CLI参数错误日志保留。证据build/daily-defaults-20260923。

已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-325；tasks/UI-IMPLEMENTATION-SPEC.md。

DR-325验证补充：testDailyRenderingProfilesAreSceneLocal实际1项0失败2.918秒；无渲染实验参数的testDailyAimWheelResumesAndReturnsToIdle实际1项0失败18.907秒。已打开sim/resume-3D-before.png与resume-2D-after.png目视，台面/球影/页面控件可见。2D-before捕获到初入场部分控件尚未绘制的过渡帧，该图不作静止最终态证据，after完整。

DR-325最终检查：generic iOS Release无签名build成功（release-final/test-results.log，BUILD SUCCEEDED），验证非DEBUG编译路径；不是Archive/发布或真机运行证据。最终verify-gate FAIL0，git diff --check通过。本轮未装机、未提交。
