# W07 统一进袋入口、预测与规则

2026-09-13开始，W06依赖见W06-acceptance.md；真源问题集合v63.10。当前显式混合入口已接入软袋捕获与共享收尾，普通近景及支撑/失撑/吐袋边界已验；正式App入口尚未切换。下方按时间保留探索过程，最新状态见文末。

已核实：
- EventDrivenEngine旧resolvePocket（当前1403附近）在捕获后state=pocketed并吸袋心清零；同文件enforceTableBounds约1220还有recordPocketEntry/bounds捕获路径。
- ShotPredictor约523/541及681/708构造EventDrivenEngine并调用旧simulate，包含提前结束/预算/高保真选项。W07必须保持普通远袋台面语义，不能只换一个可见入口。
- W06显式混合入口已维护空间轨迹与接触记录，但无不可逆捕获判据；输入系数显式，尚未取代生产材料响应。不能先把所有下落球标pocketed再靠W08显示补救。

下一步：完整检索捕获/兜底和规则消费者；读取真实六袋几何确定可验证捕获条件，区分运动所有权pocketID与最终真实捕获袋ID。定义规则捕获事件/时间与继续可见运动的共存，不清零物理状态。审查全局来球接触可能性，不把固定深度或旧捕获圈当未经证明的不可返回条件。同步审计普通球球摩擦/恢复系数与局部显式参数的生产契约。W08再统一回放/导出。

W06最后所有进程已终态；没有运行中测试句柄。没有提交/推送/发布。W07整体未完成。

## DR-184 — 确认捕获记录与持续运动分离（2026-09-13）
- **接口**：TrajectoryRecorder.ConfirmedCapture保存ballName/pocketID/geometryVersion及Double完整state；recordConfirmedCapture只录已经由物理判定确认的事件，重复相同输入幂等，冲突/非法状态拒绝。记录操作不吸袋心、不清速度/自旋、不改现有运动帧。
- **查询**：isBallPocketed新增可选Double查询时间；有新捕获记录时用确认时刻，截止前为false；无新记录沿用旧帧.pocketed语义。confirmedCaptures按时间/球名确定排序。当前没有生产求解器调用新录入接口，不能把契约完成当自然进袋判据完成。
- **验证**：capture-record-r1终态exit0，共3项0失败；新捕获仍有非零速度/自旋和sliding尾帧、时间前不泄漏、重复不多计、冲突不覆盖、无效输入拒绝、旧帧查询及原自然停稳回放通过。测试捕获为明确手工fixture，不是实物捕获判据证明。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-184；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## 入口与物理边界调查
已核实第三捕获路径AnalyticShotRollout约194：生成entry后吸袋心/清速度并completed；ShotPredictor约437/438按potted再次增删目标球结果；BreakSimulator约81直接按BallState.pocketed筛球，BreakFlowRunner按列表hideBall。W07必须覆盖这几个消费者，不能只换isBallPocketed查询。

2026-09-13读取WPA官方PDF（URL文件名2026.01.02，正文标Effective2025-09-15）§2.2：进袋定义涉及袋内停留/回球系统，弹回与挂袋另有规定。参考用于检查“几何进入≠规则完成”的边界，不自动替换App中八/9球/斯诺克各自规则。来源：https://www.wpapool.com/wp-content/uploads/2026/01/2026.01.02-WPA-Rules.pdf 。后续再次展开350行工具超时，不假称新取得未返回正文。

W05旧几何证据复查：section-measurements.json的角/中袋Leather剖面最低约surfaceY-0.0562m；当前数值代理只选TaiNi/Leather，并没有完整袋底支撑。旧geometry-r1原始面里White最低约0.668m，另有Gold/Black/Wood等，材料名不能代替袋网/回球器语义。以上是已有W05测量，实施捕获代理前须重新对照当前加载模型。单靠给现有代理加重力会持续自由下落，不能据此伪造“已在袋底停稳”。下一步核实袋内结构及适当数值代理/可证明停止条件，记录真实袋ID与几何版本，再接ConfirmedCapture。

当前所有测试句柄终态，W07尚未完成；未切正式App入口。

## 当前加载模型重测（geometry-current-r1，2026-09-13）
- 专用模拟器2447DFF4-394E-4707-8063-87F4763B3704，PocketGeometryV63Tests/testLoadedPocketContactGeometryEvidence终态exit0，1项0失败。原始附件保存在output/3d-v63/W07/geometry-current-r1-attachments，非沿用旧模型测量。
- physicalBedY=0.800000011920929m；角袋Leather最低0.7437626719474792m，中袋最低0.7437959909439087m，与旧代理缺少深部支撑的判断一致。所有材料范围见geometry-current-material-bounds.json。
- 对White面按完全相同的世界顶点建立连通分量（未做容差焊接）：角袋59、中袋58个分量。两者最大分量都包含14098个面顶点引用；角袋范围X[-1.3705672,-1.2449437]、Y[0.6703949,0.8003303]、Z[-0.7400834,-0.6128021]，中袋X[-0.0558393,0.0512339]、Y[0.6699113,0.7848179]、Z[-0.7583982,-0.6193974]。详细数据white-connected-components.json。
- 这把下一步范围缩小到White最大深部分量及其周围独立结构：需画出/观察其真实表面和开口，再评估简化承接代理；材料名称及AABB仍不足以证明它是连续袋底。不可把全部White面直接加入碰撞，也不可据最低Y设置捕获阈值。
- 未修改生产物理；W07未完成，下一步为该深部分量的表面形状与连通开口核验。所有测试进程已终态。

## 袋网形状核验（2026-09-13）
- 可复现脚本output/3d-v63/W07/inspect_deep_geometry.py读取本轮原始附件，输出deep-geometry-components.png、deep-geometry-widths.png和对应JSON；已打开审图。隔离Python环境依赖见geometry-python-requirements.txt，未改App依赖。
- 最大White连通分量实际是横向螺旋网绳，不是封闭袋底。角/中袋各3537面、7049条边均邻接2面，仅说明绳管表面闭合，不能误解为袋容积闭合。其余分量包括纵向网绳和上部细节。
- 先做顶点薄带观察发现截面缺边，改为实际面边与水平面的精确相交；最终脚本及JSON仅保留精确交线口径。深度60/100/120mm的截面外包凸多边形最小宽度：角袋98.81/76.38/65.39mm，中袋93.08/76.27/66.19mm；球径57.15mm。外包络不是净开口测量，也不证明完整球能穿过，但不能用这些外宽直接声称下部已经可靠卡住球。
- 技术方向收敛：采用贴合实际袋网轮廓的简化承接代理，必须明确标注简化的封口/底部与材料响应，不能把螺旋线的拓扑封闭当现成碰撞腔。下一步建立该代理的候选与几何误差/承接验证，再接捕获事件；在代理确立前不切生产入口。当前不是已完成物理承接或规则捕获。
- 图中红圆只为球径比例参考，不表示球在该截面的合法中心或稳定位置。分析脚本exit0；git diff --check通过。

## 承接代理小样与新增失败（2026-09-13）
- build_bag_candidate.py从当前六袋White网格精确水平截面建立64向轮廓、2.5mm层距，每袋37圈/4672三角面，输出bag-candidate.json并记录源SHA256。上边界暂为台面下40mm（小样参数，非捕获阈值）；底面取该袋实测White最低Y并显式封口。这是简化承接假设，未当作真实袋底、未进入App。后续需检验上缘衔接、网格误差/细分收敛、材料系数与多球承接。
- 新增探索用例PocketGeometryV63Tests/testMeasuredBagCandidateSupportsNaturalDescent，当前从本地output读取候选；正式测试集需在集成阶段替换为可由生产构造器重建的几何，不能遗留本机fixture依赖。
- bag-candidate-r1终态65：旧袋心XZ、台面球心高度起点与真实面3561初始重叠0.0002112268m；保留失败。改为袋口上方50mm自由落下作为承接测试，未放宽断言。
- bag-candidate-r2：角袋推进到约0.7857秒时接触密集、运行CPU约99%；sample确认LocalPocketSimulation.integrate/triangle.firstContact，非UI等待。主动SIGINT，日志TEST INTERRUPTED，最终进程exit73，原样保留。
- bag-candidate-r3采用显式1024迭代预算，终态65/iterationLimit。失败状态time=0.7857299573644045，p=(-1.2896644296,0.6973144375,-0.6672735859)，v=(0.0023218251,0,-0.0359357136)，omega=(-1.1840415,-1.4496997,-0.2385748)。最近4次接触都在surface12848、normal=(0,1,0)，相隔约3.03e-8s。球已到承接面高度；失败是持续支撑/重复接触处理，不能宣称已停稳或提高预算绕过。中袋尚未执行。
- 下一步在该精确状态缩小复现，检查integrate的support激活、normalForce、冗余同平面约束与firstContact衔接；修根因后再做步长/几何收敛及角中袋承接，不清零速度求绿。生产物理本轮未改，W07仍未完成。全部测试进程终态。

## DR-185微小反弹修订与回归（2026-09-13）
- bag-floor-red-r1：精确状态2ms/32预算复现，诊断显示斜壁normal=(-.9821324,.1771703,-.0634560)产生底面向上vn约3.0e-10，底面支撑被筛掉；acc.y=-9.2295后反复在约30ns撞底。
- integrate已加入基于vn²/(2a)的亚分辨率反弹识别，直接投影到共同切空间，并检查总调整能量≤g*tolerance及其他单侧可行性；超过预算保留真实离地/切向运动，自旋不改。首版迭代投影在近平行面失败（regression-r1），已改为直接正交投影加拒绝条件。DR-185已同步IMPLEMENTATION-LOG/架构技能/UI Changelog。
- bag-floor-regression-r2终态65，4项中3通过：精确状态推进、可见离地解析对照（并验证共同切向速度/自旋不变）、旧OffsetAndReturnEnergyConvergence；完整候选1s停稳用例失败，角袋速度0.03654948m/s，中袋为0。两袋高度均到底面且能量断言未报错，轨迹附件已导出，bag-motion-one-second.png已审图。不能将组合套件声明通过。
- 1秒是探索窗口，不是产品规定的停稳时限。保持速度断言不变，将完整模拟窗口延长为4s、预算4096以区分尾段与耗能不足。bag-settle-extended-r1终态65：在time=1.365928889792294出现原有projection收敛失败，3个接触面，残差4.353628568765089e-12；完整状态/三角面保存于bag-projection-failure-state.txt。尚未运行到4s，不能判断最终是否自然停稳。下一步用这组状态缩小投影复现，检查近共面约束与联合投影收敛，再继续承接/步长验证。
- verify-gate通过；所有测试/构建句柄终态。当前未正式App接入，W07未完成。

## DR-186非共面接缝与收尾时钟（2026-09-13）
- inspect_projection_failure.py使用保存状态和三角面复现：面0垂足不在面内、最近点在公共边；面1垂足在面内，最近点差约1.5e-11m，距离却舍入相同。法向差引出±4.3536e-12速度残差；底面是真正第三支撑。测量见projection-failure-measurements.json。
- exposedSupportCandidates扩展为检测“最近点被另一有效有限面覆盖”，不要求两面共面；仅在末步投影使用。精确三面测试不依赖本地output；另加真双面棱角保留测试。
- noncoplanar-seam-r1/r2先失败invalidInput，诊断为最后1ULP剩余使第二半步duration=0；外层沿用内层8ULP末步剩余合并，检查二分中点可表示。r3三项0失败（接缝/微反弹/真实离地）。
- noncoplanar-regression-r1长测越过1.366s，在3.027812842547508s出现两面force收敛失败，残差1.10685e-7，约束残差3.80038e-6；精确状态/法向/支撑力在bag-force-failure-state.txt。此轮还发现角袋±25mm偏置两步长共4组同刻同面重复记录，见noncoplanar-duplicate-events.json。
- 控制变量隔离：撤回“在初始持续支撑构建前调用exposedSupportCandidates”的新增过滤，保留末步投影修复。noncoplanar-isolation-r1终态0，独立接缝及旧OffsetAndReturnEnergyConvergence两项通过（52s），证明提前过滤与CCD候选不一致是新增重复记录的触发因素。原失败均保留，未去重事件或删断言。
- 真棱角测试在regression-r1通过，短时3测已通过；未将含失败的长测套件算作通过。下一步从两面force失败状态复现并处理收敛，随后重跑完整承接/细分与能量验证；正式App未接入。所有测试句柄终态。

## DR-187/188：接触力收敛及平移停稳（2026-09-13）
- 原两面力失败的NumPy复现：原单步Anderson、严格下降、历史4/8均4096步后残差约9.18e-7；沿力增量求下一可行法向/Coulomb边界并验证残差下降后，28步残差4.47e-13。脚本reproduce_force_iteration.py和force-iteration-comparison.json留存全部比较；最初面索引解析偏一导致断言失败，核对floor面第二顶点后更正。
- Swift已接入同一边界加速，未提高4096预算或放宽精度。force-boundary-regression-r1终态65：真棱角、接缝、旧返回能量三项通过；完整4s已走完，角袋0.01186372m/s导致原停稳断言失败，中袋0。新失败属于耗散能力，不再是迭代中断。
- 核实局部原Surface只有滑动摩擦，纯滚动不继续减速；加入默认0的rollingFriction原型，袋候选用SpinPhysics.rollingFriction=.01作未标定参考，普通几何调用不变。单面解析测试rolling-resistance-r2通过；r1错误TablePhysics字段编译失败保留。零滑动摩擦原地转动边界用例rolling-couple-boundary-r1通过。
- bag-rolling-r1终态0/1测通过：角/中袋4s平移停稳、底面高度、原能量预算均通过。角袋v约(2.24e-17,0,2.54e-18)，但omega=(0,-2.89114445,0)仍原地旋转；中袋v/omega均0。不是完整运动停稳或已确认规则进袋。
- 下一步：自旋耗散与有限接触力偶的多接触边界；sustainedPairAcceleration预求解目前尚未加入滚动力偶对球球力的影响，需要一致性验证/接入；还需候选几何细分/误差、正常台面进入、多球承接、真实捕获事件及正式入口。不以单球小样替代W07验收。
- 全部本轮测试进程终态，未发布/推送。

## DR-189：自旋与多球表面阻力矩（2026-09-13）
- Surface新增spinFriction默认0，按既有AnalyticalMotion法向自旋公式5*mu_sp*N/(2R)衰减并按有限步停止。spin-decay-r1单面正反旋/零参数/解析停止以及旧滚动两测通过。
- 单球forceMap/角加速度与多球resolveSupport共用surfaceResistance；SupportConstraint表面系数默认0，有非零值须提供正有限duration，球球约束拒绝表面系数。sustainedPairAcceleration构造静态接触时传入参数，仍只将球球力/力矩传给局部积分器，避免表面力重复计算。
- 双球叠放解析场景：两球同向平移、反向滚动，地面和球球接触均无滑移；地面压力2g，球间g，地面滚动力偶2.8*R*mu*g。解得下球a=-98*mu*g/89，上球a=4/7*a下；总功率=-2.8*mu*g*speed。测试检查加速度/角加速度/支撑力/功率，防止只增加单球耗散却漏算球间传力。
- spin-pair-r1编译失败（换行+运算符）已更正，日志保留；r2终态0，单面自旋/双球解析/完整袋候选共3测0失败，约242s。角袋4s最终v约1e-19m/s、omega约7e-18rad/s，中袋v/omega0，原高度与能量预算全部通过。完整候选仍是从袋口上方掉落，不是正常台面进入或ConfirmedCapture验证。
- 本轮验证只是单球完整承接与双球瞬时力平衡；多球持续运动、近停止时不同子步的力矩截断一致性、真实袋几何与材料标定、正式捕获/入口仍待做。袋测试依赖output候选，需移为生产几何构建后才可用于干净检出验收。性能未验，约242s的Debug数值测试不能视作手机实时预算通过。
- spin-gate-r1、spin-doc-size-r1及git diff --check通过。原有支撑回归结果随后补充；正式simulate未切换。
- spin-support-regression-r1终态0，真实网格落球/支撑、跨域同刻碰撞支撑、原滚动解析三测全部通过；spin-doc-size-final与diff检查通过。所有本轮构建/测试进程终态，未推送。下一步以持续双球推进和近停止分步一致性补足DR-189边界，再继续袋几何/正常入口/确认捕获。

## DR-190：连续双球与停止零点（2026-09-13）
- 新增持续双球叠放10ms，速度0.1/0.0002m/s，步长1/.5/.25ms；检查非穿透、能量预算与位置/速度/角速度收敛。r1闭包换行编译失败保留并修正。r2虽通过最初绝对速度1e-4判据，低速下球末态却有-6.24e-6与+2.5e-5差异；未将该宽断言通过当成停止一致性结论。
- r3收紧低速空间预算至4e-12、速度按初速1%（最终同时保留1e-4绝对上限）。旧实现每组10ms约1.2万细分，约100s才能得到一致末态。定位为单球forceMap已使用slip/dt，多球预求解却对非零slip给满额摩擦。
- resolveSupport有duration时改用与局部相同的有限步滑动方程/Coulomb投影；nil仍为既有连续力语义。r4持续/解析两项通过，执行0.726s，低速各步长末态速度差约1e-8，高速约4.5e-8；原法向/力矩/系数与迭代预算未改。
- 新增正反小滑动/大滑动解析停止用例：球球接触相对切向有效逆质量7，末态slip=sign(u)*max(0,abs(u)-7*mu*g*dt)；验证不过零与Coulomb上限。pair-friction-regression-r1四项0失败，还覆盖真实落球支撑、跨域同刻支撑、原角袋联合修正。
- 仍待袋候选几何生产构建/误差验证、正常台面入口、多球袋内承接、ConfirmedCapture生产者及主引擎/预测统一；10ms叠放不替代这些验收。
- pair-friction-gate、pair-friction-doc-size及git diff --check均通过；本轮所有测试/门禁进程终态，未推送或切换正式simulate。下一步回到真实袋几何生产构建与正常台面进入，随后验证完整多球承接和捕获条件。

## DR-191：内置网格构建与正常台面入口（2026-09-13）
- PocketContactMesh.load新增显式materials参数，默认仍为TaiNi/Leather。纯数值PocketBagEnvelope从White三角面截面构建承接轮廓/侧壁/显式底盖，40mm顶部/2.5mm层高/64径向/30度空隙为原型配置，不是捕获判据。原4s承接测试已去除output/bag-candidate.json读取，改为直接读取Bundle网格。
- bundled-bag-r1/r2六袋构建通过，均37环/4672面，底高与先前测量一致。导出附件及bundled-bag-parity.json显示旧顶点平均与三角化后中心导致对应点最高4.68mm差异；轮廓对称距离最高0.746mm，见bundled-bag-contour-parity.json。
- 改用面积重心，独立build_bag_centroid_reference.py保留原始多边形截面算法，仅同改重心，输出另存bag-candidate-centroid.json，未覆盖旧候选。严格逐点1e-10比较断言失败；bundled-bag-centroid-parity.json记录最大0.607mm（pocket4），其余最高0.0111mm。仍需查原始非平面多边形与三角化截面、窗口和细分误差，不能宣称完全等价或删除旧失败。
- 半开相交端点处理恰过顶点的截面；共面矩形侧壁及四分细化的不变量测试验证轮廓不随同面三角化密度改变，另验空输入拒绝。此测试不覆盖真实网格的非平面多边形差异。
- normal-bag-entry-r1正常台面0.7m/s滚动进入角袋/中袋，0.7s高度与能量预算通过。bag-builder-regression-r1终态0，细化不变量/六袋构建/正常入口三项通过，含最终半开相交改动。角袋正常入口末态v/omega约浮点零；不能由两个正常入口样例推定全部袋口旧基准、全4s停稳或ConfirmedCapture已通过。
- 本轮正式缓存/捕获生产者尚未接入。下一步核对0.607mm截面差异及双分辨率误差，重跑新构建的完整停稳，再做袋内多球/确认捕获及所有正式入口。
- bag-builder-gate、bag-builder-doc-size及diff检查通过，所有本轮句柄终态，未推送。正常入口中袋0.7s仍v≈0.064m/s、omega未停，当前入口断言不包含停稳；完整新构建4s验证待做。

