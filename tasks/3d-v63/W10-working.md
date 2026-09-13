# W10 动作详情与试打接入（进行中）

## DR-246 / FL-068：首屏球形准备

- 源码核对：详情DrillSceneView固定topDown2D且interactionMode.none，透明回放控制面覆盖整个台面；DrillStaticPreview.apply还直接调用rig.applyTopDown2D。正式3D接入须一并处理这些入口，不能只加切换按钮。试打Composer仍tapsOnly且使用2D布局。
- 改前标准机实际detail-baseline-r1/session42853，1测49.965s通过，但原图p1-playing-state为空桌。复制为output/3d-v63/W10/detail-before-playing.png，保留原xcresult。按钮/HUD测试不证明球节点可见。
- 根因与修复：setup先preparePreviewBoard保存球形和homePositions再后台求解；switchFormation复用，避免同步再求解；迟到的预览只在idle绘制，不重画正在演示/暂停的球形。
- detail-seating-r1/session62818终态0，实际1单测0.424s＋1实页UI48.786s通过。无挂起即时摆球/播放节点断言，以及回放隐藏/唤出控制、请求杆末暂停、保持暂停、继续流程通过。
- 改后原图output/3d-v63/W10/detail-after-playing.png已查看：首杆读球形阶段母球、8号及右侧列球均可见，HUD仍位于台面下方。截图为免费详情预览，页面底部解锁Pro是原权限状态，不作为试打已验。标准机iOS26.3；SE/iPad未复验。
- verify-gate/session68326终态0。当前只修基线缺陷，W10完整3D切换、观察、试打、跨杆一致性仍未完成。

## 下一步

## DR-247 详情3D观看入口（验收中）

- 已绑定Published cameraMode，新增2D/3D、全桌、当前杆工具行；透明控制面在3D不命中，实际SCNView处理旋转/捏合/单击唤出控件。静帧Options.adjustsTopDownCamera默认true，详情3D传false；缩略图保持原顶视消费。
- detail-3d-r1/session96139终态0：模式/相机实际投影/球位/播放状态单测0.515s；真实3D观察与杆末暂停往返51.551s；原2D暂停流程50.178s。原图已查看，实际拖动后的台面角度发生变化，暂停往返保持第1/16杆及继续状态。
- r1视觉未接受：横幅默认沿长轴取景，桌面窄小且近端贴边。原图完整保存在output/3d-v63/W10/detail-3d-r1-images；不能用交互通过替代取景达标。
- r2只改详情全桌入口：世界X长轴/Z短轴，yaw=π/2从长库方向观看，沿用rig.observeWholeTable的视口拟合；snapToTarget落实同次复位，避免把update(deltaTime:1)误当无阻尼瞬时定位。任意手动姿态仍可观察。
- detail-3d-r2/session63464运行中；控制器单测0.490s通过，实页及原图待验。完整W10尚含试打、序列换杆兼容、多球形与其他尺寸。

- r2/session63464终态0，实际控制器0.490s/实页51.832s通过，但原图仍沿长轴：beginManualOrbit首次接管重置targetYaw，设置顺序错误，视觉仍不接受。原图保留detail-3d-r2-images。
- r3为CameraRig.observeWholeTable增加可选yaw，默认nil保留旧消费者观察方向；接管后、拟合前应用显式朝向。详情用-π/2，使横向屏幕右方向为+X，保持与2D同向；单测新增真实targetYaw断言，snap仍沿用。detail-3d-r3/session13666验证中。

- r3/session13666终态0，控制器0.464s/实页51.817s通过；横向入框已实现。上一条“yaw=-π/2使屏幕右为+X”判断错误：CameraRig实际Euler转换下屏幕右为-X，原图左右与2D相反。r4改+π/2并用camera.convertVector((1,0,0),to:nil).x>0.99检查实际相机基向量，不再用自拟yaw-right公式证明。原r3图保留，detail-3d-r4/session23853验证中。

### 后续

### 三尺寸首杆边界补验（2026-09-13）

