# v73.8 轨迹标准返工与验证

2026-11-27，FL-294 / DR-476 r3。用户授权按统一轨迹标准修订。

## 已修改

- 将“扎杆与跳球”自由页现有首碰分段及球色逻辑提取为 `SpatialShotRendering.segments/appendBallRoute`，自由页、扎杆练习、跳球练习共同消费。
- 母球首次碰球前白色实线，之后白色虚线；目标球及其他被带动球使用本色虚线。主线半径0.0028m，虚线20mm实段/12mm间隔，均来自 `TrajectoryStyle`。不运动的球不生成轨迹。
- 两个答题页在已提交的真实物理记录、球位和参考杆姿、示范相机就绪后，先显示轨迹，再启动出杆。出杆、滚动和停稳均可见；重打保留上杆，换题清空。示范和回放使用当前播放杆，退出恢复玩家记录。
- 复用原三维路径、贴台/空中renderer、首碰时间及显示档位。自由页无首碰时保持原全实线规则；未提交新题不提前显示参考答案。技术规则、题库、相机和手势算法不变。

## 逻辑与集成

受管run：`4bdb131990b6471984ad7fca4523b673`；原始日志、JUnit及xcresult在 `output/local-test-runs/<run>/evidence/`。

- 初轮 `test-results`：36项，2处失败，均位于原示范相机测试的第一人称进入断言。另6个选择器误用了 `SpatialPracticeTests` 类名，实际未执行，不计通过。原失败日志保留。
- 修订示范测试为题库首题固定样本，避免把随机落点都当作第一人称可进入的测试前提；生产相机逻辑未改。测试仍覆盖第一/第三人称、侧看缩放、示范同步复位、取消与恢复。
- `unit-r1`：52/52通过，0失败：SpatialPracticePreviewTests 16、SpatialQuizIntegrationTests 11、SpatialQuizTests 25。新增测试直接读取真实网格端点，验证20/12mm虚线、实虚分界及多球颜色，并在没有renderer ticks时验证玩家杆和示范杆已显示两种线型。
- `verify-gate.log`：通过。

## 原生页面

- 标准手机首次UI启动失败：测试runner被SpringBoard以Busy拒绝，页面方法未执行。保留 `ui-standard.log/xcresult`；确认bootstatus后原条件重跑。
- `ui-standard-r1`：iPhone17Pro / iOS26.3.1，2/2方法通过、0失败（238.866s），每个均覆盖扎杆/跳球。实际显示106.319s，示范/回放/重打132.547s。
- 已目视标准手机扎杆结果图：白色实线在首次碰球处分界为白色虚线，14号球绿色虚线通向袋口；跳球播放图：白色实线跨过黑八上方，首碰后白色虚线及2号球蓝色虚线，出杆阶段已可见。实际图见下方。
- `ui-compact`：iPhoneSE3 / iOS17，1/1方法通过、0失败（96.895s），覆盖双模式设置、播放、结果、重打和换题。已目视小屏扎杆结果与跳球播放原图，实/虚分界及目标本色虚线成立。
- 两设备共3次UI方法执行、2个不同方法；加上52项逻辑/集成，不把重复执行计作不同测试。`git diff --check`通过，测试后6个源码文件SHA与`tested-source.json`一致。
- 资源收尾：已通过local_test_lifecycle complete关闭本轮run，实查state=reclaimed、work目录已删除；日志、xcresult、原生图和源码哈希保留，核心模拟器数据保留。

[扎杆结果原生图](ui-standard-images/massePractice-actual-routes-result.png) · [跳球出杆原生图](ui-standard-images/jumpPractice-actual-routes-playing.png)

改前相同benchmark题图保留在 `../feedback-r4/ui-standard-images/`，可对比原全实线和修订后的实/虚分段。

## 边界

本轮不声称全App、真机手感或用户最终验收。`before/`、`before.json`保留开工源码；`changes.diff`只表示本轮局部差异；`tested-source-initial.json`及`tested-source.json`区分初轮和修订测试源。
