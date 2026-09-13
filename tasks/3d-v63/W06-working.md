# W06 工作记录：局部空间接管与多球调度

状态：进行中，尚未满足 W06 验收。真源为问题集合_v63.md §5.3–5.4、§8 W06。

## 已实现的接触基础

CollisionResolver.swift 的 SpatialBallContact 提供相对重力下球球连续检测、保留三维速度的等质量球冲量，以及多球/静态面的联合冲量。普通平面解析与原碰撞器尚未替换。

firstContact 使用 B-A 相对坐标，返回 A→B 法线；Constraint 法线则为 B/静态面→A。调用者必须显式转换。持续接触与几何穿透修复不由该球球首次接触函数提供。

## 真实测试记录

- spatial-contact-r1：3项通过；竖向碰撞、高度错开、高速CCD、动量/角动量/能量和摩擦锥矩阵。
- coupled-contact-r1：5项通过；新增下落球与受支撑球、自由双球对拍及对称三球。
- separating-support-red-r1：1项4断言失败。上球向下1m/s、下球向上2m/s且刚离开支撑，错误联合响应把单位质量动能2.5变成约4.5。原失败证据保留。
- 修复：初始法向相对速度大于零的接触不参与本次冲量；响应后新变为接近的接触必须在同一绝对时间重新调度。不能把本次接触子集当成整个时刻的最终结果。
- coupled-contact-r2：构建失败，物理测试未执行。SettingsView.roomStyleSection 的Swift类型检查超时；等价抽取roomStyleRow后进行r3，不修改风格选项、布局或选择行为。

- coupled-contact-r3：构建及6项测试通过，0失败；原能量反例修复，主调度尚未接入。

日志与xcresult位于 output/3d-v63/W06/。

## 接入仍须完成

1. 静态袋口几何的运行时所有权/缓存与注入，避免每次预测依赖创建UI场景。
2. 在支撑变化前连续检测进入局部区域；主事件时钟协调局部与平面事件，失效受影响缓存。
3. 多球局部接触、同时间接触重建、真实高度球球检测、返回/重入与能量检查。
4. 主引擎当前仍有平面越界约束与吸袋清零，不能把独立单球尾段追加到其结果冒充完整接管。
5. W05自主单球静态休眠不能直接用于有外部球的调度器。跨域碰撞可唤醒原本静止的球。

W07负责统一旧捕获/兜底/预测/规则；W08负责各消费者空间播放。W06尚未接入主引擎，更未证明App自然进袋修复。

检查点：verify-gate-contact与verify-doc-size-contact通过；本轮修改文件scoped git diff --check通过。无存活测试进程。下一步仍为主时钟接管、同时间接触重建与返回/重入验证。

## 同时间接触闭环

SpatialBallContact.resolveInstant接收完整几何接触候选，在固定位置/法线下反复调用联合响应，检查每轮产生的新接近接触；沿用联合求解1e-11速度尺度残差，不制造正时间步。返回逐轮响应供诊断，预算不足抛convergence而不返回未处理完的状态。

instant-contact-r1：完整7项0失败，新增两轮响应的最终速度、每轮能量不增、反转约束顺序一致及预算不足明确报错。标准模拟器Debug构建通过。该闭环仍需接入主引擎事件时钟，并由几何检测提供完整候选；不能将调用者缺少接触的输入视为安全状态。

## 静态几何入口

DR-156增加独占节点树解码入口，scene包装委托该入口。geometry-injection-r1八项0失败：角袋/中袋与原路径逐顶点、材质、ID完全相同，输出不持有节点引用，非法坐标拒绝；七项空间接触回归通过。没有改变实际几何/台呢对齐或渲染。

剩余：无场景资产初始化仍需同源bedY测量与明确缓存所有权；当前测试用scene获取标定参数，再用独立树解码，不能算完全无场景初始化证明。主事件时钟、接管/返回、多球全流程未接入。

## 无训练场景资产初始化（已验证基础）

PocketGeometryAsset.load直接使用TableModelLoader加载独占球桌树，沿用setupTable的surfaceY定位，通过MobileClothAlignment新增静态树测量入口获取bedY，然后解码六袋。进程级锁仅保护初始化，缓存纯数值不可变快照；没有节点引用进入缓存，不受2D/3D观看选择影响。解析失败向调用方抛出，不缓存失败。

geometry-asset-r1验证六袋逐顶点/材质/ID及高度与场景一致、重复load返回同一数值资产对象；同时运行既有静态入口与空间接触回归。此入口还未由主引擎消费，不代表W06结束。

geometry-asset-r1终态：构建成功，9项0失败。主事件接管、平面返回、多球全流程仍未完成。

## 局部运动区间与跨轨迹CCD

LocalPocketSimulation.Result新增accepted intervals，每段保存经支撑处理后的起态、线/角加速度及右端冲量/投影后的状态。sample可分别查询右端碰前左极限与碰后状态；只有接受的两半步进入结果，拒步不泄漏区间。静态休眠段显式保存零加速度区间。

local-interval-r1十三项0失败，包含7项接触、5项局部求解与碰前/碰后采样闭式测试。原物理演进未改变。

firstPairContact以双指针合并两条已接受轨迹的重叠绝对时间区间，使用各段实际相对加速度做球球CCD，返回碰前状态。只负责检测；碰后必须作废原未来区间并重新求解。分段端点的同时静态冲量仍需由主调度完整接触集合统一处理，不能把独立预测的静态碰后状态直接当成联合结果。

interval-pair-r1终态：十四项0失败，包含不同步长绝对时间球球CCD。下一步应消费这些区间进行最早事件截断/联合响应/未来重算，再接主引擎；W06仍未验收。

## 多球最早事件截断与重算

advanceTogether对局部球预测同一时间窗，选择最早球球接触；按该时刻碰前状态重建球球与静态面候选，调用resolveInstant，返回已截断区间与碰后状态。调用者从返回时刻再次调用，原未来预测不进入结果。

coupled-advance-r1十五项0失败，新增下落球撞受台面支撑球的7.2s接触、反弹后重算到7.25s闭式位置/速度及无未来区间泄漏。该API仍处于W06开发中，尚未接入主引擎。

