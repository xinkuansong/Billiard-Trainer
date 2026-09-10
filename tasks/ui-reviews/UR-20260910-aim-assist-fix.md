# 训练瞄准辅助修正（DR-132）

日期：2026-09-10。状态：定向功能验证与标准手机视觉审查通过。证据目录：`output/aim-assist-fix-20260910/`。

## 范围与根因

- 2D/3D角度训练：TrainingAssist.aimLine 原为65%青蓝，现为白色；保留延伸到库边。
- 辅助球杆：旧实现只在3D启用并每帧读取相机yaw；现由辅助开启/刷新沿母球→假想球摆杆，两种模式一致。关闭、结果、换题仍清理。
- 假想球：标准直径57.15mm，模型球实测约56.8–57.5mm。保留物理尺寸及2R相切位置，不透明度32%→50%使轮廓更明确。3D透视下远球自然显得更小，不按屏幕尺寸强制放大。
- 2D/3D瞄准点训练：用户线与共享特写均跟随白色Token；提交参考线改白虚线，保留青蓝瞄准点/橙黄接触点。

## 相关页面检查

| 消费方 | 核对结果 | 处理 |
|---|---|---|
| 2D/3D角度训练 | 专用蓝线、3D相机绑杆、2D缺杆 | 修正并回归 |
| 2D/3D瞄准点训练 | 专用蓝线；球杆已沿用户aim | 修正线及参考线，保留杆方向逻辑 |
| BTAimCloseupHUD | 训练snapshot复用蓝线Token；球/假想圈同ballRadius | Token同步，尺寸不变 |
| 角度与瞄准、教学图 | 默认aimColor白色，默认假想圈标准R | 无同类专用配色问题，保留 |
| 翻袋/反射解球器 | aimColor白色；杆用用户aim/求解方向 | 源码未见相机绑杆，保留 |
| 自由击球/自由走位/打三/斯诺克 | 共享TrajectoryRenderer及预测击球方向；默认标准R圈 | 源码未见同类绑定，保留 |
| Drill静帧/回放 | 标准白线；静帧放大时球和假想球同倍缩放 | 保留 |

上述相关页区分源码检查与真实UI覆盖，不声称已跑遍所有入口。

## 验证轨迹

- before-raw.log：独立17Pro/iOS26.2、large字号；辅助开关双模式流程通过。独立3D测试点击后仍显示“辅助”，失败与截图保留；未以失败图证明辅助生效。
- model-probe.swift/log：复用TableModelLoader的独立macOS SceneKit读取，因平台CGFloat类型做适配，仅测量工具；未改模型资产。
- after-raw.log：同仓另一会话正在改的AimPointTheoryScanTests出现编译错误；其后该会话已修复，重新启动r2；本任务未修改该文件。
- after-r2-raw.log：真实display-link的球杆方向/显隐/换题回归通过。尺寸检测因隐藏父节点包围盒为0失败，改直接网格顶点测量；两条瞄准点UI误找不存在的“下一题”，按产品自动下一题流程修正。失败原记录保留。

## 验证边界

未提交、推送或发布；不宣称真机手感、iPad、完整VoiceOver及全场景矩阵通过。无球桌模型/物理引擎/相机姿态曲线修改。

## 最终功能验证

- 2项单测（after-r3-raw.log，TEST SUCCEEDED）：真实display-link持续帧、横向/纵向相机变化、3种模式与辅助显隐/换题；全部16模型球网格尺寸与标准假想球误差≤0.5mm、白线材质、标准直球延伸库边与2R位置。
- 4项UI通过：r2的testAngleAssistRailExtension（2D+3D开启/关闭）与testTrainingAssist3D（转动前后/隐藏）；r3的testAimPointTrainingMarkers2D/3D（瞄准/调整/提交/自动进入下一题）。r2中未通过的另外测试不计入；r3修正测试测量/流程后重新通过。
- 独立模拟器：QiuJi-AimAssist-QA，iPhone17Pro/iOS26.2，UDID D7BBB7B7-E13F-4FE8-B562-65378258C552；large字号。球桌页面使用实际强制黑色背景，未声称浅/深双矩阵。
- 定向git diff --check、verify-doc-size通过。生产文件r2至r3指纹不变；本任务增量patch与基线快照已保留，原有未提交工作未回退。

## 最终视觉审查

已打开原图检查：
- `after-2d.png`：白实线延伸至库边，木杆在母球后沿同一直线，假想球轮廓与相邻目标球尺寸一致；球库/辅助/答题保持原布局。
- `after-3d.png` / `after-3d-rotated.png`：同一道题改变视角，杆与白线保持共线；假想球半透明边界清楚、没有额外放大；两个标记分色仍可辨。
- r3的2D/3D瞄准点训练aiming原图：用户白线与木杆同现。
- r3的3D submitted原图：用户白实线与正确参考白虚线可区分。2D submitted截图已经进入后续阶段，不能用该帧证明短暂参考虚线；该分支与3D共享绘制函数。
- 相关页中未见本次变更引入布局挤压、标题/操作消失；球杆尾端超出台面/视口是完整物理长度投影，未为容纳全杆缩小球桌。

代表图：
[2D角度训练](../../output/aim-assist-fix-20260910/after-2d.png) · [3D辅助](../../output/aim-assist-fix-20260910/after-3d.png) · [3D转动后](../../output/aim-assist-fix-20260910/after-3d-rotated.png)

最终 `make -f scripts/Makefile build` 在独立DerivedData完成，`build-final.log` 为 **BUILD SUCCEEDED**。系统未安装xcpretty，Makefile自动回退至原始xcodebuild输出；未更改构建脚本。
