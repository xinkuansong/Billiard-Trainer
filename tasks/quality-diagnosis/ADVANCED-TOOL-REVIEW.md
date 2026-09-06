# 高级工具正常UI诊断草稿审查

2026-09-05；依据snapshot-002；未编译、未运行、未操作模拟器。只写独立测试草稿与本说明。未修改 `ToolDiagnosticUITests.swift`。交付**2条候选方法**，其余2工具存在明确设置与可观察性阻碍，不用仅点击标题或XCTSkip凑覆盖。

## 建议候选选择器

```text
QiuJiUITests/AdvancedToolDiagnosticUITests/testSnookerDefaultSolveRespondsAndUndoOrNoSolutionReturns
QiuJiUITests/AdvancedToolDiagnosticUITests/testComposerDefaultStrikeRedoRestoresActionStateAndReturns
```

依赖现有 `XCUIApplication.launchClean`、`switchTab(.angle)` helper；正常入口是练习Tab的“解→防守”“打→自由走位”。沿用专用无真实凭证模拟器、inMemoryStore、既有forcePremium fixture；不能把此批当Free门控验证。每次启动新App进程，串行，截图只落主控指定 `QD_SHOT_DIR`（同时支持TEST_RUNNER前缀）及xcresult附件。执行前将草稿与冻结业务hash一同登记；两方法非零执行数才可计实测。

| 方法 | 实质动作/断言 | 证明边界 |
|---|---|---|
| 防守 | 求解前击球/上一杆禁用→点击求解→等待状态改变且退出busy；若无解则无解文案+击球/下一解禁用；若有解则击球可用，多解时点击下一解并断言解1→解2；击球结束→上一杆→恢复提示、撤回/回放禁用、击球可用；正常返回入口 | 有解/无解是动态分支，**只证明默认题面的反馈与操作一致**，不证明默认盘面必有解或无解正确。无解分支未执行撤回、多解不足时未执行下一解，要按截图stage分项登记，不将方法通过外推为所有分支通过。不能证明防守100%遮挡或物理合法首触。 |
| 自由走位 | 默认未录制盘面可击球；击球后重打/回放可用；点重打后二者禁用、击球重新可用；正常返回 | 验证未录制单级重打状态，不证明多杆编排录制/导出/持久化。截图留给主控对比盘面，但脚本没有球位数值AX断言，不宣称所有球坐标已恢复。回放本身未点击。 |

## 源码前提与安全审计

源码路径均省略 `build/quality-diagnosis/snapshot-002/`。

- `SnookerTacticsViewModel.swift:160–181`默认母球、1/2/9/10在台，目标1号；`:86`有目标且对方球非空即可求解。页面 `SnookerTacticsView.swift:189–216` 正常求解/下一解/击球/上一杆绑定VM；`ViewModel:387–428` 调用本地 `PositionPlaySolver.solveSnooker`，无结果有明确文案；`:461–468`多解状态前缀“解N/总数”；`:733–744`撤回后明确状态和标志。草稿没有调用`:917`起的诊断种子入口。
- `PositionPlayViewModel.swift:184–206`默认母球+1/2，自动选袋并recompute；`:108`isRecording初始false；`:1182–1195`仅recording为true才appendRecordedStep，本草稿从不打开录制；`:1304–1329`未录制重打使用lastShot单级恢复，清除canReplay/canPlayback。`PositionPlayComposerView.swift:327–339`按钮名是“重打”，并非“上一杆”。不要按其它工具的名字误判缺按钮。
- `BTShotPageChrome.swift:175–233`动作/求解按钮禁用是VM状态的真实绑定；`:318–326`状态字幕有 `navStatus.subtitle`，可读取实际label，不依赖短暂的求解中文字闪现。
- 本批不做摇杆/球桌几何坐标推断，不点击开球、拍照交付、更多、命名、清空、录制/制作入口。算法与场景局部状态在内存；宿主默认Auth仍可能读Keychain，因此专用无凭证宿主是前提，inMemoryStore不等于网络隔离。

## 暂不能可靠写成短自动化的两项（不计执行样本）

### 思路训练 SC22

默认只有母球(.30,.30)、1号(.62,.20)，自动选目标/袋，但**没有约束**：`SiluTrainerViewModel.swift:56/139–157`；`SiluTrainerView.swift:250`明确 `hasConstraint` 才能求解。因此“进入→点求解”会卡在禁用控件，不是产品缺陷。

正常流程必须选择约束工具后在球桌画线/区，`SiluTrainerView.swift:158`起 `SolveConstraintDrawingOverlay` 依赖sceneFrame和projector.unproject。当前代码检查未得到可直接读出的球桌世界坐标或独立可访问性球实体标识，不能凭整屏固定百分比可靠画出同一个求解问题，尤其导航栏/视口会变化。纯画一个大圈再接受任意结果，无法证明约束落在有效台面、也可能只是UI没画上。

后续最小补验：先正常入口实际取AX树/截图，确认球桌可定位区域；按冻结投影转换数值构造一个合法、可重复的区域拖动，保存手势起止点和实际形成约束证据，才写“有约束→求解结果→下一解/击球→撤回/返回”。已知不可达区需要独立的几何与solver证明，不能仅看到降级文字称无解正确。本轮没有种子注入或假模型。

### 打一走二想三 SC22

`PlanThreeViewModel.swift:283–294`默认四颗目标球，但只把armedRole置为ball1，没有填①球/①袋/②球/②袋/③球；`:608` `currentConstraint()!=nil`才可求解。`PlanThreeView.swift:290–345`角色chip只进入等待点击的角色状态，不会自动选中盘面实体。直接点“求解”或依次点五个chip无法完成配置。

正常UI要依次点角色+正确球/袋，再完成落区约束；SceneKit实体命中依赖投影，缺稳定球/袋AX实体。未实际读树/取图前，不起草凭空坐标点击脚本，不用preset或启动种子“喂绿”。后续要保存五角色实际标签/所选球袋及约束，再求解；第三杆目标是否可打还须依据真实终位独立计算，标题可见不算覆盖。

## 执行时的误判风险

- 默认防守solver若超过60秒，本草稿失败并保留原日志；不能加无限等待掩盖性能问题。60秒是诊断预算，不是产品SLA。
- 无解分支的“通过”仅是反馈一致；主控必须写明实际分支。若要固定正例/无解正反对照，需要另行构造正常UI可设置盘面及独立可解性证据。
- 多解状态必须实际从“解1/”切换“解2/”；按钮存在但禁用不算下一解完成。单解允许但单列缺口。
- 当前草稿导航断言依赖navigationBars[title]；若toolbar principal合并使名称不同，先看AX树确认页面与正常返回控件，判测试定位问题，不改业务导航或扩大随意点击。
- 截图输出是诊断证据写盘；所有业务/内容/序列资产无写回。不得把未录制击球重打称为完整编排功能验收。

验收状态：SC21补到“自由走位默认击球+单级重打草稿”；SC22补到“防守求解反馈/条件下一解/条件撤回草稿”。思路与三球逆推UI仍缺正常盘面设置证据。两方法均未执行，当前没有新增测试通过结论。
