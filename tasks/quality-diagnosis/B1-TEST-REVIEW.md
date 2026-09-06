# B1 UI 诊断草稿前提审查

日期：2026-09-05。依据：PLAN-v2 与 COVERAGE-PLAN 的 SC05/09/12；审查对象 `tasks/quality-diagnosis/QualityDiagnosticUITests.swift`。本次只读 UI/VM/helper/内容源，没有修改 Swift、运行测试或操作模拟器。正式结果必须归属主控新建的 snapshot-002；snapshot-001 及探索运行不自动沿用。

## 结论

草稿建立了有价值的“正常入口→保存→终止进程→历史读回”骨架，但不宜直接把运行结果判为 SC05/09/12 整包通过。先修正测试前提、唯一记录辨识和休息/键盘处理，再执行方法试运行。以下是测试资产风险，尚不是已复现 App 缺陷。

| 审查项 | 代码证据与风险 | 建议改法（仅建议，未改） |
|---|---|---|
| **初始磁盘与账号不确定** | 草稿 `:68` 调用 launchClean；helper `QiuJiUITests/Helpers/XCUIApplication+Extensions.swift:52` 起只设中文、跳引导、resetDebugPremium，并不清 SwiftData、Keychain、owner 或已有活动。方法名 Clean 不代表空数据库。已有主线/记录可改变 freeTraining CTA，重试旧记录可造成假绿。 | 用专用模拟器/独立安装容器准备 DATA0，执行前证实游客、空历史和无活动；仅在首次运行前初始化，保存后重启绝不能清容器。不得卸载共享用户 App。每次运行生成独特 note 标记，例如 run ID + UUID。 |
| **选择动作依赖列表可见性** | `:72`–`:74` 等待“添加中袋直线出杆”存在后直接 tap，没有搜索/滚动或 hittable 检查。当前 `DrillPickerSheet` 为 List + searchable（`ActiveTrainingView.swift:869`、`:956`）；c012 确为免费（JSON `:12`）。非首屏行可能不在 AX 或不可点。 | 通过现有“搜索训练动作”搜索明确名称，再断言唯一、可点；点击后核对“取消选择…”与完成(1)，完成按钮也等待可点。这仍是正常 UI，不是深链或种子数据。 |
| **心得字段类型与键盘** | `:76` 只查 textFields；生产为 `TextField(axis: .vertical)`（`DrillRecordView.swift:205`），不同 Runtime 可能呈现不同 AX 类型，需实测确认。`:80` app.swipeDown 不证明键盘消失；该 ScrollView 仅 `.scrollDismissesKeyboard(.interactively)`（`:88`），全屏手势可能滚错容器或下拉整页。 | 首次失败保留 AX hierarchy，按语义定位输入元素并确认真实类型；输入后断言 value 包含唯一 marker。用已确认的页面滚动容器或系统键盘收起操作，明确等待 keyboard 不存在，再找目标；不通过盲点坐标或删断言放行。 |
| **“标记完成”只是一组** | `:81` firstMatch 点击一个组按钮；c012 默认8组，每组15（`Resources/Drills/fundamentals/drill_c012.json:21`–`:28`）。`completeSet` 切换单组 `isCompleted`（VM `:727`–`:750`）。草稿未输入进球数，不足以验证实际成绩录入或整项完成。 | 若验正常完整训练，明确固定输入例如每组不同可辨数值，完成全部约定组并独立算总数；若仅做短程保存样本，则命名为“单组标记后提前结束”，另留完整完成场景。0 成绩保存可作为独立边界，但不能代替非零数字核对。 |
| **完成后默认触发休息** | VM `:316` 默认 restDuration=60，`:749` 标记成功后 startRestTimer；ActiveTrainingView `:55` rest overlay。草稿直接截图、点击结束或更多（`:84`–`:87`），可能被覆盖，错误地报告结束按钮不可用。 | 用正常休息设置设 0 并断言，或明确点击休息层“完成休息”（`ActiveTrainingView.swift:729`）并等层消失，再结束。若覆盖出现但不支持退出，不自动推断 App Bug，先分清预设与真实交互缺陷。 |
| **完成按钮的 AX 子元素** | `BTSetInputGrid.swift:455`–`:456` 每行 combine + rowAccessibilityLabel；`:579` 子按钮才标“标记完成”。SwiftUI 不同系统 AX 合并结果须实测。firstMatch 也未绑定某组。 | 先检查 AX，再按特定组行范围定位，并验证点击后该组状态/进球值；不能看到屏幕任何一个“已完成”就视为目标组完成。若不得不新增诊断标识，需主控另评是否越过不改业务实现边界，不能在本任务改生产 View。 |
| **结束/跳过/保存跳转断言不足** | `:87` fallback 未等待更多按钮和菜单项可点；`:89` 正确对应 `.note` 标题与“跳过”（ActiveTrainingView `:24`，TrainingNoteView `:8`）。保存由 Summary `:388` 起成功后700ms dismiss；`:92` 仅 free.exists，背后首页可能在弹层未关时仍存在。 | 每阶段先断言当前页面、可交互控件，再操作。保存后断言无“保存失败”、summary 已消失且首页主 CTA hittable；确认记录写入后才 terminate。对保存失败保持原失败结果，不继续到历史误报“丢记录”。 |
| **历史同名行和固定备注可假绿** | `:96` 按名称firstMatch；历史行按日期显示，可能有旧同名训练。`:99` 固定“QD disk persistence”可来自上一轮。最终仅 exists，不核对详情归属、数字、剂量、重复条数。 | 使用独特 marker；先在保存后查明确日期/唯一新增记录，重启后再对照同一记录。核对 drill名、组数、各组 made/target、条目心得和 session 心得边界；第三次进入确保无重复。必要时独立磁盘读取匹配 marker 及 session/entry ID，不依赖标题排序。 |
| **日期跨零点前提** | 新记录日期取创建时刻；重启 History 默认选中当前日期。跨零点可能读到新一天而找不到刚保存记录，形成假丢失。 | 记录测试开始/保存本地日期；重启后明确选保存日或规定测试不跨零点，并在跨日发生时标前提失配重排，不能把记录判丢失。 |
| **Free 历史权限** | `HistoryAccessController.swift:4`–`:12` 为近60天可访问；新保存当日记录可看，无需强制Pro。`HistoryCalendarView.swift:270`–`:284` 不可访问会开订阅页。 | 保持Free验证当前记录，点行后断言进入目标详情而非付费页。另建59/60/61天边界及Pro场景；本条只覆盖当日免费可达，不宣称权限矩阵通过。 |
| **详情为 sheet，未验证返回刷新** | `HistoryCalendarView.swift:46`–`:58` 打开 NavigationStack sheet，onDismiss重新load；`TrainingDetailView.swift:65` 有xmark关闭，未显式“返回”文本。草稿到截图即结束，完全未走关闭、编辑/删除与刷新。 | 不套用 navigationBars.buttons[返回] 假设；检查真实AX中的关闭控件（必要时按toolbar作用域），关闭后等详情消失与日历列表可点。SC12另外执行备注编辑保存、取消、删除确认与取消、返回后列表刷新、空日和月份变化。 |
| **证据输出目录外部依赖** | capture `:17` 强制unwrap QD_SHOT_DIR/TEST_RUNNER_QD_SHOT_DIR，且不创建目录；环境没传或目录不存在会把取证错误混入产品测试失败。 | B0确认目录已创建且runner环境可读可写，以 run/scenario/device 唯一路径命名避免覆盖；将取证/基础设施失败与App断言失败分开，保留xcresult attachment作为同源备份。 |

