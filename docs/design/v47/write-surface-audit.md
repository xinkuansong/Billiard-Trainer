# v47 W0 测试写盘盘点

2026-10-06 每日面板补充：`DailyAdaptivePanelUITests.swift`只消费调用方显式注入的本批 `DAILY_ADAPTIVITY_DIR`/`TEST_RUNNER_DAILY_ADAPTIVITY_DIR`，缺省失败。方法独立目录，入口截图加入launch序号/fixture避免同方法多次启动覆盖；原PNG、完整AX、状态/目标测量JSON、manifest及xcresult附件为测试证据。调用器新叶子exist_ok=false，失败不覆盖；字号由专用模拟器实际设定并读回，结束恢复large。测试只对该专用设备resetState/fixture与本地偏好做操作，不写内容资源/设计golden/用户真机；不自动删除证据。历史失效采集按原目录保留，不能将旧入口同名覆盖计为多个独立画面。


### 2026-10-06 每日清台适配取证

登记 `DailyAdaptivityAuditUITests.swift`、`DailyLayoutLifecycleUITests.swift`：必须显式注入 `DAILY_ADAPTIVITY_DIR`（或 `TEST_RUNNER_DAILY_ADAPTIVITY_DIR`），缺失时测试失败，不再回落到旧报告目录。写本轮 PNG、AX、JSON 和 xcresult 附件；生命周期类按方法分子目录。调用脚本按批次/设备/状态创建新叶子，拒绝复用叶子并保留失败。仅专用模拟器使用 resetState/fixture；不写 Bundle、训练内容或设计基线，不自动删除证据。相同目录重复执行仍可能覆盖同名图，因此由调用方负责隔离及后续清理。

### 2026-10-01 袋口延后确认取证

登记 `PocketMarkerHighlightTests.swift`：实际SCNRenderer时序测试默认向当前源码所在仓库 `output/pocket-selection-20261001/rendered` 写16张PNG，文件名按普通/移动、2D/3D、时序阶段分开；复跑覆盖同任务图片，本轮iOS26结果先保存为rendered-26，最终iOS17结果保存在rendered。写盘失败抛出，不主动清理，不写Bundle、用户存档、内容或设计截图基线。清理由任务方负责。已登记 `PocketLeatherFlowUITests.swift` 仅显式 `POCKET_UI_EVIDENCE` / `TEST_RUNNER_POCKET_UI_EVIDENCE` 时写本轮PNG及AX文本，否则仅XCTest附件；不同设备/轮次使用独立目录，固定名称会覆盖同目录证据。原生测试使用专用模拟器resetState/夹具，不对用户真机执行。

2026-10-01 金属音色替换：同一已登记的 `ShotAudioTests.swift` 现验证 Bundle 中两种单次金属齿声，试听解码证据改写至 `build/control-metal-20261001/ui_aim_metal.caf` 和 `ui_power_metal.caf`；旧试听及截图保留，不写产品资产。正式WAV由授权试听提取，位于现有Audio资源目录，来源/哈希登记CREDITS.md及build中的assets.json。

2026-10-01 两尺刻度声：登记 `ShotAudioTests.swift`，音频样本结构测试写 `build/control-audio-20261001/control-tick.caf`，只作本地试听证据。`AdaptiveShotControlsUITests.swift` 已登记，新增方法写同目录 `ui/` 中启用/静音的2D/3D截图；不写产品资源或历史截图基线、不主动清理旧证据，同名复跑会覆盖当前轮文件，失败抛出。

2026-10-01 直接路线优先：沿用已登记的 `PositionPlayFreeAimTests.swift`，只有显式 `DIRECT_REVIEW_OUTPUT`／`TEST_RUNNER_DIRECT_REVIEW_OUTPUT` 时才写 `routes.json`；本轮为 `build/daily-direct-recommendation-20261001`，输出截图近似球形的原候选和新推荐实际轨迹。默认回归不写此文件；不删除旧证据、不修改存档或资源，写入失败抛出。同任务复跑会覆盖JSON，任务方负责留存历史。

