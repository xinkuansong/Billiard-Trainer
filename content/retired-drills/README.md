# 暂时下架的动作（2026-08-26）

用户裁定：这 10 课暂时从 App **完全消失**（动作库 + 官方计划都不出现）。
内容留在本目录，**不进 Bundle**。序列仍在 `content/position_play/sequences/`（本来就不进包）。
精讲 PNG 母版仍在 `QiuJi/Resources/DrillTutorials/`（按 FL-031 本就不进包）。

c055 翻袋入中袋 **留下**。

## 名单

| id | 课名 |
|---|---|
| drill_c006 | 握杆稳定性 |
| drill_c007 | 站位与身体对齐 |
| drill_c008 | 八种手架 |
| drill_c043 | 高级手架 |
| drill_c002 | 斜角入底袋 |
| drill_c061 | 解球（逆境球） |
| drill_c066 | 开球训练（中式台球） |
| drill_c067 | 九球顺序清台 |
| drill_c062 | 远台中袋直线 |
| drill_c059 | 跳球基础 |

## 恢复

1. 把 `Drills/` 下 JSON 移回 `QiuJi/Resources/Drills/<category>/`。
2. 缩略图 / 盘面 / HEIC 移回对应 `QiuJi/Resources/` 目录。
3. 写回 `Drills/index.json`。
4. 按当时课表把官方计划引用加回去，并同步 v38 §3 / v39 §5。
5. `make tutorial-figures`（若 HEIC 清单需重生）→ `make verify-gate`。
