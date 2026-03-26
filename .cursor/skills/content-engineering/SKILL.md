# Content Engineering Skill

## 触发场景

在以下情况读取并遵循本技能：
- 生成 Drill JSON 内容文件
- 定义或调整 Drill JSON Schema
- 生成官方训练计划 JSON
- 验证内容数据合理性

## 坐标系协议

> 完整物理参数见 `.kiro/steering/table-geometry.md`。

### Canvas 归一化坐标（Drill JSON 使用）

- **原点**：台面左上角（顶视图，上侧为 +Z 方向）
- **X 轴**：从左到右（0.0 = 左边库，1.0 = 右边库）
- **Y 轴**：从上到下（0.0 = 上边库，0.5 = 下边库）
- **单位**：台面**长度**（innerLength = 2.540 m）的百分比
- **宽高比**：2:1（width × 0.5 = height）

### 从 SceneKit 物理坐标转换

```
canvasX = (sceneKitX + 1.270) / 2.540
canvasY = (0.635 − sceneKitZ) / 2.540
```

示例：
- 球桌中心 SceneKit (0, 0) → Canvas (0.5, 0.25)
- 右下角袋 SceneKit (+1.312, −0.677) → Canvas (1.0165, 0.5165)
- 上中袋 SceneKit (0, +0.688) → Canvas (0.5, −0.0268)

### 有效击球区范围

JSON 中母球和目标球初始位置**必须**在以下范围内（不含库边）：

```
X ∈ [0.0197, 0.9803]   （库边宽 0.0197 = 0.050/2.540）
Y ∈ [0.0099, 0.4901]   （库边高 = 0.050/2.540 × 0.5）
```

### 袋口参考坐标（用于路径终点校验）

| 袋口 | canvasX | canvasY | 类型 |
|------|---------|---------|------|
| 左上角袋 | −0.0165 | −0.0165 | corner |
| 右上角袋 | +1.0165 | −0.0165 | corner |
| 左下角袋 | −0.0165 | +0.5165 | corner |
| 右下角袋 | +1.0165 | +0.5165 | corner |
| 上中袋   | 0.5     | −0.0268 | side |
| 下中袋   | 0.5     | +0.5268 | side |

### 坐标自检规则（JSON 生成后必须验证）

```
母球 start: X ∈ [0.05, 0.95], Y ∈ [0.05, 0.45]
目标球 start: 同上，且与母球距离 > 0.05
路径终点距指定袋口中心 < 0.03（容差）
两球不重叠：distance(cueBall, targetBall) > ballRadius × 2 = 0.0225
```

## 完整 Drill JSON Schema

```json
{
  "id": "drill_c001",
  "nameZh": "半台直线球（中式台球）",
  "nameEn": "Half-Table Straight Shot",
  "category": "accuracy",
  "subcategory": "straight",
  "ballType": ["chinese8"],
  "level": "L0",
  "difficulty": 1,
  "isPremium": false,
  "description": "将目标球从半台距离沿直线打入底角袋，训练基础瞄准稳定性与跟杆控制。",
  "coachingPoints": [
    "保持出杆方向与瞄准线一致",
    "发力均匀，避免急停杆"
  ],
  "standardCriteria": "15球进10球",
  "sets": {
    "defaultSets": 3,
    "defaultBallsPerSet": 15
  },
  "animation": {
    "cueBall": {
      "start": {"x": 0.5, "y": 0.25},
      "path": [
        {"x": 0.5, "y": 0.47}
      ]
    },
    "targetBall": {
      "start": {"x": 0.5, "y": 0.43},
      "path": [
        {"x": 0.5, "y": 0.5}
      ]
    },
    "pocket": "bottomCenter",
    "cueDirection": {"x": 0.5, "y": 0.0}
  }
}
```

### `animation.path` 格式

- **直线**：一个终点坐标 `[{"x": 0.5, "y": 0.5}]`
- **曲线（加塞/库）**：使用贝塞尔控制点：
  ```json
  [{"x": 0.3, "y": 0.4, "cp1": {"x": 0.2, "y": 0.3}, "cp2": {"x": 0.25, "y": 0.42}}]
  ```
- **多段路径（走位）**：多个点，渲染器按顺序动画
  ```json
  [{"x": 0.3, "y": 0.47}, {"x": 0.7, "y": 0.3}]
  ```

## 8大类分类表

| category | nameZh | 典型 Drill |
|----------|--------|-----------|
| `fundamentals` | 基础功 | 站架、握杆、瞄准线 |
| `accuracy` | 准度训练 | 直线球、五分点、角度入袋 |
| `cueAction` | 杆法训练 | 高杆、低杆、斯登、加塞 |
| `separation` | 分离角 | 分离角控制、薄球分离 |
| `positioning` | 走位训练 | 一库走位、多库走位 |
| `forceControl` | 控力训练 | 强力高杆、软打控位 |
| `specialShots` | 特殊球路 | 斯诺克防守（defer）、飞杆、贴库球 |
| `combined` | 综合球形 | 连打、Ghost Game、清台练习 |

## 分批生产 SOP

### 每批流程（10个 Drill / 批）

1. **准备**：确认本批次覆盖的 category 和 level 范围，对照 `docs/research/20260323-训练内容体系-动作库分类.md`。
2. **生成**：按 Schema 生成 10 条 JSON，坐标自检（见下方验证规则）。
3. **isPremium 验证**：按 `docs/08` Freemium 比例分配（L0 全免费，L1 约 30% 付费）。
4. **写入**：`Resources/Drills/<category>/drill_xxx.json`（`xxx` 为三位数序号）。
5. **更新索引**：`Resources/Drills/index.json`。
6. **标记 H-11**：在 `tasks/HUMAN-REQUIRED.md` 更新 H-11 状态为 `⏳`，等待台球专业内容审核。

### 坐标自检规则

- 母球（cueBall）`start`：`x ∈ [0.05, 0.95]`，`y ∈ [0.05, 0.45]`
- 目标球（targetBall）`start`：同上，且与母球距离 > `0.05`
- 路径终点：击球袋口坐标偏差 < `0.02`

## Freemium 分配目标

| Level | 免费比例 | 付费比例 |
|-------|---------|---------|
| L0 | 100% | 0% |
| L1 | ~70% | ~30% |
| L2 | ~40% | ~60% |
| L3 | ~20% | ~80% |
| L4 | ~10% | ~90% |

## 官方训练计划生产要点

- 6套计划 ID：`plan_beginner` / `plan_cueball` / `plan_positioning` / `plan_intermediate` / `plan_advanced` / `plan_fullskill`
- 每套计划的 `drillId` 必须已存在于 `index.json`（不能引用不存在的 Drill）
- `isPremium: false` 仅限前两套（`plan_beginner`、`plan_cueball`），其余为付费
