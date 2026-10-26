# 多球设置行距修复（2026-10-26，FL-209）

用户提供同设备的参考训练设置与2D多球截图，指出选项间距明显过大；批准按参考页优化。

## 改动与基线

- `MultiBallSettingsView` 容器由List改为与`SceneTrainingSettings`一致的Form。
- `choice`移除内容层`minHeight:44`及plain Button样式；由原生Form管理行高、留白和命中，保留contentShape及单选AX状态。
- 作用于2D/3D、顺序4/5/6/9、中八己方4–8及对手0/随机。文字、分组顺序、练习模式、Pro/每日额度及抽题逻辑保持。
- before为用户真实截图，已保存在`output/multi-ball-spacing-20261026/before-user.png`；参考页在同目录`reference-user.png`。不将此前“可点击/无截断”判定继续当成本轮行距认可。

## 验证状态

构建成功。iPhone13/iOS26.3.1现有3项UI通过：顺序球数选择/重开/取消，中八己方/对手球及重新进入设置，3D设置/临时俯视/布局取消。iPhone SE3/iOS17的中八选项与滚动流程1项通过；复用本轮构建产品，没有改写测试。日志及截图在`output/multi-ball-spacing-20261026`与受管run `fbb584e60b264da2ab6c62c54b0145c8`。

原生AX行高：同一iPhone13的顺序9球选项，旧phone-r4为74pt，本轮52.333pt，收紧29.28%；中八相同；SE3为44pt。原始日志行保存在`row-measurements.json`。最终行维持完整点击范围，既有用例的行中心点击及选中状态断言通过。

视觉审查：已打开同尺寸同选择的旧/new `01-rotation-settings`原图对比，并核本轮浅色2D/3D、深色中八、SE浅色顺序/深色中八。球数行收紧，文字、勾选、分隔线对齐；标准手机练习说明上移完整显示，小屏中八可滚动至对手选项。用户提供截图和旧模拟器图均保留为before。浅色预览：`phone-light/multiBall-light.png`、`phone-light/multiBall3D-light.png`。

`git diff --check`与`verify-doc-size`通过；仅刷新本轮已测设置源对应的路由签名（随后标题修订由其所属任务继续更新），未将本轮定向结果声称为全仓门禁或全量回归通过。参考页/测试源SHA无漂移。收尾时发现工作区另一处修改将本页标题改为“训练设置”；仅还原此标题字符串后SHA与测试源完全一致，确认间距实现未变。保留该并行修改，本轮截图标题为调整前，不冒称已验证最新标题。汇总见`summary.json`。

资源收尾：两台模拟器均已Shutdown，本轮租约已归还；受管工作区已reclaimed，实际释放1,665,871,872字节，日志/截图/xcresult保留。

本轮仅复核设置行布局和受影响交互；物理、题库、权益规则不重复计数。真机、VoiceOver及大字号未专项验证，不以模拟器截图代替用户认可。未提交、推送或发布。
