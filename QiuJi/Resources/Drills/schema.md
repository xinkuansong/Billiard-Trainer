# Drill JSON Schema

> Canonical reference. All Drill JSON files **must** conform to this schema.
> Kept in sync with `.cursor/skills/content-engineering/SKILL.md`.

## Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `String` | ✅ | Unique ID, e.g. `drill_c001` |
| `nameZh` | `String` | ✅ | Chinese display name |
| `nameEn` | `String` | ✅ | English display name |
| `category` | `String` | ✅ | One of 8 categories (see table below) |
| `subcategory` | `String` | ✅ | Subcategory within the category |
| `ballType` | `[String]` | ✅ | `"chinese8"`, `"nineBall"`, or `"universal"` |
| `level` | `String` | ✅ | `"L0"` – `"L4"` |
| `difficulty` | `Int` | ✅ | 1–5 |
| `isPremium` | `Bool` | ✅ | Freemium gate flag |
| `description` | `String` | ✅ | Teaching description (Chinese) |
| `coachingPoints` | `[String]` | ✅ | Ordered coaching tips |
| `standardCriteria` | `String` | ✅ | Pass criteria, e.g. "15球进10球" |
| `sets` | `DrillSetsConfig` | ✅ | Default practice sets configuration |
| `animation` | `DrillAnimation` | ✅ | Canvas animation data (hand-drawn `manual` or engine-`baked`) |
| `tutorial` | `DrillTutorial?` | ❌ | Detailed coaching tutorial sections |
| `videos` | `[DrillVideo]?` | ❌ | 预留真人示范位，当前无内容；引擎渲染视频已于 v25 下线 |
| `shotIntent` | `ShotIntent?` | ❌ | Physics shot intent (P10, ADR-P10-01). Source of truth for `baked` animations. |

## `DrillSetsConfig`

| Field | Type | Description |
|-------|------|-------------|
| `defaultSets` | `Int` | Recommended set count |
| `defaultBallsPerSet` | `Int` | Balls per set |

## `DrillTutorial`

