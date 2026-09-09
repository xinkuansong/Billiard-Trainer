# SC15 真实 Bundle 最小剩余补证

2026-09-08，只读准备；主控 data-goal-companion001 UI 占用期间未构建、测试、操作设备或修改工程。只新增本文。已全文读取 RELEASE-004-RESULT.md、冻结004下述四个测试文件，以及 V54PlanContentModelTests 作候选比较；核实际归档，不把编译日志当执行结果。

## 已有证据可直接复用

`archive/quality-diagnosis/runs/formal-004-release-001` 的 archive-manifest 明确 kind=release-build-not-xctest。实际 `球迹.app`、package-audit.json、package-sha256.json 均存在。本次对 Drills/Plans/DrillBoards/TutorialFigures 的891份实际包文件重新计算 SHA256，全部与 package-sha256.json 一致，失配0。

已核资源计数：Drills76、Plans13、Boards98、TutorialFigures704；实际禁止母版目录未进包、无PNG母版误装包的现有静态审计可复用。六份下架盘面残留是已确认QD009，不重新复现同质失败。本包是模拟器Release build，不是已启动的Release验收，也不是XCTest运行；文件存在/哈希相同不能证明真实Swift模型/UIImage运行时解码。

CONTENT-FRESHNESS-004-AUDIT及新原件已补当前资源/上游/加载入口对004的相同输入、当前JSON结构/引用门禁、704母版manifest MD5；无需因旧002原件缺失重复整B3 31方法。它仍不能替代当前Bundle运行时加载证据。

本次在004归档 selectors.txt 及日志中检索四个测试类/相关方法，未找到相应 `Test Case ... passed/failed` 终态或选定selector。日志有这些Swift源编译记录，明确不是执行通过。当前已跑动作库/计划连续课程/精讲等UI证明代表内容正常加载，不能覆盖全部74动作、12计划、98盘面、704图。因此仅补以下5个现有hosted方法即可闭合这次“当前完整Bundle解码”缺口；未运行不填通过。

## 精确最小 selectors（共5，不选择整类）

|顺序|selector|实际断言/必要性|
|---|---|---|
|1|QiuJiTests/DrillContentValidationTests/test_loadedDrillCount_matches74|setUp经真实DrillContentService读取Bundle，严格allDrills.count=74，避免compactMap丢课后仍对残余样本通过，也防后面图引用集合为空/缩小|
|2|QiuJiTests/DrillContentValidationTests/test_allIndexedDrills_loadSuccessfully|对索引ID与实际已加载ID做差集，缺失给出直接JSONDecoder失败codingPath；与计数配对，不能只用74数量证明每个索引都命中|
|3|QiuJiTests/V21W5PlanContentTests/testOfficialPlanShelfOrderFollowsIndex|独立字面12个ID数组同时核索引及loadAllPlans的完整顺序；任何解码丢失/排序变化均失败，比testAllOfficialPlansStillDecode的“至少6套”更适合本轮|
|4|QiuJiTests/DrillTryoutBoardStoreTests/test_allBundledBoards_decodeAndInRange|Bundle枚举全部json，JSONDecoder+iso8601解码PositionPlaySequence，开局非空、所有开局球x∈[0,1]/y∈[0,.5]；不是仅文件解析或命名存在|
|5|QiuJiTests/TutorialFiguresBundleTests/test_referencedTutorialImages_allResolveFromBundle|setUp遍历真实已加载drill的顶层sections与formations.sections；引用非空，全引用经DrillTutorialImageStore.image加载不得nil。当前静态集704，与前两方法和实际包计数联合使用|

上述源均已在snapshot004的QiuJiTests目录，已有项目编译记录；没有必要新增诊断源或改断言。主控正式执行前仍应核真实Sources/生成scheme/selector原件，避免零方法或跑错target。若任一方法失败，保存原失败，不通过删断言、补资产、替换fixture改变结论。

## 全文源码审查结论与限制

