# P09b r02 · 3D角度训练反馈修订

2026-10-09，针对用户四项反馈及两次澄清。

## 目标与来源

1. 临时2D只校正球桌尺寸，按固定2D训练的实际投影桌框验收；保持透明悬浮，下层3D场景仍可见。
2. 答题结果复用2D训练/角度与瞄准的球杆、瞄准延长线、角弧和屏幕正向文字。
3. 两视角共用当前题目与辅助/结果状态，未答辅助不提前显示角度答案；结果可切临时2D复盘。
4. 3D底部不能露出2D地毯条。沿FreePlayView每日清台的背景GeometryReader + ignoresSafeArea处理全窗渲染，HUD仍按safe page布局；撤回中途提出的临时2D地毯背景。

## 实现范围

SceneAimingView使用每日已有全窗渲染容器方式；AimingQuizViewModel两入口启用既有adaptive diagram及辅助球杆；AngleSceneView仅由P09b显式开启标准临时stage取景，其余消费者默认沿原策略。临时场景继续镜像当前源节点，不另生成题目或新建主相机。

## 证据

目录output/table-page-adaptation/P09b/r02：源码before及r01真实before保留；本轮用户图作为需求证据。最初默认build缺少xcpretty且未形成有效构建证据，终止本任务进程后改Makefile test build-for-testing并指定实际UDID。两次中途UI因用户澄清而取消，目录保留，不作最终通过证据。

验证进行中；最终状态、截图清单和局限以verification.json及本报告收口段为准。尚未装真机、未提交；本轮不据旧r01结果宣称iPad或全部Runtime重新通过。

## 视觉否决与回修

failed-readable-frame中3D用例虽绿，但原图显示临时桌仍过大，固定2D参考不可见；不得交付。复核PreferenceKey发现有效测量被nil覆盖，已采用每日同源保留策略；验收追加测量存在与实际viewport=stage，避免两条错误路径相互印证。

## 最终验收

最终build-measured-stage.log构建成功；final矩阵10项单测＋3次原生UI（标准手机3D、小屏3D、固定2D）全部通过，源码指纹一致。手机/SE临时桌的实际viewport与独立stage一致，实际投影桌框与固定2D逐边误差≤1pt；2D与AD01的stage同为(128,42,618,342)pt。原图已审：临时叠层透明，3D铺满底部，辅助开关与结果球杆/标注同步。

- 标准手机原图：temporary-assist-hidden/restored确认静止时同步隐藏/显示辅助；temporary-result/result/result-return确认同题22°答案、球杆、瞄准延长线和正向标注。fixed2D参考实际可见。
- 小屏原图：temporary-result与result-return的桌面/文字/按钮可见；底部无二维地毯条。
- 固定2D原图：球杆、延长线、22°内角弧与文字正常，AD01布局对拍通过。
- 网格在3D流程中按设置打开，同题临时2D同步保留；固定2D参考图没有网格；此处对拍的是桌框尺寸，网格同步另由同题开关状态图验证。
- 门禁verify-gate、verify-doc-size、git diff --check通过。完整命令选择器、日志、xcresult、源码hash与原图清单在r02/verification.json和final下。

本轮未重验iPad、未装真机、未改Figma、未提交；不外推真机手感/温升。状态为已验证待用户体验；下一步仅处理P09b反馈，不推进P02。
