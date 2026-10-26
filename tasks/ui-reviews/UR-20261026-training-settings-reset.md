# 训练设置恢复默认 · DR-435

日期：2026-10-26。范围：2D/3D角度、瞄准点、准度、分离角、两球走位及蛇彩，共11入口；自定义球形模板管理排除。

## 实现与行为

- 所有适用设置表单底部复用`BTTrainingSettingsResetSection`，点击区域≥44pt，整行可点。
- 点击直接恢复当前页的出厂默认草稿，短暂显示“已恢复默认设置”；开始/重新开始成功后保存，取消保留原设置及当前题目。
- 路由默认值抽到`SceneTrainingConfiguration.defaults(for:)`，首次加载与恢复同源。分离角和两球走位保持各自原有默认角度、杆法；两球默认为轨迹走位。
- 蛇彩编辑时不再立即写入偏好，沿现有开始流程保存；历史记录和模板管理无重置写入。

## 验证

| 范围 | 实际结果 |
| --- | --- |
| 编译 | build-for-testing通过，包含新增共用组件及UI测试 |
| 模型回归 | 27项SnakePracticeTests＋1项配置迁移，共28项通过 |
| SE / iOS26.3 | 10个场景入口逐页修改→恢复→核对→重复恢复通过；两球取消/确认及当前题目保留、蛇彩取消/保存/进程重启、自定义页排除通过 |
| 原生外观 | SE浅色改前/改后、深色恢复提示、横屏重开设置已查看原图；底部动作完整，无遮挡 |
| iPad mini / iOS26.3 | 3项UI通过：浅色截图、两球深色恢复取消/确认、蛇彩深色恢复取消/保存/重启；原图已复核 |
| iPhone16 Pro Max / iOS26.3 | 1项浅色截图测试通过；补做停止滚动后的原生静态复核，说明文字和按钮间距正常 |

前期UI脚本有整屏滚动越过选项、开关坐标误触浮动底栏以及点击标签未切换开关的问题；已按AX树及录屏修正定位，保留全部断言与原失败证据。最终按页面组复验，未把失败轮次列为全绿。过程见[任务卡](../table-page-adaptation/TRAINING-SETTINGS-RESET-20261026.md)。

## 证据

证据目录：`output/training-settings-reset-20261026/`。`before/`为改前；`compact-first-images/`为浅色改后及取消/确认；`compact-final-images/`为准度、角度、瞄准点深色；`trajectory-verified-images/`为四个轨迹入口最终通过原图。每组含xcresult、日志及图片manifest。

- [大手机停止滚动后的最终原图](../../output/training-settings-reset-20261026/large-phone-still.png)
- [SE准度浅色底部](../../output/training-settings-reset-20261026/compact-first-images/AB263D20-721E-4459-9BC3-7C8199A88696.png)
- [SE两球深色底部与短提示](../../output/training-settings-reset-20261026/trajectory-verified-images/C26895DA-81C0-449B-B2C6-38B18A4F6CD4.png)
- [iPad蛇彩深色弹窗](../../output/training-settings-reset-20261026/ipad-images/7565EDCA-27B5-4E02-845E-B908942CA507.png)
- [SE蛇彩横屏重开设置](../../output/training-settings-reset-20261026/compact-first-images/2AA02E41-5C76-4987-BB89-A3C9788E917D.png)

边界：本轮不代表真机、VoiceOver、云同步或发布验收；历史非空记录由模型回归覆盖，UI流程使用未出杆记录状态。未提交、未推送、未发布。

资源收尾：本轮SE、iPad mini、16 Pro Max均已Shutdown且无本轮租约；受管工作目录已回收，释放约2.41GB，日志/xcresult/截图保留。未修改其他任务评审现场。

共享工作区边界：验证期间其他会话继续修改击球反馈、袋口提示等代码；本轮保留这些修改。恢复组件、设置草稿、路由默认值及蛇彩保存逻辑按本报告验收，其他会话的完整功能回归由其自身记录负责。
