# 制作入口与下架盘面可达性审计

2026-09-06。只读 `snapshot-002` 源码/内容及既有证据；没有启动UI/构建，没有录制、导出、删除或修改资产。

## 结论范围

1. **SC28在批准表中是“音效回放F20”**。制作/录制入口主要关联SC21编排与SC37发布边界；二者共享回放/导出基础设施，但不能把制作流程排除误写为SC28已覆盖。
2. 普通用户的自由走位/自由击球/动作试打与内容制作分开。冻结普通`PositionPlayComposerView`虽保留早期“录制开关”注释，**实际View没有startRecording/stopRecording/归档调用，也没有录制/导出按钮**；真实开始录制调用位于BatchAuthoringView。不能凭旧注释报告普通页面仍有录制入口。
3. 批量出片台明确是**模拟器条件**，不是DEBUG条件。普通模拟器“练习→打”确实会添加制作卡；同配置Release模拟器仍满足条件。真机编译分支不添加卡，MainTab目的地为EmptyView，Batch代码整体不编译。未做真机产物/UI实测，不能把源码排除当签名真机验证。
4. QD009是**六个文件、五个已下架drill ID**。当前Bundle内容源的正式索引、Drill内容文件和计划JSON均无这五ID；正常动作库/计划/新自由训练选择器不会从DrillBoards反向生成课程。因此静态链路支持“这些残留不是新用户正常课程入口”。历史数据、制作台以及参数路径另列，不绝对断言所有状态不可达。

## 产品裁定与版本边界

- `tasks/phases/P11-position-play-composer.md` ADR-P11-10（2026-06-12）明确：录制暂不开放终端用户、模拟器采集直写内容库、生成视频管线与用户App分离。该历史条目描述的普通编排台录制按钮，**不能直接当冻结实现**；现有View已没有对应调用。
- `docs/04-功能规划.md` F13仍列“录制开关→导出序列JSON（模拟器侧直写内容库）”；F20是声音与原速回放。功能文档是方向/历史验收约定，具体当前入口须用下面源码确认。
- `问题集合_v44.md` §3.3明确将c002、c006/c007、c062、c066列为下架课，计划用相邻课程补位。v41“c062本轮跳过不删JSON”是**更早批次裁定**，不能拿来推翻v44下架状态。
- `问题集合_v46.md` D-v46-8把batchDrillStudio标为非正式IA的SIM工具；“首页不出”语境是正式产品卡片资产，不等同模拟器源码必须删除卡。
- 上述讨论/任务文档来自主工作区历史文件，冻结snapshot未包含它们；只用于裁定来源，不把其内容计入B0源码指纹。本次实现结论全部依snapshot-002。

## 制作/用户入口实际链路

| 入口/调用 | 源码证据（相对snapshot根） | 公开边界与副作用 |
|---|---|---|
| 练习→打→自由走位 | AngleHomeView.basePlayEntries → MainTabView.positionPlayComposer → PositionPlayComposerView | 普通入口；当前更多菜单只有重命名、清空桌面、清空并重来及显示选项；没有录制/归档调用。重命名是内存序列名变化，本审计没有操作 |
| 动作详情→上手试打 | DrillDetailView.startTryout → PositionPlayComposerView(sourceDrill,formation) | 普通入口；默认序列演示或自由模式；试打更多菜单为“试打说明”等，隐藏普通重命名/清空项，提供重摆球形；不等于制作 |
| 练习→打→自由击球 | AngleHomeView.freePlay → FreePlayView | 普通对局工具；不是BatchAuthoring，不因共享PositionPlay VM就等于能导出 |
| 练习→打→批量出片台 | AngleHomeView:208–215 `#if targetEnvironment(simulator)`；MainTabView:224–230相同条件 | 模拟器直接可达，不要求额外启动参数。仅适合宿主内容工作；不要在正常巡游点击制作行/删除/保存 |
| BatchDrillStudioView | Features/BatchDrillStudio/BatchDrillStudioCore.swift整体 `#if targetEnvironment(simulator)`；onAppear reload/refreshSaved | 列表读取宿主项目15截图目录、项目13内容序列目录；不是被冻结App Bundle的封闭内容视图。进入将扫描宿主目录，当前审计未执行 |
| BatchAuthoringView | composer.startRecording唯一App调用；BatchSequenceArchive.archive调用处 | 作者编辑/采集路径，归档会写固定宿主内容库；某些界面动作会开始录制，不能用“只点进去看看”假定无副作用 |
| BatchBallExtractionView | BatchSequenceArchive.deleteArchive调用 | 制作侧有删除归档能力；不属于本次用户内容功能诊断执行范围 |
| PositionPlaySequenceArchive | Features/PositionPlay/Services/PositionPlaySequenceArchive.swift整体模拟器guard | 写/替换序列实现仍保留；本次检索App源码未发现对其archive的调用。保留实现不证明有可点UI入口 |
| SequenceVideoExporter | Core/Media/SequenceVideoExporter.swift | 导出实现存在；实际导出调用主要由QiuJiTests/PositionPlaySequenceExportRunnerTests制作runner发起。普通App文件中的类型引用/相机工具调用不等于视频导出入口 |
| 制作测试runner | scripts/Makefile position-export等、QiuJiTests制作runner | 独立制作工具/文件门，不是普通用户路由；本次不运行、不写导出调用示例 |

可达性的依据是调用图与guard，而不是是否在二进制中搜索到“录制”字符串。Release模拟器与App Store真机应分别报告。

