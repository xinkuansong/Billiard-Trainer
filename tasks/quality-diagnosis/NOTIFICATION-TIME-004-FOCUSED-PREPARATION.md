# 通知 20:17 一次聚焦复验准备

2026-09-08；只读准备，未写 Swift、注册、构建或操作设备。只新增本文。依据 `NOTIFICATION-004-RESULT.md`、`SystemBoundaryDiagnosticUITests.swift`、`NotificationPendingDiagnosticTests.swift`、冻结 TrainingGoalView/UserPreferences/TrainingReminderScheduler 与旧003/observe001归档日志。目标是区分**输入没有到17**与**已经选17却保存成15**，不重复允许/拒绝权限，也不先判产品根因。

## 已核旧证据与源码

- `archive/quality-diagnosis/runs/formal-004-notification-allow-change-ui-003/xcode-test.log:378–392`：小时 adjust("20") 在26.40秒开始，分钟 adjust("17") 在26.52秒开始，26.74秒读分钟得到 **`Optional("15")`**，不是 `17分钟`；随后 teardown，没走关闭/重入。因此原失败同时有数值不同和展示后缀不同，不能只去掉后缀就称修好。
- `formal-004-notification-allow-change-observe-001/xcode-test.log` 的独立 OS JSON：authorized、reminderEnabled=true、dailyRequestCount=1、20:15、repeats=true、explicitTimezone=nil、otherPendingCount=0。它证实已排20:15，不证明 DatePicker 曾经稳定选到17。
- `formal-004-notification-allow-picker-ui-001/screenshots/system-62266160-B000-4BE9-9A16-DC55DA8C60CD-authorized-time-picker-after-tap-observation-AX.txt:51/69–71`：时间选择器曾为 Other value19:00；两 PickerWheel 曾为19点/00分钟；关闭按钮真实ID `PopoverDismissRegion`、label关闭弹出式窗口。后来003控件类型/原始value不同，所以不要限定 Other 或强制后缀。以上旧frame只是历史证据，不能直接拿来点击当前屏幕。
- 冻结 `QiuJi/Features/Profile/Views/TrainingGoalView.swift:258–262,291–319`：DatePicker每次set立即进入 updateReminder；`isUpdatingReminder` 为真直接return，更新期间 DatePicker disabled；async schedule成功后才persistReminder，再defer解锁。**小时和分钟连续更新可能与这个异步窗口相关，但本次仅是待验证解释，不能凭代码证明丢17。**
- `QiuJi/Data/Services/UserPreferences.swift:89–94,144–153,177–179`：时间按Date时间戳保存，关闭只写enabled=false而不清旧time。`TrainingReminderScheduler.swift:35–49,75–94` 按传入calendar提hour/minute，替换同identifier请求；源码没有本次查到的15分钟取整规则。

## 前置与设备边界

1. 仅原 Allow 专用设备 `CB246F30-E917-492B-B0C4-511F473D8C15`、com.xinkuan.qiuji、原guest；主控实际核 runner UDID匹配、当前安装输入与无真实账号、系统时区/locale。不可操作正在跑 c042 的设备，不reset、不清defaults、不重装丢原状态、不改时钟。
2. 该设备后来已**正常关闭提醒**，新方案起点应为 authorized + enabled=false + dailyRequestCount0，而不是旧方法的 ALLOWED_ENABLED /19:00。先用独立只读 OS probe 核这三个实际值，另保留原偏好值的只读摘要；不预写19:00/20:17。实际旧time预计可能20:15，但必须读回，不把预计当guard。
3. 既有 probe 精确selector：`QiuJiTests/NotificationPendingDiagnosticTests/testObserveActualAuthorizationAndDailyPendingRequest`。环境 `QD_NOTIFICATION_ENVIRONMENT=DEDICATED_GUEST_SIMULATOR`、`QD_EXPECTED_NOTIFICATION_STATUS=authorized`、`QD_EXPECTED_NOTIFICATION_COUNT=0`、`QD_EXPECTED_REMINDER_ENABLED=false`，支持 TEST_RUNNER_。该方法缺授权会XCTSkip且没有精确UDID guard，所以编排层必须先核专用UDID并核**实际1方法非skip**；不能将它直接看成完整安全护栏。
4. 正常“我的”→“训练目标”，核guest、开关0与“系统通知权限已开启”。只点现有开关开启，等value1且enabled、DatePicker出现且enabled；不得预期新系统权限弹窗。若出现 Allow/Don't Allow 选项、未授权或真实账号，先PNG/AX并停止，不点击权限选项继续。

