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

## 图文精讲「应用课」模板（ADR-P11-14 / DR-019，样板：drill_c042）

> 实际写精讲请用专职子智能体 `tutorial-writer`（`.cursor/agents/tutorial-writer.md`）+
> 技能 `tutorial-authoring`：先跑 `scripts/tutorial_digest.py` 从序列 JSON 确定性提取几何事实，
> 再按模板组织语言，几何零脑算。本节保留为模板真源。

> 适用：**多杆走位/清台类** drill（内容来自走位编排台录制的序列）。
> 单技术点 drill（高杆/低杆/分离角等）保持经典四段结构（技术原理/动作要领/常见错误与纠正/进阶练习）不变。

### Section 骨架（固定顺序）

| # | title | 容器 | 配图 |
|---|-------|------|------|
| 1 | `技术原理` | content（理论锚点，1–2 段） | 无 |
| 2 | `开局与击球顺序` | content（布局 + 顺序规划逻辑——顺序和袋口是一起规划的） | `<id>_initial` + caption |
| 3..N | `第N杆：X号球 · 袋口` | **items + params**，content 留 `""` | `<id>_sNN`（带 HUD 静帧）+ caption |
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

| 产物（`build/position_play_export/seq_<id8>/`） | 落位 | 命名 |
|---|---|---|
| `initial.png` | `Resources/DrillTutorials/` | `<drillId>_initial.png` |
| `sNN_still.png`（带 HUD） | `Resources/DrillTutorials/` | `<drillId>_sNN.png` |
| `full.mp4`（2D 顶视 1440×2720@60 带 HUD） | `Resources/Videos/<drillId>/` | `full.mp4`，JSON `videos: [{id:"full", file:"full.mp4"}]` |
| `full_3d.mp4` / `sNN_3d.mp4`（3D 斜视角手机档 1440×2720@60 带 HUD，ADR-P11-15） | OTA（`Resources/Videos/<drillId>/` 临时） | `full_3d.mp4`，JSON `videos:` 追加 `{id:"full3d", file:"full_3d.mp4"}` |
| `full_3d@2160.mp4`（3D 高分档 4K 2160×4080@60） | 外站备用（不进 Bundle） | `full_3d@2160.mp4` |
| 缩略图 | 跑 `DrillThumbnailBakeRunnerTests` 重烘焙 | `<drillId>.png` |

### 序列 → drill 接入清单（每条都做）

1. `shotIntent` 换为序列真实逐杆（cue/target 取该杆 `before`，spin/velocity/pocket 照抄，其余在桌球进 `obstacles`）；`animation` 用首杆数据（`source: "composer"`）。
2. 媒体按上表落位；`description`/`standardCriteria`/`sets` 与序列杆数对齐。
3. 精讲按本模板写；打点读数口径=占打滑极限百分比（`SpinDisplay.readout` 同源）。
4. 验证：JSON 可解码 + 缩略图重烘焙 + 模拟器/UI 测试截图核验精讲逐节渲染。

### ⛔ 红线

- 示范击球**以编排台人工录制为准**；禁止从存量 `shotIntent` 批量反推生成序列（用户拍板：存量数据精度不可靠，2026-06-13）。
- 精讲文案与示范击球必须一致（文案说「留角度」示范却打直线球＝内容缺陷，写完用序列数值复核一遍）。

## 多球形精讲 + 配图选用（ADR-P12-02，2026-06-18）

> 适用：**一个 drill 含多个不同摆球布局（球形）**，每个球形是一段独立小教学。单球形 drill 不受影响（继续用 `tutorial.sections`）。

### 多球形：精讲隔离用 `tutorial.formations`

- `tutorial.sections` 与 `tutorial.formations` **二选一**。多球形把 `sections` 改为 `formations: [{ id, title, sections:[…] }]`，每个球形一段隔离精讲；App 顶部用**吸顶分段控件**切换，复用同一套 section 渲染。
- `title` 是分段标签（短，例「球形 A：薄切走位」）。`id` 稳定（`f1`/`f2`…）。
- **视频/gif 不强制隔离**：视频按顺序排在详情页 `videos[]` 即可；gif 拼接成一段后转 mp4。详情页球台预览只画**第一个/代表性球形**（多球形完整展示集中在精讲页）。

### 每节配图：PNG 海报 + 可选 mp4 片段

每个视觉素材 = 一张静态 PNG 海报（`image`，兜底）+ 可选动态片段（`clip`，mp4）。**选用规则（按节目的）**：

| 讲什么 | 用什么 | 理由 |
|--------|--------|------|
| 位置 / 几何 / 落点区域（开局布局、落点示意、错位对比） | 只配 `image`（带标注 PNG） | 可标注、可全屏放大研究；滚动页不分心 |
| 运动 / 走位 / 杆法效果（母球怎么走、分离角、跟缩杆滚动） | `image` 海报 + `clip` | 时间维度信息，定格会丢关键 |
| 纯概念 / 纯文字（技术原理、进阶练习） | 不配图 | — |

- App 行为：海报上有 `clip` 时显示**播放角标**，点击进**全屏看图组件**（图集左右翻页 + 捏合/双击缩放 + 下滑关闭；`clip` 静音循环播放）。
- **gif → mp4**：产出的 gif 一律转**静音循环 mp4**（H.264/HEVC，体积小、硬件解码），落 `Resources/DrillTutorials/<clip>.mp4`；`clip` 字段填不含扩展名的文件名（与 `image` 同约定）。
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

- 6套计划 ID：`plan_beginner` / `plan_cueball` / `plan_positioning` / `plan_intermediate` / `plan_advanced` / `plan_fullskill`
- 每套计划的 `drillId` 必须已存在于 `index.json`（不能引用不存在的 Drill）
- `isPremium: false` 仅限前两套（`plan_beginner`、`plan_cueball`），其余为付费

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
