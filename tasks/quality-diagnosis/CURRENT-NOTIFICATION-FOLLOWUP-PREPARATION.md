# 通知授权后的三个局部跟进草稿

2026-09-07，snapshot-004。只读当前 `TrainingGoalView` 及调度入口，仅修改 `tasks/quality-diagnosis/SystemBoundaryDiagnosticUITests.swift` 独立草稿，原有方法保留。**未注册、编译或运行；没有修改正被测试的 snapshot-004。**

## 当前真实控件与语义

`TrainingGoalView.swift:239–243` 开关真实 ID 为 `trainingGoal.reminderEnabled`；`:258–262` 为真实 SwiftUI DatePicker（hourAndMinute），ID `trainingGoal.reminderTime`，只在 prefs.reminderEnabled 时显示。它没有显式指定 wheel/compact，因此不能先验假设三个轮子或某小时选项。

`:292–324` 关闭分支调用 scheduler.disable，并持久化 reminderEnabled=false，不撤销系统通知权限；开启被拒绝则开关回 false，弹“无法开启提醒”，按钮“知道了”。`:327` 页重新进入会查询授权状态；状态文本三种分别为首次请求、已开启、未开启请去设置。拒绝后再试不应重新出现系统允许/不允许选择。

## 新增精确 selector

统一前缀 `QiuJiUITests/SystemBoundaryDiagnosticUITests/`：

1. `testAuthorizedReminderTimePickerOpensForObservationWithoutChangingTime`
   - 外部状态须 `ALLOWED_ENABLED`；实际游客→训练目标，等待开关1且enabled、授权已开启。
   - 只用真实 `app.datePickers["trainingGoal.reminderTime"]`，验证 elementType=datePicker、可点、enabled，保存操作前PNG/AX，点击后保存实际呈现PNG/AX。
   - **纯观察方法**：不猜wheel、不选时间、不点击任意“完成”、不断言某布局。主控须看操作后图/AX判定实际是否展开；方法绿色本身仅证明真实DatePicker被点击和证据生成，不自动代表时间选择或重排已通过。若平台未将其暴露为DatePicker，保留失败，依据实际AX另修草稿。
2. `testAuthorizedReminderCanBeDisabledAndRemainsOffAfterReentry`
   - 同外部状态 `ALLOWED_ENABLED`，真实开关1→点关闭→等0；时间选择控件消失；返回我的再进训练目标仍0且时间控件不存在。
   - 授权状态仍“系统通知权限已开启”，区分关闭App提醒与撤销系统权限。保存关闭前/关闭后/重进三阶段PNG/AX。
   - 不声明OS pending request已查询为空、已送达通知被撤回、跨进程持久性或真实定时投递。
3. `testPreviouslyDeniedReminderRetryShowsAppExplanationWithoutSystemPrompt`
   - 外部状态须 `DENIED_DISABLED`，实际状态文案拒绝、开关0。
   - 再点开启→明确App“无法开启提醒”→“知道了”→仍0及拒绝文案。操作前、App弹框、关闭弹框后保存PNG/AX。
   - 三个观察点同时检查SpringBoard和App alert下都没有允许/不允许（含英文Allow/Don't Allow）按钮。不自动批准任何系统框；如系统选择出现即失败。
   - 这是离散观察点和UI行为验证，不等同完整录像排除任意瞬时系统弹框；若该边界有疑问须保留xcresult录像复核。

## 运行前置与顺序

环境为 `QD_NOTIFICATION_FOLLOWUP_STATE`（兼容 `TEST_RUNNER_` 前缀），必须精确为上述状态；不是自动设置权限的开关，真实UI文案和值仍独立校验。沿用现有setup：内存模型、forceNonPremium、跟随系统外观，**通知授权和UserDefaults不是内存fixture**，会保留在专用模拟器。不能用普通用户/其他数据设备。

已授权时间观察先于关闭方法；关闭会使提醒持久化为0，不能再直接重复要求1的方法。两个已授权方法可以使用刚真实允许且已排程的同一专用设备，必须串行、保留中间环境记录；拒绝重试用真实拒绝的另一专用设备。若前置不满足，方法失败不自动重置/授权或清理用户数据。

新增helper每阶段保留PNG（沿用原capture）与完整App AX+SpringBoard alerts AX、xcresult keepAlways；写AX不覆盖。所有等待10秒以内，reveal最多7次。三个新方法共计划8对PNG/AX；不读取Keychain/Secrets/通知私密内容，不设置提醒时间。

## 待验收边界

本次只是草稿，未声明任何通过。DatePicker展开形态、日期/时间显示值、真实系统授权与开关初始值都以执行现场为准。时间调整后重排、关闭后的OS待发队列、授权被设置App外部撤销后的恢复、前后台实际投递仍是独立缺口。
