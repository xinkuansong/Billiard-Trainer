# 统计 PRO 常驻

2026-10-17，DR-123 r2。

用户两张截图为问题基线：历史选中时统计无 PRO，统计选中后才出现。源码定位 HistoryCalendarView.proBadgeState 的 activeTab 条件。仅删除该条件，角标仍读取当前订阅权益；共享组件、颜色、字体、间距和统计付费门控不变。

验证证据目录：`output/statistics-pro-20261017/`。

- 构建：`build.log` 为 **TEST BUILD SUCCEEDED**。
- 功能：既有 `P6_HistoryStatsUITests/testSwitchToStatistics` 两次均通过，每次 1 test / 0 failures；第二次为补采运行截图，未新增或修改测试代码。`test.xcresult`、`visual.xcresult` 保留。
- 原生视觉：iPhone 16 Pro / iOS 26.3 / 深色 / 免费档。已打开整图核对 `frame-06.png`（历史选中）与 `frame-08.png`（统计选中），两态 PRO 闭锁完整显示，标题/角标无重叠和截断。用户原图为浅色已购买档，与本轮数据、主题不同，只对比角标显示行为，不宣称像素同态。
- 原生窗口控制不可用，改为在真实页面回归期间用 simctl 采集；首轮采集触发字符串漏了引号，无截图，第二轮修正采集脚本后补齐。其他帧含启动/退出画面，不计页面证据。
- `verify-doc-size`、`git diff --check` 通过；`verify-gate` 在路由覆盖签名漂移失败（missing=[] / extra=[]），本次只改 HistoryCalendarView 一处条件，未改路由，未覆盖其他工作区变更。
- 设备已由受管流程关机；补充shutdown返回already Shutdown（405），未重复操作或清理。浅色、小屏、大字号、会员开锁及真机本轮未重验；权益表达仍使用原 SubscriptionManager 和 BTProBadge。

未装真机、未提交或发布。
