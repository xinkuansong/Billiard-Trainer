# v66 扎杆与跳球自由练习实施

2026-11-17，用户授权一次完成自由练习页，入口放在「练习／进阶」；两个答题模式后续。

基线：fcbdfaff；打包依赖补齐提交8b601624、e632be76。首两轮远端基线因历史Git忽略的TrainingRoom打包网格缺失，在测试执行前失败；补齐后R3构建通过但默认设备容量受保护，R4改用独立SE3完成测试。旧记录不改为通过。

## 设计与隔离

- 新页SpatialPracticeView及独立TeachingTableHost，不接入旧PositionPlayViewModel或训练答题成绩。
- 请求显式指定SimulationModel.spatialPractice，appDefault仍为planarReference。ShotPredictor.simulateFree新增默认0的elevation，只有新模型消费空间冲量。
- 与现有空间求解器共用事件时钟、台呢、球球、库边和袋口；新模型额外请求独立不可变外部几何。旧模型不会触发外部几何加载。
- 坐标X/Z水平、Y向上、米；场景地面Y=0，床面和半径引用代码常量。几何来源是实际打包桌体，外侧材质排除重复台呢/皮革/网兜。
- 桌外运动仍受重力与碰撞；完成后根据真实停点区分台面/袋内/桌外。台面矩形越界不触发早收球。8m模拟域越界明确报错并恢复杆前，不冒充静止。
- 页面持久键spatialPractice.v1.<owner>；独立偏好masseJump；正式击球与回放消费同一已冻结轨迹。240Hz展示采样另插入已接受物理分段端点，物理结果不由采样积分。

## 批次

|批次|状态|证据／剩余|
|---|---|---|
|B0旧路径基线|进行中|output/v66/baseline-result失败证据；远端v66-baseline-20261117-r2|
|B1请求隔离|实现中|默认未改，待逐位同输入回归|
|B2正式空间击球|实现中|独立host冻结输入，待真实编译／击球|
|B3外部碰撞与校准|实现中|真实桌体+地面，材料目前候选值，需数值与几何图验证|
|B4自由页|实现中|进阶入口、球库、瞄准、速度、打点、抬杆、相机、示例|
|B5恢复／回放|实现中|独立记录、重打、慢放、取消代际；待测试|
|B6UI与隔离验证|待执行|以v66 TP01–36完整表为检查入口|
|B7最终验收|待执行|不可将候选材料和模拟器证据冒充实球标定或真机通过|

## 适用性与验证

完整TP01–TP36判定沿用[方案](../../问题集合_v66.md)；本记录逐项补实际证据。共享壳无页面业务改写，新增偏好／布局枚举采用独立身份。未完成项保持待验证，不作不适用。

功能矩阵：初始示例；0/高角度；左右对称；仅母球／16球；回袋／出桌／反弹回台；计算取消与过期回调；运动退出；回放停止恢复草稿和相机；重打参数完整恢复；owner切换；空桌恢复；旧页同参数默认与显式平面精确一致；旧页与新请求交错。

## 当前校准边界

公式来源与核验参考：[pooltool空间击球接口](https://pooltool.readthedocs.io/en/latest/autoapi/pooltool/physics/index.html)、[3D击球保留垂直冲量的原始实施讨论](https://github.com/ekiefl/pooltool/issues/314)、[Dr. Dave抬杆效果](https://drdavepoolinfo.com/faq/cue/elevation/)。这些支持模型结构和变化趋势，不提供当前中国八球桌/杆/台呢的实测材料标定。本页沿用现有候选台呢垂直恢复系数0.3；桌体0.35、地面0.2为显式近似材料，不声明实球高度或落点的毫米级准确。240Hz显示采样误差界只约束已求出的抛物段插值，不是现实模型精度。

坐标数值验证：`python3 scripts/spatial-v66/coordinate_check.py`，16个方位/角度正交基全部通过，地面法向+Y；证据output/v66/coordinate-contract.json。

本机构建R3/R4完整App及测试target通过；R5含侧面观察与存档深度校验继续构建。门禁路由登记新增1页，总99页；verify-gate通过。模拟器运行不继承构建通过状态。

## 2026-11-17 定向运行与返工

- 基线R4：iPhone SE3／iOS26.2，64项执行、60通过、4原有失败（PhysicsEngineTests的三项bankSolve测试及test_kickLowPowerContactHasPhysicalWitness）；ScoringOnlyConsistencyTests 6/6。原件：output/v66/baseline-result-r4。
- 首个候选R1：ScoringOnlyConsistencyTests 6/6；新页数值7项中6通过，floor实物接触／停点已通过，附加的中心台面精确接触断言因Float高度转换不成立。修订为验证地面停球不会被交回台面。左右扎杆镜像、真实单球跳起落台、记录往返、偏好隔离、旧引擎逐位一致均通过。
- R1原生UI真实进入进阶新页，抬杆操作通过，但默认三球示例无法完成，保留失败。日志定位0.288秒落台时两相邻台呢面法向差1.84e-7，jointImpactIterationLimit；运动残差4.06e-16而冗余冲量残差1.12e-8。新增仅新模型启用的同材质近平行法向合并，阈值1e-6（球面接触点差约0.029微米，小于1微米空间容差）；旧模型参数为0，原接触求解函数与几何文件不改。新增该实测失败状态的不增能回归。
- R1证据：output/v66/feature-result-r1；分析副本feature-r1-analysis.xcresult，截图及诊断分别在feature-r1-attachments／feature-r1-diagnostics。SE画面已打开核对；功能失败不标为通过。
- 本机构建R3–R7通过。R8被几何文件指纹门禁拦截后，将新处理移至页面独立扩展，原TableGeometry.swift字节恢复，无放宽门禁／改写题库历史指纹。R9继续构建。
- 首轮诊断设备与远端临时构建在证据回传并逐文件核验后按生命周期精确退役／清理；未操作其他任务设备。
