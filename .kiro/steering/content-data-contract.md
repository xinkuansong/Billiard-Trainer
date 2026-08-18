# 内容与训练数据 — 真源契约与数据流（Steering）

> **版本**：2.12（v39 W2：I13 ① 改为建议周下界）
> **最后更新**：2026-08-18
> **地位**：本文件是「内容资产真源归属、标识符命名、数据流向、用户训练数据口径」的**唯一契约来源**。
> 其余文档（`QiuJi/Resources/Drills/schema.md`、`content/position_play/README.md`、
> `docs/06-技术架构.md`）在与本文件冲突时**以本文件为准**，并应改为引用本文件而非重复定义。
>
> **本文件不是现状快照。** 描述性事实集中在 §8 现存偏差登记，会随收敛而清空；
> §1–§7 是约束，变更需走 ADR。

---

## 〇 为什么需要这份文件

同一个概念在本项目中曾出现多个真源并各自演化，已造成可验证的偏差：

> **§〇 的历史陈述已部分被 §7.1 / v26 消化取代**：下面第 1–2 条曾描述的 profile 孤儿与
> C4 长期 FAIL，已于 v26（W0 profile 退役、W2–W12 精讲迁移、W13 C4 转阻塞）销账；
> 其余不变量已由 `pre-push` 钩子阻塞。本节保留为立档动因。

- 「球形」同时存在于 `content/drill_profiles/*.profile.json`、drill JSON 的
  `tutorial.formations`、`content/position_play/sequences/*.json` 三处，
  立档时 **11/11 个 profile drill 的三者不一致**（已消化，见 ~~§8.1~~）。
- `make verify-tutorials` 的 C4 检查曾长期 FAIL 且非阻塞门禁（已消化：v26 W13 转阻塞，见 ~~§8.2~~）。
- `docs/06-技术架构.md` 描述的 `AngleTestSession / AngleQuestion` 结构在代码中
  **从未存在**（实际只有扁平的 `AngleTestResult`）——文档独立漂移的既成案例。

因此本文件的价值排序是：**裁定真源 > 定义可执行不变量 > 描述现状**。

---

## 一 真源裁定

| 数据 | 唯一真源 | 派生物（禁止手改） | 生成方式 |
|---|---|---|---|
| 球形几何（摆球 + 逐杆意图） | `content/position_play/sequences/*.json` | `QiuJi/Resources/DrillBoards/`、出片产物、缩略图 | 走位编排台**人工录制** |
| 出片产物（视频/静帧/预览帧/封面） | `build/position_play_export/` | `Resources/{Videos,DrillTutorials,Previews}` | `make position-export` → `import-engine-export-to-app.py` |
| 精讲配图**发布图**（进包的那一份） | `Resources/DrillTutorials/*.png`（母版） | `Resources/TutorialFigures/*.heic` + `content/tutorial-figures-manifest.json` | `make tutorial-figures`（`publish_tutorial_figures.py`，回填后自动跑）|
| 列表缩略图 | 序列文件（经渲染） | `Resources/DrillThumbnails/*.png` | `DrillThumbnailRenderer` 离线烘焙 |
| Drill 元信息与精讲文本 | `QiuJi/Resources/Drills/*/*.json` | — | 人工撰写 |
| 训练计划 | `QiuJi/Resources/Plans/*.json` | — | 人工撰写 |
| 球桌几何常量 | `.kiro/steering/table-geometry.md` | — | — |
| 用户训练数据 | 设备 SwiftData | 后端 MongoDB 副本 | App 写入 + `BackendSyncService` 推送 |

### 1.1 球形几何真源 = 出片台录制序列（2026-08-06 用户裁定）

**用户拍板**：以批量出片台产出的序列为准；精讲内容等出片台内容定稿后统一重写。

这条裁定与既有红线一致，并追认了 `8293ef4`（`content: retire legacy initial-only
sequences in favour of manual recordings`）的既成事实——该提交全库退役了脚本推导的
0 杆 / 1 杆序列，换成人工录制的真实序列。

**推论（必须遵守）**：

1. `content/drill_profiles/*.profile.json` **降级为设计期参考档案**，不再是球形真源。
   它记录变量矩阵设计意图，可用于设计新球形时参考；**不得据此断言 App 内球形现状**。
2. drill JSON 的 `tutorial.formations` **必须对齐序列文件**（数量、顺序、token）。
   当两者不一致时，**改精讲，不改序列**。
3. `sets.defaultSets` / `defaultBallsPerSet` 不得与球形结构冲突（见 §5 待裁定）。
4. drill 元数据（`nameZh` / `description` / `coachingPoints` / `standardCriteria`）与序列实测
   内容冲突时，**改元数据，不改序列**；`drillId` **永久不变**（v26 W0 / D-v26-1～2）。

### 1.2 红线（沿用既有拍板，不得绕过）

1. ⛔ **AI 不生成球形坐标**（2026-07-20 拍板）。球形由用户在出片台人工设计。
2. ⛔ **禁止从 `shotIntent` 反推生成示范序列**（2026-06-13 拍板）。示范击打人工录制。
3. ⛔ 几何/坐标推导必读 `geometry-spatial-reasoning` 技能，数值以脚本验算留档，
   口径对齐 `scripts/b5_audit_drills.py`，禁止脑算。
4. ⛔ 声称"通过 / 完成"必须附真实 build / test / 脚本输出。

---

## 二 数据流向

### 2.1 内容生产（离线，仓库内）

```
走位编排台（BatchDrillStudio / PositionPlayComposer，仅模拟器构建可见）
   │  人工摆球 + 录制击打
   ▼
content/position_play/sequences/drill_cNNN__<token>-<名称>-<N>杆.json   ← 真源
   │
   ├─ make position-export ─→ build/position_play_export/seq_*/
   │        │  cover.png / preview/frame_NN.png / initial.png / final.png
   │        │  sNN_still.png / full.mp4 / full.gif / full_3d.mp4
   │        ▼  import-engine-export-to-app.py
   │     QiuJi/Resources/Videos/<drillId>/
   │     QiuJi/Resources/DrillTutorials/<drillId>[_<token>]_sNN.png
   │     QiuJi/Resources/Previews/<assetKey>/
   │     （并重写 drill JSON 的 videos[]）
   │
   ├─ make tryout-sync（rsync --delete，仅 drill_c*.json）
   │        ▼
   │     QiuJi/Resources/DrillBoards/                      ← App 试打/场景/静态预览
   │
   └─ DrillThumbnailRenderer（离线烘焙，见 §8.3）
            ▼
         QiuJi/Resources/DrillThumbnails/<drillId>.png     ← App 列表缩略图

校验：make verify-tutorials（C1 出片新鲜度 / C2 回填一致性 / C3 引用指向 / C4 结构对齐
      + I5 精讲 token / I7 profile / I8 Bundle 子集 / I9 序列覆盖）
门禁：make verify-gate（pre-push 钩子入口，见 §7.1）
质检：python3 scripts/verify_manual_formations.py --gold <drillId>（切角/距离/覆盖矩阵）
```

**不在自动化链路上的手工内容**：`Resources/Drills/*/*.json`、`Resources/Plans/*.json`。
这两者与几何层漂移的机制原因即在于此——没有任何工具保证它们跟随序列更新。

### 2.2 App 内容读取（运行时，全部 Bundle 直读）

| 消费方 | 来源 | 入口 |
|---|---|---|
| Drill 元信息/精讲 | `Drills/index.json` + 各 drill JSON | `DrillContentService` |
| 球形几何/试打/场景 | `DrillBoards/*.json` | `DrillTryoutBoardStore.formations(for:)` |
| 列表缩略图 | `DrillThumbnails/*.png` | `BTBakedDrillTable` |
| 训练计划 | `Plans/*.json` | `PlanContentService` |

**内容 OTA 目前不存在。** `DrillContentService` 仅有 Bundle 路径，
`GET /drills` 是代码注释中的未来式（ADR-002 规划态）。
**因此内容版本 ≡ App 版本**，内容变更需发版。文档与排期不得按 OTA 已就绪假设推进。

### 2.3 用户数据写入

| Tab | 写什么 | 存储 |
|---|---|---|
| 训练 | `TrainingSession` / `DrillEntry` / `DrillSet` | SwiftData |
| 练习 | `AngleTestResult`（仅 4 个入口写） | SwiftData |
| 练习 | 自适应出题画像（角度分区滚动误差 ×10） | UserDefaults `AdaptiveQuestionEngine_v1` |
| 练习 | Freemium 每日额度 | UserDefaults（`AngleUsageLimiter`） |
| 动作库 | `DrillFavorite` | SwiftData |
| 我的 | 周目标天数等偏好 | `UserPreferences` |

`AngleTestResult` 的四个写入点：`GeometricAngleViewModel`、`AimingQuizViewModel`、
`AimPointTrainingView`、`AimPointSceneTrainingView`。练习 Tab 其余二十余个页面
（球感/翻袋/钻石系统/击球模拟/自由击球/思路训练器/斯诺克战术/取球/各图谱与原理页）
**不记录任何成绩**。

### 2.4 用户数据读取（记录 Tab）

- **历史子页**：合并 `TrainingSession` 与 `AngleTrainingSession`。
  后者是**内存投影**——把扁平的 `AngleTestResult` 按「同 `quizType` 且间隔 < 30 分钟」
  推断成一场，id 为 `"<quizType>_<firstResultId>"`，无对应 SwiftData 实体。
- **统计子页**：**仅读 `TrainingSession`**；无 drill 会话时才嵌入 `AngleHistorySection`。
- **详情页**：`TrainingDetailView`（drill）/ `AngleSessionDetailView`（角度）。

### 2.5 同步

`SyncQueueManager.enqueue` → `SyncPendingItem` → `BackendSyncService`。
**仅同步两类**：`syncSession`（训练会话）、`syncAngleTest`（角度成绩）。
计划激活状态、自定义计划、收藏、自适应画像、周目标**均不同步**，换机即丢。

---

## 三 标识符与命名契约

