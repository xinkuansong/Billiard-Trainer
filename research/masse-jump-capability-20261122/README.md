# CB-01 扎杆与跳球能力边界测绘

本目录只保存研究脚本、隔离运行证据和候选实验输出。

## 2026-11-26 扎杆专用单解搜索

**全量10,000球形已启动，当前仍在计算。** 运行入口为`run_masse_full.py`，实时状态、候选清单和中断续跑命令见[全量运行记录](masse-full-run-20261126.md)。复用首批已验60条，独立保存全量身份与结果，不覆盖首批证据。

最新入口是 `run_masse_search.py`，结果见 [首批扎杆搜索报告](masse-search-results-20261126.md)。从既定 10,000 个基础球形抽取 60 个覆盖样本，搜索瞄准补偿和合法障碍位置，每个基础球形只导出一个位置、一个解；不做扰动试验。独立复核与真实轨迹图使用 `analyze_masse_search.py`。

主工程已改名为 CuePhys；下文 E0/E1 的 `run.py build` 是历史入口，会重建旧快照，**不要用它覆盖本轮快照**。本轮复用已审计的冻结引擎，通过 `run_masse_search.py build` 编译研究测试；具体命令和版本身份见最新报告。当前缓存测试二进制已更新，旧 `one-solution-build-20261124.json` 不代表当前二进制；历史结果保持原样。

## 研究范围

- 不修改 `CuePhys/Resources/training-grid-bank.json`（原名 `QiuJi`）
- 不修改正式训练页面、训练额度或答题记录
- 来源球形来自现有准度题库，障碍球只在研究运行时临时叠加
- E0 负责来源、坐标、障碍球和杆尾空间检查
- E1 通过隔离的 XCTest 快照调用生产 `ShotPredictor.simulateFree` 三维模型

## 运行

```bash
python3 research/masse-jump-capability-20261122/run.py prepare
python3 research/masse-jump-capability-20261122/run.py build
python3 research/masse-jump-capability-20261122/run.py run
python3 research/masse-jump-capability-20261122/run.py ingest-remote-log \
  --log research/masse-jump-capability-20261122/evidence/mac-mini-e1-r4/test.log
python3 research/masse-jump-capability-20261122/run.py report
```

`prepare` 和 `report` 只需要 Python 标准库。`build` 会创建隔离的 Xcode 快照并执行 `build-for-testing`。`run` 通过统一模拟器租约运行 E1，运行失败时保留证据目录。
`ingest-remote-log` 从 Mac mini 分批 XCTest 日志提取 `CB01_ROW` 并生成本地 `e1-results.json`。

E2 修正轮的脚本入口如下。

```bash
python3 research/masse-jump-capability-20261122/e2.py prepare
python3 research/masse-jump-capability-20261122/e2.py ingest \
  --log research/masse-jump-capability-20261122/evidence/mac-mini-e2-r1/test.log
python3 research/masse-jump-capability-20261122/e2.py report

python3 research/masse-jump-capability-20261122/filter_source.py filter
```

`filter_source.py filter` 从原始准度球形全量展开 30%、50%、70% 障碍位置，输出压缩 JSONL。E2 运行使用隔离的 `CB01CapabilityResearchTests` 和 Mac mini 管理池设备，按 750 条分批执行。

## 输出

- `first-batch.json`：第一批实验球形和几何筛选结果
- `e0-summary.json`：E0 汇总
- `request.json`：E1 参数任务
- `e1-results.json`：逐参数组合的物理结果
- `e1-summary.json`：按杆法、距离和障碍位置聚合的结果
- `e1-analysis.json`：E1 指标与按障碍比例的统计
- `e1-conclusions.md`：E1 能力边界结论与 E2 候选窗口
- `e2-request.json`：修正后的 E2 参数任务
- `e2-results.json`：E2 逐样本结果
- `e2-summary.json`：E2 按技术、障碍模式和距离聚合结果
- `e2-analysis.json`：E2 按参数维度和组合分析
- `e2-conclusions.md`：E2 中心诊断结论与 E3 细测建议
- `e2-execution-status.json`：E2 远端构建、分批运行和修正记录
- `filter_source.py`：原始准度球形全量静态过滤脚本
- `filtered-source-shapes.json`、`filtered-source-shapes.jsonl.gz`：几何通过候选清单及压缩记录
- `source-filter-audit.json`、`source-filter-audit.jsonl.gz`：全量通过／拒绝审计清单及压缩记录
- `filter-summary.json`：来源过滤统计和规则快照
- `source-filter-conclusions.md`：来源过滤结论
- `sample_100.py`：100 个基础球形的分层抽样与可视化脚本
- `source-filter-sample-100.html`、`source-filter-sample-100.png`：100 个样本的交互预览与静态图
- `source-filter-sample-100.json`：100 个样本清单
- `sample_distribution.py`：按来源分布加稀有类别覆盖抽样脚本
- `source-filter-sample-36.html`、`source-filter-sample-36.png`：36 个样本的交互预览与静态图
- `source-filter-sample-36.json`：36 个样本清单
- `sample_10000.py`：按距离、袋口、角度和贴库状态联合分层的 10,000 个样本抽样脚本
- `source-filter-sample-10000.jsonl.gz`、`source-filter-sample-10000-summary.json`：10,000 个样本及其分布、来源哈希和距离范围摘要
- `obstacle-grid-design.md`：障碍球纵向位置 `s` 与遮挡程度 `q` 的二维网格设计
- `one_solution_plan.py`：每个基础球形选择一个合法障碍位置并生成首个解搜索请求
- `one-solution-plan-10000.jsonl.gz`、`one-solution-plan-summary.json`：10,000 个基础球形的一障碍计划
- `one-solution-request-00000-00100.json`：首批 100 个球形的 1,600 条真实求解候选
- `trace-request.json`、`trace-results.json`：三条代表性轨迹的实际帧
- `evidence/`：隔离构建、测试和模拟器日志

