# 单球形击球试跑：记录口径

## 本次边界

从135,700球形库取`grid-v3:1512:68:1`（原生成切角17°），完整消费上一轮冻结的45打点×14杆速，630组不重新随机。不放第二颗球；第二球候选数组保持独立。

走`ShotPredictor.predictForPositionSolve`：生产走位求解的自动瞄准/事件引擎入口，`includePresentation=false`，每组500事件/15秒上限。使用原题库下球点作为`pocketAimOverride`，保持原目标袋；不做打点/杆速精修。此次未走`PositionPlaySolver.scanMatrix`的外层解析rollout与缓存，所以耗时不能当作全量优化扫描性能。本次是字段/落点试跑，不是全量速度基准。

引擎仍在内存中生成求解必需的记录；持久化结果仅保留输入、终态、关键事件，**不保存帧、折线或完整轨迹**。研究测试追加到独占源码快照，不改App实现或题库。

## 文件级/球形级只存一次

- schema版本、原球形ID、原始C/A坐标、原袋号、原下球点、生成角度；距离单位米、角度明确度/弧度。
- 采样文件与源题库SHA-256、原随机种子协议；源代码指纹、物理模型、桌面高度/球半径、模拟限额。
- 计算入口与是否使用解析外层扫描、运行设备、批次耗时。冻结的Swift测试和输入一同保留。

## 每次运行必须保留

| 内容 | 字段/用途 |
|---|---|
| 唯一身份 | `trialID`, `tipID`, `speedID`，与球形ID关联 |
| 精确击球参数 | `spinX`, `spinY`（球半径单位）、`velocity`（m/s）、`simulatedElevationRadians`；存原生Float实际值，原双精度输入另在input.json |
| 实际瞄准 | `strikeDirection`、`aimOffsetRadians`、`pocketAim`；可固定方向复跑，避免重求方向改变答案 |
| 出杆可达 | `cueAccessAvailable`、`accessElevationRadians`，使用实际方向/打点和渲染球杆包络 |
| 结束依据 | `termination`、`resolved`、`cueEndSpeed`、`simDurationSeconds`；时间/事件上限并非停稳 |
| 落点 | `cueStopValid`及有效时才出现的`cueStop`；`cueEndPosition`只是末端观测，不能无条件当停点 |
| 进球 | `targetPottedSelected`、`targetActualPocket`、`cuePocketed`、`cueActualPocket` |
| 碰撞 | `cueTargetContactCount`、`firstContactTime`、碰前吃库数、碰后主库/袋角/其他库次数、目标球吃库数 |
| 短事件序列 | 球-球、吃库、进袋的时间、对象和库段/袋号；可复算吃库数与顺序，不含逐帧路径 |
| 参数合法性 | `parameterStatus`为legal/illegal/undetermined；在实际瞄准方向下无法出杆=illegal，不进入走位结果。未能求得方向时不能冒称已验证出杆 |
| 使用状态 | `status`（illegal_parameters/success/target_miss/scratch/unresolved等）、`usableForPositionMatch`、`failureReasons`（可以同时多项失败） |
| 性能诊断 | `wallMilliseconds`；量产可改批次聚合，失败原因不能丢 |

## 判定注意

1. `settled`为全场停稳；`interestResolved`为生产引擎证明关注球不再平移（可保留原地自转）。两者可标有效停点，另需母球未落袋、末速近零且坐标有效。其余结束状态保留失败/未完成记录。
2. 主库吃库与袋角分开。`cueCushionTotal`包含袋角，不能直接当用户所说主库数量。主库接触按事件计数，不合并重复同库；短事件序列保留实际先后。
3. 本次“可用于走位匹配”仅要求出杆可达、指定袋进球、母球未落袋、结果已解析且停点有效。碰前库/袋角/多次碰球都如实标记，未擅自新增淘汰规则。
4. 物理沿用求解模式的平面击球（elevation=0）。球杆可达检查的仰角是几何姿态，**没有把该仰角代入本次物理重算**；两者分别记录，不声称抬杆动力学已验证。
5. 后续某一B被匹配为第二球时，可用冻结参数加入B重跑检查干扰，不必为全部630组合永久保存轨迹。
6. 本次无原生页面变动、无球桌界面图，仅离线参数结果矩阵与统计图；球桌页面TP01–36不适用。原生测试通过不代表题库已人工验收。

用户补充（本轮）：无法出杆明确归类“非法参数”。`results.json`保留原生测试原始输出；`records.jsonl`依据原始出杆检查追加parameterStatus/status，不修改物理结果。此次只运行一个球形，未启动135,700球形全量模拟。
