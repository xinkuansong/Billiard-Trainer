# 免费额度耗尽与本地 Pro 连续答题结果

2026-09-08，snapshot004，SC32。唯一方法 `QuotaBoundaryDiagnosticUITests/testLastFreeAnswerExhaustsQuotaThenLocalMonthlyPurchaseAllowsNextAnswerWithoutRestart`，1/1通过76.905秒，make0/recorder0。

新专用iPhone17Pro/iOS26.2设备11D7F92D-5220-45E6-A757-5B6316C3D8B1；API固定离线身份与内存训练库，`-w7.forceDailyLimitNear`仅构造前19次。单次正常启动，正常练习入口，不使用forcePremium。

- 初始真实页面次数0/剩余1，正常输入30°提交后次数1/剩余0；结果显示已输入答案，满额提示出现，换题disabled、答题和下一题不可用。
- 当前满额提示进入订阅，正常选择月度并点击一次购买。本地初始交易0，购买后只有id0/monthly/purchased/pending=false的一笔交易。
- sheet关闭后原题结果和次数1保留；剩余栏消失、下一题恢复。正常下一题再输入30°提交后次数2，仍可下一题且无满额拦截。
- 全过程实际App PID29637，未重新启动或重置额度。终止后独立读取两个指定偏好键：AngleUsage_count=21，AngleUsage_date=2026-09-08。

主控已审五张完整PNG（2/4/5/6/8），分别为剩一题、满额、正常月度选择、购买后原结果、第二次提交结果；控件可见并与断言一致。两次回答都故意固定30°，不以答对与否判本条。

[运行归档](../../archive/quality-diagnosis/runs/formal-004-quota-boundary-001/)130文件；[观察归档](../../archive/quality-diagnosis/observations/formal-004-quota-boundary-001/)含连续录像和精确进程采样；[独立复核](../../archive/quality-diagnosis/observations/quota001-review.json)含五PNG SHA、PID和两键读回。xcresult为Test-QiuJi-2026.09.08_19-05-26-+0800.xcresult。

仅补剩一题至购买后继续的有界链。前19次是夹具；不是实际连续答20题、真实商店/跨设备权益、所有题型或跨日活跃进程刷新。训练记录异步保存未在此查SQL，沿用既有认知数据诊断。未新增缺陷，SC32仍partial。
