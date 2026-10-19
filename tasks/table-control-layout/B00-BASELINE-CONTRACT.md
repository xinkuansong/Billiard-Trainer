# B00：操作布局基线与接入合同

日期：2026-10-17。真源：[v1.1 方案](../TABLE-CONTROL-LAYOUT-PLAN-20261017.md)。状态：✅ B00完成。18入口源码核对、三页区域/暂停/保存流程合同、四窗口108张基线与3张实际击球忙碌样本已交付；B01依赖就绪。

用户已明确要求“好的，开始执行吧”。本批落实 B00，App 布局实现从 B01 起。以下“当前”指冻结源码中的行为；“接入合同”指后续要实现和验收的行为，二者不得混称。

## 1. 版本、范围与复现

原生证据目录为 [B00/r01](../../output/table-control-layout-20261017/B00/r01/)，其中 `source-fingerprint.json` 记录源码哈希，`git-status-before.txt` 和 `git-diff-before.patch` 记录采集前工作区。HEAD 为 c31fad98，但存在大量同期改动，不能用 HEAD 单独复现。App、扩展和配置冻结在 `/private/tmp/qiuji-layout-b00-source`，隔离工程同目录；独立 DerivedData 为 `build/ControlLayoutB00`。采集测试不加入正式工程，源文件位于证据的 `capture/`。

设备通过 `scripts/simulator_lifecycle.py run --udid` 显式借用已关机且无租约的设备。临时新建被8台容量限制拦截后，改用独立 bundle ID `com.xinkuan.qiuji.layoutbaseline`，保留原App安装和数据、设备保护标记；记录并恢复外观/字号，结束关机。每台的 `device-state.json`、测试参数、原图、AX 树、JSON 控件框和 xcresult 一并保存。截图使用中文、深色、标准字号、DEBUG 会员及内存数据夹具；这是布局基线，不是会员、冷启动、浅色、大字或真机验收。每日页面使用 selection 夹具，不把该球形解释为普通用户首次进入状态。

### 1.1 入口核对

| 入口 | 冻结源码中的导航与宿主 | 独立身份/差异 |
|---|---|---|
| P01 每日清台 | MainTabView → FreePlayView(entryMode: .dailyClearance) | dailyClearance；计分、玩法与每日草稿 |
| P02 自由击球 | MainTabView → FreePlayView() | freePlay；手动开球/自由摆球 |
| P03 分离角与走位 | MainTabView → ShotSimulationView → FreePlayView | shotSimulation；教学限制 |
| P04 蛇彩 | MainTabView → SnakePracticeView → FreePlayView | snakePractice；首杆摆球/失败与尝试记录 |
| P05 自由走位 | MainTabView → PositionPlayComposerView → FreePlayView | composer；编排/录制 |
| P06 详情试打 | DrillDetailView → PositionPlayComposerView(sourceDrill:) | drillTryout；只读序列/作者球形 |
| P07 思路训练 | MainTabView → SiluTrainerView → BTTeachingTablePage | silu；约束、求解、解与开球子状态 |
| P08 打一走二想三 | MainTabView → PlanThreeView → BTTeachingTablePage | planThree；角色/步骤 |
| P09 防守 | MainTabView → SnookerTacticsView → BTTeachingTablePage | snookerTactics；目标和障碍 |
| P10 翻袋 | MainTabView → BankShotView → SolverStageChrome | bankShot；库数/解 |
| P11 颗星 | MainTabView → DiamondSystemView → SolverStageChrome | diamondSystem；解球目标 |
| P12 角度与瞄准 | MainTabView → AngleDynamicView → BTTeachingTablePage | angleDynamic；教学读数 |
| P13 分离角图谱 | MainTabView → SeparationAngleAtlasView → BTTeachingTablePage | separationAngleAtlas；轨迹/读数 |
| P14 加塞吃库图谱 | MainTabView → CushionEnglishAtlasView → BTTeachingTablePage | cushionEnglishAtlas；教学参数 |
| P15/P16 2D/3D角度训练 | MainTabView → SceneAimingView(initialCameraMode:) | sceneAiming2D / sceneAiming3D；独立页，不合并成绩 |
| P17/P18 2D/3D瞄准点训练 | MainTabView → AimPointSceneTrainingView(initialCameraMode:) | aimPointScene2D / aimPointScene3D；独立页，不合并题目 |

