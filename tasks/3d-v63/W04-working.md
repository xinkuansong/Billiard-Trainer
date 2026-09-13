# W04：运行时空间记录与时间契约

2026-09-12，真源v63.5。W00基线已就绪，W03验收文档已完成。仍保留W05–W16/H01–H04全部范围。

## 当前实现
- TrajectoryRecorder新增PocketEntrySnapshot，保存吸袋/清零前BallState、绝对时间、稳定袋ID、完整值类型TableGeometry与planar-capture-v1标记。来源event/boundsFallback/analyticRollout；明确只是旧捕获边界，不冒充支撑丢失。
- EventDrivenEngine正常resolvePocket与边界兜底记录；AnalyticShotRollout.SingleBallResult携带同类型入口快照。已经被兜底捕获的球不再次解析同一捕获事件。
- 兜底在evolveAllBalls内部处理，真实状态时刻为currentTime+dt；此前resolvedEventTimes误用推进前currentTime。现在显式传stateTime。无下一事件分支先提交maxTime再记末帧，避免先进球位后仍记旧时间。
- SpatialMotionSegment是无接触自由段的不可变契约：绝对起始时间、正时长、真实p/v/omega、加速度、ball/pocketID和阶段；查询越界返回nil，段内闭式重建。碰撞必须分段，不能让此类自行穿透实体。W05/W06将接入求解，当前回放未切换到空间求解。
- 旧BallFrame/BoardSnapshot/PlannedShot字段未改；不批量改内容或存储。

## 测试
contract-r1四项中一项失败：测试错误假设centerX=1.31边界到达必由兜底，实际正常CCD成功。入口p/v/omega/time断言均通过，原日志保留。
修正夹具：原边界样例明确正常事件；另加初始已经在孔圈、短推进未触及下一根的兜底样例，不改生产来强迫走某路径。contract-r2五项0失败/TEST SUCCEEDED：含两类入口与解析绝对时间、自由段乱序查询/能量、旧记录回放及原自然停稳测试。
parity-r1正在执行，exec67668：AnalyticRolloutParityTests三项及DrillTryoutBoardStoreTests/test_allBundledBoards_decodeAndInRange；门禁exec82942。先轮询，不重复启动。

## 仍须完成
补测结果、源码审计、DR/规则回写和验收文档。不得将W04视为自然入袋或跳球已实现。W05必须重新测量支撑/袋沿几何，保留入口不是物理接管完成。


收尾：parity-r1四项0失败/TEST SUCCEEDED，exec67668退出0；verify-gate FAIL=0，exec82942退出0。DR-144已同步规则/UI规格。逐项验收见W04-acceptance.md。本任务无存活测试进程。下一步W05：角袋/中袋局部空间几何与自然下落原型，依赖W04已就绪。