## DR-191补充：三角化差异关闭，采样上缘问题保留（2026-09-13）
- reference_triangulation.py独立复现物理网格的主平面耳切，build_bag_triangulated_reference.py对原始测量四边形先三角化、再构建面积重心截面；保留此前多边形参考不覆盖。bundled-bag-triangulated-parity.json六袋逐点最大误差3.14e-16m，原0.607mm差异归于三角化处理，不是窗口/坐标错误。bag-triangulation-difference-localized.json定位最大差异在中袋pocket4顶部y=.7600000119。
- bag-input-and-settle-r1终态0，六袋含原始输入三角面导出及新构建4s承接共2测0失败，约255s；角/中袋最终平移与自旋近浮点零，原高度/能量/停止断言保持。正式App入口仍未接入。
- 新增独立细分参考：2.5mm/64点→1.25mm/128点→.625mm/256点。compare_bag_resolution.py及compare_bag_finer_resolution.py输出同高度插值环轮廓双向距离；这是采样比较，不是全三角面Hausdorff误差认证。
- bag-resolution-comparison.json：角袋最大.335mm，中袋4.80/5.16mm；bag-resolution-finer-comparison.json：角袋.188mm，中袋4.30/4.52mm，后者未呈可接受的全域收敛。异常集中在台面下40–45mm，排除该顶部带后本轮最大.420mm。不能因为单球停稳通过而宣称几何精度全面通过，也不能直接移动顶部配置掩盖误差。
- 下一步：观察40–45mm顶部网线/连接件与实际Leather覆盖关系，确认这段表面是否应属于承接代理、如何接续；再做几何/运动收敛与完整袋内多球。当前保持默认原型配置，不用5mm误差反推捕获阈值。
- bag-resolution-gate、bag-resolution-doc-size与diff检查通过；本轮所有xcodebuild/Python/门禁句柄均已终态，未推送。保留完整xcresult内的六袋输入三角面附件，后续可导出用于上缘诊断。

## DR-192：浅层同材质部件与袋网分离（2026-09-13）
- 查看middle-pocket-upper-sections.png、middle-pocket-upper-worst-sections.png与middle-pocket-comparison-overlay.png：大轮廓差异在中袋两侧，原始截面可见浅小部件；未平移顶部或强行平滑。bag-component-bounds.json定位pocket4两个独立352面分量7893/11061，深度41.555–43.897mm，约2.76×2.34×21.21mm，均不延伸至袋底。White不是袋网专属材质；不依靠外观猜测其具体用途。
- 按共享精确顶点建立连通分量，保留触及全局测量底部以上一球半径带的完整分量。Python select_bag_strands.py独立在原始面筛选，角袋7458/10988面，中袋7547/11077面；Swift在三角面筛选，角袋14630/21686，中袋14800/21856。保留分量全高，40mm顶部不变。
- 三档筛选后参考与compare_bag_strands*.py：2.5mm/64→1.25mm/128最大角袋.335mm、中袋.490mm；再至.625mm/256最大角袋.188mm、中袋.420mm。输出bag-strands-resolution.json和bag-strands-finer-resolution.json；仅是同高插值环的采样比较，未称全表面认证或运动收敛。
- PocketBagEnvelope.build新增radius默认BallPhysics.radius（正有限），连通筛选及sourceTriangleCount/selectedTriangleCount诊断。构造同面细化测试增加独立浅三角片，验证袋轮廓完全不变且仅排除该片；不凭面数识别真实部件。
- bag-strand-selection-r1终态0，六袋构建/细化及浅片不变量/角中袋正常台面入口三项0失败，约53s。导出六袋实际三角输入；bag-strand-selection-parity.json与独立原面筛选/三角化参考最大逐点差3.14e-16m。
- 下一步：筛选后完整停稳与运动双分辨率、多球袋内承接，之后ConfirmedCapture及正式入口。旧DR-191四秒停稳为筛选前结果，不能直接算本轮完整停稳复验。当前真实资产消费规则以后换模型须重验，正式simulate尚未切换。
- bag-strands-gate、bag-strands-doc-size与diff检查通过，本轮所有模拟器/Python/门禁进程终态，未发布或推送。

## 筛选后运动分辨率验证：失败保留（2026-09-13）
- 新增testBagMotionConvergesAcrossEnvelopeResolutions：角/中袋从台面以0.7m/s纯滚动进入，同一maxStep=.00125、同一系数，比较2.5mm/64与1.25mm/128几何；701个共同绝对时间点检查位置，保持2mm上限，并检查各自产生的高度/能量。未修改生产算法或降低断言。
- bag-motion-resolution-r1终态65：运动收敛两处断言失败（角袋最大15.1917mm，t=.7；中袋7.8652mm，t=.51）；独立筛选后完整4s承接/平移自旋停稳通过。共2个测试方法、2处失败，总约531s，不能把整套测试记作通过。
- 导出bag-motion-resolution-r1-attachments；analyze_bag_motion_resolution.py生成bag-motion-resolution-diagnosis.json及已查看bag-motion-resolution-differences.png。角袋首次超过.01mm在.239s、超过2mm在.266s；中袋分别.269s/.282s。入袋前可视曲线重合，袋内运动开始分离；这不是接触事件精确时刻，还需原始接触数据。
- 角袋t=.7两几何均在同一底面Y，但XZ相差15mm；中袋t=.51同一底面Y也有7.9mm差异。因此轮廓亚毫米采样变化和“最后能停稳”均不足以证明运动收敛。不得扩大误差或把候选全面接入来绕过此失败。
- 下一步：在角袋.239s、中袋.269s附近缩小复现，导出每个接触的法向/三角面与前后完整状态；区分接触几何/法向变化与积分误差，并检查代理表面建模。随后保留同一2mm比较重验，多球/捕获/正式入口仍未完成。
- bag-motion-resolution-gate、bag-motion-resolution-doc-size与diff检查通过；这些静态门禁不抵消运动用例失败。本轮所有测试/门禁句柄已终态，未发布或推送。

## 首次接触的时间步/几何隔离（2026-09-13）
- 新增短时诊断到.3s，保留全部接触时刻、法向、三角面及接触前后完整状态；案例为64/2.5mm网格步长1.25/.625ms、128/1.25mm网格步长.625ms。bag-first-contact-r1终态0，生成六份附件；这是诊断执行成功，不代表原运动收敛断言已过。
- analyze_first_bag_contact.py与bag-first-contact-diagnosis.json：时间步减半的.3s末位差角袋1.98e-10m、中袋5.61e-9m；几何加密差分别3.14/4.17mm。首次袋内法向几何夹角4.619°/7.386°，入口速度基本相同，反弹速度明显变化，故当前主要原因是接触几何离散，而非本次积分时间步。
- inspect_first_contact_features.py量化：角袋两档均命中三角面内部；中袋粗档命中环边（重心坐标一项约0），细档命中面内部。保存bag-first-contact-features.json，未通过改摩擦/恢复系数去抵消法向变化。
- bag-first-contact-finer-r1终态0，追加256/.625mm网格、.625ms时间步的两袋诊断。相对128网格，首次接触法向差角袋.0304°/中袋.0871°，.3s末位差.0260/.0730mm。详bag-first-contact-finer-diagnosis.json。说明更细档在首次接触附近收敛，尚不能代表完整.7s。
- 新增testBagMotionConvergesAtFinerEnvelopeResolution调用同一完整比较及原2mm断言，以128→256验证完整.7s；旧64→128失败用例保留不删，默认配置尚未改。完整运行结果随后记录。
- 完整128→256比较bag-motion-finer-r1终态65，未得到角袋完整比较结果：pid83724在02:59:03以signal9退出，XCTest重启后0测试汇总不能算通过。xcresult test-results summary明确Test crashed with signal kill。诊断目录bag-motion-finer-r1-diagnostics及bag-finer-kill-host.log保留；host日志只见渲染连接随进程退出失效，未证实OOM、超时或外部操作原因。
- 本轮并未启动重复运行来掩盖kill。下一步将长时物理测试改为消费已验证坐标契约的纯数值资产，避免完整AngleTrainingScene/房间渲染资源，并继续同一128→256、.7s、2mm比较。正式默认64配置仍未升级，原完整收敛失败仍有效。
- bag-first-contact-gate终态2：路由表层签名检测报extra=[QiuJi/Features/Profile/Views/SettingsView.swift]，未通过；本轮没有修改该文件或路由基线，待核对当前共享工作区变化后处理，不能盲目刷新签名。bag-first-contact-doc-size与diff检查通过。所有本轮测试/日志查询/门禁句柄终态，未发布推送。

## DR-193：纯数值资产、路由审计与长测隔离（2026-09-13）
- PocketGeometryAsset新增bagSourceTrianglesByPocketID，独立校准球桌提取White三角面一次缓存，原始材料分量仍由Envelope筛选。完整运动比较不再构建AngleTrainingScene。numeric-bag-parity-r1六袋逐点与可见场景1e-12内一致、缓存身份验证通过。
- numeric-bag-motion-r1在旧2447设备再次终态65/SIGKILL；日志出现本用例未执行的settings.ballSticker.vintage UI自动化查询及XCTAutomation支持加载，表明存在同设备自动化干扰。没有据此认定物理/内存错误，也不声称已确定前次kill的具体调用来源。
- 新建专用QiuJi-W07-Numeric-Isolated-20260913，UDID **EC19B1C4-AFE2-4E9E-B12C-1A2FDC6415DC**，同iPhone17Pro/iOS26.3 Runtime。原有模拟器保持原状态，未停他任务进程。后续数值长测使用此ID，DerivedData仍output/3d-v63/DerivedData；当前numeric-bag-motion-isolated-r1正在执行，最终结果随后补充。
- 初版numeric-bag-resource-samples.jsonl错误匹配了自身shell命令，不是App RSS证据，保留并作废；改用sample_numeric_bag_process.py按可执行路径与新UDID匹配，未找到目标进程时输出空数组，不报告内存值。
- SettingsView源码可达性已审计：两个生产NavigationLink指向TableStyleSelectionView/BallStickerSettingsView，目标叶页存在。settings-route-audit.md与route-coverage.csv登记源码范围及UI待验；未修改生产页面。仅更新审计的SettingsView签名，其后共享工作区其他签名曾再漂移，未盲刷；numeric-bag-gate-r2在当前状态通过，routes79。此前两个失败门禁保留。
- 专用长测仍在运行，未重启：functions exec session **92750**，xcodebuild pid94296，App pid95876；numeric-bag-motion-isolated-r1.log最新已至角袋256档t≈.519s。下轮先poll同一session或核对该pid/xcresult，不能因观察窗口结束重新启动。
- sample_numeric_bag_process.py已真实匹配新App：样本RSS约504→331→165MiB，见numeric-bag-isolated-memory.jsonl；仅为macOS模拟器观测，不能称真机内存预算已过。旧初版自匹配样本仍作废。
- numeric-bag-gate-r2、numeric-bag-doc-size与diff检查通过。当前只有上述专用完整运动测试仍活跃；未宣称测试完成，未发布或推送。
- 最近一次观察：角袋128→256完整.7s最大位差 **0.177745mm**（t=.334），原2mm断言通过；已继续中袋阶段（日志时间重新从0开始）。整项测试尚未终态，仍续等session92750。

## 完整细分运动通过与袋底双球反例（2026-09-13）
- numeric-bag-motion-isolated-r1 同一进程自然结束，exit0，1测0失败，执行1052.600s。128点/1.25mm与256点/.625mm，角/中袋各完整.7s、701个共同采样点；最大位差角袋0.177745mm(t=.334)、中袋0.826204mm(t=.698)，原2mm标准及高度/能量断言未改。
- 四组原始附件已导出至numeric-bag-motion-isolated-r1-attachments；plot_finer_motion.py独立重算并生成finer-motion-comparison.json/png，原图已审。仅证明此输入/时段几何细分差异；不是全袋型、手机性能或完整W07验收。旧粗网格失败与两个SIGKILL结果保留。
- 新增testBundledBagSupportsAnIncomingBallAboveAnOccupiedBottom，数值缓存+显式128/1.25mm候选、角/中袋，初始袋底一球与上方5mm净间隙落球；验证初始有限面间隙、连续球间不穿透、共同时间、能量/底部边界和实际球球事件。球球恢复取BallPhysics.restitution，摩擦0.05及袋面参数仍是原型，未实标。
- occupied-bag-r1终态65，一项抛convergence(residual:7.997558904015989e-08)。角袋首次承接冲击含大量完全相同的向上静态约束，来自底盖共点三角扇；不是初始穿透。尚不能宣称双球承接通过。
- 新增独立duplicate-static冲量测试：同一支撑复制2/64/128/256份、正反顺序、竖直/有切向两种入射，竖直结果另对解析上球反弹e*v、下球静止。先跑原求解器红控制，再决定精确同约束去重；不近似合并法线/材料，不修改迭代预算与残差。

## DR-197验收补充（2026-09-13）
- resolveCoupled对完全相同body/normal/material的静态冲量约束精确去重；不近似合并法线，不改4096预算/64ulp残差。occupied-bag-r3终态0，真实角中袋承接、独立重复数量/正反顺序/解析与切向响应、跨owner支撑共3测通过（53.196s）。两袋各两次球球接触，.12s上球仍在反弹；本测试不包含最终停稳，也不代表从台面进入的完整双球过程。
- 原occupied-bag-r1实际收敛失败保留。duplicate-impact-red-r1和occupied-bag-r2都在BallStickerTests:129编译失败，没有执行物理测试；只将原RGB误差reduce拆为具名中间量，计算/阈值不变，r3编译通过。该测试文件的视觉行为未由本轮验收。
- duplicate-impact-regression-r1遇到共享AngleTrainingScene调用showsSights与marker接口不匹配的编译中间态，未修改该渲染接口。使用r3已构建包test-without-building：duplicate-impact-regression-built-r1终态0，独立棱角/非共面接缝/近停双球/高速同刻四测通过；前后App及测试包SHA256完全一致（duplicate-impact-built-hashes.txt）。此结果只证明该构建，不声明当前全部共享源码构建通过。
- occupied-bag-r3-attachments保留事件状态，plot_occupied_bag.py生成occupied-bag-fixture.png，已检查两球高度与袋底关系；灰色为独立128档参考轮廓投影，不是App画面或全表面间隙认证。
- occupied-bag-gate-r1、occupied-bag-doc-size-r1与diff检查通过（各自运行时快照）。所有本轮测试句柄已终态，没有遗留长测。
- 下一步：将已验证的128/1.25mm候选收敛到默认配置并重新明确粗网格诊断测试含义（当前默认仍64/2.5mm，未偷偷改动）；继续真正台面入口双球+袋内接续/时段收敛与性能，完成ConfirmedCapture生产条件及主引擎/预测/规则全部入口。W07未完成，W08–W16/H01–H04完整范围保留；未发布/推送。
- 另在编译日志发现CollisionResolver.resolveSupport的scale换行以一元+开始，第二球尺度项可能未纳入；本轮未混入该相邻修改，下一轮须用异速/自旋接触反例核对后修正。

## DR-198：默认128档与完整台面双球（2026-09-13）
- 默认改为128点/1.25mm；testBagMotionConvergesAcrossEnvelopeResolutions仍比较默认与两倍分辨率、原2mm断言不变，与先前已通过的128→256物理配置相同。移除重复finer包装；历史短时诊断显式固定64/2.5mm基准，旧失败原始文件保留。
- bag-default128-r1终态0，六袋72环/18304面、细分与浅部组件不变量、角中袋正常入口三测通过（147.423s）；gate/doc-size/diff检查通过。未重跑参数完全相同的17分钟完整几何比较，不将先前结果称为本次新跑。
- runConsecutivePocketEntry复用原testTwoConsecutiveBallsActuallyFallThroughEachPocket的真实台面起始点/两球0.5m/s/0.8s流程；includeBag:true加入默认承接几何、连续球间间隙/底部边界、共同时钟、能量与必须发生球球事件的断言，保留false原用例。原型球球e=.9/摩擦.05不代表已实标。
- consecutive-bag-entry-r1正在专用模拟器运行，session57177，App17740；不可因观察到时重新启动。普通单球回归通过不代表此完整双球已过，后续先核同一进程/句柄终态。
- bag-default128-sample.txt采集运行中Debug栈，主要时间落在连续三角面求根；是优化定位线索，不是手机帧率/性能验收。暂未用性能理由放宽精度或改几何。
- 正式simulate与ConfirmedCapture生产者仍未接入。DR-197记录的resolveSupport第二球scale换行问题仍待专项反例；完整双球结束后处理，避免本轮同时改变数值模型。

## 完整双球续等与舍入尺度回归准备（2026-09-13）
- 上一轮为实质进展（默认精度落地+三测通过）；本轮续查session57177及App17740均仍活跃，未重启。最近日志epoch128/time=.3175，App运行4分32秒/97.2%CPU；这不是测试终态。
- consecutive-bag-entry-r1-sample2.txt第二次2秒采样仍落在advanceTogether/integrate/三角面firstContact求根，未落在assertContinuousPairClearance的断言细分循环；暂不能判死锁或失败，继续跟踪同一句柄。
- 已新增testPairSupportSlipRoundingIncludesBothBodies，尚未编译/运行。构造A静止、B的vz=-1及omegaX=(1/R).nextUp，接触法线+Y；交换A/B和法线后，应保持相同物体加速度。独立Python按实际Float半径计算：残余接触滑速-2.220446049250313e-16，完整舍入界7.105427357601002e-15；旧A-only scale为0，会将它保留成非零滑动。该反例验证后再修换行运算，不提前宣称通过。
- 当前没有新生产代码改动，没有更改求解预算或终止长测。下一步仍先poll57177/读同一日志终态，随后执行新增回归；W07–W16/H01–H04保持未完成。

## DR-199独立Swift反例（2026-09-13）
- 为避免重装正在长测的模拟器，check_support_rounding.py从当前TableGeometry/CollisionResolver原样提取PocketContactResponse/SpatialBallContact，编译独立macOS Swift可执行文件；无替代实现/mock。source摘要和原失败源码support-rounding-red.swift保留。
- support-rounding-red-r1 exit1：正序力z=3.172065784643305e-11，反序0；编译警告直接指出未使用一元+表达式。修复二元+换行后support-rounding-green-r1 exit0，正反序切向力0、编号交换误差0；旧失败不覆盖。
- 新iOS testPairSupportSlipRoundingIncludesBothBodies尚未运行。当前consecutive-bag-entry-r1仍是修复前构建；不能把它算作DR-199回归。下一步先poll同一session57177；长测终态后跑新增iOS反例及现有有限步摩擦/近停回归。

