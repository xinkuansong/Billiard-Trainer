# 本周训练卡片实现记录

项目：`/Users/song/projects/13.billiard_trainer`。日期：2026-09-09。

## 本轮实现

- 使用新摄影背景 `trainingWeekly`：比赛绿平整台呢、细织物纹理、右半区完整白球与右侧木杆/蓝巧粉皮头。照片等比裁切，避免球形被拉伸；构图避开右上实体按钮。
- 清台入口改为100%浅米白实体胶囊，深绿文字/图标、轻阴影；继续复用现有44pt命中区、`BreakRackGlyph`、字号和导航。
- 完成日为浅米白实圆+深绿勾；未完成日为浅米白65%描边空圆；今天仅10%深绿圆角底。无白色日期卡片。
- 米白 `btTrainingIvory` 使用项目现有分享纸色数值 #F7F6F2；深绿 `btTrainingInk` 使用原摄影组件深绿数值。两种外观同值；火焰沿用 `btWarning`。
- 晨/昼/晚共用确认照片，叠加0/3%/8%深绿光照，避免时段切图导致绿色和球形漂移。现有时段边界、分钟刷新及减少动态效果机制保留。
- 原卡片高度、间距、字号、数据计算、周一起点和清台交互保留。隐藏两处分隔线但保留占位，避免线穿过球面；首页其他区域未做布局调整。

## 修改文件

均相对于项目根目录：

| 文件 | 关键变更 |
| --- | --- |
| `QiuJi/Features/Training/Views/TrainingHomeView.swift` | 实体按钮、今天底色、隐藏卡内分隔线但保留占位 |
| `QiuJi/Core/Components/BTTrainingAtmosphere.swift` | 新摄影素材、同源时段光照、米白及深绿颜色引用 |
| `QiuJi/Resources/Assets.xcassets/Atmosphere/trainingWeekly.imageset/` | 新增摄影PNG及资源描述 |
| `QiuJi/Resources/Assets.xcassets/btTrainingIvory.colorset/` | 浅米白命名色 |
| `QiuJi/Resources/Assets.xcassets/btTrainingInk.colorset/` | 原摄影深绿命名色 |
| `QiuJiUITests/TrainingAtmosphereUITests.swift` | 完成训练状态、44pt入口、清台跳转与返回的浅深色验证 |
| `tasks/UI-IMPLEMENTATION-SPEC.md`、`tasks/IMPLEMENTATION-LOG.md`、`tasks/PROGRESS.md` | DR-127规范及完成记录 |
| `tasks/ui-reviews/UR-20260909-weekly-training-final.md` | 视觉审查和验证边界 |

## 验证

- 最终 Debug：`BUILD SUCCEEDED`。
- 原有时段边界/素材加载单测：2项通过。
- iPhone 17 Pro、iPhone SE（第三代），iOS 26.2：各1项UI流程测试通过，每项覆盖浅色/深色、完成日、清台进入/返回及记录保持。
- 最终四张整页截图已打开目视，白球完整、按钮不遮球，日历七列与文字无截断；小屏页头原有标语截断不属于本次修改。
- 训练数据来自已有内存夹具，因此截图为“本周1/3天、连续1天”；生产仍显示用户真实数据，不硬编码2/3或周三。
- 内容门禁 `FAIL 0`，文档体积与diff检查通过。
- 初轮测试的Light标签实际渲染深色，已修正为现有v54外观参数并在两设备重新跑；最终证据仅以 `standard-verified` / `compact-verified` 为准。
- 真机、iPad、放大字号及完整VoiceOver未验证。未提交、未发布。原有未提交工作保留。

项目证据：`/Users/song/projects/13.billiard_trainer/output/weekly-training-final-20260909/`，含构建日志、测试日志/xcresult、最终提示词与源码SHA-256。

## 实际页面

### iPhone 17 Pro — 浅色

![iPhone 浅色](/Users/song/Documents/Codex/2026-09-09/referenced-chatgpt-conversation-this-is-an/outputs/iPhone-Light.png)

### iPhone 17 Pro — 深色

![iPhone 深色](/Users/song/Documents/Codex/2026-09-09/referenced-chatgpt-conversation-this-is-an/outputs/iPhone-Dark.png)

### iPhone SE — 浅色

![SE 浅色](/Users/song/Documents/Codex/2026-09-09/referenced-chatgpt-conversation-this-is-an/outputs/SE-Light.png)

### iPhone SE — 深色

![SE 深色](/Users/song/Documents/Codex/2026-09-09/referenced-chatgpt-conversation-this-is-an/outputs/SE-Dark.png)


## 同数据布局核对

同为0/3天、继续清台、浅色默认字号，最终截图与改前截图已逐项目视：首页其他区域位置保持。

[修改前](/Users/song/Documents/Codex/2026-09-09/referenced-chatgpt-conversation-this-is-an/outputs/首页-修改前.png) · [修改后](/Users/song/Documents/Codex/2026-09-09/referenced-chatgpt-conversation-this-is-an/outputs/首页-修改后.png)