22 个 TablePreferencePage 身份中，18 个在已批准范围；`drillDetailPreview` / `drillRecordPreview` 是嵌入预览，不开放编辑。同期新增的 `customFormationPractice` / `customFormationEditor` 已存在于枚举与 FreePlay 宿主，不能再称“仅在设计中”；它们暂保持默认，未来需另列接入/验收，不自动扩入本轮 18 页。拍照识球转入思路/编排/PlanThree 仍使用目的页身份，不生成新的布局页 ID。RootView 的 DEBUG 深链用于到达同一宿主，不能取代正式导航入口的代码核对。

## 2. 坐标与固定区域

页面布局单位为逻辑 pt，页面左上为原点，X 向右、Y 向下。AX 坐标属于屏幕；先减页面 frame 原点再与区域比较，不把截图像素当 pt。SceneKit X–Z 水平面、Y 向上的世界坐标只用于球桌几何，不能存入布局偏好。

记真实安全区调整后的页面为 P，`DailyLayoutMetrics.Foundation` 结果为 F。F 使用当前默认仪表测量值求解一次；个人配置不得反向改变它的球桌大小。左右安全区只扣一次。当前列宽 60；导航带高 44；F.table 为默认外桌框，F.stage 是含渲染边距的框，两者不等价，3D 场景可延伸覆盖整个窗口。

| 区域 ID（拟新增） | 边界及位置表达 | 接纳内容 | 跨区与保护合同 |
|---|---|---|---|
| fixed.navigation | 现有返回、标题、更多的实测 frame 并集；固定 | 返回/更多/标题/必要状态 | 不拖动；所有目标先扣除真实命中框 |
| fixed.palette | 当前 Palette 求解的实际球库/翼框；固定 | 球库及业务选球 | 不重排球序、不缩桌换空间 |
| lane.leading | X = F.left.minX，宽 60；Y 从 44 到 P.height，扣除导航/球库/状态实际侵入段 | 方向组、重打回放组、仪表组、主动作、思路整组 | 一维顺序 + 有界纵向偏移；不是任意二维坐标。组的视觉与命中并集须全在许可段 |
| lane.trailing | X = F.right.minX，宽 60；同上 | 同上 | 跨侧只能显式交换；同时验证两侧全部组，不能只把单组叠到原控件上 |
| camera.default | CameraLane 根据 powerShell 实测中心计算的当前槽位 | 相机整组 | 保留默认桌缘覆盖例外；不向普通组开放 |
| camera.mirrored | 将相机组放在左侧仪表朝球桌的一侧；独立验算后的候选槽位 | 相机整组 | B02 须验证球库、状态、触点、特写和临时俯视，验证前不可选，不能复用右侧 offset 符号 |
| fixed.information | 当前教学/比分/状态保护框 | 页面信息 | 首阶段保持原位；不因侧列变动裁掉错误/必要提示 |
| floating.spin/menu/closeup | 当前专用算法 + 最终触点/保护框 | 打点盘、透明度/更多面板、特写 | 不保存自由位置；展开和收起不重新排列主操作 |
| protected.table | 默认桌面交互框与球/袋/轨迹保护 | 场景触摸 | 普通控件不得侵入；仅保留已明确声明的相机/浮层例外 |

3D 的 renderer 是全屏，不能把整个 renderer 当作普通组禁入区；也不能把透视投影的桌边当作移动区域边界。普通侧列始终来自固定默认 Foundation，桌面禁入区使用同一逻辑参考桌框，3D 输入/特写另外扣除最终控件命中保护框。

槽位排布先用现有默认顺序；配置只存稳定区域、组顺序及受限偏移，frame 不落库。默认组对齐方式按宿主保留：FreePlay 两列围绕桌框中心，思路普通左列由宿主按 table.midY 放置，不能以同一顶部填充抹平差异。可偏移量从许可段减整组高度计算，负容量拒绝。排序的间隙为既有 4pt；主操作周围保留现有命中空间，不通过改变文字字号获得容量。

