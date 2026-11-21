# v66返工执行记录

2026-11-17用户确认“好的，开始吧”；实施中明确本页只需3D。当前需求真源：[v66.7](../../问题集合_v66.md)。

## R0进行中

- 独立worktree：`/Users/song/projects/13.billiard_trainer-v66-rework`，分支`codex/v66-free-practice-rework`，基于`5a21b7fde`。主工作区的AngleSceneView/CameraRig/DailyAdaptivePanelUITests为其他任务未提交改动，不纳入本轮旧基线、不覆盖；最终合入须重核。
- 基线诊断提交`ebb1c336`只加测试，不改App：5类球形×3轮，求解/采样/编码计时及插值连续性诊断。未运行前不作性能结论。
- Mac mini当前有camera-v67作业，由共同FIFO队列排队，不并发绕过。Xcode26.2、iOS17/26.2、可用空间109GiB只读确认。
- R1–R6未开始。工程/自动化/原生UI/真机/用户认可分别验收。

### R0 修复前冻结（2026-11-17）

- 首轮：`v66-rework-r0-baseline-1`，快照 `6661fed02c74dcc359c441d2c8e08e0f7d19a6b6c5c633c7302fcf3a817de710`，SE3 / iOS26.2 / Xcode26.2。5类三球输入各3轮，分别输出 solve / freeze / encode，第一轮单列首次样本，其余为暖态小样本；不能据此认定进程与全部资源完全冷启动；3次不足以稳定估计P95，最终重复测量另列，不将本轮均值代替P95。
- 边界补充提交 `ac18a36b`：微跳、贴库、袋角、地面、离域、固定seed66的16球开球各3轮。外部状态直接进入引擎，避免正式击球API将母球放到台面，导致测试标签与真实输入不符。尚未执行。
- 连续性修复前预算：无接触自由飞行对独立重力解析值位置误差≤0.1mm；240Hz呈现插值重力弦误差理论约0.0213mm，含Float坐标误差验收≤0.1mm。接触位置突变/所有权交回以0.1mm为诊断上界，真实速度冲量不平滑。帧时间单独输出P50/P95/max和相邻时间差，不以平均FPS替代位置连续性；真机手感仍待设备实测。
- V01静态调用审计：Features中显式`.spatialPractice`生产入口仅SpatialPracticeViewModel；ShotPredictor与BreakSimulator默认`.appDefault`；EventDrivenEngine.appDefault仍`.planarReference`。Bank/Kick/ThreeBall/TwoBall/Accuracy/AtlasSpinTrack/ReflectionSolver/BankShot/DiamondSystem消费默认，Defense显式`.planarReference`。这是源码范围证据，运行隔离及全部消费者回归未通过前不关闭V01–V09。
- 首轮已于北京时间16:30进入执行，测试构建通过后继续运行；没有操作、终止或恢复其他任务设备。

- `61c44644`新增仅`-masseJump.probe`启用的正常/1⁄4回放动作时钟、模型与presentation位置诊断；发布构建无此分支。动作求值节奏与GPU实际呈现帧率明确分开。参考正式P01真实导航/2D–3D基线随补充作业采集。
- 为避免重复全量构建，尚未执行的`v66-rework-r0-boundary-1`已取消，边界/开球与运动探针将合并到同一最新冻结快照执行。取消不记作测试失败或通过。
- 核心源码SHA-256冻结：`output/v66-rework/r0-source.json`；对应提交`61c44644`，相较原App仅多了显式DEBUG诊断，没有修复物理/播放或更换页面布局。

- `v66-rework-r0-motion-1`同样在执行前取消；替代作业`v66-rework-r0-combined-1`使用`61c44644`快照，一次构建运行边界18样本、正常/慢放运动数据与正式P01真实入口截图。结果尚未出齐，R0未关闭。

### R0 第一组结果与定位

`v66-rework-r0-baseline-1`：23/23通过，无跳过（1个测量用例、15个空间用例、6个旧评分一致性用例、1个完整原生UI流程）。源`ebb1c336`；证据`output/v66-rework/r0-baseline-1`，附件`output/v66-rework/r0-attachments`。诊断用例通过表示数据完整，不表示连续性达标。

|场景|solve首次 / 暖态两次 ms|freeze暖态 ms|encode暖态 ms|最大插值差 mm|
|---|---|---|---|---|
|50°跳球|256.578 / 7.885 / 7.869|1.562 / 1.585|21.653 / 23.587|13.594|
|70°左扎|13.222 / 11.861 / 11.817|1.434 / 1.449|19.138 / 18.855|10.091|
|70°右扎|11.867 / 11.855 / 11.860|1.428 / 1.432|18.893 / 18.990|10.091|
|75°高跳|12.477 / 12.318 / 12.272|1.681 / 1.680|20.161 / 19.920|8.703|
|平杆|3.540 / 3.484 / 3.524|0.756 / 0.742|14.691 / 14.623|0.00748|

- 原始15行数据：附件`52A3406B-CBDB-45D3-AEC3-0CEB21DCB328.json`；汇总`output/v66-rework/r0-measurements.json`。当前样本不宣称P95，也不把模拟器计时等同真机。
- 四个空间场景异常均为落台后的水平停顿/跃移，Y稳定在球心床面高度。跳球0.412500–0.420833s位置不变，0.422127s前移27.188mm；高跳尾部亦有17.406mm跳变。并非已证实的垂直Float精度问题。
- 源码嫌疑明确：混合引擎`mirror`先标sliding，局部积分结束记帧后，交回时改成实际rolling但未发布新帧；Playback继续从旧sliding演进，而`evolveSliding`对零滑速直接返回原位，下一事件帧再追上。R1须以交回元数据及独立滚动解析断言确认，并限制修复在spatialPractice分支；不得仅视觉平滑。
- 普通杆暖态solve约8–12ms；freeze约1.5ms；整档编码约19–24ms。当前`updateInput→save`反复编码含历史路径的整档，优先消除这项成本；不先削减物理精度。旧120Hz折线与新240Hz采样的重复工作需拆开保留spin tail的语义后再优化。
- 已查看原生ready附件`986A4B7E-A3C0-483C-B6F8-7752751B1EDF.png`：仍为旧抬杆文字/方向下重打回放，无实时空间预览；截图仅冻结现状，不当作页面验收。

### 正式P01迁移合同的源码基线

参考为正式“分离角与走位”真实导航→PositionPlayComposerView→FreePlayView/PositionPlayViewModel，不取tryout或未合入v67候选。

|动作|正式P01现行行为|本页R3应核对|
|---|---|---|
|首次3D/视图往返|首进第三人称，已有透视保存恢复；2D不改物理|共享初始化与本页2D/3D布局隔离|
|第一/第三人称按钮|发布当前球/杆向观察上下文，丢弃旧透视快照，surfaceTravel普通0.5/开球1|抬杆不改杆向，不引入自动选袋|
|第三人称观察|保留手动观察；第一人称观察结束回最新杆向|不用独立“侧面”菜单代替规范手势|
|全桌观察|清旧透视并发布当前观察候选|允许运动中观察，权限与物理编辑分开|
|临时俯视|保留编辑，纯查看恢复原机位；实际改球后按当前意图恢复|当前canEdit整体禁编是已知差异；共享host当前结束只清标志，需本页显式策略|
|回放|begin保留现场，showShot显示原杆机位，finish恢复现场|当前只有begin/finish，缺原杆捕获/showShot|

源码基线仅说明调用合同；同窗原生正式P01截图及正常/慢放运动探针仍待combined作业，R0继续开放。

- `v66-rework-r0-combined-1`已在北京时间16:50进入构建，未修改运行中快照。首次结果的原始包另存`output/v66-rework/r0-baseline-pristine`并验证后完成远端complete；分析副本的xcresult数据库被本机xcresulttool打开后哈希改变，不用它绕过证据校验。原始包保留，远端仅清理本任务build/source。
- 本地库存只读核对：8台核心设备均Booted且有保留现场，额外临时名额亦在用；没有借用、覆盖或关机，继续通过远端队列运行。

### R0 边界原始日志（combined尚在运行）

