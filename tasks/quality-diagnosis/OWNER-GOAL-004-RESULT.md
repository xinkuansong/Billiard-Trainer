# 每周目标按身份隔离：有界补验结果

2026-09-08，snapshot-004，SC14，诊断未改业务。

唯一选择器：`QiuJiTests/OwnerGoalBoundaryDiagnosticTests/testWeeklyGoalsRemainOwnerScopedAcrossSaveSwitchAndStoreRecreation`。实际1/1通过，0.019秒，make退出0。

专用新设备 `D9A95BFC-2E3C-4EFA-A470-B9F2F7373282`，iPhone17Pro/iOS26.2；使用App初始化前启用的内存宿主，无真实登录凭据，三个Store共用独立UUID defaults并显式注入受控backend。

| 阶段 | 实际结果 |
|---|---|
| 初始 | 三个Store默认3，三个owner持久键未设置，请求0 |
| 游客保存 | 2天，本地对应键2，请求0 |
| A保存 | 请求4天、受控响应5天；Auth、Store和A键均5 |
| B保存与非法值 | B为6天；随后0、8拒写，三个值保持2/5/6，请求总计2 |
| A→游客→B | 新Store缓存及load后分别5/2/6；三个持久键仍2/5/6，请求总计2 |

主控逐份读取五阶段JSON，核对身份、同步关闭、请求字段/响应、持久键及Store状态；没有失败快照。重建CurrentOwnerContext也保持相同游客键。保存结果以返回的服务端资料为准，未把请求值4当最终值。

[运行归档](../../archive/quality-diagnosis/runs/formal-004-owner-goal-001/)含54文件、测试源码、五阶段JSON和SHA清单。xcresult：`Test-QiuJiDiagnosticMemoryHost-2026.09.08_18-56-55-+0800.xcresult`。

仅证明本地真实Store/Auth与owner键隔离行为；backend是受控实现，不能外推HTTP认证归属、真实账号、跨设备同步、冷进程磁盘持久性或提醒权限。当前首页目标刷新缺陷QD028仍开放，本方法不重复或取代该UI链。SC14维持partial。未新增产品缺陷。
