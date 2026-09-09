# 当前剩余精确选择器审查

2026-09-07，只读 snapshot-003、REMAINING-REVIEW 与当前 COVERAGE-STATUS；未执行、复制注册或修改业务。当前覆盖表已追加千场与 DATA1 两轮 UI 证据，不应重跑这两组补旧文字中的“未验”。本文仅涉及学习、认知、工具、计划模版；不扩大设备矩阵。

## 运行前必须区分：已注册与候选草稿

实际文件枚举发现：snapshot-003/QiuJiUITests 中存在 `CurrentTrainingJourneyUITests.swift`，但尚无下述 `LearningTourDiagnosticUITests`、`CognitiveJourneyDiagnosticUITests`、`ToolDiagnosticUITests`、`AdvancedToolDiagnosticUITests`、`SolverBoundaryDiagnosticUITests`、`DetailJourneyDiagnosticUITests`、`TrainingJourneyDiagnosticUITests`、`MenuHitDiagnosticUITests` 文件。它们目前在 tasks/quality-diagnosis，是待审计复制注册的独立草稿，不能称为 snapshot003 已有可执行测试。

下述所有 UI 选择器完整形式均为 `QiuJiUITests/类名/方法名`，不带括号。主控须先核对当前工程、实际编译和 xcresult 的测试数量/方法名；make exit 0 但选中 0 tests 不算通过。只选方法，不选全类/全 target。复制注册仅在无运行任务时进行，并记录 overlay；下面的数量都是候选数，不是已通过数。

## 1 学习：21 个当前主要入口，一次普通 iPhone 巡游

候选类 `LearningTourDiagnosticUITests`。所有方法正常练习 Tab→学/理卡片→操作或下段文字→返回，不用 deeplink；每次 launch 内存 store、forcePremium。不得将只检查 slider.value 变化称为几何正确，也不得把正文片段存在称为整篇教学审核。

| 方法 | 实际断言 |
|---|---|
| testLearn01AimingPrincipleLowerContent | 厚薄球概念及下方数值片段可见，返回 |
| testLearn02AimingMethodsSlider | thetaSlider 调到 0.82 后 value 不同 |
| testLearn03AimingCorrectionSliderAndAdvice | 速度 slider 改变、实战启示下段可见 |
| testLearn04SpinStateChangesReadout | 后旋/滑动选择状态与对应文字改变 |
| testLearn05AngleDynamicDisplayMenu | 更多中网格菜单可见、退出回球库；不拖球 |
| testLearn06SeparationAtlasToggleTrack | 图例 value/selected 两次切换；图像须独立核验 |
| testLearn07CushionAtlasToggleTrack | 同上，不证明所有图谱分支 |
| testLearn08BallFeelLowerAdvice | 训练建议下段可见 |
| testLearn09ContactPointSliderAndCurve | thetaSlider 变化及 d/R 曲线标题 |
| testTheory01ThirtyDegreeSliderAndScope | slider 变化、失效边界、相关页面可见 |
| testTheory02NinetyDegreeSliderAndScope | slider 变化、不成立条件、相关页面 |
| testTheory03TangentSliderAndScope | slider 变化、易混说法、相关页面 |
| testTheory04SpeedLowerScope | 最低速度实战边界片段 |
| testTheory05BackwardPlanningLowerScope | 两球及以下规划边界片段 |
| testTheory06KeyBallLowerScope | 失位改变关键球片段 |
| testTheory07ClustersLowerScope | 球团防守价值片段 |
| testTheory08RiskLowerScope | 球数影响风险选择片段 |
| testTheory09MinimumEnglishLowerScope | 加塞后的输入端修正片段 |
| testTheory10SafetyLowerScope | 实力差下弱防守风险片段 |
| testTheory11FlowLowerConsequences | 跳步/失位后果片段 |
| testTheory12QuickReferenceLowerLines | 八句速查下段片段 |

先取 Learn01/06、Theory01/04 四个壳类型作适配小批；通过后只执行其余 17 个，不再次重复首批。既有 iPad T07 只标题/进入，不能直接冲抵本方法下段内容+返回范围。草稿中文锚点需与当前页面核对，实际 AX 仍以首次证据为准。

## 2 认知：已有六题型保存候选，缺中断方法

