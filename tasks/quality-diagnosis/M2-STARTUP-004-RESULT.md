# M2 普通启动与首次通知拒绝结果

2026-09-08，snapshot-004，只诊断。

- 运行：`formal-004-m2-startup-deny-001`，唯一方法 `M2StartupPermissionDiagnosticUITests/testOrdinaryM2EmptyGuestStartupAndFirstNotificationDenialSurvivePageReentry`。
- 结果：1/1通过，39.036秒，make退出0，录像进程退出0。
- 专用SE3/iOS17：`008E37F5-91B1-46FE-8AA7-3E70823FE9A8`，实际Light/large。普通新磁盘，仅语言启动参数，没有内存/引导跳过/权限预授。
- 正常空训练首页、游客、目标设置依次进入；初始提醒关闭且undetermined。实际系统中文通知弹窗选择“不允许”，随后App“无法开启提醒”解释。关闭解释后提醒关闭且denied；实际返回并重新进入仍关闭且denied，未再次弹系统询问。
- 主控已审完整截图1/3/4/5/7，共5张；首页浮动“+自由”与等级筛选区域接近/重叠仍为已有待交互核实观察，不以本方法通过宣称全页布局通过。

原件：[95文件运行归档](../../archive/quality-diagnosis/runs/formal-004-m2-startup-deny-001/)，[6文件观察归档](../../archive/quality-diagnosis/observations/formal-004-m2-startup-deny-001/)。xcresult为 `Test-QiuJi-2026.09.08_18-50-52-+0800.xcresult`；两个归档均有SHA清单。正常首次页按实际RootView为MainTabView，不把预览专用Onboarding当必须首启步骤。

覆盖SC01/34/38的上述代表边界，仍partial；不证明真实通知送达、OS待通知独立数量、真机权限或全部旧Runtime旅程。设备保留拒绝状态，没有重置权限。未新增产品问题。
