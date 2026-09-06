# 关键正常训练旅程补充草稿

2026-09-06：`TrainingJourneyDiagnosticUITests.swift` 新增4方法，未编译/运行。只写本文件与Swift草稿，不改业务、既有诊断文件或模拟器。

## 方法与实际范围

前缀 `QiuJiUITests/TrainingJourneyDiagnosticUITests/`。

| 方法 | 正常路径/核对 | 未覆盖 |
|---|---|---|
| testNormalOfficialPlanActivationArrangementAndStart | 空内存训练首页→plan_beginner货架卡→开始此计划→确认激活→编排今天→默认当前课已选择1项→加入今日→首页0/1→开始这节课→activeTraining.timer | 完成课程/重复保存/顺序推进/取消激活/跨进程游标 |
| testNormalTemplateNameAndDrillSaveAndReopen | 首页更多→新建模版→实际唯一名称输入→添加中袋直线出杆→仅保存→我的模版按唯一名称和edit前缀定位→编辑页名称/动作一致→返回 | 多动作顺序/剂量/修改后保存/删除/磁盘重启 |
| testDailyClearanceNormalStartReturnAndResume | 首页未开始→每日清台真实启动→HUD与stage→返回首页进行中→再次进入HUD与stage | 无fixtureSettled/seed/reset；不证明自动开球终位/同一局ID/球数/计时完全保持；不是系统后台或跨进程 |
| testStatisticsWeekMonthYearAfterNormalCognitiveAnswer | 正常练习→角度预测答45→结果→记录/统计→周月年逐项选择、对应本周/月/年训练天数标题、非空态/非加载错误→历史仍有角度预测记录 | 没有硬塞统计数值；不证明各范围分箱、数值/准确率正确、drill/tool口径；数据单测另补 |

所有方法使用中文、内存SwiftData、forcePremium、跟随系统；没有业务fixture、deeplink、登录、上传或资源制作。统计也通过正常UI创建一题认知成绩，而非人工构造期望图表。图像以UUID+阶段命名，keepAlways并写QD_SHOT_DIR/TEST_RUNNER_QD_SHOT_DIR，I/O失败抛出。

## 冻结源码依据

- TrainingHomeView货架`planPoster-*`、更多`trainingHome.moreMenu`、模版`trainingHome.template.edit.*`、清台`trainingHome.dailyClearance`；今日单课`开始这节课`及summary。
- PlanDetailView `handlePrimaryCTA`初次走激活确认，成功后CTA变编排今天；编排sheet `planDetail.arrangementSummary` / `planDetail.addToToday`；默认当前课选择。新方法明确走真实货架，不复用planState深链fixture。
- CustomPlanBuilderView字段`customPlanNameField`、添加按钮“添加训练项目”、保存菜单“仅保存”；至少一个动作才能保存。用唯一名称识别本次模版，不能误把原有模版打开当新建成功。
- FreePlayView `dailyClearance.hud` / `freeplay.stage`；现有V52正常首页测试也是返回导航后首页进行中。代码没有明确“最小化清台”按钮，因此本方法如实称“返回首页再继续”，**不冒称训练浮标缩小恢复**。
- HistoryCalendarView顶部实际分段“历史/统计”；StatisticsView时间选项来自StatisticsTimeRange“周/月/年”，对应metric标题“本周/本月/本年训练天数”。统计视图和历史视图均保活，断言用可见性/当前标题而不是仅任意树节点存在。

## 运行前提和待实测点

1. 清台状态由本地UserDefaults/草稿保存，不受内存SwiftData隔离；必须在本日未开始的专用设备执行，已有进行中就前提失败，不清除QD证据。本任务没有reset或fixtureSettled快捷路径。
2. 官方计划单课按钮、模版卡AX可能在实际快照中合并或离屏；有界滚动耗尽必须失败。先取AX/截图归因，不跳断言或把失败当完成。
3. 模版输入由真实字段frame右端定位，逐字删除后严格value比较；实际中文键盘换行/首次滑行提示可能影响可达性，草稿处理已知提示但尚未运行验证。
4. 清台HUD出现只证明进入并可继续，不代表自动开球已经完全停稳；需实际图像检查，若需球数/同局ID等可靠状态不变量，应独立存储证据补强，不从截图估算。
5. 周/月/年当前标题断言需要真实AX树；统计空内存新一题在当前窗口都应有数据，但不据此断言天数或误差硬值。本方法适合先补可达与切换证据，精确统计口径留独立数据测试。
6. 本轮全部是待运行草稿；不得在覆盖表写通过。主控独立编译、每方法专用输出与selector指纹、串行设备执行后再归档结果。
