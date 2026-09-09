# 休息后台自然归零诊断 — snapshot004

## 预先范围与判定

对应PLAN-v2原SC10/38及剩余包7。正常游客入口创建自由训练并开始计时、开始默认休息，记录实际剩余秒数；Home进入后台后真实等待该秒数+2秒，再激活App。预期休息按钮恢复“休息设置”，完成休息按钮与休息胶囊消失；下一次正常休息可开启并继续递减。首轮绝不手动结束、不注入倒计时、不更改系统时间。默认值若超过60秒直接保留失败而不无限延长。

代码锚点已核对：ActiveTrainingView.scenePhase恢复调用refreshTimers；ViewModel以restEndDate计算剩余时间并在到零后调用完成逻辑。此实现仅用于定位，正常倒计时到期应结束的预期来自计时旅程。源文件只增加独立诊断方法，已注册类无需重新生成工程。

专用已有ContentBundle模拟器401DEA72-01DD-46C2-B774-86B7D58BC06C；inMemory、Free游客，无真实身份。仅覆盖模拟器普通后台跨零及新休息，不证明系统真实挂起、锁屏通知/声音/触觉、Live Activity清理、休息是否计入累计时间或跨进程恢复。

执行：formal-004-rest-background-zero-001。已终态，见下方实际结果。

## 已执行与审查结果

休息后台自然归零正式补测 formal-004-rest-background-zero-001：1/1通过108.985秒，make0。实际59秒时进入后台，单调时钟等待61.004652秒；返回休息状态清除，重新开启59→56秒（约3.1秒）正常递减。3张完整PNG及对应AX已由主控核对，69文件含真实xcresult/源哈希归档。仅模拟器普通后台同进程，不证明系统挂起、锁屏通知/Live Activity、触觉声音或休息累计口径；无新增问题、无业务修复。

归档：archive/quality-diagnosis/runs/formal-004-rest-background-zero-001。xcresult：Test-QiuJi-2026.09.08_16-15-53-+0800.xcresult。初始59秒浮层、返回后正常记分页与休息设置、下一轮56秒浮层均已完整目视。App PID80139由测试正常结束，session92715关闭。
