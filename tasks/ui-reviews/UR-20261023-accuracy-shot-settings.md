# 准度击球设置审查 · 2026-10-23

范围：2D／3D准度入口设置、标准打点盘、实际出杆及重打。依据用户提供的分离角设置样式、DR-428、ADR-P18-11与TP11/24/27/33；继承既有六页完整TP审查，本轮不重宣全App通过。

## 功能证据

证据根：`output/accuracy-shot-settings-20261023/`，设置主体验证源码哈希见`settings-source-sha256.json`，取消自动调整提示后的最终源码见`source-sha256.json`；仅ViewModel移除提示转发有差异。

|项目|结果|证据|
|---|---|---|
|构建及单元／集成|36通过、1诊断用例按原规则跳过、0失败|`verified.log`／`verified.xcresult`的QiuJiTests部分|
|iPhone 16 Pro Max／iOS26.3.1|1项UI通过，同一用例完整覆盖2D及3D|`ui-final.log`／`ui-final.xcresult`|
|iPhone SE3／iOS17.0|1项UI通过，覆盖2D及3D|`small-verified.log`／`small-verified.xcresult`|
|取消自动调整比例提示后的增量|1项实际物理＋1项双模式UI通过、0失败|`silent-verified.log`／`silent-verified.xcresult`|
|DTO／后端契约检查|FAIL 0／WARN 0|`schema-gate.log`|
|差异空白检查、进度体积门禁|通过|`git diff --check`、`verify_doc_size.py`|

逻辑覆盖：新默认、双向互斥、两轴独立、两组均关、旧配置迁移、保存往返、非法值、固定非零轴及打滑圆边界、实际尝试与出题类别不同的合法保存、非法锁定轴拒绝。2D/3D真实VM出杆产生的轨迹与相同实际打点的独立模拟逐采样吻合，并与中杆轨迹存在差异；验证重打/回放各自打点、首杆不可覆盖、下一题清除草稿及后台恢复。沿用六口高度、特写、透明度及共享打点盘数学回归。

原生UI覆盖：两组开关双向切换、另一轴不联动、关闭不反向开启、标签去“允许”、标准盘高低/左右微调、回中、真实出杆后重打保持打点、重新进入设置保留配置、混合轴模式方向键禁用与可调轴生效。

## 原图审查

改前采集`before/`来自同一受管大屏手机；改后`large-final/`为XCUITest原始截图的同内容命名副本，不经过裁切／重画。

|原图组|已核内容|结论|
|---|---|---|
|大屏2D/3D：manual-settings-on、generation-settings-off|练习模式下新增击球设置；原生圆角分组、分隔线、品牌绿开关、灰色尾注与i图标；出题名称简化|通过，说明完整可见|
|大屏2D/3D：mixed-spin-settings|单轴关闭状态、重新开始入口、表单滚动与其他条件|通过|
|大屏2D/3D：manual-spin-adjusted、mixed-spin-controls|标准盘、四向键、回中、实际读数与侧栏；未增答案辅助|通过；禁用权限另由UI断言确认|
|小屏2D/3D同组10张（small-success/）|两组尾注可见、滚动可达、单轴状态、标准盘及读数|通过，无新增截断/遮挡|

大小屏各已逐图核对上述10张；颜色／字号沿用系统Form及btCaption2/btTextSecondary，不新增硬编码颜色。已核范围未发现新遮挡或文字截断。浅色设置与球桌HUD为实际采样外观；未声称完成Dark Mode、最大字号、VoiceOver、iPad、真机及性能验收。

## 失败与修复

- FL-200：第一轮保存层仍要求题目/尝试杆法类别一致，调整后不能出杆。已改为实际坐标与锁定轴校验；保留`unit`、`ui`失败记录及修复后逻辑结果。
- `verified`中的UI失败：测试直接点全桌关闭层的中心，实际落到打点盘中心；改点盘外并确认面板消失，原打点一致断言保留。生产逻辑无需改动。
- `small-final`：既有比例调整提示阻挡点击，曾以精确识别文案关闭后在`small-verified`通过。用户随后要求直接自动调整、不提示，生产代码移除提示转发，最终UI改为明确断言无弹窗。
- `silent-final`：测试选择器参数格式错误，未启动用例；已改为两个独立-only-testing参数，保留命令日志。
- SE17首轮`small`：App级滚动在设置返回后的方向状态拉出系统通知中心；改为Form容器内滚动，不放宽开关断言。最终结果见上表。

未执行真机安装、提交、推送或发布。现有分离角及视频任务修改保留；本轮测试结果不代表它们的验收。

## 可查看原图

[击球设置](../../output/accuracy-shot-settings-20261023/large-final/2D准度-manual-settings-on.png) · [出题设置](../../output/accuracy-shot-settings-20261023/large-final/2D准度-generation-settings-off.png) · [2D混合轴](../../output/accuracy-shot-settings-20261023/large-final/2D准度-mixed-spin-controls.png) · [3D混合轴](../../output/accuracy-shot-settings-20261023/large-final/3D准度-mixed-spin-controls.png)

最终收尾：受管模拟器测试命令成功退出，租约由入口释放；独占测试工作目录运行4f1f8cdff5894e65860a94972ca0a2c6在导出证据后关闭回收。日志与结果包留在证据根。
