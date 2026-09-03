# 训练计划 / 练习卡片封面提示词系统 v1

> 日期：2026-09-02
> 状态：设计与提示词规格已完成；2026-09-03 已生成 60 × 4 = 240 张候选并通过机械验收；同日按用户要求从每组随机抽取 1 张完成本地 App 试装，尚未作最终视觉选择
> 范围：12 个官方计划 + 36 个练习入口；附录另管 12 张自定义计划模板
> 生成模式：内置 ImageGen，一张资产一次调用；本文件不授权批量写入 Asset Catalog

### 0.1 2026-09-03 候选生成授权与波次

用户已授权为每个资源键生成 4 张候选，共 60 × 4 = 240 张。本轮只写入
`output/imagegen/cover-prompt-system-v1/20260903/`，不得写入或替换正式 Asset Catalog。

| 波次 | 范围 | 资源键 | 候选数 | 执行方式 | 模型 |
|---|---|---:|---:|---|---|
| W1-A | P01–P12 + 学01–学08 | 20 | 80 | 并行独立目录 | 继承当前 Codex 模型 |
| W1-B | 学09 + 理01–理12 + 练01–练06 + 打01 | 20 | 80 | 并行独立目录 | 继承当前 Codex 模型 |
| W1-C | 打02–打04 + 解01–解05 + Template01–Template12 | 20 | 80 | 并行独立目录 | 继承当前 Codex 模型 |

每个候选必须是一次独立的内置 ImageGen 调用，文件名固定为
`<asset-key>/v01.png`–`v04.png`。四张只允许改变构图微差、主体在安全区内的位置、景深和灯光比例，
不得改变该资源键的主题语义、镜头模板、器材规范或参考图角色。

### 0.2 2026-09-03 随机 App 试装

用户随后明确要求“随机从每一个里面选择一个，然后放到 App 里”。因此仅针对本地视觉试装，
从每个资源键的 `v01`–`v04` 中随机抽取 1 张，临时写入对应正式 Asset Catalog PNG；这是一项
后续授权，不改变 0.1 的原始生成边界，也不代表候选已通过人工视觉闸。

- 固定随机种子：`ec06c13311dea1f7894c6de81b6b374d`
- 抽取分布：v01 × 25、v02 × 12、v03 × 10、v04 × 13
- 试装清单：`output/imagegen/cover-prompt-system-v1/20260903/app-preview/random-selection-manifest.md`
- 原资源备份：`output/imagegen/cover-prompt-system-v1/20260903/app-preview/formal-assets-before/`
- App 截图：`output/imagegen/cover-prompt-system-v1/20260903/app-preview/PREVIEW.md`
- 验证：60/60 安装哈希与候选一致；主工作区 Debug 构建通过；iPhone 17 Pro 的计划、学、理、练、打、解 6/6 个 Light UI 截图测试通过

当前工作区保留随机试装资源，等待用户目视选择；不得将“随机抽中”解释为正式批准。

## 1. 这套封面解决什么问题

封面承担的是“主题识别 + 品牌氛围”，不是教学图、球形截图或物理证明。精确摆球、轨迹、
角度和逐杆过程仍以 `content/position_play/sequences/`、`DrillBoards` 与真实场景页为准。

本轮锁定的视觉方向是**高品质台球器材静物摄影**：以球、球杆、局部台呢、库边或袋口作为
主题符号，通过低机位微距、长焦纵深、深灰俯拍和高调棚拍形成变化。禁止重新回到“整桌俯视 +
程序线条”作为统一封面，也禁止把 48 张卡做成 48 套互不相关的艺术风格。

### 1.1 不变项

- 4:3 横图；交付规格 1600×1200 px。
- 写实摄影或不可辨别于摄影的克制写实 3D。
- 六点红母球、标准中式八球球色、浅木色球杆、低纹理深胡桃木库边。
- 品牌色域：深绿 `#1B6B3A`、石墨 `#1C1C1E`、冷白灰 `#F2F2F7`；黄/金只作小面积暖色。
- 约 5000K 中性白平衡；暗场保留中间调，不做酒吧霓虹与橙青电影调色。
- 无人物、手、文字、Logo、水印、UI、轨迹、箭头、角度弧、定位点、准星、数字步骤。
- 主体避开左上编号区和右上 Pro 徽标区；缩到约 524×393 px 后仍可识别。
- App 运行时会再叠加 12% 中性黑幕，原图不得已经压黑。

### 1.2 可变项

- 主角可为六点红母球、黑 8、某颗关键目标球、球杆皮头、局部球组、袋口或库边。
- 允许四类受控舞台：深绿台呢微距、长焦纵深、石墨俯拍静物、冷白高调棚拍。
- 镜头、焦点、景深、球数、负空间方向可按主题改变；材质、色域和摄影气质不得改变。

### 1.3 内容准确度边界

- **官方计划**：读取真实计划 JSON，选择一个代表动作；其 initial 图只提供球身份与核心拓扑，
  不要求封面复刻精确坐标。不得凭封面声称某条物理线路正确。
- **练习入口**：没有独立 `BoardSnapshot`，使用语义静物；不冒充某个 drill 的真实初始球形。
- **密集球号**：ImageGen 不可靠。封面只表达“连续、多球、球团”等主题；若必须保证具体号码，
  后处理必须使用确定性球面素材并逐球验收。

## 2. 真实卡片环境

- 计划与练习卡使用 `BTContentGridCard` 的 4:3 封面。
- 资源规格：1600×1200 px；运行时 `scaledToFill`。
- iPhone 393 pt 两列布局中，单张封面约 174.5×130.875 pt；@3x 检查约 524×393 px。
- 计划卡左上可能有“第 N 期”；练习卡左上有组内编号，右上可能有 Pro 徽标。
- 正式图像自身不嵌字，标题由卡片下方系统组件承担。

## 3. 参考图库（R00–R09）

所有参考图只用于提示与视觉校准，不作为发布资源。用户提供的图可能具有未知来源，禁止直接裁切、
重绘或随 App 分发。项目内副本只为避免临时剪贴板路径失效。

| 编号 | 项目内路径 | 角色 | 使用规则 |
|---|---|---|---|
| R00 | `docs/design/references/cover-prompt-system-v1/R00-app-light-context.png` | App 品牌与真实卡片上下文 | **不传给 ImageGen**；只在人工验收时比较明度、色域与小卡协调性 |
| R01 | `docs/design/references/cover-prompt-system-v1/R01-macro-cue-line.png` | 深绿台呢、母球主角、球列纵深、浅景深 | 用于“母球主角 / 连续球列”类 |
| R02 | `docs/design/references/cover-prompt-system-v1/R02-macro-eight-hero.png` | 黑 8 主角、暗场微距、上下负空间 | 用于“战术 / 关键球 / 特殊球”类 |
| R03 | `docs/design/references/cover-prompt-system-v1/R03-macro-cue-depth.png` | 母球主角、三层景深、袋口与远球背景 | 用于“瞄准 / 球感 / 解题局面”类 |
| R04 | `docs/design/references/cover-prompt-system-v1/R04-charcoal-overhead.png` | 石墨背景、俯拍稀疏球组、理性负空间 | 用于“理论 / 对照 / 角度 / 球团”类 |
| R05 | `docs/design/references/cover-prompt-system-v1/R05-high-key-cue.png` | 冷白高调棚拍、球杆与器材静物 | 用于“基本功 / 入门 / 速查”类 |
| R06 | `docs/design/references/cover-prompt-system-v1/R06-material-lock.png` | 球桌、球、球杆整体材质锁 | 每张最多与一个主要风格参考共同传入 |
| R07 | `docs/design/references/cover-prompt-system-v1/R07-ball-kit.png` | 六点红母球、号码圆、标准球色 | 指定号码或密集球身份时使用 |
| R08 | `docs/design/references/cover-prompt-system-v1/R08-cue-kit.png` | 中式球杆结构、皮头、木纹 | 球杆或打点为主角时使用 |
| R09 | `docs/design/references/cover-prompt-system-v1/R09-table-structure.png` | 标准六袋球桌、库边与袋口 | 袋口、贴库、翻袋、吃库语义时使用 |