当前 Foundation 默认档位：页高 ≥396 时顶部 56、辅助 48，否则 48/44；方向尺 144 或120；间隙8或4；小高度时辅助操作按现有横排。它们是当前自适应结果，不是已开放的个人档位。B02 的有限候选为方向尺120/144、顶部48/56、辅助44/48，主动作固定60，思路普通工具固定44、整组宽60高≤284。候选必须通过当前窗口全组容量和行程验证后才能显示；默认选项始终调用原计算，不能写死为某个数值。杆速读数与打点入口首版成组，组内尺寸随现有档位，不单独缩放。实测FreePlay杆速命中宽52pt，而Silu为60pt；两宿主必须共享区域规则、保留各自真实组边界，不能强制成同一内部框。完整左右交换在两列都容纳且相机关联槽位合法时才开放。

已取得的每日/自由页数据：标准手机页面874×382、默认组高336，扣44导航后的纵向整组余量仅2pt；SE页面667×375、组高312，余量19pt；iPad横屏页面1210×782、组高352，余量386pt。这是扣其他障碍前的数学上界，不承诺每个偏移均合法。Silu普通左组只有284高，须按实际组单独求余量，不能套用Foundation整组高得出相同拖动范围。默认列位置与球桌大小不因用户配置改变。

容量失败顺序：原意图 → 本许可段夹紧/吸附 → 全部保护框校验 → 整页临时安全默认。默认仍不合法时显示可返回的空间不足状态。不得自动换侧、隐藏主操作、缩桌或把回退写回个人配置。

## 3. 控件目录与状态语义

| 组/控件 | P01 每日清台 | P02 自由击球 | P07 思路训练 | 可编辑与保护 |
|---|---|---|---|---|
| 顶部返回/更多/球库 | 原动作与合法球选择 | 原动作与摆球 | 目标球选择/摆球 | 固定、命中框障碍 |
| 顶部业务动作 | 重开/玩法状态依当前阶段 | 开球/重开 | 普通无方向顶部；开球子状态重开 | 随完整业务组；不得新增阶段中不存在的动作 |
| 方向尺 | 原瞄准增量 | 原瞄准增量 | 仅开球时存在 | lane；120/144候选；真实触点和灵敏度验证 |
| 重打/回放 | 撤销该页一杆/回放 | 撤销该页一杆/回放 | 普通工具组中的重打/回放 | FreePlay 成组；Silu 不从整组拆出；禁用仍占位 |
| 杆速+读数+打点入口 | 原参数/提示 | 原参数/提示 | 无解禁用；有解调当前方案；开球调runner | lane成组；不得换绑模型，打点入口与大盘框关联 |
| 主动作 | 开球/确认/击球随状态 | 开球/确认/击球 | 计算中/击球/开球/完成 | lane；固定60；不能隐藏或解除禁用 |
| 思路工具整组 | 不支持 | 不支持 | 摆球/落区/落点/过点、清除、求解、解切换、重打、回放 | lane整组宽60，高min(可用高,284)，内部44与4间隙，保留ScrollView；不借用为FreePlay撤销组 |
| 相机组 | 3D状态显示 | 同左 | 同左；是否可瞄准受解状态约束 | camera槽位；完整组，禁用/临时俯视保留 |
| 展开面板 | 打点、透明度、更多、玩法/结果 | 打点、透明度、更多、开球 | 打点、透明度、更多、帮助/解信息、开球 | 固定浮层规则；布局草稿不能触发真实开球/清台 |

普通态、无解/不可击球、开球摆位/确认、击球/回放、求解、临时俯视、拖球/拖尺/按住杆速、展开菜单/打点、结果态均需声明。禁用只改变 enabled/opacity，不删除槽位。普通态与开球态替换页面专属组时预留各自声明范围，不能让主动作跟随方案数量跳位。P07 普通态没有方向尺是“不支持当前状态”，不是“方向尺被用户隐藏”。2D 没有相机操作但保留其配置，切回3D再解析。

布局编辑入口仅在原业务安全空闲且无活动手势时可进入；击球、求解、回放和相机过渡时不可通过菜单强行开启。临时俯视按现有交互退出后才进入。实际忙碌样本与临时俯视样本必须标明区别。

## 4. 生命周期与计时接入合同

