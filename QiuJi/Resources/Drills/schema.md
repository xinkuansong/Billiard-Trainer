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
| `videos` | `[DrillVideo]?` | ❌ | Bundled demo videos (real-person takes) |
| `shotIntent` | `ShotIntent?` | ❌ | Physics shot intent (P10, ADR-P10-01). Source of truth for `baked` animations. |

## `DrillSetsConfig`

| Field | Type | Description |
|-------|------|-------------|
| `defaultSets` | `Int` | Recommended set count |
| `defaultBallsPerSet` | `Int` | Balls per set |

## `DrillTutorial`

| Field | Type | Description |
|-------|------|-------------|
| `sections` | `[TutorialSection]` | Ordered tutorial sections |

## `TutorialSection`

| Field | Type | Description |
|-------|------|-------------|
| `title` | `String` | Section heading, e.g. "技术原理" |
| `content` | `String` | Section body text (Chinese) |

Standard section titles: `技术原理`, `动作要领`, `常见错误与纠正`, `进阶练习`

## `DrillVideo`

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Stable identifier, e.g. `take_01` |
| `file` | `String` | Filename under `Resources/Videos/<drillId>/`, e.g. `take_01.mp4` |

Videos are bundled at `QiuJi/Resources/Videos/<drillId>/<file>`. Populated by
`scripts/import-videos-to-app.py` from the ShootersPool `_inbox` archive.

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