## 连续碰撞求根的独立性能小样（2026-09-13）
- 当前consecutive-bag-entry-r1仍同一句柄57177/App17740，最新核实运行12分09秒/98.7%CPU/RSS约164MiB，日志最后epoch128/time=.3175。未终止/重启，不当作完成或失败。
- check_contact_pruning.py保留原PocketContactTriangle+QuarticSolver，另生成仅内部roots增加保守位移上界筛选的副本：距离大于R+|v|dt+|a|dt²/2及算术余量时才跳过顶点/无限边线求根；投影不增位移。仅output小样，生产firstContact未改。
- 首轮小样Swift字面量`.1`编译失败，保留contact-pruning-compile.log；修为0.1后r2执行exit0。12000组固定种子三角面/退化面/不同速度加速度和horizon输入，5945个命中，TOI/点/法线逐值完全一致；优化版约.0637s、原版.0814s。此随机小样不是实际袋网或手机性能结论。
- 已导出bag-default128-r1-attachments，包含六袋原始几何及真实角/中袋正常入口状态，供下一步真实候选窗口对拍；不得只凭随机对拍把优化接生产。
- DR-199 iOS回归仍待长测终态。先继续poll57177；其结束前不重装专用模拟器；原目标W07–W16/H01–H04保持。

## DR-201真实候选对照与完整双球终态（2026-09-13）
- check_contact_pruning_real.py读取bag-default128-r1导出的环/正常入口位置速度，重建同序侧面与底扇；按原AABB窗口选择角103066/中114670，共217736候选。以零/重力加速度各测，565次命中，旧/筛选版TOI/点/法线完全相同；.5458s→.1600s。此输入不是实际持续力加速度全轨迹，不能称完整运动已对拍。
- 保守位移界已接入firstContact内部roots，DR-201；原求根与有限面验证不变。独立转向反例命中.011270166537925848；十进制端点.1-.09比.01存在表示差，原/新均nil，因此正式端点测试用精确二进制.125-.0625=.0625，两版契约不放宽。iOS针对性回归正在执行。
- consecutive-bag-entry-r1原进程自然终态65，执行962.721s。袋壁/底面/球球三个独立约束的瞬时冲量残差7.532151475080169e-11抛错；不是重复静态约束，也不是超时强杀。完整双球仍未通过。日志保留完整两球v/omega与三法线，已提取testOccupiedBagWallFloorPairImpactConverges快速反例。
- wall-floor-pair-red-r1运行中，session64385：包含新现场反例、DR-199编号对称性、DR-201转向/端点及原有限步/近停回归。预期现场反例可能仍红，不能因其他四项通过关闭W07；先核终态，再分析三约束Coulomb耦合，不增加迭代预算或放宽残差。
- wall-floor-pair-red-r1已终态65：5测1失败，1.059s。现场三约束反例0.060s复现同残差；DR-199编号对称、DR-201转向/端点、原有限步摩擦、近停推进四项通过。长测及快测句柄均终态，无活跃本任务进程。下一步直接用快速现场反例定位Jacobi/Coulomb耦合，再回完整台面入口双球；不得把此红套件写成通过。

## DR-202：三约束冲量快速修复（2026-09-13）
- analyze_wall_floor_impulse.py用独立NumPy映射重现慢模态：原4096次后map残差约4e-11；深度一受保护Anderson约252次降至9.23e-15。该残差是草稿固定点范数，与Swift自然互补残差分开记录。
- Swift resolveCoupled重用motion/mapped/residualSquared，候选经非负法向/切向投影并仅在实际映射残差下降时接受；原4096/64ulp两重检查保留。impulse-acceleration-r1四测0失败，现场0.007s、整体9.001s；覆盖重复数量/顺序、跨owner、高速同刻，旧红日志留存。
- 已启consecutive-bag-entry-r2，session67374，专用EC19B1C4设备；包含DR-199/201/202的当前构建，完整角/中袋双球入口0.8s尚未终态。下一轮先续同一句柄，不能以快测绿代替完整双球结果。
- impulse-acceleration-gate-r1、doc-size及diff检查通过（运行时快照routes80）。唯一活跃本任务为完整consecutive-bag-entry-r2：session67374，App30636，最近epoch128/time=.3175。旧r1及全部快速测试均终态；未发布/推送，下一轮续同句柄。

## 完整双球r2与四约束持续力反例（2026-09-13）
- consecutive-bag-entry-r2自然终态65，153.482s；已越过旧瞬时三约束失败，后续四约束resolveSupport抛convergence(residual:3.3094123584862303e-13)。包含两个球/袋底与两侧壁，详细motions/external/normalRate/系数留于日志。采样时进程已退出，sample命令255不可当活跃栈或失败原因。
- check_bag_force.py原样提取Swift源+真实状态，dt=.0025独立复现完全同残差；.00125/.000625等残差随1/dt增长。新增testOccupiedBagWallFloorPairSupportConverges，bag-force-red-r1已终态65，快速iOS复现。当前无活跃本任务测试。
- bag-force-diagnostic.log最后一步显示主要残差在球0两静态接触的切向更新，压力约5.83/14.70；球0法向速度约4.7e-15（处于原激活舍入界）。仅给requestedT再次投影无效，bag-force-tangent.log保留，未采用。
- 独立8192迭代诊断仍约3.305e-13，排除单纯预算不足；生产4096上限未改。有限步切向要求消除slip/dt，而法向仅要求加速度约束，已有微小法向速度未消除，可能形成不兼容条件。
- bag-force-normal-step.swift仅小样为法向请求加入vn/dt，.0025/.00125/.000625等通过；2^-6档仍1.628e-13失败，不能宣称全部稳定。生产resolveSupport与单球forceMap均未采用该变化；下一步验证共同有限步法向契约、单球/多球一致性及小步极限，再回完整双球r3。严禁只加大容差或预算。
- 原目标W07–W16/H01–H04保持；正式simulate/捕获未接入。DR-202快速冲量验收仍有效，但不能覆盖本次受力失败。

## DR-203：有限步法向一致性与持续力回归（2026-09-13）
- normal-support-step-r3原session37743已自然终态0：六项测试零失败、0.906s，xcresult/log保留。包含四约束真实反例dt=.0025/2^k（k=0...20）、两体舍入、有限步摩擦、堆叠近停、不同折面、跨owner同刻支撑。
- 单/多球法向加入vn/dt，原单球最终约束检查同步；多球受保护Anderson只在原自然残差下降时采用，4096与64ulp不变。独立normal-step曾在第6档失败，加入外推后21档通过。
- r2并非通过：独立SIMD归一化/点乘导致纳秒dt下加速度形式放大舍入；bag-force-normal-evaluation.swift/log给出原始系数对照。r3仍保留原1e-12加速度断言，采用一致标量系数，另独立SIMD检查步末速度64ulp尺度。没有用改阈值掩盖失败。
- 已启完整consecutive-bag-entry-r3，session24955，专用EC19B1C4模拟器，当前源码Debug构建；先续同一句柄，不因观察超时重启。W07生产捕获/预测尚未接入，W08–W16/H01–H04保留。
- normal-support-gate-r1内容/路由/写盘门禁通过（80 routes /146 write-surfaces）；verify-doc-size通过（97KB/10条）；git diff --check通过。完整r3仍活跃，session24955/App35962，最近实测运行3分44秒、100%CPU，模拟时间已达.643524；拒步日志不是测试失败终态。sample1保存实际积分/接触求根栈；下轮必须续同一句柄，未重启。
- 生产接入复核：simulateMixedWithLocalPockets当前只构建asset.tablePatches，未包含已验袋承接代理；recordConfirmedCapture仍无正式物理生产者。之后须同时处理默认袋几何接入、捕获判定与所有生产/预测入口，不能只切换调用名。

## 连续双球r3续等与最近点热点小样（2026-09-13）
- 原session24955/App35962持续活跃；本轮最新确认运行8分01秒/99%CPU，未重启或终止。日志最后拒步状态time=.643524，尚无完整测试终态；拒步不等于失败。下一轮先续该句柄。
- sample1与sample2实际运行栈显示热点主要是projectContactPositions逐面closestPoint（sample2约945/989采样），而非仅firstContact求根；先前概括为积分/求根不足以描述主热点，本条细化证据。原日志/采样保留。
- 独立check_closest_point.py提取当前原始方法，生成仅去除临时edges/map数组的同序计算候选，生产代码未改。closest-point-comparison-r1 exit0：10万随机/退化/顶点输入逐值相等；macOS -O约.008507s→.002411s，源码摘要在输出中。并非真实袋网全轨迹对拍或手机性能验收，不能据此直接宣布优化落地。
- 生产缺口重核：PocketGeometryAsset在Core/Scene/TrajectoryRenderer.swift持有原始bagSourceTriangles，混合引擎仅取tablePatches；后续要纳入袋代理/一致几何版本及ConfirmedCapture生产条件。完整W07与后续范围未变。

## 连续双球r3终态与五约束投影现场（2026-09-13）
- 原session24955自然终态65，单测622.785s失败；已推进至time=.6893224432611166，projectPressure五约束达到4096上限。两球/两处球0静态面/球1相邻面13230与13231；原始与末态完整记录在日志。不是观察超时、未被强杀，DR-203受力修正不能据此宣称整个双球通过。
- 最近点候选补217736实际袋网/正常入口候选查询，逐值一致，-O约.018829→.004034s，-Onone约.473010→.218360s；仅独立macOS方法对照，未替换生产closestPoint，也未宣称完整轨迹等价。
- 新增testOccupiedBagPressureProjectionAtSharedTriangleEdge，按真实资产/固定接触索引重建五约束，保留完整现场p/v/omega并输出四面坐标附件。PressureContact/projectPressure从private改为internal仅供@testable直接回归，算法不变；后续若调整须记录DR及独立几何/速度约束断言。
- pressure-edge-red-r1正在专用模拟器运行，session1008；完整r3已终态，无其他本任务长测。下一轮先核快速现场红测结果/附件，再分析共享边接触和收敛，禁止提高阈值或迭代数。
- pressure-edge-red-r1已自然终态65，4.340s精确复现同一projectPressure iterationLimit，四面/两球附件已导出至pressure-edge-red-r1-attachments；当前无活跃测试句柄。
- analyze_pressure_faces.py读取该附件：13230球心垂足三个边符号均正（最小5.970e-9），13231一个边符号负（-1.140e-7），两面共用两顶点、法线差约.0029684。不能当精确重复面去重；需核实持续支撑是否保留被相邻面覆盖的边特征。压力投影算法未修，快速红测保留，下一步先追exposedSupportCandidates与sustainedPairAcceleration/projectPressure的候选一致性。

## DR-204/205：投影修正与完整r4（2026-09-13）
- pressure-edge-r2终态0，4测0失败，7.001s；现场5.980s，包括真实资产加载。projectPressure每轮重评估被面覆盖边；现场新增保留面/球球间隙与法向速度独立断言，释放边仍检查不穿透。原真实折面/非共面边/近停回归均通过；持续力和CCD候选不变。
- 最近点同序去临时数组候选已接入，DR-205；独立逐值对照源/日志保留。未擅自改变局部几何或收敛阈值。
- consecutive-bag-entry-r4已启，session90463，专用EC19B1C4，含当前源码完整双球、现场投影、转向端点、非共面边、真实折面共5项。下一轮先续同一句柄；r3与r2快速测试均终态。正式捕获和后续范围未完成。
- pressure-edge-gate-r1门禁通过（80 routes/146 write-surfaces）、文档体积97KB/10条通过、diff检查通过。r4当前构建现场投影5.042s已过，完整双球仍运行：session90463/App44392，最新核实1分33秒/100%CPU。其余三几何项尚未执行，不能把五项套件称通过；下一轮续同句柄。
- r4续等已核实时长5分01秒/98.6%CPU，session90463/App44392仍活跃，无终态；本轮为具体句柄的验证等待。r3-r4-diagnostic-prefix.json确认目前两条拒步状态日志逐字一致，仅稀疏诊断点，不是全轨迹对拍。下一轮继续同句柄，不能重启；仍未越过原失败点的可见日志证据。
- r4续等：session90463/App44392最新核实11分44秒/100%CPU，仍未终态；新增日志time=.6817578，同刻分步事件差异被自适应拒绝。consecutive-bag-entry-r4-sample1实际栈仍以projectContactPositions为主，说明去数组未消除算法热点，不能将方法小样加速宣传成App性能达标。当前未改代码/重启，下一轮续同句柄。

## r4越过失败点并完成角袋段（2026-09-13）
- 日志静默期间两次LLDB只读附加读取栈/局部状态后明确process detach，debugger1/2日志保存；未重启或改变状态。实际time=.78603485875229295证明已越过原.689322投影失败，不能仅由CPU推断。
- 后续原日志输出角袋pocket0完整time=.8、epochs12、pairs11；目前未输出该段断言失败，附件待整项终态导出。随后time重新从.3175开始，为中袋阶段。整项/五测套件仍未终态，session90463/App44392继续；不把角袋段当作全部W07验收。
- 因调试器短暂暂停，本次墙钟耗时不得作为未干扰的性能基准；轨迹/断言仍可按其实际范围核验。正式捕获及W08–W16/H01–H04仍未完成。

## DR-206：等待中袋时准备共享袋代理（2026-09-13）
- r4仍是原session90463/App44392，中袋流程活跃；本次新增源码未进入该既有二进制，r4只能证明DR-204/205版本的数值行为。
- PocketGeometryAsset新增bagEnvelopes() throws：按默认精度/稳定ID一次构建全套纯数值代理，实例独立锁、成功后原子发布缓存；未改变求解器、材料参数或正式simulate。
- 既有六袋测试扩展为与独立可见场景rings/bottom/面数对照，尚未编译运行。r4终态后执行testBagEnvelopeBuildsFromBundledNetForAllSixPockets；不要为运行该测试中断或重装活跃模拟器。

## r4中袋异常模式、主动取消与快速复现（2026-09-13）
- 中袋从time=.664386起连续13条同类whole无事件/fine有3接触的差异，约52微秒推进，后续dt约1.22微秒；middle-event-mismatch-r4.json保存完整现场。该重复异常模式构成主动取消依据，不是因观察到时判终态。
- 向已核实xcodebuild44237发SIGINT，原session90463最终exit73，日志TEST INTERRUPTED、App44392退出；r4不是通过或自然失败。所有未执行几何项不算通过。角袋完整轨迹附件已成功导出至consecutive-bag-entry-r4-attachments。
- 初始中袋对间隙约-1.416e-14m、相对法向速度1.281e-14m/s；新testMiddleBagPressureStepDoesNotInventSplitImpact用原time=.664386295473439、dt=1.953125e-5及完整p/v/omega对照whole/half/fine。当前把持续支撑不得凭分步生成冲击作为待验证假设；需读实际法向/受力证据，不能仅以测试名称当物理证明。
- 已启动middle-split-red-r1，session71059，专用EC19B1C4；包含现场短步、DR-206六袋独立场景对照、转向端点、非共面边、真实折面共5项。下一轮先核该句柄终态。完整W07/生产捕获与后续范围保持未完成。
- middle-split-red-r1终态65为新增测试`)}+`空格导致的Swift编译错误，没有执行；修为二元运算符后r2终态65，5测中现场方法两断言失败（7.604s），其他4测通过。half/fine实际停在.664396061098439，whole到.664405826723439，完整状态/接触日志保留；可直接定位，不再以20分钟入口作首轮反馈。
- DR-206六袋独立可见场景rings/bottom/面数对照通过（8.281s），另三项转向端点/非共面边/真实折面通过。两套红日志均保留；当前所有本任务进程已终态，无活跃测试。下一步分析中袋短步返回的接触法向、持续受力与分步后激活条件，保留原阈值。

## DR-207：中袋新壁接触及时联合求解（2026-09-13）
- middle-split-diagnostic-r1终态65，支撑计划显示initial有袋底24275/球球/袋壁14440；half仅剩球1壁。球0新壁21489在.66438714895实际碰撞；half末新壁vn=-8.165e-6、底部间隙5.718e-12。旧“无新冲击”测试前提错误，真实新壁必须保留。
- advanceCoupledTrial纳入loadedBodies首次静态接触，统一事件前缀与共享冲量；测试改验首次新壁事件截断，旧失败与前提纠正记录DR-207。没有加大舍入或迭代上限。
- middle-shared-impact-r1终态0：3测0失败、11.120s，现场7.102s；原无新接触压力与堆叠近停通过。
- 新增现场后1ms持续推进、连续间隙断言，middle-shared-continuation-r1正在执行，session4341，专用EC19B1C4。下一轮先核同句柄。r4仍是主动取消，完整双球/W07/生产捕获与后续范围仍未完成。

## DR-208：联合微反弹与完整r5（2026-09-13）
- middle-shared-continuation-r1复现重复微秒事件差异，确认原xcodebuild55319后SIGINT主动取消，session4341终态73；不是自然失败/通过，日志保留。
- check_group_microrebound.py独立投影现场全组法向，能量下降、法向残余约1e-19，重力反弹高度4.203e-14m。原样Swift持续力在.00025/.000125/.000001三dt都给出正压力；不作为iOS验收替代。
- preparedGroupSupport已接入：真实入射不消除，低于既有空间预算的向外微反弹整组投影；全部接触无新穿入、能量不增加、重新求力确认微接触承压后才接受；无候选回原流程，保留位置/自旋/时间及原阈值。
- group-microrebound-r1已终态0，3测0失败，14.155s。现场1ms在2次推进到.665386295473439，连续间隙/能量/状态保持/真实入射断言通过，另原持续压力与堆叠近停通过。
- 已启consecutive-bag-entry-r5，专用EC19B1C4，完整角/中袋台面起始双球与跨owner/重复静态接触共3项；下一轮先续新句柄，不重复启动。W07生产捕获及W08–W16/H01–H04保持未完成。
- r5运行句柄为session92046；跨owner支撑0.006s、重复静态接触0.013s已通过，完整双球日志epoch128/time=.3175，尚未终态。group-microrebound-gate-r1门禁通过、文档97KB/10条通过、diff检查通过；下一轮续92046，不将两项回归算作整个三测套件通过。

## r5终态与错误现场诊断（2026-09-13）
- 完整双球r5自然失败，142.400s抛invalidInput；跨owner及重复接触两项通过，三测套件失败。xcresult无可导出轨迹附件，不能宣称角袋段完成。
- 检查DR-207路径发现待验证假设：新静态碰撞触发共享事件，但resolveContactGroup仍要求球球约束；仅凭源码不能确认本次命中。新增DEBUG错误现场及无球球约束日志，原错误继续抛出、全部物理判据保持。
- consecutive-bag-diagnostic-r1已启动，session38923，专用EC19B1C4；下一轮续同句柄，先取证再修因。生产捕获及后续完整范围仍未完成。

- diagnostic-r1终态65，137.338s复现并确认命中resolveContactGroup无球球约束guard：角袋事件time=.6401624918538632，4条静态约束，投影前后位置相同；整步起点.6395079239818969/dt=.0010955921681824476。现场与独立球间隙计算保存在static-event-without-pair-r1.json（间隙1.954034156703699e-12m）。下一步从该真实现场构造短回归，审查静态事件有效性及主调度对约束的解释，修正入口契约；本轮只加诊断，尚未修复。当前本任务测试均已终态。文档体积与diff检查通过。
- 口径校正：独立计算球间隙仅1.954e-12m；只能确认当前几何超出接触舍入窗，不能把它定性为宏观真实分离。后续须区分持续力预测的微小接触漂移与真实脱离，再决定共享事件契约/接触重建修复，禁止简单放宽球球阈值。

## DR-210：真实半步现场修复（2026-09-13）
- corner-loaded-event-red-r1固定步7.546s通过，未复现；改回实际共享误差控制后red-r2在9.107s同guard失败，原记录保留。
- 事件前缀新增承压几何校正，原入射速度/自旋/时钟不变；未放宽球球阈值或移除guard。event-pressure-geometry-r1三测通过，完整测试待续。
- event-pressure-geometry-r1终态0：角袋10.668s、跨owner0.003s、中袋7.165s，合计17.836s/3测。门禁81 routes/146 write-surfaces通过、文档97KB/10条通过、diff检查通过。
- 完整consecutive-bag-entry-r6运行中，session35145/xcodebuild66739，专用EC19B1C4；最近核实进程时长2分58秒，日志已到.628054拒步现场。下一轮必须续同句柄，不以观察超时重启；尚无完整终态，不能宣称越过原失败点或W07通过。

