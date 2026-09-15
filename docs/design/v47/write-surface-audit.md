# v47 W0 测试写盘盘点

2026-09-13 球贴纸：`BallStickerTests` / `BallStickerUITests` 只写 `output/ball-stickers-20260913/app-renders` 与 `ui`，所有写盘错误抛出。UV 相机校验帧为测试 Bundle 中的 `BallStickerUVFrames.json`，不依赖旧 output。SettingsView → BallStickerSettingsView 为正常生产导航，六款选择与本地重启保留由 BallStickerUITests 覆盖；深链取证外观使用已有显式 Light 参数，不将默认强制 Dark 的图冒充 Light。

机器清单见 `write-surface-files.txt`，由 `verify_v47_ui_baseline.py` 对 `QiuJiTests/` 与 `QiuJiUITests/` 中的 `.write(`、`FileManager.default.createDirectory`、`pngRepresentation` 扫描生成并做差集门禁。当前共登记 147 个文件；新增写盘测试未登记时 `verify-gate` 失败。

2026-09-14 补登记已有 `RoomReflectionProbeTests`：仅显式 `V62_SHOT_DIR` 指定且非 `device` 时写 PNG；默认不写盘，写入失败抛出；任务方须给独立 `output/` 或 `build/` 证据目录，留存由该任务负责，不得指向 Bundle/content/docs 基线。此次仅补清单和审计，未改反射测试。

## 分类与处置

| 类型 | 默认执行集 | 允许目录 | 清理 / 污染要求 |
|---|---|---|---|
| 普通单元测试临时文件 | `QiuJi` scheme 的 `QiuJiTests` | `FileManager.default.temporaryDirectory`、测试专属临时目录 | 测试自行删除或由系统回收；不得写仓库真源 |
| 诊断 / evidence renderer | 多数在 `QiuJiTests` 默认执行集 | `build/<task>-*` | 允许覆盖同任务 build 产物；不得写 `QiuJi/Resources` 或 docs 基线 |
| bake / export runner | scheme 内但应由内部 gate 或 `-only-testing` 控制 | 明确的 `build/`；显式发布命令才可写 `QiuJi/Resources` / `content` | 默认全量测试必须证明 runner gate 未开启时不写真源 |
| UI 截图 | `QiuJiUITests`；普通 `QiuJi` scheme 会包含 | `build/<task>-screenshots`、`tmp/` | PNG 写入失败必须让测试失败；不得默认写 `docs/ui-polish` |
| 旧 worktree 绝对路径 | 仍存在于历史测试 | 对应旧 worktree `build/` | 属已知技术债；若路径不存在应写当前仓 `build/` 或显式失败，禁止回退到 docs/Resources |
| 内容录制特例 | `B1_ManualFormationUITests` 等 | `content/position_play/sequences` | 只允许显式 `-only-testing` 的录制流程；不得进入普通 smoke / W15a 默认巡游 |

## 已确认的默认执行关系

- `QiuJi.xcscheme` 的 TestAction 同时包含 `QiuJiTests` 与 `QiuJiUITests`，没有 `.xctestplan`。
- `QiuJiUITour.xcscheme` 只包含 `QiuJiUITests`，用于长巡游；必须配合 `-only-testing`，否则会运行整个 UI target。
- `make test` 当前末尾带 `|| true`，不能作为诚实的全量测试结论；v47 基线和收官一律用直接 `xcodebuild` 并检查退出码。
- `ScreenshotTourUITests` 已改为默认写 `build/v47-screenshots/{light|dark}`，建目录和 PNG 写入不再使用 `try?`；完整设计师巡游按 66 张预期 manifest 做缺图断言。
- v49 的 21 个文案取证测试统一写入仓库忽略目录 `build/v49-screenshots/`；写入失败会触发 `XCTFail`，不会回写 Drill、精讲图或设计基线真源。
- v52 的首页/设置与每日页截图测试通过 `TEST_RUNNER_V52_SHOT_DIR` / `V52_SHOT_DIR` 注入每次运行的 `build/v52-qa/<runtime>/<device>/<appearance>/<size>/` 隔离目录；未提供环境变量时仍只写忽略的 `build/v52-*`，写入失败会让测试失败。
- v53 的 `V53ProfilePreferencesTests` 只在 `FileManager.default.temporaryDirectory` 下创建 UUID 隔离的头像 JPEG 缓存目录，并由每条测试的 `defer` 删除；不写仓库资源、用户真实头像或长期证据目录。
- v54 的迁移测试只在 `FileManager.default.temporaryDirectory` 下创建 UUID 隔离 store 并清理；`V54ScheduleUITests` 只写调用方注入的 `build/ui-reviews/v54/<device>-<appearance>/`，不覆盖设计基线或 Bundle 资源，写入失败直接使测试失败。