- DrillContentValidationTests：setUp async 先loadDrillIndex、XCTAssertNotNil，随后 `index!`；若索引缺失可能在记录失败后trap，属于原方法诊断质量限制。本任务不修改。必须保留xcresult/崩溃或日志，不能把该中断视为后续通过。两个所选方法无写盘、无seed、无网络请求；decodeFailureReason只读Bundle并调用JSONDecoder。未选的字段/动画/premium20项已有历史与当前静态证据支撑，本轮目的并非重做整个语义矩阵。
- V21W5PlanContentTests：无setUp/tearDown或全局seed。所选方法只调用loadPlanIndex/loadAllPlans（Bundle JSON），字面序为beginner、accuracy、intermediate、force、cueball、english、accuracy3、separation、positioning、positioning2、advanced、fullskill。Optional索引与完整数组比较，不存在guard-return把空内容误绿。V54PlanContentModelTests的真实Bundle方法只测beginner9课，其他方法为构造payload，故不选来冒充全12套。
- DrillTryoutBoardStoreTests：无setUp/tearDown。所选方法直接读Bundle，不调用引擎出片/tryout-sync，不构造SwiftData。其数量断言仅≥80，不是98精确；本轮由实际Release98份清单和输入一致性补数量证据，主控新Debug宿主仍需核98份对应输入。如丢1份后仍97，该单方法可能通过，不能单独宣称完整集。检查开局before/initial，不能证明后续steps动态正确、碰撞/轨迹正确。
- TutorialFiguresBundleTests：setUp载动作并收集图片，无网络；图store依heic/png/jpg顺序在Bundle TutorialFigures查文件，调用UIImage(contentsOfFile:)，写进程NSCache而非磁盘。该方法能证明UIImage对象加载，不强制所有像素绘制/全屏显示，不证明教学对应和渲染新鲜度。`guard !unresolved.isEmpty else { return }` 是已扫描无失败的正常返回；起始集合有非空断言，不是无条件skip。
- 不再选containsNoPNGMasters/countMatchesReferencedSet：实际归档已给704和禁止资源的静态证据，正式新宿主资源清单核对即可复用。publishedFigure_decodesAtSourceResolution仅首图宽1440及宽高>0，不提供全量新增覆盖，故本最小批不加。不存在用1张尺寸通过替代704加载的情况。

## 宿主、schema与副作用边界

真实Bundle必须是App宿主：project.yml的QiuJiTests依赖QiuJi，TEST_HOST=`$(BUILT_PRODUCTS_DIR)/球迹.app/球迹`，BUNDLE_LOADER=TEST_HOST。不能改为无宿主测试或Bundle(for: testclass)，后者会读测试Bundle而不是产品资源。

主控待当前UI终态后串行执行，使用已有QiuJiDiagnosticMemoryHost的TestAction预先传`-v50.inMemoryStore`，先静态回读真实scheme；不要在setUp才传。QiuJiApp初始化即按该参数选ModelContainerFactory.makeInMemoryContainer。该factory用currentSchema=QiuJiSchemaV5、QiuJiMigrationPlan；11模型是TrainingSession、DrillEntry、DrillSet、AngleTestResult、UserActivePlan、DrillFavorite、SyncPendingItem、CustomPlan、CustomPlanDrill、TodayTrainingSchedule、TodayScheduleItem。不能临时拼旧6模型容器或误把schema缺失当内容失败。

这些测试不需要受控磁盘seed、日期9/8、forcePremium、真实账号或StoreKit；无需复用data刷新设备的已播种磁盘。使用专用无真实凭据环境。App宿主启动本身仍可能创建guest/UserDefaults，factory会对空内存容器执行OwnerV4/V54 normalization；不是严格零副作用进程。参数只隔离训练数据库，不能声称隔离Keychain/网络。所选service路径均Bundle-only，测试方法自身不触服务，正常App启动边界沿既有诊断设备控制。

## 正式执行时的有界验收

主控归档五个精确selector、所选测试源SHA、实际宿主bundle身份/资源路径清单与输入哈希、scheme TestAction、完整log/xcresult和真正退出码。需要5方法实际终态，0 skip；不能用编译成功、Make0或整体方法数替代逐项。可一次hosted小批完成，失败后仅根据证据处理诊断前提；不追加工具UI、不制作资产。

本批若通过，可与现有Release静态包及当前文件新鲜度审计共同核销SC15本机内容完整性所需的“当前Bundle模型/图片加载”层。QD009与C1的95项出片新鲜度缺口仍保留，教学正确性/真实动态展示/Release运行/真机仍按各自边界记录；不宣布整个质量诊断目标完成。
