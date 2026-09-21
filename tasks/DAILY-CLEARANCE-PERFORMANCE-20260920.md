# 每日清台 2D / 3D 模拟器初步性能诊断

日期：2026-09-20。范围：用户授权在模拟器实测；不修改产品性能策略。

## 环境与方法

- 源码：`35d461682d8caaceeb2ac844b894d150519f2303`；测试开始时仅有既有 `tmp/` 未跟踪文件，未改动。
- Xcode 26.2 (17C52)，iPhone 17 Pro / iOS 26.3 专用模拟器 `133B2301-328F-4952-8020-8140761544FB`。
- `make -f scripts/Makefile build SIM_DEVICE='iPhone 17 Pro'`：最终 `BUILD SUCCEEDED`，退出码 0。本机缺 xcpretty，Makefile 自动回退原始 xcodebuild；日志保留。
- 当前 Debug 构建，默认外观：标准球桌、经典绿，帧率偏好显式 60。没有使用 fixtureSettled 或虚构盘面；真实中八自动开球后，15 球盘面比较静止 2D / 3D。
- CPU 指标为 macOS App 进程累计 CPU 时间差 / 窗口墙钟时间，100% 表示一个主机 CPU 核；每秒读取 ps，非手机 CPU 指标。RSS 与 sample physical footprint 分开记录。
- `sample` 抓调用栈；部分窗口同时采样或查询无障碍树，含诊断开销。没有 GPU 时间、实际呈现帧时间、电池功耗、手机温度数据。
- 原始证据：`build/daily-performance-20260920/`（context.json、measure.py、逐秒 JSON、sample 栈、截图、build.log）。目录被 Git 忽略。

## 有效观察

| 场景 | 窗口 | CPU 单核折算 | 说明 |
|---|---:|---:|---|
| 2D 停稳静止 | 39.35 s | 1.52% | 同一真实开球盘面；RSS 1198.38 → 1198.44 MiB |
| 3D 停稳静止 | 39.34 s | 1.70% | 页面显示 FPS · 静止；RSS 1201.86 → 1170.48 MiB |
| 3D 单次击球及前后等待 | 19.16 s | 8.40% | HUD 杆数 0 → 1；不是纯运动区间 |
| 2D 单次击球及前后等待 | 19.16 s | 7.20% | 自由瞄准，HUD 杆数 1 → 2；不是与 3D 同一杆，不能比较渲染效率 |
| 切入后台 | 29.26 s | 0.48% | 已核实模拟器桌面；进程仍存在 |
| 正式首页、进入前 | 19.17 s | 0.99% | 重启到正常首页，第二进程 PID 5271 |
| 正式入口进入、切3D、返回首页后 | 29.29 s | 1.26% | 已核实返回；采样栈未见 AngleSceneView / TrajectoryPlayback / PositionPlayShotSolver |

静止调用栈主要等待事件，仍能看到 CADisplayLink → renderUpdate → updateFramePacing → enumerateChildNodes；这说明有周期检查，但当前短窗口未发现静止状态持续高 CPU。FPS · 静止是应用自身状态提示，不是硬件呈现帧率的独立测量。

physical footprint：2D 静止约 618.8 MiB，3D 静止约 619.0 MiB，2D 击球采样约 623.4 MiB；进程启动以来峰值 819.7 MiB。与 RSS 约 1.17–1.20 GiB 是不同口径。没有足够证据认定内存泄漏，亦不能外推手机内存。

## 计算热点及无效/受限测量

3D 选袋交互采样明确出现：

`PositionPlayViewModel.launchSolveIfIdle → DirectPotBankFallback.solveBankAlternatives → BankKickSolvePipeline.solveBank → ShotPredictor.predictBankAll → EventDrivenEngine.simulatePrediction`

这是直击几何失败后的翻袋备选搜索，2D/3D 共用。原始 29.25 秒交互窗口 CPU 折算 44.38%，ps 平滑瞬时读数最高 293.9%（多核）。但一次无障碍 secondary action 报 element ID 失效，且反复 AX 查询带来额外开销，动作数未可靠确认；**不能作为确定场景性能基准或直接归因手机发热**。栈证据可作为下一轮定位入口。

2D 交互窗口 29.25 秒 / 16.75%，执行 17 次坐标点击（20.349 秒），未逐次确认实际成功切袋数，不能与 3D 做公平 A/B。

`orbit-3d-60.json` 原计划转视角，但截图并未确认视角旋转，只观察到目标袋变化，因此不作为相机拖动性能证据。`shot-3d-stack.txt` 采集时段大部分在击球前，不能作为3D运动热点证据。`initial-break-and-settle.json` 未覆盖完整启动/开球计算，不报告开球耗时。

2D 击球栈可见 SceneKit 渲染提交与 TrajectoryPlayback.action/stateAt；尚不能区分 GPU 瓶颈与框架/Debug 开销。

## 判断与下一步

1. 本轮短时模拟器观察没有复现静态盘面持续满负载，不能将现有 30 Hz 空闲轮询直接认定为手机发烫主因。
2. 优先对翻袋备选搜索做受控诊断：固定盘面/目标球/目标袋，记录调用数、每次耗时、在途过期结果、最新请求等待；检查过期计算是否可中断。当前只是候选优化方向，没有改代码。
3. 补优化配置下的固定动作脚本、纯运动窗口与相机拖动测试；必要时添加仅诊断插桩，避免高频 AX 查询干扰。
4. 用用户实际发热机型、接近发布配置做 15–20 分钟 CPU/GPU/功耗/thermal 真机采样，才能解释手机发热。当前没有 Release、真机、能耗、30/60/120 帧对照、连续多局泄漏或性能回归门禁结论。
5. 本轮为交互观察和采样，没有运行 XCTest；构建成功不能替代性能验收。

## 退出页面补验

第二进程首页进入前 RSS 约 1139.7 MiB，进入每日清台、切3D、返回后约 1316.3 MiB，保留约 176.5 MiB；退出后 sample physical footprint 638.6 MiB。单次进出不能区分框架缓存、可回收资源或持有泄漏，应以重复进出并观察平台期及 Memory Graph 验证。返回动作曾遇到 Computer Use native pipe closed，重新读取已确认首页且进程未变；这是控制工具中断，不作为 App 崩溃。

仅新增本报告、进度/归档记录和被忽略的测量产物，未修改 QiuJi 产品代码。


后续已补做GPU逐帧、真实开球、优化构建、空闲生命周期及资源审计；最新结论见 [扩展性能诊断](DAILY-CLEARANCE-PERFORMANCE-EXPANDED-20260920.md)。本篇保留初测原始范围。
