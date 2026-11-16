# 跨页面球桌生命周期诊断

2026-11-16（北京时间），诊断完成。用户关心从分离角与走位、两球走位、三球走位反复切换时，旧球桌是否仍同时运行。

## 范围与验收

Test Engineer；使用 simulator-use、mac-mini 与球桌适配技能的局部生命周期分支。TP01 正式导航、TP15 迟到计算、TP30 离页/后台/释放、TP35 证据边界继承现行规范；本轮不修改布局、物理和画质，不重做整页适配矩阵。

诊断副本冻结当前源码，通过弱引用记录 VM/场景/SCNView/Coordinator，通过计数记录真实渲染和 DisplayLink 回调，通过任务起止记录三页求解。探针不保留被测对象；每秒更新小型诊断 AX 节点，不是无侵入性能基准。正式首页 push→页面→返回，不使用缺少导航祖先的直达根页。2D 只读偏好覆盖，不改变物理与渲染配方。

计划 10 轮 × 3 页，共 30 次进入退出；覆盖静止、击球后退出、前后台往返。每次离页等待收尾后核对象和计算归零；每次进入核仅当前 VM 存活。原始检查点以 XCTest JSON 附件保留，目标页首轮原图单独检查。发现失败先保留原件并判定夹具/产品/框架，不用更改业务清理来喂绿。

执行主机 Mac mini，Xcode 26.2 / iOS 26.2。r2 的 iPhone 17 Pro 类型容量已满，构建通过但分配被拒；r3 排队期间发现前序任务也使用 iPhone 17，因此执行前取消；r4 使用同一快照改为当前无保留现场的 iPhone 16 Pro。它不能替代用户手机当前安装包、热状态或耗电实测。

## 记录

- 本机另有活动构建/测试，可用空间约 19 GiB；改用远端串行队列，远端预检约 82 GiB。
- 首次复制被源码漂移校验拒绝：DiamondSystemViewModel.swift 被其他任务更新。未构建、未执行测试；失败记录 `output/local-test-runs/5c7df46457114b57b5a3d7bdd36a2591` 保留，另建新轮，不混合快照。
- 诊断脚本：`scripts/research/table_lifecycle_20261116/`。仅在独占副本注入，未修改正式 App 文件。
- 用户确认实际路径为“返回练习列表，再进入下一页”，与本轮真实导航用例一致。
- r2：快照 `7a8b2674967182d2ed99722f1d3feaaf4cf4742d030630ff4eb6f4bb3d97787a`，4611 个文件；完整构建 `TEST BUILD SUCCEEDED`。受管设备分配报 `Managed capacity reached (8 total / 2 per type+runtime)`。实时 inventory 共 5 台，其中 iPhone 17 Pro 已有 3 台保留/运行/失败现场；不触碰这些设备。测试执行数为 0，不作产品判断。原始证据回传至 `output/table-lifecycle-20261116/r2`。
- r3：同快照选择 iPhone 17；发现队列前序任务也使用此类型，为避免其保留失败现场后再次达到类型上限，在 queued 状态取消，未执行构建/测试。取消证据回传 `output/table-lifecycle-20261116/r3` 并完成收尾。
- r4：同快照选择 iPhone 16 Pro（当前无该类型设备），通过 FIFO 和统一生命周期创建本轮独占设备；已完成，XCTest 1 项通过，0 失败、0 跳过。

## 源码结论（与运行证据分开）

- 每页独立 VM/AngleTrainingScene；没有全局“只允许一个活球桌”的仲裁器。是否残留取决于导航和持有关系，不能仅由独立实例推断叠加运行。
- `AngleSceneView.dismantleUIView` 依次清理交互/观察、停止 DisplayLink，设置 `isPlaying = false` 并断开 delegate、相机和 scene。离窗时 `updateFramePacing` 也暂停；可见但静止时依据动画/交互状态按需渲染。
- 两球/三球通过 `BTTeachingTablePage.onDisappear → suspendActivity → suspendTeachingActivity` 取消预取、参考计算和当前工作，并让过期结果失效；分离角通过 `FreePlayView` 离页挂钩暂停编辑/开球活动。
- `TableResourceCache` 最多保留一套 `idleTable` 静态可复用模型；这是主动缓存，不等于保留之前页面的完整场景、球、相机和每帧回调。因此 RSS 没立即回落不能独立证明旧球桌存活。
- 2D 使用 SceneKit 俯视，仍有渲染、预测和动画成本；本轮不测真机功耗，不能据此判定发热根因。
- 待运行验证的风险：共享页面前后台恢复未显式按页面可见性过滤；部分同步 `simulateFree` 仅在前后检查取消，离页后可能有有限计算尾巴。它们目前是代码风险，尚未证明在用户路径复现。