- SE3/iOS26.3/深色/large字号：detail-3d-se-r1/session42846终态0，1项真实UI53.511s通过。iPad mini A17Pro/iOS26.3/浅色/large：detail-3d-ipad-r1/session99342终态0，1项56.432s通过。appearance/content_size均在本轮simctl读回。
- 两设备overview原图已打开：模式/全桌/第1/16杆文字完整，六袋横向入框，台面与底部主行动未重叠。图片分别保留detail-3d-se-r1-images与detail-3d-ipad-r1-images。加上标准r4，三尺寸同一观察/切换/首杆暂停及继续操作已验；不是整条16杆全部完成或所有球形已验。
- 试打接入预飞：Composer.sceneContainer当前tapsOnly，同时绑定onAimNudged、draggableBallNodes和palette的unproject；3D需按FreePlay已验方式解除观察与瞄准/摆球的手势冲突，2D保留精准编辑。stage内仪表/动作/瞄准轮用ShotStageProxy二维台面矩形，需切换ShotPerspectiveLayout；不能只开放cameraControl。
- 序列内容消费新证据：PositionPlayViewModel.swift:265–267明确每杆before含作者手动调整，重建也不能从initial连续推进。下一杆保存before不是一概错误；旧/新结果不同时需保留作者球形并明确呈现杆间切换，禁止为连续动画改变教学球形。DR-245已修运动后after覆盖问题，尚未解决这一切换呈现。

- r4/session23853终态0，控制器实际相机基向量/球位/播放状态0.451s，3D实页旋转/捏合/模式往返/杆末暂停/继续52.130s通过。overview原图已查看，球桌横向完整入框，右侧列球与2D对应；图片保留detail-3d-r4-images。原2DUI在r1已通过，此后仅调整3D全桌朝向。
- 标准机当前入口可进入试用；不宣称完整W10已完成。SE/iPad、Dark/最大字号、多球形切换及试打仍须验证，跨杆兼容问题仍未关闭。verify-gate-r3/session86565终态0，r4仅方向符号/断言调整；doc-size/diff-check通过。

完成详情跨尺寸/球形切换验证，再接试打往返及动作库列表资源边界；同步保留W08/W10保存before与新物理结果的跨杆衔接问题。

## DR-248 试打3D实页与截图复核

- tryout-3d-r1/session96400已结束，xcresult实际1项UI42.488s通过，gate日志FAIL 0/WARN 0。覆盖首杆暂停、只读打点、重播、2D/3D往返、自由与序列切换；不等于全部8杆和所有模式已验。
- 已导出5张附件到output/3d-v63/W10/tryout-3d-r1-images，直接打开序列、暂停打点、重播及自由4张原图。序列右端贴边；暂停只读盘底部读数不可见，背景与操作列重叠。视觉暂不接受。
- 取证风险：新测试在模式切换、面板展开后立即截图，可能记录相机/SwiftUI过渡帧。此次仅在5个截图点各等待1秒，业务状态断言仍立即执行，未改生产相机/面板。tryout-3d-r2/session62298复验中。先验证稳定画面，不能根据过渡截图盲改生产布局。

- r2/session62298终态0，实际1项UI48.130s通过；5张附件已导出，序列及暂停打点原图直接查看。稳定后“低78%”读数完整出现，r1读数缺失确为过渡帧，撤回该项产品缺陷判断。只读卡背景仍跨到右侧操作列；全桌右侧仍贴边，尚待布局/拟合复核。未修改生产布局，避免把截图时机问题当产品问题修。
- 当前无本任务活跃测试。下一步：只读紧凑卡应按实际内容收窄；全桌拟合需核对当前真实视口及操作区遮挡，不用任意缩放常数掩盖原因。W10仍未完成，SE/iPad试打、完整多杆/进袋模式/列表资源和跨杆兼容仍待验。diff-check/doc-size通过。

- r3/session16252终态0，1项UI48.224s通过。紧凑只读卡已按内容收宽，新增实际card.maxX < 继续.minX及低78%读数断言通过；暂停原图已直接打开，背景不再覆盖重播/继续列。gate/session9684终态0。
- SE深色/large由simctl实际读回，同一流程tryout-3d-se-r1已启动，跨尺寸结果待查。全桌取景尚未修改；当前公式按整个视口拟合，未计侧列避让，是否还存在投影裁切需要独立实际投影证据。

