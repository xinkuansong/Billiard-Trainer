# 本地权益变化诊断004

新隔离 iPhone17Pro/iOS26.2，单次启动内完成本地月度正常UI购买1笔、c039试打、付费计划激活确认后取消、图谱轨迹切换、模拟到期及三类重新拦截。1/1通过260.668秒，1601文件及observer归档，12张关键完整PNG已审。初始交易0笔，购买及到期后均为同ID的1笔历史；全过程App PID16441保持。

运行 `formal-004-entitlement-boundary-001`，选择器 `EntitlementBoundaryDiagnosticUITests/testLocalMonthlyUnlocksThreeCategoriesAndExpiryRelocksWithoutRestart`。设备 FC0FD561-6693-4F56-B8A0-70C3A61BC624，Light/large已实际读回。原测试源、日志、xcresult及截图位于 archive/quality-diagnosis/runs/ 同名目录；录像、RSS及runner0/recorder0位于 observations/ 同名目录。

固定离线资料身份，无forcePremium/forceNonPremium。一次App.launch和一次正常购买；到期使用本地SKTestSession.expireSubscription，未重启或恢复绕过。到期后个人页无Pro，三类再次进入订阅页。图谱实际显示8/8→7/8→8/8；计划只取消激活，不算已开始付费计划；试打点击重摆只证实入口和操作响应，不等于8杆完成。

12张完整图审：初始三类订阅拦截；购买后Pro、实际试打、计划确认、图谱隐藏及恢复；到期后Free、三类重新拦截。没有新增产品问题。交易历史恰一条是本次SDK实际观察，不提升为所有版本契约；所有摘要都在teardown清理前留证。

预飞提示首次键盘引导未处理，本设备实际输入成功并进入精确c039；未修改原测试后冒充本轮已验证。18:08冻结5350输入改变0/缺失0，见 source-recheck-20260908-1808.json。

SC32/33仍部分覆盖：额度近满、真实Sandbox、跨设备权益等尚未证明。原购买取消、pending批准、进程重启和恢复成功证据继续复用。本次不能认证所有权益或真实商店。

主控已全文复核B6-COVERAGE-AUDIT-004.md，原38SC范围保持；其中权益未执行描述由本终态更新，其余本机缺口继续推进。
