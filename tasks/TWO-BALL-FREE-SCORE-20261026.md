# 两球自由走位评分接入 · 2026-10-26

状态：评分已实现并通过验证；最新“只展示最终分”界面修正已通过两项UI回归；未提交/发布，真机待体验。最终用户选择为20°袋距角度＋0.5最低分＋0.5几何平均。完整公式及授权见[评分决策](TWO-BALL-ANGLE-DISTANCE-REVIEW-20261026.md)。

## 范围和接线

`TwoBallShot.init` → `TwoBallComfortScore.evaluateFreePosition` → 冻结comfort/comfortVersion → `freeScore` → 两维度共用ViewModel/记录/最终得分读数。

`TwoBallQuestionPreparer.materialize`与`TwoBallBankStore.load`保留旧版evaluate/version；题库来源、加载校验、85筛选和首杆排序均不更换。旧comfort快照继续可读；Attempt新增可缺省的comfortVersion，不要求旧记录迁移。轨迹模式继续原P2。

坐标：SceneKit XZ米、Y上；几何沿现有TwoBallDifficultyMetric.Geometry.source的Float冻结表尺与瞄点。二维横桌+Z向屏幕下，Steering方位文字中的“上侧”不是本轮屏幕契约；不更改几何或物理袋口。

## 保留的球距与空间分

以下距离使用米，与生产一致；题库与新自由评分共用，只有角度及总分组合改变。

- 从目标球沿目标球→袋口瞄点的反方向射到球心矩形边界，得到纵深L；k=clamp(L/0.9,0.4,1)，lo=0.5k、hi=0.8k。d₁为母球与目标球中心距。
- D=100exp(−[max(lo−d₁,0)/(0.8lo)]²−[max(d₁−hi,0)/0.75]²)。
- 四边球面净距gᵢ；tᵢ为母球→假想球方向的反向（杆尾方向）朝该边的非负分量。pᵢ=(45+15tᵢ²)exp(−[max(gᵢ,0)/0.08]^1.2)。
- E=100−pₘₐₓ−min(8,0.25pₐ𝒹ⱼ)，pₐ𝒹ⱼ取最大惩罚边的两条相邻边中较大者。
- 首杆未进指定袋、母球落袋、碰动第二球等失败沿用零分；无正向直击第二杆线路也沿用零分。没有把分数当作可进球或物理可行性证明。

## 检查范围

- 单元/集成：原22停点银行口径、578参考路线、题库/筛选/额度/保存回滚等既有测试；新增原36加权对照、短板D/E、袋距/切角/镜像/退化、正式击球与新旧快照兼容。
- UI：受管iPhone16ProMax/iOS26.3，两球2D和3D自由走位正式流程，核新版本、分数详情公式、重打/回放/下一题。
- 不改布局；不重做全设备矩阵。真机、VoiceOver、云同步与用户实际手感未验证；不发布、不提交。
- 最初纯几何平均构建被用户新决定中止（`output/local-test-runs/21664f189d664899b863fabc090ffaa5`，exit130，未执行测试，不计通过）；其日志保留并已申请收尾。

## 证据

- App构建与测试：`make -f scripts/Makefile sim-test SIM_TASK=two-ball-free-min50-20261026 SIM_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max ONLY_TESTING=QiuJiTests/TwoBallPracticeTests TEST_BUILD_SETTINGS='-only-testing:QiuJiUITests/TwoBallPracticeUITests/test2DFreeFlow -only-testing:QiuJiUITests/TwoBallPracticeUITests/test3DFreeFlow'`。
- [测试结果包](../output/local-test-runs/e9e20a0c5f1341a2a17f75d58b83f855/evidence/tests.xcresult)及[test-results.log](../output/local-test-runs/e9e20a0c5f1341a2a17f75d58b83f855/evidence/test-results.log)：`TEST SUCCEEDED`；25单元/集成＋2UI＝27项，通过27、失败0、跳过0。包含全部578生产参考路线对拍，证明本轮未改变题库评分口径。
- [原生Swift数值对拍](../output/two-ball-free-angle20-20261026/weighted-scorer-probe.log)：36组已审加权结果及D/E最低样本通过，最大误差6.40e-14。
- 历史修前图（用户已否定详情设计）：[2D评分详情](../output/two-ball-free-angle20-20261026/attachments/358D61BA-8015-4F7B-9BBB-0636FA3442A1.png)、[3D评分详情](../output/two-ball-free-angle20-20261026/attachments/0E30954B-C175-4EC8-A512-0C09754E8128.png)：三分项、加权公式与说明完整可读；两个入口该样本均66.8。所有捕获附件与状态在同目录manifest.json。
- [关闭证据](../output/two-ball-free-angle20-20261026/closure.json)：源码和oracle SHA未漂移；16ProMax已Shutdown、无本轮租约；最终成功轮和最初中止轮临时构建均reclaimed，日志/xcresult保留。其他任务设备未操作。
- 验证仅覆盖本次评分与现有流程。真机、iPad/紧凑尺寸、VoiceOver、真实云同步未测；不宣称发布或全App回归完成。

## 最新界面纠正：只展示最终得分（FL-207）

用户否定评分详情弹窗。TwoBallPracticeView删除侧栏得分点击、按钮语义及alert，也删除结果提示detailText。2D/3D共享此入口，旧成绩同样不开放详情；最终分数、均分、失败提示和内部计算保持。历史27项通过证明当时执行结果，不代表该弹窗获得用户认可。新增回归实际点击侧栏与重打结果提示，确认无弹窗、无分项/公式，保留得分与重打/回放/下一题流程。本轮2D/3D各1项UI流程通过（2/2，失败0）；实际点击原侧栏与重打结果提示无弹窗，分项/公式文本均不存在，最终分样本仍66.8。

本轮证据：`output/local-test-runs/2bb03fc2dbf246c0b02a05e3bfaa84cb/evidence/tests.xcresult`；修后截图及摘要在`output/two-ball-free-angle20-20261026/final-only/`。已逐图核2D `57F49800-BE05-4B53-909C-521633F9DDC5.png` 与3D `A27195F3-AAB2-4D0F-A3E9-86A41752F1A6.png`：点击后仍为球桌和最终得分，无详情遮挡。沿用既有字体/布局；3D原场景库边标记经过侧栏附近属于既有背景，未在本轮改变，不据此宣称全页视觉优化。评分及记录源码SHA与上一轮一致。设备Shutdown、临时工作区reclaimed、exit0。真机/iPad/VoiceOver未新增验证，未提交发布。
