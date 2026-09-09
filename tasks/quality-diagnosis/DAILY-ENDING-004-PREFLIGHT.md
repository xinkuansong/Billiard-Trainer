# 每日清台正常终态下一步有限预飞

2026-09-08。只读审计；没有运行/注册测试、操作设备或改业务。此次仅新增本文件，不新增 `DailyEndingDiagnosticUITests.swift`：现有AX足以定位手动开球的「完成」，但**入口事件未到达原因仍未解决**，复制原链再跑不是新增有判别力的诊断；正常胜负盘面也没有足够当前几何证据支持写死击球。

## 先区分两个“完成”

`break.confirm`（label「完成」）是**开球散局交付**，不是完成每日清台。源码 `Core/Rack/BreakFlowRunner.swift::confirmSettled`仅在phase settled、有settledOutcome时调用deliver；`Features/PositionPlay/ViewModels/DailyClearanceController.swift::handleBreakOutcome`再决定playing、失败或手动重开。手动开球若终局球落袋可能进入失败/重摆，不能永远断言点完成后一定HUD playing。

真正胜利由`DailyClearanceRulesEngine.judge`的合法终局球裁决触发`finishCompletion`，保存当日完成、清草稿；`FreePlayView.dailyCompletionBar`展示「今日已清台」及 `dailyClearance.replay`/「再来一局」。中八需本组清完后合法进8；九球族需先合法首触最低球且合法进9。普通犯规只是自由球继续，不是整局失败。手动完成交付即使补通过，也不能关闭正常胜负/完成标记/再来缺口。

## 已有原件与当前裁定

归档根为 `archive/quality-diagnosis/runs/`（R）、`archive/quality-diagnosis/observations/`（O）。父任务口述manual-complete002/003在现有归档中实际名为**daily-manual-break-002/003**。

| 证据 | 已证明与不能推出 |
|---|---|
| `DAILY-NORMAL-004-RESULT.md`；R/formal-004-daily-normal-001；O/daily-normal001-disk | 正常自动开球、回首页重入HUD保持；原文后续“真实击球未验”已被legal-shot等后续证据推进，不能原样当最新全貌。 |
| `DAILY-SHOT-004-RESULT.md`；R/formal-004-daily-legal-shot-001、daily-rerack-001 | 真实合法一杆、保持、重开确认后manualRacked。已知取消按钮/自动等待oracle错误不再重试。 |
| R/formal-004-daily-shot-003 | 提前选8被“按当前规则不能打8号球”保护，未击球；不能重复非法目标点击来追失败终态。 |
| R/formal-004-daily-manual-break-001 | `testPersistedManualRackActualBreakReturnsPlayable` 1失败84.376秒：确已真实开球散开，遗漏点击完成。此次实际view_image完整审`.../screenshots/daily-normal-129C50D0-172A-478A-BA56-B497DA150BFC-terminal.png`：桌面散球、上方待手动开球，下方取消/重开/完成。对应terminal.txt第147行明确`break.confirm`，frame (294,772,92,42)。这是历史实测节点，不把旧坐标用于下一次点击。 |
| R/formal-004-daily-manual-break-002 | `testPersistedManualRackStrikeConfirmAndResume` 1失败31.475秒。terminal AX仍「我的」Selected，profile.login在上方越界；尚未进入每日清台。不能说点完成失败。 |
| R/formal-004-daily-manual-break-003 | 同一方法1失败43.116秒。真实训练Tab selected通过，t24.90点击trainingHome.dailyClearance、t25.01 Synthesize event，之后15秒breakStatus不存在。此次实际view_image完整审`.../screenshots/daily-normal-03AF16B9-5235-4E95-9DDC-688D1B49D617-terminal.png`：完整训练首页、上方继续清台、训练Selected。对应terminal.txt第42行真实入口frame(263.7,144,110.3,44)。无开球/完成操作。 |