当前结果属于模拟能力边界，不代表真实球台标定或正式题库资格。E1 已在 Mac mini 管理池设备上完成 18,966 条样本扫描，E2 修正轮已完成 7,371 条样本扫描，原始准度球形全量静态过滤已展开 4,695,168 条候选并保留 550,884 条几何通过记录。首轮错误复用障碍坐标的 E2 原始结果保留为 `e2-results-r1-raw.json`，不参与结论。

## 36 个预览样本的抽样规则

- 只从 91,814 个通过静态几何过滤的基础球形中抽取，每个基础球形只出现一次，展示默认 50% 障碍位置，并保留 30%／70% 切换。
- 30 个主样本固定按来源距离位元分配为 `d5/d6/d7/d8/d9 = 10/7/5/4/4`，对应通过集合的距离分布。固定距离配额内用确定性随机搜索，使袋口和角度边际接近来源分布。
- 另加 6 个覆盖样本，强制保留 2 个贴库、2 个中袋、1 个低角度端点和 1 个高角度端点，并把它们分配到中短距离层，避免稀有覆盖把距离边际明显拉偏。覆盖样本用于检查稀有几何，不作为来源比例估计。
- 这组 36 个样本用于人工看图和检查球形覆盖。正式题库候选仍以全量 91,814 个基础球形为输入，不以 36 个样本代替全量。

## 10,000 个基础球形下采样

10,000 个样本从 91,814 个基础球形中抽取。联合分层字段为距离位元、袋口、角度位元和贴库状态，共 184 个分层。每层使用 Hamilton 最大余数法分配配额，再用固定种子 `20261122` 在层内抽样。每条记录保留 30%、50%、70% 三种障碍位置，输出为压缩 JSONL。样本实际母球—目标球距离范围仍为 1.0565–1.70715 m。

当前一障碍计划已为 10,000 个球形各选出一个合法且挡住直接进球线路的障碍位置，使用 `s=0.30/0.50/0.70` 与 `q=1.00/0.75/0.50/0.25` 的 12 个单元。2026-11-24 已通过共享 compact-phone 角色解决临时模拟器容量阻塞。新执行器使用扎杆 9 组、跳球 8 组 E2 参数，按仰角升序逐球求首个合格解，逐球落盘、输入身份核验和断点续跑。

全量 10,000 个球形已完成本轮搜索：8,146 个合格跳球解、1,705 个当前候选未找到解、149 个模拟未确认；扎杆当前为 0。21 个 XCTest 批次及零重跑续接检查通过。

当前研究沿用 2026-11-22 冻结物理快照，不重新复制已改名的主工程。执行状态由 `one-solution-current-run.json` 指向证据目录，结论见 [单解执行报告](one-solution-results-20261124.md)。旧 `one-solution-request-00000-00100.json` 是历史 1,600 条请求，不参与本轮统计。正式题库和训练页面未修改。

```bash
python3 scripts/simulator_fleet.py run --role compact-phone --task cb01-one-solution \
  -- python3 research/masse-jump-capability-20261122/run_one_solution.py \
  --udid '{udid}' --mode all --batch-size 500
```

`--mode pilot` 取样本索引 1、101、…、9901 的 100 个分散球形做执行链路检查；这不是新的等概率统计样本。`--mode all` 复用已核验的逐球记录，补齐其余样本。研究测试源码和编译产物 UUID 必须符合 `one-solution-build-20261124.json`，源码有改动必须先重新编译并更新该构建记录。

## 当前首轮状态

E0 已通过。8 个球形家庭生成 87 个几何有效布局，每个布局分别展开为跳球和扎杆，形成 174 个技术布局。E1 请求包含 18,966 个参数组合，母球—目标球实际距离约为 0.78–1.71 m，障碍球沿母球—目标球轴线取 0.30、0.50、0.70 三个比例。

`CB01Research` 隔离 scheme 的 `build-for-testing` 已通过，使用生产 `ShotPredictor.simulateFree(..., simulationModel: .spatialPractice)`。E1 已在 Mac mini 管理池设备上分 26 批完成 18,966 条物理扫描。详细状态见 `e1-execution-status.json`，结论见 `e1-conclusions.md`。