- 18样本均产出诊断，microJump暖态3.240/3.117ms，pocketCorner3.027/2.856ms，externalGround4.871/4.850ms，domainExit0.049/0.050ms，rack16 1424.201/1422.383/1416.071ms；上述终态settled。首次microJump2308ms，含进程/模型首用成本，不与暖态混合。
- **nearRail三次真实失败**：`jointImpactIterationLimit`，14.160/0.431/0.363ms；诊断用例绿灯不代表这三杆成功。R1修复后必须实打及断言settled。
- 失败原始约束：同材质台呢法向(0,1,0)与(0,0.9999999999980623,-1.9686039990755764e-6)，速度(3.956153392791748,-4.71475935757421,2.9868127171539527e-7)。4096次后motion residual≈8.88e-16而force residual≈3.98e-7，提示冗余接触冲量分配未收敛。原1e-6法向合并界限没有覆盖这个网格接缝。
- 待R1验证的几何假设：法向差对应球面接触点差R·|Δn|≈5.63e-8m，小于当前碰撞空间容差1e-6m；应以空间分辨率/球半径推导同材质冗余接触合并条件，不能任意增加迭代次数/放宽残差或把失败回收成成功。旧模型仍保留零合并默认。

## R0冻结完成；R1进行中（2026-11-17）

- combined结果：构建成功，3个用例实际运行，2通过/1失败，无跳过。边界数据完整；本页原生完整流程及正常/1⁄4探针通过。正式P01用例因旧`shotSimulation.readout`不存在失败，当前真实路由是Composer宿主，显示开球按钮，不是旧isShotSimulation分支。保留失败，不修改产品去迎合旧选择器。源/构建/录像/层级原件在`output/v66-rework/r0-combined-pristine`；xcresult分析另用克隆副本。
- 已看正式P01原录像第17秒进场及20.8秒横屏2D帧（`r0-formal-p01-entry.png`/`r0-formal-p01-2d.png`）。后者视频保留竖向画布而内容横置，可核对正式开球、方向、重打回放和球库。相机模式迁移的源码表已冻结；本轮没有把失败用例当成3D全手势通过，R3/R6须补现行正式路由断言。
- 正常动作384行，回调间隔P50 16.664ms/P95 17.192ms/max20.486ms；慢放1531行，P50 16.666ms/P95 16.837ms/max18.038ms，模拟时间步长分别约16.667ms/4.167ms，无时间倒退/重复。该UI杆角度由slider调整，不与数值夹具50°混称同输入；没有复现完全静止后突移，保留数值夹具四场景的明确问题证据。动作内model/presentation同帧差为0，不能据此声称GPU呈现无延迟；显示提交时钟和真机手感仍待后续专项。
- 边界接触端点最大修正：rack16约2.149µm，其余完成样本约机器精度；在预先0.1mm预算内。贴库杆无有效局部区间，是首个床面接触即失败。
- R0完成的是“修复前源、输入、参考、已复现问题/未知项与误差预算冻结”，不是产品验收。R1–R6仍须各批实证；当前开始R1物理/播放连续性及实测成本，后续页面合同尚未实施。

### R1首轮候选

- 提交`5cea6f104846cd7517022d531a6e61a59d39d14b`，快照`baa013a892c34bc628d49e683504b3e9ba927ee3a94e61bdaea129a6ea69a64f`，作业`v66-rework-r1-continuity-1`。Swift语法检查与diff检查通过；完整构建/31项选择器结果待出。
- 仅空间分支在交回后记实际运动状态；同材质接触合并以1e-6m/球半径推导；独立buildPolylines参数默认true，本页false但保留spin-tail完成；精确静止样本压缩及冻结取消检查。
- 新测试：交回对独立滚动解、四夹具插值≤0.1mm、空中重力/接触连续性、贴库完整求解/不增能、略去旧线物理一致、静止球端点、旧9组并发/取消交错隔离；普通/扎杆/平杆/16球开球各21次计时。
- 本机直接抽取当前`PocketContactResponse`与空间扩展源码做独立数值诊断（非iOS集成验收）：旧阈值真实复现失败；新几何界限下结果与单一合并法向闭式冲量速度差1.4e-15，能量量纲因子从37.880降到13.180。证据`output/v66-rework/r1-contact-source-check.swift/.log`。完整贴库流程仍等iOS测试。
- R0 combined失败临时设备`BA1BDD9C-1AA8-4509-82BE-4094993F09E6`已核对归属/Shutdown/证据，按生命周期精确退役回收；对应远端build/source已清理。未操作其他设备。
- R1作业当前构建通过；已执行的重力解析、静止路径、交回连续性、贴库/能量、略去旧线一致性均通过。四夹具最大中点误差分别5.096/4.273/4.280/5.126µm（原为13.594/10.091/10.091/8.703mm），交回后滚动解析断言通过。性能/并发/原生完整结果尚未回传，R1未关闭。

### Q21实施中范围收敛

- 用户：“我们这里只需要3D模式就可以了吧”。按当前任务收敛本页，已归档v66.4并将真源升到v66.5。
- R3固定`3D`，不显示2D/3D切换，不消费历史2D布局/投影偏好；保留第一/第三人称、全桌观察、临时俯视摆球，退出恢复机位。轨迹保留瞄准线/双线/全部/关闭。
- 临时俯视不切页面模式，不新增2D布局；其他页和通用偏好不改。R1数值/物理基线与在跑作业继续有效，旧本页2D截图只作历史，不计新范围验收。

### R1验证完成；进入R2

- `v66-rework-r1-continuity-1`冻结源`5cea6f10`：完整构建通过，31/31通过、零跳过。包含16空间、6连续性、2诊断、6评分一致性及1原生正常/慢放流程。原件`output/v66-rework/r1-pristine`，分析使用独立克隆。
- 四夹具中点误差4–5µm；贴库完整求解、独立重力/滚动、接触不增能与旧9组并发/取消隔离通过。动作正常P95 16.965ms、慢放17.527ms，无时钟倒退/重复；只代表动作回调节奏，不替代GPU呈现或真机手感。
- 各21轮，首轮单列、20暖态：jump solve/freeze/encode P95=7.526/1.565/12.474ms；masse=11.585/1.486/7.426ms；planar=3.360/.761/8.880ms；rack16=939.099/143.155/411.541ms。静止压缩降低普通杆编码量；16球仍有约1.08s求解+整理及8.31MB整档，尚未达到开球体验目标。R4继续优化，R5分离历史持久化；不改冻结阈值、不把隐藏计算文字当优化。
- R1关闭范围是已定位连续性/接触修复及阶段性能证据，非整页/真机完成。R2开始同源预览、单链缓存取消、固定抬杆可达域；R3以后按v66.5仅3D。

### R2首轮与补充

- `6320d4a0`加入页面完整输入缓存、单链可取消预览、正式击球复用与固定角度CueStrikeAccess；旧自动角度仍nil默认。首轮作业`v66-rework-r2-preview-1`构建失败（音频timeline为MainActor，后台闭包不能直接调用），测试未运行。原始构建日志保留`output/v66-rework/r2-preview-1-pristine`，未删断言；已修正actor调用边界后重跑。
- `ebe932e6`第二轮（快照`7a5d878da3243eb1c02c24a302ae4f80501edc94f99d3fba2fbba7d23dfd8e13`）增加真实XYZ批量管线、共同线宽/虚线及0.05mm呈现简化预算。物理记录/播放不降采样；同刻接触组按图连通处理。排队验证中，不提前宣称完成。
- 继续自审补充：改球退出历史、停稳后旧缓存不作新盘面预览、owner换代拒绝；需要随最后源码再验，不能拿第二轮结果覆盖后续改动。

- R2第二轮源`ebe932e6`完整构建通过，33/33通过（32单元、1原生）；原件`output/v66-rework/r2-preview-2-pristine`，分析克隆独立。已查看ready及侧向原图：空间跳跃弧线真实可见、后段和被带动球沿共同虚线；沿杆机位本身遮叠，R3仍须各视角原生复核。正常动作384行，回调P95 16.831ms，无重复/倒退。
- 第三轮尚未执行即取消（只更新了owner/菜单，随后发现stop→refresh→suspend会遗留预览，需完整取消守卫）；取消证据`output/v66-rework/r2-preview-3-cancelled`，不计通过。
- 最终候选`ec23edb8`快照`fd8d2fe50312382350eb03f2daa9c5c1086850bfb84009448709eb644e297af4`作业`v66-rework-r2-preview-4`加入离页取消、改球/owner代次和四档原生菜单验证，等待结果，R2未关闭。