| 标识符 | 稳定性 | 说明 |
|---|---|---|
| `drillId`（`drill_cNNN`） | **永久稳定** | 用户历史数据外键；重构 drill 内容时沿用 id，不新建 |
| 球形 `token` | **事实上已固化** | 见 §3.1 |
| 序列 `PositionPlaySequence.id`（UUID） | 不作为资产键 | 录制时生成，未参与文件名 |
| 序列文件名 | **协议**，见 §3.2 | 下游 `tryout-sync` / `DrillTryoutBoardStore` / 出片 runner 依赖 |
| `quizType` 字符串 | **永久稳定** | 历史 `AngleTestResult` 解引用依据 |
| `PracticeStorageKey` 原值 | **冻结** | 改名即抹除用户数据（文件头已声明） |

### 3.1 球形 token 的现状与约束

token 由文件名解析（`DrillTryoutBoardStore.token(fromFileName:drillId:)`：取 `__` 与
下一个 `-` 之间的段；旧式单序列为空串）。现存三类取值：

- `manualNN` —— 出片台人工新增球形（B1 引入），当前主流；
- `Snipaste_YYYY_MM_DD_HH_MM_SS` —— 早期截图派生，录制过程残留；
- 空串 —— 旧式单序列。

**token 已编码进 418 个 `DrillTutorials` 资产文件名、`Previews` 目录名与 `Videos` 产物名**
（`import-engine-export-to-app.py` 以 token 为产物前缀，并对 `manual01` 额外写无前缀别名）。
`DrillTryoutBoardStore.representative` 的挑选优先级仍保留 `A1` 分支（A 系列已退役，该分支现为死路）。

**约束**：

1. 变更 token 命名规范 = 重命名千级资产 + 重写 JSON 引用 + 重跑出片回填。
   **必须走 ADR**，不得在实现任务中顺手改。
2. 在规范未变更前，`manualNN` 是既定稳定键，精讲与 profile 引用一律使用它。
3. 新增球形沿用 `manualNN` 递增；token 内**禁止出现 `-`**（文件名解析分隔符）。

### 3.2 序列文件名协议

```
多球形：drill_cNNN__<token>-<名称>-<N>杆.json
旧式单序列：drill_cNNN-<名称>-<N>杆.json
```

归属判定为前缀 + 分隔符匹配（`drill_c04` 不得误匹配 `drill_c042`）。

### 3.3 分类：主分类单值 + 副分类标签（2026-08-09 用户裁定 D10）

drill 的分类是**一主多标**结构，但两层职责严格分开：

| 层 | 字段 | 取值 | 职责 |
|---|---|---|---|
| 主分类 | `category`（单值，必填） | 8 类之一 | 文件目录归属、`index.json` 归属、**统计归属**、详情页主徽章 |
| 副分类 | `secondaryCategories`（可选数组，**每条 drill ≤1 个**） | 8 类之一，且 ≠ `category` | **仅**动作库浏览与筛选命中 |

**硬约束**：

1. ⛔ **统计只记主分类**。`StatisticsViewModel` 的 category 分组（§5.4）**不得**读副分类——
   一条记录同时计入两类会使分母重复，与 §5.4 「不同单位不得同分母」的裁定冲突。
   推论：本条口径落地时统计层**零改动**。
2. 动作库分组（按类分节）仍按主分类；筛选命中主 ∪ 副。
3. 副分类**不改变文件目录**。drill JSON 仍存放在 `Resources/Drills/<category>/`，
   `index.json` 仍只在主分类下登记一次；副分类不产生第二条索引项。
4. 跨类条目总量控制在 **15 条左右**（用户口径）。清单需用户确认后定稿。

---

## 四 用户训练数据结构（现状 + 已知缺陷）

```
TrainingSession（id / date / ballType / totalDurationMinutes / note / planId）
  └─ DrillEntry（drillId / drillNameZh）
       └─ DrillSet（setNumber / targetBalls / madeBalls）

AngleTestResult（date / actualAngle / userAngle / pocketType / quizType / errorMM）  ← 无会话归属
UserActivePlan（planId / isCustom / startDate / currentWeek / currentDay）
CustomPlan → CustomPlanDrill（drillId / roundsPerFormation / order）   ← v31 W0 schema V3，见 §6.6
DrillFavorite / SyncPendingItem
```

**已知结构缺陷（详见 §8）**：

- 每组仅落 1 个用户产生的整数（`madeBalls`）；已采集的 `duration` 与 `drillNotes` 在保存时丢弃。
- 无「球形」维度：`DrillSet` 不知道自己属于哪个球形，多球形 drill 的组次无法区分。
- 无机读达标线：`standardCriteria` 是自然语言，App 不解析。
- `currentWeek` / `currentDay` 只读不写，计划无法推进。

### 4.1 目标 schema（2026-08-06 定稿；本地模型已落地，传输层/后端 2026-08-12 补齐）

一次性迁移，覆盖 §5.1/§5.3 裁定、§6.5 快照裁定与 §8.7 丢弃字段。**实现时须写 ADR + `MigrationPlan`。**

**落地状态**：

| 层 | 状态 | 依据 |
|----|------|------|
| SwiftData 本地模型 | ✅ 已实现 | `DrillSet.swift` / `DrillEntry.swift` / `TrainingSession.swift` / `AngleTestResult.swift` |
| 上行传输层 `TrainingSessionDTO` | ✅ 已实现（2026-08-12 v36 W1） | `BackendSyncService.swift`：`DrillSetDTO` 6 字段 + `DrillEntryDTO` 3 字段，编码直传、解码 `decodeIfPresent`+默认值 |
| 后端 Mongoose schema | ✅ 已登记（2026-08-12 v36 W1） | `backend/src/models/TrainingSession.js`：9 字段全部登记、给 default、不加 required（`strict: true` 不登记即静默丢弃） |
| 下行恢复（DTO → 实体重建） | ⏳ 待实现 | v36 W3 |

决策依据见 `tasks/phases/P2-data-layer.md` ADR-007（ADR-v36-01）。

```
TrainingSession
  + kind: String              // "drill" | "cognitive" | "tool"（§5.3）

DrillEntry
  + orderIndex: Int           // 训练内顺序（现依赖数组下标，脆）
  + note: String              // drillNotes 落地（§8.7）
  + criteriaText: String      // 达标说明快照，人类可读（§6.5）

DrillSet
  + formationToken: String?   // 球形归属
  + formationName: String?    // 球形显示名快照（§6.5）
  + unitLabel: String         // "球" | "局" | "次"（§5.2）
  + passMade: Int             // 达标线快照，为 D2 预留两种层级（§5.5）
  + passTotal: Int
  + durationSeconds: Int?     // 每组用时，已采集但丢弃（§8.7）

AngleTestResult
  + sessionId: UUID?          // 归属 kind="cognitive" 的 TrainingSession（§5.3）
```

**设计取舍**：

1. **无 metric 类型枚举** —— §5.1 裁定使 `made/target` 一个结构通吃。
2. **达标线放 `DrillSet` 而非 `DrillEntry`** —— 使 D2 两种裁法都不必再改 schema。
3. **快照字段写入即冻结**，展示层禁止回查当前内容（§6.5 推论 2）。
4. `kind="tool"` 的 session **不产生 `DrillEntry`**，只有日期与时长。
5. 历史无 `sessionId` 的 `AngleTestResult`，用现有「同 `quizType` 且间隔 < 30 分钟」
   推断逻辑（`AngleTrainingSession` 投影）做一次性回填。

---

## 五 训练量与计分口径

> 本节已全部定稿（2026-08-06：§5.1–§5.3 上午裁定，§5.4/§5.5 晚间裁定）。

### 5.1 录入原语 = 计数型，唯一形态（2026-08-06 用户裁定，原 D3 + D4）

**所有成绩一律表达为「N 次中成功 M 次」**，即现有的 `targetBalls` / `madeBalls`。

**裁定理由（用户原话要点）**：用户在球台边没法量距离，也不好记；最简单的就是
「练了 10 次成功 5 次」或「一组里 5 次成功」。

**推论（硬约束）**：

1. ⛔ **不做逐次三态判定**（进袋且到位 / 进袋未到位 / 未进）。会打断球台边训练节奏。
2. ⛔ **不做走位距离量化**。App 无视觉输入，无法获知母球真实落点；用户也量不了。
3. ⛔ **不引入 metric 类型枚举**。局胜负型与计数型同构——「10 局赢 3 局」= made 3 / target 10。
4. ✅ 走位目标区**可以渲染出来供用户自评**（数据来自序列 `steps[i].after` 的母球落点 + 容差圆），
   但只作视觉参考，**不参与判定、不落库**。

### 5.2 单位语义

`made / target` 的单位由 `unitLabel` 声明：`"球"` | `"局"` | `"次"`。
仅影响展示文案，不影响任何计算。

### 5.3 会话分类 `kind`（2026-08-06 用户裁定）

| kind | 含义 | 来源 | 计入准确率统计 | 计入周目标 |
|---|---|---|---|---|
| `drill` | **真实球台成绩** | 训练 Tab 正式训练流程 | ✅ | ✅ |
| `cognitive` | **屏幕内认知测验** | 练习 Tab「练」分区 6 页（角度/瞄准点） | ✅（与 drill 分开展示） | ✅ |
| `tool` | **工具使用活跃度** | 练习 Tab「打/解」分区、动作库试打 | ❌ | ❌ |

**`tool` 类只记日期与时长，不产生 `DrillEntry`，不记任何成败。**

**裁定理由**：「打/解」四处（自由走位进袋模式、自由击球、打一走二想三、动作库试打）
确实有 `objectPocketed` 进袋判定，但那是**物理引擎在手机上算出来的**——用户可反复试、
调力度重来、不满意就撤销，进袋率天然虚高，与真实球台成绩不可比。混入统计会污染水平评估，
且可能诱导"刷模拟器涨数字"而非去球台练。记录时长的目的是**运维与产品优化**（用户 2026-08-06）
以及避免日历活跃度盲区。

