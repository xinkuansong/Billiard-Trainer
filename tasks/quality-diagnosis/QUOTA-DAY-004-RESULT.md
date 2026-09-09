# 运行中当地日期变化：额度实例对照结果

## QD-032：当地日期变化后存活的免费额度实例未刷新（P2，服务层已复现）

2026-09-08 snapshot004，formal-004-quota-day-001：唯一方法失败0.764秒，make2，1366文件含xcresult和五阶段JSON归档。独立UUID defaults、新专用内存宿主，不改业务或系统时钟。

- UTC−12下实际当地日2026-09-07，20次正常recordQuestion后used20/remaining0/已限额；持久键同日20。
- 仅测试进程默认时区切UTC+14，实际当地日2026-09-09；新DateFormatter偏移和显式Gregorian/POSIX日期对照均通过。**创建新对象前**，原对象仍remaining0/已限额。
- 同一独立defaults新建对象正常重置used0/remaining20/未限额，持久键也写新日0；原对象仍20/0/已限额。失败发生在新旧实例一致性的产品断言，而非日期前提。
- 第五阶段确认进程时区恢复Asia/Shanghai，随后抛错；测试仅清理自己的UUID domain。

根因限定：AngleUsageLimiter.init比较日期并重置，remainingToday/isLimitReached仅查看缓存questionsUsedToday，recordQuestion递增时没有先核日期；App页使用长寿命shared。有效规格docs08免费每天20次。潜在用户影响为App持续运行、当地日变化后仍被旧额度限制；用户重启新建对象可能恢复。**没有真实等待午夜、没有系统时区变更通知或SwiftUI刷新实测**，因此不宣称所有跨午夜场景已复现，也不推断时区旅行的产品政策细节。

后续修复方向：明确每日额度使用的日历/时区政策，统一存活实例和持久状态的换日更新，再用正常跨日/前后台UI验证。当前只记录，不修业务、不将失败改绿。详QUOTA-DAY-004-RESULT.md。

[运行1366文件](../../archive/quality-diagnosis/runs/formal-004-quota-day-001/)；[五阶段核对](../../archive/quality-diagnosis/observations/quota-day001-review.json)。xcresult：Test-QiuJiDiagnosticMemoryHost-2026.09.08_19-18-08-+0800.xcresult。SC32仍partial，正常近满至本地购买连续链复用QUOTA-004-RESULT，不重跑。
