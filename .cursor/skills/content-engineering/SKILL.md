# Content Engineering Skill

## 触发场景

在以下情况读取并遵循本技能：
- 生成 Drill JSON 内容文件
- 定义或调整 Drill JSON Schema
- 生成官方训练计划 JSON
- 验证内容数据合理性
- 编写/迁移图文精讲（`tutorial`），尤其是走位序列类的「应用课」精讲

## 坐标系协议

> 完整物理参数见 `.kiro/steering/table-geometry.md`。

### Canvas 归一化坐标（Drill JSON 使用）

- **原点**：SceneKit `(−1.270, −0.635)` 对应 Canvas `(0, 0)`
- **X 轴**：随 SceneKit `+X` 增（0.0–1.0）
- **Y 轴**：随 SceneKit `+Z` 增（0.0–0.5）
- **单位**：台面**长度**（innerLength = 2.540 m）的百分比
- **宽高比**：2:1（width × 0.5 = height）
- **用户方位**：Drill 为 portrait 屏幕系，袋口中文名必须按 `.kiro/steering/table-geometry.md` 的 schema ID 映射，不按 Canvas 图面直觉命名。

### 从 SceneKit 物理坐标转换

```
canvasX = (sceneKitX + 1.270) / 2.540
canvasY = (sceneKitZ + 0.635) / 2.540
```

示例：
- 球桌中心 SceneKit (0, 0) → Canvas (0.5, 0.25)
- 其余坐标直接使用上式计算；袋口渲染坐标与用户可见名称查下方唯一真源，不另存示例值。

### 有效击球区范围

JSON 中母球和目标球初始位置**必须**在以下范围内（不含库边）：

```
X ∈ [0.0197, 0.9803]   （库边宽 0.0197 = 0.050/2.540）
Y ∈ [0.0099, 0.4901]   （库边高 = 0.050/2.540 × 0.5）
```

### 袋口参考坐标（用于路径终点校验）

袋口坐标、schema ID 与 portrait 用户名只认 `.kiro/steering/table-geometry.md` 的当前表；本技能不复制，避免再次产生方向分叉。

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

### `shotIntent` 与引擎烘焙（P10，ADR-P10-01，推荐路径）

手画 `animation` 物理不可信。新内容**优先**用「击球意图」描述，由物理引擎离线烘焙出精确轨迹回填 `animation`：

```json
"shotIntent": {
  "version": 1,
  "shots": [
    {
      "cue": {"x": 0.5, "y": 0.25},
      "target": {"x": 0.5, "y": 0.43},
      "pocket": "bottomCenter",
      "velocity": 2.4,                  // 连续 m/s（精准走位用连续值，不用 5 档枚举）
      "spin": {"x": 0.0, "y": 0.0}       // x:+左/−右，y:+高杆/−低杆，∈[-1,1]，可选
    }
  ]
}
```

**作者 SOP**：① 写 `shotIntent`（摆球+选袋+连续 velocity+塞），不写轨迹；② 把 drill id 加入 `QiuJiTests/DrillBakeRunnerTests` 试点列表跑测，控制台在 `===BAKE …===` 标记间打印烘焙后的 `animation` JSON + 可达校验行；③ 把烘焙 `animation`（`source:"baked"`）拷回 JSON；④ 确认 `feasible=✅`（`sim 进选定袋=⚠️` 属 P10 jaw 标定遗留、不阻断）。坐标系与上文归一化系一致；烘焙用 USDZ 对齐球桌 `chineseEightBallQiuJi`。详见 `Resources/Drills/schema.md` § ShotIntent。

## 8大类分类表

| category | nameZh | 典型 Drill |
|----------|--------|-----------|
| `fundamentals` | 基础 | 站架、握杆、瞄准线 |
| `accuracy` | 准度 | 直线球、五分点、角度入袋 |
| `cueAction` | 杆法 | 高杆、低杆、斯登、加塞 |
| `separation` | 分离角 | 分离角控制、薄球分离 |
| `positioning` | 走位 | 一库走位、多库走位 |
| `forceControl` | 控力 | 强力高杆、软打控位 |
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

## 图文精讲「应用课」模板（ADR-P11-14 / DR-019，样板：drill_c042）

> 实际写精讲请用专职子智能体 `tutorial-writer`（`.cursor/agents/tutorial-writer.md`）+
> 技能 `tutorial-authoring`：先跑 `scripts/tutorial_digest.py` 从序列 JSON 确定性提取几何事实，
> 再按模板组织语言，几何零脑算。本节保留为模板真源。

