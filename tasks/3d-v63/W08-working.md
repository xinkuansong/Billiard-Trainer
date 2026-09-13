# W08 时间一致性补验（进行中）

## 当前优先项：保存球形消费差异（2026-09-13 源码复核）

- 后续W10预飞补充：PositionPlayViewModel.swift:265–267明确保存的每杆before可含作者手动改摆，重建时也逐杆使用。不能把所有下一杆恢复before都判为错误并改为物理链式输入；真正未完成的是新物理杆末与作者下一杆球形不同的明确过渡，以及实时/导出同口径。保留现有教学球形是约束，非缩减自然进袋要求。

### DR-245 杆末修复与实际编码验收

- 导出有完整运动预测时改用预测的进袋集合与最终位置摆放杆末，保持已播放球体朝向；保存内容、不可行分支及下一杆before未改。该改动与实时两个消费者的杆末行为一致，完整跨杆兼容仍待解决。
- 新增testExportSettledFramesPreservePredictedBoardWhenSavedOutcomeDiffers：保留c039两杆真实输入，用独立预测逐帧比较实际编码前可见球集合和全部停点。第二杆保存为进球但当前预测未进的前提显式断言；原testTwoCornerShotsExportWithoutRevivingPreviousCapture未删除、未弱化。
- predicted-rest-r1/session19401终态0，实际2测0失败：新测试19.081s，第一/第二杆各24个静帧通过；原半速/原速30/60fps实际运动帧测试17.567s通过。总36.648s。证据output/3d-v63/W08/predicted-rest-r1.log/.xcresult。
- 真实视频predicted-rest-6AD7C975-C6C6-4631-808A-1F596900A8E8.mp4，抽取末帧predicted-rest-r1-final.png已查看：蓝色目标球仍在台面。402×716编码图只作该停点修复证据，不能替代整个视频的取景、完整HUD与真机观看验收。

- 用户要求停止在固定终态上过度投入；方案升至 v63.12。`PocketCollectionTail` 已提供重力下落后固定状态，本次不增加袋内模拟。
- `PositionPlayViewModel.applySequenceRest`（1937 起）有预测时用 `pocketedBalls/finalPositions`；没有预测才回落到保存的 `after`。因此不能笼统声称实时和导出都在杆末强制套用旧结果。
- `SequenceVideoExporter.renderFrames`（574）在运动结束后无条件 `placeBoard(step.after)`；395 另有不可行预测直接显示 after 的分支。修复必须区分正常运动、不可行输入、保存静帧的用途。
- 下一步核对换杆入口和保存内容契约，再确定统一结果消费方式。只更换导出杆末会留下下一杆跳变；强制目标球进袋会掩盖物理差异。此次为只读审计，无新增运行验收，不改变 c039 原失败状态。

前序证据见W07-working.md和README。本文件追加实际SceneKit动作时钟验证，不能代替全部实时/导出/暂停验收。

## 空间动作跨速度与帧率
- 新增PocketGeometryInjectionV63Tests/testSpatialActionMatchesTimeQueryAcrossFrameRatesAndSpeeds：实际角/中袋空间捕获记录，SceneKit执行action，在30/60fps、0.5/1/2倍速下逐帧比较真实节点位置与透明度和绝对时间查询。16×16离屏仅用来驱动动画，不作为视觉图证。
- r1/session44932终态2（内层测试失败），实际1测在末帧XCTAssertEqual(node.opacity,0)失败，值5.8284026493993224e-08；此前该组合每帧位置/透明度容差比较通过。不能称完整12组合通过，因为continueAfterFailure=false提前停止。
- 原断言要求浮点末时刻透明度精确0，和逐帧已采用1e-5容差不一致；r2仅将末帧断言按同一透明度容差比较，不改生产动作、物理、逐帧坐标容差或跳过组合。精确隐藏/离场另由已通过的母球生命周期及页面测试覆盖。
- spatial-action-clock-r2/session77244运行中，下一步核对实际结果；r1原日志/xcresult保留。