| 当前消费者/入口 | 当前事实 | 后续编辑接入 |
|---|---|---|
| FreePlay.onDisappear | 蛇彩finishAttempt；只读序列exitSequenceMode；结束临时俯视/按压/预览；每日stop | 布局overlay保留原VM/scene；显式离页原因判断，编辑不触发前两项；真正退出保留原清理 |
| FreePlay.scenePhase | 失活suspendGuidedSequence/flushActivity；前台resumeActivity并重算 | 编辑仍打开时不恢复输入、计时、重算；后台原因与编辑原因分别持有 |
| DailyClearanceController | activeSince非空才flush，计入draft.activeDurationSeconds；stop只是flush；resume要求draft存在 | 进入编辑flush一次；回训练且前台resume；嵌套管理退出不resume；不新建每日记录 |
| ToolUsageSessionModifier | appear开始，disappear/失活flush；每个≥5秒片段写tool，分钟四舍五入且至少1 | 编辑暂停先把有效秒数累加到同一次前台访问的内存累计量，不为每次打开编辑器立即新增tool行；真离页/后台沿用原分段落库和取整规则。恢复从新时间点接续；不写DrillEntry/made/target，不改业务训练完成次数 |
| 工具记录实际覆盖 | FreePlay为freePlay/dailyClearance；编排包装层另管freePosition/drillTryout；PlanThree有自己的modifier | 本批三页中Silu没有现有tool计时，不新增。B06保留编排入口级归属，不在共用VM重复记录 |
| BTTeachingTablePage.suspendActivity | 清空手势、结束临时俯视、调用planning.onDisappear及vm.suspendTeachingActivity | 不把它整体当布局暂停；分离纯输入挂起与离页业务回调 |
| Silu planning.onDisappear | vm.stopForDismissal | 布局编辑前只允许空闲；保留约束、解索引、球位和模型实例；不借停止离页清空状态 |

建议最小实现是页面生命周期协调器持有 `editorOpen / sceneActive / pageValid` 三个事实；嵌套预览与管理由一个编辑会话拥有，不需要全局通用任务调度器。有效训练 = pageValid && sceneActive && !editorOpen；只在布尔状态边沿调用计时启停。真实离页永远使pageValid=false；重复onAppear不能在编辑器仍开时重启计时。

可控时钟例：训练0–10s→编辑10–70s→后台70–100s→仍在编辑100–120s→恢复训练120–140s→退出。每日增加30s；工具因真实退后台保持原有两段记录规则（10s与20s各自满足阈值），不产生编辑记录。若删去中间后台步骤，只是训练→编辑→训练→退出，则累计30s只落一次tool记录（按现行规则1分钟），不能因编辑拆成两条并重复向上取整。累计有效时间<5s的真实前台访问段继续不落库。编辑间隙不重置这个累计量，进程终止也不能补计暂停间隙。保存失败、冲突、取消、管理返回和重复回调均测；计时分钟取整规则不在本需求重做。

## 5. 编辑/保存流程样例（设计合同，非 App 截图）

1. 每日清台空闲 → 更多 → 操作布局。创建当前修订快照，暂停真实训练，编辑器展示隔离球形和原生控件示例；默认作用“本页，2D与3D共用”。球桌、顶部和球库显示锁定说明。
2. 选择方向组 → 拖动排序，或用“上移/下移/交换左右”按钮完成同一操作；只有已验证的档位可选。错误落点还原上次合法位置；页面内提供基础撤销/重做。
3. 展开打点/菜单检查保护框。点击击球只演示按钮状态，不驱动背后的训练；求解样例不启动真实求解器。当前业务球位/比分不变。
4. “保存到本页”：只写选定page/domain/mode/property覆盖，显式等于模板的值仍保留用户意图；成功后才替换布局，关闭编辑并按前台条件恢复。
5. “另存模板”：例如复制A为B，将当前选定本页差异合入B的对应层；新模板、当前页绑定、清除已合入精确覆盖同事务。未合入域/模式/属性和其他页不动。返回后B独立，不跟随A。
6. 从自由击球显式应用B：预览其可借用组；不支持的Silu专属组保留存储但不呈现。先显示仍有本页覆盖的项目，不把“已应用”理解为全部视觉一致。首阶段未接入页不可应用。
7. “更新共享模板/提升本页差异”在B05管理闭环开放：列出跟随页面及仍被覆盖项目，仅清除当前页明确合入的精确属性；其他页覆盖保留。2D/3D同页的模式范围与应用到哪些页面是两个选择。
8. 取消有修改时确认放弃；无修改直接返回。保存失败/修订冲突留在草稿，训练继续暂停；提供重试、重新载入或另存。确认放弃后恢复原布局。退后台不退出编辑，不计时；进程终止丢弃未保存草稿，业务恢复沿用原合同。