⚠️ **合规连带**：`tool` 时长经 `BackendSyncService` 上传（✅ D9 已裁定 2026-08-06：上传），
属"使用数据/产品交互"类个人信息，**须在 H-09 隐私政策与 H-12 App Store 隐私问卷中如实声明**
（已转记入 `tasks/HUMAN-REQUIRED.md` 对应条目）。

### 5.4 跨 drill 聚合口径 — ✅ 已裁定（D1，2026-08-06 用户拍板）

**删除全局单一准确率，改按 category 分组展示。** 不同类别的计量单位（球/局/次）
加在同一分母无物理意义（Ghost Game 的局 vs 直线球的球）。统计页不得再出现
跨全部 session 的单一比率；实现落 v29 W6（`StatisticsViewModel.overallSuccessRate` 为改点）。

### 5.5 达标线定义与层级 — ✅ 已裁定（D2，2026-08-06 用户拍板）

**机读化；挂球形级，drill 级兜底。** `DrillSet.passMade/passTotal` 快照字段两种层级均可表达
（挂 drill 级即同一 drill 各组同值，挂球形级即逐组不同），schema 不需再改。
**内容侧 72 条 drill 暂不补机读达标线**：录入时 `passMade/passTotal = 0` 表示「未设定」，
内容补齐另立批次；补齐前展示层不得把 0 渲染成「达标线 0」。

### 5.6 训练剂量口径（2026-08-09 用户裁定 D11–D13）

> 立此节前，`sets.defaultSets/defaultBallsPerSet` 与球形结构的关系是 §1.1 推论 3 留的空白
> （「不得冲突」但没定义什么叫冲突）。本节把它补成可机检的口径，**I6 就此定稿**（见 §7）。

#### 5.6.1 剂量下沉到球形级（D11）

**训练剂量的语义单位是「球形」，不是「drill」。** drill JSON 的 `sets` 块结构：

```
sets: {
  defaultSets:        Int      // 汇总兜底 = Σ perFormation[].defaultRounds
  defaultBallsPerSet: Int      // 汇总兜底 = 主球形的 ballsPerRound
  perFormation: [              // 可选；有序列的 drill 必须写（I6a）
    { token, mode, ballsPerRound, defaultRounds }
  ]
}
```

- `token` 与序列文件名 token（§3.1）同一取值，**不是新标识符**；
- 两个汇总兜底字段**保留不删**：未展开球形的场景（列表卡、详情规格行、旧调用方）仍读它们。
  它们是**派生值**，与 `perFormation` 冲突时以 `perFormation` 为准。

#### 5.6.2 两种训练模式（D12）

| `mode` | 一轮 = 什么 | `ballsPerRound` 取值 | `defaultRounds` 取值 | 门禁 |
|---|---|---|---|---|
| `sequence` | 按序打完该球形序列的全部杆（整链一遍） | **锁死 = 序列实测杆数** | 整链重复遍数（人工定，表中多为 8） | I6b 几何锁死，阻塞 |
| `repetition` | **一个位置**：重复该位置同一击球 `ballsPerRound` 次 | **∈ [8,15]，默认 15**；非 15 须 `doseNote` | **= 序列实测杆数（轮 = 位置，位置全覆盖）**；例外须 `doseNote` | I6b 形状约束，阻塞（v34 R13/D18） |

判定依据（v31 R7，人工逐条；v34 填写表逐行人工复核）：走位链形态 → `sequence`；
独立阶梯 / 变式目录 / 多形单杆 → `repetition`。

⛔ **`sequence` 型的 `ballsPerRound` 必须取序列实测杆数，禁止手抄或估算**
（取值走脚本，口径同 §1.2 红线 3）。写 4 杆序列却标 10 球，正是本节要消灭的偏差。

**剂量数值真源（2026-08-11 用户裁定 D16，v34）**：`tasks/训练量填写表.md`
（2026-08-11 03:03 定稿版，用户逐球形手填，已入库封存）。重复型 = 每位置 15 颗 ×
轮数 = 杆数；走位链 = 每轮球数 = 杆数 × N 轮（N 以表为准）。表定稿后不再改，
数值变更走 `问题集合_v34.md` 版本记录。

**`doseNote` 例外机制（2026-08-11 用户裁定，v34 R3）**：有意偏离默认形状的球形，
必须在 `perFormation` 该条目写可选字段 `doseNote: String` 说明理由；门禁 I6b 凭
note 豁免「非 15」与「轮数 ≠ 杆数」两项（带外 `ballsPerRound ∉ [8,15]` 不可豁免）。
已知例外：`drill_c002`（8×9，每位置 8 颗）、`drill_c022` 球形 1（15×5，1 杆序列打 75 颗）。

**~~阶梯型 `repetition` 的上界放宽（D15）~~ —— 已被 D16 取代（2026-08-11，v34）**：
阶梯的每一档就是一个位置，按「轮 = 位置」口径 `c020`/`c078` 由 16×3 改为 15×16，
不再需要上界放宽；`relaxed_upper()` 已从门禁脚本删除。

#### 5.6.3 ~~总量护栏（D13）~~ —— 已作废（2026-08-11 用户裁定 D18，v34）

~~单条 drill 单次训练总量 = `Σ (ballsPerRound × defaultRounds)`，目标区间 40–60 球。~~

D13 作废，替换为**形状约束**（v34 R13，阻塞级，实现于 I6b）：

- 重复型：`ballsPerRound ∈ [8,15]`（默认 15，非 15 须 `doseNote`）且
  `defaultRounds == 序列实测杆数`（例外须 `doseNote`；无序列/空序列 drill 豁免，§5.6.4）；
- 走位链：维持 I6b 几何锁死（`ballsPerRound == 杆数`），轮数人工定；
- **不再有 drill 级总量区间**：总量由填写表真源逐球形决定（全库 9493 球，
  中位 75/球形），门禁不看总量、只看形状。

#### 5.6.4 无序列 drill 的豁免

§8.5 登记的无序列 drill（及 0 杆序列）**人工定量**：`perFormation` 可省略，只写两个汇总值；
豁免 I6a/I6b，钉到 drillId 走棘轮基线。豁免不等于随意——量值仍需逐条附理由。

### 5.7 执行负荷（六轴，2026-08-13 用户裁定 D-v37-1=A，v37 W0）

> 六轴是「这条动作在哪些方面费力」的**负荷量表**，不是动作分类。
> 分类仍看 `category`（§3.3）。**不合成总分、不做跨类唯一排序。**
> 本轮 v1 由人工按本节锚点打分；从几何 / `shotIntent` 自动计算是远期，不在本契约实现范围。

#### 5.7.1 六轴定义

| 轴 | JSON 键 | 含义 |
|---|---|---|
| 进球 | `aim` | 瞄准窗口：切角 × 距离 × 袋口 |
| 杆法 | `cue` | 纵向旋转与穿透（高/中/低杆，跟/定/缩） |
| 加塞 | `spin` | 侧旋及瞄准补偿 |
| 走位 | `position` | 母球任务：落点松紧 × 吃库数 × 链长 |
| 约束 | `constraint` | 打法标准度之外的额外限制 |
| 力度 | `speed` | 速度控制的精度和跨度，**非「打得重」** |

各轴独立取 **0–4 整数**。允许「进球 4、加塞 0」。0 = 该轴基本不参与；4 = 该轴上全库接近上限。

#### 5.7.2 锚点表

**进球（`aim`）**

| 分 | 锚点 |
|---|---|
| 0 | 几乎不考进袋（纯姿势、纯停球、纯防守布置） |
| 1 | 近/半台直线或很小切角，角袋 |
| 2 | 中台，或中等切角（约半球厚）；中袋直线也算 2 |
| 3 | 远台，或明显薄球（约 45°+），或远台中袋 |
| 4 | 极薄、远台薄切、远台中袋极限 |

**杆法（`cue`）**

| 分 | 锚点 |
|---|---|
| 0 | 中杆，无跟无缩要求 |
| 1 | 轻高杆/轻定杆，近台能做出效果 |
| 2 | 稳定定杆或中等跟/缩，距离中等 |
| 3 | 远台跟球、明确低杆缩回 |
| 4 | 远台大力低杆、穿透 + 长回缩 |

**加塞（`spin`）**

| 分 | 锚点 |
|---|---|
| 0 | 无侧旋 |
| 1 | 轻塞，无补偿要求 |
| 2 | 明确塞量，短距，补偿可感知 |
| 3 | 中长距带塞进球（需系统补偿挤偏/让点） |
| 4 | 大塞量 + 远台 + 精确补偿（加塞挤偏极限、塞走位综合） |

**走位（`position`）**

| 分 | 锚点 |
|---|---|
| 0 | 母球无任务（独立重复复位型） |
| 1 | 粗略方向要求（停在半张台内） |
| 2 | 明确落点区（一颗球范围级），不吃库或一库 |
| 3 | 精确落点 + 多库，或 3–5 杆连续走位链 |
| 4 | 三库以上走位、长链（蛇彩/清台级）、窄容差落点 |

**约束（`constraint`）**

| 分 | 锚点 |
|---|---|
| 0 | 无额外约束 |
| 1 | 轻约束（近库、稍别扭手架） |
| 2 | 贴库击球、明显障碍绕行、指定顺序 |
| 3 | 翻袋/借力/组合球等非标进球方式 |
| 4 | 跳球、多重障碍、极限贴库 + 非标方式叠加 |

**力度（`speed`）**

| 分 | 锚点 |
|---|---|
| 0 | 力度不是训练目标，中小力打进即可 |
| 1 | 只要别太冲/太软，无停点标尺 |
| 2 | 明确分档（轻/中/重），或短距停点要重复打出 |
| 3 | 五档级标尺，或软打控位、强力高/低杆作为主题 |
| 4 | 全力度走位综合，或极软与极冲在同一动作里都要准 |

**邻轴边界备忘**（打分时盯住，禁止为「看起来合理」挑一个轴记账）：

- **大力低杆** = 杆法与力度都可高（缩得出 ≠ 力打得透）。
- **短距走位 vs 轻推** = 走位管「必须停在哪」、力度管「标尺是不是主题」。
- **贴库薄切** = 进球与约束都记，不挑一个。
- **三库走位 4 不自动力度 4**（除非课就是练标尺）。