- tryout-3d-se-r1/session50073终态0，SE深色large实际1项UI49.395s通过；只读卡与继续按钮不重叠/低78%读数断言通过，暂停原图已打开，母球与动作列可见。卡片仍覆盖近端部分台面，未宣称整桌避让。
- whole-table-projection-r1/session52780执行中：新增独立SCNView.projectPoint检查，三视口×八朝向直接断言桌心居中、外框四角入视口，生产相机未修改。用于区分相机投影问题与UI侧列遮挡，不引入任意fit余量。

- whole-table-projection-r1/session52780终态0，实际1项0.098s通过，三视口×八朝向实际投影断言通过。这只证明裸SCNView/rig基础拟合，不证明Composer当前模型、实际viewport、手势和HUD避让已通过；下一步核对真实页面相机/视口状态与安全操作区，不能凭此关闭贴边问题。当前无本任务活跃测试。

## DR-249 全桌初次切换视口时序
- tryout-camera-diagnostic-r1/session87082终态0，1UI52.764s通过；实页DEBUG投影确认首次402×632下外框右点413.86005超宽，再次全桌后397.9658入框。初次取景在2D/3D底栏变化完成前使用旧height584，非裸相机公式失败。
- 已实现全桌拟合意图跟随真实viewport变化，手动手势/预设焦点退出自动拟合；snapshot保存该意图。三尺寸24朝向增加resize检查，新增手动姿态resize保持检查；tryout-camera-resize-r1/session55013运行中。实际HUD避让尚未解决，不把修复裁切等同于控件避让完成。

- tryout-camera-resize-r1/session55013终态2，xcresult汇总5单测通过、1UI失败，失败为Test crashed with signal term。没有对应新App崩溃报告；不能据此断言产品崩溃或通过。启动独立UI前pgrep确认没有xcodebuild；tryout-camera-resize-ui-r2/session34687单独复验。
- 本次xcresult记录标准机系统26.3.1(23D8133)，此前笼统26.3记录应按此细分。本次五单测包括24组合旧→新视口投影、手动相机resize保持与三项原相机/角弧回归。
- 列表消费源码核对：BTDrillCard→BTDrillThumbnail→BTBakedDrillTable使用烘焙PNG/NSCache<NSString,UIImage>，当前列表卡没有新建DrillSceneView；这只是静态边界证据，未做滚动资源实测，不能直接标列表资源验收完成。

- tryout-camera-resize-ui-r2/session34687终态0，独立UI48.053s通过。实际首次viewport402×632，右点397.8384（改前413.86005），桌心约201×316；目标距离由5.141854改为5.52694。原图28C4167E-23BA-4E4F-8A1D-76A23C437672.png已直接查看，外框入镜；右侧只读仪表仍遮挡袋口，尚未解决控件避让。
- gate/session2044终态0，diff-check/doc-size通过。当前无本任务活跃测试。DR-249标准机首次裁切修复接受；SE/iPad resize及详情/自由击球共用相机回归尚待补验，不宣称全页完成。

## DR-250 序列只读参数避让
- 3D序列将打点图/力度名称/速度放到顶部模式行，取消右侧只读长尺；暂停展开只读打点逻辑保留。普通击球及2D仪表保持原路径。新增参数行实际边界位于场景上方、旧长仪表不出现断言。
- tryout-readout-r1/session72274终态2，模拟器测试器启动被Busy/Application failed preflight checks拒绝，尚无UI通过证据。原日志保留。
- 启动前pgrep无xcodebuild；iPad浅色large实际读回。tryout-readout-ipad-r1/session87923串行跑既有新3D往返及新增8杆逐杆暂停/继续/末杆复位，当前运行中。标准机仍待复验。

- iPad r1/session87923终态2：模式往返49.079s通过，参数行实际边界及无长仪表断言通过；逐杆测试134.121s失败，前7杆通过，末杆测试误期待自动复位。现场图tryout-ipad-last-boundary.png显示第8/8杆+继续，源代码scheduleNextSequenceStep先兑现pauseRequested，resumeSequence无下一杆才finish；这是既有暂停语义，非产品故障。
- 修正新增测试：八杆均等待继续并断言本杆编号，末杆继续后才断言第1杆/击打/上一杆和重播禁用。生产播放逻辑未改。tryout-eight-shots-ipad-r2/session12964复验中，原失败保留。

