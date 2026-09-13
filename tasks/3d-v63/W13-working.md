# W13 — 思路、打一走二想三、防守

状态：🔄 首页面接入验证中；三页完整规划/演示流程尚未验收。

真源：问题集合_v63.md §8 W13。W12本地批次已验；W07–W10尚存兼容/性能缺口，不以本批页面观察进展替代。

## 当前实际差异

| 页面 | 既有职责 | 3D接入注意 |
|---|---|---|
| 思路训练 / SiluTrainerView | 选目标球/袋，画落区/落点/过点，反解塞与力度，下一解、微调、击球/上一杆/回放，已有开球 | 绘制overlay不能抢观察拖动；activeTool及约束保持；首次全桌观察 |
| 打一走二想三 / PlanThreeView | 显式①球/袋、②球/袋、③球角色；扇形引导与真正约束分开，打进后窗口前滑 | 保持角色行、杆序与自动推进；不能用思路页单目标语义覆盖 |
| 防守 / SnookerTacticsView | 当前实际是中八安全球反解，选我方目标，推断对方球组；完整斯诺克/剩余高难球 | 不是另加斯诺克赛制；没有进袋目标袋；不新增落区规划 |

## 基线

`baseline-compact-r1`/session63755终态0，三实页各1测：PlanThree19.775s、Silu19.885s、Snooker19.577s。BA57E048/D37E8F8E/D6173F40三张原图已直接查看，均真实目标页、当前固定2D。

## 首页面候选

SiluTrainerView开放silu.cameraMode，首次3D全桌观察，复用ShotPerspectiveLayout侧栏；3D取消SolveConstraintDrawingOverlay的命中和球体拖动，顶部工具禁用但保留activeTool，球库替换为编辑返回提示与查看全桌。共享scene保存/恢复视角，不重建VM或求解数据。

`silu-roundtrip-r1`/session87635终态0，1测试28.120s通过：2D画落区→3D查看/旋转→2D继续求解，留四张原图；尚未把求解可点击当成完整解算/击球流程通过。

仍需：当前解沿杆/球袋观察菜单、击球/上一杆的相机恢复、开球视角控件、真实完整解算演示、目标区/杆序状态不变量；另外两页尚未改。所有范围保留。

四张2D落区/3D/旋转/返回原图4CDCB567/FD12A2C8/48555A91/C3AF3909已直接查看，落区贴台面并随观察投影、返回原球形与区域保留。仅接受此流程；3D侧栏近袋遮挡、开球控件、观察菜单与完整求解仍需后续核验。

silu-roundtrip-gate/session92716终态0，diff/doc-size通过。

## 完整求解与上一杆补验

`silu-shot-r1`：实际UI测试1项98.125s通过，覆盖画落区→3D旋转→真实求解→击球→上一杆→2D。原始日志与xcresult位于`output/3d-v63/W13/`；已留存求解、击球结束、恢复三张原图256CBB66/BC59C195/FDDF03CB。此次求解约60秒，是仍需处理的性能缺口，流程通过不代表手机等待体验达标。采样未确认热点，不以推测归因。

相机快照候选：Silu的UndoContext保存击球前PerspectiveState，恢复球形/解后恢复观察视角；在2D恢复时保留至再次进入3D。`silu-undo-camera-r1`相机往返测试通过，但既有完整字段测试有3个失败：力度预期2.1实际3.0，spinX预期−0.05实际0，spinY预期0.3实际0。

夹具审查：原stubSolution只设置feasible/duration，termination仍为nil；当前hasFinalTableState仅接受settled，presentDisplayedSolution在回填参数前拒绝该不完整预测。原断言适用于“完整解快照”，全部保留；测试夹具显式标为settled，单测只证明状态搬运、不证明物理。同步重跑已有真实simulateFree生成完成结果、逐个拒绝nil/timeLimit/eventLimit/interestResolved/failed的测试，确保未放宽生产拒绝逻辑。`silu-undo-camera-r2`终态0，实际5项0失败，共8.469s；相机恢复0.348s、三页完整字段恢复均通过，拒绝不完整预测7.385s通过。

下一步仍是三页完整W13：当前解相机观察、3D开球/打点控件与状态边界，以及另外两页各自规划规则。袋底堆积不在此批继续探索。

DR-260收尾：`silu-undo-camera-gate.log`终态0，verify-gate通过；verify-doc-size通过（PROGRESS 97KB/10条），git diff --check通过。没有运行中的本轮测试句柄。W13保持进行中，完整目标未完成。

## 当前解观察菜单候选

DR-261：思路3D底栏复用BTSceneObservationMenu，全桌/母球/目标球/目标袋/回到瞄准；播放期间菜单禁用。共享API增加canReturnToAim（默认true，既有页面行为兼容），思路仅在有完整可击球解、可见母球及实际lastAimDirection时启用。observeCurrentAim直接调用既有CameraRig.enterAiming，不重建解、不修改参数或目标。无解禁用与真实求解后沿杆观察已加入完整UI用例，silu-observation-r1运行中。