`sections` 与 `formations` **二选一**（ADR-P12-02）。单球形 Drill 用 `sections` 平铺；多球形 Drill 用 `formations`，每个球形一段相互隔离的精讲，App 用顶部吸顶分段控件切换。旧 Drill 无 `formations`，照常工作。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tutorialKind` | `String` | ✅ | Template kind: `"singleShot"` / `"multiShot"` / `"ruleset"`（v26 W0；路由见 `tutorial-migration` SKILL 决策树） |
| `sections` | `[TutorialSection]?` | ◑ | Ordered tutorial sections (single-formation). 与 `formations` 二选一 |
| `formations` | `[TutorialFormation]?` | ◑ | Multi-formation tutorial (ADR-P12-02). 存在且非空时优先于 `sections` |

### Tutorial templates（三类，标题一字不差）

写作规范真源：`.cursor/skills/tutorial-authoring/SKILL.md`（应用课）与
`.cursor/skills/tutorial-migration/SKILL.md`（单杆技术课 / 规则流程课）。此处只登记骨架。

#### A. 单杆技术课（`tutorialKind: singleShot`）

| # | title | 容器 |
|---|---|---|
| 1 | `技术原理` | `content` 1–2 段 |
| 2 | `动作要领` | `items` 3–5 条（label = 步骤名；可含 `自检`） |
| 3 | `常见错误与纠正` | `items` 2–4 条 |
| 4 | `进阶练习` | `content`（降阶 + 升阶） |

适用：纯身体动作 / 器材操作；0 杆序列（如握杆稳定性）；缺素材临时无图版（须在交付说明标注）。

#### B. 多杆应用课（`tutorialKind: multiShot`）

| # | title | 容器 |
|---|---|---|
| 1 | `技术原理` | `content` 1–2 段 |
| 2 | `开局与击球顺序` | `content` + `image`（须回答「为什么这样排」） |
| 3..N | `第N杆：…` | `items`（`为什么`/`怎么打`/`自检`）+ `params` |
| N+1 | `常见错误与纠正` | `items` |
| N+2 | `进阶练习` | `content` |

适用：有实测击打序列（含多球形、每序列仅 1 杆的形态）。样板：`positioning/drill_c042.json`。

#### C. 规则流程课（`tutorialKind: ruleset`）

| # | title | 容器 |
|---|---|---|
| 1 | `技术原理` | `content`（练什么能力、为何这样设计规则） |
| 2 | `怎么摆` | `content` + 可选 `image` |
| 3 | `怎么计分` | `items`（须给可记录量） |
| 4 | `失败判定` | `items` |
| 5 | `常见错误与纠正` | `items` |
| 6 | `进阶变体` | `content`（加难 + 降难） |

适用：开放式挑战（`combined` + 胜率/局数/清台类达标标准）。⛔ 不得出现「第 N 杆」节。

## `TutorialFormation` (ADR-P12-02)

一个「球形」的隔离精讲（多球形 Drill 用）。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `String` | ✅ | Stable id, e.g. `f1` |
| `title` | `String` | ✅ | Segmented-control label, e.g. "球形 A：薄切走位" |
| `sections` | `[TutorialSection]` | ✅ | This formation's tutorial cards (same shape as single-formation `sections`) |

## `TutorialSection`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | `String` | ✅ | Section heading, e.g. "技术原理" |
| `content` | `String` | ✅ | Section body text (Chinese). May be `""` when `items` carry the content. Supports paragraphs (`\n\n`) and inline markdown (`**bold**`). |
| `image` | `String?` | ❌ | Static poster figure under `Resources/DrillTutorials/<image>.png` (no extension). Tappable → fullscreen viewer (pinch zoom + gallery paging). Naming: see **Tutorial image naming** below. |
| `clip` | `String?` | ❌ | Motion clip (mp4) under `Resources/DrillTutorials/<clip>.mp4` (no extension), ADR-P12-02. Pairs with `image` as the poster — shows a play badge; tap plays a muted loop fullscreen. **选用规则**：讲位置/几何/落点只配 `image`；讲运动/走位/杆法效果再加 `clip`（gif 先转静音循环 mp4）。 |
| `caption` | `String?` | ❌ | Figure caption (small gray text under the image) |
| `items` | `[TutorialItem]?` | ❌ | Structured "label + text" rows (DR-019). Labels `为什么`/`怎么打`/`自检` get accent colors; others render neutral (e.g. mistake names). |
| `params` | `TutorialShotParams?` | ❌ | Shot parameters row for per-shot sections: `{ spinX, spinY, velocity }` (tip offset /R + m/s, same semantics as `ShotIntent`). Rendered as true-scale spin icon + readout + power chip, matching the export HUD. |

Standard section titles:
- Shared: `技术原理`, `常见错误与纠正`
- singleShot: `动作要领`, `进阶练习`
- multiShot (ADR-P11-14): `开局与击球顺序`, `第N杆：…`, `进阶练习`
- ruleset: `怎么摆`, `怎么计分`, `失败判定`, `进阶变体`

### Tutorial image naming（D-v25-6）

磁盘文件名必须与 JSON `image`（无扩展名）一致。回填脚本
`scripts/import-engine-export-to-app.py` 负责把引擎出片名落到约定名：

| 引擎出片 | 落位 `DrillTutorials/` | 说明 |
|---|---|---|
| `initial.png` | `<drillId>_initial.png` | 开局图 |
| `sNN_still.png` | `<drillId>_sNN.png` | **去掉 `_still`**（JSON 写 `_sNN`，不写 `_sNN_still`） |
| `final.png` | `<drillId>_final.png` | 收杆图（可选） |

多序列导出目录带 `__<token>` 时，落位为 `<drillId>_<token>_…`（如
`drill_c077_A3_s01.png`）。

**默认取 `manual01`（c013 / c025 / c026 及同类）**：导出目录 token 为
`manual01` / `manual02` / … 时，精讲若只覆盖**一条**默认序列，JSON `image`
写**无 token 前缀**的形式（`drill_c013_s01`，不是 `drill_c013_manual01_s01`）。
回填脚本对 `manual01` 额外写入无前缀副本；`manual02+` 只保留带 token 的文件名。
校验：`python3 scripts/verify_tutorial_images.py`。

## `DrillVideo`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Stable identifier, e.g. `take_01` |
| `file` | `String` | Filename under `Resources/Videos/<drillId>/`, e.g. `take_01.mp4` |

预留字段：当前 JSON 侧应为 `[]`。引擎渲染视频已于 v25 下线；真人示范恢复时
落位 `QiuJi/Resources/Videos/<drillId>/<file>`，并由归档脚本
`scripts/import-videos-to-app.py`（或后续替代）写入。

## `DrillAnimation`

| Field | Type | Description |
|-------|------|-------------|
| `cueBall` | `BallAnimation` | Cue ball start + path |
| `targetBall` | `BallAnimation` | Target ball start + path |
| `pocket` | `String` | Target pocket ID (see Pocket IDs) |
| `cueDirection` | `Point` | Aiming direction vector |
| `source` | `String?` | `"manual"` (hand-drawn, default) or `"baked"` (engine-generated). Optional; legacy files omit it. |
| `generator` | `String?` | Baker tag for traceability, e.g. `"ShotBaker/engine@v2-geom"`. Present when `source == "baked"`. |

## `BallAnimation`

| Field | Type | Description |
|-------|------|-------------|
| `start` | `Point` | Initial position `{ "x": 0.5, "y": 0.25 }` |
| `path` | `[PathPoint]` | Ordered path points |

## `Point`

| Field | Type | Description |
|-------|------|-------------|
| `x` | `Double` | Canvas X (0.0 = left cushion, 1.0 = right cushion) |
| `y` | `Double` | Canvas Y (0.0 = top cushion, 0.5 = bottom cushion) |

## `PathPoint`

Extends `Point` with optional Bézier control points.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `x` | `Double` | ✅ | End-point X |
| `y` | `Double` | ✅ | End-point Y |
| `cp1` | `Point?` | ❌ | First control point (cubic Bézier) |
| `cp2` | `Point?` | ❌ | Second control point (cubic Bézier) |

### Path formats

- **Straight line**: `[{ "x": 0.5, "y": 0.5 }]`
- **Curve (spin/cushion)**: `[{ "x": 0.3, "y": 0.4, "cp1": { "x": 0.2, "y": 0.3 }, "cp2": { "x": 0.25, "y": 0.42 } }]`
- **Multi-segment (position play)**: `[{ "x": 0.3, "y": 0.47 }, { "x": 0.7, "y": 0.3 }]`

## `ShotIntent` (P10 content pipeline, ADR-P10-01)

Describes a drill as **physics intent** (placements + pocket + spin + continuous power) instead of
hand-drawn result paths. An offline baker (`ShotBaker` → physics engine) turns intent into precise
trajectories and **backfills** them into `animation` (`source: "baked"`). Rendering layer is unchanged.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | `Int` | ✅ | Schema version (currently `1`) |
| `shots` | `[Shot]` | ✅ | One or more shots (most drills = 1; multi-shot drills list several) |

### `Shot`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cue` | `Point` | ✅ | Cue ball placement (normalised, same coordinate system as above) |
| `target` | `Point` | ✅ | Target ball placement (normalised) |
| `pocket` | `String` | ✅ | Target pocket ID (see Pocket IDs below) |
| `velocity` | `Double` | ✅ | **Continuous** cue-tip speed (m/s). Reference anchors: 1.6 / 2.4 / 3.3 / 4.4 / 5.8. Use continuous values for precise position play (not a 5-level enum). |
| `spin` | `Spin?` | ❌ | Cue tip offset. `x`: +left / −right, `y`: +top(follow) / −bottom(draw), ∈[-1,1]. Default {0,0} (centre/stun). |
| `elevation` | `Double?` | ❌ | Cue elevation (radians). Default 0. |
| `obstacles` | `[Point]?` | ❌ | Extra/obstacle balls (normalised). Forward-compatible; the v1 baker does not bake these. |

