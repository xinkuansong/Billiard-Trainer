# 分离角与走位 120 FPS 真机诊断

2026-11-15 北京时间。iPhone 16 Pro，iOS 27.2（24B119），USB 连接并充电。使用手机原有 CuePhys 1.0.0 (1)，球桌帧率偏好 120。诊断使用「分离角与走位」3D 默认两球盘面，三次观察视角拖动及一次实际击球后的回放。保留原画质配置。诱发动作和取证使用独立 XCTest runner，主 App 未重新安装。

## 运行时目标与屏幕呈现

在同一安装容器和 App 进程分两轮取证。17:32 的 Display / Thermal State trace 无调试器。17:36 的 LLDB 轮单独观察两个 setter，避免断点延迟进入呈现统计。静止运行时读到 ProMotion 打开、设备 screen maximum 为 120、低电量关闭、SceneKit 目标 30 且 isPlaying 为 false。随后观察同一个 SceneKit view 和 DisplayLink，三次拖动唤醒及一次回放均设置 120，空闲时回到 30。DisplayLink 的 minimum、maximum、preferred 三项均实读。

| 操作 | 活动时的 SCNView / CADisplayLink 请求 | 呈现间隔中位数 / P95 | 约 16.67 ms | 约 8.33 ms |
|---|---|---|---|---|
| 转镜头，含三次拖动的间隙 | 120 / 120 | 16.669 / 16.670 ms | 245/267 | 16/267 |
| 回放开始后的约 4.2 秒 | 120 / 120 | 16.669 / 16.670 ms | 217/281 | 63/281 |

回放样本平均 67.29 次屏幕换帧/秒，最高一段连续 25 个约 8.33 ms 间隔。两段多数显示同步事件和系统期望呈现间隔也在 16.67 ms。热状态在本轮完整 19.692 秒持续 Nominal。

呈现使用 Built-In Display 的硬件 swap 时间戳，按 trace 内测试动作划窗。Display 记录的 818 次主屏 swap 均使用 CuePhys 的 Metal present assignment 所标识的五种 surface ID。复用 surface ID 只用于核归属，不用于逐帧配对或计算 GPU 延迟。回放动作取 XCTest 注入事件时间，再留 160 ms 给触摸开始及转场。此样本覆盖实测回放窗口，不代表全杆或长时间温升。

## 归因

偏好层和 App 请求层均可达 120，热限帧在这轮表现中未触发。约 60 FPS 的节奏出现在 iOS 显示同步和呈现链路，夹杂真实短时高刷。现有数据尚不能区分 SceneKit/CPU/GPU 的供帧时序和 iOS 刷新率策略各自的作用。没有取得同窗 GPU 完成区间，不能归因为 GPU 过载。USB 条件也不外推无线未充电温升。

首个自动化尝试停在 3D 菜单 selector，修正后真机自动化通过。首个较重的 Animation Hitches 录制在封存时以断言退出，盘上自由空间同期压至约 100 MB；没有该轮有效帧率。轻量复测两表与 Metal frame assignment 导出成功，GPU 完成表的补试导出错误。首次 LLDB 尝试中断了 App，之后重开进程；最终实读完成并正常 detach。

- [成功的真机自动化与时间锚](../../output/shot-120fps-iphone16pro-20261115/auto-r3.log)
- [屏幕呈现统计与归属](../../output/shot-120fps-iphone16pro-20261115/display-summary.txt)
- [实际运行时设置](../../output/shot-120fps-iphone16pro-20261115/runtime-snapshot-values.txt) · [请求原始值](../../output/shot-120fps-iphone16pro-20261115/live-request-values.log) · [请求轮动作日志](../../output/shot-120fps-iphone16pro-20261115/auto-r4-requests.log)
- [首轮采集工具失败](../../output/shot-120fps-iphone16pro-20261115/auto-r2-dynamic-record.log)

## 17:43–17:48 · 同轮 CPU、GPU 与呈现补采

仍用同一安装包和 iPhone 16 Pro，USB 条件。实际 3D 两次横拖及一次真实击球的回放。使用 Xcode Blank + GPU + Metal Application + Display + Thermal State，同一 trace 记录 CPU 编码与提交、GPU 执行、显示队列、VSync 和硬件 swap。时长约 9.8 s 并以手势和回放事件划窗，两轮各 1 个真机用例通过。无调试器附加于采样窗口。