DR-261复验：silu-observation-r1/session59712终态0，实际1项108.730s通过。无解回瞄准禁用、求解后启用/沿杆、击球/上一杆/切2D均完成。原图59245007（沿杆）、CF8E511F（上一杆恢复）、194CFDFE（2D返回）已直接查看，母球/目标球/球杆/蓝色落区与4.2力度可见且恢复一致。不是三页或全部观察项验收；本轮未逐项点母球/目标球/目标袋。系统Menu产生两条_UIReparentingView非失败诊断，保留附件，不据此改生产。

求解计时：26.64s点击求解，91.05s结果截图，约64.4s。有效采样silu-observation-r1-solving-sample.txt在scanMatrix→predictForPositionSolve→simulateMixedWithLocalPockets→advanceTogether捕获工作线程；这是实际耗时路径线索，未量化整段占比，不等于热点优化已完成。该问题归W07求解兼容/性能，避免为赶绿更换简单球形。

本轮verify-gate/session24860终态0，verify-doc-size与git diff --check通过；没有本轮存活句柄。下一步三页完整范围照旧，优先共享观察交互/开球与其他两页接入，并保留求解性能专项。

## 打一走二想三首轮接入（DR-262）

PlanThreeView新增2D/3D入口，首次全桌；3D保留①②③角色行但暂停编辑，球库替换为观察菜单，目标球/袋取当前①。绘图、球体拖动、台面点按改派在3D挂起，切2D恢复，保留armedRole与draft。左右控件使用共享透视布局。UndoContext可选保存PerspectiveState，在业务恢复后恢复观察。已有开球流程控件仍需专门验证。

planthree-roundtrip-r1运行中：现有twoBallDimmed夹具提供真实角色与落区，不注入求解结果；UI只验证模式/观察往返，不声称完整求解或击球推进。另跑三角色完整字段恢复与两模式相机恢复。

DR-262首轮：planthree-roundtrip-r1终态2；三角色完整快照2.345s、两模式相机恢复0.205s通过，UI42.479s失败。失败原文为Tab练习不存在及openCard返回false；RootView.swift的planThreeArgs会把twoBallDimmed直接路由至NavigationStack/PlanThreeView，AX和C49B0929返回截图确认真实页面。原openCard断言适用于主Tab入口，在该深链夹具前提不成立；改为直接断言planthree.cameraMode存在和table.scene可交互，所有观察/切换断言保留，r2复验中。原r1日志/xcresult/截图保留。完整真实导航仍由无夹具基线覆盖，夹具不替代手工角色指派或完整解算验收。

DR-262 r2：planthree-roundtrip-r2/session94919终态0，实际UI1项30.005s通过。A22DCDB9目标观察、F16634FD全桌、BB68BBB0返回2D三张原图已直接查看，①②角色/袋口色、扇形引导和矩形约束均保留；③未指定的既有夹具状态保留。3D下角色区仍沿用132pt底栏，存在空白可压缩；全桌前角袋与侧栏有局部重叠，保留后续布局验收项，不能据通过声明最终UI完成。

planthree-roundtrip-gate/session19932终态0；doc-size及diff通过。无本轮存活句柄。下一步：补本页真实求解/击球推进/恢复、三角色指定，处理规划页3D打点/开球布局，并接防守页；W13继续。

## 打三完整规划实测

在原twoBallDimmed固定球形/角色/落区上扩展实际UI：求解→回当前解瞄准→打一→等待上一杆可用→验证窗口前滑→上一杆→2D。没有注入解或物理结果。planthree-shot-r1运行中；本轮未修改生产源码，失败须先对照原图和真实终态。

防守页预飞已核：仅中八安全球/目标选择，无目标袋和落区编辑；后续观察菜单应省略目标袋，不能照抄打三规划语义。

打三完整实测：planthree-shot-r1/session18822终态0，实际1项108.002s通过；26.7s求解→91.51s解截图，等待约64.8s仍未达手机体验。7D207545沿杆、6550EF24①进袋推进、8B7B9C21上一杆恢复三张原图已直接查看：黄1离场、蓝2成为新①，旧②袋转为①袋；上一杆恢复黄1/蓝2角色、蓝框、3.1高杆右塞及观察视角。不是三颗角色全指定覆盖；仍需③→②推进和其他规划边界。

新增已见UI缺口：3D禁编辑时，finishStrike状态仍提示点桌上球设②，和底栏编辑返回2D冲突；应在呈现层明确当前编辑入口，勿改角色推进。底部空白、前袋侧栏遮挡及打点/开球仍未关闭。防守页未接，W13继续。