- `r2-preview-4`完整构建通过，xcresult **实际35/35通过、零跳过**（33单元+2原生）；四档真实更新、选档不关闭及同一预测ID通过，已查看原始选档图。**整轮作业仍failed**：误写`DefensePracticeTests/testProductionPipeAttackFindsSubGridRoute`，方法实际属于`DefensePhysicalScoringTests`，生命周期门控正确拒绝缺失选择器。没有把该防守项算通过。
- 正确选择器在同一`ec23edb8`快照作业`v66-rework-r2-defense-1`单独补跑；R2待这一项证据齐全。原件`output/v66-rework/r2-preview-4-pristine`。失败设备`92990D99-F52D-4748-B5F1-781BC340ABE7`核对本任务、Shutdown、无租约、证据回传后精确退役回收；其他设备未动。

### R3/R4只读接线预检（尚未实施）

- `BTTeachingTablePage.fixedView3D=true`已有入口可用；本页fields移除view3D即可保留旧值而不消费，布局host随实际3D只读threeD。旧原生测试的视图切换/抬杆sheet/侧面菜单应按Q21和新滚轮合同更新，不改旧页面测试去迎合新页。
- 共享菜单已有breakGame，但无通用上一杆子页；考虑默认nil的单独secondary menu，原消费者不传维持原行为。详情复用supplementalDetail/BTScoreDetailsOverlay。
- 临时俯视恢复需TeachingCameraHost协议显式钩子及默认空实现；不能在VM里同名shadow扩展方法。摆球canEdit与四输入/击球canTune需分开。原正式P01纯查看还原，编辑后按当前意图更新，不能每次都强置第三人称。
- 默认球库仅15目标球，没有母球按钮；移除示例后空桌须补合法母球恢复入口，不能留下“从球库放母球”但库内无母球。
- R4需实测共享开球中杆/平杆默认与固定角度可达域的一致性：真实球杆0°可能受身后库边限制，禁止悄悄自动换角度或只画自动抬杆但物理仍0°。待实际球架证据再决定，不先预设修法。

### R2阶段验证完成；R3开始

- 同源`ec23edb8`防守补验`v66-rework-r2-defense-1`完整构建与正确选择器1/1通过，补齐上一轮实际35/35；原failed门控不改写。源和快照未变，合计36项实际执行通过，无跳过。补验原件`output/v66-rework/r2-defense-pristine`。
- R2覆盖同源空间路径/三档及关闭/原地选档/缓存实打复用/旧意图取消/改球及owner失效/离页无迟到交付；固定角度球面接触、灰区谓词及旧自动角度、走位/两球/防守消费者定向回归通过。真实四输入手势、大盘、跨尺寸、完整生命周期与各观察位继续R3/R5/R6，不把本轮SE样本当整页通过。
- R3按v66.5仅3D，修改SpatialPracticeView/VM、共享shell默认nil子菜单钩子、TeachingCameraHost默认空恢复钩子及本页偏好/布局目录。R4正式开球、R5回收/持久化继续各自批次。

### R3 首轮实现与待验证

- 实施worktree提交 `d911535b`；快照 `550b71cd41a3e50f317ca58031e7f819b402852191385a3424dcdee1a168be50`，作业 `v66-rework-r3-page-1`。仅3D通过共享fixedView3D，页字段不消费/覆写历史view3D；其他页默认不变。
- 抬杆复用BTAimWheel独立44pt触区/短窄外观与布局ID，连续0–85°，放方向右侧；重打回放保持标准槽。左上同款开球外观先接布局，R4再启用实际空间开球。
- 共享shell新增默认nil二级菜单；上一杆路线/详情/速度收拢，详情用共同浮层与首次落台环。清空有确认，空桌主动作可放回母球；恢复仅本页普通输入与显示。
- 移除计算提示、示例/侧面/手动取回主菜单。临时俯视允许添移球但禁止调参/击球，退出仅实际改动才按新意图更新。回放补原杆机位捕获/showShot，恢复草稿球杆后再恢复现场机位；持久化原机位继续R5。
- 首轮新增单元与原生测试覆盖旧view偏好隔离、临时俯视编辑权限、滚轮手势、相机入口及原地菜单选档；结果待实际构建/执行，尚不声明通过。

- R3第二验证源`63e2e179`，快照`4dbd2864197282e43ae71b1275d535a457aa7febbeb1d4f4344abe9a2aec286d`：增加85°各观察位、回放前后实际机位比对、清空/取消/恢复/母球返回、独立布局取消及实际触区。标准手机作业`v66-rework-r3-standard-1`待执行；其中开球默认固定角可达性诊断只取证，不改变R4默认语义。

### 后续设计预检（提案，不是已实施）

- R4可用本页适配器持有BreakFlowRunner，仅复用rackUp/selectGame/drag/nudge/savedInput等摆架/输入职责；不调用旧breakNow。空间求解/缓存/播放继续本页唯一链，runner.showsAimAssist=false，显式输入/原杆类型另存。
- 开球普通输入应分离：草稿含玩法/seed/原普通输入/手调向标记；Shot保留开球元数据。成功交付恢复普通输入、取消恢复待开球稳定快照、重打恢复开球上下文。10m/s仅开球输入有效，不放宽普通0.1–8。开球期间仅开球区母球可拖。
- R5需把draft与大历史分开保存，避免每次转轮重复编码8MB路径；同时实现三快照、实际回收/幂等、owner及同页实例隔离、退出无迟到写入。普通档迁移和原杆机位用现有CameraRig.TrainingBookmark能力评估。

- R3首轮`d911535b`完整构建通过；临时俯视单元失败：夹具未提供viewport，CameraRig按实际保护拒绝构造俯视投影，后续权限断言连带失败。原生已实际进入俯视/添球/观察并继续击球，尚待最终结果。按既有CameraSurfaceTests夹具补真实viewport后再验，不放宽生产guard。`r3-standard-1`在执行前取消，保留取消记录，避免重复消费旧夹具。
- 后续候选另补本页实际renderer正投影探针，用原生手势拖母球并核世界坐标；补纯观察机位往返及中止新杆不覆盖上一杆机位。

- R3首轮终态：27项中26通过、1失败（同一viewport夹具内4条连带断言）；完整构建通过，16项空间/旧平面隔离全通过，2项原生UI均通过。新滚轮真实拖动、固定3D无视图入口、临时俯视添球、第一/第三人称/全局、实打/慢放/重打/返回及轨迹原地选档已在SE/iOS26.2执行。仍须看原图，不能以通过代替视觉验收。
- 当前修订源`f52b12e7`，快照`57f4027a8b3bbb4a6457c762196bea52616767fdb033f3f65420a04d21432b54`；标准机`v66-rework-r3-standard-2`与iPad`v66-rework-r3-ipad-1`排队验证。标准第一任务`r3-standard-1`执行前取消且已回传关闭。
- R5需核回放中临时切人称的aim必须来自活动原杆，不能误读回放前草稿输入；当前R3正常回放已补capture/show/finish与新杆停止保留旧快照，持久化及活动输入随R5统一收口。

- 已看首轮原图：`CE528B90...png`准备、`A87CEC3D...png`俯视、`B1AFC2AB...png`第一人称、`B564AA78...png`全局。抬杆两行文字使HStack高于共享方向尺，SE回放底部裁切；功能可点不等于可交付。将抬杆有效轨道缩至`min(110,rulerLength-36)`，保留44pt触宽、字号/球桌/方向与杆速不变，增加窗口完整可见断言。
- 修订源`b713d662`，快照`f8d9869741269447050e18508dd73924427cbfb7b7cd86028f7ce112dd0a2c5e`；最低iOS17 SE任务`v66-rework-r3-floor-1`及iPad任务`v66-rework-r3-ipad-2`待验。`r3-standard-2`仍验证f52源（仅不含本次轨道缩短/完整可见断言），最终源码验收须明确差异。`r3-ipad-1`执行前取消已回传关闭。首轮失败SE设备仅按本任务UDID、Shutdown/无租约/证据条件退役回收，首轮job已complete关闭，原件未改。