### 3.1 单次调用参考图上限

每张最多传入 4 张参考图，且每张必须写明角色：

1. 1 张主要风格参考：R01–R05 之一；
2. 1 张材质参考：通常 R06；
3. 1 张专项参考：号码用 R07、球杆用 R08、库袋用 R09，三选一；
4. 官方计划可再加 1 张代表动作 initial；练习卡通常没有第 4 张。

禁止把 R01–R05 全部同时传入，也禁止使用本轮未通过人工裁定的生成图充当新风格真源。

## 4. 镜头模板

下述焦段与光圈是视觉目标，不是要求生成器写入 EXIF。

| 模板 | 名称 | 镜头与机位 | 景深与构图 | 默认风格参考 |
|---|---|---|---|---|
| CAM-M1 | 台呢微距主角 | 70–100 mm；镜头离台呢约 4–8 cm；俯角 3–8° | 主角球占短边 22–30%；背景球柔化；上方保留暗色负空间 | R01 / R03 |
| CAM-M2 | 长焦球列纵深 | 85–120 mm；沿球列或击球方向；俯角 6–12° | 压缩纵深；近端主角锐利，远端逐级虚化 | R01 |
| CAM-M3 | 杆头打点微距 | 90–120 mm；皮头高度；俯角 0–5° | 皮头与母球接近但不穿球；目标球仅作景深参照 | R03 + R08 |
| CAM-T1 | 石墨俯拍静物 | 50–70 mm；俯角 80–90° | 3–6 颗球；柔和单向阴影；大面积干净负空间 | R04 |
| CAM-H1 | 冷白高调棚拍 | 65–90 mm；俯角 8–20° | 冷白灰无缝背景；轻微落地反射；器材轮廓清楚 | R05 |
| CAM-S1 | 局部空间关系 | 50–70 mm；俯角 25–35° | 只取球、局部库边/袋口和必要台呢；不展示全桌 | R03 + R09 |

## 5. 公共系统提示词

每张正式调用都由“本节公共系统提示词 + 第 6/7/8 节对应实例提示词”拼接。不要把实例提示词
单独执行。

```text
Use case: product-mockup
Asset type: production candidate for a 4:3 mobile billiards training-plan or practice-card cover

Primary visual system:
Create a premium photorealistic billiards-equipment still life, not an instructional diagram and not a full app screen. The image must belong to one restrained brand family built from deep natural green felt near #1B6B3A, neutral charcoal near #1C1C1E, cool off-white near #F2F2F7, realistic glossy phenolic balls, a six-small-red-dot cue ball, a simple light-maple Chinese-pool cue, quiet dark-walnut rails, and neutral 5000K studio lighting. Dark scenes must preserve midtone detail; bright scenes must remain cool-neutral rather than sterile.

Output intent:
Landscape 4:3 composition intended to be finished at 1600x1200. The main subject must remain recognizable when reduced to approximately 524x393. Keep calm negative space and a clear single visual anchor. Reserve uncluttered safe areas in the upper-left and upper-right corners for app overlays. Do not embed the card title.

Input-image policy:
Use each supplied image only for the role declared in the asset-specific prompt. Never copy text, UI, exact printed layouts, or unrelated objects from a reference. Preserve the material language from the material reference and the photographic language from the one declared style reference. A plan initial image is semantic context only: preserve the named ball identities and core relationship, but recompose them for the declared camera; do not claim exact coordinate reproduction.

Hard constraints:
No people, hands, faces, logos, watermarks, UI, captions, decorative typography, trajectory lines, arrows, grids, angle arcs, positioning dots, target rings, crosshairs, numbers used as steps, floating balls, impossible shadows, ornate wood, smoky nightclub atmosphere, neon cyan felt, saturated red-blue lighting, orange-and-teal blockbuster grading, crushed blacks, or toy-like CGI. Use only the balls and cue explicitly requested. Standard numbered-ball colors must be plausible. If a cue is present, its tip must not intersect the cue ball.
```

## 6. 12 个官方计划：逐项实例提示词

官方计划真源：`QiuJi/Resources/Plans/index.json` 与对应计划 JSON。代表动作与 initial 只为主题锚定；
若提示词与 initial 冲突，以 initial 中的球身份和拓扑为准，禁止 AI 自行发明坐标。

### P01 `plan_beginner` — 基本功 / `coverPlanBeginner`

- 计划真源：`QiuJi/Resources/Plans/plan_beginner.json`
- 内容锚：`drill_c012` 中袋直线出杆；`QiuJi/Resources/DrillTutorials/drill_c012_initial.png`
- 风格 / 镜头：冷白入门静物；CAM-H1
- 参考图顺序：R05（风格）、R06（材质）、R08（球杆）、`drill_c012_initial.png`（有序练习通道概念）

```text
Primary request: Represent “Fundamentals” as a calm high-key product still life. Place one six-red-dot cue ball as the crisp hero on a cool off-white studio surface, with a light-maple cue approaching on a perfectly straight visual axis. Behind it, use a restrained rhythm of three softly defocused standard balls to suggest repeated straight-stroke practice; the initial reference supplies only the ordered-lane idea, not an exact layout.
Composition/framing: CAM-H1, hero ball near the lower third, cue entering diagonally from the upper-right without touching the ball, generous clean negative space above and to both top corners.
Lighting/mood: soft neutral studio light, subtle grounded reflection, approachable and precise.
Constraints: no table overview, no path line, no measurement marks, no duplicated cue ball, no text.
```

### P02 `plan_accuracy` — 准度Ⅰ·近中台 / `coverPlanAccuracy`

- 计划真源：`QiuJi/Resources/Plans/plan_accuracy.json`
- 内容锚：`drill_c013/manual02` 底袋小角度；`QiuJi/Resources/DrillTutorials/drill_c013_manual02_initial.png`
- 风格 / 镜头：母球—黑 8—袋口近中台关系；CAM-M1
- 参考图顺序：R03（风格）、R06（材质）、R09（袋口）、`drill_c013_manual02_initial.png`（小角度关系）

