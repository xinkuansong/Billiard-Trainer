# 中八开球条件概率研究

这些脚本只构建独立的研究测试，不修改生产物理或默认摆球。协议见 `tasks/BREAK-POTTING-RESEARCH-20261002.md`。

研究约束：名义间距0.20mm、扰动半径0.09mm及现有随机分布固定。每局更换种子是从同一分布抽样；不同开球条件复用同一批球架进行配对比较。搜索对象是白球位置、方向、杆头速度与高低杆/左右塞。首轮只覆盖一个纵向位置和参考碰撞状态下的角度/厚薄候选，首轮范围有限；当前joint-v2已完成有界联合参数搜索，见下方。

## 实验步骤

在仓库根目录执行；当前路径和模拟器标识为本次研究专用，迁移机器需同步 Swift 配置路径与 Python `DEVICE`。不要并行运行：测试读取同一个配置文件，且共用一个专用模拟器。

```sh
python3 scripts/research/break_research.py prepare
python3 scripts/research/break_research.py build
python3 scripts/research/break_research.py preflight
python3 scripts/research/break_research.py pair-audit
python3 scripts/research/break_research.py geometry
build/break-potting-research-20261002/plot-venv/bin/python scripts/research/analyze_break_research.py geometry
python3 scripts/research/sample_break_research.py screen
python3 scripts/research/sample_break_research.py audit
python3 scripts/research/sample_break_research.py holdout
python3 scripts/research/break_research.py gap-audit
build/break-potting-research-20261002/plot-venv/bin/python scripts/research/report_break_research.py
```

绘图环境使用 matplotlib；实际模拟始终在 XCTest 内调用生产 Swift 引擎，Python 不替代物理。

构建将研究代码用唯一围栏临时注入已有注册测试文件；`finally` 精确移除该围栏，保留其他修改。独立 DerivedData 和模拟器不与页面开发共用。构建完成保存源码和测试二进制指纹，每局保留配置、实际接触、终止原因与结果；测试执行成功只表示流程完成，物理校验另看审计字段。

## 抽样口径

- 207组×5架共1,035局，只做探索；4个扰动架不能给出精确概率。
- 6组冻结控制各1,000架筛选。控制在名义架上确定一次，每局只改摆球种子。
- 基准与锁定候选各10,000架独立复验，1,000局一批，固定N，不根据中间结果停止。
- 球序审计两组各1,000架，复用筛选球架作配对；不加入主概率。
- 主概率实验共28,000局，使用11,000个独立生产球架种子，跨条件配对复用；不能把28,000局当作28,000个独立球架。
- 球距专项再用10,000个独立架，每架30条邻边。邻边相关，统计单位仍为球架。设定每对10m/s接近速度的判据探针，不是实际开球碰撞计数。

普通目标下球、白球落袋和有效普通下球分别报告。黑八单列。未停稳/无效输入/匹配失败不得被过滤后重新归一化。正式复验只有一个预先锁定的候选与基准比较，不把筛选最大值视作全域最优。

## 证据与已知问题

结果在 `build/break-potting-research-20261002/`；报告与图在 `output/break-potting-research-20261002/`。日志拒绝覆盖；大样本步骤仅复用配置一致、完整成功且生产源码未变的既有批次。改变物理版本后必须另开证据目录，不能混用原先筛选/复验结果。

2026-10-02已确认候选组的总体概率对内部球序敏感。球间立即碰撞容差0.25mm大于名义间距0.20mm，会提前处理许多正间隙接近球对。专项测试用 `XCTExpectFailure` 保留“正间隙不应立即碰撞”的已知不变量失败；审计流程通过不等于物理正确。当前结果为引擎行为基线，不作为实物开球推荐。

下一步保持当前生产物理、球序和摆球随机参数，扩展开球参数搜索：联合位置/方向/厚薄，再加入杆头速度与高低杆/左右塞；候选用新保留种子每组10,000架复验。首轮研究未覆盖左右塞；当前joint-v2入口已接入并完成生产对拍。引擎审计作为结论适用范围单列；修复物理若另行执行，须另开版本与证据目录，重新评估排名。当前研究不搜索间距、扰动半径或更宽的摆球分布。


## 联合搜索（当前 joint-v2）

`joint_break_research.py` 固定原摆球分布，联合扫描位置、初始速度射线/名义厚薄、杆速、左右塞/高低杆及顶球/第二排首碰。预算统一120秒/8000事件：原30秒探索出现侧旋自旋尾段截断，保留在joint-v1，并在候选选择前全部重跑。64个联合点加23个基准/对照点，各256架探索；4个父点各8个邻域点，各256架；8个候选加基准各1000新架；锁定1个非基准候选和基准各10000新架。每阶段配对使用同一批球架，阶段之间新种子隔离。有限范围搜索不证明全域最优。

主目录相机API开发导致构建暂时不一致，当前研究测试由托管工作区的稳定提交712c3b3a构建；物理/Rack与主目录研究快照逐文件一致，球桌资源一致，本地忽略的房间依赖按原样复制。构建工作区路径及完整指纹保存在joint-v2/frozen-build-source.json。证据与报告保留原项目目录，研究脚本不修改App物理。

在原仓库根目录、研究二进制构建完成后执行：

```sh
build/break-potting-research-20261002/plot-venv/bin/python scripts/research/joint_break_research.py all
```

当前研究报告：output/break-potting-research-20261002/joint-v2/report.html。每批验证实际测试执行、固定输入、源码/二进制指纹和完整样本数；审计兼容后最多同时计算三个独立球局，不改变单局碰撞排序。原始首次构建失败、缺少忽略资源的失败及时间预算诊断保留，不与正式复验混合。

筛选出现1局可重复的生产库边穿透保护失败，保留在原1000局分母中。未知组成功率范围51.6%–51.7%，不能改变完整停稳组L2-01的57.8%经验第一名；选择前保存selection-amendment.json，明确仅在所有未知结局补全都不改变经验赢家时锁定。否则停止选择。此边界判断不替代独立保留集推断。

联合研究已完成：59,464次参数评估，11,512个不同球架种子。最终B0与L2-01各10,000架均停稳，有效普通下球41.11%与55.25%，配对差+14.14pp，95%区间[+12.78,+15.50]pp。筛选唯一未知局保留，正式复验未知0；独立计数重算、148批输入/种子/指纹核查通过。结果仅限当前冻结模型，未证明全域最优、实物效果或操作误差鲁棒性。

本次临时构建工作区在验收后已归档（可由任务附件恢复），原始脚本与证据保留在主目录；6个忽略的房间依赖原件均仍在主目录。复用已编译二进制不需恢复工作区；需要重建时恢复工作区并补齐原件。专用模拟器在研究结束后关闭，不影响其他开发模拟器。

## 白球落袋事后分析（2026-10-03）

运行 `build/break-potting-research-20261002/plot-venv/bin/python scripts/research/analyze_break_scratches.py`，复用原130组/59,464次完整评估和8条额外诊断重放，不增加概率样本、不重新调参。报告位于joint-v2/scratch-20261003/report.html；统计包括白球概率上下界、Wilson包络、同架配对差、袋口分布和代表时序。落袋前ballContacts是引擎事件数，可能包含同刻重复处理；不能仅凭次数推断物理上的散球回撞。