新边界：起始已接触且静止的两球需要持续球球支撑力；仅独立预测加瞬时冲量不能保证不穿透。pair-support-red-r1正在用精确竖直双球静止平衡验证此缺口。不得以瞬时碰撞案例通过代替持续接触验收。

pair-support-red-r1终态exit65：1项2断言失败，上球y=0.2875而非0.3，vy=-0.5而非0。下一步必须补持续球球支撑，不应直接接主引擎。无存活测试进程。

## 持续接触力基础

DR-159：resolveSupport提供法向互补/曲率与静动摩擦联合力求解。support-force-r1九项0失败，静态双球传重、分离无力、滑动耗散、曲率脱离及原七项接触回归通过。

尚未将力接入advanceTogether，pair-support-red-r1仍为真实未修复的演进失败。下一步需在共享时间步中重算持续力并控制误差，保留原静止断言，另验滑动/分离/曲面变化；不可把原重力简单整体替换为力级结果并让静态面再算一次造成重复施力。无存活测试进程。

## 持续力演进接入

advanceTogether按maxStep刷新持续力，转交的只有球间力/力矩，台面反力由每球原求解器计算。externalAngularAcceleration默认零，参与局部迭代与区间记录。

pair-force-integration-r1：18测1失败，位置/速度通过但伪碰撞在0.005s提前返回。r2收紧力残差并处理严格舍入界内的零时刻根：18项0失败，原静止双球反例完整通过，未修改断言。r1失败证据保留。

下一步：移动接触的法线变化、漂移修正及跨球共同步长误差验证；现按maxStep刷新不等于已证明共同积分误差。各球临时求解器会重建索引，性能仍需处理。主引擎接管/返回、多球近袋实际网格场景尚未接入。无存活测试进程。

## 移动接触漂移

moving-support-red-r1一项三断言失败，三档步长末球心距0.19217/0.19009/0.18896m。步间漂移丢失接触，减步本身未解决。

DR-160：持续力计划返回压力接触引用；步内这些球对使用持续力，末态联合投影实际距离/法向速度，总位移超4*tolerance则整试算拒绝半步重试。pressure-projection-r1十九项0失败，原三档距离及收敛断言保留。

仍需检查：共同一步/两半步误差、机械能、压力在步内消失时的释放；当前步首压力不应无限延用。索引复用/实际袋口多球/主引擎接管返回未完成。无存活测试进程。

## 共同误差与能量

advanceTogether默认一步/两半步比较全部球位置/速度/自旋和碰撞时差，只提交接受的半步；rejectedTrials统计拒步。shared-error-r1因测试闭包缺return构建失败；r2二十测一失败，固定步长的相邻差单调前提在自适应下失效。保留原断言、显式固定对照useSharedErrorControl:false；默认路径另按预算收紧验证。

shared-error-r3二十项0失败。能量误差随1e-5/1e-6/1e-7预算收紧为约0.000337/0.000102/0.000051，均未增加能量；局部误差不代表全程误差。下一步失压释放边界、真实网格多球、索引复用与主引擎接入仍待完成。无存活测试进程。

## 失压释放与实际网格验证

pressure-release-r1未执行测试：并行渲染工作中的BakedTrainingRoom尚未被该次构建收录；当前项目配置已包含该文件，未改渲染实现，r2重建后脱离案例通过。

独立参考从等质量无摩擦双球的水平动量和机械能推导：L=2R，P=1，释放条件cos(theta)^3-6cos(theta)+4.5=0；对dt/dtheta积分得t=0.0987335019，随后自由运动至0.12s，上球(x,y)=(0.123938754,0.254006187)，下球x=-0.003938754，距离0.200176329。结果留在output/3d-v63/W06/release-reference.json。

release-reference-r1二十一项0失败：初始高速直接脱离符合自由落体，运动中脱离后位置符合独立参考（0.1mm预算），不同步长上限末距离约0.200170/0.200172。临时求解器改为复用不可变空间索引，保留原useSpatialIndex选择，不再每次刷新球间力重建索引。

real-mesh-coupled-r1正在验证真实角/中袋附近台呢支撑与球球碰撞，此案例不是完整自然入袋。

real-mesh-coupled-r1终态：一项0失败，角/中袋均通过接触时间、反弹速度、受支撑球高度与完整约束集检查。下一步实际两球入袋/接管返回与主引擎仍未完成。无存活测试进程。

## 两球接近同一真实袋口（诊断中）

新增testTwoBallsApproachTheSameRealPocketOnOneClock：两球从袋内侧0.13m、侧向±(R+5mm)以0.5m/s朝袋心运动，角袋/中袋，完整共同时间到0.35s。检查球间距离、机械能、事件和时钟；不预设两球必进。当前检查仅阶段末状态，完整连续最小间距与图像还须补充。

real-pair-entry-r1运行约129s仍未返回首个advanceTogether，CPU约100%；sample文件显示耗时在局部预测/三角面CCD，主动中止诊断，终态exit73/TEST INTERRUPTED，非通过。保留xcresult、日志及sample。

仅添加Debug低频进度诊断（共享128epoch、局部2048iteration），不改步长/阈值/断言；real-pair-entry-r2运行中，目的是确定时间停滞与减步位置。

real-pair-entry-r2：约108s主动中止，exit73；共享128epoch/局部2048iteration均未触发。采样指向单球run的自适应整步试算，补其32iteration低频时间/预算/拒步日志后启动r3，物理参数与断言不变。此前场景通过不代表本例通过。


## 真实入口与微小再接触根（2026-09-12）

r3已中止，非通过。诊断确认原0.13m入口角袋球初始穿透约0.772mm，自适应减步不能消除非法起态。r4的spatialResolution错误明确报告时间无法在位置精度上推进；run新增initialPenetration验证，超4*tolerance直接报错，防止非法起态无限拒步。

r5将测试入口移至0.15m，运行终态9测3处失败：角袋末球心距0.039204m，小于合法0.057146m；中袋起态最近距离比半径小约60nm，不满足测试1e-12严格条件；随后联合接触convergence残差3.7823e-5。中袋输入精度与求解失败须分开归因，未放宽断言。真实双球同袋口仍未通过。

