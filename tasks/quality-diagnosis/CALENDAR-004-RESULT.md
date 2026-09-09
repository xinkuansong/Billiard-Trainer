# 日历边界补验结果 — snapshot004

2026-09-08，formal-004-calendar-boundary-001，两精确方法通过，0.291秒，make0；未skip。Reminder 0.025秒，DST schedule 0.267秒。主控全文审核新增诊断源码与实际协议/既有服务测试，注册后保持三个custom scheme字节一致；TestAction在宿主初始化前注入-v50.inMemoryStore，专用401DEA72设备，无OS通知操作/系统时钟更改。

- TrainingReminderScheduler真实逻辑+记录参数替身：UTC2026-03-08T09:30Z/10:30Z，在洛杉矶得到01:30/03:30，在上海得到17:30/18:30；每次恰好一次schedule，四次权限检查，无请求权限或cancel。此为Calendar参数转换层，不是OS实际送达。
- TodayTrainingScheduleService真实服务+当前V5内存容器：洛杉矶3月8日00:30→3月9日00:30实际82800秒；精确日键2026-03-08→2026-03-09，旧队列在注入时刻归档、新队列空、原pending唯一item/UUID/payload保持；重复查询同UUID，独立ModelContext读回恰好2队列/1item。
- 真实xcresult及测试源码SHA、调用记录、日志共63文件归档于archive/quality-diagnosis/runs/formal-004-calendar-boundary-001；六JSON附件在原xcresult。不是磁盘重启/切换系统时区/非公历策略证明。

原目标3→5正常持久化和QD028刷新失败证据保持，不重复。跨时区后的偏好Date显示与OS重复hour/minute关系尚未集成验收；真实锁屏送达、DST缺失小时通知、LiveActivity仍属外部层。此轮无新增问题/无业务修复。审计真源CALENDAR-004-EVIDENCE-AUDIT.md。

主控另从归档xcresult导出并逐份审核6份实际JSON附件，四次参数调用和2队列/1item与断言一致；外置于archive/quality-diagnosis/observations/calendar-boundary001-attachments，含导出manifest和SHA清单。