### `Spin`

| Field | Type | Description |
|-------|------|-------------|
| `x` | `Double` | Horizontal spin, +left / −right, ∈[-1,1] |
| `y` | `Double` | Vertical spin, +top / −bottom, ∈[-1,1] |

### Authoring SOP

1. Author `shotIntent` (placements + pocket + velocity + spin) — **not** the trajectory.
2. Run `DrillBakeRunnerTests` (add the drill id to its pilot list) to bake + validate physical reachability.
3. The console prints the baked `DrillAnimation` JSON (between `===BAKE …===` markers) and a
   reachability report row. Copy the baked `animation` back into the drill JSON (`source: "baked"`).
4. Confirm `feasible == ✅`. A `sim 进选定袋 == ⚠️` row is a P10 jaw-calibration follow-up, not a blocker.

## Multi-Formation Drills & Variable-Coverage Profile（B3 定稿、B4 首用，ADR-P12-03）

> 承载「一个 drill = N 个有覆盖依据的球形」（变量覆盖方法论见
> `docs/research/20260716-drill变量覆盖设计方法论.md`）。**drill JSON 本身不扩字段**。

### 承载结构（三件套）

| 层 | 载体 | 说明 |
|----|------|------|
| 代表性球形 | drill JSON `shotIntent` / `animation` | **语义收窄**：仅承载代表性球形（profile 中 `representative: true`，缺省难度#1），供详情页演示与缩略图。多杆 `shots[]` 仍表示该球形内的击球序列，与多球形正交 |
| 全部球形（可试打/可出片） | `content/position_play/sequences/drill_cNNN__<token>-<名称>-<N>杆.json` → `make tryout-sync` → Bundle `DrillBoards/` | 每球形一条 `PositionPlaySequence`；`<token>` = profile 的球形 ID（如 `A1`，**不得含 `-`**）。仅摆球无示范时 steps 可为空（initial-only），试打序列模式自动降级；示范 steps 由编排台人工录制（⛔ 禁止从存量 shotIntent 反推） |
| 每球形图文精讲 | drill JSON `tutorial.formations`（ADR-P12-02） | `formations[].id` 与 profile 球形 ID 对齐 |