2026-10-01 选袋诊断：补登记 `PositionPlayFreeAimTests.swift`。此前用户要求球形对照的 `test_exportPocketSelectionReview` 写入 `output/pocket-selection-review-20261001` 的JSON，仅为诊断证据；同目录复跑会覆盖JSON，不写产品资源、存档或设计基线，不主动删除旧图。本轮近库回归默认仅做断言；显式 `TEST_RUNNER_RAIL_REVIEW_OUTPUT`（兼容去前缀的 `RAIL_REVIEW_OUTPUT`）才写四角真实轨迹 `physical-paths.json`，本轮目录 `build/daily-rail-rejection-20261001`。写入失败抛出；调用方负责指定独立证据目录并保留旧日志。图由独立绘图脚本生成，不替换截图基线。

2026-09-27 真机采集预检：`Daily3DDeviceProfilingUITests` 仅在显式 `TEST_RUNNER_DAILY3D_DEVICE_PROFILE=1` 且为真机时执行；向标准输出写协调标记，截图交给 `XCTAttachment` 保存到本轮 xcresult，不接受任意输出路径，不主动清理旧证据。沿用正式每日清台数据容器，不使用resetState、fixture、重开或击球；正常入口可能恢复/创建今日草稿并自动开球，离页/失活按产品逻辑保存用时和工具记录。只接受正常开球完成确认，其他业务决策截图后停止；仅瞄准与相机变更，前后上手数/剩余球数/犯规数须相同。日志仅用于协调，不能代替trace时间戳或性能验收。

2026-09-27 每日清台3D：`Daily3DClothPerformanceTests` 仅在诊断目录存在 `run` 哨兵时写PNG与逐通道比较JSON；模拟器为 `build/daily-3d-20260927/cloth-visuals`，手机为测试沙盒 caches 下 `daily-3d-cloth-visuals`。无哨兵跳过，不创建或改写用户存档、Bundle、内容真源或设计基线。写失败抛出。同目录复跑会覆盖本任务图片；复跑前由本任务保留旧证据。相机等价测试不写盘。

2026-09-13 球贴纸：`BallStickerTests` / `BallStickerUITests` 只写 `output/ball-stickers-20260913/app-renders` 与 `ui`，所有写盘错误抛出。UV 相机校验帧为测试 Bundle 中的 `BallStickerUVFrames.json`，不依赖旧 output。SettingsView → BallStickerSettingsView 为正常生产导航，六款选择与本地重启保留由 BallStickerUITests 覆盖；深链取证外观使用已有显式 Light 参数，不将默认强制 Dark 的图冒充 Light。

机器清单见 `write-surface-files.txt`，由 `verify_v47_ui_baseline.py` 对 `QiuJiTests/` 与 `QiuJiUITests/` 中的 `.write(`、`FileManager.default.createDirectory`、`pngRepresentation` 扫描生成并做差集门禁。当前共登记 167 个文件；新增写盘测试未登记时 `verify-gate` 失败。

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

## 2026-09-16 八球分离角片头

`SeparationAngleAtlasTests.swift` 新增显式开启的 `SeparationEightBallVideoCaptureTests`。无 `EIGHT_BALL_VIDEO_DIR` / `TEST_RUNNER_EIGHT_BALL_VIDEO_DIR` 时 XCTSkip；脚本只指定独立 `output/separation-eightball-20260916/r3`（r1/r2历史目录保留），写 PNG、MP4、JSON。相同输出目录重跑会覆盖本任务产物，历史版留在父目录；不写 Bundle、训练内容、用户存储或截图基线，不删除目录。写盘错误抛出，由本任务保留证据并负责后续清理。独立模拟器与构建目录防止干扰正文采集。


## 2026-09-20 六球两杆搜索写盘审计

`SixPocketTwoShotTests` 的搜索方法仅在 TWO_SHOT_DIR 显式启用时写 JSON；无变量时 XCTSkip。runner 要求独立输出目录且拒绝已有 build.log，保留源码/hash、每起点覆盖结果、实际见证解和第二杆状态库。默认位于本任务 output/two-shot-six-20260920 下，不写 Bundle、球形资源、用户存储或设计基线；失败与成功证据均保留，由任务方按需清理。输入 JSON 只读，写失败向外抛出。状态交接单测不写盘；采用独立模拟器。

## 2026-09-21 提交检查补齐视频与六袋研究登记