锚点表微调必须升本节契约版本并在校准集文首列 delta；禁止只改分数不改锚点。

#### 5.7.3 打分对象口径（D-v37-1 = A，球形级真源）

**真源单位是球形，不是 drill。** 全库 105 球形逐一打分。

- **禁止**把六轴从不同球形拼成一条合成雷达（例如进球取球形 A、加塞取球形 B）。
- **drill 雷达** = **代表球形的实分**（见 §5.7.5）为数据源；**上屏展示分 = 存储分 + 1**（1–5，D-v37-6），半径比例 = 展示分 / 5。存储分、门禁、排课比较仍用 0–4。禁止把展示分写回 JSON。
- **组课约束** = 该课实际引用的各球形在**每一轴上独立取 max**（六次 max，仍不合成总分）。
  用于排课门禁（热身 ≤ 主课，I13 ②）的包络，不是展示用雷达。六轴 scalar 不再卡周。

**走位链取分**（`mode == sequence`）：

- 进球 / 杆法 / 加塞 / 力度 = 链上**最难一杆**；
- 走位轴看**整链**（库数、链长、落点松紧）。

**独立重复复位型**（`mode == repetition`，每杆重摆）：

- 若母球**无走位任务**（进袋/杆法/姿势检验后摆回）：走位轴**必须低**（0，或至多 1 若原文写了粗略停区）。
- 若母球**有走位任务**（如独立三库停位阶梯）：走位轴按该任务的库数/落点打，**不因「每杆重摆」自动归零**。
- 进球 / 杆法 / 加塞 / 力度取该球形阶梯上**最难一档**（与走位链「最难一杆」同构）。

打分必须能追溯到本节锚点行，并引用 `description` / `coachingPoints` / `standardCriteria` / 序列 `mode` / 精讲要点中的已读原文。禁止只凭 `nameZh` 打分。无序列则在理由里写「无序列，依据元数据」。

#### 5.7.4 `load` 字段 schema（W0 定名；W1 才写入生产 JSON / Swift / MODEL_SPEC）

六轴挂在**球形级**，落在 `FormationDose` **之内**（与 `token` / `mode` / `doseNote` 并列）：

```
load: { aim, cue, spin, position, constraint, speed }   // 六个 Int，值域 0–4
```

有 `perFormation` 的 drill：

```
sets: {
  defaultSets: Int,
  defaultBallsPerSet: Int,
  representativeToken: String?,   // 可选；缺省 = perFormation[0].token
  perFormation: [
    { token, mode, ballsPerRound, defaultRounds, doseNote?, load }
  ]
}
load: { aim, cue, spin, position, constraint, speed }   // drill 级代表分（派生，必须等于代表球形实分）
```

JSON 示例（示意，**不得写入** `QiuJi/Resources/Drills/**/*.json`，待 W1 与 I10 `MODEL_SPEC` 同步后才写生产内容，FL-029）：

```json
{
  "id": "drill_c075",
  "sets": {
    "defaultSets": 17,
    "defaultBallsPerSet": 15,
    "representativeToken": "manual01",
    "perFormation": [
      {
        "token": "manual01",
        "mode": "repetition",
        "ballsPerRound": 15,
        "defaultRounds": 7,
        "load": { "aim": 2, "cue": 0, "spin": 3, "position": 0, "constraint": 0, "speed": 1 }
      }
    ]
  },
  "load": { "aim": 2, "cue": 0, "spin": 3, "position": 0, "constraint": 0, "speed": 1 }
}
```

无 `perFormation` 的无序列 drill（§5.6.4 / §8.5）：**只写 drill 级 `load`**，不写 `sets.representativeToken`，也不另建平行数组。

```json
{
  "id": "drill_c059",
  "sets": { "defaultSets": 6, "defaultBallsPerSet": 15 },
  "load": { "aim": 0, "cue": 0, "spin": 0, "position": 0, "constraint": 4, "speed": 1 }
}
```

⛔ W0 / 任何未同步 `MODEL_SPEC` 的批次，禁止把 `load` / `representativeToken` 写入生产 drill JSON（检查器忽略未知键，spec 外的键是盲区，FL-029）。

#### 5.7.5 代表分选择规则（确定性，W1 门禁 I12 可检查）

**规则（写死，禁止「感觉上最能代表」）**：

1. 若 `sets.representativeToken` 有值：代表球形 = 该 token，且必须存在于 `perFormation`。
2. 若缺省：代表球形 = `perFormation[0]`（数组字面量第一项，稳定、与 JSON 书写顺序一致）。
3. **drill 级 `load` = 该代表球形的 `load` 六元组原样拷贝**（I12：drill 代表分 = 某球形实分）。
4. 无 `perFormation`：drill 级 `load` 本身即唯一真源，不派生。

推荐：代表球形选「该动作教学主线」的那一形（通常是 `perFormation[0]` 或显式写出）；不得为了雷达好看改选更高分球形，除非 `representativeToken` 显式改写。

门禁 I12 落 **v37 W1**（字段齐全、值域 0–4、代表分等于某球形实分、组课 max 可派生；构造性违反实证 exit 1，FL-031）。

#### 5.7.6 雷达展示映射（D-v37-6）

存储分 `s ∈ [0, 4]`。动作页雷达**只改展示**：展示分 = `s + 1` ∈ `[1, 5]`，半径 = 展示分 / 5。因此存储 0 仍占最内环，不塌成点。JSON / I12 / 排课比较**一律用存储分**。禁止把展示分写回 JSON。上屏节标题为 **「难度画像」**（副题「这项动作难在哪」）；契约层仍称执行负荷。

---

## 六 内容变更规则

1. **序列变更后必跑**：`make tryout-sync` → `make verify-tutorials` → 修复 C4 不一致 →
   `verify_manual_formations.py` 复核覆盖矩阵。
2. **球形增删属破坏性变更**：会使已有用户记录的球形归属失效。
   在 §5 口径裁定（含历史记录解引用策略）落地前，**避免对已发布 drill 做球形重划分**。
   **v31 W0 起范围扩大**：token 已成为**计划外键**（§6.6），删球形还会打断按球形引用的计划条目。
   删除或重命名任何球形 token 前，必须先扫 `Resources/Plans/plan_*.json` 的
   `dose.formations[].token` 引用（门禁 I11 计划校验，见 §7），有引用则先改计划再删球形。
3. **drill 内容重构沿用原 `drillId`**，不新建 id（既有惯例，见 c053 profile `_note`）。
4. **产物目录禁止手改**：`DrillBoards/`、`DrillTutorials/`、`Previews/`、`Videos/`、
   `DrillThumbnails/`、`TutorialFigures/` 一律由脚本生成；手改会在下次同步/回填时被覆盖。
5. **配图母版与发布图分家（v25 D-v25-14）**：`DrillTutorials/` 是 PNG 母版（含孤儿帧，
   约 4.9 GB，不进包不进 git）；**进包的是** `TutorialFigures/`（仅被精讲引用者，HEIC q70，
   约 112 MB，进 git）。folder reference 整目录打包、无法挑文件，两者必须分目录，否则
   633 张孤儿帧必然进包（包体曾因此达 5.43 GB，超 App Store 未压缩上限）。
   ⛔ 新增/替换精讲引用后必须跑 `make tutorial-figures`，否则 App 里是旧图或缺图；
   `make verify-gate` 会以「未发布 / 过期 / 多余产物」拦截。

### 6.5 历史记录解引用 = 存快照（2026-08-06 用户裁定，原 D6）

用户训练记录**在写入时冻结其依赖的内容定义**，不在展示时回查当前内容。

**必须快照的字段**（内容改版后历史记录仍能自洽解释）：

- drill 身份：`drillId` + 记录时的 `drillNameZh`（`DrillEntry` 已有，保持）；
- 球形身份：球形 `token` + 记录时的球形显示名；
- 计分依据：记录时生效的达标线与计量口径（具体字段随 §5 口径定稿后确定）。

**推论**：

1. 内容改版**不回溯改写**任何已有记录；球形被删除后，历史记录仍按快照正常显示。
2. 展示层**禁止**用 `drillId`/`token` 去当前内容里查名称或达标线来渲染历史记录——
   那是活引用，与本裁定冲突。当前内容仅可用于「跳转到该 drill」这类导航意图。
3. 快照带来的存储冗余是可接受成本（已知取舍）。
4. 本裁定须在**首批真实用户数据产生前**落地；之后再改需写数据迁移。

### 6.6 动作库与计划的绑定模型（2026-08-09 用户裁定 D14）

**drill JSON 是训练剂量的唯一真源。计划（官方 + 自定义）不得再存裸球数。**

> **v31 W5 已切净**：`PlanDrillRef` 不再有 `sets`/`ballsPerSet` 字段，`TrainingDoseResolver`
> 不再有旧格式兼容路径。JSON 里再写这两个键既不生效、也会被门禁 I11 直接 FAIL。
> ⚠️ 注意区分：drill 侧的 `sets.defaultSets` / `sets.defaultBallsPerSet` 是 §5.6 规定的
> **汇总兜底保留字段**，不在删除范围内。

| 层 | 存什么 | 不存什么 |
|---|---|---|
| drill JSON `sets.perFormation` | 每球形 mode / 每轮球数 / 轮数（+ 可选 `doseNote`） | — |
| 官方计划 `PlanDrillRef.dose` | `formations: [{token, rounds, ballsPerRound?}]`（选球形；`ballsPerRound` 仅 repetition 衰减）；结构上仍允许 `roundsPerFormation`，但**官方计划一律不写**（v34 R9，完整剂量即默认 1 倍） | ⛔ `sets` / `ballsPerSet` |
| 自定义计划 `CustomPlanDrill` | `roundsPerFormation: Int`（倍数，默认 1） | ⛔ `sets` / `ballsPerSet` |
| 训练记录 `DrillSet` | 展开后的 `targetBalls` + 球形快照 | — |

