# 高级工具边界正常 UI 补充

状态：新增 `SolverBoundaryDiagnosticUITests.swift`，4条独立草稿；只读snapshot-002，未编译、未运行设备、未实际查看本批截图。未改AdvancedTool已交付文件、业务实现或资产。

## 方法与真实可观察断言

选择器前缀 `QiuJiUITests/SolverBoundaryDiagnosticUITests/`；实际target沿用主控正式UI harness配置确认。

| 方法 | 正常操作与断言 | 不能计入的覆盖 |
|---|---|---|
| `testSiluMissingConstraintRemainsDisabledAfterSelectingToolAndReturns` | 练习→解→思路训练；默认求解/下一解禁用。点“落点”后精确等待“点按球桌标出母球期望停的落点（琥珀十字为目标，环为命中容差）”，求解仍禁用；点“摆球”恢复提示；返回解入口。默认、选工具、恢复均截图+AX。 | 仅工具模式变更，没有点桌、形成约束、保存落点或求解。缺少稳定球桌AX及投影坐标，不猜坐标。 |
| `testPlanThreeUnfilledRoleRequestsPocketThenBallAndReturns` | 默认求解/下一解禁用；点①袋等待“点袋口，设为①一号球目标袋”；点②球等待“点桌上的球，设为②二号球”；求解持续禁用；“清空计划”回①球提示；返回。各阶段截图+AX。 | 选role chip只改变等待角色，没有填入具体球/袋/约束。默认armedRole为①球但角色尚未赋球；不能把“选中角色”误称“完整设置三球”。 |
| `testBankDefaultSolutionsAndOneTwoThreeCushionTerminalStates` | 正常进入翻袋解球器，默认自动求解等待合法终态；有多解实际点击下一解，验证编号按N取模前进且总数保持；依次1/2/3库，解状态必须以对应“N 库”开头，检查击打/下一解使能与多解文字一致；无解则精确文案+击打/下一解禁用；最后自动并返回。 | 无解不是数学不可行证明；单解/无解不计下一解覆盖；不验证路线几何、真实进袋、力/塞/障碍物与解质量。 |
| `testReflectionDefaultSolutionsAndOneTwoThreeCushionTerminalStates` | 同上，使用反射解球器自己的无解文案。 | 同上；自动/手动库数是解集过滤，不代表每次重新运行物理引擎。 |

## 冻结来源

以下相对 `build/quality-diagnosis/snapshot-002/`。

- `QiuJi/Features/AngleTraining/Views/AngleHomeView.swift:227–234`：四页实际在“解”入口，思路Free、打三Pro。草稿沿用`launchClean`+`-v50.inMemoryStore -forcePremium`，验证内容入口与功能，**不验证收费权限**。
- `…/PositionPlay/Views/SiluTrainerView.swift:123–147,249–253`：落区/落点/过点/摆球绑定activeTool；求解按hasConstraint门控。`…/ViewModels/SiluTrainerViewModel.swift:52–56,1097–1104`：选工具更新精确提示，不自动生成约束。
- `…/PositionPlay/Views/PlanThreeView.swift:286–312,341–348,354–358`：role芯片组合Text/Image；无独立AX ID。测试按包含①袋/②球的按钮查询，要求恰好一个，不能随意firstMatch猜中。`…/ViewModels/PlanThreeViewModel.swift:449–453,521–529,608,772–779`：armRole只设置等待角色，clearPlan清全部角色，canSolve来自currentConstraint。
- `…/AngleTraining/Views/SolverStageChrome.swift:178,210,227–236,394–415`：navStatus副标题、solver.mode、库数按钮、击打canStrike、solver.nextSolution；下一解只有多解且非播放才使能。
- `…/ViewModels/BankShotViewModel.swift:858–862,880–891,925–952,1075–1110`：selectCushions触发缓存/求解，过滤displayed；自动模式尽量保留原库数的解，**不能一律断言自动返回解1**。草稿解析实际解i/N后断言下一解i%N+1；手动库数才断言初始解1。无解精确分自动/手动。贴库专用文案不是默认球形，本批不宽泛接受所有“无解”文本。
- `…/ViewModels/DiamondSystemViewModel.swift:821–825,844–851,886–913,1013–1038`：同样缓存和库数过滤/自动保留语义；无解文案与翻袋不同。
- `QiuJi/Core/Components/BTChipRow.swift:36–65`：chip具有`shotStage.chip.i`，选中仅颜色背景，没有selected AX语义；`BTShotPageChrome.swift:303–325`：忙状态副标题可以读到“真实物理求解中…”。因此草稿不强制捕获瞬时busy（缓存命中可直接完成）。

## 防止误判与执行记录

- 终态等待只接受对应库数的解读数或对应页精确无解文案，拒绝忙、演示、自由模式/任意非空文字；随后核对动作按钮。多解必须真实点下一解并看到序号变化，不能“按钮存在”算核心覆盖。
- **仍有可观测性限制**：库数chip无selected AX。若连续两个过滤结果都是同一无解文案，或自动解恰好与新选库数相同，不能仅凭相同终态证明此次选择生效/新请求完成；主控必须查看该阶段截图选中chip与AX操作证据。若选中状态无法确认，标“终态一致、切换生效未确认”，不能记整项通过；不引入猜坐标或硬睡眠制造假同步。新请求generation没有公开AX，异步迟到响应不在本批证明范围。
- 每阶段截图与完整AX同时作为XCTest附件和`QD_SHOT_DIR`（或runner前缀变量）下随机文件保存，路径由主控专用run目录提供，缺路径明确失败；没有默认写回正式目录。AX不含登录凭据，本批只访问工具页。
- role芯片若实际AX无法找到或不唯一，默认截图已留；按测试定位阻碍记录，不能改为点屏幕比例位置喂绿。场景拖动、球/袋身份、投影矩阵及有效约束仍需另行受控方案。
- 四方法分别登记实际分支（多解且下一解/单解/无解），测试方法通过不能折算“所有正例负例求解完成”。截图文件名已区分next-unexercised、actual-next-solution。不预先保证默认必有多解。
- 本批不点击击打、不录制/出片/分享/恢复业务资产。退出可能按正常toolUsageSession记录工具活跃，使用专用无凭证模拟器及内存参数；不能把内存参数理解为UserDefaults和宿主初始化完全无副作用，沿用主控已审计隔离策略。

## 未解决的完整正负求解矩阵

思路：合法落区/落点/过点实际生成约束、求得解、不可达约束的无解、撤销与清约束后轨迹消失仍未覆盖。打三：球1/袋1/球2/袋2/球3完整赋值、扇形方向、pot-only分支、约束生成、正负求解、打完前滑/撤销仍未覆盖。翻袋/反射：只核查默认球形的状态、库数读数与解导航；路径几何和物理可行性需数值真源+独立空间断言或专门回放证据，本批截图不能替代。
