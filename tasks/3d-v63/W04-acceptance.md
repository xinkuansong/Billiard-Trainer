# W04 验收：入口状态与无接触空间段

2026-09-12，按v63 §8 W04验收完成。本批没有实现自然落袋，不改变普通内容为三维存储。

| DoD | 证据 |
|---|---|
| p/v/omega/time/pocketID无损 | contract-r2正常入口、短时兜底入口与解析rollout入口测试；以原滚动解析式核对状态，入口在吸袋/清零之前；完整TableGeometry值快照保留 |
| 运动段查询可重复 | SpatialMotionSegment按绝对时间查询；乱序重复/端点/越界/非有限时间及动能+重力势能测试 |
| 旧记录/二维内容 | 原BallFrame和BoardSnapshot/PlannedShot字段不变；旧帧回放、自然停稳测试通过；parity-r1实际Bundle球形全部解码与范围检查通过 |
| 不冒充自然进袋 | 记录明确标planar-capture-v1；局部几何/支撑/碰撞/规则与统一空间播放仍由W05–W08完成 |
| 回归 | contract-r2 5项0失败；parity-r1 4项0失败（AnalyticRolloutParityTests三项＋Bundle球形一项）；构建测试均TEST SUCCEEDED，verify-gate FAIL=0 |

记录同时修正两处旧时钟不一致：推进内兜底使用stateTime=currentTime+dt；无下一事件先更新主时钟再写末帧。contract-r1失败是测试误判路径来源，保留原日志；正确兜底夹具独立验证，不弱化入口数据断言。

证据在output/3d-v63/W04；DR-144完成接口/规则回写。无新的UI改动，不重复拍辅助线截图；真机性能、物理可信度与自然进袋验收仍在后续批次。
