# DATA1：最小混合磁盘账本与跨页数值准备

2026-09-06。本轮文件为本文、`Data1DiskFixtureTests.swift`与`Data1UIDiagnosticUITests.swift`；未注册scheme、编译、运行、改业务或操作设备。基线snapshot-002。该草稿使用**正常SwiftData模型写专用默认磁盘，随后正常App读取**，不是通过UI创建七场；数据来源仍须标“合成seed”，不能叫七场正常训练全流程。

## 先界定能做的闭环

冻结`ProfileView.swift:34–40`仅`authState.isLoggedIn`时展示`monthlyOverviewCard`，游客展示登录/警示/Pro卡。月卡`:167–177`对当前owner的sessions调用自然月指标。**guest默认磁盘播种无法让“我的”月统计出现，forcePremium也不能替代登录。** 本块可补首页→历史→统计的正常游客UI读取与数值一致性；“我的”应验证正常游客边界、不出现月卡，月卡数值只保留已有独立模型证据。后续真实测试身份登录可补这一页，或另立明确authenticated fixture的局部显示测试，绝不混为四页正常闭环。

现有FORMAL-B2-007四单测已有滚动周、多entry、自然月/周边界、千场内存及混单位/未完成组的刻画，**无需再造第五个相同Projection单测**。现有ThousandUI同日同质数据不能区分周/月与三kind。TrainingJourney统计草稿仅检查非空和切换标题，不能代替本表的准确数值。

## 独立字面账本

v1固定执行日期为**2026-09-06（周日）、Asia/Shanghai、公历**。所有样本日期都在当时，不改系统时间；草稿跨日拒绝，后续日期执行须产出新账本/新指纹，不能仅删日期断言。生产UI使用.now，没有安全时钟hook；固定一天是明确前提，不是假装长期通用。

| 标记 | 本地日期/时间 | kind | 分钟 | 明细 |
|---|---|---|---:|---|
| A | 09-06 00:01 | drill | 20 | c001两entry，各一组8/10球、2/5球；order0/1 |
| B | 09-06 00:02 | drill | 30 | c001一entry，1/2局 |
| C | 09-05 00:00 | cognitive | 5 | 一题geometric，actual45/user40、误差5°，题目sessionId指向C，题目时间00:01 |
| D | 09-06 00:03 | tool | 99 | 无entry、无成绩；note为工具历史标题QD-DATA1-D |
| E | 08-31 00:00 | drill | 10 | c001一entry，3/10球 |
| F | 08-30 00:00 | drill | 40 | c001一entry，4/10球 |
| G | 08-05 00:00 | drill | 80 | c001一entry，6/10球 |

共7session、6entry、6set、1AngleTestResult、0SyncPendingItem。所有记录同一现有guest，日期与note均独立可核对。c001真源`Resources/Drills/fundamentals/drill_c001.json`明确名称半台直线球、分类fundamentals；使用该真ID避免未知分类被过滤。

B的“局”是刻意构造的历史单位快照差异，**不是声称当前c001正常训练会生成局单位**。它检验持久快照/混单位提示，不证明教材或剂量达标；不得把混单位算术刻画记为产品正确。没有加入未完成零分组：已有B1/B2真实UI和CrossData刻画足够确认QD012，再seed一份不能加强“正常提前结束”的证据。若需要其统计页面图证，应直接复用保留的非零QD012样本另做同页读取，不与本七场基础账本混合。

## 独立预期与刻画数值

以下值从上表逐行集合和加法得出，没有调用StatisticsViewModel、TrainingGoalMetrics或DrillPracticeCounts生成oracle。准备期间用Python标准库datetime复核日期集合与加总，输出与本表一致；该计算不是产品测试。

