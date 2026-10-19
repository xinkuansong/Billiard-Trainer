# 记录页切回闪烁修复

日期：2026-10-18

## 需求与根因

切回底部“记录”Tab 时保留现有日历和列表，同时继续读取最新记录。
`HistoryCalendarView.task` 每次出现调用 `loadSessions`；后者设置 `isLoading`，视图无条件以 ProgressView 替换整个历史内容。因此已有数据也会发生内容移除、重建。

## 实施范围

区分首次成功加载与后续刷新；空库也属于已成功加载。保留页面出现、详情关闭、账号恢复通知的刷新入口。已有 PRO 角标与访问门控修改保持。

## 功能验证

实现与定向验证完成。`hasLoadedSessions` 只在主记录加载成功后置位；视图仅在 `isLoading && !hasLoadedSessions` 时用整页加载占位。保留已有错误/重试处理。账号切换仍由 RootView 的 ownerKey identity 重建页面状态，不跨账号复用。

- 修复版构建：`after/build.log`，`TEST BUILD SUCCEEDED`。
- `HistoryViewModelTests`：22 项通过，其中新增 3 项覆盖首次/空库刷新、已有内容保持与新记录读取、删除最后一条记录；验证期间通过 Combine 观察真实加载状态事件，不使用固定延时。
- `V29W6HistoryStatisticsKindTests`：13 项通过，覆盖 drill/cognitive/tool 分类读取与统计契约。
- `P6_HistoryStatsUITests.testReturningToHistoryPreservesCalendar`：1 项通过，真实点击“我的→记录”三次，月份与标题纵向位置保持。
- 结果：35 单元 + 1 UI，0 failures；日志及 xcresult 位于 `output/history-refresh-20261018/after/`。
- 定向 `git diff --check`、`verify-doc-size` 通过。

加载入口没有增加“只加载一次”的限制，新记录仍在每次页面出现时查询。新记录增删由真实内存 SwiftData 存取测试验证；本轮未追加端到端训练保存流程。

## 视觉审查

同一 iPhone SE 第三代 / iOS 26.3 / 浅色 / Large 标准字号，改前与改后均运行相同 Tab 往返测试。已打开原生全图目视：分段、PRO 角标、月标题、日历格、所选日期、底部 Tab 与背景保持一致，无新增错位或截断。截图验证稳定布局，刷新不再进入整页占位的机制由加载状态回归共同验证；未做真机逐帧测量。

- [改前](../../output/history-refresh-20261018/before/attachments/633E9A61-2756-459B-813D-3C37790CA756.png)
- [改后连续返回](../../output/history-refresh-20261018/after/attachments/D631A9FF-1A59-4AB1-9AF9-27DD0304F2F9.png)
- [本次生产差异（不含已有未提交修改）](../../output/history-refresh-20261018/scope.diff)

首轮通用构建因额外编译 Intel 架构而主动停止，保留 `before/build.log`；随后 ARM64 构建成功。修复后第一次设备借用因其他任务占用被管理器拒绝，没有启动测试；确认租约释放后同设备重跑成功，记录保留 `after/run.log` 与 `after/run-r2.log`。

改前自启设备已恢复关机；改后借用时设备已开机，因此保留开机状态，恢复借用前外观/字号并释放租约。未清理设备或用户数据。

未安装真机，未提交或发布。深色/iPad/VoiceOver与真机体感未专项复验。