- r2/session77244终态0，实际1项8.580s通过，覆盖2袋×3速度×2帧率=12组合，逐帧位置及透明度比较通过。证明SCNAction时钟消费与绝对时间查询一致；尚不代替实际导出逐帧采样、暂停/任意定位、完整页面多球同刻收尾验收。doc-size/diff-check通过。

## 离屏杆内暂停验证（未通过）
- 新增testSpatialActionPauseResumesWithoutAdvancingCapture：复用2袋/3速度/2帧率，在收集下落中段暂停节点5帧，检查暂停保持和恢复后的绝对时间位置。
- spatial-pause-clock-r1/session46891终态2，首组合角袋/0.5倍/30fps在恢复frame16失败：actual.x=-1.3225217，expected.x=-1.3213303，容差1e-5。暂停期间位置/透明度保持断言未失败；全矩阵因continueAfterFailure=false尚未跑完。
- r2/session41650终态2：在暂停/恢复切换时补同时间snapshot边界帧，仍同一误差。此假设未解决失败，原证据保留，不调整生产回放或位置容差。
- 待判断离屏SCNRenderer与isPaused时间提交语义、测试时钟假设或动作消费问题。不得把该测试失败直接归为现有页面故障；实际序列页当前是杆末暂停，已在前轮真实UI覆盖；杆内暂停组件验证仍未通过。新测试保持失败可见，W08未完成。

## 暂停时钟根因与真实时钟复验
- r3/session12052终态2，新增同组SCNAction时钟探针：暂停前frame15，expectedWall=.5、rendererTime=.5、actionElapsed=.5000000016；恢复frame16，expectedWall=.533333、rendererTime=.7、actionElapsed=.6956099768。离屏循环瞬间推进虚拟渲染时间，但isPaused仅经历约.00439s实际时间，原测试错误预期扣除.166667s。
- r4改为CACurrentMediaTime驱动实际快照并按30/60目标帧间隔等待；暂停5帧使用同一真实时钟。每帧仍以独立同组动作elapsed核对生产动作位置/透明度；暂停时动作elapsed和状态精确保持，恢复增量受真实时间上下界约束，不能包含暂停时长。未放宽原坐标容差，也未改生产动作/引擎。
- spatial-pause-clock-r4/session73087终态0，实际1项24.476s通过，角/中袋×0.5/1/2速度×30/60帧=12组合。属于真实时钟下的SceneKit组件验证；页面杆末暂停与实际导出/定位验收仍分开。r1–r3原失败作为错误测试前提证据保留。

## 实际导出世界状态对照（DR-244）
- Options.motionFrameObserver仅DEBUG且默认nil，在实际renderFrames运动循环编码前复制节点worldPosition/opacity，测试不伪造或改写节点。
- testSpatialSequenceEncodesAtTwoFrameRates沿用真实c042首杆、实际AV编码，并针对捕获球逐帧与独立预测记录的时间查询比较，检查出现最终不可见帧。
- export-states-r1/session55756运行中；不能把新断言尚未执行称已通过。

- export-states-r1/session55756终态0，实际1测16.763s通过：原速30/60fps分别123/246运动帧对照，均观测完整淡出；实际mp4输出C301F455-0E20-4E9C-8EC8-13C98F4E3A58目录。
- export-states-r2/session73680终态0，实际1测26.670s通过：新增半速30/60fps分别246/492帧，原速分别123/246帧，共1107运动帧实际节点世界坐标/透明度与独立预测时间查询一致。半速视频13.566667/13.55s，原速8.7/8.683333s；同速帧率变化时长差<=1/30s。每组合均完整捕获淡出。
- 产物：output/3d-v63/W08/encoded-sequence/1C620827-758B-4B16-ABE0-9A17F5AD39CA，四个capture-<speed>x-<fps>fps.mp4。仅证明固定真实首杆中袋捕获，不外推角袋导出/多杆衔接/任意时间定位。gate输出export-states-gate.log。

