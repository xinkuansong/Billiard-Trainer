# 每日清台统一手动开球 — 2026-09-28

用户要求所有开局先允许调整母球位置、方向、力度、打点，再主动击球。

## 实现

- 新草稿默认manualRacked；首次进入、再来一局复用手动摆架流程。
- 开球宿主移除automaticallyStrike参数与自动breakNow调用，只配置手动开球、手动停稳交付；默认8 m/s可调。
- 旧autoBreaking草稿保留原种子和规则版本，迁移并持久化为manualRacked。
- 移除V1终局球进袋后的自动重试；正常进行中草稿和历史完成记录保留。
- 新开球统一按玩家开球裁决，沿用手动开球计入上手次数的口径。
- 保留autoBreaking枚举、automaticRetryCount存档字段和历史系统开球完成类型以兼容旧数据。

## 验证

专用iPhone 17 Pro / iOS26.3模拟器：FDC7C3EA-FC82-4320-A96C-13C63226438F。

- [最终单元与UI日志](../build/daily-manual-break-20260928/final.log)：50项单元/场景（控制器18、规则27、存储5）+5项UI，0失败，TEST SUCCEEDED。
- [恢复UI日志](../build/daily-manual-break-20260928/restore.log)：1项UI，0失败。
- 控制器覆盖五玩法待开球、旧自动草稿迁移、旧终局球不重试、重开、完成后再来一局、正常球形恢复；实际PositionPlay宿主验证racked、母球可拖、力度/打点/方向可调整且未发起击球。
- UI覆盖首次页面力度与高杆调整、九球待开球、完成后再来一局、真实2D/3D手动击球与停稳确认、3D待开球重启恢复。共6项。
- 已目视检查首次调整后、再来一局待开球、3D停稳确认、2D交付后、3D恢复待开球等[截图](../build/daily-manual-break-20260928/screenshots)。
- [全仓门禁](../build/daily-manual-break-20260928/gate.log)通过；git diff --check通过。

## 验证边界

未做真机手感、iPad/小屏/旧系统矩阵及全量测试；未提交、未发布。保留工作区已有的其他修改。未改变共享开球物理和手动控件交互。
