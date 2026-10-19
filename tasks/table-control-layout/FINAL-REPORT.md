# 操作布局实施与验证报告

现行返工入口：[v2.1 方案](../TABLE-CONTROL-LAYOUT-PLAN-20261017.md)。R00–R07已验，R08实施中，R09–R10待实施；新版证据见相应R批次实施卡。以下 B 批次结果不计入新版验收。

状态：⚠️ 2026-10-19用户指出需求偏差，整体完成结论撤回（FL-181）。以下保留旧实现测试记录；单按键直接二维移动、连续缩放已分批接入，尚未完成18入口全量收口。

## 使用入口与行为

页面“更多→操作布局”调整当前页；“通用设置→练习显示→操作布局”集中管理。原布局为只读内置模板，可保存本页微调、另存个人模板、显式应用到适用页面或更新共享模板。共享更新先审阅影响范围，其他页面的覆盖项保持；不适用控件保留数据而不强行显示。

共用、2D与3D分层，手机横屏/iPad横屏/iPad竖屏分域；固定视图答题入口保持独立身份。缺少某域时采用该域默认，缩窗不回写保存意图；窗口过小显示扩大窗口提示及返回，放大后恢复。编辑使用独立草稿和预览，保存失败不发布半成品；取消、返回、冲突重载与备份恢复均保留明确边界。

## 全量冒烟覆盖

每个通过单元包含默认→保存个人8pt调整→恢复默认三张原生图，以及实际坐标与业务状态断言。14个可切视图入口本表取2D，4个固定答题入口按各自2D/3D；其他3D与实际业务操作见下方逐批索引。本表不是所有主题、字号、模式和阶段的笛卡尔积。

| 入口 | 标准手机 | iPhone SE | iPad横屏 |
|---|---|---|---|
| 每日清台 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-dailyClearance/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-dailyClearance/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-dailyClearance/test.log) |
| 自由击球 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-freePlay/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-freePlay/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-freePlay/test.log) |
| 击球模拟 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-shotSimulation/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-shotSimulation/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-shotSimulation/test.log) |
| 蛇彩 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-snakePractice/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-snakePractice/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-snakePractice/test.log) |
| 自由走位 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-composer/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-composer/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-composer/test.log) |
| 动作试打 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/phone-retry/landscape-drillTryout/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/small-retry/landscape-drillTryout/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-drillTryout/test.log) |
| 思路训练 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-silu/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-silu/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-silu/test.log) |
| 三球规划 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/phone-retry/landscape-planThree/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/small-retry/landscape-planThree/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-planThree/test.log) |
| 防守 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-snooker/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-snooker/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-snooker/test.log) |
| 翻袋 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-bank/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-bank/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-bank/test.log) |
| 颗星反弹 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-diamond/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-diamond/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-diamond/test.log) |
| 角度瞄准 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-angleDynamic/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-angleDynamic/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-angleDynamic/test.log) |
| 分离角 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-separation/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-separation/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-separation/test.log) |
| 加塞吃库 | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-cushion/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-cushion/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-cushion/test.log) |
| 角度答题2D | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/phone/landscape-anglequiz2d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r01/small/landscape-anglequiz2d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-anglequiz2d/test.log) |
| 角度答题3D | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/phone-retry/landscape-anglequiz3d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/small-quiz/landscape-anglequiz3d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-anglequiz3d/test.log) |
| 瞄点答题2D | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/phone-retry/landscape-aimpoint2d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/small-quiz/landscape-aimpoint2d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-aimpoint2d/test.log) |
| 瞄点答题3D | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/phone-retry/landscape-aimpoint3d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B11/r02/small-quiz/landscape-aimpoint3d/test.log) | [通过·已审图](/Users/song/projects/13.billiard_trainer/output/table-control-layout-20261017/B12/r01/pad/landscape-aimpoint3d/test.log) |

## 组合、外围与存储证据

- B03–B05：每日清台、自由击球、思路训练的编辑/共享/管理完整链、计时与返回、窄窗、手机与iPad代表。
- B06–B08：其余击球、规划与教学入口；2D/3D真实操作、共享链、忙碌状态、原生面板与控件触点。
- B09–B10：固定2D/3D角度及瞄点答题；输入、提交/结果、下一题、配额、背景/返回；共享链、相机换侧、瞄点尺条移动与真实特写持触录像。
- B11：36手机单元108节点；SE浅色/XXXL管理4节点；既有偏好2条实际测试5张图；详情嵌入与返回3节点。40条成功记录的连续视频完整性已核。
- B12：iPad横屏18入口54节点、五族竖屏15节点、两答题宿主旋转/实际缩窗恢复10节点、每日清台实际缩窗恢复3节点，共26条UI测试82节点通过并审图；26段连续录像完整。窗口改变前后归档修订、场景/题目身份不变，缺少方向配置回默认，恢复后个人偏移仍在。
- 外围：详情播放运行时已验；记录嵌入、文章/图解、照片校正、内部编排与离屏输出为生产消费源核查，无布局存储读取。未执行相册写回和整库出片，不将源核查写成全页UI实测。
- 存储/布局纯值33项：层优先级、设备方向及入口隔离、控件能力变化、原子保存/删除、冲突、坏/未来版本原件备份、真实文件读回、写失败不发布、窄窗临时回退与计时。日志B11/r02/pure-tests.log。

## 失败与边界

B10测量把方向列空白计入实际控件，FL-179已修复并以手机横屏/iPad竖屏真实移动与特写录像闭环。B11试打诊断identifier被权限容器继承，测试改按语义值定位，保留真实权限路径。B11磁盘耗尽导致保存等待/附件失败与主动中断，同产品代码补跑通过；所有失败轮次与空间处理记录保留。

真实VoiceOver、真机握持/触觉与用户视觉认可仍待人工验收；构建/模拟器不等于这些验收或发布。模板仅本机保存，跨设备同步、导入导出、任意缩放及历史版本浏览属于后置增强。

## 最终检查

B11/r02测试构建成功，33项纯值/存储测试零失败；B12/r01的verify-gate、verify-doc-size及git diff --check通过。11项布局生产文件与冻结构建源码哈希一致；最终手机/iPad矩阵共54入口单元162节点，另有设置、旧偏好、嵌入、旋转与窗口恢复专项。B09/B10原生定向测试分别28/21项通过，详见批次卡。同期其他工作区改动不纳入本任务完成声明；未提交、push、安装真机或发布。

## 入口索引

[使用说明](USER-GUIDE.md) · [最终人工验收](FINAL-HUMAN-ACCEPTANCE.md) · [B11](B11-PHONE-MATRIX.md) · [B12](B12-PAD-CLOSURE.md) · [完整方案](../TABLE-CONTROL-LAYOUT-PLAN-20261017.md)
