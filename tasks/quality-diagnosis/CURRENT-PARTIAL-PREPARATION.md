# 当前版 QD012 提前结束独立单测准备

2026-09-07。草稿 `CurrentPartialSaveDiagnosticTests.swift` 已按 snapshot-003 中真实 VM/API 和现有 ActiveTrainingViewModelTests 核对，**未注册、未编译、未运行**。不得当作通过证据。

三个精确方法：

- `QiuJiTests/CurrentPartialSaveDiagnosticTests/testEarlyEndFiveOfFifteenCountsOnlyExplicitlyCompletedGroup`：8 个计划组均 15 球，仅第一组输入 5 并调用真实 completeSet；endTraining → submitNote → saveTraining → 新 ModelContext fetch。要求实际成绩只有已完成的 1 组、5/15，不接受 5/120。
- `QiuJiTests/CurrentPartialSaveDiagnosticTests/testEarlyEndExplicitZeroGroupRetainsItsFifteenAttemptsOnly`：相同 8 组，仅显式完成第 1 组 0/15；要求保留这组 15 次尝试、其余未操作组不计入。防止“过滤零分组”的伪修复。
- `QiuJiTests/CurrentPartialSaveDiagnosticTests/testFullyCompletedZeroGroupIsNotDiscarded`：只计划 1 组并显式完成 0/15，要求保存 1 组/15 次。这是预计可通过的有效零分对照，不降低前两项要求。

预期依据沿用 QD012 已确认的真实成绩/完成组语义和冻结版非零 UI 证据。本版 DrillSet 仍没有完成状态，保存仍将每个计划行变为结果组；按当前实现前两项预计失败。失败必须保留，不添加 expectedFailure、不改产品、不把期望改成当前 8 组。将来若产品决定保留未完成计划行但增加完成状态，应按新模型对有效结果集断言，不能将本测试视为永远强制删除计划行的产品规格。

隔离与证据边界：

- 每方法创建独立 `ModelContainer`（isStoredInMemoryOnly=true）、关闭 context autosave；只调用真实 VM 默认 saveAction。未 configure 共享 SyncQueueManager，未改 OwnerContext、Keychain、UserDefaults 或正式内容。VM save 自身向同一专用内存 context 插入队列项，不发网络请求。
- VM 通过当前公开 ActiveDrill/DrillSetData 建立明确 8×15 输入，isCompleted 不直接设 true，而是调用实际 completeSet。restDuration=0；注入无系统副作用的 Activity 协议对象仅隔离声音/ActivityKit，完全不替代保存或计算逻辑。
- 成功保存后用新 context 读回 session/entry/set，保留唯一 marker、全部实际组号/分子/分母/成功率 JSON attachment，再执行缺陷断言。没有模拟杀进程或磁盘重启，也没有调用真实屏幕输入控件，不证明 UIKit 键盘、历史绿勾或统计页视觉。
- 父任务仍需独立核验测试、在专用无真实凭据设备及安全宿主启动 scheme 中注册/执行。虽然测试数据内存隔离，宿主 App 的正常启动行为并非由本测试全面隔离；不得在真实登录设备跑。
