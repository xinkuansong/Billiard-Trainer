# 通知时间单次聚焦复验：目标输入未实现，实际值三层一致

2026-09-08，snapshot004，原Allow专用CB246F30-E917-492B-B0C4-511F473D8C15，iPhone17Pro/iOS26.2，正常Free游客，启动前内存容器。正常授权已存在，不重复请求允许/拒绝，无系统时钟修改。

| 执行 | 实际结果 | 归档 |
|---|---|---|
| notification-time-preprobe-001 | 1通过0.615s，非skip，authorized/false/count0 | 51文件，16-04-50 MemoryHost xcresult |
| notification-time-ui-001 | 1失败50.634s，make2 | 1164文件，16-05-48 QiuJi xcresult |
| notification-time-postprobe-001 | 1失败1.177s，实际minute14≠17 | 实际16-07-43 MemoryHost xcresult |

均在 archive/quality-diagnosis/runs/formal-004- 加上表中执行名，全部终态；session91718/90663/39353结束，不再轮询。

主控全文审阅准备和独立草稿，注册仅4新增行0删除，全部custom scheme字节恢复；overlay在archive/quality-diagnosis/snapshot-004/overlays/notification-time-001。全程不修改产品实现。

## 真实值与判定

UI正常开启后初值为19:00（实际读回，不沿用预计旧20:15）。小时只adjust20一次，picker enabled且相隔约1秒两次稳定20点/00分钟；随后仅一次分钟adjust17。之后相隔约1秒两次均为20点/14分钟，picker enabled。保留FAILED-TARGET而继续正常关闭/重入采集，最终XCTFail，没有修改目标14来报绿。

关闭态两次稳定20:14，重入两次稳定20:14。主控完整查看轮值、关闭、重入三张PNG，与JSON单调采样一致。独立OS读到authorized/true、唯一qiuji.training.daily-reminder重复请求20:14、有sound、无显式timezone、无其他待通知；严格expected17保留失败。

因此：本次稳定选中值→关闭值→重入值→OS触发器一致。20:17输入没有实现，不能称保存把已选17改成14，也不能确认旧失败唯一来自两次调整太快；本次已分开等待仍不到17。XCTest adjust与当前DatePicker交互/异步绑定的具体原因未定。按已审准备仅做这一次变体，不继续滚轮直到绿，不因没有真机推给人工，更不声称通知实际送达。

## 额外操作副作用与界限

主控图审发现：轮值截图每周目标仍3天，PopoverDismissRegion.tap后的关闭/重入图每周目标为2天。原测试没有选择目标2天的显式步骤；关闭区域可能把点击传递到下方2天选项，属于本次诊断操作副作用线索，未据此新增产品缺陷。专用游客目标2天保持，未清库/重置或静默恢复。后续若重用此设备必须读回实际状态，不假定3天。

当前设备提醒开启且OS每日20:14一条请求，目标2天；保留本次真实状态。数据仍为专用诊断用途，不涉及用户真实账号。已知关闭操作副作用不改变先前稳定轮14的证据，但不能把本轮当作无额外操作的严格全旅程通过。

未验：目标17成功选择、所有分钟/时区、锁屏实达/声音/LiveActivity。原通知允许、拒绝、关闭0请求通过证据保持独立；本分支为有界输入观察限制及实际保存一致性证据，不重复旧权限链。
