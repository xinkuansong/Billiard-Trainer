# W09 页面接入验证（进行中）

真源：问题集合_v63.md §8 W09。W08尚有跨帧率世界状态/慢放等验收缺口，本表记录可独立推进的页面验证，不以页面通过替代物理/回放完成。

## 当前实现
- FreePlayView已有2D/3D切换、观察目标、回瞄准、3D布局与开球观察衔接；每日清台独立属W15。
- ShotSimulationView已有分离角与走位3D试点。
- 本轮不新增玩法，不继续调整导出取景参数。

## 验证矩阵
| 项目 | 当前证据 | 待补 |
|---|---|---|
| 标准手机15/9开球、观察、打点、2D/3D往返、续打/重打/取消 | 首轮失败；seed-r1完整流程通过，详下文 | 旧失败重现、固定慢种子及后续验收 |
| 标准手机自由/进袋、观察、前后台、打点、出杆/回放往返 | standard-r1分离角流程通过 | 其他尺寸与可见性范围 |
| 紧凑手机 | compact-r1两流程通过；DR-240复验见下文 | 横排面板其余状态、开球慢计算 |
| iPad | 专用11A0F6DD-5F06-454E-B4A4-57710E598FC3当前关机 | 同操作及面板避让 |
| 母球入袋后原有处理 | 尚无本轮完整页面证据 | 落袋后状态/继续与复位 |
| 真机触控与性能 | 未验 | 属W16仍保留 |

标准运行使用EC19B1C4-AFE2-4E9E-B12C-1A2FDC6415DC隔离模拟器，保持其他任务模拟器不动；本机多模拟器同时启动，不能以本轮墙钟时间当真机性能。

## 标准手机首轮结果
- w09-standard-r1/session88761终态65，2项中1失败：自由击球137.529s，分离角3D完整流程90.259s通过。
- 自由击球15/9开球均走到确认/交付，失败发生在之后切自由瞄准等待击球可用（30秒），没有执行后续散局续打/取消，不可算整条通过。
- delivered-9-3d-402截图已查看：交付时页头“求解中…”，按钮禁用。不能仅凭这张较早截图断言超时时仍在求解或已有无解结果。
- 源码launchSolveIfIdle在旧后台计算结束后才补跑最新请求；是否旧反解/翻袋计算拖住自由模式尚待实证，未修改生产求解器。
- 增加waitEnabled失败前截图和页面树附件，不改变等待上限或断言。w09-disabled-r1/session97199正在重现该流程；下一轮先poll该句柄，不重复启动。紧凑/iPad暂缓，优先处理已复现的标准流程阻塞。

## 二次复现与3D错误提示遮蔽
- w09-disabled-r1/session97199终态65，1项失败，提前停在9球开球确认等待。样本sample/session39879终态0，现场没有持续物理求解栈，不能支持“旧计算拖住”的初始猜测。
- 2D breaking-9截图76B67196-C131-4A52-A404-A4965CCCECD1.png明确显示“本次开球模拟未完成，请调整击球参数后重试”；3D截图却显示固定操作提示。完整附件保留disabled-r1-all，超时截图/页面树已新增并实际生成。
- 确定根因：FreePlayView.navigationStatusText只看3D+racked，覆盖BreakFlowRunner返回racked后的失败提示。生产新增simulationFailure记录具体停止原因；仅无失败的racked显示3D操作提示，成功/重摆清除失败。原开球数值失败未解决，首轮散局续打超时仍需分别追踪。
- w09-failure-status-r1/session23192编译运行中，但选择器误写BreakCompletionV63Tests（实际方法在BreakFlowRunnerV6Tests扩展）；即使绿也不能算执行。结束后必须用正确类名test-without-building，不重启编译。

- DR-239验证：w09-failure-status-r2/session45354终态0，实际1项/0失败/16.164s，失败原因保存、成功清理和重摆清理断言通过；gate/session45934终态0，doc-size与diff-check通过。修复后实际3D失败现场尚未重拍。开球初始seed来自随机值，需在下一次失败时记录seed及击球输入才能固定重现数值失败，不能把前后不同结果归因于一次代码修改。当前全部句柄终态。