## DR-211：r6五约束受力与快速修复（2026-09-13）
- r6/session35145终态65：228.525s自然失败，越过原.64016，但.65215138五约束持续力残差1.3440359936112145e-12。support-r6-source.json保留完整现场，mismatches-r6保留事件差异；不算W07通过。
- 原样Swift和iOS five-support-red-r1（0.188s）复现，沿原迭代方向到边界实验仍失败。载荷重分配独立小样收敛；正式候选增加active及切向投影护栏后iOS9项通过，未调容差/迭代上限。
- support-transfer-r1实际3测14.206s；boundaries-r1实际1测3.272s；boundaries-r2实际5测1.300s。原评论数量误报已更正并记FL-065，按实际方法与计数验收。
- 完整r7已启动并确认仍运行，session47988，专用EC19B1C4；最新日志epoch128/time=.3175。下一轮续同句柄，不重启；尚未终态。support-transfer-gate-r1通过（81 routes/146 write-surfaces），文档98KB/10条通过，diff检查通过。W07生产捕获及W08–W16/H01–H04仍未完成。

## DR-212与用户优先级校正（2026-09-13）
- r7/session47988终态65，145.795s返回球对见证丢失，独立量化static-event-without-pair-r7.json；采样sample1已保存。短回归red-r1复现，r1物理修复后仅复制的静态冲击断言不符现场，改验静态支撑/分离后接近/碰后不相向/无动能增加，r2实际4测通过15.123s。原失败均保留。
- 当前session39865终态0，无本任务活跃测试；未启动完整r8。用户质疑固定终态与投入，明确承认袋底持续多球求解优先级过高。下一步优先落实既有方案§5.7捕获及必要可见运动停止边界，复核可见收尾；保留袋口临界/吐袋/影响在场球的真实物理，不将长期袋底堆积作为推广前置。完整目标W07–W16/H01–H04不变。

## DR-213：落实产品停止边界（2026-09-13）
- 新PocketCaptureBoundary及ADR-P10-10/v63.10：硬质袋口运动保留，软袋采用吸收式收集。候选必须完整通过硬质下沿、向下且投影在实际截面；提交还须同钟活动邻球隔离。
- collection-boundary-r1/session2224终态0，3测6.879s；normal-entry-collection-r1/session4336终态0，1测6.705s，实际角/中入口time=.2584936811/.2894187022；能量/穿越正确。
- 附件均导出，collection-boundaries.png已目视核对六袋截面。候选中心Y≈.71519/.71522m，硬面下沿≈.74376/.74380m，留可见收尾空间。无活跃测试；下一步调度提交/固定终态收尾、临界吐袋与近袋多球，再统一播放消费者。W07及完整后续目标仍未完成。

## DR-214：调度收集与停止（2026-09-13）
- 混合验证入口新增collectsPocketedBalls，默认false。最早候选截断/跨域事件竞争/同钟邻球筛选，pending完整提交才记录捕获并移出ownership；原空间运动记录至真实入口，运行时停止与记录分开。稳定收集几何版本已实现。
- mixed-collection-r1/session81280终态0，实际2测14.463s；mixed-collection-boundaries-r1/session20180终态0，实际3测15.561s。普通角/中袋、唯一事件、分段逐值、连续两球与远端静球、既有续算/返回均通过。无活跃测试。
- 下一步捕获后的共享短可见收尾与真实视角检查，然后临界吐袋/近袋互动、参数及正式simulate/预测/规则消费者切换。W07后续完整范围不变；当前捕获平面停止状态不能当最终画面交付。

## DR-215：共享收尾与可见性检查（2026-09-13）
- collection-tail-r1终态0，实际3测12.328s；collection-visual-r1/session77825终态0，实际1测11.697s。无本任务活跃测试。数值/查询/倍率/续算通过，角袋与中袋各7帧原图已打开检查，球下降后被袋沿遮挡、固定终态不可见。
- 截图位于output/3d-v63/W07/collection-visual-r1-attachments/，manifest.json保留文件映射。这里仅验证组件位置/透明度，不将静态帧当动画流畅度、自转、正式页面或视频导出的验收。
- 收尾统一到记录查询并接入action/导出新记录分支；正式simulate尚未启用。下一步优先临界吐袋与袋角反弹、近袋活动邻球，随后系数/正式入口/预测/规则与W08消费者；不再启动完整袋底堆积r8。完整W07–W16/H01–H04范围不变。
- collection-tail-gate-r1终态0：81 routes/146 write-surfaces通过；verify-doc-size通过（98KB/10条），git diff --check通过。未运行视频导出及正式页面验收。

## 收集边界的产品关键回归（2026-09-13）
- collection-critical-r1/session3445终态0，实际2测19.067s。testMixedCollectionDistinguishesSupportedAndUnsupportedPocketEdge（16.762s）覆盖角/中袋实测支撑边界两侧各0.2mm：静止且有支撑不捕获、失撑后下落只捕获一次。testMixedCollectionDoesNotCapturePocketRebounds（2.306s）覆盖角/中袋4m/s真实袋口碰撞后恢复平面所有权，没有捕获、收尾或旧进袋事件。不是完整力度/角度扫描。
- 生产切换审计新增明确缺口：CollisionResolver.resolveBallBall采用BallPhysics.restitution=.95及接触切向速度的Alciatore摩擦；混合入口球球参数仍显式固定，硬面统一restitution=.3/friction=.2，不能直接宣称已与生产一致。应复用既有响应口径并明确局部表面响应，避免把测试系数默认推广。
- 另一个已定位待处理项：混合本地trial.constraints当前直接生成ballBall事件，跨owner分支却按碰前closing<0筛选；持续支撑约束不应被当作新的规则碰撞。正式接入前统一该语义并验证真实规则消费者。
- 下一步仍为正式入口/参数/事件语义与预测规则，随后W08及全页面任务；不回到袋底长期堆积。全部本任务测试已终态，无活跃句柄。

## DR-216：规则球球事件上报统一（2026-09-13）
- spatialImpactEvents共用跨owner既有碰前closing<0约定，本地trial使用beforeEndpoint速度，零时刻使用起态；只改变上报，不裁物理约束。rule-events-red-r1实际1测2断言失败（静止/分离），原输出保留。
- rule-events-r1/session37397终态0，实际4测14.947s；rule-events-local-r1/session97853终态0，实际1测4.671s。上报三态、2/8/12m/s同刻双碰、跨owner接触、捕获续算、纯局部双球碰前不发布/碰后只发布一次均通过。
- 此次修复了上报层和两条调用路径的不一致，不声称正式页面发生过该误判。接下来生产系数/静态接触吃库分类、正式simulate及预测消费仍待统一。全部本任务测试已终态；没有启动袋底堆积长测。

## DR-217：局部球球材料统一（2026-09-13）
- 共用既有BallPhysics恢复系数/Alciatore摩擦，局部冲量与持续力按双方自旋的接触滑速取值；显式supplied基线保留，ballPhysics配置贯穿混合入口、临时solver、pending校验。正式simulate尚未启用。
- ball-material-r1/session12977终态0，实际4测7.224s通过：1001点旧Float位模式、自旋/交换、斜碰冲量/自旋解析值、混合标准配置及缓存拒绝切换、旧固定配置事件。无活跃测试。
- 材料统一与物理响应等价是不同结论，三维保留Y速度；现有平面行为未改。下一步静态台呢/库鼻/皮革响应与吃库分类、正式入口/预算/兜底、预测/规则消费者；全页面W08–W16/H01–H04仍保留。

## DR-218：静态角色分类（2026-09-13）
- 先分析旧原始附件，后独立加载当前全桌物理网格验证：TaiNi有中央床面/下沿与六段库边共7个精确连通部件。实现surfaceRoles，不按单面朝向猜角色；未动材质或几何。
- surface-roles-r1/session10472终态0，实际1测3.094s通过。角色计数9701/9963/24584；缓存/反向面序和绕向/残缺结构/台面下沿均验证。surface-roles-r1-attachments保留原JSON，plot_surface_roles.py生成surface-roles.png并已打开核验顶视/侧投影。
- 缓存纯值且独立锁，未知当前资产结构明确抛错。下一步将角色用于静态响应，并建立真实主库/袋角接触的业务事件映射；当前无吃库上报变更，正式入口及完整后续目标仍未完成。无活跃测试。

## DR-219：吃库业务上报（2026-09-13）
- 库边角色真实接触映射原有限直段/圆弧索引，按球/Double时间/索引去重；业务XZ法线兼容旧消费者，原3D法线保留。台呢及皮革不直接计吃库。新晋升球从共同末态绑定接触，普通路径用原接受段碰前状态。
- cushion-events-r1/session6386终态0，实际4测7.328s通过（全部主库/圆弧索引、实际直库一次反弹/分段同时间、实际台呢落地不计库、既有接受前缀）。无活跃测试，未启动袋底长测。
- 本轮未直接套用旧库边.94：该数值是Han响应输入而非实际反弹保留率，静态响应衔接须用真实撞库案例验证；不要通过改系数名称宣称生产标定完成。下一步响应/正式入口、预算兜底与统一预测规则，完整后续范围仍未完成。

## DR-220：静态材料配置与实际差异（2026-09-13）
- contactSurfaces新增prototype与tablePhysics(clothRestitution:)候选，索引/几何不动、缓存纯值、pending绑定。原prototype缺省保持；正式simulate未启用。
- static-material-r1/session65493终态65（测试函数名编译错误）；r2/session78043终态65，实际4测其中台呢3断言失败，其他3测通过。独立计算初始Float间隙3.725nm→27.558815μs无摩擦自由落体，预测自旋差与实际相符；对照从真实落地计时并断言该解析时刻，未改误差或求解器。static-cloth-r3/session28072终态0，实际1测3.929s通过。
- r2响应JSON已导出至static-material-r2-attachments/66F9BEEE-3189-4B3B-A2A7-3C4E0EC926D7.json：同输入局部vz=.947101、vy=.167700，旧Han vz=.875972/无竖向分量。此为实测差异，不能宣称生产标定已完成；需明确普通台面附近的兼容边界和真实空间袋角预期。
- 下一步聚焦该接口衔接及正式入口/预测/预算兜底，避免继续精修不可见纳米误差。全范围W07–W16/H01–H04保留，当前无活跃测试。

## 正式配置组合与步长复核（2026-09-13）
- combined-material-r1/session42285终态65，实际6测/2错误：组合材料角袋4m/s及再入场景支撑投影失败；远端平面预算、两项续算、同刻独立事件通过。远端预算通过依赖当时试验的平面adaptiveEvolveCap，后已撤回，不能算当前版本通过。
- planar-budget-revert-r1/session37860终态65，再入测试仍在.711832896s投影失败。撤回步长后仍复现，先前归因于步长不成立；当前基线也有问题。新增远端32事件预算用例保留，待恢复合理平面步长后复验。
- 数值草稿projection-seam-diagnostic.py及projection-seam.png已核对：台呢面内垂足与旁边边缘距离在加上共同球半径后舍入近等，被错误并入投影支撑。不是袋底堆积故障。
- cloth-seam-r1/session99814终态65，4测/2错误：严格面内见证+共面边缘排除越过原失败点，但后续接缝仍失败；折角与非共面接缝2测通过。r2/session16288终态65为补丁定位错误导致编译失败，无测试通过。修正定位后r3正在验证稳定距离差比较；未预支通过，未切换正式入口。

- cloth-seam-r3/session3197终态65，4测/1错误：完整再入（2.321s）及两项折角回归通过；组合材料继续至.140s，三约束投影残差9.683e-10失败。不能把越过旧失败点记为组合配置通过。
- 已恢复无local owner时复用平面adaptiveEvolveCap；局部owner仍用原maxStep，入口穿越继续截断。planar-budget-r2/session37234正在验证远端32事件预算、完整再入、两项精确续算与同刻独立事件。无完整袋底长测。

- planar-budget-r2/session37234终态65，实际5测/1错误：远端32事件预算（6.905s，含首次资产加载）、完整再入（2.281s）、任意截断续算和同刻独立事件通过；捕获续算在.1375s三约束投影失败。原始结果保留，不声称该组合通过。
- 随位置投影更新支撑候选，避免初始同距见证在修正后已经分离仍被强制保留。cloth-seam-r4/session70824复跑8项，包含组合材料和上述捕获续算；结果待核验。gate-r1已终态0，81 routes/146 write-surfaces；doc-size97KB/10条及diff-check通过。

## DR-221 验证收束（2026-09-13）
- cloth-seam-r4/session70824终态0，实际8测22.193s全部通过：组合标准材料角/中袋.5及4m/s（11.109s）、远端32事件预算及旧平面对照（.555s）、捕获续算（3.413s）、任意截断续算（3.682s）、独立同刻事件（1.045s）、完整再入（2.387s）、真实折角与非共面接缝（.002/.001s）。先前失败均保留；没有提升阈值或删除断言。
- 最终保留面内见证区分、稳定距离差比较、每次位置修正后重建投影集合、无owner时原平面adaptiveEvolveCap。用户限定的软袋固定收尾不变，未进行袋底r8。全部本任务测试已终态，无活跃句柄。
- 下一步：生产simulate选项/异常与预算处理、统一预测及规则实际消费者；静态材料仍为显式候选，4种入口不能替代完整响应标定或手机性能验收。W07–W16及H01–H04仍未完成。
- 最终cloth-seam-gate-r2/session19396终态0：81 routes/146 write-surfaces、文案门禁通过；verify-doc-size97KB/10条及git diff --check通过。

## DR-222：搜索早停接口衔接（2026-09-13）
- 新增earlyStopBallNames/stopAfterContactBetween，默认nil。碰撞早停在接受同刻组与记帧后检查新增事件；兴趣球平面上界只用于无空间状态、无待接管袋口球的情况。未启用正式simulate/ShotPredictor。
- mixed-search-stop-r1/session83715终态0：3测7.069s；mixed-search-group-r1/session73475终态0：1测3.544s；扩展兴趣三态后mixed-interest-stop-r2/session87218终态0：1测4.620s。共4个不同测试，验证碰前截断/整程碰后值/精确续算、空中与袋口失撑、同刻独立与完整三球碰撞。无活跃测试。
- mixed-search-stop-gate-r1/session76732终态0：81 routes/146 write-surfaces、文案门禁通过；diff-check通过。下一步正式入口选项与预算/错误处理、预测和规则消费者统一；当前SimulationWorker仍无模拟失败分支，不能吞异常后把部分轨迹当完整结果发布。完整W07–W16/H01–H04范围保留。

## DR-223：正式调用的结果契约（2026-09-13）
- 已确认SimulationWorker无当前实例化调用，实际主要入口是ShotPredictor的simulateFree/runShot及ReflectionSolverCore。改动优先贯通前两条预测结果，闲置Worker不扩建。
- 引擎两类入口新增Termination；生产仍走原平面simulate，明确区分settled/timeLimit/eventLimit/contactResolved/interestResolved，混合预算与数值错误保持throw。ShotPrediction通过runShot/buildPrediction及simulateFree保留状态；nil不是成功。未新增页面处理，未声称截断轨迹已经全面禁止上屏。
- simulation-termination-r1/session38350终态0，实际3测6.655s通过；simulation-termination-early-r1/session78150补验主动早停原因。simulation-termination-gate-r1/session19015终态0，81 routes/146 write-surfaces及文案门禁通过；diff-check通过。
- 下一步仍为正式入口选择、实际预测/规则对失败和预算截断的处理；不得把闲置Worker完善当作已接入页面。W07–W16/H01–H04全范围保留。
- simulation-termination-early-r1/session78150终态0，实际2测6.716s通过，明确断言contactResolved/interestResolved/timeLimit并保留续算检查。本轮共4个不同测试（碰后续算复跑）；所有句柄已终态。doc-size97KB/10条及diff-check通过。

## DR-224：首批真实消费者阻止截断结果（2026-09-13）
- 完整桌面只接受settled；兴趣搜索还可接受interestResolved，未知/时间/事件截断/仅碰撞完成不允许进入完整播放。真实落点求解保留末速检查并叠加完成状态。
- PositionPlayViewModel四个写入点统一到applySolvedShot：当前预览/翻袋/序列，拒绝未完成结果时清掉原解及辅助显示、禁出杆；序列预测缓存也检查完整状态。共同视频/GIF运动帧入口新增明确错误，不把截断可行预测静默跳为after。其他页面、开球和全调用切换仍待完成。
- prediction-consumers-r1/session71231终态65，测试MainActor标注缺失导致编译失败；r2/session88107终态0，2测.142s通过（真实完成/截断预测到模型及导出校验、未知和搜索状态、恢复、实际落区求解）。统一实际写入入口后的prediction-delivery-r1/session12961正在验证非空旧solvedShot清除。原结果保留，未把模型校验当实际页面或视频验收。
- prediction-consumers-gate-r1/session34383终态0，81 routes/146 write-surfaces及文案门禁通过；最终delivery门禁另跑。全目标W07–W16/H01–H04不变。
- prediction-delivery-r1/session12961终态0，实际1测.047s通过：先写入非空有效解，拒绝未完成结果后旧解为空且不可播放，后续有效结果恢复。最终prediction-delivery-gate-r1/session87262终态0；81 routes/146 write-surfaces、文案、doc-size98KB/10条、diff-check通过。全部本任务句柄终态。

## DR-225：真实预测接入显式局部模式（2026-09-13）
- simulateFree与runShot统一经simulatePrediction；ShotInput新增simulationModel，缺省planarReference保留，显式localPockets采用标准球球/所选静态材料/软袋捕获，不吞错误或重跑旧进袋。新Termination.failed由完整性检查拒绝。
- 业务事件预算与内部迭代预算分开；同刻组先完整提交再检查maxResolvedEvents，局部总保护maxLocalSteps缺省100000，手机预算尚未验。首轮初始分离沿用旧50次；空间段保留，未修改回放为旧二维路径。
- predictor-local-entry-r1/session1129终态143：命令模拟器ID写错，经pgrep确认本任务PID8962后主动TERM，无测试通过结论。r2/session96281终态0，实际3测13.312s通过：真实自由预测角/中袋捕获与尾段、指定袋口目标捕获及模型传递、预算分离/失败不回退；无旧pocketEntries。当前仅显式模式链路验证，默认页面未切换。
- predictor-local-entry-gate-r1/session62538终态0。predictor-entry-compat-r1/session94829补验默认预测截断状态与.failed消费者拒绝。下一步默认切换前的其他实际消费者/预算组边界/手机成本及基准分类；全部W07–W16/H01–H04保留。
- predictor-entry-compat-r1/session94829终态0，2测.043s通过（参考模式状态传递、局部失败清旧解/禁播/导出拒绝及恢复）。本轮共5个不同测试；gate81 routes/146 write-surfaces、文案、doc-size98KB/10条及diff-check通过。所有本任务句柄已终态。

## DR-226：固定准备成本实测与消除（2026-09-13）
- preparation-baseline-r1/session43985终态0，1测8.877s；已加载资产的连续短预测仍约553ms。确认每次重建44,248面对应索引与六袋捕获边界（面数以当前角色9701+9963+24584计）。
- localSimulation按静态/球球材料缓存只读准备对象，captureBoundaries缓存不可变六袋边界；状态/轨迹/pending不缓存。先校验材质再使用键，全部构建成功才发布，独立锁保护。
- preparation-cache-r1/session96881终态0，3测10.437s，索引缓存后热均值26.621ms；r2/session33052终态0，3测9.990s，边界缓存后热均值.16175ms，5次范围.147625–.220708ms。真实角/中自由预测捕获（2.162s）及精确续算（7.823s含该轮初始加载）通过；不能把单测总时长当单杆纯耗时。
- 原始日志/xcresult保留，preparation-comparison.json记录全部5次样本与统一去首轮均值。测量是模拟器Debug无袋口接触的.01s短预测，仍需冷加载、复杂接触、真实手机/内存预算验收。
- preparation-cache-gate-r1/session67784及r2/session67142终态0；全目标与默认切换待办不变。所有本任务句柄终态。

