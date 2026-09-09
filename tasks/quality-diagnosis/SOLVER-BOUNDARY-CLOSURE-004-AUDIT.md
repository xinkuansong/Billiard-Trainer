# L6 求解与遮挡证据收口审计

2026-09-08；仅只读审计、新增本文，未运行测试或操作设备。核原 COVERAGE-PLAN SC20/22及“每工具至少正常与边界/无解样本”、B3-PREPARATION/B3、冻结004具体测试体、004求解原始日志及最新SILU-SHOT-004-RESULT。没有将每工具每模式出现空数组新增为验收要求。

## 结论先行

思路、三球、翻袋、反射、防守均已有**正常及某类明确边界**的分层证据。思路/三球完整输入返回最近解，必须记“不满足落区”的边界，不能叫成功，也不能叫空数组。SC22“可行/无解落区”的“落区无满足解”已有U+UI证据；若专指完整合法盘面返回零候选，当前未覆盖，但原文没有要求每页每模式都出现这一表示形式，无须继续盲搜空解。

仍有一个不能凭现有报告核销的原明确子项：**半遮挡/部分可见的独立数值判例**。已有完全挡死与另一个完全无遮挡，不等于同一目标仅部分可见。应先找原执行证据；确无则只补一个独立几何对照，毋须重跑求解/射击长链。B3原始运行文件当前未找到，全部历史单测执行结论须标H，不能说本次重新检查了原日志或004重新跑过。

## 旧B3执行可信度与真源

B3.md记FORMAL-B3-001 31/31、make0、用例5.481s；B3-PREPARATION列34精确方法，B3说明3个内容方法已在B1执行，因此不重跑。本文在 `archive/quality-diagnosis` / `build/quality-diagnosis` 文件列表未找到formal-b3-001/003/004/005的原log/argv/selector JSON，故只能引用报告级历史实测。未找到不等于未执行。

已实际SHA比对004以下测试体与B3-PREPARATION记录**完全一致**：PositionPlaySolverTests `52a45315…45e`，SnookerSolverTests `83e55a0b…5d9`，BankKickDifficultyTests `891b2ccb…d51`。这允许精确解释当时选中方法断言，但不证明两版生产引擎全部相同，也不把旧31方法变成004执行。下面所有U坐标均为测试源码字面输入，本文未重新计算或执行几何。

## 精确方法、输入、断言映射

前缀 `QiuJiTests/`；源位于 `build/quality-diagnosis/snapshot-004/QiuJiTests/`。