```text
Primary request: Represent “Accuracy I: short and medium range” on deep natural green felt. Make the six-red-dot cue ball the near hero; place a black 8-ball in the middle depth and a single corner pocket softly readable behind it, creating a clean near-to-far aiming relationship without drawing an aiming line. A small number of distant marker balls may echo the angle progression from the content reference but must remain secondary.
Composition/framing: CAM-M1, low felt-level view, cue ball at one third, 8-ball and pocket staggered into depth, upper background softly dark.
Lighting/mood: calm premium training-room studio light, crisp felt around the hero and controlled bokeh.
Constraints: no full table, no arrows, no false exact angle, no crowded ball rack.
```

### P03 `plan_intermediate` — 准度Ⅱ·远台切角 / `coverPlanIntermediate`

- 计划真源：`QiuJi/Resources/Plans/plan_intermediate.json`
- 内容锚：`drill_c033/manual01` 远台底袋角度球；`QiuJi/Resources/DrillTutorials/drill_c033_initial.png`
- 风格 / 镜头：长台纵深与远端袋口；CAM-M2
- 参考图顺序：R01（风格）、R06（材质）、R09（球台）、`drill_c033_initial.png`（长距离关系）

```text
Primary request: Represent “Accuracy II: long-table cuts” as a compressed long-lens corridor on green felt. Keep the cue ball sharp in the near foreground, a black 8-ball smaller in the far middle distance, and one corner pocket as a soft terminal anchor. Use one or two very soft marker balls only to imply changing cut positions from the content reference.
Composition/framing: CAM-M2, camera almost at cloth level, long diagonal depth, near cue ball large enough for thumbnail recognition, far pocket visible but not dominant.
Lighting/mood: focused and serious, neutral highlights, no theatrical darkness.
Constraints: preserve the feeling of distance; do not flatten into an overhead still life; no line, arrow, or degree mark.
```

### P04 `plan_force` — 力度 / `coverPlanForce`

- 计划真源：`QiuJi/Resources/Plans/plan_force.json`
- 内容锚：`drill_c051/manual01` 全力度走位综合；`QiuJi/Resources/DrillTutorials/drill_c051_initial.png`
- 风格 / 镜头：长空台呢与不同距离层次；CAM-M1
- 参考图顺序：R03（风格）、R06（材质）、R08（球杆）、`drill_c051_initial.png`（母球/1/8 关系）

```text
Primary request: Represent “Speed control” with one six-red-dot cue ball as the near hero, a yellow 1-ball and black 8-ball placed at clearly different depth layers, and a long uninterrupted stretch of green felt expressing travel distance. A cue may enter softly behind the cue ball with ample follow-through space.
Composition/framing: CAM-M1 with slightly deeper focus than usual; cue ball near lower-left third, 1-ball mid-depth, 8-ball far depth, clean empty lane between them.
Lighting/mood: measured, quiet and technical; restrained warm highlights only on the yellow ball.
Constraints: no multiple cue balls to symbolize speed, no speedometer graphics, rings, rulers, blur trails, or motion streaks.
```

### P05 `plan_cueball` — 杆法Ⅰ·高低杆 / `coverPlanCueball`

- 计划真源：`QiuJi/Resources/Plans/plan_cueball.json`
- 内容锚：`drill_c004/manual02` 低杆缩回；`QiuJi/Resources/DrillTutorials/drill_c004_manual02_initial.png`
- 风格 / 镜头：皮头高度与母球上下打点；CAM-M3
- 参考图顺序：R03（风格）、R06（材质）、R08（球杆）、`drill_c004_manual02_initial.png`（直球关系）

```text
Primary request: Represent “Cue-ball control I: follow and draw” through a tactile cue-tip macro. Show one six-red-dot cue ball large and sharp, with the light-maple cue tip approaching slightly below centre; a yellow 1-ball is softly aligned in the background. The image should communicate controllable cue contact rather than a specific executed trajectory.
Composition/framing: CAM-M3, cue tip and front half of cue ball in the same focal plane, target ball softly receding, safe dark negative space above.
Lighting/mood: precise studio macro, visible ball gloss and felt fibres, controlled shadow beneath the cue ball.
Constraints: cue tip must not penetrate the ball; no second cue, no ghost ball, no spin icon or contact marker.
```

### P06 `plan_english` — 杆法Ⅱ·加塞挤偏 / `coverPlanEnglish`

- 计划真源：`QiuJi/Resources/Plans/plan_english.json`
- 内容锚：`drill_c075/manual03` 塞量阶梯；`QiuJi/Resources/DrillTutorials/drill_c075_manual03_initial.png`
- 风格 / 镜头：侧向偏心皮头微距；CAM-M3
- 参考图顺序：R03（风格）、R06（材质）、R08（球杆）、`drill_c075_manual03_initial.png`（加塞主题）

```text
Primary request: Represent “Cue-ball control II: english and squirt” with an extreme macro of a cue tip approaching the six-red-dot cue ball at a clearly visible but restrained lateral offset. Keep one black 8-ball softly in depth as the target context. The cue offset is the visual subject; do not visualize the resulting path.
Composition/framing: CAM-M3, cue tip entering from a lower side edge, cue ball placed at one third rather than centred, black 8-ball in soft opposite-side depth.
Lighting/mood: dark green felt macro with neutral highlights and enough midtone detail for the app card.
Constraints: offset must remain physically plausible, under roughly half a tip visually; no bent cue, curve trail, duplicated ball, spin arrows or glow.
```

### P07 `plan_accuracy3` — 准度Ⅲ·带塞 / `coverPlanAccuracy3`

- 计划真源：`QiuJi/Resources/Plans/plan_accuracy3.json`
- 内容锚：`drill_c076/manual01` 小角度带塞；`QiuJi/Resources/DrillTutorials/drill_c076_manual01_initial.png`
- 风格 / 镜头：理性俯拍中的加塞准度关系；CAM-T1
- 参考图顺序：R04（风格）、R06（材质）、R07（球身份）、`drill_c076_manual01_initial.png`（角度阶梯概念）

```text
Primary request: Represent “Accuracy III: potting with english” as a restrained charcoal overhead still life. Use one six-red-dot cue ball, one black 8-ball and three standard coloured balls forming an asymmetric angle fan with generous negative space. A short portion of cue may approach the cue ball off-centre from the crop edge, but the balls remain the primary graphic shapes.
Composition/framing: CAM-T1, sparse five-ball composition, cue ball and black 8 separated clearly, soft directional shadows, no table rail required.
Lighting/mood: clean, premium, analytical and quiet; charcoal surface must retain texture.
Constraints: do not reproduce a dense numbered marker ladder with ImageGen; no angle line, degree label, diagram or UI.
```

### P08 `plan_separation` — 分离角 / `coverPlanSeparation`

- 计划真源：`QiuJi/Resources/Plans/plan_separation.json`
- 内容锚：`drill_c024/manual01` 分离角 90 度规则；`QiuJi/Resources/DrillTutorials/drill_c024_manual01_initial.png`
- 风格 / 镜头：两球接触关系与开放侧空间；CAM-T1
- 参考图顺序：R04（风格）、R06（材质）、R07（球身份）、`drill_c024_manual01_initial.png`（碰撞关系）

