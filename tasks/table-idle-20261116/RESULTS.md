# 2D 四状态模拟器工作量诊断

2026-11-16，北京时间。最终 r4 定向诊断通过；正式 App 未修改。

## 结论与处理

沿用户确认的“返回练习列表→进入下一页”路径，未发现多页球桌同时持续运行。最终一轮12次进入退出、三页各3杆、55个检查点，实际1项XCTest通过（653.632秒，0失败/0跳过）。所有11个约20秒静置窗口，所跟踪球桌 didRender、didApplyAnimations、CADisplayLink、updateUIView/layout及轨迹重算均为0。切页后的三页静置CPU为0.48–0.54%，初始与最终列表均0.53%，没有静置负担随切页累积的证据。

12个VM、12个renderer、12个coordinator、13个scene最终全部弱引用失效，已监测计算任务0；各检查点最多1个VM存活，观察到释放后的对象没有帧/回调增长。这里是指定对象、指定检查点与有限窗口的证据，不是对所有对象无泄漏或所有导航路径的证明。

当前无需据此重构页面关闭逻辑或清空所有模型缓存。本轮没有发现必须修复的持续后台渲染/重算。后续若继续追手机发热，应测活动期真机CPU/GPU与热状态；本轮观察到的负载主要集中于击球、回放、重打及切页初始化窗口，但尚不能把手机温升归因某一项。

## 范围与方法

Test Engineer；已使用项目适配、table-page-adaptation、simulator-use、mac-mini工作流。局部诊断继承TP01正式入口、TP15过期计算、TP30休眠/唤醒/释放、TP35证据边界；不改布局、画质、物理精度或用户数据，不重跑整页设备矩阵。

- Mac mini / Xcode26.2 / iPhone16Pro / iOS26.2。独立冻结源码副本、优化Debug（Swift -O）、2D偏好。真实入口：练习→走位→分离角与走位/两球走位/三球走位→返回列表。
- 弱引用记录VM/scene/renderer/coordinator；记录didRender、didApplyAnimations、DisplayLink、updateUIView/layout、composer.recompute、two/three.redrawCue、simulateFree及其累计墙钟耗时、inventory.timer。异步任务计数仅覆盖注入的选定求解入口。
- getrusage进程CPU差分÷墙钟×100；**单核100%口径、Mac模拟器App进程值**，不是手机/整机占用，也不是GPU时间、功耗或温升。活动窗口包含UI操作等待、重打及探针/AX开销，不是纯渲染成本或连续满载基准。
- 2×2透明UIKit AX探针按查询生成快照，无周期诊断定时器；计数锁和既有3dDrag业务探针有开销，不称无侵入生产基准。
- 静置窗口20秒、开始前10秒收尾；等待不等于动画完成证明，实际计数说明窗口内是否仍在运行。每页3次真实击球，前两次重打，最后一杆保留完成状态测静置后再重打退出。两球完成态result；三球先通过实际投影选袋，第一杆成功自动到stage1/aiming且firstScore存在（这不是完整两杆题）。
- 两轮×三页进出后，再分别重进三页测静置，最后回列表测静置。全部三页首入截图及最终列表截图已打开核对，均为指定页面/2D。
- 范围不含真机、GPU计时、温升、电池、长时挂机、全球形/全App回归；没有采集内存字节曲线，不把弱引用释放等同所有缓存归零。

## 实测差分