- `r3-standard-2`完整构建成功，但生命周期入口返回同型号容量上限（17Pro现有保留设备）；测试未启动，不能计通过。只读盘点Mac mini现有4台、无租约，其中17Pro既有保留/历史设备不属本任务；不清理这些设备。改用已核可用deviceType的iPhone16Pro标准覆盖角色，作业`v66-rework-r3-standard-3`消费b713源。最低系统SE/iPad队列不受该型号限制。

### R4/R5后续接线风险补记（未实施）

- BreakFlowRunner.rackUp/cancel会调用全局ShotAudioScheduler.shared.cancel；本页复用摆架时需显式默认保持旧行为、仅本页关闭runner管理共享音频（本页已有独立音频链），不能无意取消其他实例音效。共有开球区clamp可给适配器复用，仍由本页空间求解执行。
- R5不要把大型history继续放进每次input编码；可用独立immutable UUID历史文件先原子写完再提交小draft引用，写入完成须核owner+实例writer lease；小草稿允许记住当前球形，历史写失败保留旧已提交引用并可重试。需实际失败注入与跨实例/owner晚到验证，不能仅增加字段便宣称原子性。
- main相对基线HEAD目前无新增commit；本分支18个改动文件与主树v67脏CameraRig/AngleSceneView不重叠。此次只读diff的相机改动仅新增诊断字段（19/16行），不作为最终合并证明；R6再查漂移与最终版本。

- R3原生拖动测试复核TP18时发现测试末触点未计共享`BTBallDragMetrics.fingerClearance=52pt`。补充探针将实际renderer目标投影换成带同一常量偏移的手指终点，仍断言真实母球世界坐标抵达目标，不放宽距离断言。源`f5f5b778`/快照`073a681061b86df74194e00fac234a6412aa417ee1f22d87099d35628928dfef`；标准16Pro作业`v66-rework-r3-standard-4`待验，同时补齐方向/杆速/大盘打点的原生输入。旧b713的floor-1已运行，保留实际结果；尚未运行的ipad-2/standard-3取消并按新源再排，不把取消计测试。

- `r3-floor-1`源b713完整构建通过，3项原生1通过/2失败。首项在UIKit横屏事件20.58s后0.27s断言retry.maxY=379.351 >375；原图仍750×1334。不能据此认定稳定横屏布局合格或失败。第三项使用已移除的freeLayout.customize测试入口，未执行真实布局编辑；轨迹原地选档通过。原件`output/v66-rework/r3-floor-1-pristine`保留，失败设备0B7F1CDC仅核本任务/Shutdown后精确退役回收。
- 修订源`effa66a6`只改测试：等待窗口和五控件原生frame连续1秒稳定（仍从竖屏真实导航进入、没有强行切设备横屏），随后原完整可见断言不变并附frame JSON；布局助手改当前直接点选/拖动/缩放入口。快照`fc353ec5f1f361fecd17ea2ce491c3c467dcbea7453f0253a6fc8842ce86e5e8`作业`v66-rework-r3-floor-2`，10单元+3原生待验。`r3-standard-4`执行前取消并已关闭，不计测试。R3仍未通过，R4/R5未开工。

- `r3-floor-2`完整构建通过，13项实际12通过/1失败。10单元全通过；完整击球/慢放/机位恢复、轨迹四档原地切换通过。稳定原生frame证明方向[12,135,44,120]、抬杆[64,146,44,84]、重打[12,283,44,44]、回放[12,331,44,44]均在667×375窗口内；此前379.351越界为旋转中间态。当前底部贴边，未将其扩写为全部尺寸合格。
- 原生末项的打点阈值失败不是可达域证据：合成事件归档显示“关闭打点”.tap落在原生坐标(149,333.5)，正是大盘球心，重置了先前真实选点；修改为先核选点，再点遮罩外缘，核大盘确实消失和选点保留。布局直接移动/缩放/取消、清空/恢复/四输入其余步骤已实际执行，整项失败仍保留。
- 已看最低系统ready及85°第一人称原图，后者真实出现杆身近轴放大遮挡。因此候选`fd869753`给CameraRig新增默认false、仅本页启用的第一人称杆轴视线间距：沿既有垂直13cm眼距补正交侧偏13cm·sin(抬杆)，到轴的垂距恒13cm，不改物理抬杆、不改旧页默认、不采纳v67相机候选。新增独立几何/旧默认一致单元，原生截图仍待验。源快照`6d142864568756b75c65eca974a9da936a7d8a2c128576a03e92b0615b5a76d6`，标准16Pro作业`v66-rework-r3-standard-5`。本分支现在触及CameraRig的小型显式策略，最终合并须保留main并行诊断改动。
- R4只读诊断补齐：五玩法seed66，0°中杆均受库边约束，首个0.1°扫描可行点均1.7°；共享CueStick.minElevationRadians=0.05（约2.865°），可作为正式共享“平杆”工程默认的真实抬角，不应显示0°却用另一角度。R4尚未实施。

- 同`fd869753`冻结源追加iPad Pro 11 M4/iOS26.2作业`v66-rework-r3-ipad-3`（本页3原生+CameraSurfaceTests旧相机）及SE/iOS17补验`v66-rework-r3-floor-3`（本页3原生）；串行队列，标准机另含旧TableMenuRetentionUITests。floor-2临时设备4C4DC16A核本任务Shutdown后精确退役，complete已回收该旧build/source，保留失败原件和克隆分析。

- 标准机`r3-standard-5`本页11单元（含第一人称轴距/旧默认）与完整击球/四分之一速回放/轨迹UI已通过；布局项在43.999999999999986≥44原生CGRect比较失败，尚未进入大盘补验。候选`b31dedb5`仅该断言增加1e-6pt浮点容差，实际44pt合同不变；补验`r3-standard-6`只跑该失败项，快照`dc8b1430f5cf36b957e9e87bec62d7d641df7dc9f4c7af2710d6fb2d13e449a9`。iPad-3尝试取消时已running，入口正确拒绝终止；保留运行，floor-3继续同fd869生产源（仅少该测试容差），按各自实际结果记录，不改冻结快照。

### Q22实施中角度范围收敛

- 用户认为85°过大、60°已足够大，按本页产品范围采用0–60°，初始/重置45°。真源升v66.6，v66.5原文归档。限制当前草稿及新杆，不改写历史原杆输入/路径/回放，不缩通用物理数值夹具。
- 对应85°的本页第一人称侧偏候选撤回，先复用统一相机按60°原图验收；worktree恢复本轮新增策略之前版本，不触碰main并行v67文件。若60°仍有真实遮挡，再按本页例外诊断，不能凭85°问题继续扩大相机改动。
- 尚未执行的`r3-floor-3`与`r3-standard-6`已取消；iPad-3已running，保留其旧范围实际证据但不冒充60°最终验收。此前小屏及标准结果按各自源码/范围保留。

- Q22最新覆盖：用户“或者还是75吧”，当前范围改为0–75°、初始/重置45°；v66.7替代v66.6。60°候选5b47fbdd/437d8e7c仅作中间历史，后续以75°源验证；历史85°原杆仍保持原始回放。

- R3旧范围iPad作业`v66-rework-r3-ipad-3`（fd869753）完整构建通过，实际38项34通过/4失败：CameraSurfaceTests 35项中32通过，3项在临时俯视选袋后期待travel=0.5、实际保留观察姿态（1/nil）；本页3项原生中完整击球/回放和轨迹菜单2项通过，布局/空桌项失败在iPad确认popover无“取消”按钮。未将旧页失败认定为本轮回归，已提交R0基线相同3选择器对照。原件`output/v66-rework/r3-ipad-3-pristine`，克隆分析和附件另存；精确退役本任务失败设备928FB6D6后complete。已看横竖默认原图，竖屏上部天花板占比较大，仍须按当前75°源复核，不以UI通过代替视觉通过。
- 当前75°源`4643c79f`/快照`ed8173103b6a8fc96dd31916d51aaba0c4bb8c2563d7bebe259d53a472c04c37`；新标准/紧凑/iPad原生作业分别`r3-angle75-standard`、`r3-angle75-floor`、`r3-angle75-ipad`（均带v66-rework前缀）。代码初始/重置45°、草稿/重打限75°、历史85°输入/路径完整保留；本地Swift语法解析和diff检查通过，设备结果待验。
- 60°作业`v66-rework-r3-angle60-standard`已在执行前取消；不计测试。旧floor-3、standard-6同为执行前取消，回传并关闭。

