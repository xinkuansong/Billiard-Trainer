# 六个练习入口接入可行打点区域（2026-10-25）

用户要求：2D/3D准度、2D/3D分离角、2D/3D两球走位全部接入之前使用的可行打点区域。

## 诊断与范围

准度已沿BTTeachingTablePage→BTSceneSpinPadOverlay接入scene.cueAccessSnapshot，且updateSpin再次按逐轴权限及可行域约束。分离角/两球走位显式传defersStrikeAccessUntilSubmission=true，导致浮层strikeAccess=nil，灰色区域和盘面/微调/回中约束均旁路。两页提交时仍校验可行性，但不能替代选点时的反馈。

本轮仅接入共用可行域：三类页面采用即时打点约束（准度沿用默认false，另外两页显式false），正式2D/3D共享。准度保留逐轴/全锁权限；其接线本来有效，纳入复核。沿当前场景杆向/球位/球杆轮廓更新，不新增连续进球求解。分离角和两球走位提交时仍按补偿后的真实方向最终校验；选择区域不是进球保证。共用30°可达上限与物理仰角差异不在本次界面接线范围内，不声称已修复该物理问题。

## 规范增量

沿各页已有完整检查表：TP11继承共用灰色不可选区、拖动/轻点/微调/回中约束；TP12继承面板大小/透明度；TP13/15保留提交最终守卫与既有异步节奏；TP16/25/26/30继承二维/三维、换题、重试、回放和恢复时scene快照更新；TP33保留准度逐轴权限与成绩规则。TP35/36记录本轮证据。未改布局、题库、轨迹或评分。

## 验证

run `1b215ae67e004bf99b2f04f95d836a9e`，`evidence/before`保存接线前源码与SHA。使用受管SE3/Pad覆盖局部变更，不启动整页全尺寸矩阵。构建、10项单元/集成及5项UI通过，覆盖六入口；原图已审，iPad竖屏提示布局仍开放；真机未验。

改前构建通过。SE改前分离角综合UI通过；两球综合UI在移动主按钮后的提交等待result超时，发生在本轮源码修改前，打点面板/透明度/微调/回中步骤已通过。保留before.xcresult，不把该旧用例算作通过；本轮另用不移动布局的打点定向流程验证。共享工作区另有HUD精简变更，本轮保留该变更，before/after的HUD差异不归因于打点接线。

### 已完成的功能验证

- 最终build-for-testing通过（arm64 Simulator）；10项单元/集成通过，见`after-pad.log`。覆盖贴库/沿库方向差异、后方球遮挡、30°既有可达模型、约束投影与回中、瞄准/出杆接触一致、准度逐轴权限及实际物理/重打。
- 2D/3D分离角各1项、2D/3D两球走位各1项定向UI通过：盘面低点、四向微调、回中、提交、重试、临时击球/回放停止、后台恢复、退出重入、再次提交及下一题。结果检查实际inputAccessible及题身份/输入保持，不仅查按钮存在。
- 两球在iPad mini竖屏、分离角在SE3；系统iOS26.3.1。两球采用自由走位验证共同打点入口，轨迹模式未另跑本轮UI；代码为同一controls，无分支。
- 两球本轮固定首题允许低杆到-0.5，不误判为必须出现灰区；灰区的贴库视觉反例使用生产BTSpinPadCard与真实CueStrikeAccess夹具（`restricted-spin-pad`），属于组件证据，不冒充六页均命中贴库题。

### 原生视觉与开放问题

已打开iPad两球2D/3D低点、恢复与换题原图，打点盘、方向键、读数/回中完整。组件贴库原图可见下部灰色限制区。iPad竖屏的目标袋/结果提示挤成逐字竖列：属于当前共享HUD/信息布局开放缺陷，本轮未改该布局，不能声称整页视觉通过。相关图为`after-pad-attachments/8235C0BC-323A-478E-BCF4-0D0E8DFD5ABF.png`、`6EB3C851-8246-438D-B0C1-79622AEE2777.png`。保留并转入页面卡待后续HUD复验，不覆盖正在进行的信息精简工作。

`verify-gate`在ControlLayoutLibrary的route-coverage.csv第87行既有source声明缺项失败；其余前置内容、双端Schema及术语检查通过。未为本轮更新全局基线。真机、VoiceOver、完整跨尺寸/全App回归、物理仰角一致性均未验收；未提交、推送或发布。

### 最终收尾

准度`testAccuracySpinMutualExclusionAndShotControls`通过，单用例实际覆盖2D/3D双模式的双轴编辑、逐轴互斥、锁轴、回中、真实击球与重打。最终总计10项单元/集成＋5项UI，0失败/0跳过（不含已明确保留的改前综合用例失败）。SE手机`after-phone.log`为3项UI，iPad`after-pad.log`为10项逻辑＋2项UI。

已目视SE分离角双模式展开低点及准度双模式编辑/锁轴原图，打点盘未见裁切/文字缺失。iPad原图结论如上，不将功能通过等同整页视觉通过。改前后HUD有其他在途任务的精简差异，网格有测试保留偏好差异，不做整屏像素等价声明。

证据目录：[本轮受管证据](../../output/local-test-runs/1b215ae67e004bf99b2f04f95d836a9e/evidence/)。代表原图：[分离角2D](../../output/local-test-runs/1b215ae67e004bf99b2f04f95d836a9e/evidence/after-phone-attachments/C3C88CCC-DF87-4697-AD5C-13167144F173.png)、[准度3D锁轴](../../output/local-test-runs/1b215ae67e004bf99b2f04f95d836a9e/evidence/after-phone-attachments/0BA3E92F-F4F1-4FBF-9356-7CC0C906EAC5.png)、[共享贴库灰区夹具](../../output/local-test-runs/1b215ae67e004bf99b2f04f95d836a9e/evidence/after-pad-attachments/02832579-70B1-4186-A54B-B3962F1B4147.png)。

本轮生产增量仅两处defer=false；两个VM的inputAccessible为DEBUG只读诊断，两个UITest文件增加4项生命周期回归。准度View、BTSpinPad、BTTeachingTablePage与本轮before字节一致。最终source SHA见after-source.json；保留其他工作区修改。进度文档临近100KB，已原文归档09-24至09-25每日交互旧段，不提升门禁阈值。