tiny-root-red-r1独立反例已终态失败：初始接触、以1e-9m/s离开、相对加速度-1m/s²，2ns后应再次接触，但firstContact返回nil。DR-163以导数根划分单调区间，在[0,horizon]内二分隔离空间球球多项式根；不使用绝对时间去重，普通平面QuarticSolver未改。bounded-root-r1构建与18项测试通过（8区间、10空间接触），包括保留原断言的2ns反例。

real-pair-entry-r6正在使用原r5输入重验实际案例，仅改变空间球球求根。此前失败保留；主引擎接管/返回及W06整体尚未完成。


real-pair-entry-r6终态exit65：一项测试3处失败。角袋末球心距0.039517055m，仍低于0.057145999m；中袋起态差和convergence残差与r5相同。2ns根修复不是全部穿透根因。下一步在接受区间定位首次球间距离越界，审查区间衔接/压力约束和初始轻微重叠时CCD处理；不调整分离断言。verify-gate、verify-doc-size、受影响文件diff --check均通过，但不替代真实案例失败。所有本轮测试及门禁进程均已终态。


## 首次穿透区间（r7）
real-pair-entry-r7终态exit65，同样三处失败；新增接受区间边界诊断定位角袋t=0.0900689528427376。由记录的p/v/a独立代入得到投影前间隙+3.3477e-11m，单球静态位置修正后-3.3246e-10m。数值草稿保留first-overlap-projection.json。此证据确认至少一条穿透入口是单球修正跨过邻球，而非该区间解析自由运动漏根。

joint-position-r1实验：球球事件采样后、冲量前联合投影静态/球间单边几何，仅修位置不清零入射速度；总修正仍受4*tolerance约束。无事件试算若末态球间穿透超过机器舍入界，整步拒绝并减步，不接受穿透。正在执行18项基础回归及原真实入口案例；若仍停滞需继续处理接触衔接，不是最终验收。


joint-position-r1终态19测1失败，18项基础通过；角袋不再提前穿透，但99次事件只推进到0.091208s，触发原100事件守卫，中袋未执行。不是完成自然入袋。r2统一静态联合接触与单球求解器已有的小反弹处理：预测反弹高度不超过tolerance且重力向接触面恢复时，恢复系数置零；不改球球恢复系数或事件上限。正在验证。


joint-position-r2终态19测1失败，基础18项仍通过，真实角袋第31事件后convergence残差2.6429978859624436e-10。r3只增加失败输入诊断，终态相同，确认为resolveCoupled瞬时冲量失败（不是持续力）。接触仅3个：两球各一向上台面支撑e=0、球球近水平法线e=.9；完整Motion和Constraint在r3日志。已提取testNearRestingPairImpactWithTwoFloorSupportsConverges，near-rest-impact-red-r1执行中。未调整迭代数、残差阈值或原距离断言。joint-position-gate与doc-size通过，不替代真实用例失败。

near-rest-impact-red-r1终态exit65，一项一失败，0.049s稳定复现相同残差2.6429978859624436e-10。下一步直接用该三接触输入诊断联合冲量迭代，仍须返回真实角/中袋及完整W06。所有本轮进程已终态，无存活测试。


## 释放约束残差与持续接触转换
独立Python复算near-rest-residual-analysis.json：第0约束normalImpulse=5e-324（Double最小非零数），normalError=2.643e-10；原lambda>0条件误将释放约束当成承力接触。采用法向自然投影残差inverseMass*abs(max(0,lambda-error/inverseMass)-lambda)，原精度阈值先不变。complementarity-r1实际案例越过原失败后出现密集再接触及反复试算，主动中止并确认exit73；不记通过。

球球小反弹使用事件区间实际相对加速度及法线曲率估计恢复方向；预测分离高度在tolerance内时置e=0，随后持续力决定接触或释放。静态单球已有同类重力预算机制，未设固定速度阈值。

contact-transition-r1：20测3处失败，释放约束独立反例通过；新增极小反弹→持续支撑反例失败，冲量后残余接近速度约1.67e-11，下一调用立即返回同时间碰撞。确认冲量1e-11与持续力64ulp激活精度不一致。r2将冲量和同时间闭环收敛收紧至64ulp，同持续接触标准；原测试断言保留，验证中。

contact-transition-r2终态exit0，20项0失败；原两个新反例均通过。真实案例r8开始验证，未改原输入、距离断言或事件次数守卫。


real-pair-entry-r8测试终态：一项一失败，原100事件守卫触发（约244s），角袋反复接触每次约38ns，未到0.35s，中袋未执行；已走过区间未触发距离断言不等于完整无穿透。下一步提取实际事件后p/v/omega和持续力激活输入，定位为何未承接压力。contact-transition-gate/doc-size以及受影响diff --check通过，不能替代实际失败。


## 实际重复接触状态与压力投影量纲
r9仅增加状态打印，捕获第18事件后主动中止，exit73非通过。状态保留repeated-contact-state.json：球间隙2.29e-16m，法向相对速度-1.03e-14m/s，均满足当前接触激活范围。以该状态和单平面几何建立testCapturedSlidingPairKeepsPressureAcrossSharedHalfSteps；pressure-scale-red-r1两断言失败，0.1ms请求在约49ns后提前返回事件。

根因：projectPressure用max(位置长度,速度长度,1)共同检查米与米/秒残差，约1.38m的世界位置使法向速度标准比resolveSupport更宽。DR-166分别归一化位置与速度残差，速度采用相同的64ulp速度尺度。pressure-scale-r1构建及21项0失败，原短推进反例保留断言并通过。r10原实际几何/输入重验中，完整进袋仍未验收。


r10终态exit65，真实角袋约31.85s后抛iterationLimit；已越过重复接触段，中袋未执行。r11只增加压力/联合位置投影耗尽诊断，终态仍iterationLimit但无对应诊断行，不能归因于旧三角面投影。r12将时间分辨率守卫改为带stage/time/step的timeResolution错误，继续定位；不改步长或迭代上限。此前“旧三角面可能继续约束”为假设，尚无本例证据。