- `r3-angle75-standard`完整构建成功，实际31项30通过/1失败：27单元（含75°草稿/重打限幅与85°历史原杆保持）、本页完整击球/回放及轨迹2UI、旧菜单1UI全部通过；末项清空后立即读探针仍为4而期待0。录像35.5s确认框正在收起，36.0s桌面已全空、主动作已为“放回母球”，证明界面状态消费时序，非清空未执行。测试修订等待探针0和主按钮同步后保留原断言；母球返回同样等待1/击球。源54b782d4仅测试变动，生产仍与4643c79f完全一致。补验`v66-rework-r3-angle75-standard-z`。
- 已审75°标准手机第一人称原图`E5A185FE-9441-4AB9-86EE-E1BE4D553955.png`：杆身有近大远小透视，母球及打点可见，无85°候选的侧偏策略；当前CameraRig相对基线无diff。原件`r3-angle75-standard-pristine`及克隆/附件/录像分开保存。原失败不改写为通过。

- `r3-angle75-ipad`完整构建通过，3UI实际2通过/1失败：完整流程129.221s、四档轨迹36.170s通过；空桌项在相同立即读探针断言失败。原件与克隆分开，补验`r3-angle75-ipad-z`使用54b782d4状态屏障。失败设备96B8A80E核本任务/Shutdown后退役，complete已关闭。75°第一人称原图6839EC39含EXIF orientation=8；原始像素1668×2420不能据此认定竖屏，界面日志明确Landscape Right，CoreImage按元数据生成分析副本`r3-angle75-ipad-first-oriented.png`为2420×1668，原件未动。默认45°竖屏A4934DB7与横屏/高抬杆原图已审，母球可见；高角度竖屏仍须最终矩阵，不把横屏照片冒充竖屏证据。
- 小屏旧`r3-angle75-floor`在执行前取消并回传关闭，以`r3-angle75-floor-2`（54b782d4，仅测试状态屏障变化）替代；完整3UI待执行。标准与iPad各补Z项，R3依然待闭环，R4/R5生产未开工。

- 旧相机对照 `v66-rework-r3-camera-baseline` 已完成：R0源 `ebb1c336`、快照 `6661fed02c74dcc359c441d2c8e08e0f7d19a6b6c5c633c7302fcf3a817de710` 完整构建通过，3选择器全部在同一断言原样失败（Angle 1.0≠0.5，Cushion/Separation nil≠0.5）。因此这三项是基线已有失败，不记为本页新增相机回归，也不记通过。原件 `output/v66-rework/r3-camera-baseline-pristine`；本任务设备85315B9D已核Shutdown/无占用后精确退役回收。

- 当前75°生产源的默认45°实际击球/回放动作探针分析：标准机正常553行、1/4慢放2208行；iPad同为553/2208行。四组shotTime倒退=0、重复=0、先静止再移动诊断片段=0。wall回调P95分别16.865/16.897ms（标准正常/慢放）、17.256/17.191ms（iPad）；这是SCNAction回调，不是GPU呈现或真机手感证明。各原始JSON保留在attachments，汇总 `output/v66-rework/r3-angle75-motion-analysis.json`。

- `v66-rework-r3-angle75-standard-z` 源54b782d4/快照3a76a091 完整构建通过，失败项补验实际1/1通过、0跳过。清空取消/确认、空桌放母球、恢复范围、四输入真实手势和独立布局移动缩放/取消均走完。补验与原失败分列，生产仍同4643c79f，合并覆盖标准机31个选择器均已有通过。原件 `output/v66-rework/r3-angle75-standard-z-pristine`；已审四输入原图975C606C及大盘2C206787，独立抬杆和原辅助槽可见，大盘选点关闭保留。成功设备由生命周期回收，fetch --complete已关闭作业。

- `v66-rework-r3-angle75-floor-2` 源54b782d4/快照3a76a091，SE3/iOS17.0完整构建通过；3项原生全部通过（完整流程118.954s、轨迹31.999s、空桌/输入/布局55.590s），0失败/跳过。原件 `output/v66-rework/r3-angle75-floor-2-pristine`，clone/attachments分开；已审ready 599F12CB、四输入37AACAFD与75°第一人称5A0B5CB1原图。底部回放贴近窗口边界但标签完整，实际命中通过；不把这扩为缩窗或全AX验证。fetch --complete收尾完成。

### R3闭环 / R4进入（2026-11-17）

- `v66-rework-r3-angle75-ipad-z` 同54b782d4/3a76a091完整构建及1/1原生通过（62.332s，0跳过）。标准31选择器（30+补1）、紧凑3UI、iPad3UI（2+补1）均有本轮通过；原始失败保留，三个旧CameraSurface失败已由R0对照确认为既有失败。R3的标准/紧凑/iPad初验完成，最终近库/角袋/竖屏75°/缩窗等完整矩阵仍归R6，不提前判通过。iPad补验原件 `output/v66-rework/r3-angle75-ipad-z-pristine`，fetch --complete关闭。
- R4范围：本页适配器复用BreakFlowRunner摆架/玩法/拖动，独立空间求解、开球与普通输入、停止/交付/重打/重进。共享默认和旧物理不变；自动出界回收与大历史存档改造仍按R5依赖处理。几何沿SceneKit X/Z水平、Y上、米；台呢0.8m、球半径0.028575m，共享开球区X≥2.540/4=0.635m，yaw=atan2(z,x)。

- R4候选 `3c0dbeb59347b80aa8c3c88bcbb72588a734d9b5`，快照 `5bcecfd0c6168d29ac7a5592bdfa34162bd9148676201eed6d0503425d39f070`：五玩法独立记忆、复用摆架和开球区拖动、空间执行8000事件预算、原普通输入恢复、停止/重打/重进已接。共享runner新参数默认保持旧行为。Swift语法解析/diff检查通过，完整构建与真实播放待作业 `v66-rework-r4-break-1`；不能计完成。iPad R3补验四输入原图E59D2A97已审，母球/独立滚轮/原辅助动作可见；竖屏上部空间仍较多，最终构图矩阵保留R6。

### R4主流程通过 / R5进入

- 源3c0dbeb5、快照5bcecfd0，`v66-rework-r4-break-1`完整构建及24/24通过（22单元、2原生，0跳过）。五玩法空间预测、真实16球播放21.114s、开球区/手调方向/种子记忆、参数恢复/重打/停止/重进通过；旧runner宿主7项、11项空间预览和9族并发逐值隔离通过；新页原生66.760s、旧正式Composer开球41.681s通过。原件`output/v66-rework/r4-break-1-pristine`，clone/附件另存；已审16球准备74A883B2和交付5BE3903D原图。fetch --complete已关闭并回收本任务临时资源。
- 追加小修b59828db（仅同玩法重复选中不重摆，带真实VM断言）快照22ab5aa1，`v66-rework-r4-break-2`另行排队复验，未将其计入上述24项。R4主流程完成标准已有3c0dbeb5证据，继续R5；追加修订及最终组合源仍必须通过。
- R5实施范围按v66.7 §4.3/3.4/5.1：三快照、自动回收、原杆机位/现场、v1迁移与独立历史写盘、owner/实例晚到守卫。几何沿世界X/Z水平、Y上、米；球心为台面+R，最近合法位置从共享袋口与放球净距构建。纯值40组独立设计对照见`output/v66-rework/r5-nearest-design-check.json`，不是App回收验收。当前锚点与失败验证设计见R5-PREPARATION.md。


### R5 首份候选（2026-11-17，尚未验收）

- `7c971ffc085d5d63dbb4c42993f48d7d5f55da0b` / snapshot `30b816e33c586bff13d35088607bf13c0da4c53acdbc7bea3a421ba339c598a6`，job `v66-rework-r5-recovery-1`。
- 三快照/确定性回收、静止球免逐帧动作、持久化回放机位、v2小草稿/后台不可变杆文件及writer守护已接候选。恢复位置用共享实际袋心，原始路径和85°历史保持；新输入上限75°不变。
- 本地Swift语法parse与diff检查通过，不等同类型检查或App构建。首轮选择回收、存档、空间物理、预览、开球及两条原生UI流程；还在补原生飞台/前后台测试与实际几何出图。
- 参考 [R5设计](R5-PREPARATION.md)、ADR-P5-05。构建/结果/失败待回填；R6性能目标与最终矩阵仍开放。


