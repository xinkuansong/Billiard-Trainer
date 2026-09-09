# 计时旅程视觉复核 — snapshot004

2026-09-08，UI Reviewer。本子任务实际 view_image 打开 6 张指定 PNG，核读同 stem AX、inputs.json、exit.json 和 QD-Timer 日志；没有操作模拟器、运行测试或改业务。主控独立查看的 rest-extended、rest-minimized-ticking、training-ended-note-phase 不在本次 6 图目视范围内。

## 运行与原件身份

- 原件目录：`archive/quality-diagnosis/runs/formal-004-plan-timer-003`。6 PNG 及 6 AX 与 build 下同名文件逐个字节相等。
- 输入：snapshot004 / QiuJi / CB246F30-E917-492B-B0C4-511F473D8C15；Timer 测试源记录 SHA256 `3c1400b0d7e1b80125bc42c81f5406851b2b7deffd861c393f972139ea0b0647`。
- started 11:23:41.188282+08:00，finished 11:26:15.319288+08:00，make_exit 0。
- xcode-test.log 667–818：Timer 精确方法 `testNormalTimerPauseResumeMinimizeBackgroundAndRestExtension` 91.885 秒通过；另一计划方法 34.580 秒通过，run 总 2 tests / 0 failures。耗时含测试开销，不是性能验收数字。

## 逐图观察

### running

实际图显 00:00:04，暂停图标；自由训练、中袋直线出杆、第 1/8 杆，未填成绩。AX 训练时间 00:00:04 / 暂停计时。

[PNG](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-running.png>) · [AX](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-running.txt>)
PNG SHA256：`672b7ebfd1aa1032407af834c8437848845bf7c125a554862fb95e4d39808542`

### paused-unchanged

实际图显 00:00:06，按钮变播放图标；AX 00:00:06 / 继续计时。单帧本身不证明保持，日志两次相隔约 3 秒仍为 6 秒才是保持证据。

[PNG](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-paused-unchanged.png>) · [AX](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-paused-unchanged.txt>)
PNG SHA256：`0174eb311585fff97125329ec6b04d4a748361d45679e1bb8bb4885d1e509a2a`

### session-minimized

实际图为训练首页，右下绿色播放图标 + 0:13 胶囊在 Tab 上方；五个 Tab 可见。AX minimizedTraining.resume：继续训练 0:13，点击返回。该帧没显示整张活动训练页。

[PNG](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-session-minimized.png>) · [AX](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-session-minimized.txt>)
PNG SHA256：`d3b817db25a97435972347194f43ea9251bf66b81742ce7c8081ebf886fe706f`

### session-restored

实际图返回同一自由训练与动作，00:00:18 / 暂停图标。末位 8 处于数值转场，画面稍模糊；AX 明确 18 秒。未以这一瞬时动画当文字常态模糊缺陷。

[PNG](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-session-restored.png>) · [AX](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-session-restored.txt>)
PNG SHA256：`2da5d7dddeaa3647bb238d948079c87246cfcc59848ea6d99ca5fad63e3afecb`

### foreground-time-restored

实际 PNG 为 00:00:25，暂停图标，动作/未填成绩保留；同 stem AX 读到 00:00:27。PNG、AX 与日志是先后采集，不能假称原子同一时刻；日志取样为 25 秒，截图后 AX 继续走到 27 秒符合运行态。

[PNG](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-foreground-time-restored.png>) · [AX](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-foreground-time-restored.txt>)
PNG SHA256：`6e531bfade6ef660d35e7f7b59d9e9f9d6001da609796edd7c84d9fdca025225`

### rest-finished

实际图回到自由训练记分页，00:00:46、暂停图标、休息设置 60s；未见休息覆层/倒计时胶囊。AX 46 秒、休息设置；没有 完成休息 按钮。60s 是下次休息配置，不是当前剩余。

[PNG](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-rest-finished.png>) · [AX](</Users/song/projects/13.billiard_trainer/archive/quality-diagnosis/runs/formal-004-plan-timer-003/screenshots/timer-033618D9-4E6B-42C1-B2F1-C2C73E0788CF-rest-finished.txt>)
PNG SHA256：`164655851cd144dd3e1e2ed75c5defcb94b8ba2b67a949929520d0102702eaa5`

## 与日志数值交叉核对

| 阶段 | 实际日志值 | 可支持的结论 |
|---|---|---|
| 启动 | 0 → 1 → 4 秒 | 正常启动并走秒；1 到 4 的单调采样起点间隔约 3.027 秒 |
| 暂停 | 6 → 6 秒 | 两次单调采样起点相隔约 3.025 秒，暂停精确保持 |
| 继续 | 7 → 10 秒 | 单调采样起点相隔约 3.028 秒，继续后增长 |
| 整场缩小恢复 | 10 → 18 秒 | 单调采样起点相隔约 8.030 秒，没有归零 |
| 短后台前台 | 18 → 25 秒 | 单调采样起点相隔约 7.747 秒；截图 25 秒，后采 AX 27 秒 |
| +30S | 59 → 87 秒 | 经过约 1.669 秒得到净增加 28 秒；与 +30 后继续倒计时一致。此处只核日志，该两阶段图由主控另审 |
| 休息最小化 | 84 → 81 秒 | 单调采样起点相隔约 3.079 秒；下降 3 秒。该阶段图由主控另审 |

## 结论与限制

六个指定状态有实际图像证据，截图中的计时状态与对应 AX/日志一致（允许采集时刻不同，已单列 25/27）。运行、暂停、整体缩小、恢复、前台恢复及完成休息的页面均可辨识；未发现这六帧中的计时数字裁切、主动作消失或休息覆层残留。训练最小化胶囊未遮住所见五 Tab。

- 这不是六个新增测试通过；是一个已执行 Timer 方法的六帧独立视觉复核。
- 静态图不证明连续时钟；暂停保持、走秒、后台差值依据原始 QD-Timer 日志与真实通过断言。没有重跑或重新采样。
- 全部六图为浅色页面；未覆盖 Dark、其他设备、Dynamic Type/VoiceOver、触摸扩展热区与长时间运行。
- 完成休息后的 46 秒仅为实际显示，不据此裁定休息应计入训练总时长。Q-v48-1 意图缺口保留。
- 不证明休息后台、真实锁屏/灵动岛、进度环随时钟变化、到零自然结束、Activity 释放、数据库计时保存或长时稳定性。结束心得阶段未由本子任务重复目视。
- 新增已确诊 P0/P1 视觉问题：0；这不代表完整视觉或系统计时验收通过。
