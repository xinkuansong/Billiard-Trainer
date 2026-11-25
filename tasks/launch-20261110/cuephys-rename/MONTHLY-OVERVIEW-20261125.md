# 本月概览全活动口径（DR-469）

日期：2026-11-25。用户要求：本月概览把所有的都算进去。

## 原因与范围

原 `TrainingGoalMetrics.monthlyOverview` 复用 `goalCounting`，只纳入 `drill`、`cognitive`。因此历史中已有工具使用和模拟练习时，概览仍可能显示三个零；这不是仅凭两张截图即可判定的云同步故障。本轮将概览的统计口径与周目标拆开，不修改历史数据或同步协议。

当前账号仍由 Profile 的 owner 查询隔离。本自然月的真实训练、认知练习、工具使用和八类模拟练习记录均可计入；模拟练习复用历史页的载荷身份、版本、兼容性和非空 attempts 检查。未答草稿、不可读或身份不匹配的模拟载荷不计入。没有生成 TrainingSession 的局内计数或其他独立存档不在本轮新增适配范围。

- 天数：沿用 reportingDate，以当前 Calendar 的自然日去重。
- 时长：累加被纳入记录的 totalDurationMinutes，保持小时与分钟展示。
- 连续练习：本月内最长连续自然日，不把上月串入。
- 周目标和准确率：仍按各自既有 kind 合同计算。

## 实现

`HistoryViewModel.hasRecordedActivity` 复用现有历史装配入口；`TrainingGoalMetrics.monthlyOverview` 使用该判断，声明 MainActor 与其 SwiftData／历史调用边界一致。ProfileMonthlyOverviewCard 的 API、颜色、布局和账户筛选未变。

## 验证记录

首轮真机构建失败：同步统计函数调用了 MainActor 隔离的历史判断；已把 monthlyOverview 声明为 MainActor。原失败包保留在 `output/local-test-runs/0a870fc1ae1b43febe596f3b032a4761/evidence/tests.xcresult`，不记作测试通过。

第二轮：两项统计单元测试及真实账号 UI 通过；新增准度草稿测试的样本默认抽取20题，不符合记录构造所需的15题，失败发生在测试样本构造阶段。已显式按 ordinaryRoundCount 抽题；保留 `private/retry.xcresult`，不掩盖失败。

最终定向真机复验：**4/4 通过，0 跳过**（`private/final.xcresult`）。

| 验证 | 结果 |
|---|---|
| 工具纳入、同日去重、自然月过滤；周目标及准确率不变 | 通过 |
| 最长连续天数不跨月 | 通过 |
| 准度已提交记录纳入、未答草稿排除、owner不匹配排除；八类模拟破损载荷排除 | 通过 |
| 真机真实账号 Profile 概览非零 | 通过：9天、10小时54分、月内最长连续4天 |

iPhone 16 Pro USB、iOS 27.2.1，生产数据查询路径、当前已登录账号；非模拟器、非植入统计样本。首张真机截图中概览完整、无截断，顶部另有系统通知；最终四项测试截图捕捉到回到桌面的动画，因此不将该张作为页面视觉证据。补做单项 UI 复验数值仍一致，但截图时手机已被用户切到其他应用；立即停止真机操作，附加截图不作产品证据。视觉验收仅依据首张概览区域无遮挡的原生图，未声称获得无系统通知的整页截图。没有扩展为全 App 全量测试。

`make verify-gate`、`make verify-doc-size` 和 `git diff --check` 通过。原始结果包、日志与截图均保存在 `output/monthly-overview-20261125/private/`，含真实账号信息，不纳入 Git。

本轮不退出账号、不清空容器、不写入测试训练、不切换会员或云同步设置。测试固件中的临时模型只在内存创建。

原生概览证据：`private/retry-attachments/2386A85B-72C7-481E-A433-B51DC4F415A4.png`。

## 同步文档

内容数据合同 §5.3、docs/05、docs/00 讨论记录、实施日志 DR-469、UI 实施规范与 PROGRESS。
