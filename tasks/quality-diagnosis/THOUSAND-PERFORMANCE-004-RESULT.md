# 千条磁盘历史与统计：一次性能观察

2026-09-08，snapshot004，SC36。保留旧snapshot003功能结果；旧设备/原件当前不可复用，因此仅重建本次合成性能前置，不重复详情999/978链。

- 新专用iPhone17Pro/iOS26.2：CCA94E7E-981D-4F16-A115-40677FC3097C，实际Light/large。
- probe001：1/1通过0.013秒、51文件；确认内存宿主和默认磁盘不存在。
- seed001：1/1通过0.425秒、49文件；严格按实测owner/相对路径/当天日期写1000条。
- UI001：测试日志格式化API编译失败，0方法、make2/recorder0、25文件归档；不是产品失败。仅两处NSStringFromCGRect改String(describing:)后独立UI002。
- UI002：唯一方法 `ThousandPerformanceDiagnosticUITests/testObserveThousandRecordScrollStatisticsAndReturn`，1/1通过210.634秒、make0/recorder0、83文件与observer归档。

正常磁盘启动→记录页→一次短滚动→实际完整可点记录行→统计概况2000分钟/1000组→一次摘要滚动显示8000/10000球与1,000组同一分类行（图为80%）→历史返回。五张完整PNG已逐张核，首次日历与滚动后的列表确有视觉位移；没有打开详情或遍历千条。`forcePremium`仅开放统计，不作购买证据。

## 计时口径与实测

以下均为操作到指定AX断言完成的自动化区间，包含XCTest输入派发、idle等待和可访问性查询；非纯App延迟。完整截图与AX采集放在区间外，但仍可能预热下一阶段，统计视图本身也可能预加载。不能相加当冷用户旅程，未规定或放宽SLA。

| 区间 | 秒 |
|---|---:|
| 单次启动到记录Tab可操作 | 33.623 |
| 点击记录到历史/月标题ready | 33.755 |
| 一次短拖到实际行ready | 44.524 |
| 点击统计到概况ready | 8.743 |
| 一次统计短拖返回（非摘要ready） | 2.688 |
| 拖后摘要AX检查 | 2.554 |
| 返回历史到实际行ready | 23.542 |

实际App PID30679，186个RSS样本，首8.25MiB、末331.02MiB、峰1607.69MiB。高峰是需关注的观测，但包含大量AX活动；不是普通交互内存、泄漏或真机达标结论。连续录像保留，未作逐帧时长/FPS分析，不能以5个关键帧宣称动画全程流畅。没有因数值大而臆造性能缺陷，也未宣称性能通过。

## 独立数据链与边界

终态宿主后SQLite备份独立核1000场/entry/set，队列0，全部唯一游客owner，时长2000分钟、成功8000/目标10000球、1000唯一note。UI安装后容器根虽重定位，结束时manifest逐字节保持，四表数量和owner/总时长再次核对不变。

- [种库独立证据](../../archive/quality-diagnosis/observations/thousand-perf-seed001/)
- [UI运行83文件](../../archive/quality-diagnosis/runs/formal-004-thousand-perf-ui-002/)，xcresult `Test-QiuJi-2026.09.08_19-10-15-+0800.xcresult`
- [观察原件](../../archive/quality-diagnosis/observations/formal-004-thousand-perf-ui-002/)
- [时间/RSS/五PNG复核](../../archive/quality-diagnosis/observations/thousand-perf-ui002-review.json)
- [运行后磁盘核对](../../archive/quality-diagnosis/observations/thousand-perf-ui002-disk-after.json)

本次有限千条历史/统计观察已完成；单日同类合成数据不是真实跨千日、多类型工作负载，不再重跑同质长链。真机热耗电、正常触控性能、长期内存仍列外部补测；SC36继续partial。