## 运行结果

- 环境：Mac mini / Xcode 26.2 / iPhone 16 Pro 模拟器 / iOS 26.2（23C54），独占设备 `FDC8BADD-A191-45A1-83D0-1EEA00168E70`。
- 选择器：`QiuJiUITests/TableLifecycleResearchTests/testThirtyRealPageVisits`；实际执行 1 项测试、0 失败、0 跳过，用例耗时 638.753 秒（约 10 分 39 秒）。
- 10 轮 × 3 页 = 30 次进入/返回；其中 9 次点击击球按钮后退出（复核发现三球3次未选目标袋，仅触发选袋提示，不能计为真实击球中退出）、9 次球桌页前后台恢复、3 次列表页前后台恢复。每次返回等待 5 秒再检查，不能据此推断退出瞬间零 CPU 尾巴。
- 83 个 JSON 检查点、8 张截图。30 个 entered 检查点各只有 1 个当前页面 VM；30 个 returned 检查点的 VM、scene、SCNView、Coordinator 均为 0，在途探针任务为 0。
- 最终累计记录 30 个 VM、30 个 SCNView、30 个 Coordinator、34 个 scene（包含辅助场景），全部弱引用归零；30 次 dismantle 事件。后续检查点中已释放对象的绘制/逐帧回调计数未增长。
- 探针累计记录 80 次求解完成，最终在途为 0；覆盖的是脚本明确注入的求解入口，不宣称枚举所有 CPU 任务。
- 已打开首轮三个 entered 原图，确认分别为分离角与走位、两球走位、三球走位的 2D 俯视界面；final 原图确认实际回到走位练习列表。不是直达根页的模拟退出。
- 快照后核心 VM/场景/渲染文件未漂移；共享 `BTTeachingTablePage.swift` 仅菜单重置按钮 AX ID 从 `.resetBoardMemory` 改成 `.reset`，与本用例路线无关。不能扩大为后续任意提交都已验证。

结论：在这份当前源码诊断副本、2D、返回列表再进下一页的范围内，未复现旧球桌持续存活或越切越多。无证据要求因此改成全局单一球桌或大改释放架构；正式 App 源文件未修改。

## 证据与资源收尾

- 原始、逐文件 SHA-256 核验通过的队列证据：`output/table-lifecycle-20261116/r4/evidence/`，源快照同 r2。
- 结构化分析：`output/table-lifecycle-20261116/analysis.json`；导出附件：`output/table-lifecycle-20261116/attachments/`。
- 仅读取克隆的 `tests-analysis.xcresult` 导出附件；没有用 xcresulttool 改写回传原件。
- 诊断注入前清单、注入文件和工具副本：`output/local-test-runs/685321e003404ed294bc7f428a5cc1fc/evidence/`。
- 本机诊断运行 `685321e003404ed294bc7f428a5cc1fc` 已 complete/reclaimed，独占工作副本和 xcresult 分析克隆已回收，原始清单、注入副本和证据保留。
- 成功设备已由生命周期管理器删除；r4 已完成队列 complete，独占 build/source 与无其他引用的快照已回收；r2/r3 原始失败/取消证据保留。仅处理本任务资源。

## 后续建议与边界

本轮回答的是“旧球桌是否叠加活着”，没有测 iPhone 真机功耗/温度，也没有确认用户手机安装版本与该源码一致。它不覆盖切 Tab 保留页面、其他球桌入口、3D、所有球形或长时间使用，不能将未复现表述为全 App 无泄漏。

下一步优先在真机对比四段：新启动只进一个 2D 页并静置、连续操作/击球、同路径反复切换、返回列表静置；记录 CPU/GPU、实际帧回调和热状态，并确认安装包版本。这样才能区分当前页空闲开销、预测计算和反复初始化的热量，针对热点修复。源码中的隐藏页恢复与同步计算取消仍可作为后续边界加固候选，不能当成本轮已证实根因。
