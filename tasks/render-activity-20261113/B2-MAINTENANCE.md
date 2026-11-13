# B2 共享场景维护收窄

2026-11-13，真源：[活动期方案 v1](../问题集合_3D活动期性能优化_v1.md)。结论：保留局部候选；工作量确定减少，整页 CPU 净收益尚未量化。B1 的按需 HUD 继续保留。

## 实际改动与边界

`AngleSceneView.Coordinator.updateViewport` 的两个分支共用一次实际窗口坐标转换；仅在 rig 的 viewport 或 presentation rect 变化时赋值，避免逐帧先清空再重设。继续读取实际转换：祖先移动而自身 bounds 不变时仍能正确更新，不能仅凭尺寸缓存。可读区 inset 原有幂等早退保留；后安装或替换 rig 依自身状态取得布局。

`DiagramLabelOverlay` 在场景/球集合 revision 改变时准备有序节点列表；revision 只由私有球字典修改增加，不是逐帧发布。球显隐/位置仍逐帧检查，完整布局缓存保留；使用双缓冲键代替每帧排序、filter 和多段数组拼接，只有布局失效才建立 visible 列表。补全 Y、ghost/rail、角度和 surfaceY 输入；实际 renderer 的五个投影锚点继续每次检查。新计数仅 DEBUG 且默认关闭。

原有 label 完整布局缓存本来就能跳过静止布局，**不能把这一既有效果算成本轮新增收益**。本轮稳定 601 次 update 中排序准备为 1 次、布局为 1 次；旧路径源码对应每次 filter/sort，共 601 次，而布局也应为 1 次。后续 600 次没有新增布局。新增/移除实例会重建顺序；Y 改变、显隐、hide 后重显会重建布局而不重新排序。

同时满足全窗口和两视图控制时，旧路径每次两次 `convert`，当前一次；viewport/presentation 写入改为按实际变化。这里的前后转换/赋值次数来自明确源码路径，未伪称为 Instruments 采样。固定小数组、节点状态与投影检查仍有成本，不声称每帧零分配或零工作。

动画扫描、frame pacing、0.5 秒宽限、FPS/偏好缓存、临时俯视缓存、首帧收据、球 uniform 的 didApplyAnimations 顺序均未改。动作扫描在发现首个动画时已退出；没有取得它的独立显著成本证据，完整动作所有权又超出本批，故保留。8 个生产 `AngleSceneView` 调用点均显式传入 contentIsAnimating；当前无 nil 生产宿主可作 UI 代表，nil 的兼容分支原样保留，不能虚称已验一个不存在的 nil 页面。

## 有效验证

- `build-r2.log` App + tests 构建通过；后续三次 UI-only 修改的最终构建 `build-ui-r3.log` 通过。
- 受管 iPad Pro 13 M4 / iOS 26.3：**40 项逻辑用例通过，0 失败/跳过**。覆盖 Daily3DRenderDiagnostics、AngleDiagramAnnotation、AngleDynamicAssist、AimCloseupUpdate。3 项新增用例检查 600 稳定帧、实例增删、祖先移动/可读区变更/关闭全窗口及移出 window。
- 有效 UI 为三个 selector：`testAngleDynamicNoticeAtTop`（r1）通过，实际拖目标球、指标变化与重进；`testP01TemporaryTableProjection`（r2）通过，正式 2D/临时 2D 的逐球位置与投影边界一致并恢复 3D；`testActivityMaintenanceAcrossShotAndPageLifecycle`（r3）通过，当前首页真实进入、两次实际击球/停稳、撤销、每杆后台恢复、离页重进。分别保留原始 PNG/AX/JSON。
- 已打开检查角度图初态与恢复 3D 原图：标注、球影与投影可见。其余截图继续纳入 B4；不声称跨设备、像素级相等或用户认可。
- 每轮显式安装后读取二进制 SHA，App 相同：`8e6dcf74bb807aefc9b76d0a346a24fa517ab38b46eaf77838b0ff5deb7ebecb`。仅改 UI 测试不改变 App。原件：[b2 目录](../../output/render-activity-20261113/b2/)。

## 失败记录与解释

初次 test build 的新夹具误写只读 `usesFullWindowTableViewport`，编译拒绝；改为真实入口 `tablePreferencePage`，未修改生产访问控制。

旧 P01 两个 UI selector 把当前首页入口当作旧 `shotSimulation` 宿主，真实 AX 显示已为 `composer.landscape`、标题“分离角与走位”；修正入口标识及 iPad 方向假设。临时俯视随后通过；旧 `testP01BackgroundReplayAndExit` 在点击后立即断言菜单禁用仍失败，尚未验证后续“中断即取消首杆”旧合同。源码中该取消路径仅属 isShotSimulation，不能移作 composer 的验证；该旧失败保持记录，未删除其断言、未标通过。新增当前宿主的完整击球/后台/进退合同已通过。原因与防复发见 FL-268。

## 适用性、资源和下一步

局部继承 TP16/17/23/27/29/30/35。没有改页面结构、相机公式、物理、分辨率、MSAA、材质或 FPS。新有序节点列表只属于 overlay，大小受本场景球集合约束；不另建发布器/定时器。生命周期释放与跨宿主汇总由 B4 收尾。

使用已有共享 `build/DerivedData`，不删除其历史缓存。设备每轮均通过 fleet large-pad 独占租约；脚本 finally 关闭本轮启动设备并释放，不删除核心数据。失败原件与成功结果均保留。

按方案的工作量证据保留候选，CPU/提交量净收益未证明、手机降温未验；不为本批重复追测百分比。下一批 B3 的算法探索不依赖 B2 的时间收益，直接继续。

后续状态：B4 已完成本地共享集成，实际覆盖与环境缺口见 [B4-COVERAGE.md](B4-COVERAGE.md)；阶段交付与最终成本口径见 [B5-DELIVERY.md](B5-DELIVERY.md)。本文早期“下一批”段落保留为该轮时点记录。
