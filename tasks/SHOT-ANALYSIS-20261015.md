# 每杆物理分析 · 2026-10-15

用户授权：先备份序列，在每杆新增 analysis，新录制自动生成；不改 before/after、原击球参数、方向、物理与瞄准逻辑、不改精讲内容、不保存 trajectory、不加分离角。后续明确同时保存瞄准角与实际切球角。

状态：实现、迁移与验证完成；未安装真机、未提交或发布。证据目录 `output/shot-analysis-20261015/`。

## 数据定义

所有矢量均 SceneKit 世界系：XZ 水平、Y 向上；距离 m、速度 m/s、角速度 rad/s、角度 degree。沿用 BallPhysics/AngleSceneCalculator 的真实常量和纯几何函数。

- `analysis.schemaVersion = 1`；`engineVersion = qiuji-planar-reference-20261015` 对应本次备份内物理代码 SHA 清单；这是分析的物理来源版本，不参与求解。以后更动物理必须更新该标识并重生成分析。
- `aim.aimAngleDegrees`：击球前母球→假想球的瞄准线与目标球→引擎进球瞄点的进球线夹角。进球瞄点用现有 effectivePocketAimPoint（含贴库管道几何），假想球用 ghostBallPosition 在反方向退 2R；不使用补偿后出杆射线生成的展示 ghost。保存 targetBallKey、pocket、pocketAimPointMeters、ghostCenterMeters 供核对。纯自由瞄准无进球线，aim 缺省，noAimReason 明示；不从实际碰撞方向倒推几何瞄准角。
- `firstContact.actualCutAngleDegrees`：第一次实际施加球球碰撞冲量前，母球入射水平速度与母球→被碰球球心连线的夹角（0…180°，静止目标常规为0…90°；移动目标碰静止母球可能没有定义）。使用 make_kiss/约束后的实际冲量几何与碰前球态。
- 同时保存首碰球键、时刻、母球碰前速度/角速度、引擎 motionState、底部接触点滑动速度。`cueForwardRollRatio = R * omega·(up×v)/|vXZ|²`，正为顺滚、负为回旋，1为沿运动方向的纯滚动分量；侧旋另在 omega.y，不仅凭 ratio 判定整个球态。
- `cueCushionContacts` 按真实已解算事件排序，保存时间、原始 cushionIndex、四主库坐标侧、首碰前/后阶段；袋角/喉壁 mainRail 缺省。主库次数由 mainRail 非空条目数得出，原始事件不擅自合并，方位不受摄像头旋转影响。无球球首碰时为 noBallContact。
- `cueTravelDistanceMeters`：按同次模拟的无碰撞帧区间对水平速度积分（8点Gauss-Legendre数值求积，速度复用引擎 AnalyticalMotion）；终点为停稳或平面入袋边界，不计 make_kiss/分离校正的瞬时跳跃、入袋吸附、袋内呈现。不是两点直线距离，也不是落盘轨迹。
- 没碰球时 firstContact 缺省且 noContactReason=noCueBallCollision；无速度/退化法线时角度缺省且写原因，绝不伪造0。未停稳/不支持的模拟不发布分析。
- analysis 可选；旧档缺省正常。损坏的 analysis 单独带 step ID/codingPath 日志后忽略，原击球字段仍严格解码。生产回放不读取 analysis。新录制、单杆替换、重录后续与编辑器重建均从本杆实际 prediction 提取。

## 备份与保护

- `before.zip` 249个源/Bundle/历史序列及相关实现文件，逐个SHA验证。103份当前源（639杆）、98份Bundle（629杆）；历史子目录不迁移。
- `protected-hashes.json` 冻结精讲JSON与发布图片；`baseline-hashes.json` 冻结原始序列和物理等源文件。
- `baseline.log`：修改实现前103份639杆的当前方向回放成功；`replay-before.json` 包含全球120Hz播放位置、停点、进袋集合，不能覆盖。

## 验证

- `analysis.log` 首轮23测试通过（尚未加入几何瞄准角）。
- `dual-angle.log` 的18项真实录制/重录测试全部通过，包括进袋／自由、选杆单替换／重录后续／原杆保存／取消；每次核当次prediction产生的analysis与录制后JSON读回值相等。整轮25项有2项诊断断言失败，未记整轮通过：一项把进袋球内部末坐标误当台面停点；一项把Float接触几何的近似正碰误当数学精确0度。
- `legacy-pocket.log` / `legacy-pocket-diagnostic.json` 使用本次备份逐字节相同的旧EventDrivenEngine（无观测hook），复现c060第4杆已进袋的_11内部末坐标53.5445mm差异：boundsFallback保留口沿坐标，event路径吸附袋心。该值不在after中，也不是台面停点。跨进程Dictionary顺序引起已有事件边界浮点差异，物理/瞄准不改。该轮全库台面轨迹和未进袋停点差异≤0.000357628mm。
- `final-analysis.log` 最终7/7通过：六项数值／单位／正负旋转／主库与袋角／退化／损坏元数据隔离／双角度独立／真实碰前状态测试，以及103份639杆迁移对照。生成的最终数据与修改前120Hz回放相比，最大位置差0.000119209mm，进袋集合一致。数值测试用atan2独立复核真实切角，几何0/30/45/60度样例及图示见angle-contract.*。
- `apply-migration.py` 只插入analysis字符，删除新增字符能逐字节恢复原文件；before/after/shot/recordedDirection/id/时间戳均不变。98份Bundle通过正式tryout-sync入口与真源逐字节一致。`bundle-integrity.json`：629杆，574个瞄准角、591个实际切角；55杆纯自由无进球线、38杆无球球碰撞。新增586209字节（572.47KiB）。
- 精讲JSON和704发布图等保护集合SHA保持；C1–C4、内容门禁、文档体积门禁通过。C1为元数据增加了带完整输入/帧SHA的证据分支，4个构造性测试覆盖改参数／方向／before／after、改图、坏证据和无证据，不能无条件豁免analysis文件。92组796张旧图仅在与原渲染冻结输入/图片SHA完全相同后建立证据，不改图、不改时间戳。
- `production.log` 5/5通过：实际生产控制器95个有杆球形629杆全部finished、无接续错误（2D/3D交替）；3个空归档读取通过。覆盖五分点、两库走位及初/中/高级蛇彩全部球形，高级蛇彩球形2为15杆。包内629杆有/无analysis的完整引擎帧、120Hz播放位置、停点逐位一致；没有持久化trajectory，回放仍基于before和已保存方向计算。
- `final-integrity.json`：103份源639杆、98份Bundle629杆移除analysis后所有字段与备份相等；8个历史备份与779个精讲/图片保护文件SHA不变，Bundle与真源逐字节一致。没有真机安装、提交或发布。

- `final-contract.log` 最终7/7通过：六项分析测试（含缺省analysis旧档与损坏元数据兼容），以及一杆隔离的原生精讲图片导出。新生成3帧及render-input.json由真实C1消费端验证通过（render-proof-roundtrip.json），未回填任何生产图片；临时烘焙开关与请求已清除。
