> 当前正式题库（2026-11-05，剔除目标球间碰撞）：轨迹3511题7928参考，四类709／866／898／1038；自由58470题不变。沿用固定镜像、20×20去重与禁止袋角接触。参考ballBall事件必须包含母球，排除目标球再撞其他目标球的方案；借静止球遮挡保留。
>
> 正式来源：`output/defense-no-object-contact-20261105/bank/`；生成/发布入口：`research/defense-no-object-contact-20261105/filter.py`与`publish.py`；App资源路径不变。来源指纹、SHA与删除事件见同轮`publication.json`、`removed-references.json`。原3777题9119解删除1191解，266题无剩余参考后移出轨迹库。详`tasks/DEFENSE-NO-OBJECT-CONTACT-20261105.md`；旧包保留审计。

# 防守参数题库与页面接入交接

最初开发交接样例（历史）：`content/defense-bank/pilot-v1/`，18个球形、44个参考解，来自固定20题约束内重算。每类有解题数为5/4/4/5；另外两题仅在coverage.json记为inaccessible，不进入轨迹题索引。当前包用于功能页面开发和预览，未完成实桌或独立稳定性验收。

- 数据契约：[FORMAT.md](FORMAT.md)
- Swift Foundation解码类型：`scripts/defense-bank/DefenseBankModels.swift`
- 可读完整示例：[pilot-v1/example-question.json](pilot-v1/example-question.json)
- 包入口：[pilot-v1/index.json](pilot-v1/index.json)
- 校验结果：[pilot-v1/audit.json](pilot-v1/audit.json)
- 对照图册：`output/defense-constrained-20-20261104/r1/review.html`

## 初始交接合同（当前包与接入状态以上方更新为准）

1. 复用两球走位的参数包读取方法：index → 校验gzip分片SHA/字节数 → 解压JSONL → 用索引的0基line取题并核id。按需加载，不必一次加载所有轨迹。
2. `DefenseBankQuestion`已经包含完整初态。摆球使用cue和balls，不用来源网格反推，也不从sampleID解析球号。用户应击打ownBallNumber；对方当前合法球为opponentBallNumber。单球双方均为8合法。
3. 首次自主作答前隐藏参考方向、终态和轨迹。参考解用于轨迹模式/答后展示；自由模式根据用户实际终态评估，不把离线参考分数作为用户成绩。
4. 生成参考时只按parameters中的direction/velocity/spinX/spinY做完整`ShotPredictor.simulateFree`，不重新寻优。使用当前台面高度及真实球杆可达性；命名母球用`ShotInput.cueBallName`，其余球用`_球号`。Float转换只发生在引擎入口，与原模拟一致。
5. 重放后核对纯防守合法性、执行约束、全桌停稳和对方效果；比对事件顺序、落袋集合及终态。失败参考不得照画旧expected终态冒充本次结果。expected是离线校验锚，轨迹由当前重放产生。不要将事件时间当成事件先后判断依据。
6. 不要复用“两球走位首球必须进袋、不能碰第二球”的成功判定。防守需要合法首碰己方球、随后碰库或合法落袋，禁止母球/己方球/黑八落袋；可以碰其他球，允许短路线再次球球接触。对方最后彩球合法落袋后改评黑八。
7. 完整直击遮挡才有score=100；其他参考score=null，展示/内部保留容错角和舒适分，非遮挡总分公式尚未确定。不能使用100−舒适分臆造已批准总分。四点扰动参与选解，不是成功率；低通过数需要保留参数敏感提示。
8. 题目和参考ID稳定，替换全量包不应按数组序号关联历史。整包fingerprint变化时当前训练段须显式结束/重新开始，历史尝试保留当时参数和实际回放。

本轮只提供内容包、DTO及合同；未接入App资源目录、未恢复延期的旧防守入口、未修改页面。页面会话负责接入路径、界面合同、原生验证及记录模型。

## 全量运行

授权范围：轨迹候选5698（1198＋1500＋1500＋1500），自由球形59000仍保持原库。

入口：`research/defense-full-5698-20261104/run.py`；八进程，共用一个冻结二进制，每进程独立输出/缓存/断点。

- 状态：`output/defense-full-5698-20261104/r1/status.json`（实际进程启动后出现）
- 启动日志：`output/defense-full-5698-20261104/r1/launcher.log`
- 分进程日志：`output/defense-full-5698-20261104/r1/workers/00` 至 `07/run.log`
- 成功后同格式全量包：`output/defense-full-5698-20261104/r1/bank/`
- 全部题覆盖：完成后的bank/coverage.json；未找到不等于物理无解。

全量未完成前先使用pilot-v1；不读取正在生成的分片作为发布库。最终包通过审计后再选择新包，不能覆盖pilot-v1原件。

评分实现参考研究源码：`research/defense-full-5698-20261104/Attack.swift`、`PipeWindow.swift`与`main.swift`中的assess/blockage/invalid/defenseRouteViolation。它们是研究入口，不能把整个main.swift加入App target；移植为页面服务时保持相同指标和测试样例。