## DR-227：常见完整击球停稳（2026-09-13）
- 实际指定袋口预测maxTime3s时，目标已进、母球末速0但返回timeLimit；初始袋口静止球也跑满.1s。local-rest-red-r1/session63291终态65，两个用例失败，原证据保留。
- 复用已有几何支撑证明，提取planarSupport；仅无pending、全部local owner有台面支撑且v/omega严格为0、其他球静止且没有待接管区域球时结束，记stationary而不释放owner。没有引入新阈值、改袋口边界或强行清零。
- local-rest-r1/session76049终态0，4测11.846s：真实完整预测（9.308s含初始加载）、空中/失撑三态（.598s）、完整再入（1.909s）、静止袋口支撑（.031s）。两项原红例现返回settled，确认非timeLimit。
- local-rest-gate-r1/session26162终态0，81 routes/146 write-surfaces及文案门禁通过。全部句柄已终态；默认切换/其他消费者/复杂与真机预算仍待办，完整W07–W16/H01–H04保留。

## DR-228：翻袋/反射消费者（2026-09-13）
- 两页自由击球预测在运杆前检查，回放再次检查；未知、截断、仅搜索完成、failed均不作为完整一杆，恢复before、退出播放态、提示重试，有效结果清提示。解目录/草稿展示/求解演示同步检查完整状态。
- bank-kick-consumers-r1/session7749终态0，3测5.314s：两页状态拒绝/球形恢复/有效恢复（.010s），真实翻袋（3.919s）与反射（1.385s）微调目录不变及循环恢复通过。bank-kick-consumers-gate-r1/session67132终态0，81 routes/146 write-surfaces及文案门禁通过。所有本任务句柄终态。
- 图谱功能仅需要首碰/首库等前缀，不能直接套用全桌停稳；下一步按所需前缀终点检查，再处理瞄点验证/开球/其他调用及默认切换。页面视觉、完整导出、真机仍未验，完整W07–W16/H01–H04保留。


## 当前页面可见流程复核（2026-09-13）

按用户固定终态反馈回到实际页面；标准模拟器完整3D切换/观察/击球/回放/重打1项UI测试通过，7张当前截图已直接查看。默认仍为平面物理，不能据此验收新版进袋。独立附件、生产入口差距与下一步详见 [W07-visible-flow-check.md](W07-visible-flow-check.md)。未新增袋内求解探索。


## DR-229 — 开球统一预测入口与完整结果交付（2026-09-13）
- **根因**：BreakSimulator独立调用旧simulate，并按XZ末速<0.3推断settled；低速但时间预算截断时可误报完成。BreakFlowRunner未在运杆前检查结果。
- **变更**：breakShot增加随请求传递的simulationModel，经simulatePrediction调用；BreakResult保留termination，settled仅等于引擎settled。只有完成才执行原静止重叠清理。runner在起播前共用acceptCompletedSimulation，拒绝未完成结果并恢复racked，保留现场摆位/方向/力度/打点、禁止确认及交付，显示重试提示。
- **验证**：break-unified-entry-r1退出0，4测/0失败/7.511s；真实低速maxTime=0截断不会交付，正常结果可再次接受；无效局部材料failed无平面回退；旧开球确定性和手动确认通过。break-local-full-r1退出0，1测/0失败/8.564s；实际9球seed7默认6m/s显式局部模式正常settled、10球完整，计算8.536s（含本进程准备成本），本杆pocketed为空，不能作为开球进袋证据。gate退出0，81 routes/146 write-surfaces及文案门禁通过。
- **边界**：默认仍planarReference；未证明所有玩法局部开球、进袋开球、真机耗时或提示的实际UI。没有新增袋内微接触求解。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-229/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-230 — 图谱按所需事件片段验收（2026-09-13）
- **根因**：图谱把cuePath末端当停点，不检查模拟是否截断；但要求整桌settled也会丢弃已完整的教学片段。
- **变更**：两图谱增加hasCompleteSlice；分离角接受完整桌面或已记录碰后首库；加塞吃库接受完整桌面、已记录二库或已有0.40m库后片段。原切片几何/教学盘面/打点/颜色不变。切片入口拒绝不完整结果，VM逐档检查，仅保留完整档位并提示部分模拟未完成，拒绝档位不画碰前stub。
- **验证**：atlas-completion-r1/session25506退出0，实际14项测试/0失败/0.414s。新增真实时间截断验证分离角首库前拒绝/首库后虽timeLimit仍接受，加塞首库后短截断拒绝；完成路径改为timeLimit的契约用例证明完整片段不依赖全桌状态。原低力度停点、切片端点、8档吃长库、打点边界与挤偏补偿回归通过。
- **边界**：未改最近点切片算法；当前测试为默认平面预测与模型契约，不代表图谱新版局部物理预算、实际提示UI或所有3D图谱验收。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-230/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-231 — 瞄准点验证失败保留当前题目（2026-09-13）
- **根因**：验证击球只检查recorder/duration，无记录时直接advanceAfterStrike，截断预测也会播放并自动换题。
- **变更**：acceptVerificationPrediction在进入striking/清除辅助线/运杆前检查完整结果；失败取消自动击球任务、保持showingResult与原答案，verificationErrorMessage驱动系统弹窗。重试仅重复strike，不重复submit/计分/保存；下一题由用户明确选择。新题清错误态。
- **验证**：aim-verification-r1/session41669退出0；2测/0失败/1.335s，未知/时间/事件/failed结果保留题目坐标、误差和答案数量，完整预测恢复清错误；原2D/3D练习不泄露理想方向回归通过。
- **边界**：系统弹窗实际页面视觉与按钮流程未验，尚不能声明本页面全部完成；正常后续播放结束时机仍由W08统一审查。默认局部物理切换仍未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-231/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-232 — 三个规划页完整结果检查（2026-09-13）
- **范围**：SiluTrainerViewModel、PlanThreeViewModel、SnookerTacticsViewModel。
- **变更**：canStrike要求hasFinalTableState；展示目录/微调结果前共用acceptCompletePrediction，未完成时清轨迹/藏杆/清瞄准方向并提示。上一杆回放同样在修改场景与播放态前检查；原解目录、草稿与撤销模型保留。
- **验证**：planning-completion-r1/session14075退出0；5项/0失败/25.846s。三页未知/时间/预算/兴趣早停/failed结果拒绝与完整结果接受；真实三个页面微调目录与循环恢复、连续微调保留前次打点均通过。Snooker完整测试23.352s，包含求解/微调/断言，不是单次预测或真机性能指标。
- **边界**：页面错误提示实际视觉、局部模式求解预算与默认切换未验；不把消费者守卫视为W07完成。仍须核对EngineCushionTracer旧直接入口，SimulationWorker目前无实际实例不可冒充用户链路。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-232/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-233 — 反射追迹统一入口与截断终点（2026-09-13）
- **变更**：EngineCushionTracer.launch经simulatePrediction，Launch携带termination；shoot的模式参数贯穿miss搜索与build重建。仅settled追加自然末点，时间/事件截断或failed不把最后记录帧补成停点，既有已完成库间片段与斜库截断规则保持。显式局部材料失败不回退。
- **验证**：reflection-entry-r1/session60323退出0，11测/0失败/14.053s。短时截断只留下起点；显式局部低速球正常停稳、无效材料failed；原单库求解、长库分类、翻袋/反射真实模式及力度响应回归通过。局部测试是低速无库球，不替代局部多库反解验收。
- **边界**：默认planarReference仍待切换验证；当前产品实际直接旧simulate只剩无实例的SimulationWorker（本轮检索），不得据此称全物理完成。W07默认切换、性能与临界捕获回归、提示UI仍未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-233/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-234 — 默认预测切换局部进袋（2026-09-13，全面验收中）
- **变更**：SimulationModel.appDefault为不可变.localPockets(tablePhysics(clothRestitution:0.3))；ShotInput/simulateFree、BreakSimulator、EngineCushionTracer.launch/shoot共用默认策略，显示2D/3D不选择物理。显式planarReference保留作旧基准对照。删除ShotPredictor“主线程可直接跑且极快”的过期注释，页面后台调用需继续审查。
- **切换前证据**：local-search-r1/session82634退出0；实际单库局部射击法（搜索与build）6.597s到达目标，中袋完整predict瞄准搜索7.795s、settled且真实捕获；2测/0失败/14.448s，计时含进程准备差异，非真机预算。
- **切换后证据**：default-local-r1/session1079退出0；默认simulateFree中袋确认捕获/无旧pocketEntries1测7.247s，实际S2_ShotPagesLayoutUITests.testShotSimulation3DPilot 1测90.259s/0失败。完整观察/手势/后台恢复/击球/回放/重打通过；本轮after-3d-pocket与after-replay-3d原图已目视，独立附件位于output/3d-v63/W07/default-local-r1-attachments。页面流程击打自由球，不能当动态进袋验收。gate/session49022退出0，81 routes/146 write-surfaces及文案检查通过。
- **未完成**：W07临界旧基准差异分类、全页面/开球玩法/反解吞吐、同步主线程调用、错误提示UI；W08动态进袋/遮挡/任意定位/实际导出及后续完整范围。静态台呢e=.3为候选，未宣称实物标定。当前源码默认已切换，不能再沿用“生产默认未接入”描述；全面验收仍在进行。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-234/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；ADR-P10-11；W07-working；v63.11。


## 默认15球回归性能缺口（2026-09-13 08:37:58 CST，运行中）

- 当前默认局部模式回归：`default-regression-r1.xcresult/.log`；工具会话92196，xcodebuild PID25515，测试宿主PID25619（专用EC19模拟器）。命令选择15球确定性/方向响应和两图谱共16项；不得按选择数宣称已执行。
- 08:37:58实查首项`test_break_aimDirectionAffectsOutcome`仍无终态，宿主运行2:26 / CPU2:27 / 100%。这不是完成证据；不能据此声称通过，也尚不能判断数值结果。
- 已对已确认归属的宿主采样3秒：`output/3d-v63/W07/default-regression-r1-sample.txt`。栈集中于EventDrivenEngine.swift:566 → LocalPocketSimulation.advanceTogether/advanceCoupledTrial/run/integrate，说明实际计算热点是局部多球推进。
- 下一步首先poll原会话92196；未确认终态前不重启同测试。当前默认切换保持验收中；15球等待成本不满足手机体验，须分析热点与实际局部接管状态，不能用9球或单球替代15球验收、不能把复杂袋内堆积重新纳入范围。


## 默认回归失败与单球分支复验（2026-09-13）
- default-regression-r1/session92196 已确认终态65，TEST FAILED；开球方向响应173.625s、确定性251.178s，两项通过不代表整批通过。低力度低杆分离角切片为空，随后测试强制解包崩溃；原日志和xcresult保留。
- 当前已在两处切片断言加入termination诊断，并在已失败断言后退出，避免空数组强制解包打断后续测试；没有删除或放宽切片断言。
- 已有LocalPocketSimulation单球免重复组误差控制分支尚未验收。singleton-regression-r1/session48568 正在同一专用EC19模拟器验证实际捕获、吐袋、跨域碰撞、分段续算及上述低杆失败。此批未含15球计时，不能据此宣称开球加速。
- 按用户反馈继续限定袋内为吸收收集边界和短可见收尾，优先现有图谱轨迹与手机等待成本，不增加袋底堆积求解。W07及后续完整范围仍未完成。

- singleton-regression-r1实际执行6项：5项PocketGeometryInjectionV63Tests通过（8.521s），低杆切片失败（17.210s），明确termination=timeLimit，整体6项/1失败/25.731s。减少重复组控制没有解决低杆无法完整停稳；下一步检查末态球及局部所有权，不放宽切片规则或延长预算掩盖问题。


## 低杆超时根因与修复复验（2026-09-13）
- low-draw-diagnostic-r1/session56423、r2/session86953均终态65，真实旧低杆用例失败保留。r2末态：母球stationary无局部接管；目标球仍归pocket_1，v.x=-3.384776724577492e-178，omega.z=1.1845238120953696e-176，位置(1.2529878177067126,0.8285750113427639,-0.5940459241297907)，终止timeLimit=15s。不是仍在可见滚动；严格零判据让摩擦残差阻止结束。
- 待验修复：混合引擎仅对有planarSupport的局部球按64*Double.ulpOfOne判断线速度和球面自旋速度的舍入残差，完整全桌条件满足时统一提交零速度/自旋并记录stationary快照。未修改几何、物理停止阈值或模拟预算。
- local-rest-roundoff-r1/session64495进行中：两个相同15球输入、完整SeparationAngleAtlasTests、支撑/失撑与吐袋测试。gate/session5351进行中；不得预支通过或性能结论。

- local-rest-roundoff-gate-r1/session5351终态0，81 routes/146 write-surfaces、双端和文案门禁通过；git diff --check通过。测试session64495仍活跃，08:51:08开始首个15球方向响应测试，宿主30158。后续继续poll原句柄，不重启。

- 回归观察：session64495仍确认活跃，宿主30158运行1:57/CPU2:00，首个15球用例尚无终态。不能把当前停稳修复称为开球性能问题已解决。
- 对开球测试补充a/b.settled断言：原确定性/方向响应测试只比较盘面，无法证明可交付完整开球。新增断言尚未编入当前local-rest-roundoff-r1，须在该进程终态后构建验证；保留原输入和差异断言。

- local-rest-roundoff-r1首个15球方向响应117.600s通过，对照旧174秒（精确173.625s），Debug仍不符合交互预算。相同运行采样local-rest-roundoff-r1-sample.txt/session30398已终态0，仍见组推进与有限三角面碰撞计算。
- 为区分Debug编译开销与算法成本，启动Release ENABLE_TESTABILITY=YES独立ReleaseDerivedData的build-for-testing（optimized-build-r1.log/session33590）；仅构建，不安装或启动，不干扰session64495。待两者终态后在EC19运行相同15球输入，并包含已新增settled断言。模拟器Release计时不能冒充真机性能。

- local-rest-roundoff-r1/session64495已终态65：实际9项/1失败/291.747s。开球两项117.600s及166.445s（旧173.625s、251.178s）；本轮仍是旧断言版本，不证明完整settled。分离角图谱实际5项全通过4.976s，低杆1.361s恢复；吐袋通过.444s。临界支撑/失撑用例失败supportConvergence(time:.03499999953101721,stage:force,contacts:2,residual:3.298069384189862e-7)。
- 下一步隔离单球绕过组误差控制分支与停稳修复：前者跳过了组层的失败细分重试，疑似造成新临界失撑失败，尚未A/B确证。待optimized-build-r1/session33590终态后移除该未验收优化，仅保留舍入停稳修复，聚焦复验临界失撑和低杆；不同时修改正在编译的源码。Release构建是旧候选，不能将其验证结果冒充移除优化后的候选。

- 优化构建PID31105已主动TERM停止（因候选已有正确性失败，不是观察超时），session33590终态2，未运行Release测试。单球快捷分支已移除，保留局部静止舍入判断；rest-only-regression-r1/session70517正在验证临界支撑/失撑和低杆原样例。
- 补充源码核对：组控制catch只对penetration减步重试，supportConvergence仍抛出；因此不能将这次失败直接归因为“组层自动重试所有收敛错误”。快捷分支改变了原组层粗/细步接受路径和接触状态，是否导致临界失败以本次A/B为准。

- rest-only-regression-r1/session70517终态65：2项/1失败/15.902s。低杆4.897s通过；临界支撑/失撑仍supportConvergence(time:.02749999950438449,contacts:2,residual:1.5105466087473657e-7)。因此单球快捷分支不是该失败的必要原因，不能把移除当作修复。当前源码仍移除该分支，保留舍入停稳；后续性能不能引用117.600/166.445作为当前版本值。所有本轮工具句柄已终态。
- 下一步：临界样例须在无舍入停稳改动的同工作区基准下隔离，确认既有失败还是本次回归；不得放宽断言或新增袋底求解。Release性能尚未验证；新的开球settled断言已编译但对应方法未执行。W07仍在进行中。


## 接触残差基准与当前入口复核（2026-09-13）
- edge-strict-zero-baseline-r1/session31240脚本终态0，但内部xcodebuild BASELINE_EXIT=65；不是测试通过。严格零判据仍复现临界失败，脚本已确认ROUNDING_PREDICATE_RESTORED。未改变其他并行工作。
- 力收敛候选：固定相对运动残差1e-10之外，考虑slip/dt放大的速度舍入底限64*ulp*max(1,|v|,R|omega|)/(dt*forceScale)，保留原constraintResidual位移预算。测得失败dt=4.956e-10时舍入底限2.923e-6，相应约束位移仅4.631e-12m。
- contact-roundoff-r1/session56006终态65，实际9项/1失败/29.942s。原force失败越过，但临界用例在t=.075、projection/3contacts、residual=1.9222768992896433e-14失败；不宣称修好。其他8项（图谱5项、吐袋/续算/跨域碰撞3项）通过。gate/session89221终态0；git diff --check通过。候选尚未验收，无新增袋内模型。
- 原临界fixture使用prototype材料与显式混合入口；保留原方法/断言，抽出共享fixture并新增testAppDefaultDistinguishesSupportedAndUnsupportedPocketEdge，通过simulatePrediction(.appDefault)检验同一角/中袋支撑边界两侧，要求settled及原捕获断言。app-default-edge-r1/session15990正在运行；下一步先poll此句柄。

- app-default-edge-r1/session15990终态65；实际1项/12断言失败（2项为nil捕获派生的XCTUnwrap），21.168s。两处有支撑offset+.0002通过；角/中袋offset-.0002均timeLimit，1s未捕获，未出现prototype的supportConvergence。不能把这解释为同一求解异常。下一步检查实际默认材料下末态/支撑：贴边0.2mm可能由滚动阻力形成悬停，原prototype“1s内必落”前提不能无诊断移植；保留所有失败断言。所有工具句柄终态。

- app-default-edge-r2/session54025终态65，1项/12断言失败/21.052s。末态实证：角袋1s水平位移约33微米，v=(-2.245e-5,-2.883e-7,-2.753e-5)m/s；中袋约16微米，v=(-3.305e-14,-4.774e-8,-6.381e-6)m/s。二者不是严格静止，仍局部sliding；不能未经证明称作稳定悬袋。末端均留约1.033e-14s区间，诊断保留。
- 当前surfaceResistance以omega/dt限幅，尚未建立静止斜面滚动阻力平衡；其与微量爬行是否相关需步长对照，不直接延长时间或改掉捕获断言。新增testDefaultPocketEdgeStepSensitivity，用共享fixture实测中袋Float输入、同生产材料、0.25s分别maxStep=.0025/.00125，按已有1e-6m空间预算检查末位差。edge-step-sensitivity-r1/session89422运行中。

- edge-step-sensitivity-r1/session89422终态65，1项/1失败/12.080s：0.25s末位z=-.62423766(.0025)与-.62423575(.00125)，差约1.91e-6m；位移约3.82与1.91微米，随步长减半而约减半。微爬行具有明显步长依赖，不能作稳定真实运动证明。当前测试预算是全段对比，不等于已证明每子步误差超预算；根因优先检查阻力在零速附近缺乏静态平衡。所有工具句柄终态。