**`roundsPerFormation` 语义重定义（2026-08-11 用户裁定 D17，v34 R9，B 方案）**：

- 字段**保留**（不做 Schema V4 迁移），默认 1；
- 语义由「每球形轮数（覆盖 `defaultRounds`，会砍位置）」改为「**整个动作重复几遍（倍数）**」：
  展开 = 内容侧完整剂量 × 倍数，**位置永远全覆盖**，任何取值都不会砍掉某个位置；
- `dose.formations` 按 token 选球形的能力保留，但逐球形 `rounds` **不得低于**该球形
  内容侧 `defaultRounds`（低于 = 砍位置 = I11 FAIL，阻塞级）；
- 消费方（`TrainingDoseResolver` 等）改造落 v34 W4。

**复习课次减量例外（2026-08-13 用户裁定 D-v37-2=B，v37 W0 锁语义，实现落 W4）**：

v34 R9「位置永远全覆盖 / `formations[].rounds ≥ defaultRounds`」对**首次引入课次**仍然成立。
为表达「同一动作后续课次衰减复现」（课次级、可跨周），增加**显式标记**例外：

- **标记字段**：`PlanDrillDose.decay: Bool`（可选；缺省或 `false` = 非衰减）。
  挂在 `PlanDrillDose` 上，不挂 `PlanDrillRef`，也不复用 `SessionPhase.type == "review"`
  （后者是「复盘记录」相位，与衰减复现不是同一语义，禁止撞名）。
- **`decay: true` 的可调维按 mode 分叉（v38 R7 / D-v38-4=A）**：
  - **`repetition`**：`formations[].rounds` **必须 ≥** 内容 `defaultRounds`（位置全覆盖，decay 也不砍杆）。
    减量写可选 `formations[].ballsPerRound`（每位置颗数，须 ≥1 且 ≤ 内容 `ballsPerRound`）。
  - **`sequence`**：允许 `formations[].rounds <` 内容 `defaultRounds`（降整链遍数，≥1）。
    **禁止**写出与内容不等的 `ballsPerRound`（杆数 = 链长，I6b 锁死）。
- **首次引入不得借例外减量**：同一 `drillId` 在一份官方计划中**第一次出现**的课次
  必须完整剂量（不得标 `decay: true`，且 repetition 的 `rounds ≥ defaultRounds`、
  不得写低于内容的 `ballsPerRound`）。
- 本例外不改变 `roundsPerFormation` 的倍数语义，也不允许用它表达减量（官方计划仍一律不写该键）。
- 代码 / `MODEL_SPEC` / `_dose_errors` / `TrainingDoseResolver` 已于 **v38 W1** 按上表分叉。
  I13 展开球数计入计划侧 `ballsPerRound` 覆盖。

示意（repetition 衰减：8 位置 × 15 颗 → 8 × 10）：

```json
{
  "drillId": "drill_c001",
  "dose": {
    "decay": true,
    "formations": [{ "token": "manual01", "rounds": 5, "ballsPerRound": 10 }]
  }
}
```

**为什么这不违反 §6.5 快照裁定**：计划 → 训练是**激活时解析的活引用**，
解析结果在落 `DrillSet` 时才快照冻结。§6.5 约束的是「已落库的历史记录不得回查当前内容」，
计划本身不是历史记录。

**推论**：

1. 计划里改不动实际球数——要改量就改轮数，或去改 drill 内容。这正是本裁定的目的：
   消灭「c020 单球形 16 杆却写 4×10」这类计划与内容各说各话的偏差。
2. 按球形引用（`dose.formations`）使**球形成为难度阶梯**：计划可以第 1 周只练 `manual01`，
   第 3 周加 `manual02`。代价是 token 升级为计划外键（§6 规则 2 的删除连带）。
3. 未在 `dose.formations` 中列出的球形，本次训练**不展开**。
4. 持久化影响：`CustomPlanDrill` 的字段变更走 SwiftData V2→V3 迁移（ADR-v31-01，
   折算 `rounds = max(1, sets / 球形数)`，无球形声明按 1 球形算）。

---

## 七 不变量清单（应接为门禁）

| # | 不变量 | 现有检查 | 状态 |
|---|---|---|---|
| I1 | 精讲球形数/杆数 == 序列实际值 | `verify_tutorial_sync.py` C4 | ✅ 有，✅ **已接门禁**（v26 W13 转正） |
| I2 | 出片产物不早于源序列 | C1 | ✅ 有，✅ **已接门禁** |
| I3 | 回填图与产物图字节一致 | C2 | ✅ 有，✅ **已接门禁** |
| I4 | 精讲 `image` 指向最新图 | C3（含失效引用棘轮） | ✅ 有，✅ **已接门禁** |
| I5 | 精讲 formation token ⊆ 序列 token 集合 | I5（v29 W9 新增） | ✅ 有，✅ 已接门禁（legacy 豁免已于 v26 清空） |
| I6a | 有序列 drill 的 `sets.perFormation` token 集合 == 该 drill 的序列 token 集合（无序列 drill 不得写 `perFormation`） | I6a（v31 W4 新增） | ✅ 有，✅ **已接门禁**（棘轮豁免 `i6a_token_mismatch_exempt` 为空） |
| I6b | `mode == sequence` 的球形 `ballsPerRound` == 该球形序列实测杆数（`len(steps)`）；`mode` 取值 ∈ {sequence, repetition}；**`repetition` 型形状约束（v34 R13/D18，阻塞）**：`ballsPerRound ∈ [8,15]` 且（非 15 或 `defaultRounds ≠ 杆数` 时须 `doseNote`） | I6b（v31 W4 新增；v34 W0 加形状约束） | ✅ 有，✅ **已接门禁**。空序列球形与无序列 drill 按 §5.6.2/§5.6.4 **规则性豁免**（不入基线）；`repetition` 型豁免的只有几何锁死（门禁输出「规则豁免 N」），形状约束照常阻塞；棘轮豁免 `i6b_shots_exempt` 为空 |
| I7 | profile formation 集合 == 序列 token 集合，或 profile 标记为已退役 | I7（v29 W9 新增） | ✅ 有，✅ 已接门禁（孤儿 profile 已退役，豁免已清空） |
| I8 | `Bundle/DrillBoards` == `content/.../sequences` 的 `drill_c*.json` 子集 | I8（v29 W9 新增） | ✅ 有，✅ 已接门禁 |
| I9 | 每个 `index.json` 登记的 drill 至少有 1 个序列，或在豁免名单内 | I9（v29 W9 新增） | ✅ 有，✅ 已接门禁（豁免见 §8.5） |
| I10 | 全部 bundled drill / plan JSON（含各自 `index.json`）能被 App 的 `Codable` 模型解码——必填字段齐全、类型正确 | I10（v30 X-1 新增；v31 W4 扩到 `sets.perFormation` / `secondaryCategories` 与计划侧模型） | ✅ 有，✅ 已接门禁（无豁免） |
| I11 | 官方计划可解析：每条目 `drillId` 存在于 `index.json`、`dose` 结构可解析（`roundsPerFormation` 与 `formations` 恰好二选一、轮数 ≥1）、按球形引用的 token 存在于该 drill 的 `perFormation` token 集合 ∩ 序列 token 集合。**可调维按 mode（v38 R7）**：`repetition` 的 `rounds` 不得低于内容 `defaultRounds`（decay 也不砍位置）；`sequence` 仅在 `decay == true` 时允许 rounds < defaultRounds；`repetition` 可用可选 `ballsPerRound` 降每位置颗数（须 decay 且 ≤ 内容）；`sequence` 禁止改 `ballsPerRound` | I11（v31 W4；v34 下限；v37 decay 例外；**v38 W1 按 mode 分叉**） | ✅ 有，✅ **已接门禁**。构造性：`i11_repetition_decay_cut_positions` / `i11_sequence_override_balls` exit 1；`i11_repetition_decay_balls_ok` 与 sequence 降遍数放行 |
| I12 | 六轴 `load` 齐全、六键值域 0–4 整数；有 `perFormation` 时每球形必有 `load`，drill 级 `load` = 代表球形实分（`sets.representativeToken` 或缺省 `perFormation[0]`）；`representativeToken` 若出现必须 ∈ `perFormation` token 集；无 `perFormation` 时只允许 drill 级 `load`；组课 max 可由被引用球形派生 | I12（v37 W1） | ✅ 有，✅ **已接门禁**（无豁免；构造性违反：缺字段 / 值域越界 / 代表分 ≠ 球形实分 各实证 exit 1） |
| I13 | 官方计划排课规则（v37 R4–R6 + v38 W7 内容层 + **v39 W2**）：①**建议周下界**——每份计划内 **focused 首次引入** 不得早于 `docs/research/20260818-v39-语义课表.md` §5 该 `(plan, id)` 的建议周（warmup / `reviewFrom` 咬合不计入新引入；缺表或不足 83 条 ⇒ FAIL）。**六轴 scalar 不再卡周**（只作 ② 热身包络）。②热身≤主课——同 session **非咬合**热身 scalar max ≤ focused scalar max（带 `reviewFrom` 的热身豁免，因 R6 上一档末段可难于下一档开课）；③衰减——同 drill 按课次展开球数单调不增（展开计入计划侧 `ballsPerRound` 覆盖），低于完整剂量必须 `decay: true`，计划内首次不得 `decay`；④`reviewFrom` ∈ `Plans/index.json` 且来源计划实际包含该 drill。⑤**引入序（v38 W7）**：focused 首次引入短 id 序 = `docs/research/20260814-v38-先决与主课名单.md` §3 该计划主课表序。**只比序，不比「建议周」**。 | I13（v37 W5；v38 W7 落地引入序；**v39 W2 改 ①**） | ✅ 有，✅ **已接门禁**（五条）。构造性：`i13_week_order_drop` 把 c032 首次提前到早于建议周 ⇒ exit 1；对调准度Ⅰ前两堂 focused ⇒ exit 1 |

> **编号说明**：`问题集合_v31.md` W4 把计划校验称作「I10」，但 I10 已被 v30 X-1 的
> 模型可解码性占用。本契约按既有编号顺延为 **I11**；W4 实施时以本表为准。

