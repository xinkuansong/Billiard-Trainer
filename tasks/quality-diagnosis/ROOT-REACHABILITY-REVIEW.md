# 根页可达性补充草稿

2026-09-06。仅新增 RootReachabilityDiagnosticUITests.swift，未构建或执行，供主控在小屏 AX5 审查后运行。两条均正常游客/Free 根入口、内存空库、跟随系统外观，无深链、历史 fixture、购买、账号或业务修改。截图使用指定输出目录及 UUID 唯一名，XCTAttachment keepAlways。

## 两条方法

- `testTrainingLevelFilterReachableAndChangesCards`：正常训练根，记录初始遮挡；有界滚动到入门，实际选择并核对 selected trait、基本功卡；再选择中级，核对 selected trait 与入门取消选中、准度Ⅱ卡出现及基本功卡退出结果。最后检查没有意外进入活动训练。不是仅断言按钮 exists。中级卡本身为 Pro，但此测试只浏览筛选，不打开/解锁。
- `testHistoryEmptyCTAReachableAndRoutesToTraining`：正常历史空根，最多六次上滑，要求 CTA 全 frame 在屏内且 hittable、空态文字 hittable，截图后实际点击，核对训练根 CTA 出现且历史 CTA 不再 hittable。

## 冻结来源

- `QiuJi/Core/Components/BTFilterChip.swift`：真实 identifier 为 `filterChip_标题`，选中提供 `.isSelected` trait。
- `QiuJi/Features/Training/Views/TrainingHomeView.swift:1459`：筛选横向 ScrollView；计划按钮 identifier `planPoster-计划ID`。
- `QiuJi/Features/Training/ViewModels/TrainingHomeViewModel.swift:203`：入门匹配 L0，中级匹配 L2；默认全部。
- `QiuJi/Resources/Plans/plan_beginner.json`：基本功 L0→L1；`plan_intermediate.json`：准度Ⅱ·远台切角 L2→L3。因此两个过滤结果应发生明确变化。
- `QiuJi/Features/History/Views/HistoryCalendarView.swift:305`：空态文案“还没有训练记录”，按钮“去开始第一次练球吧”，动作是 `router.switchTab(.training)`，不直接开始训练。

## 执行边界和待核对项

没有硬编码点击坐标。纵向滚动六次封顶，回找筛选五次下滑封顶，横向筛选最多三次左滑，使用实际包含 chip 的最短高度 ScrollView 定位横向容器。若 AX5 下 chip 被 SwiftUI 延迟创建、横向容器没有暴露、卡片 label 未合并标题或滚动步幅越过控件，应保留失败 AX/截图后修订草稿；不能删断言/guard return 假绿。现阶段实际 AX5 容器结构未知，不能称脚本已验证。

`exists` 对 LazyVGrid 中卡片缺失本身不充分，因此组合了实际 selected trait、预期中级卡和入门卡移除；主要正确性证据仍为选择状态与正向目标卡。isHittable 也不能完整证明浮动控件未遮挡，所以实际点击后的结果断言不可省略。若点击失败，当前草稿不自动重试点其他坐标，以免掩盖遮挡。截图只证各捕获阶段，不是全程录屏。