## 单平面滚动阻力根因复现（2026-09-13）
- 新增PocketGeometryV63Tests两项：testSubcriticalSlopeDoesNotProduceStepDependentCreep、testSupercriticalSlopeStillAccelerates。只用一个水平三角面和带切向分量的重力（等价于斜面坐标）；不依赖袋口网格。根据现有实心球I=.4mR²和阻力矩上限3.5*mu*N/R，静态所需2.5*g_t/R可在低坡度由摩擦承载；高坡度预期a=(5/7)*g_t-mu*N。
- slope-resistance-baseline-r1/session13286终态65，实际2项/5断言失败/.172s。低坡度g_t=.005g、mu=.01时，步长.0025/.00125的.25s位移分别1.09213e-5/5.46749e-6m，末速度4.37946e-5/2.18973e-5m/s；单平面即明确复现数值爬行。高坡度速度断言通过，位移.00570861对解析.00569330，差1.53e-5超1e-5。没有修改断言或调几何。
- 下一实现方向：当前surfaceResistance仅用起始omega/dt限幅并独立于接触力矩迭代，零速返回零，导致重力先启动微运动、下一步阻力再制动。应让受压力上限约束的滚动/旋转力矩与切向接触力共同求解静态平衡，而非把多个接触各自补满重力力矩（会重复补偿）。该求解修复尚未实现；所有工具句柄终态。当前仍为contact-roundoff候选+停稳修复，单球快捷分支已移除，整体W07未验收。


## DR-235 — 局部静止残差与阻力矩平衡候选（2026-09-13，验收中）
- **根因证据**：低杆目标球v约1e-178但严格零判据导致timeLimit；独立单平面小坡度复现步长相关爬行，排除袋口网格依赖。surfaceResistance仅按起始omega/dt制动，未平衡接触力产生的角加速度。
- **当前变更**：EventDrivenEngine仅在已验证台面支撑的全桌静止条件下归零64ulp范围内线速/球面自旋速并提交所有权状态。LocalPocketSimulation在每次接触力候选下共同求解压力有界的滚动/旋转力矩，投影保持各接触力矩容量，使用求得的角加速度校验接触约束。极短步的force相对残差考虑速度舍入除以dt的下限，原约束位移预算保留。单球快捷分支已撤下，既有117.600/166.445s不能作当前性能值。
- **验证**：coupled-moments-r1/session39754终态0，实际4项/.519s：小坡度两步长位移降至1e-21m量级，大坡度解析运动、原平面滚动减速及无滑动摩擦时不造能通过。低杆恢复此前在rest-only回归验证；本候选真实袋口/多球/性能尚未完成，prototype临界投影失败仍保留，不能宣称进袋验收完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-235；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

- coupled-moments-pocket-r1/session51858运行中：默认临界/步长敏感度、真实组合材料进袋与反弹、标准材料续算。gate/session18346运行中；先poll原句柄。

- coupled-moments-pocket-r1/session51858终态65：4项中2项正常组合材料进袋/反弹与续算通过（2.687s/1.056s）；默认临界和步长用例失败，总13断言失败/18.234s。中袋新增surface-moment双接触慢收敛，t=.00037700881491908297,residual=.00196817；角袋仍timeLimit。原捕获断言未变。gate/session18346终态0，doc-size与diff-check通过。
- 力矩内层增加与外层同类的受约束secant加速：候选先投影至各接触力矩容量，只有真实投影残差降低才接受；4096上限与舍入阈值不变。coupled-moments-r2/session31908正在验证真实中袋步长与两个单平面样例。当前仍未验收，不能使用r1单平面通过替代多接触稳定性。

- coupled-moments-r2/session31908终态0，实际3项/12.223s：真实中袋步长对照11.957s通过（两步长最终z均-.62423384、速度降至1e-20/1e-26量级），小坡度与大坡度.196/.069s通过。受约束secant使双接触不再surface-moment失败；完整袋口矩阵尚未重跑。
- 剩余已定位：默认临界球在袋沿力矩平衡，但引擎全桌停稳仅接受planarSupport，故仍timeLimit。下一步使用已接受局部区间的静止起止速度/自旋及零加速度作为平衡证据，排除自由落体/碰撞后短暂零速；需在有支撑微悬袋与更明显失撑的球形上实证。原prototype -.2mm必落断言保留；新默认材料fixture的预期应据静态力矩容量分析区分微悬袋与真正失撑，不能把所有负offset都当1秒必落。所有工具句柄终态。


## 袋沿平衡结束与投影预算（2026-09-13，验收中）
- 全桌静止条件补充已接受区间的平衡证据：起止线速/球面自旋速在64ulp内，区间末态对应当前owner，线加速度及球面角加速度在重力标度舍入内，位置不变；不能用瞬间零速替代，原平面支撑路径保留。
- 默认材料fixture按前述力矩容量证据区分+.2mm台面、-.2mm微悬袋、-2mm失撑；原prototype两档及必落断言保持原样。新默认用例先前负offset均1s必落的前提不适用于包含滚动阻力的静态平衡，补-2mm实际落袋对照以保持失撑覆盖，不改变生产捕获条件。
- lip-equilibrium-r1/session30759终态65：实际3项，总6断言失败（同一中袋-2mm投影失败派生）/10.449s。角/中微悬袋现在settled，角袋-2mm捕获通过；中袋-2mm在t=.00625出现projection residual6.1176e-14。步长用例.093s通过（此前11.957s且timeLimit），空中势能保护.562s通过。gate/session74805终态0。
- 候选投影收尾：继续优先128次迭代逼近机器精度，若未达到内部阈值则重新测量最终实际接触流形；仅当球面距离误差<=已有tolerance且法向速度*convergenceHorizon<=同一tolerance时接受；保留大穿透拒绝和整步误差检查，不上调tolerance/迭代上限。projection-budget-r1/session5367正在验证原型/当前边界、真实材料进袋反弹与续算、旧临界步长和能量收敛。

- projection-budget-r1/session5367终态65：实际6项/7断言失败（2unexpected）/85.831s。原型临界7.749s、正常材料进袋反弹2.686s、续算.531s、偏移返回能量收敛25.305s通过；默认中袋-2mm与旧临界步长仍force收敛失败。未改失败断言。
- 力迭代增加与投影一致的收尾核验：严格迭代4096次后若仍有负载重分配，只有相邻迭代的线/角运动变化折算位移，以及实际接触约束残差折算位移，均<=原tolerance时接受。未改变普通快速收敛路径、tolerance或迭代上限。contact-budget-r2/session7057运行中，覆盖实际默认边界、旧临界步长与两个斜面；gate/session50960运行中。


## 当前边界通过与优化构建（2026-09-13）
- contact-budget-r2/session7057自然终态65，实际4项/1失败/324.030s。默认角/中袋三档（共6输入）全部通过286.016s；两斜面.195/.069s通过；旧临界步长37.750s失败。曾计划主动停止Debug长测，但kill PID42462返回no such process，实际进程已自然结束，不能记作主动取消或超时。
- 当前宿主42564两秒采样contact-budget-r2-sample.txt/session52493终态0，热点在forceMap/residualSquared/resistedRotation嵌套迭代，非工具等待。
- 旧临界失败定位进一步明确：t=.0009999999999981044、dt=1.895619078373656e-15，constraintResidual=.0011638647374815504，被完整1s convergenceHorizon预算拒绝；不能再放宽空间预算。下一步检查几何接缝截步在可表示末端留下不可分辨小尾段的原因（integrate边坐标根导致dt=t），需要按几何/时钟分辨率处理，不按时间阈值随意跳真事件。
- optimized-build-r2命令终态2：-arch与具体destination冲突，未编译；初次hash写到不存在tasks/3d-v63/W07路径也失败，已改output/3d-v63/W07。optimized-build-r3/session57836正在Release+ENABLE_TESTABILITY=YES+ONLY_ACTIVE_ARCH=YES独立ReleaseDerivedData构建，仅build-for-testing，无安装/启动；源hash在optimized-build-r3-source.txt。不要修改编译中的源码。构建完成后在EC19跑同默认边界、两15球完整结束断言及旧临界步长；Release模拟器仍非真机性能。当前仅该构建句柄活跃。

- optimized-build-r3/session57836已终态2，测试target编译失败（例如DrillListViewModelTests引用DEBUG专用applyFiltersSync）；不是物理测试失败，未运行测试。已启动optimized-test-build-r4/session见工具返回，Release配置但显式保留DEBUG测试入口并-O优化、ONLY_ACTIVE_ARCH=YES；这应称“优化测试构建”，不能称正式Release验收。源码未改，仍用r3-source hash。计划构建成功后test-without-building跑同边界、两15球完整结束断言与旧临界步长。

- 当前唯一活跃句柄为优化测试构建session19879（optimized-test-build-r4.log）；无模拟器测试在运行。后续先poll并核验构建终态，再运行测试。

- 优化测试构建session19879仍确认活跃，swift-frontend已实查持续CPU编译；未新启同构建。源码保持r3 hash。
- 旧临界失败数值草稿输出critical-remainder-resolution.json：末段1.8956e-15s，按日志当前速度/加速度估算位移9.2134e-20m，y/z坐标ULP均1.1102e-16m。估算假定该极短段沿用日志加速度，并非独立证明不存在新接触；后续若合并尾段仍须保持时钟/速度/事件，不得直接丢弃碰撞。当前未做该修改。


## 优化测试构建结果（2026-09-13）
- optimized-test-build-r4/session19879终态0，TEST BUILD SUCCEEDED；优化级别-O、Release配置但保留DEBUG测试入口与testability，不能称正式Release验收。源hash与optimized-build-r3-source.txt逐项匹配。
- optimized-tests-r1/session67857：实际4项/1失败/21.018s。两个15球用例通过：方向响应5.100s、重复确定性3.029s，每项2杆，新增a/b.settled断言确实执行通过（四杆正常结束）；角/中六种边界通过11.137s，同源码Debug对照286.016s；旧临界步长1.752s仍同t=.0009999999999981044、dt约1.896e-15、force错误失败。
- 已区分编译与算法成本：当前优化构建能完成15球与正式默认边界，但仍需手机实测与页面后台等待审查；默认边界11.137s包含六种输入，不能称单杆11秒或正式性能验收。旧临界尾段数值错误与优化无关，继续处理，W07及后续范围未完成。


## 优先级收敛与尾段试验撤回（2026-09-13）
- tail-origin-r1/session73931终态65：旧临界样例的极短尾段来自无碰撞截步，尚不能据此断言具体是摩擦还是接缝截步。
- coalesced-tail-r1/session10641终态65：尾段合并仅将旧临界失败推迟至t约.039s，未修复。该实现还在CCD查询后延长步长，不能证明新增区间无碰撞；本轮已完整撤下这段试验，恢复原step选择，不改失败断言。
- 按用户优先级，停止围绕旧原型极端样例扩大求解器；该失败继续保留，W07不标完成。确认进袋后保持现有重力收尾/固定隐藏，不增加袋内接触与堆球。
- 转向W08可独立验证部分：角袋/中袋空间回放、淡出与不同速度时长、实际SceneKit采样画面。playback-priority-r1/session23037正在运行；这不替代真实页面动态/暂停/导出验收。

- playback-priority-r1/session23037终态0，TEST SUCCEEDED，实际2项/0失败/12.162s。空间状态/透明度/.5、1、2倍速动作时长断言通过；角袋和中袋各7帧的SceneKit截图已导出并实际查看：采样显示逐步袋沿遮挡，尾段末及后续采样无残留球面。附件见output/3d-v63/W07/playback-priority-r1-attachments。采样不是连续动态验证，也没有覆盖真实页面暂停恢复、不同导出帧率或真机响应；W08仍未验收。git diff --check通过。


## W08 导出重复收尾修复（DR-236）
- export-tail-r2/session57196终态0，实际1项/0失败/9.245s，角/中袋各三种速度及早捕获/混合旧轨迹时长断言通过；gate/session1754终态0，doc-size与diff-check通过。首轮export-tail-r1/session49664编译失败，未执行测试。当前证明生产导出结束时间计算，实际编码视频/暂停恢复尚未验收。


## W08/W10 现有序列暂停语义实页复核（2026-09-13）
- 源码确认DrillSceneController与PositionPlayViewModel均为杆边界暂停，当前杆完整结束后停住，不能用SCNNode瞬时暂停测试替代产品语义。
- 发现两页仍在cueAction完成后固定等旧pocketSettleDuration+.1；属于待统一的重复等待，尚未修改。PositionPlayViewModel延时任务还需验证硬停后的旧回调隔离，当前仅源码风险，未声称复现。
- sequence-boundary-r1/session8754：详情页testPlayButtonStateAndPauseCompletesCurrentShot已通过51.501s；试打页连续暂停/上一杆/最终复位仍运行中。当前基线测试未显式切3D，不能作3D全页验收。

- sequence-boundary-r1/session8754终态0，TEST SUCCEEDED，实际2项/0失败/281.462s（含既有固定等待）。详情51.501s、试打229.961s；覆盖杆边界暂停、保持、继续、第二杆暂停、上一杆、整段结束回第1杆。导出12附件，实际查看详情暂停、试打第2杆暂停及最终复位3图：暂停盘面1号球已隐藏，最终复位恢复初始1号球及预告线，符合重置语义。截图是2D基线，未证明3D/所有进袋球全程状态或导出视频。当前无活跃工具句柄。

- DR-237已接两个序列页面：最长球体action决定收尾，空间尾段去重复sleep、旧捕获保留预算；sequence-boundary-r2/session15475正在跑同两实页回归。

- DR-237验证补充：sequence-boundary-r2/session15475终态0，TEST SUCCEEDED，实际2项/0失败/279.608s；详情49.674s、试打229.933s（含固定测试等待，不能作性能提升值）。暂停/继续/上一杆/整段复位通过，12截图已导出，最终复位图已查看。gate/session14588、doc-size、diff-check通过。实际3D切换、硬停快速重启竞态、编码视频仍待验；当前无活跃句柄。


## W08 实际3D编码视频（2026-09-13）
- 新增testSpatialSequenceEncodesAtTwoFrameRates，使用现有drill_c042/manual01第一杆；先确认hasFinalTableState及collectionTails非空，再调用真实SequenceVideoExporter.exportVideo，3D预设只将场景分辨率降至402×716（含HUD成片402×761），分别30/60fps。
- encoded-sequence-r1/session44104终态0，实际1项/0失败/17.505s；ffprobe另验30fps/261帧/8.700s、60fps/521帧/8.683333s，相差1/60秒。文件位于output/3d-v63/W08/encoded-sequence-r1。验证了实际编码链和帧率/总时长，不替代逐世界坐标/旋转帧率不变量测试。
- 已实际查看视频18帧概览、5s原帧及5.0–5.6s中袋12帧裁切：目标球接近袋口后逐渐被袋沿遮挡，后续概览目标球保持消失。发现3D竖版导出取景上下留黑多、HUD离台面远，球桌利用率不足；W10/导出取景待修，不能将编码成功标为视觉完成。

- DR-238验证：portrait-fit-r1/session92541终态0，实际5项/0失败/.004s；独立角点/最小距离矩阵已含60°，其余既有测试通过。doc-size和diff-check通过。尚未用新预设重编码视频，原encoded-sequence-r1仍为30°基线，禁止混用。

- DR-238实际视频验证：encoded-sequence-r2/session16922终态0，实际1项/0失败/16.530s；60°新预设30fps=8.700s、60fps=8.683333s，均有真实空间捕获。视频与8帧中袋抽帧在output/3d-v63/W08/encoded-sequence/232C8959-D0EE-4C73-8AA5-94960F5C346C，已实看目标球接近袋口、消失后不再出现。ffprobe核验60fps/521帧/402×761。与30°基线时长一致；旧基线保留。此为402宽验证，1080原生/真机观看及逐世界状态跨帧率仍未验。

## W13默认防守求解超过90秒（2026-09-13）

真实默认入口snooker-shot-r1等待90秒失败，simctl原图仍求解中；原始采样在W13/snooker-shot-r1-sample.txt。后台solveSnooker第1362行并行engineCell第1300行落入局部袋口推进，主线程采样在RunLoop等待。思路/打三已有约64秒同类实测；优先审查候选批量模拟的重复工作和空间owner生命周期，不增加测试超时、降低正确性或改成简单盘面。详情W13-working。

## 构建模式与重复候选预审

同一默认防守UI在独立DerivedData-Optimized构建，Debug保留测试入口，显式SWIFT_OPTIMIZATION_LEVEL=-O、enableCodeCoverage NO；这是优化编译对照，不是Release/真机验收。Makefile固定YES，追加NO被xcodebuild拒绝（snooker-optimized-r1未启动测试），已使用直接xcodebuild且每参数仅一次，snooker-optimized-r2运行中。生产源码、搜索范围、物理参数均未变。

审查线索：solveSnooker细化集合用cellsOpt[ni]==nil判断未评估，但粗评失败亦为nil；邻近可行粗格可能把已失败粗格重新加入refineSet。候选可去重，尚未修改或测量收益；不得把该局部重复当成整个超时的已证实根因。

优化编译基线snooker-optimized-r2/session56595终态0：实际UI77.178s通过，25.19s点击求解→65.65s结果截图，约40.46s。QiuJi编译行确认-O、无-Onone/无profile-generate；只改变构建条件，未解决40秒等待，不是物理优化或真机通过。防守实际沿杆/击球/上一杆原图A065A21A/45CF5E17/C85C1CE7直接查看，目标/球形/0.6低杆左塞恢复一致，求出5个解。

候选去重：细化集合subtract(coarseIdx)，已失败粗格不再重算，全部未访问邻域和已算结果保留；不改任何候选参数、物理或评分。snooker-dedup-r1同盘面同-O构建运行中，收益未测定。

去重复测snooker-dedup-r1/session6745终态0，实际UI78.639s通过；24.68s点击→67.15s结果截图42.47s，相比优化基线40.46s未显示收益，不能宣称性能修复。恢复原图74D21DD5已核，仍5解、同0.6低杆左塞及球形。去重只消除重复调度，不改变已评估结果；主要性能问题未解决。gate/session52089终态0。

计时口径修正：此前思路/打三约64秒、防守优化40/42秒均为UI事件到结果截图时间，含XCTest AX查询等待，是观测上界，不是纯求解器耗时；截图时刻与实际求解结束可能不同。普通防守90秒超时有同时仍求解的原图支持。下一步优先内部单调时钟与阶段统计、独立于UI查询的固定盘面benchmark，禁止继续以截图间隔归因或凭猜测扫描参数。

## 默认防守内部计时实证

defense-internal-timing-r1/session33125终态0，实际1测39.320s通过。测试由SnookerTacticsViewModel.setupScene/currentSnapshot取默认盘面（目标_1，对方_9/_10），标准搜索不缩网格，直接用systemUptime计时，排除UI/AX查询。-O无覆盖率配置下总求解38.041s：快速预估18.89ms，粗评6755.85ms，细评30680.70ms（约80.7%）；候选阶段37455.46ms。返回5个完整解，母球未落袋、真停稳、首触_1断言通过；所有杆法输出在原始log。

现有并发安全measureSample统计1912次simulateFree.engine，累加652850.2ms，均值341.45ms，最大4980.31ms；累加跨线程不能当墙钟耗时。Physics.cushion.detect/ballBall.detect旧begin/end标签在并发下出现负min，已知共享标签竞态，不能用它们归因；新增三个阶段只在单次串行外层配对，口径有效。

结论：等待并非仅UI测试开销，主要工作落在细化候选全引擎回退。下一步应量化歧义分类/必要回退与各候选局部推进成本，沿同一默认盘面减少真实重复工作；不能降低搜索范围或仅放宽90s超时。gate/session86100终态0，未宣称性能解决。

## 快评回退分类与Release复核