## 开球输入诊断与成功对照
- BreakFlowRunner.breakNow仅DEBUG使用NSLog记录不可变输入和结果：seed/game/surfaceY/cue/aim/power/spin/termination/duration。没有修改模拟参数、随机规则或成功条件。
- w09-seed-r1/session33019终态0，真实自由击球完整UI流程通过（见原日志确切时长）。15球seed1618622848438816929、aim=(-1,0,5.025017e-05)；9球seed7636693507816629570、aim=(-1,0,-1.1578792e-05)；均cue=(.635,.828575,0)、power6、spin0、surfaceY.8。两次termination均settled，物理时长7.41195/7.861883s。system日志在seed-r1-system.log。
- 之前两次失败仍有效，不能以本次随机输入通过称已修复数值或续打问题。sample/session3995终态0，后台在PositionPlayShotSolver→simulateMixed→局部接触；但本次最终已完成，不能称死锁。采样时截图已进入后续开球选择sheet，并非失败现场；文件free-shot-stall-r1.png的名字只是采样时猜测，不能作为卡住证据。
- 当前所有句柄终态；需保留随机输入差异，继续收集失败输入并补紧凑/iPad页面范围。

## 紧凑SE流程与截图审查
- 专用iPhone SE 3rd/iOS26.3模拟器已启动（bootstatus/session1654终态0）；compact-r1/session46940终态0，实际2项/0失败：自由击球129.091s、分离角88.811s。复用已编译当前产物test-without-building，seed日志另存compact-r1-seeds.log。
- 真实查看break-spin-9-375.png及附件D62F42DD-AE81-4992-B800-29947448F37A.png（分离角after-spin）：两个3D页面的大打点盘均遮住母球（后者只露球顶），虽微调/回中/击球控件可达，仍违反W09“面板不挡母球”要求。因此本轮不能标布局验收通过。
- 根因范围：BreakInstrumentsOverlay、FreePlayView和ShotSimulationView沿用BTSpinPadOverlay底部大十字盘，3D只按全屏宽计算，没有考虑投影母球或可用高度。需共用紧凑呈现/避让设计，不能仅改某一张截图位置。iPad验证仍待执行，不把SE通过断言当视觉通过。

## DR-240 紧凑面板复验（2026-09-13）
- compact-pad-r1已终态65，非运行中：自由击球失败99.286s；分离角完整3D流程通过88.342s。日志：output/3d-v63/W09/compact-pad-r1.log，xcresult同名。
- 本次直接查看附件compact-pad-r1-attachments/C5300EE7-B59F-4E73-A317-6146F950E16F.png（after-spin）：横排面板位于母球下方，母球完整可见，方向微调与回中内容未截断。仅证明该SE机位；任意观察姿态、标准手机、iPad及2D回归仍待验，DR-240保持验收中。
- 自由击球失败输入已保存于compact-pad-r1-seeds.log：seed=844924979980821639，中八，surfaceY=.8，cue=(.635,.828575,0)，aim=(-1,0,-1.4691563e-05)，power=6，spin=(0,0)。DEBUG开始10:48:46.424、结束10:49:46.919，耗时60.495秒；termination=settled，轨迹时长8.990101秒。超过UI等待上限，不能归因为按钮无效、死锁或未完成终态；也不能据模拟器Debug推算真机性能。
- 后续优先级：保留此固定输入用于优化构建性能验证；继续常见手机流程与标准/iPad面板检查。不得以增加测试等待上限代替性能处理，不恢复捕获后的袋底堆积探索。
- 本次仅核验既有结果并更新记录，未重跑测试、未修改App代码；此前未知种子的9球未完成与续打超时仍保持未解决。