| 方法（B3-001已列入，H） | 实际输入与关键断言 | 能核销 / 不能外推 |
|---|---|---|
| PositionPlaySolverTests/test_region_circle_signedDistance_goldenSamples | 圆中心Canvas(.5,.25)、半径.1；scene圆心/边界/外点，断言signed distance=-.1×scale、0、.5-.1×scale及contains真假，精度1e-4 | 独立字面距离/内外金样；不是全部Region形状或三球扇形精度。 |
| PositionPlaySolverTests/test_restRegion_pottable_landsInRegion_andSorted | cue(.5,.35)、_1(.5,.15)、topCenter，圆(.5,.25),r=.4；粗网格x/y塞[-.3,0,.3]、速度1…5步1。必须非空、至少一satisfied、库数非降、satisfied必potted且margin≥-1e-4 | 可行落区及进袋/余量。finalPositions母球验证用了`if let`：若缺终位会跳过contains，不能声称每解终位存在均被强验；不是独立真机物理。 |
| PositionPlaySolverTests/test_restRegion_unreachable_returnsClosestDegraded | 同cue/target/pocket，圆中心(1.5,.25)台外,r=.02；必须恰1候选、satisfiesConstraint=false、margin<0 | **无法满足落区**有非空降级且不虚称成功，明确满足SC22负落区语义之一。不是空数组，也不是缺输入禁用。 |
| SnookerSolverTests/test_solveSnooker_invalidInputs_returnEmpty | 缺cue；有cue(.3,.25)/_1(.6,.25)/_9(.7,.30)但对方组空、包含自身目标、或_10不存在；四次均isEmpty | 防守非法输入边界；不证明完整合法盘面无可行防守解。不能冒充思路/三球“无解落区”。 |
| SnookerSolverTests/test_defenseCoverage_multiBallSample | scene cue=(0,sY,0)，对方_9=(1,sY,0)，_10=(0,sY,1)，blocker_2=(.5,sY,0)。逐ID断言_9 blocked=true/difficulty1，_10 blocked=false/difficulty∈[0,1] | 独立完全阻挡与无遮挡样本，避免只信UI“完全斯诺克”；**并非半遮挡**。源码注释把+Z叫“正上”不作为本审计屏幕方向结论。 |
| BankKickDifficultyTests/test_solveBank_typicalBoard_sortedAndAssembled | scene cue(-.5,sY+R,-.2)、object(.1,sY+R,.1)、pocketIndex1、power3.6；非空、数量上限、goodness升序、每解simObjectPotted、cushions≥1、最终库序字段一致、无错误扎库前缀 | 引擎终验/上屏结构一致性，非只有排序空循环；不证明所有独立反射角金样或真台误差。 |
| BankKickDifficultyTests/test_solveKick_typicalBoard_sortedAndAssembled | cue同上，target(.4,sY+R,.25)、power3.6；非空、数量上限、goodness升序、每解kickContactMade、cushions≥1 | 反射解真实管线接触结果及正常排序；无空解分支。 |
| BankKickDifficultyTests/test_ghostAlongFinalAim_straightOnGold | cue(-.5,sY+R,0)、target(0,sY+R,0)、aim(+1,0,0)；ghost非nil且x=-2R,z=0，1e-5 | 独立直球接触点字面金样；不能叫“全/半遮挡全验”。 |

B3-001还选两条SeparationAngleAtlasTests：`testPathSlice_startsAtBallBall_endsAtFirstCueCushion` 与 `testPathSlice_lowPowerDraw_noCushion_fallsBackToStopPoint`；其用途为事件切片起止和无库时停点fallback，不能替代遮挡或落区无解。本轮不扩大到所有物理tests重新执行。

## 当前004日志可以直接核对的UI

下表R=`archive/quality-diagnosis/runs/`，均实际读取xcode-test.log通过行；输入/结果对应TOOL-CONSTRAINT/SOLVER-FILTERS/SILU专项结果，图审采用主控记录。

| 域/精确selector（QiuJiUITests/） | 实际运行及关键断言/分支 | 正常+边界结论 |
|---|---|---|
| SolverBoundaryDiagnosticUITests/testSiluActualRectangleConstraintSolve | R/formal-004-tool-constraint-positive-001 log:734，34.381s；实际黄球/左上袋、矩形(105,310)–(295,640)，5解，清约束后求解/击球禁用 | 正常完整输入与清除边界。 |
| 同类/testSiluActualRestPointCandidateSolve | R/formal-004-tool-constraint-followup-001 log:797，28.140s；完整目标/袋、实绘落点(110,660)，6个最接近解、首解距目标141cm/容错0% | 完整输入后未满足边界，绝非零解；与U台外不可达降级相互补充。 |
| SiluShotDiagnosticUITests/testObservedRectangleNextSolutionStrikeAndUndoRestoresBoardAndSolutionIndex | R/formal-004-silu-shot-001 log:636，61.355s；同矩形2/5→真实击球→上一杆还原原cue/_1 frame及按钮→无重解3/5；主控4图核黄进袋、母球在矩形 | 原正常切解/实打/恢复已补齐。2pt重复投影/屏幕包含不外推厘米精度。 |
| SolverBoundaryDiagnosticUITests/testPlanThreeActualFiveRolesDefaultSectorSolve | positive001 log:562，48.307s；①黄/左中袋、②蓝/右上袋、③红五角色完成；默认扇形最近解4库、余量4cm但不达4×.04m门槛 | 三球完整默认约束的明确未满足边界；没有把“在区域内”直接当satisfied。 |
| 同类/testPlanThreeFiveRolesCustomRectangleStrikeAndUndo | followup001 log:656，73.859s；五角色+矩形(105,310)–(295,630)，6解、实打黄入左中、角色前移、上一杆恢复；真实母球框含于矩形 | 三球可行样本/实打/撤销；不再额外要求默认扇形必须另造满意样本才结束正常+边界层。 |
| 同类/testBankDefaultSolutionsAndOneTwoThreeCushionTerminalStates | R/formal-004-solver-filters-002 log:560，63.984s；自动2解→1库2解切2→2/3库真实无解、击打/下一解disabled→自动恢复 | 真正空候选UI已在翻袋出现；只属于翻袋，不挪用到所有工具。 |
| 同类/testReflectionDefaultSolutionsAndOneTwoThreeCushionTerminalStates | 同run log:844，69.715s；自动16、1库10、2库5、3库1（下一解disabled）、回自动16/16→1/16 | 正常多解+单解不可切/循环边界，满足“边界/无解”的边界支；无需强制再搜一个反射空解。 |