## W15a 复核

1. 重跑机器差集，确认写盘文件数与本清单一致。
2. 对所有默认执行的 runner 检查 gate，实际测试前后用 `git status --short` 确认未改 `QiuJi/Resources`、`content/`、`docs/ui-polish/`。
3. 所有 v47 截图只出现在 `build/v47-*` 或 `tmp/`；Stitch 选中截图只进入 `docs/design/v47/stitch/selected/`，且不冒充 App 截图。

## v57 持久恢复测试追加审计（2026-09-05）

`V54ScheduleDomainTests.test_v57_projectionReopensDiskStoreAfterTemplateDeletion` 仅写 `FileManager.default.temporaryDirectory/v57-projection-<UUID>/test.store` 及同目录 SQLite 伴随文件。独立目录通过 defer 删除，删除失败 XCTFail；不接用户真实 store，不写 Bundle 或内容真源。该写盘用于关闭容器后重新打开、证明已删模版的冻结课块恢复，W1 已运行通过。

## v57 W4 计次与渲染测试审计（2026-09-05）

DrillListViewModelTests.swift 新增 V57PracticeCountTests，仅在 temporaryDirectory/v57-count-UUID/test.store 创建隔离磁盘库，关闭重开用于恢复验证；defer清理目录，失败XCTFail。渲染测试用XCTAttachment，不写Bundle或内容资产。DEBUG V57PracticeCountFixtureHost 仅显式-v57.practiceCountFixture可达，持有State内存容器并真实保存/删除条目，不接用户磁盘库。既有V24渲染输出仍位于build/v24-w1-evidence，未扩大真源写入。

## 2026-09-07 提交前增量审计

引导从启动登录流程改为“我的 → 认识球迹”可选 sheet；订阅页新增游客登录 sheet 并保留套餐选择。训练新增整场心得草稿 sheet，今日安排与计划动作通过 TrainingRoute.drillDetail 在同栈打开详情；收藏页仅布局修饰变化。RootView 的预览与测试分支均在 DEBUG 内。已同步 route-coverage.csv 与路由签名，未替换历史截图哈希或声称重跑截图矩阵。

写盘文件集合与现有清单一致；OnboardingProUITests 使用 XCTest 附件保存截图及本地 StoreKitTest 会话，未增加直接写仓库文件路径。本次门禁与构建日志位于被忽略的 build/commit-push-20260907/。

- 2026-09-09：TrainingAtmosphereUITests 仅向 DAYPART_SHOTS 显式注入的 output/daypart-implementation-20260909/<device>-<appearance>/ 写截图；无参数只附 xcresult，不写资源或设计基线；使用内存训练数据，写失败使测试失败。

## 2026-09-10 训练首页辅助功能可达性审计

TrainingHome 更多菜单可达 TrainingNotesView、ManualTrainingView sheet、TrainingReminderView、TrainingHelpView；TrainingGoalView 复用提醒页。心得详情/编辑从当前 owner 的会话选择进入，帮助中的计划/补记/心得/提醒/设置/关于为实际 NavigationLink。ManualTrainingView 从记录详情可编辑补记。通知 delegate 只切训练 Tab/path，保留训练 VM。新增路由已登记，不修改历史截图哈希。

TrainingUtilitiesTests 使用临时内存 ModelContainer；TrainingUtilitiesUITests 使用 -v50.inMemoryStore 与 XCTest 附件，不写训练资源或设计截图基线。后端测试仅构造 Mongoose 对象，不连接服务器。验证结果见 tasks/training-utilities/README.md。


## 2026-09-10 六袋皮革测试写盘审计

PocketLeatherIntegrationTests 默认仅写仓库output/pocket-leather/W1/render与W4/neutral下PNG，可用POCKET_EVIDENCE指定临时渲染目录；序列只读content中的现有c060/c042 JSON。PocketLeatherUITests默认写output/pocket-leather/ui的PNG/AX；PocketLeatherFlowUITests默认写output/pocket-leather/W4/standard，可用POCKET_UI_EVIDENCE指定矩阵目录。截图另附xcresult，前景/table.scene断言失败不能认作页面通过。使用内存账号/训练fixture；批量制作只进入空球形编排，禁止点保存/导出。证据有意保留，不自动删除，按批次归档，写失败使测试失败。无Bundle、历史媒体或正式球形写入。

此次门禁同时检出已有AimPointTheoryScanTests（其他任务未登记）：已检查全部写入调用，仅写output/aim-point-theory/W0中的扫描/探针JSON和comparison PNG，无正式数据改写；本轮只登记真实写盘面，不执行其物理扫描，不宣称验收其结果。