## 两杆角袋序列兼容性发现（未通过）
- 使用真实drill_c039__manual01前两杆，两杆保存的after/before逐球坐标完全一致；袋口bottomLeft→topLeft。DEBUG观测增加step UUID与实际可见boardKey集合，便于换杆追踪，旧单杆测试已适配签名。
- two-corner-export-r1/session10008终态2，测试编译失败：CanvasPoint不支持整体Equatable；改为逐键/逐坐标比较，不改生产模型。
- r2/session66779终态2，目标进袋断言失败，未运行到实际编码；r3/session2031终态2补诊断后明确：第1杆EA793438-D256-4855-8EE0-5B5D521C4448/_1/bottomLeft，feasible=true、settled、objectPocketed=true，duration1.4589404；第2杆7E6E95F1-C0F3-43F1-AF5F-9B01733969DC/_2/topLeft，feasible=true、settled、objectPocketed=false，duration5.530551，potted=[]。
- 保存内容第2杆potted=[_2]。实际object最终(-.28717992,.828575,.49259865)，仍在台面。当前export renderFrames杆末ctx.placeBoard(step.after)会采用旧保存结果，存在未进球突然离场风险。尚未在实际多杆视频复现，因为前置断言正确拦住；不得称视频已验。
- 下一步优先旧/新入口同输入对照及保存结果消费审计；不以选另一条更易通过序列或改内容potted来隐藏此兼容性问题。原测试/日志完整保留。

## c039第二杆旧/新入口同输入对照
- corner-model-comparison-r1/session66724终态0，实际1测9.150s通过（断言两入口完整结束，不代表球应进袋）。按PositionPlayShotSolver相同坐标转换/障碍球组装输入，先取平面入口瞄准offset=-.00024844692，再固定该offset传局部入口，隔离瞄准差异。
- 平面：object于t=.3318339在pocket_0捕获，位置(-1.2778536,.828575,-.6525457)。局部：不捕获，最近点(-1.3048651,.8258149,-.6787319)，t=.37086543/.40800852/.5272998记录object袋口/库碰撞，随后返回台面并撞_3。两入口首次cue/object碰撞均t=.12280992。
- 因而差异位于旧捕获圈之后的局部接触阶段，非保存球位读取/瞄准方向变化。尚不能判断当前硬质袋口碰撞正确与否；下一步查此时接触几何/材料、并审计消费者强行套用旧after的行为。禁止无证据让该杆强制进袋或改内容potted掩盖差异。

## 实时与导出跨杆直接对照
- 新增DEBUG只读observationFrameObserver记录导出实际观察帧球节点。既有c039两杆预测终态回归扩展为真实SCNView播放两杆、逐杆暂停取终局，继续后立即取保存before；导出逐观察帧/停稳帧与实时XYZ及可见集合直接比较，同时保留原预测终态断言。
- cross-step-live-export-r1/session64648运行中；未改保存内容或生产播放语义，不把增加断言当验收完成。

- cross-step-live-export-r1/session64648终态0，实际1测31.633s通过：真实SCNView两杆逐杆暂停/继续，保存before逐球验证，导出每杆观察帧与实时起点、每杆24停稳帧与实时终局及独立预测一致。不是只比较两个数学helper。视频predicted-rest-20675242-E698-41A8-8FE3-450ECA820AD6.mp4时长16.233333s；opening/final抽帧已直接查看，第二杆未进蓝球保持在台面。
- cross-step-gate/session21400终态0，diff-check通过。两杆消费一致性接受；原旧/新物理进袋差异仍保留，完整序列/任意定位未关闭。导出观察帧没有当前杆号，换杆理解不如实时页明确；下一步补当前杆信息并验证画面布局，不能用本次坐标通过替代视觉衔接验收。当前无运行句柄。

- DR-252候选已接3D教学视频杆号行，场景外独立行不压缩台面或原参数。export-progress-r1/session98029实际双杆实时/编码一致性验证中；通过后须打开观察/执行/末帧确认文案与布局。

- export-progress-r1/session98029终态0，实际1项31.981s通过，实时/导出两杆观察与停稳节点比较仍通过。视频predicted-rest-D699D001-3B56-463D-9BD0-A18CC1D46BDC.mp4实际402×786、16.233333s；0.5/6.5/8.0/16.0秒原图已直接查看，依次第1/2观察、第2/2观察、第2/2带参数、第2/2终局。杆号与参数均在台面外，观察阶段未提前露参数。
- export-progress-gate/session52471终态0，DR-252该视频提示接受。当前无运行句柄；仍需完整多杆/其他序列、列表资源与后续页面，不以两杆视频关闭整个W08/W10。