**I10 说明（FL-029）**：`DrillContentService.loadDrillFromBundle` 曾用 `try?` 吞掉
`DecodingError`，34/77 条 drill 因缺 `TutorialSection.content` / `TutorialFormation.id`
而**静默不进 App**（动作库只有 43 条），且失败信息仅为「返回 nil」，无法定位字段。
I10 的必填字段表（`verify_tutorial_sync.py` 的 `MODEL_SPEC`）是 Swift 模型的 Python 镜像，
**改 Swift 模型必须同步改它**——检查器忽略未知键，spec 里没有的字段就是盲区。
v31 W4 补齐了 W0 新增的 `DrillContent.secondaryCategories`、`DrillSetsConfig.perFormation`
（含 `FormationDose` 四个字段与 `mode` 的枚举域），并把**计划侧模型**
（`OfficialPlan` → `PlanWeek` → `PlanSession` → `SessionPhase` → `PlanDrillRef` → `PlanDrillDose`
与 `PlanIndex`）一并纳入——计划解码失败会经 `loadAllPlans` 的 `compactMap`
让整份计划从列表里消失，与 FL-029 的「静默不进 App」是同一形态。
Swift 侧同位检查为
`DrillContentValidationTests.test_allIndexedDrills_loadSuccessfully`（失败时打印 codingPath）。

### 7.1 门禁（2026-08-07 v29 W9 落地）

**入口**：`make verify-gate`（= `verify_tutorial_sync.py --gate`），由 git `pre-push` 钩子调用。
本仓库无 CI，钩子是唯一自动阻塞点。

```bash
make -f scripts/Makefile install-hooks   # 每个克隆装一次（git 不跟踪 .git/hooks）
make -f scripts/Makefile verify-gate     # 本地自查，与钩子同一入口
make -f scripts/Makefile invariant-selftest  # 构造性用例：证明每个检查项真会报错
```

- **阻塞项**：C1 / C2 / C3 / C4 / I5 / **I6a** / **I6b** / I7 / I8 / I9 / I10 / **I11** / **I12** / **I13**
  （v31 W4：I6a/I6b/I11 接入；v37 W1：I12 接入；v37 W5：I13 接入）。
- **已知豁免（不阻塞）**：无（v26 W13：`GATE_EXEMPT_CHECKS` 已清空；I9 的 8 条无序列豁免仍在基线文件，属 §8.5 永久登记）。
- **绕过**：只有 `git push --no-verify`（git 内置，钩子无法禁）。用了必须在提交说明或 PR 里写明理由。
- **棘轮**：基线与豁免名单的唯一真源是 `scripts/content_invariant_baselines.json`。
  清单只许缩短、计数只许下调；**新增豁免必须先在 §8 登记并写明解除条件**再改该文件。
  豁免钉到具体 token / formation id，故同一 drill 出现清单之外的**新**偏差仍然 FAIL。
- 任何"已修复"声明仍必须附 `make verify-tutorials` / `make verify-gate` 实际输出。

---

## 八 现存偏差登记

> 本节记录已发现、尚未收敛的偏差。收敛一条删一条，并在 `tasks/PROGRESS.md` 留痕。

### ~~8.1 profile 与精讲双双成为孤儿（11 个 drill）~~ ✅ 已消化（2026-08-07 v26 W0）

~~立档时 11 个 profile drill 与序列全部错位。~~
v26 W0：11 个孤儿 profile 标 `"retired": true`，清空 `i7_stale_profile_exempt`；
精讲按序列重写落 W1–W12。

### ~~8.2 C4 长期 FAIL —— 门禁已知豁免~~ ✅ 已消化（2026-08-07 v26 W13）

~~立档/v29 W9 时 C4 23 条不一致登记为门禁已知豁免。~~
v26 W2–W12 精讲全量迁移后 C4 不一致归零；W13 从 `GATE_EXEMPT_CHECKS` 移除 `C4`，
C4 转为阻塞项。构造性用例证据：`build/v26-w13-logs/verify-gate-c4-probe-FAIL.txt` /
`verify-gate-c4-probe-RESTORE.txt`。

### 8.3 缩略图产物由测试用例生成

`Resources/DrillThumbnails/*.png` 由 `DrillThumbnailRenderer` 烘焙，触发方式是运行
`DrillThumbnailBakeRunnerTests` / `PositionPlaySequenceExportRunnerTests.test_exportAllSequences`。
`tasks/IMPLEMENTATION-LOG.md` 已记录该副作用（跑全量测试会把 PNG 写回仓库）。

**补充（2026-08-06 v29 审核实证）**：写盘测试不止上述两处——
`V21W2BakeTests` / `V21W3BakeTests` / `V21W4BakeTests` 同样无任何 gate，
除写 `DrillThumbnails` 外，其 `patchAnimation` 还会**改写 git 跟踪的
`Resources/Drills/accuracy|cueAction/*.json`**；scheme 无 testplan、无 skipped 列表，
全量测试必跑。另 `DrillBakeRunnerTests` 与 `test_scanFeasibility` 只读不写盘，但跑全量物理。

**问题**：测试带写副作用，无法接 CI（一跑即产生 diff）。
**处置**：拆为显式 make 目标，测试侧改为只读校验；gate 范围须覆盖上述**全部**写盘测试
（已写入 `问题集合_v29.md` W1 范围，v29.1）。

### 8.4 H-21 已过时

`tasks/HUMAN-REQUIRED.md` 的 H-21 要求录制 c053 的 A1–A8 八球形示范击打，
但 A1–A8 序列已于 `8293ef4` 退役，c053 现为 manual01/manual02 两球形人工录制版。
**处置**：关闭或重写 H-21。

### 8.5 8 个 drill 无任何序列，且本质上录不出

`drill_c008`（手架练习）、`c043`（高级手架稳定性）、`c059`（跳球基础）、
`c061`（解球）、`c065`（Ghost Game）、
`c067`（9 球标准清台）、`c068`（五球连打走位）、`c070`（全台清台挑战）。

原因分别为：盘面随机/对抗性（Ghost、清台类）、无特定盘面（手架类）、
物理引擎不支持腾空（跳球，见 `content/position_play/README.md` 3D 契约节）、
成功判据非进袋（解球）。

> **v33 W0 棘轮收紧**：`c060` 已录 8 杆合并序列（安全球，全 freeAim）；`c066` 已录 0 杆空序列（仅摆球无击打，仍无可出片内容，见 v33 §七 遗留 L1）。二者已从 `i9_no_sequence_exempt` 移除。

**处置**：需要独立于序列管线的第二通道，不应挂在出片台等待。

### 8.6 「第 N 杆」标题承载两种互斥语义（8 个 drill）

`tutorial.sections` 中 `第N杆` 标题有时指一轮内的第 N 杆（真序列），有时指第 N 个变式。
`drill_c042` criteria 明写"8 种母球起点"却用 8 个「第N杆」节；`drill_c031` 有 13 个同名节。
数据结构上无法区分。

**处置**：随精讲重写时逐个人工判定并统一编码。

### 8.7 采集但丢弃的用户数据

- `DrillSetData.duration`：`DrillRecordView` 实测每组用时，`DrillSet` 模型无该字段，保存即丢。
- `ActiveTrainingViewModel.drillNotes`：声明并维护数组长度，无 UI 绑定、`saveTraining` 不写库。

### 8.8 官方计划无法推进

`UserActivePlan.currentWeek` / `currentDay` 仅在 `init` 赋值为 1；
`TrainingHomeViewModel`、`PlanDetailView` 只读不写；全仓库无推进逻辑，单测断言其为 1。
后果：激活 `plan_fullskill`（12 周 × 5 次 = 60 个 session）后，用户永远停在第 1 周第 1 天。

### 8.9 角度成绩保存吞错误

`GeometricAngleViewModel` 与 `AimingQuizViewModel` 均为 `try? await repository?.save(result)`，
保存失败静默丢题。违反 `00-orchestrator.mdc` 工程底线第 3 条。

### 8.10 自适应画像是孤岛

`AdaptiveQuestionEngine_v1`（各角度区间最近 10 次误差）是 App 内唯一的弱项画像，
诊断价值高于 `AngleTestResult` 流水，但不展示、不同步、不备份，卸载即失。

### 8.11 文档与代码不符

`docs/06-技术架构.md` 描述的 `AngleTestSession / AngleQuestion` 结构在代码中不存在。
**处置**：改为如实描述扁平 `AngleTestResult` + 内存投影 `AngleTrainingSession`。

### ~~8.12 Bundle 同步陈旧~~ ✅ 已消化（2026-08-07 v29 W8）

~~`drill_c073` 球形 1 上游为 7 杆、Bundle 内为 6 杆。重跑 `make tryout-sync` 即可。~~
W8 全量重出片后 `make tryout-sync` 已把 Bundle 球形 1 更新为上游 7 杆（DrillBoards 90 个序列）。

### 8.13 角度成绩同步 DTO 缺字段（2026-08-06 v29 审核发现）

`AngleTestDTO`（`BackendSyncService.swift` L46–59）未包含 `quizType` / `errorMM`，
与 `AngleTestResult` 模型已有字段脱节——后端侧的角度成绩无法按题型区分、无误差值。
**处置** ✅ 已消化（`AngleTestDTO` 于 v29 W5 补齐 `quizType`/`errorMM`/`sessionId`，后端
`AngleTest.js` 同步登记，双端已对齐）。
**「改 DTO 须同步后端 schema」的闭环**（2026-08-12 v36 W1）：同类脱节在 `TrainingSessionDTO`
上又发生了一次——SwiftData V2 起新增的 9 个成绩字段（§4.1）从未进 DTO 与 `TrainingSession.js`，
`unitLabel` 丢失会让恢复数据语义错误。W1 已双端补齐并加编解码回归测试（见 §4.1 落地状态表、
ADR-007）。**根因是没有机器护栏**：DTO `CodingKeys` ↔ mongoose `paths` 无任何比对，两次都靠
人肉走查发现。对齐门禁脚本进 `make verify-gate` 为 v36 W4 待办，未完成前本条不算彻底关闭。

