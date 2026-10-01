# 渲染代码优化 S0：模拟器 CPU 基准（2026-10-01）

状态：**S0 部分完成，S1 尚未开始**。已建立固定输入、默认关闭的计时、局部 CPU 数据与回归；对象分配、真机 CPU/GPU 和整帧归属仍待测。现有证据不足以选定有明显收益的第一项改写，不能宣称 App 已进一步加速。

## 范围与环境

- 真源：[实施方案](RENDER-CODE-OPTIMIZATION-PLAN-20261001.md)，固定画质、物理只读。
- 起点 `b69aa749b12a4e322da1bbca1a78536349531c47`（代码基线 `0e465e0b`）；隔离分支 `codex/render-code-optimization`。
- 工作区 `/Users/song/.codex/worktrees/render-code-optimization/13.billiard_trainer`；未合并 main，也未给手机安装新版本。
- Xcode 26.2、macOS 26.4；专用 iPhone 17 Pro 模拟器/iOS 26.3.1，UUID `08FC41A5-57EA-4262-847B-5B297CF101EB`。
- 实际 Debug 使用 `-O`、保留 DEBUG；每日清台 `.reflection`、曝光 -0.1、MSAA4、402×874 point、请求60FPS，既有相机去重保持。标签另用402×650 point正交视图。
- 生产改动仅为 `Core/Scene` 中 `#if DEBUG` 的可选探针；测试显式赋值才计时，普通场景为 nil，Release 不包含它。探针最多每段10000样本，用锁保护跨线程写入；不逐帧写盘/日志，不修改画面、物理或播放策略。

## 固定回放与边界证明

固定中八 seed52/power8，先生成16球、60Hz、20秒位置/透明度数据，随后复用 `break-replay.json`；计量窗口仅由 SCNAction 消费位置数据，无物理求解。它不等于正式全 App 播放器：球的旋转姿态固定，测试没有完整业务/HUD/音效。

坐标为 X–Z 水平、Y向上、米；`TrajectoryPlayback.surfaceY` 接收球心平面，使用台呢高度加半径。初始高度断言容差1µm；fixture SHA256：`79182a3666b9c92074cf195165b28b66c2dfae96eeccad20c6f2e139078a0911`。

1424个保护区源码/已有资源文件哈希与起点一致，Physics/Rack/PositionPlay/Resources 无生产差异。新工作树所需6个忽略的房间USDZ从原工作区原样复制并核对哈希。门禁另恢复704个已有忽略母版（APFS克隆，未重新生成），后端模型只读检查复用原工作区 `backend/node_modules`；未改内容/依赖清单。

## 未附加 Instruments 的三轮基准

每个模式预热2秒、有效20秒；下列单位均为毫秒。每轮均通过1项CPU诊断测试。

| 轮次 | 模式 | 主回调样本 | 主回调均值 | 主回调P95 | 球影参数均值 |
|---|---|---:|---:|---:|---:|
| 1 | 2d | 1200 | 0.06750 | 0.07767 | 0.02118 |
| 1 | 3d | 1201 | 0.05980 | 0.08783 | 0.02441 |
| 2 | 2d | 1200 | 0.06679 | 0.10825 | 0.01970 |
| 2 | 3d | 1200 | 0.08546 | 0.11142 | 0.03333 |
| 3 | 2d | 1200 | 0.09511 | 0.13600 | 0.03110 |
| 3 | 3d | 1201 | 0.08396 | 0.10529 | 0.03274 |

主回调包含相机/帧率策略/标签探针，不可把子段相加再加主回调。球影更新在渲染回调线程，也不可直接相加为整帧成本。回调约60Hz不是呈现FPS。探针空记录平均0.0575–0.0649µs；主回调计时仍包含子探针开销。第三轮比前两轮慢，说明不能用几个微秒的差异宣称稳定收益；第二轮附近曾暂停另一个本任务设备编译，数据只用于量级判断，不能当严格A/B对照。

