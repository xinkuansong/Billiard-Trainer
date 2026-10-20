# 六入口题库离线生产

六入口共用 `QiuJi/Resources/training-question-bank.json`。旧四类消费“存在实际进球证明”的基础球形，准度消费指定打点、直接进指定袋且不落母球的稳定变体；两种资格不可混用。实际题量与指纹见同目录 manifest；验收记录见 `tasks/table-page-adaptation/ACCURACY-PRACTICE-IMPLEMENTATION-20261020.md`。

## 生产与复验

1. 首次建库：`python3 scripts/training-question-bank/bank.py request --count 300 --seed 20261020`，再经模拟器 fleet/lifecycle 运行 `QiuJiTests/TrainingQuestionBankTests/testGenerateOfflinePilot`。请求只消费一次，取消／崩溃后不自动重新生成。
2. 扩充或源变更后：`python3 scripts/training-question-bank/bank.py production --thin 20 --frozen 20 --distances 0`，再运行 `QiuJiTests/TrainingBankProductionTests/testRevalidateAndSupplementOfflineBank`。从上一份生产库（首次可用细化试点）逐个重放所有名义证明并重新验证九点，随后补题；`--distances N`分别补N个母球长距离、目标球中距袋和长距袋的极薄球。镜像球形也须重新模拟，不能继承证明。
3. 初次或源码已变而Bundle尚旧时，只对离线生产的Debug构建传入 `TEST_BUILD_SETTINGS=TRAINING_BANK_REVALIDATION=YES`。这是明确的复验入口；Release不能用该标志绕过门禁。生产前冻结源码，生成中不要修改指纹清单中的文件。
4. 报告：`python3 scripts/training-question-bank/bank.py report output/accuracy-practice-20261020/production-bank.json`。生产器输出12组库距／杆法配置×10个seed抽题报告。运行 `AccuracyPracticeIntegrationTests`，核实际Bundle的单项筛选覆盖、20题唯一性／精确打点配额，以及正式模型球杆的可击打性。
5. 经实际复验后打包：
   ```sh
   python3 scripts/training-question-bank/bank.py publish \
     output/accuracy-practice-20261020/production-bank.json \
     --coverage output/accuracy-practice-20261020/production-coverage.json
   make -f scripts/Makefile verify-training-bank
   ```
   打包拒绝源指纹漂移及必需的12组覆盖缺失。再做正常构建与Bundle集成检查；不能仅用生产器内存结果作为资源已入包的证据。

测试与构建仍走 `scripts/Makefile`、fleet和lifecycle；使用已借用的设备与本任务持有的测试工作目录，禁止裸建模拟器。正常测试没有一次性请求时跳过离线生产。生产日志、checkpoint、失败与取消结果保留在 `output/accuracy-practice-20261020/`，不把未完成运行标为通过。

## 验证合同

搜索允许现有反解器提出候选，但证明必须按原方向、速度、打点重新执行 `simulateFree`，等待完整settled终态；用户实际出杆也直接正向模拟。正式球桌为QiuJi工厂的44条线段＋12条圆弧；主库、本题袋嘴、其他袋嘴分别分类。贴库初始受力接触不等同于离库后反弹，不能把其他袋嘴当隐藏反弹路线。

当前规则 `direct-pot-fixed-tip-v3`：打点单轴0.25R（组合约0.354R）；九点方向／速度邻域±0.025°、±0.05m/s，九点全成功。方向范围按现有慢速方向尺校准，详见ADR-P18-09；这不替代真机手感验证。固定打点还须通过正式渲染球杆的可达性检查。

一个球形多个打点仍只算一个基础球形。一轮20题不得重复基础ID；候选同时防同袋口、双球位置均小于1cm的近似重复。随机覆盖0–85°，不同选择维度取交集、同维度多选取并集。随机库距不附带距离限制，半贴库为球表面到有限主库净距大于接触容差且≤10cm，贴库为接触容差内。

有限题库不承诺所有交叉组合都有20题。题量不足明确返回覆盖错误，不放宽角度／距离／袋口／杆法、不把不同打点当不同球形，也不把搜索预算内未找到说成物理无解。自由练习优先未见球形，合格池耗尽会明确提示重新抽取。