## 2026-09-10 心得日记页可达性审计

TrainingNotesView 由首页更多进入，按日期 navigationDestination 打开 TrainingNoteCollectionDetail；编辑在同页切换草稿态，不再叠第二层 sheet。每次训练记录 NavigationLink 保留。当天批量保存使用独立 ModelContext 事务，并按变化会话加入同步队列。新增 fixture 仅 DEBUG 模拟器且同时显式 -journal.fixture / -v50.inMemoryStore 时写内存库，零磁盘用户记录写入；截图只存 xcresult 附件。只更新本页面已审计路由签名，旧图基线不变。

本次复核发现其他并行任务的 PocketRefactorDiagTests 新增写盘，已只读审计并登记：两个诊断均要求对应 output 子目录存在 RUN 哨兵；写入 output/middle-pocket-alignment-20260910/compare/comparison.json 与 output/middle-pocket-visual-20260910 的 PNG/frames.json，不删除文件、不写 Bundle 或历史基线。本轮未执行其物理诊断，不把它计为日记功能验收。

## 2026-09-11 v62 渲染实验写盘审计

RenderQualityV62Tests 与 RenderQualityV62UITests 仅输出渲染 PNG/诊断 JSON 和 xcresult 附件。模拟器默认 output/render-quality-v62，可通过 runner 的 V62_SHOT_DIR 隔离每次运行；手机默认测试沙盒临时目录，截图附 xcresult。标准、iOS17及后续复跑使用独立叶子，不删除失败证据；写失败令测试失败。显式 -v62.fixture 固定题目/球号/球姿，仅 DEBUG 或专用 RENDER_QUALITY_VALIDATION 构建生效；UI 测试使用既有内存账号夹具。不写 Bundle、训练数据、USDZ、已有截图基线。新 HDR 是独立原创参数化资产，非截图烘焙。

## v63 W03 辅助线几何与性能证据

- `QiuJiTests/TrajectoryRendererTests.swift` 中 `TableAssistSurfaceV63Tests.testLoadedClothFootprintAndRenderEvidence` 写入当前仓库 `output/3d-v63/W03/footprint-r1/{measurement.json,before.png,projected.png}`，为固定几何夹具复跑覆盖目录。构建结果、其他附件和失败日志存入每轮独立的xcresult；不默认删除证据。
- 同文件的CPU成本报告采用XCTAttachment JSON，随每轮xcresult隔离；训练截图附件同样由结果包保留。源码路径用`#filePath`计算，写盘失败向外抛错使测试失败。
- 不写训练内容、资源、物理真源或截图设计基线。默认QiuJiTests执行集可能运行该类；本批使用显式only-testing，重跑前应先保存需要对比的footprint固定目录。

## 2026-09-13 球桌风格收尾时的并行球杆测试登记

只读核对 CueStyleTests / CueStyleUITests：分别写 output/cue-stickers/app-renders 与 output/cue-stickers/ui 的固定名称 PNG；UI另附xcresult。复跑可能覆盖固定PNG，需事前保留对比证据；无自动删除，写失败抛错。不写Bundle、正式训练数据或设计基线。UI使用内存账号夹具并保存本地外观偏好，应使用独立模拟器。本次只登记真实写盘面，球杆功能验收由对应任务负责。球桌测试自身仅使用xcresult附件。


## v63 真机测试路径适配（2026-09-15）

S1_FreePlayLayoutUITests、S2_ShotPagesLayoutUITests、DrillSceneThreeBeatUITests 的手机 PNG 改写测试沙盒临时目录，模拟器原路径保留，xcresult keepAlways 附件用于取证。TrajectoryRendererTests 两条 W17 用例改读 Bundle formation；导出影片仅手机临时目录与 MPEG4 附件，近景截图手机只写附件，模拟器原路径保留。均未写训练内容或截图设计基线；写盘错误仍令测试失败。

## 2026-09-15 角度教学视频导出

`X1_CameraAndAngleArcTests.swift` 内的 `AngleAimingVideoCaptureTests` 仅在显式 `TEST_RUNNER_ANGLE_CAPTURE_DIR` / `ANGLE_CAPTURE_DIR` 下运行，无变量时 XCTSkip 且不写盘。专用模拟器内生成4K PNG、MP4及几何/投影JSON，允许目录为任务独立 `output/angle-aiming-video-20260915/`（或显式指定的同类build目录），不写Resources、内容或设计基线；文件写入失败抛出。重复运行只覆盖本任务同名产物；证据保留供用户查看，由任务方按需清理。