## 完整8杆扩展（未通过）
- 保留c039固定序列原8杆，取消测试对前2杆的截取；原预测终态/实际实时和编码断言保留。full-sequence-live-export-r1/session58619终态2，模拟完整结束断言失败，未进入全序列编码。
- r2/session38200终态2，明确第4杆A6536409-CA24-4D8B-BBEA-A872C452F7CA在15.0秒timeLimit终止，仅一次t0.16934156母球/object碰撞。不能把前两杆通过推广到完整8杆。
- 新独立testFourthAuthoredShotReachesSettledState记录该杆最后两条平面/局部状态，第四杆自身2.1m/s、spinX0、spinY-0.055、topCenter。fourth-shot-settle-r1/session77998运行中；没有修改物理阈值、上限或保存内容。

- fourth-shot-settle-r1/session77998终态2，实际14.560s失败。末段其他球stationary，object持续自由落体，t15时y=-1033.2992m、vy=-142.43944m/s，明显未被离场/收集边界接收。不是慢速未停或袋底微碰撞。当前捕获还要求硬表面下方的袋体截面包含球心投影；r2/session44236补实际handoff/穿越capture plane的位置与轮廓，区分截面漏收与穿出袋体，尚未修改物理判定。

- fourth-shot-settle-r2/session44236终态2。pocket_4收集高度0.71522099m，首次穿越球心XZ(0.00768446,-0.73108670)，到截面最近距离8.311972mm < R28.575mm。数值/截面图明确球体接触、球心在外。DR-253改圆与多边形接触，未调几何大小/模拟上限。sphere-collection-r1/session83983终态0，3项9.095s通过，第4杆末记录1.4578476s已pocketed。full-sequence-live-export-r3/session44410运行中，附六袋边界与正常入口回归。

- full-sequence-live-export-r3/session44410终态0，实际3项全通过：c039完整8杆真实SCNView逐杆暂停/继续与导出观察/停稳节点直接对照113.321s；八杆各24静帧共192帧通过，原第二杆旧保存进球与新返回差异断言仍通过。六袋边界0.042s、正常入口0.631s通过。实际mp4 predicted-rest-EA5167D8-B2A2-4402-9E83-377531CC44DF.mp4长67.233333s，第3杆与第8杆原图已直接查看，末局仅母球，第8/8与参数完整。
- sphere-collection-gate/session55068终态0，diff-check/doc-size通过。DR-253/FL-069接受当前固定失败及截面边界范围；其他旧临界案例、完整跨设备视觉、后续页面和高度技能仍待验。无活跃句柄。

## 时间定位范围核实
PositionPlayViewModel.requestSequencePause在杆末暂停，resume从completedStepIndex+1开始，重播重新运行指定杆；DrillSceneView同样是pausingAfterShot→paused→下一杆。当前没有任意拖动时间轴入口，不能为了验收新建产品交互。底层TrajectoryPlayback.stateAt/collectionOpacity按绝对模拟时间供导出和回放取样；新增角袋/中袋真实捕获记录反向/正向时间查询，验证隐藏终态固定及重复中段查询不被后时刻污染。query-order-r1/session39090运行中。

query-order-r1/session39090终态0但实际0项：文件内新增方法属于PocketGeometryInjectionV63Tests，选择了文件首个TrajectoryRendererTests类。该run不计通过，撤回尚未核实的1项结论。改用真实所属类复验，保留r1证据。

query-order-r2/session38978终态0，PocketGeometryInjectionV63Tests.testCollectionQueriesRemainIndependentAcrossBackwardAndForwardTimes实际1项2.262s通过。角袋/中袋真实捕获记录乱序查询后，终态XYZ固定且透明度0，重复下落中段XYZ一致且透明度1，记录数量不累加。构建及diff检查通过。仅证明时间查询独立性；已有UI杆末暂停与实时导出证据分别保留，不新增任意拖动入口。当前无活跃句柄。