```text
Primary request: Represent “Separation angle” as a charcoal overhead collision study. Place the six-red-dot cue ball and black 8-ball close but not overlapping, with a large deliberate open area on the tangent side. Add two small coloured reference balls far enough away to suggest alternate outcomes without forming a diagram.
Composition/framing: CAM-T1, cue ball and 8-ball near the lower-middle, negative space opening diagonally upward, soft precise contact shadows.
Lighting/mood: rational and editorial, consistent with premium equipment photography.
Constraints: no 90-degree symbol, perpendicular axes, tangent line, arrows or multiple copies of the cue ball.
```

### P09 `plan_positioning` — 走位Ⅰ·短距到一库 / `coverPlanPositioning`

- 计划真源：`QiuJi/Resources/Plans/plan_positioning.json`
- 内容锚：`drill_c034/manual01` 不吃库短距离走位；`QiuJi/Resources/DrillTutorials/drill_c034_initial.png`
- 风格 / 镜头：母球、黄 1、黑 8 的三层关系；CAM-M1
- 参考图顺序：R03（风格）、R06（材质）、R07（球身份）、`drill_c034_initial.png`（三球关系）

```text
Primary request: Represent “Position play I: short distance to one cushion” as a low green-felt macro with a six-red-dot cue ball sharp in the foreground, a yellow 1-ball in middle depth, and a black 8-ball as the far planning anchor. Keep the three balls visually connected by depth and spacing, not by graphics.
Composition/framing: CAM-M1, cue ball at lower third, 1-ball and 8-ball staggered diagonally, a soft sliver of rail may appear in the far background.
Lighting/mood: calm, practical and achievable, with tactile felt and restrained bokeh.
Constraints: no generic straight three-ball line, no target area, path or duplicate ball.
```

### P10 `plan_positioning2` — 走位Ⅱ·多库与蛇彩 / `coverPlanPositioning2`

- 计划真源：`QiuJi/Resources/Plans/plan_positioning2.json`
- 内容锚：`drill_c042/manual02` 初级蛇彩；`QiuJi/Resources/DrillTutorials/drill_c042_manual02_initial.png`
- 风格 / 镜头：连续球列纵深；CAM-M2
- 参考图顺序：R01（风格）、R06（材质）、R07（球身份）、`drill_c042_manual02_initial.png`（蛇彩节奏）

```text
Primary request: Represent “Position play II: multi-cushion and line-up” with a long-lens low view along a clean sequence of five differently coloured object balls. Keep the six-red-dot cue ball offset and sharp at the starting end; let the numbered balls recede rhythmically into controlled blur.
Composition/framing: CAM-M2, compressed diagonal ball line, cue ball at one third, far rail only as a soft depth anchor, ample dark negative space above.
Lighting/mood: focused and advanced but not theatrical.
Constraints: the line must not look like a triangle rack; no need to make distant numbers readable; no duplicate colours in the sharp foreground.
```

### P11 `plan_advanced` — 特殊球 / `coverPlanAdvanced`

- 计划真源：`QiuJi/Resources/Plans/plan_advanced.json`
- 内容锚：`drill_c057/Snipaste_2026_06_19_17_45_48` K 球吃库；`QiuJi/Resources/DrillTutorials/drill_c057_Snipaste_2026_06_19_17_45_48_initial.png`
- 风格 / 镜头：黑 8 / 库边 / 袋口的战术微距；CAM-S1
- 参考图顺序：R02（风格）、R06（材质）、R09（库袋）、上述 initial（黄 1 / 蓝 2 / 母球关系）

```text
Primary request: Represent “Special shots” as a tense but clean local table study. Use a black 8-ball as the sharp visual anchor near a quiet walnut rail, with the six-red-dot cue ball, yellow 1-ball and blue 2-ball distributed in three depth layers; one corner pocket is readable as a secondary spatial clue. Preserve the content reference’s sense that the cushion relationship matters without drawing the route.
Composition/framing: CAM-S1, rail as a strong diagonal, 8-ball near one third, pocket away from both top overlay zones, shallow-to-medium depth of field.
Lighting/mood: premium dark studio, restrained highlights, clear midtones.
Constraints: no impossible ball sitting inside a pocket mouth, no bank line, no collision spark, no generic full-table layout.
```

### P12 `plan_fullskill` — 全能精选 / `coverPlanFullskill`

- 计划真源：`QiuJi/Resources/Plans/plan_fullskill.json`
- 内容锚：`drill_c071/manual02` 高级蛇彩；`QiuJi/Resources/DrillTutorials/drill_c071_manual02_initial.png`
- 风格 / 镜头：多球连续性与综合能力；CAM-M2
- 参考图顺序：R01（风格）、R06（材质）、R07（球身份）、`drill_c071_manual02_initial.png`（长球列节奏）

```text
Primary request: Represent “All-round selection” through a premium low-angle ball-line still life. Place the six-red-dot cue ball large and sharp at the start, with six differently coloured standard object balls receding in a gentle diagonal rhythm. The content reference supplies the idea of a long advanced line-up; do not ask ImageGen to reproduce all fifteen numbered balls.
Composition/framing: CAM-M2, closest three balls remain individually readable, distant balls blend into controlled depth, upper half is calm dark negative space.
Lighting/mood: confident, polished and comprehensive, using the same restrained green/charcoal grade as the rest of the system.
Constraints: no full rack, no duplicated visible number, no tournament branding, no exaggerated rainbow palette.
```

## 7. 36 个练习入口：逐项实例提示词

练习卡资源键以 `AtmosphereCatalog.coverArt(for:)` 为真源。以下提示词只表达入口语义，不声称是某个
drill 的真实球形。每条仍须与第 5 节公共系统提示词拼接。

### 学 01 `aimingPrinciple` — 瞄准原理 / `coverPracticeAimingPrinciple`

- 风格 / 镜头：深绿瞄准纵深；CAM-M1
- 参考图：R03（风格）、R06（材质）、R09（袋口）

```text
Primary request: Show the six-red-dot cue ball as the near hero, a black 8-ball in middle depth, and one corner pocket softly visible farther away, forming an immediately understandable aiming relationship without any line.
Composition/framing: CAM-M1, three anchors staggered into depth, hero ball at one third, clean dark negative space above.
Constraints: no cue required, no ghost ball, contact dot, angle arc or aiming guide.
```

### 学 02 `aimingMethods` — 瞄准方法 / `coverPracticeAimingMethods`

- 风格 / 镜头：顺杆视线微距；CAM-M3
- 参考图：R03（风格）、R06（材质）、R08（球杆）

```text
Primary request: Show a light-maple cue, the six-red-dot cue ball and a black 8-ball visually stacked along the viewing axis, as if looking cleanly down the cue without showing a player.
Composition/framing: CAM-M3 with slightly deeper focus so cue tip, cue ball and target ball remain separable; use the upper background as quiet negative space.
Constraints: the cue must not hide or intersect the cue ball; no eye, face, hand, line or crosshair.
```

### 学 03 `aimingCorrection` — 瞄准修正 / `coverPracticeAimingCorrection`

- 风格 / 镜头：轻微偏轴的杆头关系；CAM-M3
- 参考图：R03（风格）、R06（材质）、R08（球杆）