| 页面/范围 | 计训练的标记（排除D） | 天数 | 分钟 | drill组数 |
|---|---|---:|---:|---:|
| 首页本自然周08-31至09-06 | A/B/C/E | 3 | 首页不展示本表总分钟 | — |
| 统计周：08-31起 | A/B/C/E | 3 | 65 | 4 |
| 统计月：08-06起，滚动一个月 | A/B/C/E/F | 4 | 105 | 5 |
| 统计年：2025-09-06起 | A/B/C/E/F/G | 5 | 185 | 6 |
| 我的自然月：09-01起，**仅模型预期，guest UI不出现** | A/B/C | 2 | 55（55m） | 月卡不显示 |

首页连续训练2天（09-05/06），周目标默认3天只在专用新guest且实际偏好为3时断言“本周训练3/3天，连续训练2天”；不要写偏好强制喂期望。当前日历与统计周刚好都从08-31起，但统计滚动月与我的自然月明确不同。tool99分钟只归工具活跃度，不得加到65/105/185，也不增加训练天数或成功率。

分类fundamentals的**当前有损混单位刻画**：周14/27（球13/25、局1/2）、月18/37（球17/35、局1/2）、年24/47（球23/45、局1/2）；当前百分比格式对应52%/49%/51%，当前单位排序显示“局/球”，并应显示“单位混合”。这些混合比率不是单位可通分的验收标准；记录实际展示和警示，单独保留球/局数值为正确解释，不因匹配旧行为宣布混单位已解决。

其他强区分值：历史09-06应有A/B/D三条（两训练、一工具），09-05仅C一条且一题误差5°；08-31 E、08-30 F、08-05 G各一条，合计7。动作库c001总“已练6次”（按entry，A算2），不是5个drill session、7个所有kind或仅今天3次。首页没有通用“总记录数”指标，不为凑四页硬设不存在的数值。

## 播种草稿与执行护栏

唯一新selector：`QiuJiTests/Data1DiskFixtureTests/testSeedSevenSessionLedgerIntoDedicatedEmptyDefaultStore`。草稿只导入XCTest/SwiftData，真实默认schema+migrationPlan，显式owner，未用repository/同步服务/业务指标helper。保存后核对数量/owner/题目归属/零同步队列，manifest输出实际逐条date/kind/minutes/entry/set，不用App汇总反推期望。

前置复用ThousandStoreProbe已有只读方法，但须重新在**独立新DATA1设备与新默认库**运行，不能复用千场设备或已存在store。主控在独立hosted unit scheme的TestAction/宿主启动层传`-v50.inMemoryStore`，不是到test.setUp才传。参数如下：

- `QD_ALLOW_DATA1_DISK_SEED=DEDICATED_EMPTY_GUEST_SIMULATOR`
- `QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH`：本次probe核准的默认store沙盒相对路径；仅作为比较，不作为数据库目标URL。
- `QD_EXPECTED_GUEST_OWNER`：本次现有guest，不能硬编码别名或重设owner。
- manifest固定为当前App沙盒`Documents/qd-data1-manifest.json`，不再接受外部传入manifest目标。

缺前提明确失败，不用XCTSkip当成功。写入前验证宿主bundle、现有guest、默认相对路径、规范化沙盒边界、store/-wal/-shm/manifest均不存在、固定日期与时区。不要清库绕过拒绝。独立scheme注册与实际参数生效仍未验证；先probe证明、再播种、保留退出码与原始manifest。

已采用主控审核的ThousandHistoryFixture方案B：从真实ModelConfiguration默认URL和本进程真实home计算相对路径，与probe外部期望严格比较；拒绝绝对输入、空组件、`.`、`..`和解析符号链接后越出当前沙盒。操作系统可移动沙盒根，但不允许改变guest、默认相对路径、bundle或空库条件。manifest记录当前绝对路径、home、相对路径、bundle及0同步队列。全部数量/归属/日期guard通过后才写manifest；失败留下的store不覆盖，须保留失败产物并另建环境。

## 正常UI草稿：两条方法，尚未编译/执行

选择器前缀`QiuJiUITests/Data1UIDiagnosticUITests/`：