| 精确类/方法 | 实际范围与限制 |
|---|---|
| ToolDiagnosticUITests/testAnglePredictionAnswersAppearInHistory | 正常角度预测三个答案 17/28/39 到历史；内存同进程。旧版已做，现版需要否取决于改动依赖，不因为下五题型而整类重跑。 |
| CognitiveJourneyDiagnosticUITests/testAngle2DAnswerSaveAndHistory | 训练设置→开始→27°→返回历史恰一题、无第2题、27° |
| CognitiveJourneyDiagnosticUITests/testAngle3DAnswerSaveAndHistory | 同上，38°；forcePremium |
| CognitiveJourneyDiagnosticUITests/testAimPointDefaultAnswerSaveAndHistory | 初始偏移0mm→提交→反馈→历史恰一题及0°文本 |
| CognitiveJourneyDiagnosticUITests/testAimPoint2DDefaultAnswerSaveAndHistory | 默认初始瞄准→提交→等待验证自动下一题→退出→恰一题及0°文本 |
| CognitiveJourneyDiagnosticUITests/testAimPoint3DDefaultAnswerSaveAndHistory | 同上3D |

五个 Cognitive 方法先断言空内存历史，不修改或清磁盘记录。场景2D/3D保存按 `scene2D/scene3D` 分型；瞄准点场景按 `aimPoint2D/aimPoint3D` 分型。实际持久化由正常 VM repository 调用，但在内存容器内，不是 disk 杀进程恢复。

**当前单位风险**：snapshot003 `AngleSessionDetailView.swift:154–155` 仍统一以角度格式显示 actual/user 值。草稿明确 0° 是读回刻画，不是认可 mm 成绩用 °。零值也不能证明几何答案正确或正负偏移处理；应把真实截图关联问题/风险，不能报告“瞄准点结果单位正确”。

**没有可直接选的中断方法**：现草稿没有六类型未提交退出→无新增记录、已提交后退出→保留一次、重复结束不重复、保存失败重试的完整组合。不得把上述一题后返回叫“取消不保存”。最小新增六类型正常进入但不提交退出的参数化独立方法；已提交保存由上表承担，共享 repository 的去重/失败注入另用现有服务断言。未新增/未执行前 SC19 仍缺证据。

不要选 `V29W5ToolUsageUITests/test_geometricQuiz_threeAnswers_recordOneCognitiveSession` 替代上述结果断言：它只答45三次+等待，不读回；需要额外 SQLite 才成立，并写固定 `build/w5-screenshots` 文件名，可能覆盖旧同名证据。

## 3 工具：正常动作与边界分开计

候选最小方法：

- `ToolDiagnosticUITests/testShotSimulationStrikeAndReplay`、`testFreePlayStrikeAndReplay`：正常默认盘击球→回放→重打，实际按钮状态恢复。不是参数矩阵或音效实听。原版本已执行，只有当前相关改动才重验，其他五个“答题下一题”不再与认知保存方法重复。
- `AdvancedToolDiagnosticUITests/testComposerDefaultStrikeRedoRestoresActionStateAndReturns`：正常自由走位默认击球/重打/返回，无录制。未证明多杆编排。
- `AdvancedToolDiagnosticUITests/testSnookerDefaultSolveRespondsAndUndoOrNoSolutionReturns`：默认求解可达到有解/无解终态；有多解时实际下一解、击球/上一杆。分支实际走了哪条须按日志记录，不能一次通过同时计正负。
- `SolverBoundaryDiagnosticUITests/testBankDefaultSolutionsAndOneTwoThreeCushionTerminalStates`、`testReflectionDefaultSolutionsAndOneTwoThreeCushionTerminalStates`：自动及1/2/3库的终态，解序号真实变化；若无解则禁用下一解和击打。有解/无解皆是运行分支，不预先保证此次涵盖两者，不核对独立几何解的正确性。
- `SolverBoundaryDiagnosticUITests/testSiluMissingConstraintRemainsDisabledAfterSelectingToolAndReturns`：无落点约束禁止求解，选落点/摆球提示正确；**没有输入落点，没有完整求解**。
- `SolverBoundaryDiagnosticUITests/testPlanThreeUnfilledRoleRequestsPocketThenBallAndReturns`：未填角色禁用，选择①袋/②球出现对应指令、清空；**不是约束完整后无解**。
- `DetailJourneyDiagnosticUITests/testC042TutorialTwoFormationsKeepDistinctPostersAndReadingPosition`、`testC042BothTryoutBoardsStrikeUndoAndRearrange`：正常库进入 c042 两球形精讲/试打、海报区分/阅读位置/击球重打重摆；不复制素材、不录制。