每日清台标签段仅是未启用时的返回路径，不能代表角度页布局。另补真正启用的标签微基准，每轮每种状态1200次，场景准备/刷新在标签计量段之外：

| 轮次 | 标签几何 | 均值ms | P95ms |
|---|---|---:|---:|
| 1 | 不变 | 0.00207 | 0.00217 |
| 1 | 连续变化 | 0.13306 | 0.14217 |
| 2 | 不变 | 0.00160 | 0.00171 |
| 2 | 连续变化 | 0.12957 | 0.13758 |
| 3 | 不变 | 0.00159 | 0.00167 |
| 3 | 连续变化 | 0.12946 | 0.14108 |

正交投影断言和三个可见UILabel断言通过。SCNView附件用于核对球与投影，不包含UIKit标签合成，不能作为完整页面视觉验收。该结果是直接调用微基准，并非实际帧率/整页成本。

## 调用栈与缺失证据

修正夹具后独立附加一次Time Profiler，目标PID53129，21:19:25.773–21:19:36.373，因10秒限时正常结束；导出 `time-profile` 得到1576行Running权重样本。包含SCN名称的栈约50.6%，renderUpdate约2.86%，contact约2.54%，合成回放闭包约17.1%；这些是有重叠的样本权重类别，包含测试框架/窗口转换，不是CPU利用率，也不是SceneKit独占耗时。附加录制的回调数据另存，未混入上面三轮。

旧Allocations尝试未导出分配表，**没有取得分配次数/字节**。旧错误高度的调用栈也已撤销。不得把工具退出0写成已完成分配分析。

手机 `09F4853F-6725-5B4F-B956-BAB9471CED89` 当前为 unavailable。没有本轮真机、GPU、迟帧、温升、用户体验验收；真机测试包另行准备，构建成功也不等于设备测量。

## 验证与失败保留

有效回归：`testDailyRenderingProfilesAreSceneLocal`、`testContactPackingUpdatesOnceAndSkipsUnchangedFrames`、`testEventDrivenIdleCandidateWakesForSceneAction`、`testFrameRateReadoutDoesNotWakeIdleScene` 共4项、0失败。CPU基准三次、有效调用栈录制伴随CPU基准一次、修正后的标签基准一次均通过；不计入废弃夹具轮次。

普通Debug build、verify-gate、verify-doc-size、git diff --check已通过；真机Debug -O build-for-testing已成功（未安装/执行）。未跑完整测试矩阵或像素A/B，因为还没有算法候选。

- 初始回放把台呢高度误作球心高度，低一个半径；相关数据/截图/调用栈全部移入 `invalid-height/`，修正并加高度断言后重跑。
- 初始标签夹具在2D设置后调用snapToTarget，切回透视；数字撤销到 `invalid-label-camera/`，改为先snap再应用2D，增加正交断言后重跑。
- 缺本地资源、编译签名修正、错误构建目的地、缺母版/依赖的门禁失败日志均保留，不更改门禁阈值或忽略失败。

证据根：`build/render-code-optimization-20261001/s0/`，含baseline-1/2/3、label-summary、valid-stack、xcresult附件、哈希和日志。统计入口：`scripts/research/analyze_render_code_cpu.py INPUT --output SUMMARY`（支持CPU JSON、标签JSON、time-profile XML）。诊断结束已移除本任务run哨兵，普通测试会跳过这两项；重测需显式在对应s0目录新建run，并通过Makefile选择测试。详细运行日志仍在本地忽略目录，文档随诊断提交保存。

## 下一步

S0 的 CPU 局部部分已可复现，但未完成分配和当前真机整帧测量。先在手机上区分应用层计算、SceneKit提交与GPU工作，再决定S1；没有明确热点前，维持现有相机、球影打包和标签算法。GPU公式批次仍需真机证据和画面一致性验证，不能提前启用既有实验开关。