```text
Primary request: Create a precise cue-tip macro in which the cue approaches the six-red-dot cue ball from a subtly incorrect lateral axis while a red target ball sits softly in the intended depth direction. The image should suggest “notice and correct alignment,” not demonstrate a curved shot.
Composition/framing: CAM-M3, cue tip near the lower side, cue ball sharp at one third, target ball soft and offset in depth.
Constraints: keep the misalignment subtle and plausible; no bent cue, duplicated cue, correction arrow or before/after split.
```

### 学 04 `spinAndEnglish` — 旋转与加塞 / `coverPracticeSpinAndEnglish`

- 风格 / 镜头：偏心皮头与母球极近微距；CAM-M3
- 参考图：R03（风格）、R06（材质）、R08（球杆）

```text
Primary request: Make the six-red-dot cue ball fill much of the frame while a cue tip approaches at a clear but restrained side offset. The red dots and tip position are the visual subject; one distant black ball may provide soft context.
Composition/framing: extreme CAM-M3, tactile felt and ball surface, cue entering from the lower edge, safe uncluttered top corners.
Constraints: exactly one cue ball and one cue; no spin arrows, glowing contact point, trail or impossible tip penetration.
```

### 学 05 `angleDynamic` — 角度与瞄准 / `coverPracticeAngleDynamic`

- 风格 / 镜头：稀疏三点角度关系；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Arrange the six-red-dot cue ball, black 8-ball and one gold target ball as a sparse asymmetric triangle on a charcoal surface, using spacing alone to express a changeable cut-angle relationship.
Composition/framing: CAM-T1, three balls large enough for thumbnail scale, soft directional shadows, broad negative space around the triangle.
Constraints: no degrees, arc, ruler, axis, duplicate ball or diagram styling.
```

### 学 06 `separationAngleAtlas` — 分离角图谱 / `coverPracticeSeparationAtlas`

- 风格 / 镜头：碰撞球对与开放侧空间；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Place the six-red-dot cue ball and black 8-ball close together as a collision pair, with one gold reference ball farther into a wide open side area. The negative space, not drawn geometry, should imply multiple separation outcomes.
Composition/framing: CAM-T1, collision pair off-centre, large open diagonal quadrant, clean soft shadows.
Constraints: no multiple cue balls, fan lines, tangent line, angle labels or chart marks.
```

### 学 07 `cushionEnglishAtlas` — 加塞吃库图谱 / `coverPracticeCushionEnglish`

- 风格 / 镜头：贴库杆头微距；CAM-S1
- 参考图：R03（风格）、R06（材质）、R09（库边）

```text
Primary request: Show a six-red-dot cue ball very near a quiet dark-walnut long rail, with a light-maple cue approaching at a restrained side offset. Let the rail dominate one diagonal edge while a gold ball remains softly in open table depth.
Composition/framing: low CAM-S1 close-up, ball and rail sharp, cue tip readable, pocket excluded unless only a soft distant clue.
Constraints: cue and ball must not intersect the cushion; no rebound line, diamond number, formula or glow.
```

### 学 08 `ballFeel` — 浅谈球感 / `coverPracticeBallFeel`

- 风格 / 镜头：母球触感主角；CAM-M1
- 参考图：R03（风格）、R06（材质）、R08（球杆）

```text
Primary request: Create an intimate felt-level photograph with the six-red-dot cue ball in crisp focus, a softly blurred cue tip entering from behind, and one distant target ball. Emphasize felt fibres, subtle ball wear and quiet depth rather than explicit instruction.
Composition/framing: CAM-M1, cue ball slightly below centre, shallow controlled focus, generous soft background.
Constraints: no magical particles, aura, motion trail, hand or abstract light sphere.
```

### 学 09 `contactPointTable` — 瞄准点对照表 / `coverPracticeContactPoint`

- 风格 / 镜头：两球接触间隙俯拍；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Show the six-red-dot cue ball and black 8-ball in an ultra-clean overhead still life, separated by a very small visible gap. Their scale, surfaces and relative offset must be the entire visual idea.
Composition/framing: tight CAM-T1 crop, two large balls at a diagonal, soft shadows and ample charcoal negative space.
Constraints: balls must not overlap; no ruler, table, labels, target dot, ghost ball or contact diagram.
```

## 7.2 理（12 张）

### 理 01 `theoryPage(t01)` — 30° 法则 / `coverPracticeT01`

- 风格 / 镜头：碰撞球对与自然前行空间；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Arrange the six-red-dot cue ball and black 8-ball as a close collision pair on charcoal, with one gold reference ball placed into an open forward-side quadrant. Use the physical spacing to suggest natural rolling separation while remaining a still life.
Composition/framing: CAM-T1, pair off-centre, broad clean space in the implied continuation direction.
Constraints: no “30”, degree sign, arc, line, arrow, repeated cue ball or physics diagram.
```

### 理 02 `theoryPage(t02)` — 90° 法则 / `coverPracticeT02`

- 风格 / 镜头：正交负空间构图；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Use a cue ball and black 8-ball as a close collision pair, with two distant coloured balls occupying visually perpendicular open directions. The composition may feel orthogonal but must remain an editorial still life rather than a geometry diagram.
Composition/framing: CAM-T1, pair near the lower third, two reference balls separated across the upper and side areas.
Constraints: no right-angle mark, axes, numeric label, dashed line or duplicated cue ball.
```

### 理 03 `theoryPage(t03)` — 切线法则 / `coverPracticeT03`

- 风格 / 镜头：偏心接触球对；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Show the six-red-dot cue ball offset beside a black 8-ball with a narrow visible gap, leaving a long clean lateral band of charcoal negative space. The offset relationship should suggest a tangential exit without drawing it.
Composition/framing: CAM-T1, tight two-ball study placed on one third, side space becomes the secondary visual element.
Constraints: no tangent line, contact marker, angle arc, multiple states or annotation.
```

### 理 04 `theoryPage(t04)` — 母球速度分级 / `coverPracticeT04`

- 风格 / 镜头：长空台呢与纵深标志球；CAM-M2
- 参考图：R01（风格）、R06（材质）、R08（球杆）

```text
Primary request: Place one six-red-dot cue ball sharp at the start of a long green-felt corridor, with three differently coloured balls at progressively deeper distances and a softly entering cue. Express speed control through spatial distance and rhythm, not motion effects.
Composition/framing: CAM-M2, strong near-to-far compression, nearest cue ball large, distant balls progressively softer.
Constraints: only one cue ball; no motion blur, speed trails, gauges, tick marks or duplicated positions.
```

### 理 05 `theoryPage(t09)` — 最少加塞原则 / `coverPracticeT09`

- 风格 / 镜头：接近中点的克制偏心；CAM-M3
- 参考图：R03（风格）、R06（材质）、R08（球杆）

```text
Primary request: Create a restrained cue-tip macro where the tip approaches the six-red-dot cue ball only slightly off centre. Let the smallness of the offset and the uncluttered composition communicate economy and control.
Composition/framing: CAM-M3, cue ball and tip large, one softly blurred target ball in depth, calm negative space above.
Constraints: the offset must be subtle; no extreme side spin, arrows, glowing dot, curved cue or path.
```

### 理 06 `theoryPage(t05)` — 反向规划 / `coverPracticeT05`

