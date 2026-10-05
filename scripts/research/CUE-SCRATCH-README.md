# V023 限时母球掉袋搜索

主方案：`tasks/CUE-SCRATCH-VIDEO-ANALYSIS-20261004.md` r5。调用生产推荐、解析瞄准、事件驱动物理；Python只负责调度、分析和绘图。

## 本轮入口

- `cue_scratch_research.swift`：研究XCTest夹具，首选方向探测、原始接触分类、并行对拍、完整求解/固定方向复验。
- `cue_scratch_research.py`：通过`scripts/Makefile`优化构建、冻结源码/二进制指纹、分批执行。编译时将夹具围栏追加到已注册测试文件，结束时精确恢复。
- `run_cue_scratch_session.py`：30分钟墙钟预算，预跑、广搜、细搜、失败抽查及代表复验。
- `report_cue_scratch.py`：独立ID/事件顺序/袋号校验，SQLite索引、可按库数筛选的HTML图册。
- `audit_cue_scratch.py`：从原始事件独立重算命中资格。
- `render_cue_scratch_contactsheet.py`：Pillow实测轨迹缩略图，不生成/近似物理。

运行命令：

```sh
python3 scripts/research/cue_scratch_research.py build
python3 scripts/research/run_cue_scratch_session.py
python3 scripts/research/audit_cue_scratch.py
```

本轮目录为`build/cue-scratch-research-20261004`、`output/cue-scratch-research-20261004`。模拟器ID、输出路径是本机本轮专用配置，重做新版本先换run目录/设备配置，不覆盖证据。`session.json`已存在时调度器拒绝从头重复运行；单批可通过`cue_scratch_research.py run --config ...`执行新ID清单。当前保留分片便于恢复，但尚未实现自动从任意中断位置续跑的完整调度状态机。

## 计数与真实性

- 所有合法性/推荐拒绝单列，不冒充物理模拟。
- 首选方向传显式offset，生产预测入口不会追加最多20次补救；每条实际探测是一次完整保真度引擎演进，上限30秒/1000事件。
- 完整求解抽查/终验走原始自动补救逻辑；记录trial数量，内部1–21次演进尚未单独插桩，不能把trial数宣称为底层精确总调用数。
- 首选方向未进袋不等于完整求解无解；失败抽查有限且非覆盖率证明。
- 0/1/2/3库要求目标进推荐袋、首次母目接触前无库、只一次球球接触、捕获前两球无袋嘴/喉壁接触，目标不碰主库；几何切角需大于1°。稀有/难切情况保留数据标签。
- 开始摆位在实际有限库段/袋口之外，圆弧周围使用保守圆形排除，可能漏掉合法边界球；首轮为全台+近库+近距离混合，尚未完整兑现r2的160格等量配额。
- 全台原始路线尚未按验证过的镜像对称合并；代表以路线及球位距离去重。固定瞄准扰动目前为杆速±1%至±8%；未完成杆具出杆空间、瞄准角及摆位误差的全套稳健性验证。
- PNG/SVG是从帧记录绘出的采样路径，路径在真实捕获前球态结束；非原生App截图，未制作视频。坐标X向右、Z向下、单位米。

## 并发与性能

12路OperationQueue仅并发独立球形，每杆碰撞顺序不变。研究编译开关`CUE_SCRATCH_QUIET`仅关闭PerformanceProfiler高频计时/锁；常规App默认行为不变。60个输入进行串行与1/6/8/12路逐结果对拍，并检查固定方向完整显示模式的关键物理结局。测速不包含构建，主会话包含测试启动/调度与报告步骤。

所有正式结论以当轮`session.json`、`*-execution.json`、原始JSONL、独立审计和报告为准，不将计划数字当结果。

## 100例扩充与距离过滤（r7）

`expand_cue_scratch_candidates.py` 从原SQLite命中索引选择初始球心距≥0.30m、切角5°–75°的候选。为每例保留对称±8%杆速复验空间，基准杆速限制为0.5/0.92至8/1.08 m/s；母球距矩形库边的球面净距>5cm只是筛选指标，不等于实体球杆可出杆。

按初始两球位置做邻近/镜像外观去重：对于X/Z四种符号镜像，两球位移最大值的最小值须≥10cm；此规则仅用于素材去重，不假定镜像物理完全等价。0–3库各预选40例，每例完整求解、冻结方向重放和16次杆速扰动；通过后优先兼顾库序/袋口多样性与力度复现，最终各25例。

```sh
python3 scripts/research/expand_cue_scratch_candidates.py
python3 scripts/research/cue_scratch_research.py run --config build/cue-scratch-research-20261004/verify-distance100-request.json
python3 scripts/research/render_cue_scratch_expansion.py
```

前两步拒绝覆盖已执行证据。`render_cue_scratch_expansion.py`可重绘当前图册；原24例归档于`archive-r6-24/`。扩充统计单列`expansion-summary.json`，不算入原27分06秒搜索。旧全量报告入口会拒绝覆盖扩充图册。