### R4补验关闭与R5第二份待验（2026-11-17）

- R4 `b59828db9a7f8e6906a245501fa37938acd6402c` / `22ab5aa12848c7eac2ca9fabe78480e7861f393b82d5601f38d624462f58aaa3`，job `v66-rework-r4-break-2` 完整构建及4/4通过、无skip：五玩法9.805s、当前玩法保留输入/重开seed0.544s、实际16球21.053s、原生交付/重打/停止/九球重进69.498s。原件 `output/v66-rework/r4-break-2-pristine` 验证成功；complete后source/build及无人引用snapshot已清理。R4完整关闭。
- 补看R4主轮九球重进 `4C992195-46C6-4906-B48F-B7A899F0DFA7.png` 与正式P01交付 `88AFDCEB-E81B-44D5-80EF-F5670653A8D8.png`：新页控件独立、球库和开球状态可读，旧P01未出现抬杆占位；全轨迹档开球路线密集是该档实际结果，不等同默认简洁度/全矩阵通过。
- R5原生补验改为 `aaebb6008217e4a003fe78ffc011202d0e446f4f` / `a5793db281bc9099d567e7f7579590b78444e1c5414a576661e10d99f13fa397`，job `v66-rework-r5-native-2` 排队。新增实际拖球飞台/自动回收/重进回放/后台，真实v1版本且原档逐字节保持断言、回收几何JSON、旧BoardMemory/SharedShotReplayCamera回归。
- 原 `v66-rework-r5-native-1` 在启动前取消，被native-2替代；无构建/设备/测试结果。取消记录及快照清理已回传 `output/v66-rework/r5-native-1-cancelled`，不能计测试通过。首轮recovery-1继续运行，不改运行中源。


### R5首轮失败定位（2026-11-17，保留失败）

- recovery-1构建通过，回收最近点/边袋避让、真实文件失败重试、旧实例/owner迟到拒绝、缺历史仍恢复草稿、全静止回放等均通过。新增实际飞台回放测试在“停止/自然结束后恢复当前机位”出现16个字段断言失败，原机位存储和回放起点通过。
- 根因假设已与入口源码核实：单测只调用setupScene，host.cameraMode默认为3D但scene.currentCameraMode仍是2D；正式BTTeachingTablePage在setup后另调用setCameraMode(3D)。ShotReplayCamera按scene实际模式捕获，错误夹具没有可恢复的3D现场。没有改变生产相机或放宽断言。
- `85bea62518be5c857d1556f49304a8b0f8d54a95` 补真实setCameraMode初始化，显式断言scene为3D、两个机位不同、恢复后下一帧仍保持；原全部姿态比较保留。snapshot `e6ea2d3ae7e3ee0a2fd12815310b45cea0eef24bc9fe339ac173a69914badef8` / job `v66-rework-r5-native-3` 排队复验。
- native-2启动前取消，改由native-3执行同组测试；取消记录保留 `output/v66-rework/r5-native-2-cancelled`，不计通过。recovery-1原生常规路径已通过117.177s，空间开球UI尚在跑；首轮整体失败必须保留，R5未关闭。

- recovery-1两条原生流程均通过（常规117.177s、空间开球64.215s），整轮仍为失败，唯一失败测试为上述场景模式初始化问题；完整计数以回传xcresult为准。R5生产相对于R4仅改本页五文件及新文件注册，六个关键旧消费者/默认物理文件逐字节不变，源码审计 `output/v66-rework/r5-source-isolation.json`；源码证据不替代native-3中旧页记忆/回放运行回归。


### R5跟杆时序复核与合并复验候选

- recovery-1原件核实38项、37通过/1失败/0跳过。失败仅上述相机单测初始化；原件 `output/v66-rework/r5-recovery-1-pristine`，分析克隆独立。对应临时设备6E251B6D-44C8-49CA-BB12-C293BE94B0DD已确认Shutdown且无占用，导出后精确retire+cleanup删除；队列complete清理source/build/snapshot。
- 源码复核另发现本轮play重构把回放用updateCueStick/hideCueStick无条件用于普通触球，违反CueStroke的跟杆时序合同，会取消后续动作。`8cbd0211d5e99c626f1c286ae51db1d9e7daaba1`将它限定到replay；普通杆继续使用runCueStroke冻结姿态与跟杆。实际飞台测试在球第一次挂运动动作时检查球杆可见且仍有跟杆动作，不能靠最终落点相等证明跟杆正确。
- 所有本页apply用disableActions明确无跨空间回收动画。原生新测试选1/4慢放后检查历史输入，给真实AX采样留时，不注入结束状态。
- 合并复验source `8cbd0211` / snapshot `853891179faccbcf84e25b46c6a8938de93290d0cec5500e921800ea05a30f9c` / job `v66-rework-r5-native-4`：首轮全部选择器、旧BoardMemory/SharedShotReplayCamera、原生飞台/重进/后台同轮再验。native-3启动前取消并保留取消账，不计测试。当前R5仍未关闭。
- R5首轮正常/1/4动作探针553/2208行，时间重复/回退均0，精确静止后再动片段0；P95回调间隔17.630/17.686ms。`output/v66-rework/r5-motion-analysis.json`采用nearest-rank，仅动作时钟而非GPU或真机证明。原图settled B8CA523B-4D66-413F-974E-98825FD01621.png已看：3D全局桌面/控件可见，当前下一杆空间弧线可见。


### R5组合复验及原生投影屏障（2026-11-17）

- `v66-rework-r5-native-4`（8cbd0211 / 85389117）完整构建成功，实际53项：52通过、1失败、0跳过。50项逻辑/场景全过（含真实飞台跟杆、持久化原机位/回放现场、v1原85°字节保留、写失败/最新实例/owner、旧BoardMemory 6与SharedShotReplayCamera 8）；常规原生120.026s及空间开球原生通过。
- 唯一失败在新增原生飞台用例260行：临时俯视按钮后立即读取的投影缺失，尚未执行拖球。失败录像31.2s仍见3D画面且俯视按钮选中；测试未等待实际renderer投影。`ff802e78784b0caecd4739bad9e3ab40c06c0821`仅增加实际临时俯视状态与有限屏幕坐标就绪屏障，无坐标回退、无删改后续拖球/回收/回放断言。是否足以修复由重跑判定，不据假设算通过。
- 修订快照 `77f7e014c2cef06f11b40331602479dac6923ec6fcce528dd80f0ccf3a96d071`，job `v66-rework-r5-native-5` 仅补该原生用例；生产同8cbd0211。共享FIFO序号544，排在v67三作业后，不绕过队列。
- 原件 `output/v66-rework/r5-native-4-pristine` SHA回传校验，分析使用clone与独立attachments。summary保留53项原失败；失败owned设备13B944A6确认Shutdown/无占用后精确退役删除，complete已回收该job源码/构建/快照。R5尚未关闭，R6仅有只读预检。
- 另已审首轮开球交付原图813F0A42：左上开球、方向右独立抬杆、重打回放原位，交付普通输入45°/3m/s；该图仅证明7c971ffc当时状态。
- 实际生产回收函数四组几何输出附件 `79CCF4F1-71E8-4F82-A272-52D5AFA93BEF.json`，用Matplotlib原值作图并已目视：密集邻球/中袋/两角袋均落在合法球心矩形内并避开球/袋排除圆；`output/v66-rework/r5-actual-recovery-geometry.png`与同目录plot_actual_recovery.py保留。不是独立近似模型替代App结果。

