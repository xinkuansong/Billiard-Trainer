# CB-01 扎杆单解搜索：8 路并行验证与续跑

状态：1／2／4／8 路实测全部通过，已以 8 路持续续跑，首批 400 个通过。正式题库与训练页面未由本任务修改。

采用一个受租约管理的 compact-phone 模拟器，内部 OperationQueue 最多同时求解 8 个基础球形。每个 worker 独立保存引擎实例、参数遍历、探测、计数与轨迹；共享只读几何缓存沿用原锁，输出串行写入，逐题原子落盘。

搜索正文直接从 `MasseSearch.swift` 截取原文构建，不修改原串行文件；只替换容器类声明并追加并行入口。仰角、参数与障碍候选顺序、首次成功早停、合格判据及独立候选审计均沿用原逻辑。生产源码使用原冻结快照，构建后逐文件哈希核对；本次加速不引入新物理版本。

验证使用已完成样本中的 32 个球形：8 个 raw solved、12 个候选搜尽、6 个包含未完成模拟、6 个独立复核拒绝。按袋口、距离、库边与角度补足覆盖，分别运行 1／2／4／8 worker。必须与原串行包逐字段完全一致（仅忽略执行版本/复用来源字段），包括参数、障碍、全部轨迹、搜索过程与模拟次数；每轮同时保存宿主 CPU/RSS 采样、计算时间、总墙钟时间、真实最大并发和 XCTest 结果。

新构建通过后才停止原 worker 并转交租约，保存旧状态与全部已完成包的哈希。验证失败则保留全部证据并停止新任务，不通过降低验证门槛继续。验证通过才以 8 worker 续跑剩余球形，每批 400 个；已有包拒绝覆盖。新包添加独立 executionRevision，保留原样本/算法 runIdentity；独立复核未通过的 raw solved 不进入候选清单。

入口：`run_masse_parallel.py`；定位最新临时运行与证据：`masse-parallel-current.json`。完整任务由 local-test lifecycle 管理，成功结束自动清理临时构建，证据保留。`masse-full-current.json` 仍是全量数据入口，`job-state.json` 区分 benchmarkingParallel／runningParallel／complete／failed。

## 实测结果（2026-11-26）

32 个固定样本、13,479 次模拟，四个并发档共 128 次完整球形搜索；每个输出与原串行包逐字段完全相等。

| 并发 | 搜索秒数 | 相对单路 | 最大实际并发 | 峰值宿主 CPU | 峰值宿主 RSS | 精确匹配 |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 189.32 | 1.00× | 1 | 100.3% | 864.8 MiB | 32/32 |
| 2 | 100.97 | 1.87× | 2 | 201.9% | 881.9 MiB | 32/32 |
| 4 | 55.56 | 3.41× | 4 | 400.1% | 881.7 MiB | 32/32 |
| 8 | 37.60 | 5.04× | 8 | 790.5% | 914.8 MiB | 32/32 |

速度为 XCTest 内完整形状搜索时间，包含工作队列调度与逐题输出，不包含安装、启动、批后审计；5.04 倍不直接等于整批/全量加速比。RSS/CPU 为每 2 秒采样的宿主进程值，不是整台 Mac 的总内存/CPU。未做全量穷举或人手可操作性复验。

证据：`/Users/song/projects/13.billiard_trainer/output/local-test-runs/65d9dfd383a346b28127ee0067b7a81a/evidence`，包含 `benchmark-results.json`、逐轮 XCTest、资源采样、32 样本完整输出及来源快照。原构建证据：`/Users/song/projects/13.billiard_trainer/output/local-test-runs/3c278f51da1147c8ba9d3e74da97cff3/evidence`。

交接说明：串行停止于 4,680 个已保存球形，SIGTERM 恰逢汇总 finally，未执行后续关机；原租约已释放，fleet 因设备 Booted 拒绝自动接管。未擦除设备，改用登记的同一 UDID 显式受管借用，并通过全套对照。原失败记录保留，不记为物理求解失败；已有包哈希保存在 `preserved-packets.json`。

## 首批全量续跑验证

首批400个真实XCTest通过（退出0、完整收到400条、实际最大并发8）：搜索133.76秒，含安装/启动/测试退出146.57秒；宿主CPU峰值794.0%、RSS峰值918.6MiB。独立复核337题合格、4题复核拒绝、58题本轮候选搜尽、1题含不完整模拟。累计5,080/10,000个，独立复核合格3,127个；62个复核拒绝、1,846个候选搜尽、45个含不完整模拟。此为首批结束快照，实时状态见全量入口。

原4,680包SHA-256逐一核验，零改动；对应证据`preserved-packets-verification.json`、`first-parallel-complete-audit.json`。旧串行运行副本和首次交接失败的构建副本都已通过local-test生命周期complete回收，原始证据保留；两次实测可用空间增量共1,122,234,368字节（约1.05GiB）。当前受管运行`65d9dfd383a346b28127ee0067b7a81a`继续保留，任务完成后自动收尾。

8路中断续跑：先确认当前进程已退出、租约已释放，保留原请求与已保存结果。从`masse-parallel-current.json`读取work的上级受管运行目录作为`--build-from`，使用新local-test生命周期调用`run_masse_parallel.py resume-build --work '{work}' --evidence '{evidence}' --build-from OLD_RUN_ROOT --udid DF09A8D3-2574-43D7-85D8-369CFDB2C36D`。入口重新租用同一已登记设备、校验并克隆旧二进制、重跑并发等价对照后仅补未保存球形。不要在当前任务仍持锁时另起续跑。