`production-source-manifest.json`绑定当次物理、几何、打点、操控与验证源码。正常构建自动检查Bundle哈希及当前源指纹；源码变化后必须复验，禁止改指纹字段把旧证明冒充新验证。已保存成绩保留当时结果；旧活动题不能继续充当新版本合格题，历史结果不被重算覆盖。


## 千题规模扩充（2026-10-20）

> 历史流程，已由下方“270组合独立题库”取代；不再执行旧总量／比例配额。

`bank.py expand --minimum 3000`生成一次性请求，随后通过受管模拟器运行`TrainingBankExpansionTests/testExpandVerifiedBank`。先全量重放旧库，剔除没有稳定证明和镜像／双球均小于3cm的近似重复，再按实际库距×五档角度分层补题；每题九种打点分别有限搜索，合格才入库。正式渲染球杆profile参与可达性验证。首次可用`--minimum 600`试生产；同源继续用`--minimum 3000 --resume`，不会重复模拟已验证checkpoint。源改变会拒绝续接；重新生产时重放所有旧证明，不能改哈希骗过。

输出`output/accuracy-bank-expansion-20261020/bank.json`和`coverage.json`按上方publish入口入包；每25个球形及每250次尝试原子checkpoint。生成中冻结指纹源码，候选失败只表示本轮有限预算没有找到。三类库距下界比重50%／33%／17%，每类五档角度均分；不是运行时随机权重变更。扩充后运行`TrainingBankExpansionAuditTests`、既有Bundle集成／题库／记录测试和正常构建，报告实际交叉缺额，不能由总数推断全组合覆盖。

## 270组合独立题库（2026-10-21）

> 历史随机流程，用户已要求停止；499球形／3469解检查点保留，不再恢复旧长批。最新网格流程见下节。

当时授权：5角度×2袋型×3母球距离×3目标球距袋×3互斥库距，每格目标500个球形家族，生成不足保留实际数量，随机展示权重另议。去重不使用力度、打点；旧版镜像归一家族，比较切角、入袋方向、距离与库关系；跨格去重。详细参数和证据见`tasks/table-page-adaptation/ACCURACY-BANK-CARTESIAN-20261021.md`。

`bank.py cartesian --workers 4 --seconds 240`准备一次性请求，通过受管模拟器运行`TrainingBankCartesianTests/testProduceCartesianShards`。候选生成与求解分阶段并行；全局家族索引、入库与原子检查点单写者。`--resume`复用同源码、实际球杆profile、去重版本、seed下的分格解；`--resume --revalidate`保存历史并对全部已存输入做实际正向九点复验后续跑，不能仅更新指纹；`--cells a0-p0-c0-o0-r0 …`限定工作范围，其他格仍参加全局去重。不得在运行中更改指纹源码。

结果在`output/accuracy-bank-cartesian-20261021/shards/`，按组合保存球形＋紧凑进球证明；解只存固定打点、方向、参考速度、事件与九点结果，不保存逐帧轨迹。参考精讲`SequenceStep.recordedDirection`→`SequenceReplayResolver`的定向正向回放方式。`candidate-bank.json`只是候选汇总，不自动替换Bundle。先运行`audit_cartesian.py`独立几何／分布／跨格去重检查，再完成原生覆盖与正式发布门禁。

`TrainingBankExpansionAuditTests`已按本版需求撤换旧3000总量／15格固定下界，改为实际270格数量报告并保留几何、筛选和不重复断言；本版数量依据每格实际结果和预算明细，不以凑满500或全部20题抽取成功为前提。

快速候选只复用方向建议：同球形已验证方向、同格同袋最近两球形的角度修正，以及几何方向。全部候选仍独立校验当前球形的球杆可达性、指定袋、无白球落袋与九点容差；失败回退反解搜索。`fastProofs`记录免反解成功次数，不能用于不同批次直接推算加速倍数。

## 参数网格：先清点再验解（2026-10-21）

最新用户合同采用P—G—C、1°方向／切角和10cm距离步长，镜像作为不同视角保留。普通PG／GC网格与精确贴库边界补充分别记账；分类仍按CO／OP。完整几何取App原生44条有限线段、12条圆弧及6袋捕获区，保留参考进袋通道受阻的候选供实际求解，不能由参考线受阻推断无解。