- 风格 / 镜头：终点到前置球的纵深链；CAM-M2
- 参考图：R01（风格）、R06（材质）、R07（球身份）

```text
Primary request: Build a low-angle depth chain with a black 8-ball near a softly visible corner pocket in the far depth, a gold key ball in the middle, and the six-red-dot cue ball in the foreground. The visual order should naturally lead the eye from the final ball back toward the cue ball.
Composition/framing: CAM-M2, three main anchors along a gentle diagonal, black 8 and pocket remain distinct despite depth blur.
Constraints: no numbered steps, arrows, text cards or exact route claim.
```

### 理 07 `theoryPage(t06)` — 关键球原理 / `coverPracticeT06`

- 风格 / 镜头：关键球锐利、黑 8 次级；CAM-M1
- 参考图：R02（风格）、R06（材质）、R09（袋口）

```text
Primary request: Make a gold key ball the sharp visual hero. Place the black 8-ball softly near a pocket in the background and the six-red-dot cue ball lower in the foreground. The focus hierarchy must clearly favour the key ball rather than the 8-ball.
Composition/framing: CAM-M1, gold ball at one third and fully sharp, 8-ball and pocket readable but soft, cue ball partly separated in foreground.
Constraints: do not centre the 8-ball as hero; no key icon, crown, label or arrow.
```

### 理 08 `theoryPage(t07)` — 球团管理 / `coverPracticeT07`

- 风格 / 镜头：球团与开放球对照；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Arrange three coloured object balls as a compact but non-touching cluster on one side of a charcoal surface, with one clearly isolated open ball and the six-red-dot cue ball in separate space. The contrast between congestion and access is the subject.
Composition/framing: CAM-T1, cluster off-centre, isolated ball across a clean channel, soft consistent shadows.
Constraints: not a triangle rack or break formation; no circles, route line, label or more than five balls.
```

### 理 09 `theoryPage(t08)` — 风险报酬决策矩阵 / `coverPracticeT08`

- 风格 / 镜头：困难球、障碍球与黑 8；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Create a sparse overhead still life in which a red target ball is partly screened by a blue blocker while a black 8-ball sits in a separate high-consequence area. Use unequal spacing and focus hierarchy to imply a difficult decision.
Composition/framing: CAM-T1, three object balls plus cue ball, asymmetric layout and broad charcoal negative space.
Constraints: no matrix, axes, icons, check marks, currency symbols, scores or arrows.
```

### 理 10 `theoryPage(t10)` — 安全球三维度模型 / `coverPracticeT10`

- 风格 / 镜头：障碍遮挡的低机位；CAM-M1
- 参考图：R03（风格）、R06（材质）、R07（球身份）

```text
Primary request: At felt level, hide most of the six-red-dot cue ball behind two staggered coloured blocker balls while a distant target ball remains only partially visible. The scene should clearly communicate cover, distance and difficulty through real occlusion.
Composition/framing: CAM-M1, blockers sharp in middle depth, cue ball partially visible, target ball small and soft beyond them.
Constraints: the target must not have a clean direct corridor; no shield icon, dotted line or tactical overlay.
```

### 理 11 `theoryPage(flow)` — 清台 5 步决策流程 / `coverPracticeFlow`

- 风格 / 镜头：五球节奏链；CAM-M2
- 参考图：R01（风格）、R06（材质）、R07（球身份）

```text
Primary request: Arrange five differently coloured object balls in a deliberate near-to-far diagonal rhythm, with the six-red-dot cue ball offset at the starting side and a black 8-ball as the distant final anchor. The eye should travel through the sequence naturally.
Composition/framing: CAM-M2, closest two balls crisp, later balls progressively softer, upper background calm and dark.
Constraints: no printed 1–5 labels, step arrows, flowchart styling, rack or duplicated visible ball number.
```

### 理 12 `theoryPage(quickRef)` — 清台速查手册 / `coverPracticeQuickRef`

- 风格 / 镜头：冷白器材速查静物；CAM-H1
- 参考图：R05（风格）、R06（材质）、R07（球身份）

```text
Primary request: Create a high-key product still life containing one light-maple cue, the six-red-dot cue ball, a yellow 1-ball, red 3-ball and black 8-ball. Arrange them neatly but naturally as a concise kit of core billiards decisions.
Composition/framing: CAM-H1, cue enters from upper-right, cue ball is the near hero, object balls form a compact background group, generous off-white negative space.
Constraints: no book, paper, checklist, typography, UI card or infographic.
```

## 7.3 练（6 张）

### 练 01 `geometricQuiz` — 角度预测 / `coverPracticeGeometricQuiz`

- 风格 / 镜头：可答题的稀疏三球局面；CAM-T1
- 参考图：R04（风格）、R06（材质）、R07（球身份）

```text
Primary request: Arrange the six-red-dot cue ball, black 8-ball and one gold target ball as a clear but non-obvious triangle on charcoal, leaving one large open quadrant so the image feels like a question waiting to be judged.
Composition/framing: CAM-T1, three balls large and separated, clean soft shadows, no rail required.
Constraints: no answer line, degree value, angle arc, protractor, crosshair or UI.
```

### 练 02 `sceneAiming2D` — 2D 角度训练 / `coverPracticeSceneAiming2D`

- 风格 / 镜头：近正顶视局部台呢；CAM-T1 的绿台呢变体
- 参考图：R04（构图）、R06（材质）、R09（球台）

```text
Primary request: Create a near-overhead local green-felt still life with a six-red-dot cue ball, black 8-ball and one corner pocket forming a clean three-anchor training problem. Preserve photographic materials despite the near-2D viewpoint.
Composition/framing: 80–85 degree local crop, only a short rail and pocket corner visible, balls readable at thumbnail size.
Constraints: no full table, aiming line, grid, drag handle, coordinate system or flat vector appearance.
```

### 练 03 `sceneAiming3D` — 3D 角度训练 / `coverPracticeSceneAiming3D`

- 风格 / 镜头：顺杆纵深的低机位；CAM-M3
- 参考图：R03（风格）、R06（材质）、R08（球杆）

```text
Primary request: Look down a light-maple cue toward the six-red-dot cue ball, black 8-ball and a softly visible pocket in depth. The spatial layering must feel three-dimensional and physically plausible without showing a person.
Composition/framing: CAM-M3 with moderate depth of field, cue tip separated from cue ball, target and pocket progressively softer.
Constraints: cue may not block the cue ball; no HUD, ghost ball, guide line, hand or eye.
```

### 练 04 `aimPointTraining` — 瞄准点训练 / `coverPracticeAimPoint`

- 风格 / 镜头：两球接触区域微距；CAM-M1
- 参考图：R03（风格）、R06（材质）、R07（球身份）

```text
Primary request: Show the six-red-dot cue ball and black 8-ball very close at a slight offset, both sharp around the near-contact region while their far edges fall gently out of focus. Make the physical gap itself the visual subject.
Composition/framing: low side-above macro, two balls fill the lower half, calm dark green negative space above.
Constraints: no actual overlap, red target marker, crosshair, ghost ball, line or instructional label.
```

