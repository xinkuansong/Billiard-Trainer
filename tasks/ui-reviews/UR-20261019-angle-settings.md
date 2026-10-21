# 角度与瞄准显示设置 · 2026-10-19

用户要求：角度和普通假想球也进入页内设置，顺序为瞄准线、进球线、角度、假想球、3D假想球。原瞄准管道/进球管道接在其后。

## 实现范围

- AngleDynamicView 添加两个页内显示开关，沿用原 DailyHUDMenuItem 样式与交互。
- AngleDynamicViewModel 两项均默认开启、独立保存；控制球桌角度标注和普通假想球圈。左侧切角/厚度等指标、实际球位/选袋保持。
- AngleTrainingScene 的 showDiagramAngle / showGhostBall 参数默认 true，其他调用者保持原显示；保留 quiz 的 showAngleAnnotations 语义。
- 角度关闭仍保留自适应瞄准线/进球线标签的几何输入，2D角弧与3D角弧同步关闭；缓存包含角度开关。
- 菜单继续复用现有252pt浮层及受限滚动，不新增面板宽度/字号/球桌占位。

## 验证状态

已完成定向构建、单元测试与两种iPhone尺寸的UI复验。早期主机尝试构建因磁盘不足失败，日志保留在 output/angle-settings-20261019/before.log；本轮创建且失败的 AngleSettings20261019 构建目录已释放，其它历史产物和设备未清理。

Mac mini / Xcode26.2 / iOS26.2 使用统一FIFO队列。源码来自复制前后清单一致的独立副本，后续共享工作区变化不自动进入快照。改前与改后版本分别封存，最终结果见下节；不代表真机或用户验收。


### 构建与设备环境分开记录
- Mac mini改前、改后均出现 `TEST BUILD SUCCEEDED`，构建日志/xcresult已回传并通过队列SHA校验：`output/angle-settings-20261019/before-build/`、`after-build/`。
- 两个队列任务整体仍记failed：新临时iPhone17Pro分配遇到同型号容量上限（现有失败现场保留），不是编译失败。取消尚未开始的小屏重复构建任务，改为复用同一修改版构建产物。
- 补验继续持有同一个queue worker.lock，等待现有任务完成，再通过各次显式设备租约借用已有标准/SE设备；不删除或擦除旧设备，不修改队列失败回执。
- 六个本任务源码文件及共享教学页、菜单面板、TeachingTableHost均与受验修改版快照一致；快照ID `ad7f391d2179ecfebac31490be0f5e1ea06f2a88236ddb1f0c79fb83f0c7d469`。

### 首轮原生补验
- 11项 AngleDynamicAssistTests 全部通过；其他教学页菜单UI测试通过。新UI测试已确认选项顺序，随后因测试将关闭态AX值误写成空字符串（实际“未选”）失败，已修正断言；失败结果保留在 `output/angle-settings-20261019/recovery-r1/after/`。
- 改前球桌截图已采集；旧版菜单采集因顶部按钮的XCUI默认命中点计算失败中止。修改版沿用已有中心坐标点击方式，不将此脚本问题计为产品回归。
- 修正后的冻结快照 `5c96fe5e388e5aaa3c3207ea794530304bc4733e3ccfbcbad7ba9736d93ef445` 已重新入队，产品代码与首轮相同。
- 本机再次空间不足，已释放本任务改前/首轮修改版的本地重复源码副本；清单和远端不可变源码仍保留，未清理其它任务文件。

### UI脚本断言修正
- 第二轮11项单元测试与其他教学页UI仍通过，新UI测试在查询只读图内标签时失败。原生录像 `r2-failure.png` 确认角度/普通球圈关闭、实体3D球开启且两条线标签正常显示。源码已明确 `UILabel.isAccessibilityElement = false`；因此不能以XCUI标签查询充当视觉断言。
- 取消未开始的r3重复任务。最终r4 UI检查保留菜单顺序、开关状态、菜单关闭、指标稳定及2D/3D往返；图内显示由已有SceneKit/UIKit实测（标签/角弧/球圈隐藏状态）与截图审查覆盖。没有改动产品代码迎合测试。
- r4快照：`d3173c0e6b6254c107c4f28e426c52e7fab831b728c54d013795d149563ff475`。

## 最终结果

- Mac mini / Xcode 26.2 / iOS 26.2：r4 `TEST BUILD SUCCEEDED`，`after-r4-build/fetch-verification.json` 已校验。队列默认新设备分配因容量上限仍记failed，实际测试在同一worker锁下显式借用已登记设备完成；不改写队列旧失败。
- 单元测试：11/11通过（r2，产品与单元测试代码和r4一致）。包括两种视图、独立持久化、失效球形、图内标签/角弧的真实UIKit隐藏状态。
- iPhone 17 Pro：2/2 UI通过、0跳过（设置顺序/独立开关/菜单保留与关闭/指标稳定/2D↔3D；分离角图谱菜单隔离）。
- iPhone SE第三代：1/1 UI通过、0跳过（同一设置与视图往返流程）。最初试借历史临时SE被生命周期管理器拒绝，未操作该设备；最终显式借用已空闲的保留SE设备。
- 原生截图已逐张审查：标准屏与小屏设置文字清楚；关闭角度及普通球圈后，两条线、标签、左侧指标和实体3D假想球保持；3D重开角度及返回2D恢复正确。本轮未发现新视觉问题。
- 最终证据 `output/angle-settings-20261019/recovery-r4/` 共1155文件SHA校验通过；`after/result.json`、`small-existing/result.json`记录实际选择器、数量、OS与设备。两台设备租约均释放并保持原有protected状态，无删除/擦除。
- 六个任务源码与共享教学页/菜单/Host均匹配最终受验快照。Swift解析、`git diff --check`、文档体积门禁通过。
- 范围边界：定向模拟器测试，不是全套回归；未做iPad、大字、完整VoiceOver、真机、用户验收、提交或发布。

截图入口（均为真实原生截图）：

- [标准屏设置](../../output/angle-settings-20261019/recovery-r4/after/attachments/63495906-5D7B-40D4-9ED5-AAE8ED312324.png)
- [标准屏3D关闭角度/普通球圈](../../output/angle-settings-20261019/recovery-r4/after/attachments/9D7AFA61-5BAC-489E-ADD8-27B019B7D446.png)
- [小屏设置](../../output/angle-settings-20261019/recovery-r4/small-existing/attachments/7A26730C-98A9-4A38-A0AB-E6B483862173.png)
- [小屏返回2D](../../output/angle-settings-20261019/recovery-r4/small-existing/attachments/E5C98E2D-4283-479A-B2F6-968E24CCF12E.png)