## 标准手机DR-240及2D页面复验（2026-09-13）
- standard-pad-r1/session18446终态0，重新编译当前工作区：testShotSimulation3DPilot通过90.389s，testShotSimulationLayout通过19.858s；实际2项/0失败。使用隔离标准手机EC19B1C4-AFE2-4E9E-B12C-1A2FDC6415DC。
- 原始证据：output/3d-v63/W09/standard-pad-r1.log/.xcresult；附件目录standard-pad-r1-attachments。本轮直接查看D1FB3530-FABC-48C1-B6EF-D7A3DF5355DD.png：展开横排打点盘时母球完整可见，低杆/回中操作断言通过；仅此机位，不外推任意观察角度。
- 2D图33B915F7-3B52-4E96-B64F-C681CD4A8F42.png已查看：完整球桌、球体和底部球号选择显示，未见布局截断；截图仍处于“求解中”，该布局用例不等待结果，因此不是2D完整击球或求解性能验收。3D用例另覆盖击球后切2D、回放及重打。
- iPad和自由击球未在本轮执行；前述SE固定慢开球、未知种子失败均保持未解决。没有本轮App代码修改。

## iPad复验与固定慢开球（2026-09-13）
- ipad-pad-r1/session18174终态0，实际两测通过：分离角3D流程93.107s、2D布局19.500s。独立iPad mini模拟器11A0F6DD-5F06-454E-B4A4-57710E598FC3，content_size回读large。
- 已直接查看ipad-pad-r1-attachments/C7DBFB54-E293-4A84-90FA-43C881AAC4C4.png及8C32EE4C-90FE-465B-BDFB-4C5BECAC80EB.png：3D横排打点盘与母球分离，主要操作和底栏可见；2D球桌、球号栏完整，但处于求解中，仅证明布局。分离角标准/SE/iPad既定展开机位已具图证，自由击球跨设备、任意相机姿态仍不据此完成。
- 新增BreakFlowRunnerV6Tests/testRecordedSlowFifteenBallBreakCompletes，逐字复用SE慢计算输入，经真实BreakSimulator默认入口验证settled、16球去向及捕获尾段存在，同时输出计算耗时；未添加机器相关性能阈值。
- recorded-break-optimized-r1/session97001运行中：Release配置+DEBUG测试接口+-O优化，独立ReleaseDerivedData，经Makefile入口编译并运行上述单测。此为优化测试构建，不是真机或发布构建验收；下一步核对该句柄、真实执行数与耗时，不重复启动。

## 固定慢开球优化结果（2026-09-13）
- recorded-break-optimized-r1/session97001终态0，实际1测通过3.655s；内部BreakSimulator耗时3.620782s，termination=settled，轨迹时长8.990101，与Debug现场记录一致。16球去向及捕获收尾断言通过。
- 该证据支持先区分编译优化开销；没有改动物理求解或添加结果特例。Debug现场60.495s与优化单测3.62s处于不同宿主负载/渲染环境，不能作精确倍速基准，更不能外推真机达标。旧未知种子未完成/续打超时仍未解决。
- ipad-freeplay-optimized-r1/session74830正在运行：复用本轮已编译优化测试产物，在独立iPad执行S1_FreePlayLayoutUITests/testPerspectiveBreakAndContinue。结果未出，不预支成功。

## iPad自由击球优化产物实页结果（2026-09-13）
- ipad-freeplay-optimized-r1/session74830终态0，真实1项完整UI测试通过108.129s，包含15/9开球、观察/回瞄准、打点、模式往返、确认交付、续打/重打及取消；不是固定慢种子的UI复现。
- 已直接查看附件FB36FFEF-CA28-45F4-A9D5-39BAB136ADE6.png（9球展开打点盘）和8ADD115A-317B-4366-9433-589799EBEE3D.png（9球交付散局）：前者母球完整且底部开球/取消未被面板挡住；后者为真实散局，母球可见。未据此断言任意散局都无遮挡或母球落袋规则已验。
- 实际输入及结束日志保存在ipad-freeplay-optimized-r1-seeds.log：中八seed11113387777738692143，aim.z=-2.2405717e-05，计算1.202s，轨迹6.78329s；9球seed895355641253986313，aim.z=-5.011247e-05，计算.505s，轨迹8.789527s；均settled，cue=(.635,.828575,0)、power6、spin0、surfaceY.8。此为优化模拟器产物实页时间，不是真机基准。
- 目前所有本任务句柄终态。下一步补母球入袋后原有处理、自由击球标准/SE当前横排完整流程及W08跨时间消费者一致性；保持W07/W09未完成及旧失败有效。