- eight-shots-ipad-r2/session12964终态0，实际1项98.707s通过：8杆逐杆播放/暂停/继续、3D模式保持，末杆继续后第1/8+击打及上一杆/重播禁用。9张原图已导出，最终复位60B621DE-8176-4A6E-9DE6-5127103344D6.png已查看，初始母球/1号及障碍球和预告线恢复。不是导出一致性、所有球形或全部设备证明。
- tryout-readout-standard-r2/session23530单独串行补标准机新参数行/模式往返，当前运行中。

- readout-standard-r2/session23530终态0，实际模式/暂停/重播/自由往返48.338s通过。序列原图3597E6F3-2B47-43BB-BFB6-5CFFE96BF8EE.png已打开，六袋完整、右袋无仪表覆盖，顶栏参数保留。readout-se-r1/session14919补验中。

- readout-se-r1/session14919终态0，实际1UI47.506s通过，序列原图30681C4F-0F44-4035-9735-238151B1BB99.png已查看：顶部模式及只读参数完整，六袋可见，长仪表已移除。DR-250三尺寸本轮同一模式/暂停/重播/自由往返通过；iPad另有八杆逐杆/最终复位通过。gate/session13964、diff-check/doc-size通过，当前无活跃测试。
- 下一步：W10进袋模式实际击球与球形切换、详情多球形及完整多杆、列表滚动资源验证；W08跨杆保存before/预测结局与导出一致性仍未关闭。W10不标完成，其他批次/高度技能目标仍保留。

## 进袋试打与多球形补验
- pocket-r1/session68146终态0，实际45.923s通过。可编辑打点、2D/3D、击球、回放、重打与序列返回操作通过；改前/回放后/重打后原图已打开，重打后母球不在画面，视觉不接受。DR-251已补非录制重打的视角恢复，pocket-undo-view-r2/session31104验证中。
- detail-formations-r1/session29174终态0，单位1.091s/实页35.789s通过；c042两球形8/5杆，播放中切换即时摆球/XYZ/idle/3D投影，实页播放切球形、暂停往返、返回首球形通过。两张原图已直接查看：球形2五目标球与母球、球形1三目标球与母球和预告线均显示，杆数分别1/5、1/8；不代表详情全部8/5杆验收。

- 续验核实：pocket-undo-view-r2/session31104终态2，编译失败于PositionPlayViewModel回放调用仍传四字段上下文给三字段helper，UI未执行。现仅明确传入before/shot/prediction，pocket-undo-view-r3/session87719重新构建验证；未改击球或袋口物理。

- pocket-undo-view-r3/session87719终态0，实际1UI45.665s通过；击球前AB13E600与重打后561A2B9B原图已直接查看，母球/球杆/目标球恢复同一取景位置。非录制3D重打标准机修复接受。undo-view-2d-r1/session86596验证2D重打不切模式、再进3D恢复原相机，并保留真实母球进袋规则/回放不重复计分/补球验证。
- undo-gate/session21035终态0，diff-check/doc-size通过。

- undo-view-2d-r1/session86596终态0，实际1项14.868s通过，真实SCNView播放、2D重打保留模式/正交投影、再入3D完整相机矩阵与击球前相等、母球恢复与规则单次判定/补球均通过。当前无本任务运行句柄。DR-251标准机3D实页与2D单测范围接受；其他尺寸、连续录制撤销及完整W10仍未完成。下一步继续W08/W10跨杆作者保存before与预测终态的播放/导出衔接，不返回袋底细节探索。

## 列表场景资源静态审计（2026-09-13）
实际链路DrillListView.swift:238 LazyVGrid→BTDrillGridCard.tableArea→BTBakedDrillTable→DrillThumbnailStore.image。列表/行式卡片均加载Bundle内PNG，NSCache只缓存UIImage；缺图为SwiftUI颜色/图标占位。DrillThumbnailRenderer.render在生产Swift文件中无调用，离屏SCNRenderer属于离线工具。故当前列表滚动不会逐卡创建或保留3D场景，W10该项无需引入场景池或额外3D缩略图实现。此结论仅针对列表渲染调用链，不证明详情退出释放或图片缓存峰值；详情重复进入退出与真机内存仍归W16。