## QD009六文件核对

冻结 `QiuJi/Resources/DrillBoards` 内六文件SHA-256均与既有 `run-002/retired-bundle-audit.json` 对应记录一致；这是源码资产与旧Debug包清单对应证据，**没有在本子任务重新检查当前构建包**。

| 文件（均位于DrillBoards） | steps | DrillTryoutBoardStore直接查询时 |
|---|---:|---|
| drill_c002__manual01-斜角入底角袋 · 球形1-9杆.json | 9 | 可解码成1个formation，但没有正式Drill课程内容入口 |
| drill_c006__manual01-握杆稳定性练习 · 球形1-0杆.json | 0 | 被`!sequence.steps.isEmpty`过滤 |
| drill_c006__manual02-握杆稳定性练习 · 球形2-0杆.json | 0 | 被空steps过滤 |
| drill_c007__manual01-站位与身体对齐 · 球形1-4杆.json | 4 | 可解码成1个formation，但没有正式Drill课程内容入口 |
| drill_c062__Snipaste_2026_06_19_17_57_13-远台中袋直线-4杆.json | 4 | 可解码成1个formation，但没有正式Drill课程内容入口 |
| drill_c066__manual01-开球训练（中式台球） · 球形1-0杆.json | 0 | 被空steps过滤 |

此次逐文件JSON读取确实核对了steps数量；“可解码formation”为按Swift读取逻辑的静态推断，未另外运行Swift解码。

### 正常新用户路径

- `DrillListViewModel.loadDrills`→`DrillContentService.loadFallbackDrills`→`Drills/index.json.allDrillIds`→各分类Drill JSON。**不枚举DrillBoards生成课程**。
- 对冻结 `Resources/Drills/**/*.json`（含index）与`Resources/Plans/**/*.json`全文扫描这五个精确ID，命中0；对应5份Drill文件不存在。
- 自由训练动作选择器同样取loadFallbackDrills。正常详情`loadDrillFromBundle(id:)`只找`Drills/<category>/<id>.json`，缺失后展示`drillDetail.unavailable`：“动作暂不可用”。试打按钮仅在拿到Drill时生成。
- 因此“包里保留c002的9杆序列”不会自动使“斜角入底角袋”重新出现在库或计划，也不会自动绕过内容缺失状态。

### 参数、旧数据与制作侧例外

- RootView的`-deeplink.tryout=<id>`仍先从loadFallbackDrills匹配Drill；这五ID匹配不到，不能凭参数直接取得试打页。`-deeplink.drillDetail=<id>`允许任意非空ID，但后续详情仍要找Drill JSON，按代码应显示不可用。这些参数没有全局DEBUG包围，属于SC37测试入口残留问题，与正常可达性分开。
- `-deeplink.activeTraining=<id>`允许构造任意ID的测试宿主；TrainingDoseResolver/ActiveTrainingVM有直接按ID查询formation的方法。此类参数宿主与正常新建训练数据不同，未做参数下的完整旧盘面渲染验证。
- 历史Entry保留旧drillId/名称快照是需要支持的数据。TrainingDataEditorView会按旧ID查formation，但仅`count>1`显示选择；这五ID当前过滤后最多1形，故按代码不会显示多形选择列。不能因此宣称旧历史完全不可见，更不能为了下架删除历史。
- SchemaV3保留c006球形数是迁移的不可变快照，不是课程重新上架；ActiveTrainingView、TrainingSummaryView、BTShareCard、BTExerciseRow中的旧ID命中属于preview/sample数据，未找到正常用户入口使用这些样本。
- **制作台边界风险**：BatchDrillCatalog.retiredDrillIds仅含c019。它合并正式index与宿主项目15有截图的drill目录；若该宿主仍有c002/c006/c007/c062/c066截图目录，这些ID会作为“未登记”条目出现在制作台。这是条件性静态可达路径，**未读项目15目录验证，也未证明当前UI实际出现**；仅有本项目sequence文件并不会自动加入allIds（allIds来自index ∪ imagesByDrillId）。不得把此推断升级为真机普通用户可达。

## 两个精确、安全的UI导航建议（未执行）

1. **下架课正常库搜索**：新无凭据诊断设备、空内存库、forcedPro（仅排除门控干扰）→动作库→librarySearchField依次输入“斜角入底角袋”“握杆稳定性练习”“站位与身体对齐”“远台中袋直线”“开球训练（中式台球）”→回车；逐项断言对应`drillCard_drill_c002/c006/c007/c062/c066`不存在并截图当前结果/空态；最后搜“初级蛇彩”并确认c042可见作为正对照。不得直接把匹配到别的近义课程当下架失败；本建议只检查正常库，不构造老账号数据。
2. **普通编排菜单边界**：正常练习→打→自由走位→确认`composer.more`→展开，保存菜单AX/图，确认包含预期重命名/显示项但没有录制、停止录制、导出/保存序列动作→用非内容菜单关闭方式返回。**不点重命名保存、清空、录制或制作台卡**。另可仅在打分类截图中记录模拟器制作卡是否存在，不能点进去后扫描宿主目录来冒充本机纯UI检查。

真实设备Release制作入口不存在、旧数据升级后历史可用、任意参数路径与所有间接调用仍是各自独立验证项。本审计支持收窄QD009为资产残留与发布包/隐藏路径待核对，不支持直接判“已下架内容公开泄漏”，也不建议删除资产。