## 唯一允许的新变体：分开两次用户更改，等待实际稳定

这不是连点失败后的多次补滚轮。对比旧003唯一有依据的变因是：**小时更新完成并稳定后才操作分钟；所有终值在等待期间采样，而非马上XCTAssert**。

1. 开启后先记录当前关闭态时间。定位 `trainingGoal.reminderTime` DatePicker 内 label恰为“时间选择器”的唯一有效节点（允许实际类型变化），保留value与完整AX；如果唯一性/可读性不成立，停于观察限制。
2. 点实际DatePicker，核两轮均存在、启用、可操作。保留原始value、label、frame与截图。根据可读单位和位置交叉确定小时/分钟，不能只在未核实的新形态里盲用索引；旧两轮索引只作匹配依据。原始字符串全部落JSON，并仅将严格的1–2位数字、可选“点/分钟”解析为对应整数，不接受任意抽数字或nil默认。
3. 若小时尚非20，仅做一次 `hour.adjust(toPickerWheelValue: "20")`；小时已20则不重复输入。用单调时间记录轮值、picker.isEnabled；在最多8秒窗口内等待小时=20且picker重新启用，并在间隔至少0.5秒的两次采样相同后才进入下一步。这是观测稳定条件，不是业务SLA；保存原始采样，不伪称内部Task已经被直接观察到。
4. 分钟仅一次 `minute.adjust(toPickerWheelValue: "17")`。同样最多8秒采样两轮raw/解析值、picker enabled；稳定至少两次，保留最终值及PNG/AX。**17仍是严格目标，读15不能把期望改15来报成功。**如果小时也回退，同样记录真实状态。
5. 在无系统意外弹框且唯一 `PopoverDismissRegion` 实际可操作时正常关闭一次，记录关闭态时间、开关、enabled；正常返回再进训练目标，记录重入时间。即使轮值没到17，也可以继续这两步作为只读保存一致性采集，但须已有 failed-input 标记，不能给这组加“20:17成功”附件。所有危险前置（身份/权限/唯一控件）失败则立即throw；**业务差异暂存到诊断结果，完成三层采集后最终throw**，不吞错、不产生总体green。
6. 不再调整第二次分钟、不换隐藏API、不猜滚轮点击坐标、不靠重启把差异消除。只完成此一次分阶段操作；如当前真实AX证明不支持adjust，则停下保存输入限制，本方案不授权第二种手势自动尝试。

## 独立 OS 收尾与判定

UI终态无论成功或有数值差异，都先归档图/AX/单调采样，再单独运行上面的只读probe，期望authorized、enabled=true、count1、hour20、minute17；其报告在断言之前输出，故不达17仍能保留真实OS值。不要把expectedMinute改实际15制造绿。每个run独立输出路径；probe只读取，不能在方法里修通知或偏好。收尾probe缺预期/skip/安装容器变化同样不是成功证据。后续是否正常关闭提醒由主控另行决定并记录，不在本复验中悄悄清理。

| 实际观测 | 可形成的结论 |
|---|---|
| 稳定轮20/17→关闭/重入20:17→OS20:17 | 本次序列化正常操作保存一致；旧003失败保留，不能反推旧根因已证实。 |
| 稳定轮仍20/15→关闭/OS20:15 | 目标输入未实现；保存与实际轮值一致，20:17原需求仍未验。定位/异步回退原因保留未知，不判“存储把17变15”。 |
| 明确稳定轮20/17→关闭或重入15/OS15 | 有可记录的输入/提交一致性异常；结合采样和图像定位阶段，不能直接归因通知中心或取整。 |
| 关闭/重入20:17但OS20:15 | UI/排程不同步证据；保留真实授权/request身份和采集时间，避免将过早probe当最终保存失败。 |
| 无法稳定、控件消失/歧义或出现意外权限弹框 | 有界观察受阻或输入失败，停止本变体；不无条件多跑直到绿。 |

如需判断“最终保存”而非瞬间中间态，关闭/重入阶段同样等待enabled且两个连续一致采样后再结束UI；OS probe随后串行执行，其耗时不当作产品超时阈值。此最小方案不验证通知真正送达、声音、锁屏、跨时区或所有分钟值，也不改业务消除 isUpdatingReminder 窗口。当前只是可审准备，无新执行结果。