## SC 覆盖归属

| 场景包 | 草稿成功后最多能支持 | 仍缺的正式覆盖 |
|---|---|---|
| SC05 自由训练 | 正常入口单动作、录入条目心得、提前结束和保存（还需上述前提修正） | 非零成绩与完整组完成；保存错误、重试幂等；iOS17对应组合 |
| SC09 磁盘 | 不使用inMemoryStore，真正 terminate + launch 后条目心得可读，是有效磁盘恢复方向 | 唯一记录确认、剂量/来源快照、不重复、其他DATA1组合；自由训练无官方来源，不能代替scheduled来源恢复 |
| SC12 历史 | 当前日免费记录打开与条目心得显示 | 切月/选日/空日、编辑取消/保存、删除取消/确认、返回刷新及权限边界 |

`testFiveRootsReachable` 经 launchClean 跳过引导，不能记 SC01 首次逐页完成通过；五根可达只能作为 SC02 部分证据。`testGuestAndForcedPremiumGate` 为强制权益+深链门控证据，不代表真实购买或正常列表到详情旅程，不代替 SC18。

## B1 推荐最小调整顺序

1. B0确定 snapshot-002、专用磁盘环境、目录与唯一 marker；审阅新增测试选择器副作用。
2. 首次 UI 操作时保留 AX、键盘和休息层证据，依据实际树修正测试定位，不改业务语义。
3. 正常选择免费c012，明确录入方案与部分/完整完成目标；处理休息后完成、保存。
4. 保存后确认详情数值与唯一marker；真正终止进程重启后再核对，同步检查唯一条数。
5. 独立展开 SC12 编辑/关闭刷新和日期操作；每子场景分别记录，不用一条长测试的通过填满三个SC。

验收边界：本报告是静态测试审查，没有实测证明任何AX类型、键盘动作或按钮可达性。上述可能失配先归类测试前提/定位待验证；只有在正常用户操作同样复现且符合产品预期时，才升级登记产品问题。
