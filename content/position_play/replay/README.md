# 序列回放兼容数据

2026-10-15：按用户决定撤除实验性的持久化 trajectory。

2026-10-15 后续裁定：`legacy-directions.json` 及其包内副本已撤除。回放统一由 `before`（连续接续使用已停稳的实际球位）与击球参数调用当前引擎，不再绑定历史文件名、SHA256 或杆 ID。移除全局旧方向注册表，避免一份旧绑定失效阻断其他球形。

`legacy-trajectories.json`、轨迹采样模型、录制写入、回放/导出的采样消费和旧引擎轨迹生成工具已删除。编排源与 Bundle 中的 `steps[].trajectory` 已清除。旧 JSON 的同名未知字段可被忽略，不会再次保存。

录制流程：`before` + 击球参数 → 当前引擎 → 播放 → 击球完成后保存 `after` 与进袋结果。当前运行时轨迹计算及辅助线继续保留。

本次备份和验证：`output/trajectory-removal-20261015/`；任务：`tasks/TRAJECTORY-REMOVAL-20261015.md`。历史轨迹实验记录不再代表当前实现。

旧方向清理任务：`tasks/CURRENT-ENGINE-REPLAY-20261015.md`；备份及验证：`output/current-engine-replay-20261015/`。