详情生命周期核验：DrillSceneController后台首杆求解与延迟播放捕获weak self；AngleSceneView.dismantleUIView停止CADisplayLink。新增真实c078场景/SCNView/协调器，开启3D与播放后三轮dismantle，分别以weak引用检查controller/coordinator/scene释放。lifetime-r1/session53021编译失败，原因测试把await写入XCTUnwrap同步autoclosure，未执行测试；分离await与unwrap后lifetime-r2/session56784复验中。未修改生产资源策略。

lifetime-r2/session56784终态65，实际1项0.938s失败：3轮controller与coordinator均释放，scene即时weak断言均失败。尚不能判断永久泄漏；SceneKit渲染事务可能延迟释放。r3/session91216保持释放断言，增加最多1秒主循环窗口以区分延迟与持续持有，不修改生产代码。

lifetime-r3/session91216终态65：三轮等待最多1秒仍持有scene。r4/session60077终态0，显式在AngleSceneView.dismantleUIView解除pointOfView与scene后，同一测试三轮全释放；证明当前实例持有来自未解除的SCNView渲染关联。保留r2/r3失败，未移除断言。此项不代表真机GPU/纹理缓存峰值或整页导航实测；共享销毁的页面重入仍待UI回归。

DR-270实际导航复验：reentry-r1/session78462在SE运行c078详情三轮进入→3D→播放→返回列表，验证下次默认2D且可再次播放，并留每轮截图。测试不注入场景或播放结果，生命周期weak证明与实页重新显示分开验收。

reentry-r1/session78462终态0，SE实际1项36.188s通过，c078三轮3D播放中返回列表再进入，默认2D及播放键状态正确。3781848C首轮与416E32FE第三轮原图已核：球桌/球形/1/16杆及参数条一致、无黑屏。DR-270生命周期三轮释放与实际三轮重入均通过；仍不外推真机GPU缓存和峰值。无活跃句柄。

详情完整多杆：detail-full-r1/session88098测试c042现有manual01八杆、manual02五杆，逐杆请求杆末暂停并核对当前杆号，首杆暂停时2D/3D往返，最后一杆按详情既有语义自动结束并复位首杆/隐藏HUD。不复用试打页“末杆继续后复位”的不同语义，不修改生产播放。四张关键边界/完局图待核。

## 完整详情与当前验收边界复核（2026-09-13）
- detail-full-r1.xcresult/log已核实TEST SUCCEEDED：1项111.713s，c042 manual01八杆与manual02五杆逐杆请求暂停，首杆暂停2D/3D往返，末杆自动复位首杆且HUD隐藏。测试读取真实库入口，未注入播放结果。
- 四张附件已直接查看：AAC85A5D/4E75AE6E为两球形首杆停稳，球形、杆号和台面外打点/力度读数可见；E0304C21/2A0275B7为两组完成后首杆恢复。来源output/3d-v63/W10/detail-full-r1-attachments。暂停截图模式字有过渡叠影，不把这两帧作为稳定字体渲染证明；完成截图正常。截图FPS不作真机性能证据。
- 对照v63.12 §8：预览/逐杆播放暂停继续、重播/切自由返回、文案避让与当前杆已有上述及前轮定向证据；列表实际PNG调用链和详情三轮退出释放已核。完整八杆实时/导出起点与终点对照在W08已有113.321s证据。
- 尚不关闭整个W10：完整八杆测试当前直接比较的是观察/停稳球节点，不能冒充逐碰撞事件流对照。下一步针对实际实时/导出消费的预测记录核对事件一致性，复用完整序列夹具；无需重跑已通过的13杆详情，也不再扩展袋底模拟。W09前置完整验收和W16平台性能仍各自保留。

事件对照补验：W08 full-events-r1已实际通过1项58.655s，c039完整8杆两条消费者的ShotEvent及原首尾帧断言均通过，详W08记录。上一条事件缺口已补齐，无需再次重跑13杆详情。W10批次依赖W09仍未完整验收，不据此关闭整阶段。