`QiuJiTests/TrainingGridInventoryTests.swift`的三个入口分别检查几何谓词、读取单次`request.json`清点、读取独立`validation-request.json`验解。请求及`source-manifest.json`均位于`output/accuracy-grid-inventory-20261021/`；指纹包含本生产器与当前物理源码。运行继续走fleet/lifecycle；请求消费后不自动重跑。

用支持NumPy／Pillow的bundled Python运行`grid_inventory_report.py`，从全部紧凑掩码独立复算270格，输出`audit.json`、`组合分布.html`／`.md`及求解样例图。几何清点不计为物理合格题数；15个代表球形试跑已完成，6份稳定证明存于`validation-pilot.json`，无轨迹。每格500近似去重生产、其余打点补解与正式Bundle发布尚未完成。完整参数、数量和原生证据见`tasks/table-page-adaptation/ACCURACY-GRID-INVENTORY-20261021.md`。

### 当前v2：角袋内收基准，中袋长边中点

用户确认后，普通网格与贴库补充的P统一改为四角`(±(L/2−R),±(W/2−R))`、两中袋`(0,±W/2)`。真实袋口几何不移动；进袋参考射线越过P检查实际捕获。生产器读写新目录`output/accuracy-grid-anchor-v2-20261021/`，旧目录为历史结果。v2已完成7306006候选清点与30例渲染，尚未做物理验证。

报告命令：`grid_inventory_report.py --directory output/accuracy-grid-anchor-v2-20261021`，随后`grid_anchor_gallery.py`输出30例PNG／HTML。后者按5角度×2袋型×3库距分层、优先普通网格，覆盖六个实际袋口及短中长距离；与运行时权重无关。新源指纹对应原生2项通过、求解入口1项因无请求跳过，旧v1证明不可继承。详见`tasks/table-page-adaptation/ACCURACY-GRID-ANCHOR-V2-20261021.md`。

### 力度筛选试跑

用户要求只搜索力度，新增显式请求测试`TrainingSpeedScreeningTests/testFixedDirectionSpeedScreening`：v2的30例×九种独立固定打点，方向始终C→G，0.5–8m/s，只调用正向模拟，不做方向反解／九点。分别测单侧二分、双侧中点细分、0.1m/s完整有限对照。单次请求、源指纹、输入SHA、每阶段结果及紧凑解在`output/accuracy-speed-screening-20261021/`；报告工具为`speed_screening_report.py`。

仅“停稳且目标球进入指定袋”计筛选正例，scratch／indirect另记，不是正式准度资格。单侧未进就增力会漏解，双侧有限预算也不能证明无解。1项原生实验通过，双侧四路处理270组合（263可击）用11.74秒、60组合有解；0.1m/s对照找到76组合，其中20个被有限双侧漏掉。当前只是实验，不自动导入Bundle或启动全库。详见`tasks/table-page-adaptation/ACCURACY-SPEED-SCREENING-20261021.md`。


### 中杆五次初筛（2026-10-21，最新实验）

用户已明确当前只筛球形：中杆、固定C→G、最多5次力度，目标球进指定袋即可，忽略母球落袋。`TrainingSpeedScreeningTests/testCenterFiveAttemptScreening`读取一次性`output/accuracy-center-five-20261021/request.json`，输入仍为v2审图30例；四路并行，不自动启动全库。运行后执行`python3 scripts/training-question-bank/center_five_report.py`核指纹、5次上限、方向、零打点、指定袋事件与二分区间更新。源码快照和试跑报告同目录。近袋未进减力、未到袋口加力；歧义偏离仅试探减力。失败不得作无解证明，当前15/30不代表全库通过率。旧九打点实验仅作历史对照。


### 中袋并行基准

`middle_benchmark.py prepare`以固定种子从全部中袋库存均匀无放回抽5000题并冻结请求（需NumPy运行时）；原生选择器`TrainingSpeedScreeningTests/testMiddleConcurrencyBenchmark`依次运行4/6/8/12/18路，共用中杆五次函数，并对拍旧30例。结束后`python3 scripts/training-question-bank/middle_benchmark.py audit`逐题审计、生成报告；输出`output/accuracy-middle-benchmark-20261021/`。不要在已有成果目录直接重新prepare覆盖证据。本轮18路最快20.699秒/5000题，2,375,112中袋候选外推2.731小时，实际需留负载余量。当前只试跑，不自动执行全量。