**仍无强现成方法**：思路/三球的正常角色和盘面约束输入→可行解及明确无解、多杆编排的下一杆/撤回。旧 `W8_TrajectoryScreenshotUITests/testW8PlanThreeTrajectoryWithConstraint` 只条件式点击求解、无解结果断言；`testW8SiluTrajectoryWithConstraint` 猜屏幕坐标并条件式点击，且固定外部 worktree 输出，不可当其替代。`X3_BreakFlowUITests` 是旧深链开球交付截图而非求解正负验收，亦不应直接补全此缺口。

## 4 计划/模版：优先真正创建路径，避免重复夹具

候选正常入口方法：

1. `TrainingJourneyDiagnosticUITests/testNormalOfficialPlanActivationArrangementAndStart`：plan_beginner正常激活→编排当前课→加入今日0/1→开始出现timer。内存真实操作，无已编排夹具；不保存课程、不验证A→B→A或连续游标。
2. `MenuHitDiagnosticUITests/testTemplateEmptyShelfCreateSaveAndReopen`：空模版货架→新建唯一名+c012→仅保存→卡片重开字段一致。普通内存同进程，不是磁盘重启；可替代重复的 `TrainingJourney...testNormalTemplateNameAndDrillSaveAndReopen`，后者从 more 菜单进入，已存在历史 isHittable 失配。
3. `MenuHitDiagnosticUITests/testVisibleMoreMenuRespondsAtItsActualFrameCenter` 仅在仍需归因旧 more 命中失败时选；它是观测中心触摸，不建模版。`testTemplateShelfSaveAndReopenWithObservedNavigationTouch` 也仅做导航命中归因，不能把它与普通方法叠加计两个独立创建旅程。
4. `TrainingJourneyDiagnosticUITests/testDailyClearanceNormalStartReturnAndResume`：要求当天未开始，真实自动开球等 HUD→返回首页进行中→再次进入。**需要未用过每日清台的专用 guest 设备/当日**；`-v50.inMemoryStore` 不保证 DailyClearance 的独立状态存储为空。禁止加 reset 改写已有证据。只覆盖开始/恢复，未覆盖完成/失败结局。

snapshot003 已注册 `V54ScheduleUITests/testV57PlanShelfShowsSavedStatesAndCanSwitch`、`testV57TemplateBodyEditsAndMenuAddsOnce` 都是既有 v54 状态夹具；前者支持切换 UI，后者仅打开编辑和菜单去重，不等于新建后编辑字段保存。它们旧证据已在覆盖表，不能再整类运行后声称正常计划/模版全链完成。新模版编辑→加入今日→删除→历史来源保留的连续旅程仍需独立补法。

`V52DailyClearanceUITests/testCompletedReplayPreservesCompletionAndStartsAnotherBoard` 可作为完成态**夹具** replay 边界，但其 launch 明确 `-dailyClearance.resetState` 和 completed/fixtureSettled，写专用清台状态；若选必须全新指定诊断设备，绝不复用当前证据设备。它不能证明通过正常击球赢得清台，不是此处正常路径的替代。

## 副作用与运行底线

已审上述 tasks 草稿没有删除正式内容/录制/导出资产调用；键盘 delete 仅清空新建模版名称字段。Learning/Cognitive/Tool/Solver/Advanced/Detail/MenuHit 普遍用内存 ModelContainer，但正常偏好、Pro持久开关、独立工具/清台状态仍可能写专用 App 沙盒。只使用诊断设备，截图目录每 RUN 唯一；不推断 inMemory 意味着完全无副作用。

输出需要 `QD_SHOT_DIR` 或 `TEST_RUNNER_QD_SHOT_DIR`，不存在即 fail，不能用空路径让附件静默缺失。所有候选执行结果需真实非零测试数、精确方法和退出码，再附图/AX独立检查。出现明确产品失败可结束对应问题诊断并继续其他方法，不必反复修测试直到全绿。
