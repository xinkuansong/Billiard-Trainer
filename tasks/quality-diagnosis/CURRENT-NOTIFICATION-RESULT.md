# 当前通知诊断：前置已验，环境阻塞

2026-09-07，snapshot-003。专用Allow设备3604866D-E66B-4677-8F96-FCCBC7B1455F已完成只读宿主探针；不曾调用请求授权、预授权、重置权限或调度。

- formal-resume-notification-allow-probe-001：构建签名失败，日志同时出现ENOSPC，测试未执行；runner写清单也因空间不足失败，exit.json没有生成。保留make.log、xcode-test.log、environment-failure.json；不伪造make返回码。
- 仅清理本诊断旧DerivedData/formal-DerivedData的可重建Intermediates与ModuleCache，保留产品、日志/xcresult、截图、快照和设备数据，记录resume-20260907/cache-cleanup.json。空闲一度约1.0GiB。
- formal-resume-notification-allow-probe-002：1/1通过、0.204秒、make0；实际App通知中心status=notDetermined、dailyRequestCount=0、otherPendingCount=0、reminderEnabled=false。实际输出和结果包路径在原始日志。
- 宿主安装完成后磁盘空闲约253MiB。未继续UI、未请求权限；已关闭专用Allow设备，Deny设备未启动。当前是环境阻塞，不是通知功能失败，更不是通知功能通过。

恢复：先确认空闲空间足够构建、两个独立安装和xcresult录像（建议至少5GB可用，容量建议不是保证）。核对原4849输入与已注册11文件后，允许设备保留未决定状态；先只读重验，再执行notification-allow-ui.json以及实际pending读回；Deny按独立probe→真实拒绝→pending0。原probe001/002输出不能覆盖；新探针需新run名。详细剩余步骤见CURRENT-NOTIFICATION-PREPARATION.md。