r12终态exit65：timeResolution(stage:"local-half", time:0.15536576580755695, step:2.6592646469819098e-17)。主共享循环在同一时刻epoch128、budget1.42768e-8、rejected23，后续继续减步直至时间精度耗尽。下一步记录该时刻拒步分类（穿透/事件存在性不一致/整半步误差）与起态；不能直接放宽时间守卫。r10–r12均中袋未执行，W06仍未验收。当前本轮测试/门禁均已终态；其他渲染任务进程不属于本轮，不操作。


## 接受状态必须同时满足静态与球间几何
r13终态exit65：拒步属于penetration，步长从1.43e-8降到8.5e-16s而穿透保持约3.9413e-7m，起始球间距误差仅-3.26e-16m。起态保留rejected-step-state.json。
static-compatibility-red-r1诊断终态两处失败：捕获的旧接受状态实际分别穿入角袋网格0.2058/0.2372微米；单球各自修正后相互靠近。固定历史坐标的初态断言不会随生产代码修复变合法，因此它作为诊断证据保留，后续测试改为确认历史初态有穿透、检查经引擎联合处理后的输出同时满足静态及球间约束；没有删除输出几何精度要求。

DR-167：advanceTogether入口在既有修正预算内联合处理几何，压力投影后再验证/恢复完整单边几何，包含步首未承力的新静态面；输出同时满足两类约束。joint-static-r1构建及22项0失败。随后增加压力+单边组合修正相对raw状态的4*tolerance总预算守卫，joint-static-r2正在回归22项并重新执行真实案例。主引擎未接入，W06未完成。


joint-static-r2长流程中，位置虽被修正，但捕获到相对法向仍以约0.03m/s接近：起态球间隙约-2.2e-14m，落在联合几何按绝对世界位置计算的舍入界内，却超出球球CCD仅按相对位置计算的1.42e-14m界，导致漏掉起始冲量。新的连续几何守卫暴露出这一检测契约缺口。已保存world-relative-contact-state.json、添加firstPairContact独立捕获反例；主动中止r2，不作通过。须统一位置不确定度，再回验完整几何与冲量，不能让位置修正代替碰撞响应。


joint-static-r2确认中止exit73。world-roundoff-red-r1独立捕获反例返回nil，一项失败。DR-168使firstPairContact传入世界位置舍入界，联合位置投影按每个接触尺度归一化；不使用空间积分tolerance扩大接触范围。world-roundoff-r1终态exit0，23项0失败，已覆盖组合修正总预算守卫。r14原真实案例重验中，全部进袋与主调度仍未完成。


续接状态：r14当前仍运行，exec session_id=6784，最近wait确认live。日志显示角袋已到第18事件t=0.0927947196，单球试算在约0.0975s附近大量局部迭代；尚无终态。不要仅凭耗时重启；先等待该handle或核对同一xcodebuild进程。world-roundoff-gate/doc-size及受影响diff --check已通过。真实多球完整流程、手机性能与主引擎均未完成。


## 斜面支撑遗漏与极短碰撞
续接确认r14仍live；sample及LLDB只读采样均完成并已detach。r14-live-locals.log显示台面接触1636与袋沿接触2738，袋沿normal.y=-0.06989，碰撞时间3.83e-7s，实际acc=(-1.594,0,-.907)。仅按外加gravity·normal筛支撑会遗漏台面反力/摩擦加载的袋沿。主动中止r14，确认exit73，非通过。

新增单球floor+overhang静态平衡反例：外力(1,-10,0)，斜面反力(-1,-1,0)、台面反力(0,11,0)，净力零。overhang-support-red-r1三断言失败；仅移除支撑前重力筛选的r1仍三处失败，因为末态投影也按重力排除了斜面。r2同时移除该投影筛选，并仅把有正支撑力的面排除于后续CCD/限步，未承力接触继续检测。构建及28项0失败（11区间、6单球、11空间接触）。真实r15重验中；共享单球行为改变，需要重新验证W05实际网格收敛与释放样例，旧验收不自动覆盖新代码。


## 最终几何与法向速度衔接（DR-170）
r15已主动中止、exit73；并非通过。捕获状态在half-step-mismatch-state.json。pressure-half-red-r1固定真实状态测试两断言失败，半步末立刻返回碰撞、时钟不进。diagnostic-r1确认联合位置修正把pair法向速度从-9.98e-15变为+1.82e-14m/s，超过持续接触激活精度；位移仅约2e-13m。
在完整几何投影后，只对仍接触的旧承力约束再投影速度，不再移动位置、不拉回已分离有限特征。pressure-half-r1原断言通过；final-normal-regression-r1正在验证基础、历史静态兼容和W05三类实际网格收敛。完整真实双球及主引擎仍未完成。

final-normal-regression-r1终态exit0：33项0失败，包含三类W05实际网格（临界三步长、角/中袋三速度双步长、偏置/返回能量收敛），以及释放、联合支撑、捕获状态和半步衔接。gate、doc-size和受影响diff --check通过。真实双球r16已启动，session_id=44484；未取得终态前不要重启。

r16终态exit65：角/中袋均跑到0.35s（14/3次事件），唯一失败为中袋fixture初始距离0.028574939190397955m小于R-1e-12，差约60nm；动态距离/能量/时钟断言未失败。两球在这段均未下落，故本例不证明真实连续入袋。r17把初始球心Y按实际网格竖向球体CCD定位到支撑面，保留原XZ排列/速度及严格初态无穿透断言；不得通过放宽该断言修fixture。r17运行中session_id=25102。下一项需建立真正下落的前后双球案例，不能以当前近袋碰撞冒充完整入袋。

r17终态exit0，原双球近袋案例通过（70.531s），角/中袋均完整推进；仍不证明两球自然下落。新增testTwoConsecutiveBallsActuallyFallThroughEachPocket，前后沿袋中心方向进球，除原时钟/距离/能量外明确断言两球均下降到台面以下；consecutive-fall-r1已启动，session_id=46528。