独立2D/3D答题页到B09/B10才接入；共用模板属性可显式应用于两页，本页覆盖永远按独立page ID隔离，不新增“双页身份”中间层。

## 6. 原生测量与验收

原生原图、AX树与实测JSON见 [图册](../../output/table-control-layout-20261017/B00/r01/review.html)；逐页尺寸见 [区域测量表](../../output/table-control-layout-20261017/B00/r01/region-measurements.md)。常态/展开/临时俯视矩阵已收齐108张，实际击球忙碌样本另补3张，总计111张原图。仅有构建或源码推导不算本节通过；不得把概念流程当已经实现的编辑器。

采集已核实的交互差异：Silu无解时打点按钮禁用，通过“更多→打点盘透明度→完成”可按当前实现展示大盘；样本使用此路径，不解除禁用。Silu顶部更多的AX外框有约0.25pt的边缘扩展，标准tap和isHittable读取均可触发XCTest错误；实测frame中心点击可成功。手机补测采用中心点击且不再读取isHittable，保留原失败证据，不把缺少这项属性解释为不可见或不可用。


### 6.1 已收齐的矩阵

| 设备 | Runtime | 实际窗口/页面 pt | 三页覆盖 | 证据与执行状态 |
|---|---|---|---|---|
| iPhone 16 Pro | iOS26.3 | 874×402 / 874×382 | 每页9态，共27图 | phone-standard-r3完成每日/自由18态，测试在Silu AX属性读取时失败；phone-standard-silu独立9态补测exit0 |
| iPhone SE3 | iOS26.3 | 667×375 / 667×375 | 每页9态，共27图 | phone-small-r2完成每日/自由18态，测试在Silu AX属性读取时失败；phone-small-silu独立9态补测exit0 |
| iPad Pro11 M4 横屏 | iOS26.3 | 1210×834 / 1210×782，页面Y=32 | 每页9态，共27图 | ipad-r2/landscape，整轮exit0 |
| 同一iPad竖屏 | iOS26.3 | 834×1210 / 834×1158，页面Y=32 | 每页9态，共27图 | ipad-r2/portrait，整轮exit0 |

每页9态 = 2D/3D各常态、更多、透明度、大盘共8态 + 3D临时俯视1态。每个有效条目都具备PNG、原始AX及JSON，图册只收最终有效集，不混入首次空间不足的半写文件。手机容器测试整体失败不冒称通过，其前两页的采集检查点和后续独立补测分别保留。24组常态尺寸数据来自真实窗口和控件框；Silu仪表外框从AX中的solver.power补取，非代码假定。Foundation组高在FreePlay由探针给出，在Silu按同版本Foundation实测窗口代入求得，不能当作普通左工具组的占用高度。

已审阅各设备全态联系图并检查代表原图：三页球桌与左右列存在、普通/无解禁用状态一致、展开面板有关闭路径、方向尺和杆速条基线分别120/144。3D渲染覆盖窗口，侧列仍取固定默认参考；当前相机槽位会覆盖桌缘，故只能保留明确例外。该审阅不是逐像素全库回归或用户视觉认可。手机Silu.more的AX激活点异常保留为B05辅助功能复验项，不能通过删掉真实业务按钮规避。

### 6.2 同期代码漂移

`workspace-drift.json`记录采集期间工作区相对冻结源码发生变化的文件。已复核FreePlay差异主要是自定义球形工具、选择和3D摆球分支，三试点的Foundation/区域默认计算未改；MainTab新增DEBUG路由辅助。渲染与灯光也有同期变更，因此本包是**冻结版本基线**，不是后来所有工作区变化的视觉验收。B01从实时工作区实现，不把冻结副本覆盖回仓库；B02做默认对拍前再核对当前渲染版本并建立同版本对照。