> 适用：现网已统一为应用课骨架（技术原理 → 开局与击球顺序 → 第N杆 → 常见错误与纠正 → 进阶练习）。
> 走位链与单技术点阶梯（高杆/低杆/分离角/准度等）共用此骨架，深度按 `docs/research/20260818-v40-概念所有权表.md` 的引入/后续/合成分档，⛔ 不再走「技术原理 / 动作要领 / 常见错误 / 进阶」四段旧模板。
> 无逐杆的基本功身体课（握杆/手架等）栏目可以是「动作要领」，仍不重写已引入的切角/杆法定义。

### Section 骨架（固定顺序）

| # | title | 容器 | 配图 |
|---|-------|------|------|
| 1 | `技术原理` | content（理论锚点，1–2 段） | 无 |
| 2 | `开局与击球顺序` | content（布局 + 顺序规划逻辑——顺序和袋口是一起规划的） | `<id>_initial` + caption |
| 3..N | `第N杆：X号球 · 袋口` | **items + params**，content 留 `""` | `<id>_sNN`（预告线 + 瞄准位球杆 + HUD）+ caption |
| N+1 | `常见错误与纠正` | **items**（label=错误名，2–4 条） | 可选 |
| N+2 | `进阶练习` | content（降阶 + 升阶各至少一个方向） | 无 |

### 逐杆节写法（写作公式：为什么 → 怎么打 → 自检）

- `params`：`{spinX, spinY, velocity}` **照抄序列 JSON 该杆数值**（渲染为真实比例打点图标 + 读数 + 力度胶囊，与导出 HUD 同口径）。
- `items` 三条，label 固定（渲染有专属配色）：
  - `为什么`：杆法选择的原因 + 母球落点要为下一杆创造什么（理论在具体局面的复用）。
  - `怎么打`：动作要领（打点用「皮头」等身体语言描述，**不重复 params 已展示的数字**）；有反直觉物理现象（如短距离高杆偏切线）在此点破。
  - `自检`：母球应停的区域 + 失败征兆（「若停在 X 则说明 Y 偏了」）。落点描述**必须从序列 JSON 的 after 快照数值推导**，禁止凭渲染图脑估（几何技能铁律）。
- `content` 支持 `\n\n` 分段 + `**加粗**`（inline markdown）；caption 一句话概括该图。

### 媒体配套（序列出片 → 资源目录）

回填入口：`scripts/import-engine-export-to-app.py`（D-v25-6：**改脚本落位名，不改 JSON
`image`**）。引擎出片保留 `sNN_still.png`；脚本落位时去掉 `_still`，与下表及
`schema.md`「Tutorial image naming」一致。幂等：同一导出目录重跑，目标文件名不变。

| 产物（`build/position_play_export/<exportDir>/`） | 落位 | 命名 |
|---|---|---|
| `initial.png` | `Resources/DrillTutorials/` | `<drillId>_initial.png` |
| `sNN_still.png`（预告线 + 瞄准位球杆 + HUD） | `Resources/DrillTutorials/` | `<drillId>_sNN.png`（⛔ 不得落成 `_sNN_still`） |
| `final.png` | `Resources/DrillTutorials/` | `<drillId>_final.png` |
| `full.mp4`（2D 顶视 1080×2040@60 带 HUD） | `Resources/Videos/<drillId>/` | `full.mp4`，JSON `videos: [{id:"full", file:"full.mp4"}]`（引擎片已于 v25 下线，字段预留真人示范） |
| `full_3d.mp4`（3D 斜视角手机档 1080×2040@60 带 HUD，ADR-P11-15） | 本地预览 / 后续 OTA | `full_3d.mp4`，JSON `videos:` 追加 `{id:"full3d", file:"full_3d.mp4"}` |
| 多序列 `__<token>` | 同上，文件名加 token 中缀 | `<drillId>_<token>_sNN.png`；**`manual01` 额外写无前缀别名**（JSON 默认取 manual01，见 `schema.md`） |
| 缩略图 | 跑 `DrillThumbnailBakeRunnerTests` 重烘焙 | `<drillId>.png` |