### Variable Profile (sidecar, 机器可读)

路径：`content/drill_profiles/<drillId>.profile.json`（仓库真源，**不进 App Bundle**；消费方 = B5 全库审计与批量重构脚本）。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `drillId` | `String` | ✅ | e.g. `drill_c053` |
| `version` | `Int` | ✅ | Profile schema version（当前 `1`） |
| `methodology` | `String` | ✅ | 变量档案出处文档路径 |
| `fixedVariables` | `{String: String}` | ✅ | 固定变量 → 取值与钉死理由，e.g. `{"pocket": "bottomCenter（中袋主题钉死）"}` |
| `targetVariables` | `[TargetVariable]` | ✅ | 目标变量（全覆盖轴） |
| `conditionVariables` | `[ConditionVariable]` | ✅ | 条件变量（散布采样轴） |
| `formations` | `[FormationProfile]` | ✅ | 逐球形档案，难度序号升序 |

#### `TargetVariable`

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | e.g. `cutAngle`（行进线切角 θ） |
| `unit` | `String?` | e.g. `deg` |
| `levels` | `[String]` | 档位集合，e.g. `["15", "30", "45", "60"]`；非数值档写枚举串（如 `L`/`R`） |
| `rationale` | `String` | 档位划分依据（教学锚点 / 外部基准） |

#### `ConditionVariable`

同 `TargetVariable` 字段，另加：

| Field | Type | Description |
|-------|------|-------------|
| `sampling` | `String` | 采样策略说明（每档 ≥1 次 / 可行域约束等） |

#### `FormationProfile`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `String` | ✅ | 球形 ID，e.g. `A1`；同时用作序列文件 token 与 `tutorial.formations[].id` |
| `difficultyRank` | `Int` | ✅ | 难度序号 1..N（排序规则见方法论要素 6） |
| `cue` / `target` | `Point` | ✅ | 归一化摆位（与本 schema 坐标系一致） |
| `pocket` | `String` | ✅ | Pocket ID |
| `cutAngleDeg` | `Double?` | ❌ | 行进线切角（设计值，脚本验算产出） |
| `spin` | `{ "x": number, "y": number }?` | ❌ | **结构化打点（D-v21-4）**：与 `ShotIntent.Spin` / 引擎 `spinX`/`spinY` 同义——`x`:+左塞/−右塞，`y`:+高杆/−低杆，∈[−1,1]；幅值须满足 √(x²+y²) ≤ `CuePhysics.miscueLimitFraction`(0.5)。缺省 = 无塞声明（中心击打）。见下方「spin 与 variables」 |
| `variables` | `{String: String}` | ✅ | 本球形各变量取值，键与 target/condition 变量 `name` 对应，e.g. `{"cutAngle": "30", "side": "R", "dtp": "0.25", "d": "0.22", "nearRail": "true"}` |
| `representative` | `Bool?` | ❌ | `true` = 代表性球形（回填 drill JSON `shotIntent`/`animation`）；全档案至多一个，缺省难度#1 |
| `sequenceToken` | `String?` | ❌ | 对应 DrillBoards 序列文件 token；缺省 = `id` |

##### `spin` 与 `variables` 档位标签（D-v21-4）

| 层 | 载体 | 角色 |
|----|------|------|
| 档位标签 | `variables` 内自由字符串（如 `sideSpinLevels`: `"轻"`/`"中"`/`"满"`，或 `side`: `"L"`/`"R"`） | 教学/覆盖矩阵用语；人读友好；**不能**唯一还原引擎打点 |
| 结构化数值 | `spin: {x,y}` | 审计脚本、烘焙入参、人工录制前的意图声明；与 `ShotIntent.Spin` 同口径 |