### 8.14 出片回填脚本默认行为与 v25 决策冲突（2026-08-06 v29 审核发现）

`import-engine-export-to-app.py` 的 `--skip-json` **并非默认开启**（`store_true`；
帮助文案写「v25 视频 UI 已下线，默认应开」但代码未开）。漏传该开关会重写 drill JSON 的
`videos[]`，把 v25 W1 已清空的视频引用全部写回。
**处置** ✅ 已消化（2026-08-07 v29 W8）：脚本改为 `argparse.BooleanOptionalAction` +
`default=True`，默认 skip；要写回须显式 `--no-skip-json`。实测不带参数时 66 个 drill 全部
`json=skipped`，带 `--no-skip-json` 则 66 个全部 `json=updated`（风险确实存在）。

### ~~8.15 精讲 image 仍用 legacy 球形命名~~ ✅ 已消化（2026-08-07 v26 W2–W10）

~~立档时 6 个 drill 精讲 `image` 仍用 legacy `fN` token（I5 豁免 + C3 基线 34）。~~
v26 内容批逐条消化：`c012`（W2）/`c014`（W4）/`c005`（W6）/`c030`（W8）/
`c010`/`c022`（W10）；`i5_legacy_token_exempt` 已空，`c3_dead_refs_baseline` = 0。

### 8.16 6 个 drill 的 `animation.pocket` 为空串（v30 X-1 实测）

`drill_c045` / `c049` / `c054` / `c059` / `c060` / `c061` 的 `animation.pocket` 是 `""`，
`DrillContentValidationTests.test_allDrills_pocketValueIsValid` 因此 FAIL。

**时间线**：c054/c059/c060/c061 在 X-1 前就已 FAIL（基线实测，见
`build/x-v30-1-logs/baseline-prefix-7classes.txt`）；c045/c049 是 X-1 修好解码后
**新暴露**的同类存量缺陷——它们的 JSON 一直是空串，只是此前整条 drill 加载失败、
断言压根没跑到。**不是 X-1 引入的新问题。**

**处置**：属内容侧取值缺失，需人工判定各自的正确袋口，另立批次。
`""` 通不过 I10（类型合法，仅取值为空），故 I10 不覆盖此项。

---

## 九 待裁定事项

> 以下需用户拍板；未裁定前 §5 保持占位，相关实现不得开工。

| # | 事项 | 备注 |
|---|---|---|
| ~~D1~~ | ~~跨 drill 聚合口径~~ | ✅ **已裁定 2026-08-06：删全局单一准确率，按 category 分组**，见 §5.4 |
| ~~D2~~ | ~~达标线是否机读化，挂 drill 级还是球形级~~ | ✅ **已裁定 2026-08-06：机读、挂球形级、drill 级兜底；内容侧暂不补**，见 §5.5 |
| ~~D3~~ | ~~录入原语~~ | ✅ **已裁定 2026-08-06：仅计数型**，见 §5.1 |
| ~~D4~~ | ~~走位判据是否量化~~ | ✅ **已裁定 2026-08-06：不量化**，目标区仅供自评，见 §5.1 |
| ~~D5~~ | ~~角度训练是否并入 `TrainingSession`~~ | ✅ **已裁定 2026-08-06：并入**，加 `kind` + `sessionId`，见 §5.3 |
| ~~**D9**~~ | ~~`tool` 类时长是否经 `BackendSyncService` 上传后端~~ | ✅ **已裁定 2026-08-06：上传**（用户拍板，见 §5.3）；合规声明义务转 H-09 / H-12 |
| ~~D6~~ | ~~内容变更时历史记录解引用~~ | ✅ **已裁定 2026-08-06：存快照**，见 §6.5 |
| ~~D7~~ | ~~计划推进规则~~ | ✅ **已裁定 2026-08-06：按完成推进，不按自然日；允许手动跳过/回退**（§8.8 解锁，实现落 v29 W7） |
| ~~D8~~ | ~~球形 token 规范是否重做~~ | ✅ **已裁定 2026-08-06：不做**（成本见 §3.1；`manualNN` 维持既定稳定键） |
| ~~D10~~ | ~~多分类如何承载~~ | ✅ **已裁定 2026-08-07：主分类单值 + 副分类标签（每条 ≤1），统计只记主分类**，见 §3.3（v31 R1） |
| ~~D11~~ | ~~剂量挂 drill 级还是球形级~~ | ✅ **已裁定 2026-08-07：下沉到球形级**，`sets.perFormation`；两个汇总值降级为派生兜底，见 §5.6.1（v31 R3） |
| ~~D12~~ | ~~一轮的语义~~ | ✅ **已裁定 2026-08-07：sequence / repetition 二分**；sequence 型每轮球数锁死 = 序列实测杆数，见 §5.6.2（v31 R3/R7） |
| ~~D13~~ | ~~单动作训练量基准~~ | ✅ **已裁定 2026-08-07：中等上调 + 总量护栏 40–60 球、轮数向下取、下限 1 轮**，见 §5.6.3（v31 R2） |
| ~~D15~~ | ~~`repetition` 型 10–15 带与超长阶梯（16 档）冲突~~ | ✅ **已裁定 2026-08-09：阶梯型上界放宽到档数**（`max(15, 档数)`，「一轮 = 走完一趟阶梯」），见 §5.6.2（v31 W4）；落地仅 c020/c078 两处 |
| ~~D14~~ | ~~动作库与计划如何绑定~~ | ✅ **已裁定 2026-08-07：计划只存强度系数，激活时由内容解析、落库快照**；token 升级为计划外键，见 §6.6（v31 R4/R6） |
| ~~D16~~ | ~~剂量数值口径（旧 40–60 球护栏与实际训练强度不符）~~ | ✅ **已裁定 2026-08-11：全库重定——重复型每位置 15 颗 × 轮数 = 杆数；走位链每轮 = 杆数 × N 轮**；数值真源 = `tasks/训练量填写表.md`（03:03 定稿版），见 §5.6.2（v34 R1/R2；例外 c002/c022 走 `doseNote`，R3） |
| ~~D17~~ | ~~`roundsPerFormation` 在「位置全覆盖」口径下的语义~~ | ✅ **已裁定 2026-08-11：B 方案——字段保留、默认 1，语义改为「整个动作重复几遍（倍数）」，位置永远全覆盖**；官方计划一律不写；`formations[].rounds` 不得低于内容 `defaultRounds`（I11 下限），见 §6.6（v34 R9） |
| ~~D18~~ | ~~总量护栏 D13 与逐球形真源剂量冲突~~ | ✅ **已裁定 2026-08-11：D13 作废，改形状约束**（重复型 bpr ∈ [8,15] 默认 15 + 轮数 = 杆数，阻塞级入 I6b；D15 阶梯放宽同批被取代），见 §5.6.3（v34 R13） |
| ~~D-v37-1~~ | ~~六轴打分对象层级~~ | ✅ **已裁定 2026-08-13：A = 球形级真源**（105 球形逐一打分；drill 雷达取代表球形实分；组课约束取各轴 max），见 §5.7（v37 W0） |
| ~~D-v37-2~~ | ~~衰减复现的剂量机制~~ | ✅ **已裁定 2026-08-13：B = 放宽 §6.6**（`PlanDrillDose.decay == true` 的复习条目允许 rounds < defaultRounds；首次引入仍须完整剂量），见 §6.6（v37 W0 锁语义，W4 改门禁/Resolver） |

---

## 十 版本记录