校验：`python3 scripts/verify_tutorial_images.py`（总引用 / 失效数 / 按 drill 清单；有失效则 exit 1）。
存量磁盘若仍带 `_still` / `manual01` 前缀分叉：先跑幂等脚本
`python3 scripts/align_tutorial_image_names.py`（只改文件名，不改 JSON；与 import 脚本分工见该文件头注释）。

### ⚠️ 序列更新后必跑：全链路同步校验

`make verify-tutorials`（= `scripts/verify_tutorial_sync.py`）。上面的 `verify_tutorial_images.py`
只回答「引用的文件在不在」，**答不出「图是不是当前序列产出的」**——2026-08-03 实测正是这个盲区
让 c042 精讲长期混用两代资产（`initial` 来自 8 月 8 杆序列，`s01`–`s03` 是 6 月 3 杆序列的残留），
且 23 条精讲停留在已废弃的旧球形上无人发现。四段检查：

| 检查 | 回答的问题 | 典型失败 |
|---|---|---|
| C1 出片新鲜度 | 产物是不是拿当前 JSON 渲的 | 改了序列没重出片 |
| C2 回填一致性 | 磁盘图是不是当前产物 | 多球形各自的 `sNN_still` 争抢同名，后写覆盖先写 |
| C3 引用指向 | 引用命中的是不是最新那张 | 旧 `X.png` 与新 `X_still.png` 并存，引用命中旧的 |
| C4 结构对齐 | 精讲杆数 / 球形数是否等于序列 | 序列升级到多杆，精讲还停在 1 杆 |

**红线**：序列 JSON 有任何改动后，出片、回填、精讲三者必须同批跟进并跑本校验；
只改序列不跟进＝制造新的漂移。C4 对 legacy（无逐杆节）与无序列 drill 只提示不判失败，
故它变绿是可达目标，不得因「本来就红」而跳过。

### 已接门禁（2026-08-07 v29 W9）

同一脚本另有四项不变量（契约 §7）：**I5** 精讲球形 token ⊆ 序列 token、
**I7** profile vs 序列（容忍 `"retired": true`）、**I8** `DrillBoards` 按字节 ⊆ 上游序列、
**I9** `index.json` 登记的 drill 序列覆盖。

| 命令 | 用途 |
|---|---|
| `make verify-tutorials` | 全量校验，C4 也计入退出码 |
| `make verify-gate` | 门禁入口（git `pre-push` 调用），C4 为已知豁免 |
| `make install-hooks` | 装 `pre-push` 钩子（每个克隆一次） |
| `make invariant-selftest` | 构造性用例，证明每个检查项真会报错 |

基线与豁免唯一真源：`scripts/content_invariant_baselines.json`（棘轮，只许收紧；
改它前先在契约 §8 登记解除条件）。纪律细则见 `40-content-engineer.mdc` § PD-028。

### 序列 → drill 接入清单（每条都做）

1. `shotIntent` 换为序列真实逐杆（cue/target 取该杆 `before`，spin/velocity/pocket 照抄，其余在桌球进 `obstacles`）；`animation` 用首杆数据（`source: "composer"`）。
2. 媒体按上表落位；`description`/`standardCriteria`/`sets` 与序列杆数对齐。
3. 精讲按本模板写；打点读数口径=占打滑极限百分比（`SpinDisplay.readout` 同源）。
4. 验证：JSON 可解码 + 缩略图重烘焙 + 模拟器/UI 测试截图核验精讲逐节渲染。

### ⛔ 红线

- 示范击球**以编排台人工录制为准**；禁止从存量 `shotIntent` 批量反推生成序列（用户拍板：存量数据精度不可靠，2026-06-13）。
- 精讲文案与示范击球必须一致（文案说「留角度」示范却打直线球＝内容缺陷，写完用序列数值复核一遍）。
- **跨 drill（v40）**：写或改 `tutorial` 前读 `docs/research/20260818-v40-概念所有权表.md`。引入课 `技术原理` = 五问自然段；后续课 = 前置句 + 本课新层；合成课（走位链/综合/特殊）只写玩法新层，禁止改回阶梯腔。完整 ≠ 每形再上一遍入门课。细则以 `tutorial-authoring` SKILL「跨 drill：引入课五问」为准。
- **学员可见语域 / 距离（D-v40-8 / D-v40-9）**：按类型改，不是封闭词表（分析腔、半生口头语、教材腔、机械复读腔、球房不会这么说的计量都要改）。台面距离不上「颗球」：≤50 公分用 5 的倍数公分，更远用约 X.X 米。球厚「半颗」可留。换算与公式见 `tutorial-authoring` SKILL。写作语义以 `docs/research/20260818-v40-精讲内容规范.md` v2 为准（中间档可留空、正文不报度数、自检不抄静帧）。