| 窗口 | 秒 | CPU（单核100%） | didRender | DisplayLink | 展示区timer |
|---|---:|---:|---:|---:|---:|
| list.initial | 20.04 | 0.53% | 0 | 0 | 0 |
| composer.firstIdle | 20.03 | 0.67% | 0 | 0 | 0 |
| composer.shots | 25.76 | 27.92% | 1465 | 1434 | 20 |
| composer.afterShotsIdle | 20.03 | 0.68% | 0 | 0 | 200 |
| two.firstIdle | 20.03 | 0.50% | 0 | 0 | 0 |
| two.shots | 29.03 | 27.08% | 1358 | 1288 | 14 |
| two.afterShotsIdle | 20.03 | 0.71% | 0 | 0 | 200 |
| three.firstIdle | 20.03 | 0.54% | 0 | 0 | 0 |
| three.shots | 26.08 | 25.55% | 1117 | 1041 | 0 |
| three.afterShotsIdle | 20.03 | 0.62% | 0 | 0 | 0 |
| switching | 107.25 | 11.88% | 703 | 430 | 0 |
| composer.reenteredIdle | 20.03 | 0.48% | 0 | 0 | 0 |
| two.reenteredIdle | 20.03 | 0.48% | 0 | 0 | 0 |
| three.reenteredIdle | 20.04 | 0.54% | 0 | 0 | 0 |
| list.final | 20.04 | 0.53% | 0 | 0 | 0 |

composer=分离角与走位；two=两球走位；three=三球走位。firstIdle为首入静置，afterShotsIdle为最后一杆后停手，reenteredIdle为两轮切页后重进。switching包括实际导航、选袋及每页短暂停留，不能将其平均CPU直接视为页面初始化峰值。

分离角和两球保留进球结果时，PocketRailInventory的10Hz检查timer各触发200次/20秒；CPU分别0.68%、0.71%，帧与界面重算仍0。这个轮询有优化空间，但此次未证明它是手机发热主因。离页后以及最终列表窗口timer增量0。三球成功第一杆后自动前进，所测第二杆待击态timer增量0。

两球3杆simulateFree累计墙钟13.52ms，三球3杆10.31ms；切页窗口10次合计46.44ms。仅代表被注入的这个方法，不代表全部预测算法/所有异步工作，也不能据此认定GPU是瓶颈。

## 生命周期源码对应

- `QiuJi/Core/Scene/AngleSceneView.swift`：`dismantleUIView`停止渲染循环、移除camera观察/overlay、取消交互及反馈，清空delegate、camera、scene；`stopRenderLoop` invalidate DisplayLink；`updateFramePacing`在无活动时暂停DisplayLink和isPlaying，关闭rendersContinuously。
- `QiuJi/Core/Scene/TableModelLoader.swift`：TableResourceCache可保留共享热资源和至多1份已detach的球桌模型以缩短重进耗时；这不是持有整页VM/renderer持续渲染。内存未回首次启动值不能单独作为多桌运行证据。
- `QiuJi/Core/Scene/PocketRailInventory.swift`：有袋内展示球时0.1秒检查源球是否回桌，clear/deinit停止timer；本轮用独立计数验证。

## 证据与收尾

- 最终job：`table-idle-20261116-r4`；本机副本`35f296a1cda24080a844dc2e95bc36e8`；冻结快照`68a7f695920ea010333fbc96285d691cfbbb8b2526bfc8bf8ad111411be57c6a`。结论对应这份快照，不替同时进行的其他改动背书。
- 原始回传并校验：`output/table-idle-20261116/r4/`，含build/tests.xcresult、test-summary、lease-after、源码snapshot-manifest及证据hash；原xcresult未交给导出工具改写，使用本机工作目录APFS副本导出。
- 导出附件：`output/table-idle-20261116/r4-attachments/`；差分与生命周期分析：`output/table-idle-20261116/r4-analysis.json`。可用`python3 scripts/research/table_idle_20261116/analyze.py output/table-idle-20261116/r4-attachments --out output/table-idle-20261116/r4-analysis.json`重算。
- `scripts/research/table_idle_20261116/`保留快照准备、诊断注入、UI过程及分析脚本；最终分析脚本增加已释放对象回调增长检查，不改变已测二进制。
- 临时模拟器52D53E26-F01C-437E-94EB-3DFD9D197E63已由受管流程删除（lease-after=deleted）；远端/本机工作目录收尾状态见下方。

