# 球桌设置选择后保留菜单 · 2026-10-19

状态：实现完成；iPhone 17 Pro / iOS 26.2 定向原生回归 8/8 通过，截图审查完成；待用户试用。

用户要求每日清台及其他类似页面的设置选项在选择、取消后保留菜单，便于连续调整。

## 根因与修复

自定义 `DailyHUDMenuPanel` 本身不关闭菜单；关闭来自各宿主的选项回调，以及教学页/编排宿主给所有传入动作统一追加的关闭包装。

- `FreePlayView`：台面网格、瞄准特写、分离角、运杆预演、瞄准模式及轨迹档位保留面板；自定义球形编辑的网格/自动吸附同样保留。覆盖每日、自由击球、模拟、蛇彩、编排、试打、自定义球形的共用壳。
- `BTTeachingTablePage`：显示开关和轨迹选档保留；来自调用方的选择项（如角度与瞄准的五种辅助显示、思路训练的左右塞/基础走位）不再被统一关闭。
- 瞄准点训练、角度训练：网格/特写开关保留。
- 批量编排：特写/轨迹选档保留；原本已保留的网格与求解范围继续保持。
- 返回、关闭、点面板外仍可收起。操作布局/训练设置、清空确认、结束和需回台面操作的工具继续使用原关闭/跳转语义；临时换玩法继续原确认流程。

只改变菜单生命周期，不改布局、颜色、偏好层级、训练数据或求解规则。当前 `usesCoreTemplate` 恒为 true，未改不可达的旧系统菜单分支。

## 验证与证据

执行主机：Mac mini，Xcode 26.2，iOS 26.2；通过统一 FIFO 队列和设备租约。测试快照来自 HEAD 加本任务文件及本地生成的六份球房资产，未包含并行中的图标/颗星资产改动；不代表整个共享工作区回归。

- 首次基线 `menu-retention-20261019-before`：构建失败，Git 快照缺被忽略的生成球房文件；保留失败日志。补齐本地原文件到隔离测试提交，不修改项目索引/分支。
- `menu-retention-20261019-before-r2`：旧生产源码＋新交互断言，build-for-testing 通过；新建设备因受管容量已满失败，尚未执行测试。
- `menu-retention-20261019-after-r2`：修复源码 build-for-testing 通过；同样在申请临时设备时受容量限制，未执行测试。
- `menu-retention-20261019-final`：补齐测试前置、动作跳转断言与原用例的显式收起操作；build-for-testing 通过；同样因临时设备容量限制未在队列内执行 UI 测试，随后通过原租约管理器借用池设备续测，6项菜单交互测试＋2项偏好隔离/重入回归全部通过。
- 本机两次因磁盘空间不足无法生成上传临时 tar，最终采用流式传输并通过队列原校验入队；只清理本任务已上传的临时快照，保留清单与失败日志。
- 借用验证持有队列 worker 锁与设备独占租约，先备份原 App/数据，完成后恢复并校验。原队列失败记录保留，续测证据单独保存。
- 原有依赖“开关自动收起”的测试调整为显式关闭或原菜单内连续操作，保留原业务断言。

证据目录：`output/menu-retention-20261019/`。64 个回传证据文件 SHA-256 与远端一致。未装真机、未提交分支、未发布。

### 旧版复现

`validation/before/summary.json`：1 项执行、1 项失败、0 跳过。失败断言为 `Changing a setting must keep its menu open`；已目视检查点击前后截图，确认点击瞄准特写后面板确实消失，属于目标缺陷复现。

### 修复后原生验证

`validation/after/summary.json`：8 项执行、8 项通过、0 失败、0 跳过；`validation/result.json` 记录退出码 0、原设备数据恢复校验一致。

| 测试方法（简写） | 验证行为 | 结果 |
|---|---|---|
| DailySettingsStayOpenAcrossSelections | 瞄准特写/网格双向切换、轨迹连续选档、瞄准模式、明确关闭 | 通过 |
| FreePlaySettingsStayOpenAndLayoutActionClosesMenu | 开关连续操作、操作布局实际打开 | 通过 |
| TeachingDisplayChoicesStayOpen | 教学页网格/瞄准线/进球线、点外部关闭 | 通过 |
| PlanningOptionsStayOpen | 禁用特写前置保持、网格/左右塞/基础走位、轨迹 | 通过 |
| QuizSettingsStayOpen | 瞄准点与角度答题开关、训练设置实际打开 | 通过 |
| BatchSettingsStayOpen | 批量编排特写/网格/轨迹 | 通过 |
| LocalTrajectoryHiddenMemoryAndGlobalSameDetailUnhides | 独立隐藏记忆与全局同值重应用 | 通过 |
| ViewMemoryIsolationAndSameValueReapply | 2D/3D与网格页间隔离、全局覆盖 | 通过 |

### 截图审查

已逐图目视检查旧版前后2张，以及修复后每日特写前后、轨迹选择、教学辅助、自由击球、思路求解范围、批量编排、两类答题共9张。面板在选项改变后仍保留；目标行与原滚动位置仍可继续操作，无本次新增文字截断、面板溢出或异常导航。部分“after-toggle”截图处于勾选动画中间帧，最终选中状态另由 AX 值与反向切换断言核对。

- [每日取消特写后保留菜单](../../output/menu-retention-20261019/validation/after/attachments/C4111687-3AC8-48DD-8BFC-C87B95022B7C.png)
- [每日切换轨迹后保留子菜单](../../output/menu-retention-20261019/validation/after/attachments/D62DDD1C-4E68-4038-A387-9377C28F21A4.png)
- [教学页切换瞄准线后保留菜单](../../output/menu-retention-20261019/validation/after/attachments/4B16AFE5-A8ED-4D87-A1A9-657803E89F15.png)
- 逐图文件索引：`validation/after/attachments/manifest.json`。

### 范围限制

本轮是隔离快照的定向回归，不是共享工作区完整回归。5个生产文件与送测清单逐文件匹配；并行中的角度设置新选项、首页动效及其他资产改动未纳入。原有测试的显式收起调整已编译，但未运行那些完整测试套件。未覆盖 iPad、其他 Runtime、浅色/大字/VoiceOver矩阵、真机及用户验收。设备借用结束后归还；未清理其他设备。