## 实时/上一杆回放收尾审计
- DR-241：发现launchBalls和runPlaybackAnimation仍是母球动作+旧Task.sleep，已按全部球实际时长聚合修正；空间收尾不重复等待，旧记录兼容保持。
- live-tail-r1正在执行共享收尾单测及分离角真实3D流程。尚未宣称母球落袋规则实页通过；该路径需在此时序修正后继续补验。

- live-tail-r1/session79600终态0：共享空间收尾实际1测8.561s通过，分离角实际3D击球/回放完整UI1测89.315s通过。证明既有操作链路未回归；不是专门的母球进袋页面或任意时刻世界坐标一致性验收。doc-size/diff-check通过，gate见live-tail-gate.log。

## 母球落袋场景生命周期（2026-09-13）
- 新增CueScratchLifecycleV63Tests/testScratchPlaybackRedoAndPaletteRestoreAcrossViews，实际UIWindow承载SCNView，运行真实PositionPlayViewModel.play及replayLastShot动作，而非直接伪造落袋事实。
- 固定母球(0,surfaceY+R,-.45)，中心球力度1.5，瞄向现有中袋4；真实预测hasFinalTableState、cuePocketed及collectionTail均断言成立。
- scratch-lifecycle-r1/session38909终态0，实际1测12.467s通过：播放中切2D后只结算一次、ChineseEightBallRules返回ballInHand、母球离场；3D回放完成后仍离场且不再结算；重打恢复原位置；撤球后2D球库补球并返回3D，母球可见且opacity=1。
- 证明范围是模拟器真实动画/VM/规则链路，不是FreePlayView完整页面提示或真实触控验收。代码确认页面规则裁决后发自由球toast，3D底栏提示切2D，但落袋时实际提示与球库入口仍须页面测试。
- 本轮仅增加测试，没有修改玩法、产品入口或生产物理。原未完成范围保持。

## 母球补回页面缺口（FL-067）
- 源码审计发现真实FreePlayView.paletteBar拦截所有离场球，VM生命周期测试未覆盖此拦截。已修候选：仅非每日清台母球可点击补回，3D无母球提示切2D补回。
- scratch-page-r1/session99832正在标准手机运行真实UI测试，DEBUG固定输入仅准备球形与规则，不伪造落袋/回放/补球结果。未运行页面结果不能标完成。

- scratch-page-r1/session99832终态0，标准实际1项31.405s通过；scratch-page-se-r1/session36275终态0，SE同流程1项31.390s通过。真实页面落袋、回放、切2D点击paletteBall_cueBall补回、回3D提示及focus恢复均验证。
- 标准原图B6931FDF-58A2-41B3-B6C3-6A98DEE8093B.png与3EBD9717-04E3-484C-B55F-CEAF16E8077C.png已查看：落袋后母球离场、底栏指引可见，补回后母球与球杆出现；同时发现顶栏scratchPill挤压自由切换和gamePill，按钮换行、比分省略，需另修布局，不能标W09视觉全部通过。
- SE落袋图2EE4160C-35DA-4B88-BBA6-358C3BEA765B.png本轮已打开。所有证据位于各scratch-page结果附件目录。FL-067补回入口功能两尺寸通过；落袋状态顶栏布局继续待修。

