# 两球参数题库原型与实时轨迹验证

状态：✅ 独立原型、全量参数审计与原生模拟器抽测完成（2026-10-26）；未替换正式题库，未修改App代码。

## 用户范围

“先把只保留参数的题库做出来，看看能缩到多大，再测一下实时生成轨迹的速度和一致性，先不替换正式题库。”

## 交付

- 代码：`research/two-ball-parameter-bank-20261026/`（pack.py、audit.py、build.py、main.swift、run.py、report.py）。
- 参数包：`output/two-ball-parameter-bank-20261026/ParameterBank/`。
- [完整报告](../output/two-ball-parameter-bank-20261026/README.md)、[参数审计](../output/two-ball-parameter-bank-20261026/audit.json)、[抽测汇总](../output/two-ball-parameter-bank-20261026/summary.json)、[设备收尾](../output/two-ball-parameter-bank-20261026/device-closure.json)。

原367,798,287B → 参数版31,452,744B（31.45MB，减少91.45%）；其中gzip30,612,172B、索引840,572B。1357分片，保留13,358布局、166,443题、677,488推荐、552,055共享路线。保留精确初始坐标、B/两杆袋口、ID、杆速/打点/实际方向、首碰后库序和原推荐顺序；不存轨迹点、停点、分数或研究过程。未降浮点精度、未抽掉题目。

## 验证结果

1. 独立全量参数逐字段核验，题目成员/引用/顺序与全部SHA通过；测试结束再次核对正式包全量SHA未变。
2. 128题固定哈希随机样本＋边界极值合并为138题/578条。单进程串行重放三轮1734次，无丢弃首次路线。
3. 578条全部成功；2mm关键点（含时间）、停点、事件锚点、库序全部精确一致；三轮结果确定性一致。完整路径对离线折线最大弧长RMS1.079mm，低于当前5mm准入界限。
4. 舒适度最大差0.00000604分，源于运行时B位置Float转换，未跨85；三个分项及总分另用已有Python公式复算，差≤1.28e−13。E最大差4.44e−16，138题排序均保持。
5. M5 Pro/iOS26.3.1模拟器、Swift -O：单路线中位4.36ms/P95 6.40ms；整题1–5条含分片读取中位21.57ms/P95 30.17ms/最大46.14ms；首次球杆模型初始化1.10s（前次诊断1.37s），索引解析17.53ms。不是iPhone真机结果，不含UI、离线审计和报告写出时间。

## 发现与修复（仅测试程序）

首轮两条库序多记一次碰库，点和停点仍全等。根因：接触同一时间戳内，库事件先于碰球事件；压缩器time≥firstContact与源库contract.normalize事件顺序口径不同。将原库已有的事件顺序归一化规则移植到本测试程序后全578条对齐。首轮日志、数据、源码和哈希保存在`runs/before-event-order-normalization/`，没有更改物理或生产规则。

## 实现与证据边界

- 使用当前源码一致的既有物理/记录器/碰撞及出杆空间对象文件，当前solve/failure/comfort/几何/P2实现逐段抽取并编译；source-binding.json记录源哈希。不是完整App重新构建。
- generate入口只有参数记录，原库轨迹只在计时结束后审计使用；未在手机重做245点搜索。
- 模拟器large-phone通过fleet租约使用；16D968CB-FA14-4E00-B79F-0D675D80179E已Shutdown、工作进程退出、租约释放；本次编译工作区回收，日志保留。
- 未做全677,488推荐物理重放，未测真机，未接入参数读取器、旧记录兼容或预加载功能。
- 正式迁移前要版本绑定引擎/参数包、缓存和预加载，保留物理成功/首碰后库序/舒适度等检查；删离线点后不能照搬当前“与离线折线RMS比较”准入，研发参考库仍应独立保留。

## 重现

1. pack.py要求ParameterBank不存在，仅向独立输出写入；正式库只读。
2. `python3 research/two-ball-parameter-bank-20261026/audit.py`。
3. `python3 scripts/local_test_lifecycle.py run --task two-ball-parameter-bank-20261026 -- python3 research/two-ball-parameter-bank-20261026/run.py`（先确认large-phone空闲；重跑前归档既有本实验结果）。
4. `python3 research/two-ball-parameter-bank-20261026/report.py`。

后续：用户评估31.45MB方案；若决定接入，再做正式读取/缓存及真机性能与一致性验证。