FreeShotOutcome新增fallbackReason诊断，按原短路顺序分类，不改变needsFullSim条件；默认盘面defense-fallback-r1/session22273终态0，测试38.427s/内部37.041s，5解硬约束通过。快评回退1975格为碰后撞第三球cascade，131格为kiss风险，没有pre/post截断分类。不能以调整kiss阈值替代级联物理。

PerformanceProfiler仅DEBUG执行锁与统计，上轮碰撞热点有数百万次调用；-O Debug仍包含这些锁。因此开始真正Release+ENABLE_TESTABILITY=YES、无覆盖率的同一默认盘面benchmark（defense-release-r1），用于排除诊断器开销。Release中reportText为空是契约，仍用测试本地systemUptime计时；不改生产构建设置，不把优化Debug等同Release。

Release对照未执行：defense-release-r1/session14424终态65，测试目标编译失败，TrajectoryRendererTests.swift引用Release不包含的SequenceVideoExporter.Options.settledFrameObserver/motionFrameObserver。不能把此失败当成性能或求解失败，不能声称取得Release计时；不删除/跳过原断言求绿。后续需解决独立基准构建或正确隔离Debug观察回调，保留原编译日志。

当前可证事实仍是-O Debug的37–38秒及回退分类1975 cascade/131 kiss；Release无插桩墙钟未知。PerformanceProfiler锁开销是待验证假设，不能先认定根因。fallback-gate/session82570终态0，doc-size/diff通过；本轮无存活句柄。

Release基准隔离：defense-release-isolated-r1只通过命令行EXCLUDED_SOURCE_FILE_NAMES=TrajectoryRendererTests.swift临时排除不能在Release编译的Debug回调测试源，only-testing仍仅选默认防守基准；未修改源文件或断言，不能宣称Release完整测试或W08导出通过。ENABLE_TESTABILITY=YES保留内部访问，ONLY_ACTIVE_ARCH=YES只编目标模拟器架构。原完整Release测试目标编译缺口仍保留；本次为独立性能证据。

## Release单项基准实证

defense-release-isolated-r1/session36529终态65：进一步暴露DrillListViewModelTests与RenderQualityV62Tests对Debug专用接口依赖，未执行基准。随后命令行仅保留QiuJiTests/SnookerSolverTests.swift参与该测试目标编译，排除清单保存defense-release-benchmark-exclusions.txt；脚本断言清单与App Swift文件名无交集。没有修改/删除测试源码或断言，完整Release测试目标兼容仍未解决。

defense-release-benchmark-r1/session42476终态0，实际1项38.946s通过；本地systemUptime计总求解37.594s，5解的target/pocket/velocity/spin/freeAim/full逐项输出与优化Debug一致；终态/母球不进袋/首触目标检查通过。reportText空，符合Release无插桩契约。因此Debug计时器并非约38秒的主要来源；这仍是模拟器单项基准，不是设备性能或全Release验收。

下一步检查搜索候选在已经确认违反硬条件（例如母球不可逆进袋）后是否仍被完整推演，若可安全早拒则仅影响扫描候选；代表解继续完整模拟。不得将未完轨迹当可用终态，不能减少网格或改物理参数。全部本轮句柄终态，无存活测试。

## 防守必败候选提前结束试验（2026-09-13）

按用户要求限定最小优化：仅防守扫描engineCell传入rejectPocketedBallName=cue；引擎在isPocketed正式提交后返回独立rejectedPocketedBall终止原因，hasFinalTableState/hasResolvedSearchState均不接受它。普通预测与settle代表解不启用。没有新增袋内接触或改变捕获边界。

defense-reject-r1编译失败：检查误插入单球局部推进循环，变量不在作用域；已移动到混合调度循环并补齐平面零时刻/正常事件路径。失败输出保留。defense-reject-r2正在运行Release隔离两项测试（默认标准盘面基准、捕获与正常停球对照）；排除清单沿用r1-exclusions，不能代表完整Release测试目标验收。尚无性能改善结论；若没有实质收益，不保留额外生产复杂度。

试验结论与撤回：r2默认搜索33.823s、r3为34.542s，均5个相同有效解且硬约束通过；相对原Release37.594s约8–10%单机观测改善，未解决长等待。r2边界夹具未到袋口；r3改为中袋X=0/Z=-.56m近沿起点，局部模型在开启/关闭优化时均报相同surface-moment收敛失败（t=2.7558815e-5s），普通停球亦失败。两次测试整体均失败，不得报通过；这不是新优化造成的单侧回归，也未证明该起点物理输入适用。按用户收敛要求，撤回本次全部生产分支/API和实验测试，不追加袋口求解探索。实验测试原文存output/3d-v63/W07/rejected-search-experiment-test.swift.txt，失败日志/xcresult保留。gate通过针对试验版本；恢复后diff检查另记。W07性能与临界基线仍未解决，接下来优先W13已证实的3D控件/编辑提示缺口。

## 求解中段栈采样（2026-09-13）
- 同源码固定默认盘面：defense-sample-r1/session50430 1项38.556s通过，内部37.186s/5解；sample进程已退出未成功，不能作栈证据。r2/session80185实际36.851s通过，内部34.414s/5解；3秒样本包含初次场景/几何加载，不能用于归因持续求解。原失败/早期样本保留。
- r3/session39368在测试开始10秒后自动对确认存活的专用SE App采样5秒，sample exit0；测试1项37.932s通过，内部36.656s/5解。原始defense-sample-r3-stacks.txt约14万行，线程等待计数不当作CPU占比。活跃栈可见LocalPocketSimulation.advanceTogether→advanceCoupledTrial→run→integrate，伴随大量ARC/数组分配与接触查询。
- 源码证据：TrajectoryRecorder.swift advanceTogether:479/482/488在外层做whole/half/tail；run:1057起又做whole/first/second自适应检查。只有一个局部球时仍走两层检查，属于明确可验证的重复计算候选。下一步比较单局部球使用现有run误差控制与原双层路径；必须保留误差标准、事件/轨迹边界以及多球共享控制。尚未实施，不宣称能降低多少耗时或已解决性能。不要转回几何阈值/袋底探索。

## DR-274 单体自适应候选
single-control-r1/session90829原代码六袋30状态shared/独立路径比较1项2.247s通过。比较XYZ、dt加权速度、R*dt加权自旋（现有tolerance），接触数量/顺序/表面ID/时间及无球间事件。
新增useSingleBodyShortcut默认true，单球走原advanceCoupledTrial，内层run自适应、几何投影、穿透重试保留；false保留原共享路径，测试持续比较两条不同路径。single-control-r2/session43135终态0，六袋0.125s/真实双球2.089s/默认防守19.294s三项通过，内部求解19.192s、5解；相对本轮37.186s约减少48%，五条PlannedShot日志逐字一致。仍有已存在候选penetration失败，不能据此称物理全部正确。gate/session67829终态0。
single-control-regression-r1/session68645正在运行完整8杆实时/导出、任意分段续算与连续入袋回归，尚未验收候选整体。

DR-274回归：single-control-regression-r1/session68645终态0，实际3项57.540s通过：完整8杆实时/导出事件与首尾球位57.403s、连续入袋0.133s、任意分段续算0.004s。未移除既有断言。候选保留为本地性能改进；五组输出参数一致，完整W07临界物理、实际页面与真机性能仍未完成。

DR-274实页：single-control-page-r1/session54027终态0，S2_ShotPagesLayoutUITests.testSnooker3DPlanningRoundTrip实际61.661s通过，3D观察→默认求解→沿杆→打点盘→击球→上一杆→2D恢复。D18DEECD结果与A3AF933B恢复原图已查看，5解/0.6低杆左塞和球形恢复；这是整个UI流程时间，不是纯求解耗时，导航长说明仍会省略，不能当全部文案验收。

defense-device-r1/session44078终态0：锁屏等待后同一进程自行恢复，实际iPhone16Pro/iOS26.6.2运行1项70.448s通过，内部systemUptime求解68.763s，5组PlannedShot与模拟器逐条相同，首触/母球不进袋/完整停稳断言通过。成功包含设备构建、测试宿主安装和真实执行；不是触控/帧率/温度验收。配置Debug -O、无代码覆盖率，仍含DEBUG诊断；未取得本机优化前基线，不能把模拟器48%套用至手机。68.76秒不可作为手机性能达标，W07/W16保持未完成。

兼容对象审查已落W07-compatibility-audit.md：旧孔圈及多项原始不变量实际调用planar simulate，不能当默认局部引擎证明；原断言保留。下一组复验明确为默认六袋沿输入、搜索/全模拟一致性及旧平面孔圈参考。Release真机session79732仍存活等待解锁，未并行启动新构建。

compatibility-r1在Release真机进程确认终态后启动：默认角/中六袋沿输入、ScoringOnlyConsistencyTests两项、旧平面孔圈参考。使用当前DR-274源码，未修改原断言。

compatibility-r1/session97500终态65：实际4项，旧平面孔圈0.027s/默认六袋沿5.135s/自由早停20输入1.534s通过，搜索54输入2处cueFinalSpeed断言失败。scoring-residual-r1/session10952诊断同刻rolling→spinning双帧，max(time)读到前帧，非提前停止残速。DR-275修两个预测聚合入口取同刻最后提交帧；r2/session25051编译/门禁通过，测试器Busy启动失败，非物理失败；r3/session28553同产物独立iPad运行中。原断言不变。

DR-275同产物iPad r3/session28553终态0，默认六袋沿4.257s、搜索54输入5.413s、自由提前停止20输入1.530s三项通过，原末速容差未变。随后scoring-completion-r1/session72414新增有效终态断言：实际2项/2失败，54组中的±0.3侧塞、spinY0、5.4m/s完整预测timeLimit，其余字段比较及20组自由早停通过。新断言保留；它揭示现有15s上限下两组完整模拟未结束，不是DR-275末帧读取仍失败。下一步记录这两组15s末状态，判明平移/自旋/局部所有权，不能直接调大上限求绿。


### 15秒末态诊断（scoring-time-limit-r1）
- 已核对日志终态TEST FAILED：ScoringOnlyConsistencyTests单项6.452s、两断言失败。±0.3侧塞、spinY=0、5.4m/s两组在15s时六球平移速度均为零，五颗非母球stationary；母球spinning，角速度Y分别16.477497/-16.476585rad/s。此前“可能仍在平移/袋内运动”的不确定性已排除。原始完整日志保留在output/3d-v63/W07/scoring-time-limit-r1.log。
- EventDrivenEngine的settled要求stationary，搜索兴趣球判定允许spinning；ShotPrediction.hasFinalTableState只认settled。PositionPlayViewModel.apply与SequenceVideoExporter.validateCompletedSimulation据此拒绝该完整预测。这是有实际消费影响的终止语义差异，尚未证明具体页面复现，也不是袋底模拟问题。
- 下一步聚焦原地自旋解析尾段及完整记录的结束契约；不调摩擦、不直接放行全部timeLimit、不移除失败断言。真机Release旧session79732已终态73，不再作为等待中的任务。


### DR-276 纯自旋尾段修复
完整呈现按解析公式补齐纯台面自旋；仅timeLimit且没有残留空间接触或其他事件可进入，不修改移动球的仿真上限。spin-tail-r4/session3847终态0，ScoringOnlyConsistencyTests 4项0失败/8.062s：54组6.525s、默认混合自旋与长时平面对照.001s、平移/eventLimit拒绝.000s、20组自由对拍1.535s。保留前3轮编译/测试失败日志（详DR-276）；gate-r2终态0。两组5.4m/s完整性失败已闭合，整个W07及页面/导出/真机性能尚未验收。


### 常规进袋性能调查接入（只读核对）
已读取独立任务output/pocket-profile-20260913/REPORT.md：固定75候选中，中袋24个未接触早停候选耗131.630ms、角袋20个耗219.803ms，分别占整个求解70.8%/78.0%；该报告是固定副本模拟器证据，不能替代当前源码或真机性能。当前solveAimOffset及positionAimScore先判断objPostContactDir是否存在；未接触返回invalidCandidate+cueGhostMinDist，碰前吃库且后来接触才返回固定invalidCandidate。因此“首次吃库即同分拒绝”并非对所有样本等价，禁止直接截断并宣称评分不变。可进一步研究已有有效候选后的保守下界淘汰，但必须证明各层bestOf选解/无有效候选时的距离梯度不变；当前未实施该优化。

DR-277扩展回归：aim-pruning-r2/session12866终态0，完整ScoringOnlyConsistencyTests实际6项19.586s/0失败。12组优化开关对拍12.408s、两模型先碰库/先球球边界.004s、54组5.629s、自旋长时对拍.001s、未完运动保护.000s、20组自由早停1.544s。第二轮累计baseline5.9879s/pruned5.1113s，约14.6%减少，与首轮方向一致。未降低预测精度/缩网格/改评分；新候选淘汰仍不是斯诺克防守68.763s问题的完整解决，真机和实际页面交互性能待验。diff-check/doc-size通过。


W07入口新回归失败：entry-audit-r1/session87365终态65，5项中默认捕获、自由局部捕获、指定模型近袋三项失败，10断言/1.044s；未完成预测播放/导出拒绝与预算错误分离两项通过。失败根因仍待比较DR-274单体快捷/原共享误差控制，入口与精确错误详W07-entry-audit.md。既有通过只保留原覆盖范围，W07不关闭；无活跃测试句柄。

DR-278扩展验证：moment-bound-r2/session94468终态0，实际8项/0失败，总4.339s。默认六袋沿4.118s、默认捕获.028s、自由近袋捕获.044s、滑动态新旧单体对拍.118s；坡面静止/超临界加速、滚阻不反转、不增自旋能四项共.031s。gate-r1/session9023终态0。原指定模型近袋的CollisionResolver convergence失败仍未解决，不得以此8项绿覆盖。

DR-279完成本轮入口修复：force-scale-r2/session1884实际5项/0失败1.087s，原指定模型近袋.101s通过，双球滑移/顺序交换与未完预测拒绝保留。contact-regression-r1/session42730终态0，真实c039完整8杆实时/导出事件、起止球形与192静止帧对比1项57.338s通过；旧保存第二杆离场与当前返回台面差异断言仍通过。未新审MP4视觉，不据此宣称全部W08/W16完成。

## FL-070 常规默认球形归因进展（2026-09-13）

本轮只增加测试诊断，没有修改生产物理、力度、断言或固定进袋收尾。
- default-trace-r1/session90166 exit65：实际默认球形1项失败，保留原“默认应进球”断言。结束为settled，非预算/求解失败。目标球到达袋口后反弹回桌；不是已确认进袋后的回收错误。
- default-speed-r1/session21931及r2/session33268均exit0，各实际1项；r2耗时2.794秒。五档速度×两模型全部settled。该测试只验证完成状态并输出诊断，不能解释为进球兼容通过。
- 同一默认球形，杆头速度0.8/1.2/1.6m/s两模型均进球；2.4/3.3m/s旧平面进球、局部模型返回。每档两模型选中aimDirection一致。2.4/3.3对应产品中轻/中档，不属于仅极端大力案例。
- 默认3.3m/s：t≈0.384708失去平面支撑，t≈0.399073首先撞Leather面36820，法向(-0.956940,0,-0.290286)，该三角Y区间0.820330…0.834609m；球尚仅下降约1mm。随后多次皮革内壁接触、t≈0.417530碰袋角、0.435263台呢斜边向上反弹。原始坐标、速度、三角、法向见default-trace-r1.log与default-speed-r2.log。
- 下一步核验硬质皮革内壁的形状及材料响应是否符合袋口消费契约；尚不能判定该吐袋合理，也不能直接调低恢复系数或将失败改为期望吐袋。其余9项失败仍未分别归因。W07保持返工，H01仅独立冲量测试通过的边界不变。

## FL-070 皮革响应与瞄准几何对照（2026-09-13）

- 检查PocketContactMesh的TaiNi/Leather选取和既有实测剖面图：暂无装饰网丝误作墙、三角剖分封孔证据；本轮未移动/删除皮革。BTPhysicsConstants的0.45原来用于旧捕获圈之后的喉壁漏检兜底，现在用于真实Leather接触；已纠正注释来源，数值不变。
- leather-sensitivity-r1/session63210 exit0，实际1项2.777s。从默认预测真实首次局部接管Double状态启动单球0.2s对照，仅皮革e=0/.15/.3/.45改变；四组均算完，均回向台内且未明显下沉（minY .8265… .8270，台面静止球心Y .828575）。e=0仍返回，因此不能只调低e修复。此局部测试没有宣布规则进球或全杆完成。
- aim-geometry-r1/session89788 exit0，实际1项4.364s：默认球形×2.4/3.3m/s×pipe/nominal/marker六组完整settled。pipe(1.2698178,-.63729274)与nominal(1.312,-.677)均未进；marker(1.3,-.665)两档均进，但先发生1/4次目标球ballCushion，不能称无碰撞直进。只改变现有pocketAimOverride，生产瞄准和物理参数保持。
- 下一步优先修订实际袋口几何与物理瞄准的绑定契约；marker是视觉坐标，不允许直接把诊断成功点硬编码进生产。需要实测几何来源、其他角度/六袋和理论评分边界验证。其余旧失败继续分类，W07保持返工。
- 外部原文已阅读：https://drdavepoolinfo.com/faq/pocket/ball-ejected/ 说明可能吐袋；https://drdavepoolinfo.com/faq/pocket/rattle/ 提供袋角rattle演示链接。未观看其视频、未获皮革恢复系数或当前模型的实物标定，不能以这两页认可本App默认吐袋。Pooltool索引也未提供可直接采用的Leather参数。

## DR-281 — 收集平面求根禁止台面误捕获（2026-09-13）
- 真实反例：中袋3.3m/s在t=.152577、Y=.828575仍为台面球心高度时被捕获，收尾将XZ推进至z=1.364903，导致原显示路径偏离袋心.688938m。path-endpoint-red-r1/session7373 exit65，1项失败。不是单纯预测线采样越过隐藏终态，不采用裁线掩盖。
- 根因：PocketCaptureBoundary.firstCandidate复用全局二次求根的绝对判别式阈值1e-12，微小支撑残差下a=-2e-12、b=0、c=.1被误作重根t=0；缺少捕获高度复核。capture-root-red-r1/session86066 exit65，1项失败，球高于平面10cm仍被捕获。
- 修复：仅收集边界用单位区间时间/归一化系数、稳定q形式求根，精确零判退化，不改全局解析引擎。候选复核Y不高于收集平面（仅64ULP坐标舍入界）。几何、收集深度、材料与固定尾段不改。
- 验证：capture-root-green-r1/session1111 exit65，完整PhysicsEngineTests 40项/10项失败、22断言失败15.178s。新增反例与12组线性/加速跨平面尺度样例通过；原10项常规失败保留，中袋3.3/4.4过去的误捕获不再计进。不能称整类通过。
- capture-root-regression-r1/session90103 exit0，实际4项1.114s通过：反例/12尺度、默认近袋捕获、真实吐袋不捕获、分段续播。另一个筛选项类名误写Injection，未执行；使用源码真实PocketGeometryV63Tests补跑boundary-r2。gate/session36098 exit0。
- 回写：geometry-spatial-reasoning技能DR-281、UI-IMPLEMENTATION-SPEC Changelog。W07仍FL-070返工；不能用旧误捕获支持已完成声称，之前受该路径影响的兼容/回放证据需重验。

DR-281补验：capture-root-boundary-r2/session97595 exit0，实际2项0.004s通过：正常向下穿越/外侧拒绝及有在场邻球接触时延后捕获。联合前轮实际4项为6项定向验证。完整40项仍10失败；新求根下marker两档仍进（但吃袋角），并未因此采纳视觉点为物理真源。所有句柄终态；gate/doc-size/diff通过。

