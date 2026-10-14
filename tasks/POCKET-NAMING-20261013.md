# 击球页面袋口方位命名 · DR-391

## 短契约

用户于2026-10-13确认并授权实施。范围为每日清台、练习相关击球页面、上手试打说明及其无障碍反馈；固定参考方向的教程图片和历史内容文案不批量重写。

- UI不显示袋口编号，内部0…5和schema ID不变。
- 横桌：四角按屏幕方位命名，中袋为上中袋／下中袋；竖桌为左中袋／右中袋。
- 以页面实际2D布局为参考，不按phone／pad硬编码。3D共用该参考；相机转动、2D/3D切换不改名，横竖布局变化更新名称。
- 想三球使用“第1杆目标袋”“第2杆目标袋”；44pt按钮分两行表达，菜单显示完整角色及方位。

| 内部ID／索引 | 横桌名称 | 竖桌名称 |
|---|---|---|
| topLeft／0 | 左上角袋 | 左下角袋 |
| topRight／1 | 右上角袋 | 左上角袋 |
| bottomLeft／2 | 左下角袋 | 右下角袋 |
| bottomRight／3 | 右下角袋 | 右上角袋 |
| topCenter／4 | 上中袋 | 左中袋 |
| bottomCenter／5 | 下中袋 | 右中袋 |

## 实现

`PocketDisplay.name`要求显式传入方向。FreePlay、BTTeachingTablePage、SceneAiming和AimPoint以布局状态传递给AngleSceneView；场景保留2D参考供无障碍名称使用。试打说明通过共享页面的Environment获得同一方向；PlanThree通过布局回调更新角色文案。删除BankShot未使用的独立名称表。

当前每日清台已走核心模板；旧状态pill源码不代表当前可见UI。此次不增加新标注，也不修改袋口皮革、选袋规则、球位、相机动作、物理或存档。

## 验证与证据

- [原生截图 HTML 对照页](../output/pocket-names-20261013/review.html)：17张原图，按前后对照、手机、iPad、想三球、角度训练与每日清台分组，支持点击放大及下载。

- 修改前有效基线：`output/pocket-names-20261013/before/tryout-c042-phone.png`。手机横桌仍写“左侧中袋”；同目录早期`tryout-phone.png`误到首页，不作基线。
- 自动回归：14项单元测试通过（10项真实试打数据回归＋4项命名测试）。覆盖CameraRig真实横竖投影、3D参考不变、真实c042说明随布局改名及无效ID；见`output/pocket-names-20261013/unit.log`。
- `verify-gate`、`verify-doc-size`、`git diff --check`通过。路由签名仅PlanThree命中：测试入口后七行的角色文案变化被签名捕获，实际导航与可达性未变；审查后更新该文件签名。
- 最终原生回归：iPhone17Pro／iPadPro11(M4)，iOS26.3，各2项UI测试通过（共4次）。真实试打横竖切换、3D镜头转动及2D回切；每日清台选袋AX；想三球角色菜单／紧凑按钮；练习正式入口进入2D与3D角度训练。日志：`final-phone-r2.log`、`final-pad.log`。
- 最终16张原生截图逐图检查完成，位于`output/pocket-names-20261013/final-phone/`（7张）及`final-pad/`（9张）。手机横桌与iPad横桌显示上中袋、iPad竖桌显示左中袋；3D使用同一参考。角度训练五字角袋名完整；想三球菜单和44pt按钮不挤字，杆次提示同步统一。当前每日模板无常驻袋名，本次核查选中袋的AX名称，没有额外增添桌面标签。
- 首轮UI的`progress`球形无选中袋，换为明确目标的`cueAccessRoom`；iPad脚本修正旋转后旧窗口查询及练习入口旧标题。原始失败日志保留。一次最终构建受ENOSPC中断；仅清理本轮3个重复xcresult包，已保留摘要JSON、完整命令日志及原生图。恢复空间后最终构建与UI通过。
- 用户真机视觉与手感验收未完成；未提交、未发布。


## 原生审查入口

[UI审查结论](ui-reviews/UR-20261013-pocket-names.md)。

| 核查 | 原图 |
|---|---|
| 手机横桌目标名 | [2D](../output/pocket-names-20261013/final-phone/names-phone-landscape-2d.png)／[3D](../output/pocket-names-20261013/final-phone/names-phone-landscape-3d.png) |
| iPad方位切换 | [竖桌](../output/pocket-names-20261013/final-pad/names-pad-portrait-2d.png)／[横桌](../output/pocket-names-20261013/final-pad/names-pad-landscape-2d.png) |
| 想三球 | [菜单](../output/pocket-names-20261013/final-phone/names-plan-phone-menu.png)／[按钮与提示](../output/pocket-names-20261013/final-phone/names-plan-phone-active.png) |
| 角度训练 | [2D](../output/pocket-names-20261013/final-phone/names-quiz-2D角度.png)／[3D](../output/pocket-names-20261013/final-phone/names-quiz-3D角度.png) |

本轮审查只结论于名称、角色说明及其文字容量；用户真机体验另验，不将截图检查写成用户认可。