- `AdvancedSnakeVideoCaptureTests`：`SNAKE_CAPTURE_DIR`，写预检/标定/序列/机位/时间线 JSON、PNG 与导出视频。
- `SixPocketSearchTests`：`SIX_SEARCH_DIR`，写搜索进度、候选、诊断 JSON、PNG 与预览视频。
- `SixPocketV4ProbeTests`、`SixPocketV4RefineTests`、`SixPocketV4Round2ProbeTests`：`SIX_V4_DIR`，写探针、精修、统计 JSON/TXT；按实验子目录组织。
- `SixPocketV5VideoTests`：`SIX_V5_VIDEO_DIR`，写生产回放校验、帧 PNG、视频与清单 JSON。

六者均兼容 `TEST_RUNNER_` 环境变量前缀，写盘入口无显式目录即 XCTSkip。调用方必须使用独立 `output/` 或 `build/` 实验目录；代码接收任意显式路径，未强制限制根目录，因此不得指向 Resources、用户数据或设计基线。固定文件名复跑可能覆盖旧证据，运行前选择新目录或保留旧版本；不自动清理实验目录，由任务方按需清理。写入错误向外抛出，输入解与资源只读；使用独立模拟器运行，避免视频导出和其他测试抢占。此次只补真实写盘审计与清单，不代表重跑或重新验收这些研究。

## 2026-09-24 v64 球桌材质诊断写盘审计

`TableMaterialAuditTests` 仅在 `V64_MATERIAL_AUDIT=1` 或 `TEST_RUNNER_V64_MATERIAL_AUDIT=1` 时执行；默认 XCTSkip，不建目录、不写盘。输出在当前仓库 `output/table-materials-v64/<stage>/<leaf>/`，stage/leaf 支持 XCTest 去除 TEST_RUNNER_ 前缀后的环境变量，leaf 默认 UUID，目录已存在就失败。固定机位的完整 SceneKit 场景不等于页面截图；W0 模式读归档贴图做通道消融，W1–W4 baseline-only 模式捕获主题、角色与移动机位，恢复逐通道差不超过1/255（量化边缘），旧W0消融仍要求相同PNG。导出分支测试只向xcresult附图。资源只读，不写Bundle、USDZ、训练内容或历史设计基线；不能代替真机性能验收。

### V014 感觉瞄准视频专用导出（2026-09-24）

`FeelAimingVideoCaptureTests.swift` 仅在显式设置 `FEEL_AIM_DIR`（兼容 `TEST_RUNNER_` 前缀）时创建指定目录，输出 PNG、几何/投影 JSON 与 MP4；普通测试在创建场景前跳过。不回写 Bundle、Drill 或既有视频，使用独立模拟器和独立构建目录。

### 每日清台完整物理球局（2026-09-24）

DailyClearanceRulesTests.swift中的DailyClearancePhysicalGameTests默认只计算并断言，不写盘。显式DAILY_PHYSICAL_GAME_DIR（兼容TEST_RUNNER_前缀）时输出两个玩法的steps.json；推荐build/daily-clearance-interaction-v2/physical-games独立目录，不写Bundle、用户存档或设计基线。固定文件名可能覆盖同目录旧证据，调用方须选择新子目录，产物按需人工清理；写入失败抛出测试失败。

### 2D/3D 角度训练试适配（2026-09-26）

`S5_TrainingPagesLayoutUITests` 的角度试适配用例默认仅附 XCTest 截图；显式 `ANGLE_SHOTS`（兼容 `TEST_RUNNER_`）时写 `2D/3D-状态.png`。调用方使用独立 `output/angle-training-trial-20260926/<轮次设备>/`，不指向 Bundle、用户数据或历史设计基线。固定名称会覆盖同目录旧证据，复跑须换目录；写盘失败抛出，由任务方按需清理。内存数据容器、确定性题目与专用模拟器隔离训练记录。

### 2026-09-27 球杆淡出回归补充

`CueStyleTests.swift` 中的 `CueFadeRenderingTests` 写 `build/cue-fade-20260927/final-<systemVersion>/` 的前后 PNG 和 comparison.json；固定文件名复跑覆盖，失败证据须先保存，无自动清理，不写 Bundle 或内容资源。本轮失败对照保存在同证据根 first-visual-failure/。新增 2D 页面用例沿用 V52_SHOT_DIR / TEST_RUNNER_V52_SHOT_DIR 输出目录与 xcresult 附件约定。

