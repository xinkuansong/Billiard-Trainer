# 主工作区相对B0的当前变化观测

2026-09-06。清单实际来源`build/quality-diagnosis/b0/formal-baseline.json`的`files`字段，不是名为.files的文件。哈希观测窗口 **02:58:55.844257–02:59:06.442683 +08:00**，逐项比对4841个相对路径；完整原/今SHA256、时间、分类、缺失与二次复查保存在`build/quality-diagnosis/current-drift-observation.json`。

**这只是并行开发中的一次观测，不是当前工作区冻结、不是全量重测，也不能把snapshot-002诊断结论自动迁移为“当前版本已验证”。** 未变更任何snapshot、业务文件、设备或测试。只对baseline列出的对应路径扫描，不包含baseline之外新文件清单；文件不存在不等于产品资产缺失。Secrets/配置没有输出值，内容只做哈希，未读取展示任何凭证。

## 数量与业务分类

4841项中29项不同：20个App源码、6个测试路径（5变更+1缺失）、3个工程/构建配置；对应清单内内容/资产、文档/规则未发现哈希变化。读取期间没有检测到单文件stat变化，已变化文件在分析后二次哈希亦未再次变更；但此操作不是跨文件原子快照，后续仍可能变化。

| 类别 | 实查变化与影响 |
|---|---|
| 球库/工具布局，15个源码 | `Core/Components/BTBallPaletteBar.swift`行间距3→0；`ShotTableLayout.swift`球库最大宽440→8×44=352。13个页面/壳统一使用proxy.libraryWidth而不在invalid时fallback整场景宽：AimPointSceneTrainingView、AngleDynamicView、CushionEnglishAtlasView、SceneAimingView、SeparationAngleAtlasView、ShotSimulationView、SolverStageChrome、BatchAuthoringView、FreePlayView、PlanThreeView、PositionPlayComposerView、SiluTrainerView、SnookerTacticsView；其中AngleDynamic还跟随统一rowSpacing。合计这组实际15个文件（两公共组件+13消费者），并不改变求解引擎算法。影响SC19–22/34的球库空间、命中区、拖拽及B5矩阵可复用性；制作页BatchAuthoring依旧不纳产品正常旅程。 |
| 休息计时，2个源码 | `Core/LiveActivity/RestTimerLiveActivityManager.swift`新增可注入协议，LiveActivity更新完整state；`Features/Training/ViewModels/ActiveTrainingViewModel.swift`新增可取消restCompletionTask、防过期加时复活、now注入、stop取消异步completion。影响SC10/38与活动训练/休息浮层矩阵，须当前版本定向重新验证。 |
| 账户fixture，2个源码 | `Data/Services/APIClient.swift`只在DEBUG且-v53.authenticatedProfileFixture时直接抛离线错误；`AuthState.swift`该fixture新增-v57.longProfileName长名。不是普遍禁网，也不是正式鉴权修复。会改变账户fixture图审/离线表现，不能外推真实登录。 |
| 已登录个人页，1个源码 | `Features/Profile/Views/ProfileView.swift`调整header为纵向结构、长名换行及Pro信息区域。影响已登录/长名/Pro布局；M2游客根页不构成该新header验收。 |

源码变化合计**15+2+2+1=20**，以JSON逐路径清单为准。

## 既有问题影响

| 问题 | 当前观测是否可能改变判断 |
|---|---|
| QD-007 PUT owner覆盖 | baseline内相关backend路由未变化。APIClient变化仅诊断fixture离线阻断，未修复后端权限。冻结路由复现仍有效；当前服务部署状态未验证。 |
| QD-008 501/1000恢复截断 | baseline内相关后端路由与恢复消费未变；本次APIClient局部DEBUG分支不能修复分页。保留缺陷，不推断真实服务现状。 |
| QD-012 提前结束全计划组落库/全绿勾/统计分母 | ActiveTrainingViewModel有变化，但本轮审阅diff集中休息计时、注入和取消任务，保存组循环没有改动；DrillSet/历史/统计对应文件哈希未变。因此未看到直接修复证据，不能销账；因为相同VM已有变化，现版仍应定向跑提前保存旅程后才赋予当前版本复现结论。 |
| QD-013 c070自相矛盾 | 对应内容、精讲/序列/资产的baseline路径未变化，没有修复证据。 |
| QD-014 c022力度、QD-015 c042方向、QD-016 c085方向/皮头 | 对应内容与序列未变；工具页球库布局变化不等于修改教学图几何。既有抽样仍属于snapshot，不声称已对当前所有图复看。 |
| QD-017 c065/c070剂量预期 | 对应内容与契约文档哈希未变，本次休息计时调整不裁定训练剂量；保留预期待确认。 |
| QD-018 中袋旧坐标文档/工具漂移 | 已比较的table-geometry规则与相应内容路径未变。ShotTableLayout变化是屏幕排版宽度，不是球桌米制中袋坐标修复，不能混同。 |

本轮AX5搜索图标裁切线索所涉及BTLibrarySearchBar及Typography在对应baseline路径中未变化；这只是无直接变更迹象，不是当前全App辅助字号复验结论。大批球库布局变化与B5工具矩阵相关，应优先防止将旧截图作为当前布局证明。

## 测试/配置不冒充业务改动

- 5个已改变测试：`QiuJiTests/ActiveTrainingViewModelTests.swift`、`V51ResponsiveLayoutTests.swift`、`V53ProfilePreferencesTests.swift`；`QiuJiUITests/P2_DataLayerUITests.swift`、`W4_BallPaletteUITests.swift`。它们本身不是产品修复证据，未执行或审其新断言有效性。
- `QiuJiUITests/QualityDiagnosticUITests.swift`在当前主工作区不存在：它是正式baseline含入的独立诊断测试，不应报告为用户可见页面或资源丢失。任务目录诊断稿与正式overlay另有归属。
- `project.yml`增加UI runner复用Products.storekit资源；工程pbxproj和scheme也有差异。冻结工程已含诊断装配差异，不能把所有生成文件diff归因于并行业务开发。配置改变可能影响测试资源/host行为，正式结论必须继续绑定原输入指纹。未输出Config/Secrets值。
- baseline未列的新业务文件、新文档或其他目录不在此轮覆盖；没有出现在snapshot的文档不能据此判断主工作区原文缺失。此报告不审并行工作的合理性、不要求回滚或停止他人任务。

后续若要对“当前App质量”下结论，先由主控选定新的观测/冻结边界，按球库布局、休息计时、已登录header三组做定向复验，再复用未变依赖的旧证据。当前阶段继续保留snapshot-002正式结果，不混用源与截图、不自动重跑整包。