## 多球形精讲 + 配图选用（ADR-P12-02，2026-06-18）

> 适用：**一个 drill 含多个不同摆球布局（球形）**，每个球形是一段独立小教学。单球形 drill 不受影响（继续用 `tutorial.sections`）。

### 多球形：精讲隔离用 `tutorial.formations`

- `tutorial.sections` 与 `tutorial.formations` **二选一**。多球形把 `sections` 改为 `formations: [{ id, title, sections:[…] }]`，每个球形一段隔离精讲；App 顶部用**吸顶分段控件**切换，复用同一套 section 渲染。
- `title` 是分段标签（短，例「球形 A：薄切走位」）。`id` 稳定（`f1`/`f2`…）。
- **视频/gif 不强制隔离**：视频按顺序排在详情页 `videos[]` 即可；gif 拼接成一段后转 mp4。详情页球台预览只画**第一个/代表性球形**（多球形完整展示集中在精讲页）。
- **跨 drill / 多形完整（v40）**：每形骨架仍完整（本形练什么、怎么摆、怎么打/验、会错在哪），但后续形用一句体感差 + 自带参照，不用「与球形 1 共享/变了/为何」三问答；深度看所有权表角色，不在每形重写引入课五问。

### 每节配图：PNG 海报 + 可选 mp4 片段

每个视觉素材 = 一张静态 PNG 海报（`image`，兜底）+ 可选动态片段（`clip`，mp4）。**选用规则（按节目的）**：

| 讲什么 | 用什么 | 理由 |
|--------|--------|------|
| 位置 / 几何 / 落点区域（开局布局、落点示意、错位对比） | 只配 `image`（带标注 PNG） | 可标注、可全屏放大研究；滚动页不分心 |
| 运动 / 走位 / 杆法效果（母球怎么走、分离角、跟缩杆滚动） | `image` 海报 + `clip` | 时间维度信息，定格会丢关键 |
| 纯概念 / 纯文字（技术原理、进阶练习） | 不配图 | — |

- App 行为：海报上有 `clip` 时显示**播放角标**，点击进**全屏看图组件**（图集左右翻页 + 捏合/双击缩放 + 下滑关闭；`clip` 静音循环播放）。
- **gif → mp4**：产出的 gif 一律转**静音循环 mp4**（H.264/HEVC，体积小、硬件解码），落 `Resources/DrillTutorials/<clip>.mp4`；`clip` 字段填不含扩展名的文件名（与 `image` 同约定）。落位后跑 `make tutorial-figures` 才会搬进打包目录（见下）。
- **母版 ≠ 进包（v25 D-v25-14）**：上表落位的 `Resources/DrillTutorials/` 是**母版目录**，不进包不进 git。进包的是 `Resources/TutorialFigures/`（仅被精讲 `image`/`clip` 引用者，PNG 压成 HEIC q70），由 `make tutorial-figures` 生成。⛔ 写完精讲改了 `image` 引用就必须重跑，否则 App 里缺图；`make verify-gate` 会拦。
- 详情页的「视频示范」仍承担全程演示；精讲的 `clip` 只放**针对性短片段**，别重复全程。

## Freemium 分配目标

| Level | 免费比例 | 付费比例 |
|-------|---------|---------|
| L0 | 100% | 0% |
| L1 | ~70% | ~30% |
| L2 | ~40% | ~60% |
| L3 | ~20% | ~80% |
| L4 | ~10% | ~90% |

## 官方训练计划生产要点

- **10 套计划 ID**（`Plans/index.json`）：
  - 综合/主线：`plan_beginner` / `plan_cueball` / `plan_positioning` / `plan_intermediate` / `plan_advanced` / `plan_fullskill`
  - 专项（v22）：`plan_accuracy` / `plan_force` / `plan_separation` / `plan_english`
- 每套计划的 `drillId` 必须已存在于 Drills `index.json`（不能引用不存在的 Drill）
- **Freemium（D-v22-1）**：`isPremium: false` = `plan_beginner`、`plan_cueball`、**`plan_accuracy`（准度专项）**；其余（含力度/分离角/加塞专项与既有综合付费套）为 `true`
- `plan_advanced`：docs 称「高级综合（多库/防守占位）」；加塞主路径是 `plan_english`，勿与之混名（D-v22-5）