- R5坏档复核发现sorted校验的previous=-1会接受首帧-0.5s；生产3b7ae3cf明确sample.time>=0。新增实际文件篡改用例（负首帧）核拒绝历史、保留稳定球形/输入、原坏文件及草稿备份；语法parse/diff已过，完整测试待验。正常轨迹和旧85°原档均非负，不改变合法历史。
- native-5启动前取消关闭；最终补验改为3b7ae3cf0a95d4c1c367afe7d174239a5f7044c1 / e347acf9f1fdb97bac6e2c1b246368ac47d493996d0b1f260fd15a11b8be8b83 / v66-rework-r5-native-6：archive4项、SpatialPracticeTests16项、旧85°迁移1项及原生飞台1项。R5仍未关闭。


### R5临时俯视拖球崩溃（保留失败）

- native-6（3b7ae3cf / e347acf9）完整构建成功，实际22项21通过/1失败/0跳过。Archive4、Spatial16、旧85°迁移均通过；原生飞台流程通过实际投影屏障后，在临时俯视拖母球时App崩溃，尚未到击球/回收。原件`r5-native-6-pristine`、分析clone/summary、独立`r5-native-6-drag-crash.ips`保留。
- 崩溃EXC_BAD_ACCESS在SceneKit渲染线程的`renderResourceForMaterial`→`objc_opt_isKindOfClass`，寄存器明确正在检查NSData；主线程在拖球unproject。源码显示主场景MobileContactOcclusion每次球位变化替换TaiNi材质的contactUniforms NSData，而临时俯视共享同一SCNMaterial。共享动态参数跨renderer是当前根因假设，必须靠修订原生复验验证，不先判修复。
- a31efa50先隔离本页俯视材质；6ad34fd5进一步让副本维护独立阴影参数并随clone位置更新，避免只复制材质导致球影停留旧位置。新策略默认false，仅本页开启；旧页材质/初始化路径保持默认。加入材质身份/删除轨迹、实际台呢参数独立且拖球后更新两项测试。Swift parse/diff通过，App构建/运行待验。
- 原native-7在启动前取消，不计测试；修订6ad34fd5b7c35585f1040b687864492cb67db11a / cb9196eac61c6859632e85eb464ce3d1b85a4c4aaea3d9cfcd09fb3b5190b0d4提交native-8，选择18项SpatialPracticeTests和原生飞台全流程。R5未关闭，R6仍仅预检。

- 静态复核又补0e3be7a6：副本只更新contactUniforms，不重新安装基础surface shader；否则会覆盖已安装的台呢参考光照。断言增加shaderModifiers逐值相同。native-8尚未启动即取消关闭，改native-9（0e3be7a65743d0f669deed5ad523a0bc1652614b / c216eb447ce0fcbe0c5cc86f54f4a3271e929239c3cfc4d163363288db3e40fc），加入旧默认临时俯视共享身份、默认金标准光照和真实移动阴影测试。native-7/8均无运行结果，不计通过。
- native-6失败设备57F14AE6已核本任务/Shutdown/无占用后精确退役删除，原始xcresult与崩溃报告已回传；complete已清理其source/build/snapshot，失败身份保留。


### R5 native-9结果与存档诊断（2026-11-18）

- 0e3be7a6 / c216eb44完整构建成功；22项实际20通过/2失败/0跳过。旧默认俯视材质身份、默认台呢金标准和真实移动球影三项全过；本页材质隔离/删除节点通过。新增球影更新单测未推进源renderer帧，怀疑复制读取尚未更新的presentation，参数不变断言失败（未先认定根因）；7bdba5ef测试夹具改真实SCNRenderer前后帧，并显式比较presentation与model位置，尚待补验。
- 原生同一临时俯视长拖不再崩溃；实际抵达x≈0.999949455/z≈0.0005759854，45°/8m/s飞台、整杆后母球回原位及单一回收事件均已走通。重进后的historyID为空失败，不能算完整流程通过。已审回收原图CD6D3575与录像54.8s重进帧；后者回放确实不可用。
- 进一步只读检查本任务failed设备6E72464E的真实App容器：v2草稿仅母球/8m/s/45°，historyID缺失，当前namespace下根本没有SpatialPractice历史文件。不是仅凭UI等待即可解释；原因仍待定位。保留设备供存档诊断，未complete。
- 7bdba5efe741e1184d89f56d2c5840b27b7292b0 / 3f48cd21d9649f43400021853eeb57c57db70684b127dbfdca9b7c1bf9843c31（native-10）增加仅DEBUG且-probe启用的写权/prepare/completion/end有限日志；原生在离页前必须断言committed history UUID，附真实诊断JSON；增加精确原生近库输入的实际VM预览/写盘对照。旧断言保留，复验目的先区分生成数据与页面写权生命周期，不预判修复。
- 原件r5-native-9-pristine与分析clone/attachments/summary分离；R5仍未关闭，R6仅只读预检。

- 存档提示复核发现BTTeachingTablePage的仅母球分支会优先进入摆球提示，甚至提示已隐藏时也不显示information，故先前回收截图没有错误提示不能推断保存成功。2b86fd11本页显式设置showsPlacementHint仅在message/archiveMessage均空时开启，复用既有参数、不改旧页默认。当前native-10保持7bdba5ef冻结诊断源，最终修订须另验；未因提示修复跳过存档根因。

- native-9失败现场原始v2草稿字节已导出至`output/v66-rework/r5-native9-original-drafts`，SHA清单保留；确认设备6E72464E属于该作业、Shutdown且无占用后精确retire/cleanup，complete已回收其source/build/无引用snapshot。原始失败结论、xcresult、录像、容器检查与草稿均保留；native-10继续FIFO等待，不复用或重建旧失败设备。

### R5飞台存档根因与修订（2026-11-18）

- native-10（7bdba5ef / 3f48cd21）完整构建成功，7项实际5通过/2失败/0跳过。4项Archive守护和真实renderer球影更新通过；独立近库实际杆validShot/写盘及原生durable引用均失败。原件`r5-native-10-pristine`，分析clone/summary/attachments独立。
- 原始Swift杆附件`A3014474-D3FC-4485-8913-8BF246224BE7.plist`显示45°/8m/s终点X=3.0127570629m，超过X=3m模拟域12.757mm；时间/旋转/音效/机位均无该类异常。原生写权trace显示owns/current均true，两次prepare均以coderInvalidValue拒绝，排除该例writer争抢假设。
- 根因是exitState只取最后区间，而一个已接受子步含多段，最后段起点已经在域外；guard失败将域外fallback直接发布，严格validBoard正确拦截。35dc92fd754488cda82d1fa2c0ff61a648f6bde5改查实际首个inside→outside跨界段，二分时刻/解析状态不变；增加±X/±Z多区间回归，原失败实际VM/原生测试原样复验。没有放宽存档合法域或删断言。
- Swift parse/diff通过，snapshot `a84d23226d8cb6adf6c46154c15558e8faea379846063d10a93bead95b890e54` / native-11复验待运行。包含2b86错误提示优先修订；R5仍未关闭。原始轨迹出图`r5-native10-domain-failure.png`已目视，绘图脚本只消费Swift附件，不充当引擎通过证据。

- native-10诊断结束：BE9538EF确认本任务/Shutdown/无占用，精确退役删除；complete回收source/build/无引用snapshot，失败原件与原始杆/写盘trace保留。native-11序号558已按FIFO进入构建，未跳过原失败断言。

### R5首个跨界段复验与短回放断言（2026-11-18）

- native-11（35dc92fd / a84d2322）完整构建成功，实际28项27通过/1失败/0跳过。27项逻辑/场景全过：实际45°/8m/s杆写盘、四方向多段跨界、回收/镜头现场、Archive四项、Spatial十九项含旧九族并发/取消对照。附件23A65556原杆终点X=3.0m；原生9FBFAAD3 trace prepare一次成功，committed UUID=4C9ED6D3…，重进同UUID通过。回收原图80FC7C83已审。
- 唯一失败在原生331行：327–330已实际观察replaying且displayedElevation=45；下一次独立AX读取发生在1.25s慢回放结束后，得到恢复草稿40.19278887。断言混合两个时刻，不是保存再失败。1d22ea427ffb54253fc8e072decb60edcb0be3c7只改测试：捕获实际replaying快照，对同一快照单独断言phase和原45°并附JSON；结束后同时断言草稿输入与显示恢复，原机位/重打/后台断言保持。
- snapshot 52e24f0722a366d1dc4ce969faa5507a19c036b00ca7f224b88f534a425bb940 / native-12只补该原生链，生产仍35dc92fd。R5未关闭。native-11原件/分析clone/附件保留；2200823A已核Shutdown/归属/无占用后精确退役删除，complete收尾。