consecutive-fall-r1终态exit0，一项通过（6.893s）：角/中袋两球都真实下降至台面以下，终态时钟/距离/能量满足断言。本例没有球球冲击（epochs=1），不能替代相互接触着下落、全程最小间隙、重复性和多步长收敛。下一步补联合轨迹连续间隙/两球下落相互接触验证，再做平面与局部所有权/返回/主时钟接入；不要把本例下落当成规则捕获或App自然进袋已完成。
本轮进程全部终态：pressure-half-red/diagnostic exit65、pressure-half-r1 exit0、33项回归exit0、r16 exit65（仅fixture）、r17 exit0、consecutive-fall-r1 exit0、gate/doc-size/diff通过。当前没有本轮仍运行的xcodebuild。


## 连续间距与离台球球碰撞
continuous-fall-r1终态exit0，两项通过：角/中袋下方追撞（两球均离支撑）与前后连续入袋。追撞从实际单球下落状态构造，两球竖向间隙0.01m、相对速度0.5m/s、相同重力，独立预期t=0.42s，两袋均符合1e-8s。事件后续算到0.5s，能量/时钟通过。
新增测试侧连续间距证书：合并每对接受运动区间，按中点距离减去相对速度/加速度位移上界给全区间下界，不能认证时二分；独立于生产CCD，另验修正右端点。原复杂近袋测试用它替换仅打印的边界采样。人工首尾安全但中途穿过原点的轨迹触发预期失败，证明检查器能拒绝；此预期失败仅限故意非法的检查器样本，不包裹产品测试。continuous-near-pocket-r1运行中session_id=12176。
主引擎仍为Float平面时钟/旧捕获，没有空间所有权接管；不能把局部tests通过说成App自然进袋完成。

continuous-near-pocket-r1终态exit0，两项0失败（70.856s，包含故意非法检查器fixture的预期失败）。复杂角/中袋全段通过连续间距证书，原4*tolerance空间预算不变。continuous-fall-gate、doc-size、受影响diff --check通过，本轮全部进程终态。
下一步：W06主调度衔接前，落成平面/局部所有权及进入/返回边界；进入必须早于支撑变化，跨区球球接触不能被忽略。现有EventDrivenEngine.simulate以Float currentTime驱动事件、evolveAllBalls及多个boundsFallback，LocalPocketSimulation用Double绝对时钟；不应每步把局部Double状态转回Float再构造下一步。需保留局部权威状态、只在消费者适配时转换，统一最早事件。基础跨区返回/再进入仍未实现，主引擎接入不可标完成。


## 局部域连续穿越（DR-171）
区域采用原局部窗18cm半宽作为球心域，数值几何提取窗增加一个球半径保证区域边界完整球体的候选覆盖。PocketLocalRegion按边界二次方程根划分开区间，区分有限矩形进入/离开和相切，保留纳秒级事件；不设为capture。local-region-r1运行中session_id=2836，基础穿越与六袋网格对拍已执行，实际速度矩阵尚未终态。其编译后新增asset.regionsByPocketID及映射断言，必须下一构建验证这些新增代码。主调度、支撑边界提前量和返回未完成。

local-region-r1终态exit0，3项通过：连续穿越、六袋资产数值对拍、角/中袋三速度双步长矩阵（56.303s）。regionsByPocketID及断言在r1编译后新增；local-region-r2正在单独验证该新增映射和扩大候选网格后的真实下落追撞/复杂近袋连续间距，session_id=24543。gate、doc-size（99KB）及受影响diff通过。

local-region-r2终态exit0，六袋区域ID映射、真实下落追撞及复杂近袋连续间距共3项通过（复杂项69.500s）。r1/r2为6次测试执行，包含重复资产检查，不是6个独立功能。主引擎未接入。下一步以实际网格验证接管早于有限支撑变化，实现带Double权威状态的所有权交接与返回判据；不把越过矩形边界等价于落袋或已落稳。本轮所有测试和gate均终态。


## 所有权与返回（DR-172）
新增LocalPocketOwnership保留Double state，唯一所有权、revision失效、共同时间组原子提交；通过真实支撑判据后才移出local。ownership-r1两项0失败。真实边界r1/diagnostic-r1均exit65：角袋大台呢面三个Y顶点相差一Float ULP，法线z=1.1644e-7；并非真实袋沿。planarReturn限整面一Float ULP层且脚点在有限面、速度沿实际法线切向，返回仅校准Y/vy，水平p/v、omega及绝对time保持。真实fixture从水平速度改实际面切向速度、断言水平分量保留与vy归零，理想水平面仍断言完整向量相等。local-ownership-r2运行中session_id=13337，包含真实六袋及两项基础。主引擎未接入。

local-ownership-r2终态exit0，3项通过：理想面完整状态往返/重入旧事件失效、墙沿腾空拒绝及原子失败、真实六袋代表边界支持。真实Y修正最大约5.96e-8m，在原预算内。只覆盖中心方向代表边界，不证明全方向或主调度；尚不能标W06完成。doc-size/diff通过，local-ownership-gate运行中session_id=86871。

local-ownership-gate终态exit0，本轮测试/gate全部结束。下一步把Double所有权接入EventDrivenEngine真实事件循环，统一最早局部/平面事件、处理邻球与过期预测；保留旧解析台面路径但不能继续让局部球走旧吸袋/清零或bounds兜底。先完成主引擎单球进入/下落/返回fixture，再补多球共享时钟。现有接口仍未由主引擎调用。


## 主引擎接入（DR-173/174）
simulateWithLocalPockets已使用Double时钟、所有权、区域进入事件和真实支撑返回；recorder保存Double空间区间/交接。单球验证入口，正式simulate未切换；多球输入明确抛groupIntegrationPending，规则capture仍待W07统一，不能把此阶段下落当规则已进袋。
main-local-entry-r1中袋正入在0.40804897s接缝投影不收敛，角袋下落/中袋返回通过。diagnostic-r1/r2均exit65；r2明确六个接触面只有一Float ULP台呢Y差形成微折面。物理代理仅规范该精度层内台呢顶点，非台呢/低于该层曲面及显示USDZ不变。
main-local-entry-r2运行中session_id=94798；当前主引擎下落/返回、六袋代理对拍、普通引擎/停稳测试已通过；临界与速度矩阵待终态。共享平面evolvePlanarBall是机械提取，旧bounds调用顺序保留。下一步刷新实际多球后做共享调度，不能停在单球限制。