| 渲染条件 | 阶段 | 呈现间隔约 16.67 ms / 8.33 ms | CPU Metal 编码中位 | Present command 的 GPU Active 并集中位 | App GPU 活动区间占窗口 |
|---|---|---:|---:|---:|---:|
| 2622 × 1206，Fair | 转镜头 | 154 / 14 | 0.69 ms | 6.82 ms | 29.6% |
| 2622 × 1206，Fair | 回放 | 200 / 100 | 1.35 ms | 7.02 ms | 48.2% |
| 1748 × 804，Nominal | 转镜头 | 155 / 8 | 0.65 ms | 7.15 ms | 27.0% |
| 1748 × 804，Nominal | 回放 | 233 / 28 | 1.42 ms | 7.55 ms | 40.8% |

CPU 列是提交表的编码耗时，不含主线程的全部状态更新，也不是 CPU 占用率。GPU 列只算关联呈现命令的 Active 区间并集。占窗口按该 App 所有已识别 GPU Active 区间取并集，不外推硬件利用率、瓦数或发热。手势窗包含拖动之间的间隙。

- 原分辨率 354 个约 16.67 ms 屏幕间隔中，Instruments VSync 轨在中间均无刷新事件。系统的 desired presentation time 也以 16.67 ms 为主，实际 swap 跟随 desired time 的中位差为约 0.53 ms。
- 497 个实际 App present 各有唯一 CPU 提交和 GPU 命令 ID。460 个显示面的呈现可用 `surface ID + (swap time − Instruments CPU-to-display latency)` 精确找回 CPU commit。随后以 command buffer ID 取 GPU 区间，并以 `swap ID + framebuffer index` 唯一对齐入队。原分辨率约 60 Hz 的精确关联中，转镜头 141/147、回放 182/191 的关联 GPU 执行和入队均早于上一帧呈现后 8.33 ms。该时点用作假设的 120 Hz 半拍，系统实际上没有发出这个中间 VSync。少量关联 GPU 区间落在实际呈现之后，尤其在 120 Hz 段。没有把这些样本解释成该帧的就绪时间。
- 主球桌代码的 60 仅来自低电量、严重热状态及恢复迟滞这些条件，实际运行时请求上一轮已单独实读为 120。瞄准特写的 1/60 Timeline 仅在显式调试参考参数下启用。回放用 SceneKit 的逐渲染帧动作推进，相关 1/60 定时用于引导相机等待，非这条播放器的更新时钟。
- 分辨率仅在内存中由 scale 3 降至 2，保持抗锯齿设置。对照前后在同一个 SCNView 读回实际 drawable，结束恢复 2622 × 1206 后正常重启 App，并恢复工程提供的原 UI test runner。对照仍以 16.67 ms 为主。两轮热档位不同，且 GPU 单命令 Active 中位未下降，不能把分辨率缩小 56% 当作已经降低同等比例的 GPU 单帧成本，也不能由此排除渲染负载是系统选档的输入。

**归因**：这两轮观测到的是 iOS 显示同步多次选用 60 Hz，穿插 120 Hz。多数精确关联的 60 Hz 帧已提前就绪，缺少中间的显示时点，足以解释这批样本的约 60。主渲染链没有发现固定在 60 的设置。当前证据无法读出 iOS/SceneKit 选择这一档的内部规则，或证明全场能稳定供应 120 个新帧。生产代码未修改。

- [原分辨率统计](../../output/shot-120fps-iphone16pro-20261115/followup/combined-summary.txt) · [降分辨率统计](../../output/shot-120fps-iphone16pro-20261115/followup/scale2-summary.txt) · [原分辨率真机动作记录](../../output/shot-120fps-iphone16pro-20261115/followup/combined-ui.log)
- [GPU、CPU 与屏幕关联脚本](../../output/shot-120fps-iphone16pro-20261115/followup/analyze-combined.py) · [分辨率实读与恢复](../../output/shot-120fps-iphone16pro-20261115/followup/contrast-scale.txt)
- [同窗原件](../../output/shot-120fps-iphone16pro-20261115/followup/combined.trace) · [对照原件](../../output/shot-120fps-iphone16pro-20261115/followup/scale2.trace)
