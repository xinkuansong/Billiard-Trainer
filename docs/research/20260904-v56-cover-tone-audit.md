# v56 摄影封面明暗审计

日期：2026-09-04
范围：当前 Asset Catalog 中 60 张 `cover*` 试装图
性质：只读量化 + 中性叠层策略；不构成封面视觉选型批准

## 结论

用户本轮要求是保留原有 UI 形态、只整理颜色与材质。因此 v56 不替换、不重生成、不重选任何封面源图。当前 60 张仍是此前固定随机种子产生的试装结果，是否作为正式封面集继续使用，仍与本轮颜色收口分开决策。

现有封面曝光跨度很大：60 张中位亮度的总体中位数为 `61.0`，单图范围为 `33.6–237.4`。统一使用固定 12% 叠层无法兼顾高调白底图与低调暗场图；v56 仅按亮度桶施加中性黑色 scrim，不进行色相、饱和度或品牌绿染色：

| 桶 | 判定 | Light scrim | Dark scrim | 数量 |
|---|---:|---:|---:|---:|
| High key | median luma > 150 | 24% | 26% | 4 |
| Bright | 75 < median luma ≤ 150 | 16% | 18% | 7 |
| Default | 45 ≤ median luma ≤ 75 | 12% | 14% | 38 |
| Dark | median luma < 45 | 8% | 10% | 11 |

Dark 只在对应桶上增加 2%，并封顶 30%；这一步只稳定文字与摄影图的层级，不改变照片内容。

## 分桶结果

High key（4）：`coverPlanBeginner`、`coverPracticeQuickRef`、`coverTemplate01`、`coverTemplate06`。

Bright（7）：`coverPracticeBallExtraction`、`coverPracticeComposer`、`coverPracticeFreePlay`、`coverPracticeShotSim`、`coverPracticeSolver`、`coverPracticeSpinAndEnglish`、`coverPracticeT06`。

Dark（11）：`coverPlanCueball`、`coverPlanFullskill`、`coverPlanSeparation`、`coverPracticeAngleDynamic`、`coverPracticeGeometricQuiz`、`coverPracticePlanThree`、`coverTemplate03`、`coverTemplate04`、`coverTemplate07`、`coverTemplate09`、`coverTemplate11`。

其余 38 张进入 Default 桶。

## 可复现方式

量化脚本：`scripts/design/analyze_v56_cover_palette.py`。它只读取图片，输出每张图的 median luma、p10 黑位、R-B 色温差、绿色区域饱和度和顶部安全区亮度，不写 Asset Catalog。

对应实现：`BTAtmosphereToneProfile` 只返回中性 scrim opacity；自动测试 `AtmosphereCatalogTests.testV56NeutralScrimBucketsPreservePhotographyWithoutHueWash` 守住四档数值、Dark +2% 与“不得增加 hue wash”契约。

## 决策边界

- 已完成：当前试装图在 Light / Dark 中的可读性归一。
- 未声称：60 张图片本身已经通过视觉选型。
- 后续若用户选择恢复上一套或重选候选，只需替换源图；本轮中性分桶仍可复用并重新跑量化。