## 防守页3D接入（DR-263，验收中）

保持中八安全球语义；3D暂停目标选择/摆球，首次全桌，底栏替换为观察菜单与编辑返回提示。菜单目标取selectedTargetKey，pocketIndex传nil省略不存在的目标袋入口；当前解实际杆向返回瞄准。UndoContext可选存储PerspectiveState，在业务恢复后恢复观察。首轮snooker-shot-r1实际默认入口求解/击球/上一杆/2D全流程与两项快照测试运行中；没有注入防守解。

DR-263首轮结果：防守完整字段恢复2.456s、两模式相机恢复0.357s通过；实际页面默认盘面求解超过90s仍未得到可击球解，315行等待断言失败。16:20原始simctl截图snooker-shot-r1-live.png已直接查看为求解中，不是已解。原测试continueAfterFailure导致后续截图错误命名solved，已仅在该方法设置失败即停，90秒门限与原断言保留；未重跑、不称通过。

有效sample（pid70547，16:20:53，snooker-shot-r1-sample.txt）主线程91/93样本在RunLoop等待，后台solveSnooker→engineCell→simulateMixedWithLocalPockets/LocalPocketSimulation运行；足以否定该采样窗口主线程死循环，不能推断整段耗时占比。进程footprint494MB、峰值740.4MB为模拟器采样值，不代替设备测量。求解超时后向本轮xcodebuild69951发送SIGINT停止无意义的后续未就绪操作，日志TEST INTERRUPTED，原始证据保留。

后续优先W07真实批量求解性能，防守整页未验收。新接口已编译且两个模型测试通过，gate/session94460终态0，doc-size/diff通过；不可用它们代替UI全流程。

中断收尾：session27164终态2，采样session60488与截图session4039均终态0；本轮无存活句柄。未把忙碌截图或中断结果计作完成。

防守优化构建对照：snooker-optimized-r2实际UI77.178s通过，求解约40.46s；沿杆/击球/恢复三张原图已核，首次完整实际流程通过仅限-O无覆盖率构建。普通Debug超时仍保留，真机性能未验。W07继续同输入候选去重复测，未把编译选项当作产品性能修复。

W07去重后防守实页snooker-dedup-r1通过78.639s，恢复图74D21DD5已核。优化编译下完整防守流程已有证据，但UI点击至截图40/42秒含AX等待，不作纯求解耗时结论；后续需内部计时，性能仍未通过。两次运行均终态0，无存活句柄。

- DR-262补充（2026-09-13）：W13三页3D打点面板复用FreePlay现有usesCompactLayout，宽度取stage扣两侧Spacing.lg，底距Spacing.sm；2D使用原布局。PlanThree非开球3D底栏按现有角色行48pt+观察行topRowHeight分配，恢复台面空间。Silu的3D点球/点袋入口与另两页统一禁用，2D回切保留编辑状态。构建已通过，紧凑机实页复验中；状态文案与完整W13尚未验收。

compact-controls-build-r1构建成功；compact-controls-ui-r1实际完整流程48.071s，只有新增尺寸断言失败：spinPad.card返回40×40子按钮。已导出并查看F771B194原图，确认横向打点盘与缩短底栏真实出现，母球可见；不能用该图替代尺寸验收。BTSpinPadCard增加accessibilityElement(children:.contain)保留子按钮并建立卡片容器，r2复验中。gate-r1终态0，针对容器修改前版本。

compact-controls-ui-r2/session29445终态0：实际1项47.570s、0失败，完整求解→3D打点面板开关→打一→①进袋推进→上一杆→2D通过。尺寸读取修正后断言未放宽；已直接查看CBB48387打点图与CA641009返回图。gate-r2/session89860终态0。仅证明SE打三该流程；Silu/Snooker同类面板流程、编辑状态提示、③实际推进和其他设备仍待验证，W13继续进行中。

## 三页面板流程补齐与编辑提示（2026-09-13）
compact-controls-remaining-r1/session55168终态0，实际2项/0失败/128.940s：思路49.310s、防守79.630s，均实际求解→沿杆观察→面板打开/尺寸/关闭→击球→上一杆→2D。已查看848D2E94与BC3AAE43两张面板原图，母球可见、面板横排。加上打三r2，仅三页SE该流程有证据；不代表全设备或面板数值编辑验收。

编辑提示采用不依赖模式的明确指令：在2D中选球/选袋/画约束/补回母球，保留进袋、窗口前滑、计划保留和上一杆等事实；不引入模式切换时刷新业务状态。此文案修改晚于上述测试二进制，构建单独运行edit-hints-build-r1，不能声称截图已含新文案。下一步验证打三实际③角色推进、开球分支与跨尺寸，W13仍未整体完成。