## 测试前置复核修订

r1 已开始构建后，源码复核发现三球需先选下一颗球的目标袋，原脚本只点击击球会进入提示而不是出杆。保留 r1 的运行与失败/部分采集，不视为完整四状态验证；未杀运行中的任务或改其快照。r2 补真实投影位置点击选袋并回读 plannedPocket、击球按钮文案、playsStroke、每杆 phase=result，结果探针作为附件保留。上一轮生命周期记录也同步纠正：三球3次点击不能算真实击球中退出，30次释放观测仍成立。

r2 本机副本 `139d164e3f884929810e7af00b4f572f`，快照 `a69812fcfeea54b64e5c5345ae0f3737f5ef4af4d48ad8ee152b353302ace14b`，job `table-idle-20261116-r2`。启用既有 `3dDrag.probe` 读取原生投影后点击，活动期额外AX编码成本应与业务成本区分，不作为无探针生产CPU基准。

r2 在 queued 状态取消（0测试），改为r3：最后一杆结果保留20秒再重打，以覆盖有袋内球的停手状态；r2已回传取消证据并完成远端/本机独占目录收尾。r3 本机 `aeb3608ebc1b4bd6bf8ffbd740bb96d7`，快照 `ed18db377bd1d944d42b175db062878e153466044de31ef37eac9f8029c63945`，job `table-idle-20261116-r3`。

r1 完整构建通过；实际1项UI执行391.055秒，在三球未选袋后的重打按钮等待处失败，符合已识别的夹具缺口，不作App性能失败。前两页与三页首次静置附件保留作部分观察。修订版未放宽断言，而是补齐业务前置。

## r1 部分有效观测（非整轮通过）

28个检查点，6次已到重打可用态的击球。三个首入静置窗口约20.03s：帧/DisplayLink/updateUIView/所记录重算全部0；单核100%口径的App进程CPU分别分离角0.56%、两球0.47%、三球0.66%，列表0.55%。分离角与两球3杆操作窗口分别27.22/30.27s，CPU25.48%/24.61%；恢复球形后的静置均0.47%、无帧和重算。原始附件 `output/table-idle-20261116/r1-attachments/`，差分 `r1-analysis.json`。三页首入截图均已打开确认2D。

r1 失败设备已确认由本任务独占、Shutdown、无租约/外部占用，经retire保留0天与精确UDID cleanup删除；原失败证据和状态保留。r2只取消未执行。r1仅部分有效；完整结果以最终r4为准。

### r3构建期中止与最终r4

进一步读 `ThreeBallPracticeViewModel.completedPlayback` 和既有 `ThreeBallPracticeUITests` 后确认：成功第一杆会自动 `advanceStage()`，完成态应为 `phase=aiming, stage=1, firstScore!=nil`；不是通用result。r3 尚在generic模拟器 build-for-testing，核PID13672完整命令归属后仅向该xcodebuild发SIGINT，队列正常记failed，未启动UI/分配设备，0性能样本，不归因App。未修改运行快照、未停止其他任务。

r4按真实合同检查两球result、三球第二杆aiming+stage1+firstScore；三球停手样本准确命名为“完成第一杆后的第二杆待击态”，不是错误要求停留在结果页。本机运行 `35f296a1cda24080a844dc2e95bc36e8`，快照 `68a7f695920ea010333fbc96285d691cfbbb8b2526bfc8bf8ad111411be57c6a`，job `table-idle-20261116-r4`。生产源码未变。

## 最终收尾确认

r4远端complete已回传：仅删除本job的build/source和已归档快照；本机受管工作副本已complete回收，原始证据、导出附件与分析均保留在output/table-idle-20261116。r1失败设备及副本、r2取消副本、r3中止构建也已按各自归属完成收尾。派生文件校验表为r4-derived-sha256.json；限定文件diff --check通过。无正式App改动、无提交或发布。
