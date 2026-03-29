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
| `animation` | `DrillAnimation` | ✅ | Canvas animation data |

## `DrillSetsConfig`

| Field | Type | Description |
|-------|------|-------------|
| `defaultSets` | `Int` | Recommended set count |
| `defaultBallsPerSet` | `Int` | Balls per set |

## `DrillAnimation`

| Field | Type | Description |
|-------|------|-------------|
| `cueBall` | `BallAnimation` | Cue ball start + path |
| `targetBall` | `BallAnimation` | Target ball start + path |
| `pocket` | `String` | Target pocket ID (see Pocket IDs) |
| `cueDirection` | `Point` | Aiming direction vector |

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