002/003的具体测试源均保存在各run `tested-sources/QiuJiUITests/DailyClearanceNormalDiagnosticUITests.swift`，selector/exit/xcode-test.log可复核。003源码对入口已有frame在window内、TabBar上、hittable/enabled守卫；日志确认事件派发，不能无证据归因“按钮在TabBar下面”或“没有点”。O/formal-004-daily-manual-break-003/observation.json保留设备/录像/负载；当时负载较高不是已证根因，不能凭它替换交互诊断。

现有历史设备是 `9A9EBD8F-2D89-4E98-A035-B71752FAB8D3`，归档名QD004-Daily-20260908。本次没查设备实时状态，不能保证当前启动/日期/草稿仍如历史。不得重建、换seed或清原草稿来伪装续测。

## 下一批唯一最小行动：入口对照 → 真实手动完成交付

先由主控串行完成**一次有新增观测的入口对照**，而不是重选旧整方法：

1. 只读核该专用设备当前owner、日期、activeDraft phase/seed及App PID，保存新目录；确认仍manualRacked且同日。如果跨日归档或设备不存在，明确当前前置变化，原草稿不可直接复用，不偷偷改日期/种回盘面。
2. 主控确认设备/前台正确、Mac没有锁屏且没有另一UI测试；取得当前训练Selected、真实入口完整PNG/AX和无遮挡frame。通过正常入口**只派发一次**点击，录下输入发生前后连续视频和AX/当前页。优先采用可观察真实点击位置的手动/CUA交互对照已有XCTest事件（仅主控，工具不可用就保留该条件；不绕过锁屏）。这用于区分当前交互与旧测试事件失效，不声称能直接确定产品根因。不新增任意睡眠/多击/坐标常量。
3. 若仍留首页，当批停止并归档；这就是新的有限入口反例，不能接着重试001式长链。若正常进入，记录当前 `dailyClearance.breakStatus`、`break.strike` 或已实际存在的 `break.confirm`。旧001散局并不保证进程重启后保留，因为持久草稿仍manualRacked，恢复逻辑会重新摆架。
4. 当次确为待手动开球时，仅正常点击一次实际`break.strike`，连续视频确认散开到停稳，等待当前`break.confirm`可操作并取证；点击一次完成。不能只凭完成按钮出现就认定运动已审。若当次进入时已经是已确认playing，不再击球，说明前置与预期不同并保留现场。
5. 真实交付若playing：HUD0杆0犯规、目标球>0、无breakStatus/autoBreaking/失败/完成条；保存图/AX与phase=playing正常磁盘原件，正常退出重入核同一局HUD计数。若是源码允许的开球终局球异常：保存实际原因/失败或手动重摆，停止，不换seed追playing、不当成UI点击故障。未停稳或点击未生效单独记实际现象。

新自动化方法应在上述入口对照取得**当前到达实证**后再写：直接复用已实测identifier与有界guard，输入严格UDID/同owner同日草稿声明、全新证据目录；failure PNG先AX后，主控独立磁盘读回。现在不再注册原`testPersistedManualRackStrikeConfirmAndResume`第四次同质运行。

## 完整胜负剩余，不能冒充已有

交付链之后仍缺正常完成/失败→首页状态/重入→再来保留当日完成。当前中八盘要合法清组再进8；不能将“完成”按钮当终局按钮，也不能因目标8被拒就认定正常失败不可实现。

可行的最小后续候选是正常菜单选择4球，保留真实自动/手动开球与规则，减少合法清台杆数；源码有 `dailyClearance.changeGame`、`dailyClearance.game.fourBall`，但本次实际归档未取得该菜单的现时AX/确认提示和新盘几何，**仅有源码不能马上写固定击球脚本**。需先观察正常菜单和当次盘面，确认目标/袋口身份与可行路径，再限定一局一次候选；不 seed 终局、不把自由摆球改变规则盘作为正常清台、不无限换盘。另一种完整失败需要实际合法操作产生终局球违规落袋，其几何同样尚缺。

原B6/SC23范围保留：已有规则/服务断言可以支撑状态机语义，不替代正常物理终局UI；若有界候选未达，保留“可执行但未取得正常终态”的缺口。当前最优先只补手动开球交付，不同时扩完整胜负两个长脚本。