## 实际消费事件对照（2026-09-13）
- full-events-r1/session37209终态0，实际PocketGeometryInjectionV63Tests.testExportSettledFramesPreservePredictedBoardWhenSavedOutcomeDiffers 1项58.655s通过。复用c039原8杆及旧保存进球/实际返回台面的断言，没有替换内容或缩减序列。
- 两个DEBUG只读观察点分别位于实时runSequenceStep和导出renderFrames选定可播预测之后，暴露值类型[ShotEvent]，无模拟或场景修改能力，Release不包含。测试逐杆比较事件数量、顺序、类型、时间（1微秒容差）、碰撞参与球与进袋ID，断言八杆各出现一次且非空；不是重新调用helper后自比。原观察帧、每杆24停稳帧共192帧的XYZ/可见球集合与独立终局断言同时通过。
- 本轮视频predicted-rest-F00B4E26-229C-4424-9C56-8B1A06A85A1A.mp4已写盘；未重新作视觉画质验收，本轮只增取证钩子/事件断言，无渲染行为改动。full-events-gate-r1/session46648终态0。W08/W10此固定完整序列的事件一致性缺口关闭，W07旧物理案例与W16完整平台性能仍未完成。

DR-279完成本轮入口修复：force-scale-r2/session1884实际5项/0失败1.087s，原指定模型近袋.101s通过，双球滑移/顺序交换与未完预测拒绝保留。contact-regression-r1/session42730终态0，真实c039完整8杆实时/导出事件、起止球形与192静止帧对比1项57.338s通过；旧保存第二杆离场与当前返回台面差异断言仍通过。未新审MP4视觉，不据此宣称全部W08/W16完成。

## DR-281 后完整八杆实时/导出复验（2026-09-13）
- capture-root-sequence-r1/session60463 exit0，实际1项56.298s。使用当前已构建DR-281产物；真实c039八杆逐杆实时播放/暂停/换杆与导出同事件种类/对象/顺序/时间、同起始球形、同杆末XYZ和可见球集合。八杆各24个杆末帧，共192帧。旧保存第二杆进袋与当前返回的差异断言仍通过。
- 实际输出predicted-rest-856E57EF-6C59-41B6-993F-0C56FA0ECAB4.mp4，ffprobe确认402×786、30fps、67.233333s；输入options.size402×716为表区，最终含底栏，勿将视频高度误报716。
- 已直接查看capture-root-sequence-r1-contact-sheet.png（0.5/5/15/25s）及late-frames.png（40/55/67s），覆盖杆1/2/3/5/7/8。桌体与球、杆序/打点/力度可见；第7杆辅助线与球杆可见，第8杆末帧完整。仅离散抽帧，未声明连续近袋视觉、低机位遮挡或真机帧率/热量验收。
- 本次复验不关闭W07普通物理10项失败，也不以数据/抽帧通过代替W08/W10/W16所有要求。

## DR-285 后当前完整序列复验（2026-09-13）
- ownership-sequence-r1 已终态成功；真实 PocketGeometryInjectionV63Tests.testExportSettledFramesPreservePredictedBoardWhenSavedOutcomeDiffers 1项58.391s、0失败。八杆实时/导出事件、起终球形及192杆末帧断言保留，旧第二杆保存进袋/当前返回的差异未被抹平。
- 当前文件 predicted-rest-BF0950C4-7A74-48E3-AEC5-2C854C29A5A7.mp4 经ffprobe确认402×786、30fps、66.800000s。不得沿用旧版本67.233333s。
- 已查看 ownership-sequence-r1-review.png 七帧拼图，覆盖第1/2/3/5/6/7/8杆；台面、杆序、打点/力度可读，第8杆只剩母球。离散抽帧不证明连续袋沿遮挡、原生分辨率画质或真机帧率。
- 任意定位查询已有query-order-r2证据，README旧“任意定位待验”应修正；真实产品仍为杆末暂停，不增加时间轴。W08保留连续近袋视觉与适用平台验收缺口。