## 内容体系三 SOP（ADR-P12-01，2026-06-14）

> 配套：课程地图 `tasks/curriculum-map.md`（完备真源）+ 理论编号 `16.billiard_theory/contracts/`。

### SOP-A 理论引用「三层渐进式披露」（⛔ 禁教材腔）

精讲挂理论**绝不写「根据 T03 切线法则……」**（教材腔，破坏教练感）。统一三层：

| 层 | 形态 | 来源 |
|---|------|------|
| 1 教练话 | 精讲正文用人话把原理说成"就是这样"（如"母球击球瞬间总先沿切线走，之后被旋转拉弯"＝T03，**不出现编号**） | 作者写 |
| 2 一句话 | 轻触正文 → 弹定理 `statement_one_liner`（≤60字） | 16 `theorem-tags.json` 现成 |
| 3 完整页 | 再点 → 理论详情页 | 16 `doc_path` |

数据层分工：`theoremIds`/`moduleIds` 是**给机器的标签**（导航/错题分析/筛选），**不进正文措辞**；链接以"安静的可点 chip/下划线"出现。横轴类别→定理绑定查 `curriculum-map.md` §2，不逐条拍脑袋。

SOP-A 仍要做，但**不够当引入课**（v40 R5）：概念第一次出现时，`技术原理` 按所有权表机制卡五问写，不能只留一句翻译。详见 `tutorial-authoring` SKILL「跨 drill：引入课五问」。

### SOP-B 社媒/竞品「拿球形 idea，不拿片段」

避免闭门造车补经验，但**产品里不出现原视频**（版权/拒审红线）。流程：

```
刷到好教学视频 → 提取「球形 + 教学点」(idea) → 编排台复刻成击球序列 → 引擎生成干净示范+HUD
```

三角验证给每条 drill 出处：球形来自真人（非拍脑袋）、正确性锚 16 理论（Tier1/2 源 > 随机网红）、可达性引擎验证。采集**有界**：绑定 `curriculum-map.md` 待填格子，禁开放式囤积；接 16「教学知识库」轨道不重复。`球形来源` 记入地图单元格条目。

### SOP-C 理论配图三类（成本递增，非白嫖 drill 出片）

| 类型 | 适用定理 | 管线 |
|---|---|---|
| 1 标注图/交互场景 | T01–T03/T09 | **复用** `AngleTrainingScene`（假想球/切角弧/α°）或内嵌交互场景——近零成本 |
| 2 参数扫描叠加 | T01/T02/T04（切角扫描偏折恒定 / 9 档速度走位线叠加） | **需新增** sweep+多轨迹渲染模式（阶段2）|
| 3 战术/决策图 | T05–T08/T10/M01–M06/5步流程 | 多杆走位用编排台；布局/流程/矩阵=平面设计图，非引擎 |

## Changelog

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.6 | 2026-08-30 | 清除 DR-063 前遗留的反向 canvasY 公式；坐标、袋口 ID 与 portrait 用户名统一引用 `table-geometry.md`。 |
| v1.5 | 2026-08-26 | 动作库类别短名：基础 / 准度 / 杆法 / 走位 / 控力。货架序：基本功→准度Ⅰ→准度Ⅱ→力度→杆法Ⅰ→杆法Ⅱ→准度Ⅲ→分离角→走位Ⅰ→走位Ⅱ→特殊球→全能精选。 |
| v1.4 | 2026-08-24 | DR-074：`sNN_still` 与视频亮方案拍对齐，有预告线则摆瞄准位球杆。 |
| v1.3 | 2026-08-18 | 红线指向精讲内容规范 v2（中间档可留空 / 正文不报度数 / 自检不抄静帧）。来源：问题集合 v40.9。 |
| v1.2 | 2026-08-18 | 红线补 D-v40-8 语域类型规则 + D-v40-9 距离公分/米。来源：问题集合 v40.5。 |
| v1.1 | 2026-08-18 | 应用课模板：删除过时「单技术点保持四段结构」句，改为与现网统一骨架 + 所有权表分档。红线与多形节对齐 v40 跨 drill（引入课五问 / 后续课新层 / 合成课禁改回阶梯腔）。SOP-A 补「不够当引入课」。来源：问题集合 v40.3 W0。 |
