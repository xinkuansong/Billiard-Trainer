# 翻袋解球轨迹保留 · 原生复核

范围：用户提供的翻袋解球求解态反馈，仅影响TP13/22/24/25/29/30/35；继承P07布局及字体、透明HUD、球库、按钮合同。

r3：iPhone16ProMax / iOS26.2，正式「解→翻袋解球」入口；2D与3D均执行击球、上一杆回放和重打。UI用例通过，12张附件已导出；已直接查看两种视图的strike-2及replay四张原图：页面为“击球中”，球已离开原位，两球预测路线仍完整留在台上，未因触球消失。2D/3D颜色与虚实线沿原组件，未新增底板或更改字号。

证据：`output/bank-trajectory-recontact-20261103/r3-analysis/attachments/manifest.json`。本轮实时SCNView逻辑测试同时验证全部原路线节点在触球后及300ms后仍有父节点、未隐藏，并覆盖停止、自然结束、重打与回放返回。

用户原图保存在专项证据根目录，证明反馈页面及目标显示；没有恢复用户原盘面的精确坐标，不将新测试盘面当同球形前后对照。r3完整测试因两项用例失败而不算整体通过；原因及r4复验见[任务卡](../table-page-adaptation/BANK-TRAJECTORY-RECONTACT-20261103.md)。

本轮不涉及页面布局迁移，未重跑iPad、多窗口、VoiceOver、全App或真机；用户认可尚待反馈。最终r4复验结果如下。


## r4最终复验

同设备类型与系统，构建及14项测试零失败零跳过。已导出12张原图并直接查看2D/3D击球第2秒及回放四张，均为“击球中”，移动后的球与持续显示的母球白线、目标球黑虚线可同时确认；未发现本次保留轨迹引入的遮挡或样式变化。

原图位于`output/bank-trajectory-recontact-20261103/r4-analysis/attachments/`，manifest保留状态与文件映射：2D strike-2=`6FFF98B1-3DB0-4EDF-A0ED-73F1F2AEB24B.png`；3D strike-2=`54C4F06A-D169-4671-9F56-0B79683B581A.png`；2D replay=`5AC4097F-DADB-4B4F-954D-2463EDCBEFD5.png`；3D replay=`29F55BCA-B4A5-486E-A1A1-C64193EDF734.png`。

结论限r4冻结快照及上述定向状态。并行颗星改动后的整体工作区未复验，真机/iPad/VoiceOver/全App与用户认可未完成。