main-local-entry-r2终态exit0，41项0失败：主单球角/中袋下落、中袋返回、六袋代理调整界与数值对拍、普通物理/停稳及W05临界/速度矩阵。r3终态exit65，25项里只有新续算测试4断言失败，实际多球近袋连续间距/离台追撞与基础22项未失败。任意0.6s切段改变积分网格，位置2.4微米/速度5.8微米每秒差异。DR-175保留已求解Result尾段并按owner revision续用，提交前缀到用户请求时间；同时间无操作。r4主单球/返回/原续算三项通过；r5追加p/v/omega精确相等和无操作帧数断言，session_id=36866仍运行；main-local-final-gate session_id=87328运行中。

r5终态exit0，续算p/v/omega逐分量精确相等及同时间无新增快照通过。main-local-final-gate、doc-size/diff通过；本轮所有进程终态。主入口仍显式单球，App默认simulate不切换；下落记录未标规则pocketed。下一步扩展混合多球共享调度：局部/平面预测的最早球球事件必须统一，碰撞更新后所有相关未来区间失效；不能通过扩大固定区域假设永不跨区碰球。邻球可能在局部域外接触域内球，需实际接触模型/几何覆盖及共同时钟验证，完成后移除groupIntegrationPending。

## DR-176 — 跨所有权预测与平面方程一致性（2026-09-12）
- **范围**：findNextEvent增加局部owner排除集合，保留球数据；firstLocalPlanarContact用真实高度连续检测，预测止于下一平面事件，接触自旋从实际平面方程查询。当前为混合调度基础接口，尚未接入多球主循环。
- **失败机理**：EngineNumerics加速度仅在速度>0.001时启用，而AnalyticalMotion滑动/滚动在>0.0001时仍减速。0.0005m/s滑动反例预测接触22.351740729微秒，独立方程23.428689391微秒，原1e-10s断言失败。
- **修复**：预测加速度的两个域边界与现有演化方程一致，分类阈值不变；未放宽断言。
- **验证**：cross-owner-low-speed-red-r1终态失败保留；green-r1终态exit0，39项0失败，覆盖跨owner高度/先行事件截断/不删球过滤、普通PhysicsEngineTests及PhysicsRestTransitionTests。先前planar-owner-filter-r1为37项通过，cross-owner-prediction-r1为3项通过，属于重复执行不能累计为独立功能覆盖。
- **边界**：不代表混合组事件响应、外部变更缓存失效、全低速域或App自然进袋验收。正式入口仍未切换。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-176；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

本轮测试全部终态。下一步仍是混合多球共同提交/接触响应与几何覆盖，不是另建只读预测就算完成；外部输入变更和未来轨迹失效需同时处理。W06保持进行中。

## DR-177 — 共用接触时刻联合响应（2026-09-12）
- **范围**：从advanceCoupledTrial提取resolveContactGroup(initial,accelerations,pairRestitution,pairFriction)，原局部推进改为调用同一入口；接收同一时刻的碰前状态和加速度，联合处理实际静态几何与球球接触，返回碰后速度/自旋与约束，不生成运动区间。
- **原因**：跨owner预测之后不能仅交换球速；受支撑接收球的台面反作用必须与球球冲量共同求解。低反弹的有界处理继续使用各球真实预测加速度，不改旧接触参数或误差预算。
- **验证**：cross-owner-response-r1终态exit0，两项通过：理想平面向下0.5m/s撞击、e=0.8后落球向上0.4m/s且台面球vy=0，异步输入拒绝；真实角/中袋落球与受支撑球联合案例。r2在加入有限状态检查后回验新入口、真实离台追撞、持续压力半步及复杂近袋连续间距。
- **边界**：此入口不推进主引擎时钟、不提交所有权、不负责缓存失效。混合主循环与覆盖域外邻球的实际静态几何仍待接入，W06未完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-177；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

cross-owner-response-r2运行中session_id=4681，禁止未读终态即重启。

cross-owner-response-r2终态exit0，4项0失败，包含复杂角/中袋0.35s连续间距与能量验证、实际离台追撞及持续接触半步。r1/r2共6次执行含重复新入口，不作6个独立功能。gate/doc-size/diff通过，本轮所有进程终态。下一步：主引擎将跨owner预测的接触状态送入共用响应，完整接触组须带域外邻球的真实几何覆盖；同时处理Double共同提交及预测失效。单球入口限制尚未移除，正式App与规则capture仍未接入。

## DR-178 — 域外接触组的全桌数值几何（2026-09-12）
- **范围**：PocketContactMesh.Coverage新增fullTable选项，默认仍pocket；PocketGeometryAsset缓存tablePatches，用同一TaiNi/Leather筛选、移动台呢对齐及一Float ULP规范契约提取全桌候选。局部球心所有权域未扩大，原六袋patch保持。
- **原因**：区域边缘的局部球可以接触域外邻球。只扩大所有权区域不能消除跨区接触；共用响应必须拥有邻球所在位置的真实支撑/袋沿几何。全桌值快照供空间索引查询，不代表全桌球都改用空间积分。
- **验证**：full-contact-geometry-r1终态exit0，两项通过：六袋原网格是全桌候选逐顶点精确子集；桌心及沿六袋朝桌内方向越过所有权边界两球半径处均有实际竖直球体CCD台面支撑；六袋Scene加载对拍保持通过。r2追加同七处的联合落球响应及单球主入口回归，尚须读取终态。
- **边界**：保留既有碰撞材质范围，不宣称袋底/装饰材质或全方向已验收；主混合调度尚未使用tablePatches，性能预算仍未验。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-178；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

full-contact-geometry-r2运行中session_id=30635，按同一句柄等待终态。

DR-178验证更正：r2终态exit0但仅执行1项，七处全桌几何联合响应通过。命令误写testMainEngineBeginsNaturalPocketDescentBeforeLegacyCapture（真实名称为Owns），Xcode未报不存在筛选项，不计主入口验收。full-contact-main-r3使用源码准确名称补跑主下落与Double精确续算，session_id=8644。