### V019 球杆打点预览导出（2026-09-28）

`CueSpinPreviewCaptureTests.swift` 仅在显式设置 `CUE_SPIN_DIR` / `TEST_RUNNER_CUE_SPIN_DIR` 时创建调用方指定目录，无变量时 XCTSkip。调用方须使用本任务独立的 output 或 build 子目录；输出 PNG、JSON、版本文本，开启 CUE_SPIN_VIDEO 时另写 MP4。固定名称复跑会覆盖同目录产物，需保留的证据先另存或使用新目录；无自动清理，由任务方按需清理。脚本要求显式设备与输出目录，构建默认隔离在输出目录下。不写 Bundle、训练数据或设计基线，写盘失败抛出。

2026-09-28 DR-336：`AdaptiveShotControlsUITests` 使用每日清台模拟器夹具，写 `build/adaptive-controls-20260928/after` PNG 和 xcresult 截图附件；按维度/滑速/屏宽分文件。不会写 Bundle、内容真源或设计基线；同名复跑覆盖本任务图片，旧证据由任务方先保存，不主动清理目录。写盘错误抛出。launchClean/resetState会重置测试模拟器的每日状态，不用于用户真机验收。


2026-09-28 全局相机预览：Daily3DCameraPerformanceTests.swift内GlobalCameraPreviewTests仅在显式GLOBAL_CAMERA_DIR/TEST_RUNNER_GLOBAL_CAMERA_DIR存在时写本次PNG和parameters.json，写入错误抛出，普通测试跳过出图。选定C档回归本身不写盘。V52相机图标UI用例沿用既有V52_SHOT_DIR目录与隔离selection夹具，截图由既有snap写入；不操作真实用户存档。

DR-336 r2（2026-09-28）：AdaptiveShotControlsUITests截图目录改为`build/adaptive-controls-r2-20260928/after`，按维度/速度/屏宽分文件；原轮证据保留。新增瞄准慢滑/快滑精度状态与力度不被瞄准修改断言，仍仅重置测试模拟器夹具。

2026-09-29 三视角隔离：`HumanCameraIsolationTests.testCaptureHumanBaselineMatrix` 写入 `build/camera-isolation-20260929/w3/frames` 的12张PNG及参数JSON，仅使用内存场景；写入失败抛出，不清理目录，不接触Bundle、存档或设计基线。同名重跑覆盖本任务产物，最终以通过运行的日志与清单为准；历史失败日志独立保留。

2026-09-29 同文件离线隔离测试额外写 `build/camera-isolation-20260929/export-isolation` 的9张PNG（前/无操作重复/交互后），只读固定drill_c001第一杆；DEBUG诊断读取实际导出矩阵/FOV/隔离开关，不写相机；不修改旧视频或内容资产。

2026-09-29 相机回退：HumanCameraIsolationTests 随隔离方案撤出测试 target，源文件和产物留档于 build/camera-rollback-20260929/；从当前写盘清单移除该入口。GlobalCameraPreviewTests 保留 C 档基线，V52 原生交互回归使用已有 V52_SHOT_DIR 契约。

## 2026-09-30 音效本地试听取证

`ShotAudioPreviewUITests` 仅在仓库本地试听 manifest 存在时运行，向忽略目录 `output/shot-audio-preview-20260930/` 写两张 PNG；写失败抛出，复跑覆盖同任务截图，清理由本任务负责，不回写真源。测试使用模拟器的每日清台 fixture/resetState，会改其测试数据；不对用户真机执行这一 UI 测试。声音触发以同次运行系统日志另证，截图不代表主观听感。

### 每日清台 v4 连续适配（2026-10-07）

FreePlayView 生产入口维持训练首页每日清台/自由击球；每日页将原系统菜单、玩法 sheet 和 confirmationDialog 收敛为单一 DailyHUDPresentation，新增分层开球处置，未新设深链或额外导航入口。普通自由击球保留原系统 Menu。源码路由表面变化逐项核对，本轮只更新 FreePlayView 签名；UI 测试写盘为显式 fresh 输出目录，测试未默认运行整个写盘套件。

2026-10-07 B8：FreePlayView每日标题新增系统窗口控件安全区读回，仅调整标题带leading/trailing，导航目的地与非每日入口不变；核对后更新对应surface签名。
