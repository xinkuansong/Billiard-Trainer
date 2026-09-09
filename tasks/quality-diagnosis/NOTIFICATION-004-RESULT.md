# snapshot004通知实际执行结果

2026-09-07，当前局部记录，尚未完成全部SC38。基线见BASELINE-004.md。下面均为精确单方法，结果来自当前实际日志，未修改业务实现。每个已完成run已复制到archive/quality-diagnosis/runs/<run>/，含xcresult、原始日志和SHA256清单。

| run（formal-004-notification-前缀） | 结果 | 实际证据 |
|---|---|---|
| allow-probe-001 | 1/1通过，2.499秒，make0 | App OS权限notDetermined、提醒偏好false、待通知0，无其他请求 |
| allow-ui-001 | 1/1通过，40.529秒，make0 | 正常我的→训练目标，实际系统弹框同时有不允许/允许，点击允许，状态已开启、开关1 |
| allow-observe-001 | 1/1通过，0.588秒，make0 | App OS权限authorized、偏好true、daily-reminder仅1条，19:00、repeats=true、通知标题/正文/sound与预期一致，无其他请求 |

Allow设备CB246F30-E917-492B-B0C4-511F473D8C15，iPhone17Pro/iOS26.2；Light/large/对比度disabled已设置回读。主控实际目视allow-ui-001三张PNG：请求前开关关闭、系统允许/不允许弹框、完成后开启且时间19:00。当前证据不证明锁屏/后台实际送达、真实声音、跨时区或所有系统设置组合。

Deny设备0AFA3D75-DB70-405C-8E4B-B38C5221D0CF，独立新建；deny-probe-001 1/1通过0.788秒make0，初态未决定/无请求；deny-ui-001 1/1通过47.384秒make0，真实系统点击不允许，App显示无法开启提醒/知道了，确认后开关0并提示系统权限未开启。主控实际审三张系统拒绝/解释/最终状态图；deny-observe-001 1/1通过1.998秒make0，OS denied/0/false。随后deny-retry-ui-001 1/1通过35.974秒make0，拒绝后再次点击只见App解释、关闭保持；deny-observe-002 1/1通过1.363秒make0，实际仍denied/0/false。拒绝分支五次运行均归档，专用Deny设备已关闭保留。拒绝后重试已完成，改时间与关闭取消仍待；不把前置探针或开关变绿单独当整个通知功能通过。

## 时间输入测试失配保留

allow-picker-ui-001 1/1通过35.104秒make0；主控实际打开PNG/AX，系统popover两轮值19点/00分钟，关闭控件PopoverDismissRegion。观察通过只证明真实展开。

allow-change-ui-001 1失败27.078秒make2/xcode65：当前快照把时间选择器子节点暴露成Button/现代StaticText，与前次AX Other不同；失败于读19:00前，未修改时间。保留xcresult及导出层级。allow-change-ui-002 1失败28.094秒make2/xcode65：已读到19:00并打开轮子，但adjust拒绝20点，实际错误明确列出可选值为01…23、00。两者是定位/动作参数失配，不能算产品排程失败，也不能算测试通过。独立003保留全部时间断言，只使用跨类型同标签查询及滚轮可接受的数值字符串20/17。


## 2026-09-08 续接核验

allow-change-ui-003：1失败，28.262秒，make2；数值字符串20/17被接受为操作参数，但分钟读取实际15而非预期17分钟。紧接allow-change-observe-001：1失败，1.477秒，make2，独立OS读取authorized/true/1条重复请求，实际20:15，而预期20:17。原始失败均已归档。尚不能区分滚轮未到目标、动画时机和保存行为，不能认定时间修改通过，也不能据此确定业务根因。后续需独立复验正常选择与最终保存的一致性。

本日核对专用Allow设备为Shutdown，已仅启动该设备执行关闭/重入检查；未操作正在运行的其他设计任务设备。

关闭取消完成：formal-004-notification-allow-disable-ui-001实际1/1通过39.707秒make0；正常关闭、重入仍关，主控目视最终PNG，关闭开关/无时间行/系统权限仍开启一致。随后formal-004-notification-allow-cancel-observe-001独立宿主1/1通过0.577秒make0，实际authorized、reminderEnabled=false、dailyRequestCount=0、otherPendingCount=0。两次xcresult及源/日志均已归档。此证明关闭取消，不证明后台实际送达。

notification-time-preprobe001实际1/1通过0.615秒非skip，authorized/false/count0，51文件归档。主控全文审核独立NotificationTimeDiagnosticUITests.swift并注册（4新增0删除、全部custom scheme字节恢复）；notification-time-ui001由session90663执行，严格一次minute17、稳定采样与关闭/重入，OS单独后续读回，未预报成功。

通知时间聚焦三run全终态：preprobe1通过0.615s；UI1失败50.634s，稳定轮14/关闭与重入20:14；postprobe1失败1.177s，OS唯一重复20:14≠严格17。三层实际值一致，目标17未输入成功，不判保存把17改14；按方案停止重复调轮。主控三完整图审另见关闭PopoverDismissRegion后目标3→2副作用，专用状态已记录（提醒开20:14、目标2），不新增产品缺陷/不静默复原。详NOTIFICATION-TIME-004-RESULT.md。
