# v46 封面语义合成试装批（2026-08-31）

## 结论

本试装批验证通过：同一张稳定摄影球桌底图可以通过确定性透视映射，叠加真实计划球形、程序化白色横线/定位点、球与球杆，并在现有 4:3 卡片壳中保持 Light/Dark 可读。6 张试装图均为 1600×1200；聚焦 UI 测试在 iPhone 17 Pro（iOS 26.2）Light/Dark 各通过 2 个用例。

本轮只做临时试装。6 张正式 Asset Catalog PNG 已在测试结束时自动恢复，未批量替换生产资源。

## 稳定底图

- 母版：`/Users/song/.codex/generated_images/01a04ebb-5107-7242-9b5d-f7bd804e9d6d/exec-6a979936-9638-4605-90f9-437538e5a628.png`
- 生成方式：内置 ImageGen 精确编辑；只生成一次清洁底图，不让 ImageGen 决定球、线、点或球杆的位置。
- 编辑提示词：

  > Edit only the provided billiards-table image. Remove only the thin white horizontal line across the green cloth and the two small white positioning dots on the cloth. Reconstruct the green felt naturally underneath. Preserve every other visual element exactly: the same camera, crop, table geometry, grass-green felt colour and texture, plain dark walnut rails, white rail sights, pockets, carved legs, studio background, lighting, exposure and shadows. Do not add balls, cue sticks, markings, text, logos, UI, or any new objects. Output one clean photorealistic 4:3 billiards-table base.

- ImageGen 原始输出：`/Users/song/.codex/generated_images/01a04f13-eb72-7ee0-a8c8-4b539496b9b2/exec-53bc1716-6d83-452b-afdb-d3b7df0dbff1.png`
- 项目内试装副本：`tmp/cover-semantic-validation/20260831-pilot/base/table-clean.png`

## 坐标映射

逻辑坐标沿用 App 真源：`x ∈ [0, 1]`、`y ∈ [0, 0.5]`；球半径为 `0.01125`。App 的 3D 换算仍是：

```text
sceneX = x × 2.540 − 1.270 m
sceneZ = y × 2.540 − 0.635 m
```

摄影底图台面四角通过一次标定固定为归一化图片坐标：

| 逻辑点 | 图片点 |
|---|---|
| `(0, 0)` | `(0.078, 0.444)` |
| `(1, 0)` | `(0.568, 0.143)` |
| `(1, 0.5)` | `(0.917, 0.183)` |
| `(0, 0.5)` | `(0.645, 0.661)` |

由这四对点解出的单应矩阵（图片归一化坐标）为：

```text
H = [[ 0.976959426,  0.748870007, 0.078      ],
     [-0.178402820,  0.039316395, 0.444      ],
     [ 0.857322934, -0.597100764, 1.000000000]]
```

映射采用 `p′ = H × [x, y, 1]ᵀ`，再除以齐次分量。球的图片半径不是固定像素，而是用该点附近 `x/y` 两方向的单应局部尺度计算，因此远端球会自动缩小。所有卡先在 1600×1200 底图坐标中合成，再按每卡固定 4:3 crop 放大回 1600×1200；App 中继续走现有 `scaledToFill` 和 12% 中性黑暗幕。

## 六张试装图

| 资产 | 类型 | 数据来源 | 复杂度 |
|---|---|---|---|
| `coverPlanPositioning` | 官方计划 | `drill_c034` manual01，真实 `initial.onTable` | 低：3 球 |
| `coverPlanAccuracy3` | 官方计划 | `drill_c076` manual01，真实 `initial.onTable` | 中：8 球 |
| `coverPlanFullskill` | 官方计划 | `drill_c071` manual02，真实 `initial.onTable` | 高：16 球 |
| `coverPracticeSpinAndEnglish` | 练习卡 | pilot manifest 的语义球形 | 低：2 球 |
| `coverPracticeSeparationAtlas` | 练习卡 | pilot manifest 的语义球形 | 中：3 球 |
| `coverPracticeDiamond` | 练习卡 | pilot manifest 的语义球形 | 中：3 球 + 反射瞄点 |

计划卡直接读 `BoardSnapshot.initial.onTable`；球键沿用 `cueBall`、`_1`…`_15`。球面采用项目已有 `BallFaceRenderer` 产出的 16 张透明球面素材；球杆、阴影、白线、白点、裁切和卡片暗幕全部由代码绘制。

## 验证结果

- 确定性重跑：6 张封面与联系表 SHA-256 全部与首次输出一致。
- 基础构建：`make -f scripts/Makefile build` 通过。
- Light：`W3_HomeCoverUITests/testW3HomeCoverLightScreenshots` 通过；`V37W4PlanShelfUITests/testCoverPilotTargetCards` 通过。
- Dark：`W3_HomeCoverUITests/testW3HomeCoverDarkScreenshots` 通过；`V37W4PlanShelfUITests/testCoverPilotTargetCards` 通过。
- 全页面 `ScreenshotTourUITests/testUnifiedDesignPages` 首次尝试被系统以 signal kill 终止；改用封面聚焦用例后四次均通过。这是巡游 Runner 稳定性问题，不是封面渲染失败。
- 6 张正式 Asset Catalog PNG 在试装前为 clean，脚本退出后再次为 clean。

产物：

- 生成清单：`tmp/cover-semantic-validation/20260831-pilot/pilot-manifest.json`
- 生成脚本：`scripts/generate_cover_pilot.py`
- 可逆 App 试装脚本：`scripts/verify_cover_pilot_app.sh`
- 6 张 1600×1200 封面：`tmp/cover-semantic-validation/20260831-pilot/output/`
- 524×393 px @3x Light/Dark 联系表：`tmp/cover-semantic-validation/20260831-pilot/output/pilot-card-check-light-dark@3x.png`
- 真实 App 截图：`tmp/cover-semantic-validation/20260831-pilot/output/simulator/{light,dark}/`

## 尚未解决的问题

1. `.kiro/steering/table-geometry.md` 只定义台面尺寸、球径与袋口，不定义开球线、头点、脚点。试装暂用 `headStringX = 0.52`、头点 `(0.52, 0.25)`、脚点 `(0.25, 0.25)`；这三个值只是对参考截图的标定，不得冒充几何真源。扩批前必须由产品确认，并写入唯一真源。
2. 三张计划卡使用真实球形；三张练习入口没有自己的 `BoardSnapshot`，目前是语义示例球形。若正式采用，需要为每个练习入口提供持久化的封面球形数据，避免把构图常量散落在脚本中。
3. 照片透视下的二维球面素材在小卡中可读，但阴影方向和景深仍是近似。它适合训练计划封面，不应被当成物理模拟或逐杆教学图。
4. 白线与定位点已由代码确定，不再出现 ImageGen 漂移；但横线的业务含义必须先命名（开球线、练习分区线或自定义标线），否则无法判断它是否应出现在每张封面。

## 下一门禁

先由用户审阅联系表和 4 类真实 App 截图，明确：① 白线/两点的正式几何；② 三张练习入口的球形是否采用；③ 球、球杆在小卡中的视觉大小。通过后再扩成正式批次；未通过前不替换其余 60 张资源。