1. `testNormalGuestHomeTodayHistoryAndEntryCount`：真实游客正常disk启动→首页组合AX精确3/3天与连续2天→正常库搜索c001，已练6次必须属于该卡→历史当天A/B/D各有唯一标题/时长行→实际打开A并核唯一note及两个entry的8/10、2/5→返回首页指标不变。**当前草稿只查看当天及A详情，未点B详情、C前一天或上月E/F/G日期**，不能把前版候选完整日历巡查算已实现。跨月边界由正常统计值区分，但不是历史每条均看过。
2. `testNormalGuestStatisticsRangeValuesAndProfileBoundary`：正常记录→统计→周/月/年，每次先PNG/AX，再绑定概况65/4/3、105/5/4、185/6/5；滚至相应混单位摘要，要求4/5/6组和单位混合警示位于同一可见行；最后我的确认游客、三月卡ID不存在。混合摘要是当前行为刻画，不接受跨单位通分。该方法没验证成功率百分比、图表柱、环比或认知误差卡。

启动仅用中文、已完成引导、跟随系统外观和`-forcePremium`。冻结StatisticsView的非Premium分支用fullMask覆盖概况；因此**统计门控必须受控解锁，但身份仍guest**。这不是真实订阅/购买测试，不使用inMemory、deeplink或authenticated profile fixture，更不会让guest月卡出现。

UI runner必需环境：`QD_UI_ENVIRONMENT=SEEDED_DEDICATED_GUEST_SIMULATOR`、实际seed导出的`QD_EXPECTED_MANIFEST_JSON`、同guest的`QD_EXPECTED_GUEST_OWNER`、同默认路径的`QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH`、本轮新`QD_SHOT_DIR`或`TEST_RUNNER_QD_SHOT_DIR`。manifest版本、bundle、owner、相对路径组件与5项计数必须匹配；它不是直接证明App当前容器身份，主控仍须核seed→终止host→当前App容器→UI的安装与数据存续链。业务App不接收manifest。

### 精确语义绑定，不能孤立数字exists

`metric`只接收精确字段标题：本周/月/年训练天数、分钟·总时长、训练组数。标题必须唯一、全框在当前window且hittable；候选值须可见、纯整数、位于标题上方-4…70pt并与标题横向有重叠。**只能有一个候选**才比较字面期望，同时留标题和值的frame附件；零个或多个候选直接失败，不选择恰好等于期望的那个。该算法匹配冻结value在caption上方的真实布局，不按固定屏幕坐标猜位置。

分类摘要采用完整`14/27 局/球`等文本定位，组数与单位混合必须在其垂直中心±12pt的可见同行。全局其他组数或隐藏树节点不能凑通过。球/局摘要仍必须目视分类卡上下文；同一fixture只有fundamentals类别，不是多分类情况下通用的AX绑定器。

每个关键阶段先保存原始PNG和完整AX，再检查；文件名含方法、阶段和UUID，写盘错误抛出，xcresult附件keepAlways。若首次AX把整个metric合并，或数字值因设备字重/行距超出窗口，草稿会失败并保留现场；主控根据真实树修独立绑定，不能删成全App数字存在。Ready与滚动均有界；历史行若嵌套AX未合并成按钮label亦会明确失败。

首页周目标默认3天是专用新guest前提，不写偏好强制喂期望。日期固定9/6、上海时区，跨日拒绝；后续执行必须新账本，不改系统时钟。本批尚不含杀进程后二次重复旅程，默认disk首读源自已结束的seed宿主；如增加UI终止重启，应记录为新增步骤而非现有覆盖。

建议先M3竖屏普通字号验证公共绑定，再按失败/风险决定是否补M2，不重复完整矩阵。已有CrossData四单测不重跑。本块不包括owner切换、真实上传恢复、自然月卡登录UI、千场性能、失败重试或QD012修复。当前状态仍为“待审核/注册/编译/执行”，不能提前提高SC11–14覆盖等级。