| 版本 | 日期 | 变更 |
|---|---|---|
| 1.0 | 2026-08-06 | 初版。真源裁定（球形几何 = 出片台录制序列，用户拍板）；数据流三链路；标识符契约；不变量清单 I1–I9；现存偏差登记 8.1–8.12；待裁定 D1–D8。§5 训练量与计分口径留占位。 |
| 1.1 | 2026-08-06 | v29 主控审核回写：§8.3 补全写盘测试清单（V21W2/3/4BakeTests 无 gate 且改写 drill JSON）；新增 §8.13（AngleTestDTO 缺 quizType/errorMM）、§8.14（回填脚本 --skip-json 非默认，与 v25 W1 冲突）。 |
| 1.2 | 2026-08-06 | D9 裁定：`tool` 时长上传后端（用户拍板）；§5.3 合规连带改为义务并转记 HUMAN-REQUIRED H-09/H-12。 |
| 1.4 | 2026-08-07 | v29 W8 执行回写：§8.12（c073 Bundle 陈旧）与 §8.14（`--skip-json` 非默认）标记已消化；C1/C2 归零，C3 剩 34 处失效引用（全为 `_fN_` legacy 多球形命名，随 v26 精讲迁移消化）。 |
| 1.5 | 2026-08-07 | v29 W9 执行回写：**§7.1 门禁落地**（`make verify-gate` + git `pre-push` 钩子；阻塞 C1/C2/C3/I5/I7/I8/I9，C4 已知豁免）；I5/I7/I8/I9 四个不变量实现进 `verify_tutorial_sync.py`，基线与豁免真源 `scripts/content_invariant_baselines.json`（棘轮，钉到 token/formation id）；C3 失效引用基线锁 34（只许减）；新增 **§8.15**（6 个 legacy 精讲 token 豁免，含 I5 新发现的 c022；v26 待办清单）；§8.1 补 I7 豁免与解除条件；§8.2 改写为「C4 门禁已知豁免 + 解除条件」。构造性用例 9/9：`make invariant-selftest`。 |
| 1.6 | 2026-08-07 | v26 W0：§1.1 推论追加第 4 条——drill 元数据与序列冲突时改元数据、不改序列，`drillId` 永久不变；11 个孤儿 profile 标 `retired: true` 后清空 `i7_stale_profile_exempt`（棘轮收紧）。 |
| 1.7 | 2026-08-07 | **v26 W13 收尾**：§8.1/§8.2/§8.15 标记已消化并销账；C4 从 `GATE_EXEMPT_CHECKS` 移除并转为阻塞（§7.1）；I1 状态改为已接门禁；基线复核 `i5`/`i7` 豁免为空、`c3_dead_refs_baseline=0`。 |
| 1.8 | 2026-08-07 | **v30 X-1（FL-029）**：新增不变量 **I10 模型可解码性**（`verify_tutorial_sync.py` 的 `MODEL_SPEC` 为 Swift `Codable` 模型的 Python 镜像），直接列入 §7.1 阻塞项，无豁免；构造性用例 3 条（缺必填 / 类型不符 / 可选缺省应放行）。`TutorialSection.content` 放宽为可选（45 处纯 items 节），`TutorialFormation.id` 按序列 token 补齐 7 处（c073/c074/c075）。新增 §8.16（6 个 drill `animation.pocket` 为空串，其中 2 个为解码修复后新暴露的存量缺陷）。 |
| 1.9 | 2026-08-09 | **v33 W0**：§8.5 I9 豁免 10→8；移除已录序列的 `c060`（8 杆合并）与 `c066`（0 杆空序列，见 v33 遗留 L1）。 |
| 2.0 | 2026-08-09 | **v31 W0 横切基建**。新增 §3.3 多分类口径（主分类单值 + 副分类 ≤1、统计只记主分类、不改目录）、§5.6 剂量口径（球形级 `perFormation`、sequence/repetition 二分、sequence 型每轮球数锁死 = 序列实测杆数、总量护栏 40–60 球轮数向下取、无序列 drill 人工定量豁免）、§6.6 动作库-计划绑定模型（计划只存强度系数、激活时解析、落 `DrillSet` 快照）。§6 规则 2 破坏性变更范围扩大（token 成为计划外键，删球形前须扫计划引用）。§7：**I6 口径定稿**并拆为 I6a/I6b（实现落 W4）、新增 **I11 官方计划可解析**（待实现；说明 v31 文档称其为「I10」的编号冲突）。§9 记录裁定 **D10–D14**。代码侧同批落地：`DrillContent.secondaryCategories`、`DrillSetsConfig.perFormation`、`PlanDrillRef.dose`、SwiftData **V3**（`CustomPlanDrill.roundsPerFormation`，ADR-v31-01）。⚠️ 版本号说明：`问题集合_v31.md` 写「升 v1.8」，但 1.8 已被 v30 X-1 占用、最新为 1.9，故本次进位 2.0。 |
| 2.1 | 2026-08-09 | **v31 W4 门禁与校验**。§7 表：**I6 拆为 I6a/I6b 并双双接门禁**（`i6a_token_mismatch_exempt` / `i6b_shots_exempt` 两条棘轮豁免均为空；`repetition` 型与无序列 drill 走**规则性**豁免，不入基线，门禁输出显示「规则豁免 N」），**I11 官方计划校验接门禁**（drillId 存在 / dose 恰好二选一且轮数 ≥1 / 球形 token ∈ perFormation ∩ 序列 token；残留旧格式为 WARN）；**I10 补齐 W0 新字段并扩到计划侧模型**（`secondaryCategories`、`sets.perFormation`+`FormationDose`、`OfficialPlan` 全链 + `PlanIndex`），FL-029 第 3 条销账。§7.1 阻塞项 9→12 项，构造性用例 11→23 条。§5.6.2 新增**阶梯型 `repetition` 上界放宽（D15）**：上界 = `max(15, 档数)`，全库仅 c020/c078 触发（`ballsPerRound` 15→16，总量 45→48 仍在护栏内）；总量护栏与 repetition 取值带在门禁里均为 WARN。§9 记 D15。 |
| 2.2 | 2026-08-09 | **v31 W5 收尾**。§6.6 的「计划不得存裸球数」在代码侧切净：`PlanDrillRef` 删 `sets`/`ballsPerSet` 两个可选字段与 init 参数，`TrainingDoseResolver.resolve` 删 `legacySets`/`legacyBallsPerSet` 旧格式兼容路径（解析只剩「`perFormation` 逐球形展开」与「汇总兜底」两条）。连带销账：§7 表 I11 的「残留旧格式为 WARN」**转 FAIL**（字段已不存在，再写只是被解码器忽略的哑数据），`MODEL_SPEC.PlanDrillRef` 同步删除这两个键以保持 Swift 镜像（FL-029 第 3 条）；构造性用例 23→24（新增 `i11_legacy_volume_keys`）。测试侧：`PlanDrillRef.sets/ballsPerSet` 的 `XCTAssertNil` 断言无法再编译，改为**原始 JSON 键扫描**（`assertPlanJSONHasNoLegacyVolumeKeys`），覆盖面由「focused 段的可映射字段」扩大到「全计划全部条目的 JSON 键」，⛔ 未删除任何断言语义。 |
| 1.3 | 2026-08-06 | D1/D2/D7/D8 全部裁定（用户逐项拍板，均按推荐）：§5.4 按 category 分组、§5.5 机读挂球形级（内容暂不补）、D7 按完成推进、D8 token 规范不做。§9 待裁定清零；§5 全节定稿。 |
| 2.3 | 2026-08-11 | **v34 W0 契约与门禁**。§5.6.2 剂量口径重定（D16）：数值真源 = `tasks/训练量填写表.md`（03:03 定稿版，83 drill / 105 球形 / 9493 球）；重复型「一轮 = 一个位置」每位置 15 颗、轮数 = 杆数（位置全覆盖）；走位链每轮 = 杆数 × N 轮；新增 `doseNote` 例外机制（R3，例外 c002/c022；`MODEL_SPEC.FormationDose` 与 Swift `FormationDose` 同步加可选字段，FL-029 第 3 条）；**D15 阶梯放宽被取代**（c020/c078 → 15×16，`relaxed_upper()` 删除）。§5.6.3 **D13 总量护栏作废（D18）**，替换为阻塞级形状约束（bpr ∈ [8,15] 默认 15 + 轮数 = 杆数，入 I6b；I6a 的总量 WARN 一并删除）。§6.6 **`roundsPerFormation` 语义重定义（D17，R9 B 方案）**：倍数、默认 1、位置全覆盖、官方计划一律不写；`formations[].rounds` 下限 = 内容 `defaultRounds`（I11 阻塞）。§7 表 I6b/I11 行更新。§9 记 D16–D18。构造性用例 24→28（i6b 形状约束 ×4 + i11 下限 ×1，删 `i6b_repetition_tolerated`——其「bpr=99 应放行」语义已被 R13 反转）。⚠️ 过渡窗口：形状约束转阻塞后，存量剂量（v31 口径）在 W2 写回前会触发 I6b FAIL，属预期；W2 后复核归零。 |
| 2.4 | 2026-08-13 | **v37 W0 执行负荷与复习减量（D-v37-1 / D-v37-2）**。新增 **§5.7**：六轴（进球/杆法/加塞/走位/约束/力度）0–4 整数、不合成总分；锚点表与邻轴边界备忘；球形级打分口径（105 球形逐一打分，drill 雷达 = 代表球形实分，组课约束 = 各轴 max）；走位链取分与复位型走位轴规则；`load` schema（挂 `FormationDose` 内，无 `perFormation` 则只写 drill 级 `load`）；代表分规则写死为 `sets.representativeToken`，缺省 `perFormation[0]`。§6.6 增「复习课次减量」例外：标记字段 **`PlanDrillDose.decay: Bool`**，首次引入仍须完整剂量。§7 表 I11 行补例外一句（实现落 W4）；新增 I12 行（待 W1 接门禁）。§9 记 D-v37-1/2。本批不改生产 JSON / Swift / `MODEL_SPEC`（FL-029）。 |
| 2.9 | 2026-08-14 | **v37 W5**：新增 **I13 排课门禁**并接入 `verify-gate` / pre-push。操作定义：周序只看 focused 首次引入 + scalar max；热身用 scalar（逐轴会假红 61 课）且 `reviewFrom` 咬合热身豁免；衰减查展开球数单调不增；`reviewFrom` 外键有效。构造性四例实证 exit 1。 |
| 2.12 | 2026-08-18 | **v39 W2**：I13 第 ① 条从「六轴 scalar 周序不降」改为「focused 首次引入不得早于语义课表 §5 建议周」。scalar 只给 ② 热身包络。构造性 `i13_week_order_drop` 按新口径改写。现网课表在填课（W3–W6）前会因早于建议周红，属预期。 |
| 2.11 | 2026-08-14 | **v38 W7**：I13 落地内容层第 ⑤ 条——focused 首次引入序对照 W0 §3 主课表（只比序，不比建议周）。构造性 `i13_intro_order_vs_w0`。货架 12 份。 |
| 2.10 | 2026-08-14 | **v38 W1**：§6.6 衰减可调维按 mode 分叉（repetition 降 `ballsPerRound`、sequence 降 `rounds`）。`PlanFormationRounds.ballsPerRound` 可选。I11 / Resolver / I13 展开球数同步。I13 内容层草案（引入序对照 W0 表）记入本表，落地 W7。 |
| 2.8 | 2026-08-14 | **v37 W4**：§6.6 复习减量例外落地。`PlanDrillDose.decay` / `reviewFrom` 写入 Swift + `MODEL_SPEC`；I11 `_dose_errors` 仅 `decay==true` 允许 rounds < defaultRounds；Resolver 同步；构造性 `i11_decay_rounds_below_default`。§7 I11 行状态改为已接门禁。 |
| 2.6 | 2026-08-13 | **v37 W2 / D-v37-6**：§5.7.3 上屏改为展示分；新增 **§5.7.6** 雷达映射（存储 0–4 → 展示 1–5，半径 = 展示/5）。JSON / I12 / 排课仍用存储分。 |
| 2.5 | 2026-08-13 | **v37 W1**：`LoadAxes` 写入 Swift `DrillContent` / `FormationDose` 与 `MODEL_SPEC`（FL-029）；生产 drill JSON 写回球形级 `load` + 顶层代表分；**I12 接门禁**（齐全、值域 0–4、代表分 = 球形实分；三类构造性违反实证）。契约「105 球形」= 97 个 `perFormation` load + 8 条无序列 drill 级 load（§8.5）。 |