### 练 05 `aimPointScene2D` — 2D 瞄准点训练 / `coverPracticeAimPoint2D`

- 风格 / 镜头：俯拍两球与袋口；CAM-T1 的绿台呢变体
- 参考图：R04（构图）、R06（材质）、R09（球台）

```text
Primary request: From near overhead, place the six-red-dot cue ball and black 8-ball at a readable cut relationship with one corner pocket in the local crop. Use photographic spacing and soft shadows only.
Composition/framing: 85-degree local green-felt crop, two balls near centre third, pocket away from overlay corners.
Constraints: no full table, guide line, target dot, drag handle, grid, UI or duplicate cue ball.
```

### 练 06 `aimPointScene3D` — 3D 瞄准点训练 / `coverPracticeAimPoint3D`

- 风格 / 镜头：皮头—母球—号码球近景；CAM-M3
- 参考图：R03（风格）、R06（材质）、R08（球杆）

```text
Primary request: Create a precise low-angle close-up of a cue tip, six-red-dot cue ball and black 8-ball arranged in three depth layers. Keep the target ball’s standard 8 marking readable while the cue-ball contact direction remains clear through perspective alone.
Composition/framing: CAM-M3, cue from lower edge, cue ball foreground-middle, 8-ball sharp enough in middle depth, softly dark background.
Constraints: no person, HUD, target circle, line, duplicated ball or tip penetration.
```

## 7.4 打（4 张）

### 打 01 `shotSimulation` — 分离角与走位 / `coverPracticeShotSim`

- 风格 / 镜头：三球局部碰撞与落位层次；CAM-S1
- 参考图：R03（风格）、R06（材质）、R09（球台）

```text
Primary request: Show the six-red-dot cue ball and black 8-ball as a clear local collision pair, with one gold reference ball farther into open green felt and a short rail segment providing spatial scale. The scene should feel ready to simulate but must not show the result.
Composition/framing: CAM-S1, collision pair near one third, reference ball in a separate depth layer, enough open felt around them.
Constraints: no trajectory, impact effect, target area, duplicated state, HUD or play button.
```

### 打 02 `positionPlayComposer` — 自由走位 / `coverPracticeComposer`

- 风格 / 镜头：可规划的开放散球；CAM-T1 的绿台呢变体
- 参考图：R04（构图）、R06（材质）、R07（球身份）

```text
Primary request: Arrange the six-red-dot cue ball and four differently coloured object balls in a spacious irregular composition on deep green felt. The layout should feel intentionally open to multiple plans rather than like a fixed drill.
Composition/framing: 75–85 degree local overhead crop, no more than five balls, strong negative space and soft shadows.
Constraints: no rack, preset line, numbers as sequence labels, grid, UI controls or full-table overview.
```

### 打 03 `freePlay` — 自由击球 / `coverPracticeFreePlay`

- 风格 / 镜头：自然散球的低长焦场景；CAM-M2
- 参考图：R01（风格）、R06（材质）、R07（球身份）

```text
Primary request: Create a natural post-break-feeling arrangement using the six-red-dot cue ball and five differently coloured balls spread through several depth layers. The scene should feel open and unscripted while retaining a single sharp foreground anchor.
Composition/framing: CAM-M2, cue ball or one coloured ball sharp at one third, other balls recede naturally, no complete table visible.
Constraints: not a fifteen-ball rack, no duplicated visible number, no chaotic pile, path, player or tournament setting.
```

### 打 04 `ballExtraction` — 拍照建球形 / `coverPracticeBallExtraction`

- 风格 / 镜头：带取景裁切感的不规则球局；CAM-T1 的绿台呢变体
- 参考图：R04（构图）、R06（材质）、R07（球身份）

```text
Primary request: Show a slightly imperfect real-world local ball arrangement from high above, with the six-red-dot cue ball and four standard object balls entering and leaving the crop naturally. The crop should feel observational, as if capturing an existing layout, without showing a device.
Composition/framing: 70–80 degree green-felt crop, one ball partly cropped at a side edge, remaining balls fully readable, neutral even light.
Constraints: no phone, camera body, scanner frame, corner handles, detection boxes, UI or text.
```

## 7.5 解（5 张）

### 解 01 `positionPlaySolver` — 思路训练 / `coverPracticeSolver`

- 风格 / 镜头：问题局面而非答案；CAM-S1
- 参考图：R03（风格）、R06（材质）、R09（球台）

```text
Primary request: Create a local green-felt problem containing the six-red-dot cue ball, one red target ball, one black blocker and one gold position reference, with a short rail section defining the available space. The relationship should look solvable but non-trivial.
Composition/framing: CAM-S1, four balls in distinct depth and lateral layers, rail as a secondary diagonal, one clean area left open for visual breathing room.
Constraints: show the problem only; no answer route, arrow, target zone, formula or interface.
```

### 解 02 `planThree` — 打一走二想三 / `coverPracticePlanThree`

- 风格 / 镜头：三颗顺序球的纵深链；CAM-M2
- 参考图：R01（风格）、R06（材质）、R07（球身份）

```text
Primary request: Use the six-red-dot cue ball as the near anchor, followed by three differently coloured object balls at clear successive depth layers, with a black 8-ball softly beyond as the strategic endpoint. A cue may enter subtly behind the cue ball.
Composition/framing: CAM-M2, diagonal long-lens rhythm, closest two balls sharp enough to separate, upper background calm and dark.
Constraints: no printed 1/2/3 steps, arrows, route, repeated numbers or more than five balls.
```

### 解 03 `snookerTactics` — 防守 / `coverPracticeSnooker`

- 风格 / 镜头：真实遮挡与远端目标；CAM-M1
- 参考图：R03（风格）、R06（材质）、R07（球身份）

```text
Primary request: At felt level, show the six-red-dot cue ball mostly screened by a black 8-ball and a blue blocker, while a red target ball sits distant and only partly visible through the obstruction. Make the absence of a direct corridor unmistakable.
Composition/framing: CAM-M1, blockers sharp in middle depth, cue ball partially visible behind them, distant target small and soft.
Constraints: do not reveal a clean line of sight; no shield icon, dotted path, tactical label or dramatic smoke.
```

### 解 04 `bankShot` — 翻袋解球器 / `coverPracticeBankShot`

- 风格 / 镜头：目标球、长库与角袋；CAM-S1
- 参考图：R02（风格）、R06（材质）、R09（库袋）

```text
Primary request: Show a red 3-ball as the sharp subject near a long cushion, with the six-red-dot cue ball in softer near depth and a corner pocket visible at the opposite end of the local rail. The rail must be the strongest compositional diagonal.
Composition/framing: CAM-S1, red ball at one third, cushion runs across the image, pocket kept clear of both upper overlay zones.
Constraints: no rebound path, mirror line, arrow, diamond number, full table or ball inside the pocket mouth.
```

### 解 05 `diamondSystem` — 反射解球器 / `coverPracticeDiamond`

- 风格 / 镜头：贴库母球、障碍与远端目标；CAM-S1
- 参考图：R03（风格）、R06（材质）、R09（连续库边）