full-contact-main-r3终态exit0，准确名称两项执行均通过：主入口角/中袋下落及单球精确续算。DR-178三轮共5次执行（含重复几何测试），全桌七处联合支撑通过；gate/doc-size/diff通过。所有句柄终态。下一步使用tablePatches构建共享接触求解器并接入多球主时钟，暂不能移除单球限制或标W06完成。

## DR-179 — 混合多球主循环验证入口（2026-09-12）
- **范围**：EventDrivenEngine.simulateMixedWithLocalPockets(maxTime,maxStep,pairRestitution,pairFriction,maxEvents)新增显式验证入口。台面事件/局部域进入/局部组最早球球接触/跨owner CCD共用Double时钟；普通台面球仍由evolvePlanarBall演化。全桌接触索引用于局部组及域外邻球，接触邻球沿接触关系加入同一联合响应，复制所有权账本完成共同提交后发布Float镜像，每轮清理旧平面事件缓存。
- **参数**：球球系数由验证调用者显式传入，尚未取代生产碰撞材质契约；静态接触沿用既有W05原型参数。正式simulate以及单球simulateWithLocalPockets未切换。
- **返回**：局部球需满足真实台面返回判据，且与其他局部球离开4*tolerance接触预算；此边界仍需实际返回/重入回归。新增球球事件写入既有事件/时间记录，首次碰撞时间使用当前绝对时间。
- **验证**：mixed-main-r1终态exit0，真实中袋域内腾空球撞域外台面球通过：动量传递、台面支撑、邻球空间接管与无旧捕获。r2因新测试直接比较非Equatable的SCNVector3编译失败（保留）；改为逐分量精确断言后r3补跑两地区下落+远处静止球和跨区单次事件。
- **尚未完成**：混合续算完整步缓存、外部setBall输入生命周期、同时事件/静态事件记录审计、返回再入、接触组多球连续间距/能量和生产参数一致性。多球单次输入已有实际推进代码，不等于整批W06或App进袋已验收。不可用新入口的一例通过移除正式门控。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-179；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

mixed-main-r3运行中session_id=43311。

mixed-main-r3终态exit0，两项0失败：两个不同袋口在同一Double时间推进到1.1s均下降，远处静止球逐分量保持；真实跨owner接触动量/支撑/晋升及单次球球事件记录通过。r2编译失败已修为逐分量断言，未改物理断言预算。gate/doc-size/diff通过，所有进程终态。下一步混合主循环连续段/同袋多球/返回再入和任意时间续算：当前主混合入口已接通但未完成这些验收，正式simulate与原单球入口仍保持。

## 混合边界与续算反例（2026-09-12，DR-179后续）
- mixed-boundaries-r1终态exit0，2项0失败：角/中袋各两球从台面连续来球到1.4s，两球均下降、各一次接管、局部段连续间距认证和最终总机械能预算通过；混合返回台面用例一次进入/一次返回，恢复rolling、Y/vy正确。不是同袋撞击全矩阵或所有状态验收。
- mixed-continuation-red-r1终态exit65，1项1断言失败：一次0.0307s与先0.0073再0.0307s，空间球最终Y差1.1e-16m、Z差约4.4e-16m；速度/自旋/事件时间/交接次数未失败。保留SIMD精确断言，不放大容差。根因：混合maxTime截断末步，续算从截断位置重新积分，舍入路径不同；单球已用pendingLocalResult保留完整步，混合尚无对应机制。
- 下一步具体实现：缓存完整混合epoch（原始planar状态、局部预测区间、完整碰后状态、晋升/进入/事件待提交动作及参数/revision）；请求只消费前缀，余段不重新积分。截止早于事件时不得提前提交事件/晋升；后续从原区间sample，完成后提交完整终态。不以从零重算全部历史替代运行时续算。普通平面剩余量也不得被请求截断改写下一步起点。
- 所有测试句柄终态，无运行中xcodebuild。本轮未改生产代码；测试新增已落盘。W06仍进行中，精确续算红例待修，正式入口未切换。

## DR-180 — 混合完整步骤缓存与前缀提交（2026-09-13）
- **根因**：混合入口使用maxTime裁积分末步，后续从裁点重新积分，旧反例最终位置差约4.4e-16m。精确断言保留。
- **实现**：PendingMixedStep保存共同步骤起止、局部原始区间/完整终态、平面原始状态/完整终态、晋升与事件待提交动作、参数和版本。固定完整maxStep或最早物理事件决定求解边界，请求只决定消费前缀。局部前缀从原区间sample，平面前缀从原步骤初态演化；完成时采用缓存终态，不从已发布前缀续积分。只有到完整事件时间才发布碰撞/晋升/进入。部分提交更新owner revision，后续匹配续用。
- **输入保护**：缓存绑定maxStep/球球系数/ballInputRevision和owner revisions；参数或外部setBall变更不能继续使用旧预测，当前明确抛staleUpdate。setBall正常路径只增加revision计数。单球局部入口拒绝混合缓存，反向混合入口原有pendingLocalResult检查保持。完整外部修改后重新接管/重算流程仍待验证，不声称已支持任意运行中编辑。
- **验证**：mixed-continuation-green-r1终态exit0，原精确p/v/omega续算反例及跨owner单次碰撞两项通过。green-r2追加事件前多次截取（不得提前发布事件/晋升）、系数变化拒绝后正确续算、同时间无帧变更，并回验同袋双球、返回、不同袋口与原单球精确续算；尚须读取终态。
- **边界**：正式App入口未切换。多球同刻静态/球球事件完整日志、连续再入及整批性能/确定性矩阵仍待验，W06不标完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-180；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

mixed-continuation-green-r2运行中session_id=79462。

mixed-continuation-green-r2终态exit0，5项0失败：混合多次截段p/v/omega精确一致、事件前不提前发布/晋升、系数失配拒绝后正常续用、同时间不增帧、同袋双球连续间距/最终能量、返回台面、双袋共同推进和原单球续算。两轮7次执行含重复续算，不当作7个独立功能。gate/doc-size/diff通过，全部句柄终态。下一步继续同刻事件/连续再入与外部输入生命周期：缓存失配目前拒绝，不能宣称自动重建已完成；正式入口/规则捕获仍未切换。