edit-hints-build-r1/session40745终态0且BUILD SUCCEEDED；edit-hints-gate-r1/session76145终态0，doc-size/diff-check通过。全部本轮工具句柄已终态。新提示文案实际页面截断/可读性仍待跨尺寸复验。

## 规划页3D开球（2026-09-13）
Silu/PlanThree此前未向已有BreakInstrumentsOverlay传isPerspective，导致3D开球仍用2D投影布局；两调用补isPerspective:is3D，无新组件/物理参数。planning-break-r1/session4075终态0，实际2项/0失败/71.897s：打三36.710s、思路35.187s。真实15球选择→3D紧凑面板尺寸/关闭→开球→停稳→完成→保持3D→2D编辑。已查看041C44F4/F8C29153面板、DAD25B92/CC11188A交付四图；面板透明区域仍覆盖部分近端台面，不能声称全视角避让通过。planning-break-gate-r1/session61324终态0。

新确认待处理：开球共用statusText在3D仍说拖屏调方向/拖母球，与cameraControl和禁拖球入口不一致；应让提示说明3D瞄准轮及2D摆位，避免改手势来凑文案。取消开球仅boardBeforeBreak恢复球位，当前start会清约束，完整规划草稿恢复缺口由源码确认，尚未做实际取消前后对照。③角色推进仍待实测。W13不标完成。

## 取消开球保留规划（2026-09-13）
根因：startBreakFlow清约束/选择/解，cancel又loadBoard当新球形重置。改为开球期间保留VM规划数据，仅清可视化；保存球位与原透视状态，取消时恢复球位并重画原约束/当前解，确认完成仍loadBoard新球形。start禁止求解计算中进入，避免旧求解回调跨开球；两页绘制覆盖层增加!isBreakMode，保留activeTool不会拦截开球手势。
break-cancel-state-r1/session10875终态0，实际2项/0失败/1.344s：现有全字段恢复样例追加真实start/cancel，原角色/约束/解/参数断言未改。解为既有snapshot fixture，只证明状态保留，不证明物理。break-cancel-ui-r1正在验证打三已有twoBallDimmed草稿→开球取消→完整求解/击球/上一杆，未预支通过。

break-cancel-ui-r1/session3558终态0，实际1项/0失败/52.724s；已查看89B02D2D取消恢复原图，①②角色/袋/落区保留，后续真实求解/3D击球/上一杆/2D通过。gate/session29923终态0。思路取消实页、取消时相机矩阵、计算/播放中取消仍未验，③推进和3D开球提示继续待办。全部本轮句柄终态。

## 思路3D取消与开球提示（2026-09-13）
BreakFlowRunner新增statusText(isPerspective:)：仅racked且3D返回瞄准轮/2D摆位指引，其余保持原statusText。四个现有消费者FreePlay/Composer/Silu/PlanThree传当前is3D，避免只修一页。Silu完整UI追加真实3D开球→核对瞄准轮提示→取消→保留求解能力与3D→完整求解/击球/上一杆。silu-cancel-hints-r1验证中；实际取消规划恢复仍以新结果为准。

silu-cancel-hints-r1/session45206终态0，实际1项53.776s/0失败。3D开球提示断言、取消保留3D与原落区、继续真实求解/击球/上一杆/2D通过；A4DF386F恢复原图已查看。gate/session90429终态0。只验证待开球取消，未覆盖正在计算/播放时取消或完整相机数值矩阵。③推进与跨尺寸仍待办，无活跃句柄。

## 三角色实际推进（2026-09-13）
新增threeBallDimmed初始盘面（已有twoBallDimmed加第三球），通过既有deeplink.planThree进入；不预置解、不跳过物理。角色按钮补可访问球号值及planthree.role.<rawValue>标识。three-roles-r1/session3984终态0，实际1项32.532s/0失败：①②③=1/2/3，真实求解/打一后=2/3/空，②袋清空；上一杆恢复1/2/3与击球能力。已实看24DFA3DE推进、2BB48B1F恢复原图，①袋迁移的视觉高亮与旧②袋一致；具体索引另有既有模型测试。
门禁r1/session23845失败于PlanThree测试场景路由签名。审计确认只有该文件签名变，移除threeBallDimmed token后精确还原旧hash，生产导航未变；只更新对应签名并在route-coverage.csv补本测试。r2复验中，未改门禁逻辑。W13后续中途取消/跨尺寸仍待验证。

three-roles-gate-r2/session16146终态0，doc-size/diff-check通过，无本轮活跃句柄。

iPad-planning-r1/session95959终态0，实际3项32.757/54.553/77.102s通过；三张关键原图已直接查看。取消在busy时UI禁用，撤销将“中途取消”视作待新增能力的范围推断。W13按真源三页完整流程标准本地验收，见W13-acceptance；性能归W07，完整平台矩阵归W16，完整目标保持进行中。