旧B3-005 `AdvancedToolDiagnosticUITests/testSnookerDefaultSolveRespondsAndUndoOrNoSolutionReturns` 报告81.516s，6解1→2/击球/上一杆/返回，原7图主控已审但目前原件未找到。其无解if分支当时未走；配合上面H非法输入/完全挡死与无遮挡测试，防守已有正常与边界。不能用其方法名的OrNoSolution推定两分支都跑过。

旧B3-003/004 `ToolDiagnosticUITests/testBankSolverModeStrikeUndoReturn`、`testReflectionSolverModeStrikeUndoReturn` 对应实际模式切换、击球/上一杆/返回；B3-004报告反射16解。保留H旅程，不把004最新筛选方法未击球解释为整个反射从未击球。

## 存在但不能当执行证据的测试/弱断言

- `PlanThreeSectorSolverTests/test_sectorRegion_satisfiedSolutionsRestInsideSector`：cue(.5,.36)、_1(.5,.16)、_2(.3,.3)，②袋0生成扇形；必须sols非空，但只对`satisfiesConstraint`子集循环，不要求至少一个satisfied。本轮B3精确清单未选它、未找到其正式终态，因此既不能计已执行，也不能用其标题声称扇形满意正例。
- `SnookerSolverTests/test_snookerCoverageMulti_singleBallRegression`：同轴cue0/target1/blocker.5对照single/multi、margin3.286±.1，以及远blocker1.5不挡；不在B3本批所选，不由文件整体存在计通过。即使执行也仍非半遮挡。
- `SnookerSolverTests/test_solveSnooker_satisfyingSolutions_passReCheck` 有非空及每解首触/不scratch/真停，完全解复核是条件循环，无至少一个full断言；`test_solveSnooker_degradesToHighDifficulty_whenNoFullSnooker`允许空数组且子集断言近同义。均未找到本批精确执行，不能取名字补缺口。
- 单纯`testSiluMissingConstraint...`/`testPlanThreeUnfilledRole...`只缺输入禁用，不属于完整约束不可达；旧W8条件点击/截图不补这项。

## 原SC22“可行/无解落区”如何落账

可以写：可行落区U与UI已验；不可满足落区U强制降级且UI思路/三球明确最近解已验；下一解/实打/恢复具分层证据；真正空数组在翻袋UI、防守非法输入U出现，**完整合法思路/三球盘面零候选未验**。这是准确覆盖状态，不把closest改成empty，也不把后者强制提升成每页的新增必过组合。

必须保留的数值缺口是半遮挡：原SC22明确“全/半遮挡”，H multiBall只有完全挡与完全可见两个不同目标，当前UI标签未独立测量可见角。现有公开证据不足以核销。最小下一动作仅一条独立几何对照（完整挡死 / 部分可见 / 完全可见），先读实际coverage计算契约和球半径，用独立角区间计算预期，再查其精确旧run；有旧真证据则引用，无则准备一个只读数值诊断。不能直接选整个含截图/性能类；不能以“blocked=false”独自证明部分可见。本文不新增该测试，也不声明它执行。

除此之外，不需以默认扇形满意、反射必空解或无界落点搜索阻止本轮L6诊断收口。物理全参数/真实台球精度仍按原分层局限记录，而非把所有未证明的全称命题转成无限本机任务。