```text
Primary request: Create a close local problem with the six-red-dot cue ball near a long cushion, a black blocker ball occupying the direct interior corridor, and a gold target ball farther away. Let the continuous cushion occupy one side of the frame and make the three depth layers readable without drawing the bank solution.
Composition/framing: CAM-S1, high-enough oblique angle to read the obstacle relationship, rail as a strong diagonal, cue ball large enough for thumbnail scale.
Constraints: no diamond labels, formula, reflected line, arrows, cue-direction claim, full table or extra ball.
```

## 8. 12 张自定义计划模板（非内容语义卡）

`coverTemplate01`–`coverTemplate12` 通过 hash 池供用户自定义计划复用，它们没有固定课程真源。
因此模板只变化静物构图，不绑定训练结论。每条仍拼接第 5 节公共系统提示词。

| 资源键 | 镜头 | 参考图 | 专属提示词 |
|---|---|---|---|
| `coverTemplate01` | CAM-H1 | R05, R06, R08 | One six-red-dot cue ball and a light-maple cue on cool off-white, minimal beginner-friendly still life. |
| `coverTemplate02` | CAM-M1 | R03, R06 | Cue ball hero on deep green felt with one gold ball softly behind, broad negative space. |
| `coverTemplate03` | CAM-M1 | R02, R06, R07 | Black 8-ball hero with cue ball and one red ball separated in depth. |
| `coverTemplate04` | CAM-T1 | R04, R06 | Three standard balls forming a spacious asymmetric triangle on charcoal. |
| `coverTemplate05` | CAM-T1 | R04, R06, R07 | Cue ball, black 8 and gold ball aligned with large charcoal negative space. |
| `coverTemplate06` | CAM-H1 | R05, R06, R07 | Black 8-ball hero and two coloured balls on a cool off-white studio surface. |
| `coverTemplate07` | CAM-M2 | R01, R06 | Cue ball followed by four softly receding coloured balls on deep green felt. |
| `coverTemplate08` | CAM-T1 | R04, R06 | Four-ball gentle arc on charcoal with soft directional shadows. |
| `coverTemplate09` | CAM-S1 | R03, R06, R09 | One coloured ball near a quiet rail and pocket, cue ball softly in depth. |
| `coverTemplate10` | CAM-M3 | R03, R06, R08 | Cue-tip and cue-ball macro with one target ball in soft depth. |
| `coverTemplate11` | CAM-S1 | R02, R06, R09 | Black 8-ball, rail and pocket close-up with controlled dark green background. |
| `coverTemplate12` | CAM-M1 | R03, R06, R07 | Balanced cue-ball hero with black and gold balls creating a clean depth rhythm. |

模板共用追加约束：`Do not imply a specific drill, answer, level, or numbered sequence.`

## 9. 生成批次与验收顺序

### 9.1 Gate A：四张风格锚点

先只生成以下四张，覆盖四种舞台；未通过前不扩批：

1. `coverPlanBeginner`：CAM-H1，高调入门；
2. `coverPlanAccuracy`：CAM-M1，深绿微距；
3. `coverPracticeSeparationAtlas`：CAM-T1，石墨俯拍；
4. `coverPracticeDiamond`：CAM-S1，库边问题局面。

每张单独生成，不做 2×5 联系表。四张通过后把批准版本复制到新的 `approved/` 目录，并记录
SHA-256；只有这些批准版本可作为后续同类卡的附加风格锚点。

### 9.2 Gate B：计划卡 12 张

按 P01–P12 单张生成。每张先检查主题识别，再检查球数量/身份和镜头，最后放入真实计划卡壳。
计划 initial 只作内容参考，不应被模型直接裁成封面。

### 9.3 Gate C：练习卡按栏目扩批

顺序：学 9 → 理 12 → 练 6 → 打 4 → 解 5。每完成一个栏目先做该栏目联系表与真实 App
试装，再进入下一栏目；禁止一次生成 36 张后统一返工。

### 9.4 Gate D：自定义模板

模板最后生成。模板不得抢夺官方计划或练习入口的独特主构图；同一用户的多个自定义计划同时出现时，
12 张模板必须能在缩略图中区分，但仍属于同一摄影系统。

## 10. 单张验收清单

### 10.1 文件与卡片

- [ ] 最终为 1600×1200、4:3、sRGB。
- [ ] 真实卡片使用 `scaledToFill` 后没有关键主体被裁掉。
- [ ] 叠加 12% 中性黑幕后，母球、主角球和库袋关系仍清楚。
- [ ] 左上编号区与右上 Pro 区没有关键球、皮头或袋口。
- [ ] 524×393 px 检查图中，主题无需读标题也能大致区分。

### 10.2 品牌一致性

- [ ] 台呢是深自然绿而非蓝绿 / 荧光绿。
- [ ] 暗场保留中间调；没有酒吧霓虹、烟雾或橙青调色。
- [ ] 石墨与冷白舞台使用同一球面高光、阴影软硬度和白平衡。
- [ ] 胡桃木纹理低对比，不出现花梨瘤纹、红漆或夸张镜面。
- [ ] R00 只用于并排目视，封面进入现有 App 后不显得像另一个品牌。

### 10.3 语义与物理边界

- [ ] 球数与专属提示词一致；六点红母球没有变成普通白球或多颗母球。
- [ ] 需要黑 8 时，号码面、黑色和尺寸合理；其他指定号码遵循标准球色。
- [ ] 球均落在平面上，有一致接触阴影；没有漂浮、相交或陷入库边 / 袋口。
- [ ] 球杆不穿球、不穿库、不弯曲；皮头大小合理。
- [ ] 没有轨迹、角度、定位点、标尺或结果性图形。
- [ ] 封面只表达主题，不被当作真实球形、答案或教学物理证据。

### 10.4 多图系统性

- [ ] 48 张只有 CAM-M1/M2/M3/T1/H1/S1 六套镜头语法，没有私自发明第七套风格。
- [ ] 同一栏目连续卡片至少在主角、景别或空间参照之一显著不同。
- [ ] 同一镜头族使用相同主要风格参考，不引用未批准生成图。
- [ ] 高调图、石墨图和深绿图在 Light/Dark App 中都经过真实尺寸并排检查。

## 11. 生成记录模板

每张生成后在同目录另建机读台账时至少记录：

```yaml
assetKey: coverPlanBeginner
sourceId: plan_beginner
promptSpec: docs/design/20260902-card-cover-prompt-system-v1.md#p01-plan_beginner--基本功--coverplanbeginner
cameraTemplate: CAM-H1
references:
  - R05
  - R06
  - R08
  - QiuJi/Resources/DrillTutorials/drill_c012_initial.png
generationMode: built-in-imagegen
status: draft
outputPath: null
sha256: null
cardFitLight: pending
cardFitDark: pending
humanDecision: pending
```

## 12. 当前未决事项

1. 四类风格锚点尚未生成并经人工裁定，因此本文件是**可执行提示词规格**，不是最终视觉批准。
2. 用户提供的 R01–R05 仅能作为视觉参考，来源许可未确认，不得直接发布。
3. ImageGen 对球号、密集球列和精确遮挡仍可能漂移；生成通过不等于语义通过。
4. 本轮不替换 `QiuJi/Resources/Assets.xcassets/Atmosphere/`，也不修改 `AtmosphereCatalog`。