## 常规失败与实际入口分流（2026-09-13）
- `test_predictor_defaultLayoutPots`使用历史两球(-.35,.22)/(.55,-.18)、3.3m/s，注释声称与当前placeBallsAtDefaults一致已过时。当前AngleDynamic是几何页且球位不同；实际PositionPlayViewModel.applyDefaultLayout为归一化母球(.30,.30)、1号(.62,.20)、2号(.78,.34)，ShotTuning.defaultVelocity=1.5。原断言保留，只纠正注释；不得据历史fixture失败声称现页面开箱不能进。
- `test_currentPositionPlayDefaultsProduceResolvedPot`通过真实VM.setupScene→后台求解→solvedShot验证，不复制摆球/选袋算法。current-defaults-r1/session33311 exit0，实际1项1.250s；当前球形保持、自动topRight/目标_1、1.5/无塞、settled且进球，所有实际捕获Y≤对应收集平面。并非UI触控/帧率验收。
- `test_predictor_withSideSpin_stillPots`追加最终状态断言与诊断，side-spin-final-r1/session75802 exit65，实际1项1.906s、仅原进球断言失败；最终settled，非求解中断。此前整类日志的penetration不能直接归到该最终预测。原同一输入普通加塞未进仍是模型差异待审，不能宣称修复。
- 当前优先级：真实入口错误与规则/展示不一致优先；历史高力度“必须进”样例逐项按轨迹和旧捕获前提分类，不盲目改页面默认力度或物理参数。W07仍返工，常规10项失败尚未全部裁定。

证据范围更正（2026-09-13）：ShotSimulationView.onAppear在setupScene后loadBoard(defaultBoard)，实际仍为(-.35,.22)/(.55,-.18)两球，页面力度为1.5m/s。此前“历史defaultLayout不是当前页面默认”的说法过宽：布局仍被该页使用，测试的3.3m/s与当前默认力度不同。currentPositionPlayDefaults测试仅证明裸VM三球初始化，不证明该页面覆盖后的默认进球；原失败保留，未关闭W07。

## 实际页面默认球形补验（2026-09-13）
- page-default-r1/session65243 exit0，实际UI 1项24.621s。通过真实入口打开分离角与走位，未调整球位/力度/打点/瞄准，切3D击球后回2D。
- 已查看before-2d 1ED8321B、after-3d B7973FC3、after-2d 1F3EF2FF原图：默认母球/黑8、1.5；终态两模式仅母球在桌，8号球回到球库，状态为点选一颗目标球，击球禁用、重打/回放可用。这是实际页面的可见结果证明，区别于裸VM默认测试；不证明其他力度或袋沿连续运动质量。
- r2/session37334正在补生产“无目标球/禁用击球”状态断言、同杆回放与重打恢复。r1只说明流程与已审图，不把其就绪断言称为自动进球判定。原10项物理失败保留。

实际默认页r2/session37334 exit0：1项32.941s、0失败。默认击球后及3D回放后均命中生产“点选一颗目标球”状态且击球禁用；重打后恢复可击球。96DBC61E回放/47FF2037重打原图已审：回放后仅母球，重打恢复黑8及原默认球形。此处已补实际页面入口证据；没有改默认力度、物理系数或捕获边界。此用例的可见结果与状态通过，不替代原10项物理失败及连续袋口动画验收。两次测试均终态，无活跃句柄。

## 首触错误候选早停实验：未采用（2026-09-13）
- 原因：Snooker搜索首触非目标已必败，尝试只在scoring-only模拟中提前返回candidateRejected；展示忽略开关。原完整模拟评分仍拒绝这些候选。
- r1/session81883 exit0：实际2项38.017s通过；两模型错误首触提前拒绝、正确首触/展示保持完整；标准默认搜索5组解的编码参数、约束、事件顺序/时刻和终位一致。先原版18.605s、后候选17.776s。
- r2/session90842 exit0：反向顺序实际1项38.333s通过，同样5组结果一致；先候选18.641s、后原版18.007s。顺序效应超过可确认收益，不能宣称约4%加速，更不能外推69秒真机。
- 决策：撤回本实验的引擎/预测器/防守搜索新增参数与辅助方法，不采用未证实收益的复杂度。实验测试随候选源码保留在output/3d-v63/W07/first-contact-candidate-source，r1/r2日志与xcresult完整保留；不是删除旧失败断言。原SnookerSolverTests方法和其他脏工作保留。
- candidate门禁first-contact-gate-r1 exit0。恢复后原默认完整搜索first-contact-restored-r1/session46195执行中，未声称通过。下一步关注局部接触/调度器已记录热点，不重复此首触优化；W07/W16性能仍未达标。

恢复验证first-contact-restored-r1/session46195 exit0：原默认完整搜索实际1项19.333s通过，内部17.667s、5解，原首触/母球不进袋/停稳断言通过。实验已撤回，当前无活跃句柄；doc-size/diff通过。仅模拟器证据，手机69秒缺口未关闭。

## DR-283 — 有限三角面距离保守筛选（2026-09-13）
- 根因：包围盒重叠仍包含本步不可能接触的斜面边角，继续进行面/边/顶点求根。有限三角面距离满足1-Lipschitz；若初始距离>半径+|v|h+0.5|a|h²+原64ulp尺度余量，可拒绝整面求根。含加速/反向，不缩时间窗、不改接触容差。坐标为SceneKit世界XYZ、Y-up、米。
- 变更：PocketContactTriangle.firstContact默认启用距离筛选；useDistanceBound=false供同函数原求根路径对照。坐标尺度只算一次，复用于边/顶点原有保守界。无捕获规则、袋底/堆球或参数标定变更。
- triangle-distance-r1/session56284 exit0，实际3项18.251s：5400组对照（128命中/5272未命中）时刻/接触点/法线完全一致；旧反向/端点测试通过；实际标准防守内部16.583s、5解。五组shot描述与上一轮恢复版完全一致；单次时差不构成稳定百分比收益或真机达标。
- triangle-distance-r2/session64451 exit0实际仅1项2.045s：任意边界暂停续算通过。其他选择器误指类；不计为额外测试，正常进袋另补。
- triangle-distance-regression-r1/session82747 exit65：实际42项，PhysicsEngineTests41项中仍原10个失败方法/22断言失败（与capture-root-green-r1失败方法集合严格相同，无新增/消失）；正常进袋收集边界1项0.019s通过。保留全部原失败，W07仍FL-070返工。
- triangle-distance-gate-r1/session97251 exit0；doc-size/diff另核。所有测试句柄终态。下一步仍为手机等待时间和剩余正式页面/高度范围，不因此关闭W07/W16。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-283；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-285提前球体接管窗口，修复真实9球种子穿透；6项针对回归和SE最大字号完整开球流程通过。完整41物理测试新增低力度勾球前提差异已用实际接触/独立行程前提两项核对并修正测试输入，原.6另设碰撞见证回归、原失败日志保留；其余10失败未闭合。详W09-working DR-285。

## 当前防守搜索复核与调用栈（2026-09-13）
- defense-stack-current-r1/session75674 exit0，实际1项25.164s，内部23.651616s/3解；r2/session4245 exit0，内部22.678109s/3解。同一当前构建，两轮均不再是DR-283旧5解。现有断言只证明返回解停稳/合法首触/母球未入袋，不证明候选覆盖未下降；禁止继续引用旧5解作当前证明。两轮有Local prediction failed/penetration日志，缺解原因尚未归因。
- r1手动sample时测试进程已终止，未采到样本，不是挂起；r2在实际测试启动后自动定位自有SE进程72286，5秒/5ms调用栈成功保存defense-stack-current-r2.sample.txt。采样会扰动性能，不拿r2计算优化百分比。
- 栈中可见PocketGeometryAsset.load首次初始化锁等待、局部integrate/resistedRotation及大量引用计数/分配；首次资源加载等待不能直接归为稳态锁瓶颈，累计线程采样不能当墙钟比例。搜索层已扣除重复coarseIdx，旧错误首触早停实验不重做。
- 下一步先逐个重放DR-283的5个原解，比较当前完整物理/终态/异常，定位少掉的2解；性能优化须同时保留真实解质量。无新生产改动，两轮测试均已终态。

## 旧五组防守解直接重放（2026-09-13）
- 新增SnookerSolverTests.test_historicalFiveDefenseShotsResolveOnCurrentPhysics，参数逐位取triangle-distance-r1日志，使用真实默认VM球形与PositionPlayShotSolver，不重新搜索或改输入。r1编译失败因未展开可选预测，已用XCTUnwrap修正；r2/session91426 exit0，1项2.653s。
- 五组全部settled且母球未进袋。第1/2/4组仍挡住两颗对方球；第3组_10覆盖余量-0.828683°，第5组_9为-7.790924°，均未完全遮挡。因此“旧五解→当前三解”在这五个固定输入上由终位/防守判定变化解释，不是这两杆模拟失败；尚不证明对应新物理终位比旧版正确，也不证明全搜索无漏解。
- 原默认搜索测试增加独立终态遮挡断言：每个宣称satisfiesConstraint的结果必须保留全部对方球并逐球blocked，原合法首碰/停稳/未入袋断言不删。defense-coverage-current-r1/session16629 exit0，实际2项25.262s，默认完整搜索24.921s（内部23.254819s/3解）及旧五杆0.341s均通过。
- 本轮只改测试，无物理/搜索行为改动。性能仍未达标，日志里其他搜索候选的penetration未解决。下一步按当前实际调用栈缩小热点，不能以强行恢复五解或缩小搜索网格换通过。

DR-286修复并发检测计时：defense-local-timing-r1/session14556 exit0，实际2项23.881s，搜索内部21.948852s/3解，返回参数与defense-coverage-current-r1逐字一致。两检测均2557648条非负计时；累计库边54781.6ms、球球8581.7ms，不当墙钟。下一步检查库边检测重复工作；正式性能与旧物理失败仍未完成。

DR-287恒定球心省算已接：stationary-boundary-r1四项25.295s与r2两项24.884s通过。9/15开球、三组防守参数/25个历史球终位保持；scoring-only/full兴趣球一致。内部19.484/21.075s仍不满足手机体验，不外推真机。只跳过v/a精确全零的静态边界求根，球球/转换照常；不存在丢掉慢球的速度阈值。门禁另核，整体未完成。

## 稳态采样与缓存核查（2026-09-13）
- defense-steady-stack-r1/session70463 exit0，实际默认搜索1项23.945s通过，内部22.408941s/3解。sample定位本轮自有SE进程74456并生成报告；实际采样时间23:03:04.518已接近23:03:07.899测试结束，栈多为等待/收尾，不作为细评主体热点比例证据。不能按脚本预期“启动8秒后”冒充覆盖了指定阶段。
- 当前PocketGeometryAsset已缓存surfaceRoles、captureBoundaries、contactSurfaces及包含BVH的localSimulation；没有每候选重建网格的证据，不新增缓存层。
- 源码确认simulateMixedWithLocalPockets每个epoch在findNextEvent前eventCache.clear；有局部owner时全局stepCap=maxStep。因此其他台面球在袋口小步期间也反复求全部静态边界。后续应研究对未变化台面运动的查询复用，并同时验证局部→台面接触/碰撞失效与Float演化漂移；不能直接删除clear或放大步长。
- 本轮无生产修改，原常规失败、约20秒搜索、W08/W16平台与H01–H04完整范围继续保留。

DR-288圆弧可达范围：arc-reach-r1三项通过，17280组/825命中与旧求根时间一致，3组解/25球终位保持。regression-r1实际47项、21断言失败，仍原10失败方法；9/15开球与scoring/full通过。20.94s未证明整体加速，不关闭W07/W16。详IMPLEMENTATION-LOG DR-288；下一步转回普通进袋失败分类，不继续微小性能扫描。

## 中袋直球首次反弹定位（2026-09-13）
- middle-current-trace-r1/session20003 exit65，原五档进球断言保留；3.3/5.8仍失败，均settled。aim约(3.52e-8,0,1)，瞄点(0,.8,.675965)，不是横向瞄偏或收尾回收错误。
- 3.3杆头速度的目标球进入局部域时vz=4.711726m/s；t=.174005到z=.700791、Y=.827236，t=.176505已vz=-2.038752，随后返回台面。5.8入口vz=8.567483，同样几乎未下沉即反弹。杆头输入与目标球实际速度不可混称。
- middle-surface-r1/session50718 exit0，单项2.222s；从真实Double入口状态计算0.1s，不模拟袋底。首次反向接触t=.1751971373，tablePatches[43986]为Leather，法向(.098014,0,-.995185)，三角X[-.008362,0]、Y[.826726,.834609]、Z[.734221,.735044]。随后t=.20340925触及TaiNi6775/9376袋沿三角。原值见日志。
- 该证据定位到可见袋口背部皮革，尚不能证明它应为软捕获面或当前反弹系数正确；不删除三角、不改恢复系数、不提前宣告进袋。下一步按模型部件/物理消费契约分类这片背壁，并将旧捕获圈“所有力度必进”的前提与新实际碰撞分开审查。其他九类失败不据此一并裁定。

## 内衬物理角色参考补齐（2026-09-13）
从WPA官方PDF读取第10/11节：内衬上部应导球向下，不能把Leather材质名本身当作硬壁响应依据。当前43986法线Y=0，反冲主要朝台面；是否需修改原内衬结构仍待候选验证。不得把back draft12–15度当内衬角或据DrDave吐袋实例认可当前参数。详细来源、已知证据与六袋候选边界见W07-liner-contract.md。本轮没有修改几何/材料参数或删除失败断言。

六袋内衬离线核查：audit/session41932、render-r2/session21000均exit0，六袋均单一连通网格；副本来源哈希与当前USDZ一致。法线/径向初筛只选部分窄条，原图已查看，未采用该标签修改物理。独立blend/JSON/六图与范围见W07-liner-contract。正式资源未改；继续以实际接触种子/面邻接划定完整内壁，避免再增加无依据参数。

内壁范围第二轮：近竖直面连通仍跨外壁，已拒绝；腔内水平射线选区最终四角各114/两中各112面，六图已查看，顶面/外侧/连接片未选。独立cavity-probe-audit.blend/JSON保留，正式USDZ哈希不变。只完成离线选区，未变形、未接App或宣布物理修复。详W07-liner-contract。

## 皮革 e×μ 二维扫值与弧壁导向根因（2026-09-14）
用户提出把皮革恢复系数压到极低让水平速度消失。先复核已有 leather-sensitivity-r1（e=0 仍返回），再把 `test_defaultPocketLeatherResponseSensitivity` 扩成逐次接触打印 + 皮革 μ∈{0.2,0.5,1,2}×e∈{0,0.15,0.3,0.45} 二维扫值。没有修改生产物理、常量或断言。
- leather-contact-trace-r1 exit0（1 项）：默认球形角袋 idx1，目标球 4.13m/s；t=.384968 失去支撑，t=.399073 首撞 Leather 法向(-.957,0,-.290)，仅下沉 1mm。e=0 时首撞法向被吃掉（4.13→2.59m/s），随后 15 次 Leather 接触法向从(-.957,0,-.290)连续转到(.707,0,.707)，每次仅损失微小法向分量，绕壁 180° 后仍 1.8–1.9m/s 且朝台内；t=.4208 撞 cushion 法向(.861,-.053,.506)，t=.4422 撞 clothBed 斜面向上反弹。高度全程 .8275–.8286，未下落。
- leather-sweep-r1 exit0（1 项 25.459s）：16 组全部返回台内，0.2s 末速 0.99–1.49m/s，minY≥.8265；μ≥0.5 三组结果完全相同（切向冲量已到止滑上限，`impact` 中切向冲量=-slip/3.5 只能把 ~29% 切向速度转走，其余转为自旋），e 只影响首撞。结论：**皮革 e 与 μ 都不是本弹出的杠杆**，硬质竖直半圆杯壁的切向弧导向才是；用户「压低 e」方案在该几何上不成立，已如实回复。
- 竖壁贴行时 vy 由 -.133 升至 +.08 已核：ω=(-7.9,8.2,-12.9)、arm=-nR 下接触点相对速度向下 .29m/s，摩擦向上托球，是刚体接触的正常「爬壁」效应，不是求解器错误。
- 下一步候选（未实施、待用户裁定）：①皮革接触引入切向恢复系数 e_t<1（软内衬抓球、切向耗能），Surface 默认 1 不改现有行为；②重启已暂停的内衬几何候选。禁止以扩大捕获区/提前隐藏替代。原 10 个常规失败保持。

## DR-292 内衬耗能体模型接入与回归（2026-09-14）
- 用户提供乔氏台角袋实物照片（已存 output/3d-v63/W07/liner-audit/joy-corner-pocket-real-20260914.jpg）：皮革挂在台框外、顶沿不高于台呢、软且松垂，是接球围裙不是碰撞墙；能顶回球的只有库鼻。据此用户裁定按耗能体建模，决策见 ADR-P10-13。
- 变更：pocketLinerRestitution=0、pocketLinerRetention=0.4；Surface.tangentialRetention 默认 1；linerSink 接入单球与多球两条冲量路径；仅 .leather 绑定。库鼻/台呢斜边/袋沿/捕获边界/固定回收不变。
- liner-retention-sweep-r1 exit0（1 项 19.764s）：同一默认角袋交接状态，保留 1.0×e{0,.45} 两组弹出；保留 .6/.4/.2/.0 × e{0,.45} 八组全部落洞（末态 Y .774–.803，vy 向下，水平≈0）。
- liner-regression-r1（Debug -Onone，UI 开着的 iPhone 17 Pro）多项 30s SIGKILL，单跑 test_bankRails 12.6s 通过；判为环境（同 DR-291 记录），改回基线配置。
- liner-regression-r2（-O、DerivedData-Optimized、与 arc-reach-regression-r1 同选择集）exit65：55 项 1 失败。原 10 失败方法中 bankRails/cornerModerateCut/cornerNearStraight/defaultLayoutPots/easyCornerPot/largeCutClearShot/middlePocket/obstacleAwayFromLine/withSideSpin 九个转绿，无新增。唯一失败 objectPath_reachesPocketWhenPotted：球已捕获（pocket_5、vy=-1.40），仅显示末端距袋心 29.8mm > 旧窗口 20.4mm；末端 z=.7053=皮革面 .735−R，球贴后壁落洞，球心仍在洞口 43mm 内。窗口改为 dropRadius，断言目的不变。
- liner-regression-r3（iPhone 17 Pro，9 套件）129 过 16 失败 3 跳过，其中 15 项 signal kill（含本就 ≥45s 的 Busy45s 系列）；liner-regression-r4 改用 QiuJi-v63-iOS17 专用模拟器重跑 PocketBehaviorDiag/PocketRefactorDiag/PocketLeatherIntegration/ScoringOnlyConsistency：61 项 57 过 3 跳过 1 失败 0 重启（1769s；test_I_lowPowerRailHug 246s、test_Q2_lossStrictness 287s，无历史耗时可比）。
- 残留 test_R2_railFrozenEndToEnd：8 档全部 `Local prediction failed: penetration(.0049–.0112)`。liner-r2-ab-old 将内衬参数临时设回保留 1.0/e .45 单跑，8 个穿透值逐位相同 → 球撞内衬前已失败，是贴库球起始位置与空间库边几何的既有穿透，与 DR-292 无关；此前不在 W07 回归选择集内，新增登记为 W07 待归因项。临时参数已还原。
- 未完成：六袋 × 偏入 × 全力度矩阵、真机性能、rattle 边界带与库鼻系数的交叉核验；W07 仍不关闭。用户另提出「搜索用平面判据、仅对选中解跑空间模型」的拆分求解方案，已口头评估（需 ADR、需收窄 B4 否决范围、需改 ScoringOnlyConsistency 契约），未实施、未入方案文件。