- **为何需要**：initial-only 序列（`steps: []`）只有 `initial.onTable` 球位，**不含** spin/velocity（见 `问题集合_v21.md` §2.4）。几何主题 drill（如 c053）摆位即承载变量；**加塞 drill 的目标变量是 spin**，摆位看不出来——无 `spin` 字段时试打页只剩普通球形。
- **消费方**：`content/drill_profiles/` 仓库真源上的审计 / 批量脚本 / 人工编排；**不进 App Bundle**（与 profile sidecar 整文件同策略）。App 运行时仍以示范序列 `steps[].shotIntent`（录制后）或代表性球形 drill JSON `shotIntent` 为准。
- **一致性**：若同球形同时写了 `variables.side`/`spinLevel` 与 `spin`，以 `spin` 数值为准；档位标签须能由 `spin` 映射回（满塞 `|x|=0.5` 等），脚本可做交叉校验。

#### 最小示例

```json
{
  "drillId": "drill_c053",
  "version": 1,
  "methodology": "docs/research/20260716-drill变量覆盖设计方法论.md",
  "fixedVariables": { "pocket": "bottomCenter（中袋主题钉死）", "entryAngle": "0°（控制变量）" },
  "targetVariables": [
    { "name": "cutAngle", "unit": "deg", "levels": ["15", "30", "45", "60"], "rationale": "厚薄教学锚点" },
    { "name": "side", "levels": ["L", "R"], "rationale": "左右切视线/送杆不对称" }
  ],
  "conditionVariables": [
    { "name": "dtp", "levels": ["0.12", "0.15", "0.20", "0.25"], "rationale": "目标球距袋", "sampling": "每档≥1次，上限受可行域约束" }
  ],
  "formations": [
    {
      "id": "A1", "difficultyRank": 1,
      "cue": { "x": 0.5647, "y": 0.1128 }, "target": { "x": 0.5, "y": 0.3768 },
      "pocket": "bottomCenter", "cutAngleDeg": 15.0,
      "spin": { "x": 0.0, "y": 0.0 },
      "variables": { "cutAngle": "15", "side": "R", "dtp": "0.15", "d": "0.25", "nearRail": "false" },
      "representative": true
    }
  ]
}
```

## Pocket IDs

| ID | Position |
|----|----------|
| `topLeft` | Left top corner |
| `topRight` | Right top corner |
| `bottomLeft` | Left bottom corner |
| `bottomRight` | Right bottom corner |
| `topCenter` | Top side pocket |
| `bottomCenter` | Bottom side pocket |

## 8 Categories

| `category` | nameZh | Typical drills |
|------------|--------|---------------|
| `fundamentals` | 基础功 | Stance, grip, aim line |
| `accuracy` | 准度训练 | Straight, 5-point, angle pocketing |
| `cueAction` | 杆法训练 | Follow, draw, stun, side spin |
| `separation` | 分离角 | Separation angle control |
| `positioning` | 走位训练 | 1-cushion, multi-cushion position |
| `forceControl` | 控力训练 | Power follow, soft touch |
| `specialShots` | 特殊球路 | Safety, jump, rail shots |
| `combined` | 综合球形 | Run-outs, Ghost Game, clearance |

## Coordinate System

- **Origin**: Top-left of table surface (top-down view)
- **X**: 0.0 (left cushion) → 1.0 (right cushion)
- **Y**: 0.0 (top cushion) → 0.5 (bottom cushion)
- **Aspect ratio**: 2:1

### Valid placement range (excluding cushions)

```
X ∈ [0.0197, 0.9803]
Y ∈ [0.0099, 0.4901]
```

### Pocket reference coordinates

| Pocket | X | Y |
|--------|---|---|
| Top-left corner | −0.0165 | −0.0165 |
| Top-right corner | +1.0165 | −0.0165 |
| Bottom-left corner | −0.0165 | +0.5165 |
| Bottom-right corner | +1.0165 | +0.5165 |
| Top center | 0.5 | −0.0268 |
| Bottom center | 0.5 | +0.5268 |

## `index.json` Structure

```json
{
  "version": 2,
  "categories": [
    {
      "category": "fundamentals",
      "drills": ["drill_f001", "drill_f002"]
    },
    {
      "category": "accuracy",
      "drills": ["drill_c001", "drill_c002"]
    }
  ]
}
```
