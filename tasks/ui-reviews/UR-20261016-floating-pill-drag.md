# 训练与休息浮窗拖动 · DR-094 r2

用户批准分析方案后实施。两个最小化胶囊支持拖动，释放后固定贴右侧12pt；拖动超过10pt才接管点击。单击仍恢复对应界面。同场训练分别保存两类胶囊的纵向位置，切Tab、恢复再最小化保留，新训练重置。首页“自由训练”入口保持固定。

## 实现边界

共享BTFloatingIndicator接收可选的session位置对象，按胶囊真实尺寸限制整个frame；避让安全区、顶部导航/训练标题、底部Tab/操作栏及键盘。暂时避让不覆盖用户偏好高度。VM新增两个内存UI对象，不改计时、训练统计、成绩或持久化。减少动态效果时关闭吸附弹簧，并提供辅助功能上移/下移操作。

源码改前6文件在`output/floating-pill-20261016/source-before/`，本任务差异为`changes.diff`，前后指纹为`source-manifest.json`。MainTabView原先已有其他改动，快照及差异保留该基线；未把全仓dirty算成本任务修改。

## 验证与失败保留

- 改前：iPhone16Pro的2项既有UI通过；原图在`before/`。
- phone-r1：71项ActiveTrainingViewModelTests、17项V51ResponsiveLayoutTests通过；3项UI中2项失败。原因是嵌套Preference尺寸读为零，实际胶囊越界，记为FL-166。改用胶囊自身onGeometryChange测量，零尺寸不显示/命中。保留首轮xcresult、失败截图及附件。
- phone-r2：最终生产实现的17项布局/状态单测通过；3项UI中2项在弹簧结束前读取位置失败。只将UI等待改为实际右边距达到12pt，未放宽边界断言。
- phone-r3：最终6项UI全部通过，覆盖两类拖动、12pt贴右、顶部/底部限制、点击恢复、五Tab保持位置、外围滚动、长达100小时的计时宽度、休息展开/收起、键盘出现避让和关闭后恢复、首页固定入口。
- se-dark：小屏深色模式最终4项UI全部通过，覆盖训练/休息拖动与上下边界、点击恢复、五Tab与滚动、键盘避让/恢复、首页入口不被改为拖动。两台合计10次UI测试全部通过。

新增3个单测含144种尺寸/拖动边界组合、临时障碍与旋转后坐标约束、真实AppRouter会话恢复与新会话重置。生产实现采用部署目标支持的单值onGeometryChange重载。单测与UI通过分开记录，首两轮整体TEST FAILED并未算作整轮成功。

设备：iPhone16Pro（8D5DC391-6FA1-4A51-8327-74B5E8425FFE）浅色；iPhoneSE3（FEC0D1E7-0A8E-4CDB-ADE9-D33DC2D4C898）深色；均iOS26.3。通过simulator_lifecycle显式借用已有关闭设备，独立DerivedData，串行运行；runner退出关闭本轮设备并释放租约，不处理其他评审设备。

## 视觉与门禁

已逐张查看主尺寸和SE深色的拖后胶囊、休息上下界、键盘避让原生截图，文字完整、右边距及控制条避让正常。静态图证明停靠状态，拖动/点击行为由XCUITest验证；不以截图代替手感验收。

`verify-gate`的内容同步、图文、对齐与术语检查通过，但全仓gate因AimPointSceneTrainingView.swift、SceneAimingView.swift两项路由签名漂移失败。这两个文件本任务未修改；未更新其签名来通过门禁。证据见`checks/verify-gate.log`和`checks/route-drift.json`。

未验真机手感、VoiceOver实际操作、Reduce Motion系统设置及最老支持系统；旋转/iPad仅布局单测覆盖，不声称完整原生UI验证。未提交或发布。

原生前后对比：[效果图册](../../output/floating-pill-20261016/review.html)。最终本任务文件diff检查及文档体积门禁结果见`checks/`。
