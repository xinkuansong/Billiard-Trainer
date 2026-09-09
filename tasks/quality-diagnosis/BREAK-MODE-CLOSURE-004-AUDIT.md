# L4 / SC21 开球玩法与交付证据清算

2026-09-08。只读 B3、冻结测试源码及当前实际run/AX/磁盘原件索引；仅新增本文件，无测试注册/运行/设备操作。结论：**seed确定性及真实重开换seed已有分层证据，不应再泛称未测；正常选择玩法→实际开球→点完成交付并核球ID/状态仍未找到完整已验链**。X3源码包含交付动作，但缺其本轮真实运行原件，不能直接当通过。

## 旧方法究竟覆盖什么

| 方法/来源 | 实际断言与证据层 |
|---|---|
| `RackGeneratorTests/test_eightBallRack_rulesAndGeometry` | 八球架数量、规则摆位、边界/不互穿。列于B3-PREPARATION精确selectors；B3.md FORMAL-B3-001记31/31通过。是历史实测记录，旧002原xcresult当前不可核，不抹成从未运行。 |
| `RackGeneratorTests/test_sameSeed_sameRack` | 固定seed42的两次**球号数组**一致；只凭该方法不能说所有球位逐轴相同。与上一项同B3历史层。 |
| `RackGeneratorTests/test_breakNineBall_producesLegalSettledBoard` | seed7、母球偏移0.03、power5，真实BreakSimulator九球停稳，桌球数=10−落袋数、独立board边界/球距，eightOnBreak false。B3选中且历史通过；不是正常UI玩法选择/按钮完成。 |
| `BreakFlowRunnerV6Tests/test_sameSeed_identicalRackSpacing`、`test_differentSeed_perturbsRackSpacing_boundedByJitterRadius` | 同/异seed坐标及jitter界，源码有，不在B3所列31方法中。本次没找到它们对应的真实run终态，不因文件名算已验。 |
| `BreakFlowRunnerV6Tests/test_sameRunner_reRack_producesDifferentRack` | rackUp后reRack，seed精确+1、球位maxDelta>0、racked且showsConfirm false。源码有，不能把B3整体31通过贴到该方法。 |
| `BreakFlowRunnerV6Tests/test_manualDeliver_settleStateMachine` | 明确调用`applySettledBoardForTesting`注入2球盘，未确认前callback nil，confirmSettled后callback非nil/count2。是交付状态机UT设计，不是实际物理开球/UI；没有核逐球ID/坐标。`test_autoDeliver_callsOnSettledImmediately`同为注入空盘控制。 |
| `X3_BreakFlowUITests/testX3_SiluBreakManualDeliverFlow`、`testX3_PlanThreeBreakManualDeliverFlow` | 已全文核helper：deep-link进入→选中八→真实开球→完成/重开存在→重开→第二次开球→点完成→break.entry复现。**只复现入口，不核交付球ID/终位，不比较seed数值**。有条件fallback、sleep、continueAfterFailure=true和try?输出，不能直接当强诊断。当前质量归档未找到x3-delivered图/对应日志，不凭文档引用测试名假称通过。 |
| `S6_BreakUniversalUITests/testV6BreakUniversal` | 多处if/tapIfExists，可未进入也结束；自由击球只截settled，不点完成；思路/三球只截racked并取消。不能替代真实完成交付。 |

B3.md其余003/004普通击球重打与005自由走位/防守不是开球交付；不重跑这批。`docs/research/20260902-v50-设备状态矩阵.md`引用X3类仅是入口/截图覆盖索引，不是独立执行结果。

## 当前004可复用的真实证据