## DR-181 — 连续再入接缝支撑与首次碰撞时钟（2026-09-13）
- **实际反例**：混合球从中袋局部返回台面，与迎面球碰撞后重新进入。mixed-reentry-r1终态exit65，在t=0.7118319298395155s支撑projection失败，4个共面三角候选、residual=1.7340928696757009e-9。原始状态/三角顶点在日志保留。
- **几何机理/修复**：球的垂足已处于某一面内部，邻接共面三角的边缘距离却因舍入被列入同一nearest+roundoff投影集；这要求多个实际不能同时成立的法线速度为零。exposedSupportCandidates仅在确有垂足位于有限三角内部时，排除同平面上离该垂足有可分辨距离的边缘候选。共面判据使用既有64ulp空间尺度，不扩大投影残差阈值。没有面内部覆盖的真实袋边、非共面面和孔洞仍保留。当前使用点为无撞击步的支撑投影。
- **首轮验证**：mixed-reentry-r2终态exit0，进入→返回→平面球碰撞→再次进入及同pocketID/顺序通过。
- **时间反例**：新增同源时间断言后mixed-reentry-clock-red-r1终态exit65：firstBallBallCollisionTime=0.0003577754，而事件列表绝对时间0.27785778。resolveEvent误用相对event.time；改为调用方已推进的currentTime，普通与混合平面入口共用此修复。
- **回归**：mixed-reentry-regression-r1运行中；包含再入/混合精确续算、实际复杂双球连续间距、W05临界袋口和返回能量、普通PhysicsEngineTests，尚须读取终态。原红证据与精确断言保留。
- **边界**：没有变更显示几何/材质，没有调物理接触参数。W06同时事件完整记录/外部输入生命周期及全面验收仍待完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-181；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

mixed-reentry-regression-r1运行中session_id=77718。

mixed-reentry-regression-r1终态exit0，38项0失败（211.164s）：33项普通物理、混合再入+绝对首次碰撞时间、混合精确续算、复杂近袋连续间距及W05临界/返回能量。两次原红证据保留；未改变误差断言预算。gate/doc-size/diff通过，全部进程终态。下一步W06事件完整性审计：advanceTogether目前只向主循环返回球球约束，单球run内部静态contacts未随CoupledAdvance向上传递，主记录存在袋沿碰撞事件缺口；须保留接受前缀内的静态接触及ID/时间，拒绝试算/未来事件不能上报。外部编辑生命周期仍不可宣称已支持。

## DR-182 — 已接受局部静态接触向主记录传播（2026-09-13）
- **缺口**：LocalPocketSimulation.run已有Contact时间/面索引/法线，但advanceTogether只回传轨迹和球球约束，主循环丢失静态接触。
- **实现**：CoupledAdvance.staticContacts按球保留已接受半步/试步的静态事件；拒绝试算不入结果。遇到更早球球接触时只保留严格早于该时刻的旧静态事件，同刻以联合响应接触重建。resolveContactGroup保留实际向静态面逼近的接触，静止支撑约束不直接当成新撞击。
- **主记录**：TrajectoryRecorder.localStaticContacts带ballName、geometryID和原始Contact。混合PendingMixedStep独立保存逐球静态列表，含刚晋升邻球的联合接触；按已消费计数只发布time<=请求截止的前缀并依时间排序，续算不重复发同一条。面索引对应缓存tablePatches，geometryID当前为运行时全桌快照标识；持久化版本映射和业务吃库/音效分类不是此字段自动完成的。
- **验证**：static-event-pipeline-r1终态exit0，再入/混合精确续算两项通过；r2终态exit0，实际落地静态事件时间与独立自由落体方程匹配，事件前为空，一次/多次续算记录时间/面索引/法线精确一致，真实离台追撞/受支撑接触共3项通过。r3在补晋升邻球独立事件列表后验证编译、落地续算及跨owner，尚须读取终态。
- **边界**：同一物理接触可能含多个几何面记录，尚未将几何接触自动等价于业务吃库事件；正式App与规则capture未接入。W06不因数据管线绿而直接完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-182；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

static-event-pipeline-r3运行中session_id=71805。

static-event-pipeline-r3终态exit0，3项0失败；新增主事件前缀/续算一致性、跨owner与实际支撑通过。三轮8次执行含重复用例，不当作8个独立功能。gate/doc-size/diff通过，所有进程终态。下一步按W06 DoD集中审计高速/同刻组事件与确定性，明确几何接触日志和业务事件的边界，再确认进入W07的前置；不能把静态面索引直接当库号或自动计分。

## 高速/同刻矩阵与验收审计（2026-09-13）
mixed-high-speed-r1编译失败（测试表达式类型推断过重），r2终态exit0。一个测试内2/8/12m/s三档×重复/半步共9次模拟，对称三球同时双接触、无额外能量、各对连续间距、精确重复和半步误差通过。误差值见W06-audit.md。验收审计发现另需“局部进入与无关平面碰撞同刻”反例，当前dueEntry/dueEvent互斥及消费else-if依赖重查，不预支完整不丢事件结论。W06仍进行中；下一步复现并修正此分支。

## DR-183 — 同刻独立台面事件直接提交（2026-09-13）
- **审计结论**：coincident-entry-baseline-r1终态exit0，初始t=0区域进入与不相关已接触球对的碰撞均保留，旧重查在该用例有效；此前只是风险假设，不能记作已复现漏报。
- **调整**：混合入口用事件涉及球集与最终局部owner集判定。无关同刻平面事件直接随PendingMixedStep保留并提交，不再被dueEntry或cross的互斥条件丢弃；涉及新owner的旧事件交新局部/联合求解，不双算。零时刻进入同样可在该时刻处理独立事件。规则capture仍未切换。
- **验证**：coincident-entry-r2终态exit0，4项0失败，含初始同刻碰撞和独立参考结果逐分量一致、高速三球三档/重复/半步矩阵、混合精确续算与真实连续再入。工作区原失败及探索记录保留。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-183；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

2026-09-13：W06验收结项见W06-acceptance.md；同刻互斥风险初始用例未复现漏报，DR183按涉及球集显式提交独立事件，4测/最终gate通过。所有进程终态，完整目标转入W07，正式App未切换。