## 7. 工具故障记录

首次隔离工程生成把外部测试路径交给XcodeGen，路径相对化耗时异常；已采样并终止本任务进程，改用冻结目录内相对测试路径。首次build-for-testing因扩展Info.plist按工程根解析失败（exit65）；工程移入冻结源码根，随后重建。两项均是本批证据工具配置问题，不修改App规避，也不登记为App功能缺陷。

工具补充：主菜单无子菜单关闭按钮，首次脚本等待错误ID失败；已修正。标准机Silu.more的自动命中定位失败，改为现有测试采用的中心坐标点击。Silu无解状态不能从禁用打点键打开大盘，改走真实透明度菜单。失败时Xcode同时导出两份约2.5GB的宿主CoreSimulator日志导致磁盘耗尽，小屏JSON写入中断；结果归档后释放了大部分暂存，另仅清理本任务已完成构建的Intermediates/ModuleCache（约1GB），保留源码、Products、原图和xcresult。补跑使用`-collect-test-diagnostics never`，保留正常测试日志、断言、原图与结果，不再复制宿主全量诊断。

计时核对补充：StatisticsViewModel 按kind排除tool训练量并单列工具分钟；HistoryViewModel会逐条展示tool记录。因此工具编辑暂停需内存累计有效秒数，不能套用每次flush就新建记录的后台回调。该累计不新增持久化模型或改变既有后台分段合同。Silu.stopForDismissal会清场景动作、隐藏球杆、取消求解代次并恢复中断击球前状态，明确不作为布局编辑入口。

## 8. B00验收与交接

| B00完成标准 | 本批证据 | 结论 |
|---|---|---|
| 18入口/排除项与控件能力 | §1.1、§3；22个页面身份中18在范围、2嵌入、2新增独立需求 | 完成源码核对；不声称18页均跑过UI |
| 可实施区域与容量、相机例外 | §2及12行区域测量表、24组2D/3D常态JSON | 完成；相机镜像和非默认档位仍按计划由B02实装验证后开放 |
| 三页四窗口基线、流程和忙碌态 | §5、§6；108图+busy目录3图 | 完成；流程是设计合同，未实现编辑器 |
| 退出/前后台/计时及旁路保护 | §4；FreePlay、TeachingHost、Silu、DailyController、ToolUsageTracker与统计消费者 | 完成接入合同；实际编辑暂停回归属于B03/B04/B06 |
| 模式/页面范围、原子清理、取消与证据身份 | §5；source-fingerprint、runtime-build、各测试日志与设备状态 | 完成；B01进入存储事务实现 |

`testBusySamples`在iPhone16Pro通过（exit0、3张）：每日与自由的实际击球启动、Silu通过现有开球菜单进入开球运杆；逐页断言主动作由可用变为禁用，截图和JSON保留禁用状态。它是忙碌态代表采样，不覆盖求解中全部阶段、击球结果规则、恢复耗时或真机性能。画面中FPS不是本需求性能验收结果。

验证：隔离Debug build-for-testing通过；iPad横竖两个完整测试、两手机Silu补测、三页busy测试通过。手机每日/自由36图来自各自容器测试的已完成检查点，后续AX读取失败单列，不把整个用例改记为通过。111个图像条目、24组常态测量及配套文件检查通过；原图与概念流程明确区分。文档链接、围栏、定向空白和verify-doc-size检查通过。未进行Release门禁、真机、VoiceOver人工操作或用户视觉验收；这些不计入B00完成声明。

修改范围：方案、PROGRESS对应索引、本合同及独立output采集脚本/证据。正式App布局代码未改。本次独立包安装在显式借用的模拟器中，原bundle安装和数据保留；显示设置恢复、设备关机和租约释放见各device.log/result.json，原保护标记保留。未提交或发布。

下一批 **B01**：从实时工作区实现最小模板/绑定/属性覆盖归档、本页保存、另存及原子覆盖清理、修订检查和失败恢复。先读方案B01卡及本合同，核对workspace-drift，不复制冻结源码回仓库。B02才接入真实排布，B03才完成每日页面编辑闭环。