## DR-243 落袋顶栏紧凑呈现
- 以落袋提示替代瞄准胶囊，模式和警告保持单行；gamePill显示玩家名称，省略重复“轮到”，accessibilityLabel保留完整含义。
- scratch-header-se-r1/session33966终态0，实页1测31.298s通过，但原图仍截断玩家信息，未作为视觉通过。r2/session55998终态0，实页1测31.055s通过。
- r2原图6C086989-DA3C-415F-94C8-4BEF1B2B2389.png已直接查看：自由、母球进袋、开放局/玩家B均完整单行，补球指引可见。未提高顶栏高度/缩小全局字体。标准最终版本及更长比分/最大字号尚待验证。

- DR-243标准最终复验scratch-header-standard-r1/session74314终态0，实际1项31.889s通过；A93758A3-4589-4A3D-9927-47F8B3D77773.png已查看，三个胶囊完整单行，补球指引可见。标准/SE固定落袋状态已具最终图证，长比分及最大字号不外推。

W15共享开球栏回归：manual-r4中S1_FreePlayLayoutUITests.testPerspectiveBreakAndContinue实际105.177s通过，紧凑SE 15/9球真实开球、面板/观察、2D往返、交付、继续击球、重打与四球开球取消恢复；取消默认行为保留。证据位于output/3d-v63/W15/manual-r4.xcresult；本轮图片仍待逐项核验，不据此宣称完整W09视觉验收。

W15/manual-r4旧证据补审：已导出到output/3d-v63/W09/manual-r4-review，直接查看2DE01428（9球交付）与9DA4767A（取消）。母球/散局及取消恢复可见；9球交付截图gamePill显示“追分0:0｜玩家A 0…”且省略尾部，确认常规SE比分状态仍有信息截断，不能用DR-243固定scratch图验收一般比分。下一项应修复该胶囊信息布局并用实际页面复验；不能把功能测试通过当视觉通过。

DR-273候选：gamePill从固定单行改为ViewThatFits横排/两行；比分与玩家原文保留，46pt顶栏不变。score-layout-r1/session71745实际SE 15/9球开球→交付→继续/重打/取消验证中。改前图为manual-r4-review/2DE01428；必须审查改后图才能接受。

DR-273复验：score-layout-r1/session71745终态0，SE实际15/9球开球、模式往返、交付、继续击球、重打与取消1项102.817s通过，无确认超时。CAC5CA18九球/D7465C22中八原图已直接查看，比分和当前玩家完整两行，原46pt顶栏内无越界。gate/session94944终态0。仅接受SE普通字号这两类状态，宽屏横排/更长比分仍待验证。

DR-273 iPad复验：score-layout-ipad-r1/session92487终态0，实际1项127.817s通过，15/9球开球、交付、续打/重打/取消及2D/3D往返。simctl读回large/light；F564ED35九球与010755C7中八原图已查看，两状态比分/玩家完整横排，位置正常。附件output/3d-v63/W09/score-layout-ipad-r1-images。与SE两行证据共同覆盖宽窄布局，未证明所有长比分或最大字号。


当前版本iPad分离角与走位复验：shot-ipad-final-r1/session59957终态0，S2_ShotPagesLayoutUITests.testShotSimulation3DPilot实际1项91.469s/0失败。覆盖进袋→四观察模式→近袋低角度→自由模式→前后台→模式往返→方向/低杆输入→击球中切2D→回3D回放→重打。simctl读回large/light，但页面原图为深色专用台面UI，不能据此声称所有Light外层页面验收。
已直接查看after-spin(2FB20F6F)、after-replay-3d(1B2A0E39)、low-close(42DBEFF4)原图：打点面板未挡母球和右侧击球按钮；回放重打回到准备态。低角度近袋确为手动局部观察，目标球被右侧视口裁切，不能将这张图当作全桌可见验收；未发现相机穿入桌体。截图中的60FPS只为模拟器显示，不作为设备性能证据。所有附件见output/3d-v63/W09/shot-ipad-final-r1-images。W09的跨尺寸/最大字号与W16真机仍另验。