- `formal-004-daily-normal-001`正常自动开球到playing，O=`archive/quality-diagnosis/observations/daily-normal001-disk/active-draft.json`：seed8016700117247144671；合法一杆后O/daily-legal-shot001-disk/activeDraft.json保留实际局。
- `formal-004-daily-rerack-001`正常确认重开，O/daily-rerack001-disk/activeDraft.json：seed10241297249008912792、manualRacked、0杆0犯规。这已证明**正常重开换seed与计数重置**，虽然测试最后错误等待自动开球而失败；不能把整run失败抹掉其有效分支，也不宣称该run全过或seed恰+1（每日控制器用新随机seed，语义与runner.reRack不同）。
- `formal-004-daily-manual-break-001`已散球，真实`break.confirm`，但未点完成；002/003没到该按钮。详DAILY-ENDING-004-PREFLIGHT。此分支不能补满L4交付，且当前Mac锁屏入口对照未具备，不猜每日入口坐标。
- `formal-004-repeated-shot-001/screenshots/repeated-shot-810E2DD0-8651-4047-9C22-4BE922F326AC-initial-default-board-AX.txt:205`，普通自由击球已实测Button `break.entry`/「开球」，frame(1.7,681.7,48,46)。同run正常根入口/十轮击球不等于开球模式，坐标只用于历史识别，不能硬写到新设备。
- `formal-004-silu-shot-001/screenshots/silu-shot-45CA22A9-949C-4789-90E0-E4BA5F0BB0D9/1-actual-yellow-and-reviewed-pocket-selected.txt:161`亦有相同break.entry正常AX。思路普通击球不代开球，下一步不需要再解一道题。

以上run均位于`archive/quality-diagnosis/runs/`，当次选源、selector、exit/日志为真源。当前未发现正常工具**玩法选择sheet**的独立实际AX；旧X3源码中的`break.game.15`不是实测节点原件。

## 唯一最小下一执行合同（正常自由击球，不经每日清台）

选择普通自由击球代表宿主，一次「9球」玩法与一次真实开球交付，不另换seed、不扩全部玩法。seed变化已复用上述正常重开磁盘证据，没必要为了这一包再开两盘。

1. 新专用guest、严格UDID匹配、内存宿主、正常单次launch，练习→打→自由击球；无deep link/真实账号/生产fixture，不录制导出写内容资产。复用REPEATED-SHOT正常入口，原默认盘截图/AX保存。
2. 点已实测`break.entry`一次，保存当前玩法sheet完整PNG/AX，**这一步必须先观察**。源码`BreakGamePickerSheet`的标题「开球玩法」、选项「9 球」、`break.game.9`有明确依据，但现存原件未给该sheet实际AX；不写猜label或坐标fallback。一次打开观察后才能按真实节点完成后续方法。
3. 从正常picker选9球，rack静止时核真实球集合`cueBall,_1…_9`，无_10…_15；禁止仅以palette里仍有这些球或不可见SceneKit残留节点算台面身份。球的实际frame、visible/hittable和完整PNG共同验；若球形过密无法逐球AX独立识别，保留场景可见与模型证据不足，不弱化为只看“9球”文字。
4. 正常`break.strike`一次，连续视频审查真实散开与停稳；完整原图AX采集停稳后的实际桌面集合/位置。必须出现可操作`break.confirm`后点击一次，不能见ready瞬间就跳过运动。
5. 完成交付后break.confirm/strike消失、普通break.entry及宿主状态返回，核桌面身份与完成前集合相同，逐球屏幕位置在同一投影下保持合理一致，球数允许小于10（真实落袋），不能预设散局仍有10个球。若母球落袋或宿主补回行为导致差异，应先按FreePlay当前接收逻辑核其语义，不删除集合断言追绿。主控至少审racked/settled/delivered三图与连续视频，才能把真实球形而不是AX残留当交付。
6. 正常返回练习页，有限链结束。不得为了不同随机盘面继续更换玩法/seed重跑至绿。

**当前交付为前置合同，不新增全链Swift**：已知break.entry足够安全取得下一次picker AX，但缺该新正常sheet/9球rack的实际节点证据；立即写全链会违反本任务“用现有实测AX，不猜”。如主控希望先自动取得菜单，可另准备Observation方法，只到break.entry点击后PNG/AX，绝不计L4完成。后续接真实节点时继续采用强guard、失败PNG先AX、全新输出与来源记录；不要直接选旧S6弱方法或X3深链类。

## 收口判定

可核销：B3历史八球摆架/同seed球号/九球真实物理终位；004正常每日重开真实seed变化。暂未核销：当前正常非每日工具玩法选择与手动开球**完成交付到真实球集合**。此处给一条有限后续，不删除原SC21范围，也不因旧X3原件缺失重跑所有开球测试/所有宿主。原Daily手动散局和已知入口失败保留，L4无需等待该同一入口恢复才能继续正常工具路径。