### R5关闭与R6开始（2026-11-18）

- native-12（1d22ea427ffb54253fc8e072decb60edcb0be3c7 / 52e24f0722a366d1dc4ce969faa5507a19c036b00ca7f224b88f534a425bb940）完整TEST BUILD SUCCEEDED，原生真实飞台全链1/1通过、0失败/跳过，81.432s。实际拖球、整杆回收、durable history、退出重进同一历史、1/4回放原45°、结束恢复当前草稿/机位、重打和后台恢复均通过。生产代码仍35dc92fd；不是重新求解或注入历史替代原生流程。
- 原件r5-native-12-pristine，分析clone、summary及attachments分离；6F4E8EDF活动回放JSON与FFD1A9B7恢复草稿40°原图保留，后者已目视。成功设备按队列生命周期回收，fetch --complete成功。结合native-11的27项逻辑/场景通过，R5关闭；原失败轮次不撤销。
- R6索引候选4221bd76d1d0cb04775559b5dace6a3bf37ee1a8：仅新空间freeze显式准备有序区间索引，旧默认线性查找不变，异常顺序/嵌套/追加退回原语义；加入逐值对照与真实四输入轨迹用例。显式采样离域时刻并统一Float事件可见性。parse/diff通过，snapshot cc02a289b860f3237558bb4b4a40fa53e8c2942c2b191a8152fff7775ec760fa / v66-rework-r6-index-1已进入FIFO运行，尚未判测试通过。
- R6仍待端到端渲染计时、最终原生/旧页往返与集成源验证。未合并主工作区，真机体验/校准/用户认可未验。

### R6索引实测与旧回放待定位（2026-11-18）

- 4221bd76 / cc02a289 / r6-index-1完整构建成功，xcresult实际60项59通过、1失败、0跳过（原始日志4条失败断言属于同一testDiamondFreeReplayLifecycle，不是4个失败用例）。空间索引逐值/事件可见性、空间19、Recovery4、Preview11、BoardMemory6、SequenceEnginePersistence3均通过；旧颗星自由回放返回球位/旋转不一致须单独定位，不能先归为基线失败。未改原断言。
- r5-native-12原生产1d22ea42冻结源已提交r6-replay-baseline-1，以相同BoardMemory/Sequence/SharedShotReplay三组对照。新的索引只由SpatialPracticeRecord.freeze显式准备，旧默认查找保留，但源码推断不能替代基线运行。
- 原始性能附件83F79961-E104-46D7-B107-611BEEB970BD.json；21轮首冷/20暖，compute=solve+freeze逐样本相加后取nearest-rank P95。暖P50/P95毫秒：平杆4.082/4.322、跳球8.710/8.833、左扎杆12.509/12.676、16球981.134/1023.736。16球freeze P50/P9586.296/90.601（R1约135.744/143.155）；solve P50/P95894.730/932.492仍为主耗时。整档编码仍约350.557/365.939ms，R5在后台prepare历史，不混入上述compute口径。模拟器同机数据，非真机或点击到画面时延。汇总r6-index-cost-summary.json。
- fc6a9af5+4064d1c1增加仅DEBUG且显式-masseJump.timing启用的独立渲染回执/分段计时，旧页nil。原TableFrameReceipt生产单槽不占用；实际观察运动的杆头/模型子节点，根节点固定击点不用于测运动。增加预览帧过期守护、原生调参/命中出杆采样、旧五页面往返、保存布局重进/透明度/微调/回中、iPad真实系统缩窗回程测试；语法通过，完整构建运行待验。
- d6a61e6d仅验收快照保留成功UI系统录像（project.yml和scheme systemAttachmentLifetime），集成前恢复原测试附件策略；生产代码与4064d1c1相同。r6-native-1快照准备中。R6未关闭。

- R6索引失败轮次诊断设备20EB814A已核本任务/Shutdown/无占用，精确retire+cleanup删除；原件/分析clone/统计保留，complete成功清理source/build/无引用snapshot。颗星问题仍在独立基线作业对照，未判关闭。
- 源码定位另一处重复求解：schedulePrediction(immediate:true)会取消同key仍在运行的预览。665b7097改为复用未取消且完整key相同的在途请求，保留改输入/owner/离页取消；新增真实16球在途观测、startedSolves数量与受理输入/最终球形断言，未注入求解结果。完整验证待运行。
- c395d3d1补原生提前点开球采样（按实际cached字段分类，不强设命中/未命中），并核实准度设置宿主的真实training.settingsCancel返回。原r6-native-1在queued态取消，未构建/测试，不计验收；改由r6-native-2最终候选。
- 主工作区重新只读核实：HEAD仍5a21b7fd；现在额外AngleSceneView含v67相机/诊断改动，最终三个重叠文件pbxproj、AngleTrainingScene、AngleSceneView都须三方合并并保留当前内容。未写入主工作区代码。

### 主工程与真机安装（2026-11-18）

主分支提交015889ae整合27个文件，保留主工作区同期相机修改与原有测试录像配置。主工程Debug真机构建成功，覆盖安装至已连接的iPhone 16 Pro并成功启动com.xinkuan.qiuji。凭据在output/v66-rework/main-device-build.log、main-device-install.json和main-device-launch.json。尚待最终回归与真机击球体验复核。

### 11月18日摄像头接线修订

真机先前安装的扎杆与跳球由教学宿主选用旧策略。本页现显式选用分离角与走位的相机策略，方向尺发送手动瞄准意图，观察手势松手由控制器处理；历史保存和恢复实际相机快照。iPhone 16 Pro 上 75° 两种视角拖动与松手、全桌观察后方向尺返回、飞台后重新进入并回放和恢复当前草稿，以及共享默认策略共3项通过。证据在 output/v66-rework/spatial-camera-device-{test,wheel}.log。

### 11月18日开球、选球、抬杆与轨迹对齐

开球准备仅绘制共享瞄准辅助。每杆静止后推荐目标，普通杆使用 2.0 m/s、中心打点。自动或手动选球都从共享避障角开始，移球时保留可用手调角。贴台线以布面高度裁剪，腾空段保留相对高度。打点盘保留虚线边界。抬杆尺横置于回放右侧，基础灵敏度 0.20°/pt。iPhone 16 Pro 首轮 48 项中 46 项通过、1 项 GPU 采样跳过、1 项截图库误写 Mac 路径；改用 XCTest 附件后该项通过。随后在同一真机通过 16 球实打重打、移球避障及原生横尺手势复验。日志见 output/v66-rework/q7-tests.log、q7-native.log。

同一真机完成分离角与走位、走位求解的往返测试。在各页摆入 7 号球，切到扎杆与跳球出杆，再返回逐球比较坐标并摆入 8 号球；两页均通过，独立抬杆尺仅在自由练习显示。凭据为 output/v66-rework/q7-cross-ui.log 和 q7-cross-attachments。

开球切换采用与分离角与走位相同的第三人称。原生界面测试等待相机结束运动，核对提示线、杆速、水平尺和打点盘；稳定截图见 output/v66-rework/q7-verified-ui，测试见 q7-rack-camera.log。

### 11月19日移球时的手调仰角与避障

原实现把避障结果写回唯一的角度字段，移开障碍后无法还原用户的设定。现在仅在需要补偿时另存手调角，拖动过程读取实际球位，按正式出杆使用的球杆外形和打点检查可达性；松手更新整杆预测。界面、杆姿、物理和回放读取本杆实际角度。回到开阔球位后恢复手调值，手调新值取代旧值。单页存档以可选字段兼容旧草稿。测试通过真实场景的拖球入口验证 6.25° 和 12.5° 的抬升及回落、受阻位置的存档重进、58.5° 新设定，以及开球与重打。凭据在 output/v66-rework/preferred-elevation-device-2.log。

最终 iPhone 16 Pro 定向功能测试 22/22 通过（preferred-elevation-final-device.log）。独立原生 UI 拖动用例已编译，手机测试运行器在建立连接前退出（code 74）；本地评审设备正运行，Mac mini 模拟器达到容量上限，界面手势留待复验。远端证据已回传，任务已关闭。