## DR-284 / FL-071 — 3D开球失败提示被普通说明覆盖（2026-09-13）
- current-se-ax5-r1/session69731 exit65：SE/iOS17/AX5两条实页流程，开球流程128.875s失败、母球落袋/补回26.914s通过。15球已完成散局交付，9球默认8.0求解失败后无法确认；失败截图CC4206FD及AX树6A51AF0A显示普通操作提示，错误未显示。不是等待时间不足。
- 系统日志current-se-ax5-r1-break-system.log给出9球seed=17829163102452725902、cue=(.635,.828575,0)、aim=(-1,0,3.304183e-05)、spin=0；终态failed(penetration(0.0011684512086055138))，模拟时刻0.34930834。15球seed=4712397786635757473正常settled，未把同一流程的9球失败抹掉。
- 反馈根因：statusText(isPerspective:)只看racked便返回普通文案，acceptCompletedSimulation失败也回racked。修正为仅simulationFailure==nil时替换；保留原错误和未完成禁止交付。
- failure-feedback-r1/session9303 exit65，实际2项3.200s：未完成开球保持球架/禁止确认/2D与3D均保留失败提示测试2.404s通过；新增真实种子测试0.796s失败，精确复现上述穿透值/时刻。原断言与失败证据保留；没有降力度、换种子或扩大容差。
- 状态：反馈映射修复已构建及状态验证，修后真实失败页截图待补；物理穿透未修，W09不能接受当前完整开球范围。W07既有10失败之外增加独立9球实页回归，不能称全部基准只有10个问题。所有句柄终态。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-284组件契约/Changelog。下一步定位固定种子穿透涉及的球与接触阶段；不返回袋底堆积研究。

## DR-285 / FL-071 — 球体触及袋口窗口时接管（2026-09-13）
- 固定9球失败源定位：nine-ball-contact-source-r1/r2实际各1项失败。交接初态t=.34930834149434303、p=(-1.2414212226867676,.8285750150680542,-.49699997901916504)，直库鼻边三角面13888–13895距离已小于球半径约1.35–1.41mm；projectContactPositions第一轮修正1.168mm超过原4µm预算。不是袋底/收集尾段问题。
- 根因与修正：旧局部窗口只在球心越界时接管；改为中心域半径=原窗口半径+球半径，保守覆盖球体前缘到达窗口的时刻。全桌接触网格覆盖此边界，未改实体网格、恢复系数、捕获面或容差。临时穿透打印已撤去，原诊断日志保留。
- nine-ball-ownership-r1/session88220 exit0，原失败种子实际1项2.678s，settled，模拟时长16.162428s。
- regression-r1/session88931 exit0，实际6项7.243s：原9球种子、原15球种子、另一慢15球、全桌几何覆盖、任意时刻续算、正常进袋；原9球全部5次进入交接按完整实体网格检查，重叠不超过原4µm预算。
- final-r1/session58995 exit65：实际PhysicsEngineTests41项出现原10方法及新增低力度勾球前提差异（11失败方法/22失败断言）；SE/iOS17/AX5实际15/9球开球→交付→续打/重打/取消完整UI 1项92.369s通过。01059FE9、80B9986F、2F4850D4三原图已审：球形交付、比分和操作可见。随机UI球架与固定失败种子测试分别记证，不冒充同一输入。
- 新增差异核对：low-power-kick-current-r1/session79474原断言1项2.289s失败，输入杆头速度.6实际母球初速约.923，右库后t=3.1890607有真实球球事件。旧测试把.6无条件当作必然不足不成立。保留该输入为新物理见证测试；原“不足力度不接触”断言保留，输入改.1并增加空桌无碰库/完整停稳/最大行程小于目标可达距离的前提检查。不是生产降力度或删原失败证据。
- low-power-kick-premise-r1/session81038 exit0，实际2项2.209s；.6碰库后记录球心间距.05715998m，与2R在10µm内一致；.1行程前提及未接触断言通过。其余原10物理失败尚未裁定，不标W07完成。
- gate/session95245 exit0；所有句柄终态。FL-071固定9球穿透与反馈映射本地修复，跨设备/性能及完整W09仍待核。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-285；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。
