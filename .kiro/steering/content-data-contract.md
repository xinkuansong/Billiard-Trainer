# 内容与训练数据 — 真源契约与数据流（Steering）

> **版本**：1.8（v30 X-1：新增不变量 I10 模型可解码性并转阻塞；§8.16 登记 pocket 空值）
> **最后更新**：2026-08-07
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

---

## 四 用户训练数据结构（现状 + 已知缺陷）

```
TrainingSession（id / date / ballType / totalDurationMinutes / note / planId）
  └─ DrillEntry（drillId / drillNameZh）
       └─ DrillSet（setNumber / targetBalls / madeBalls）

AngleTestResult（date / actualAngle / userAngle / pocketType / quizType / errorMM）  ← 无会话归属
UserActivePlan（planId / isCustom / startDate / currentWeek / currentDay）
CustomPlan → CustomPlanDrill（drillId / sets / ballsPerSet / order）
DrillFavorite / SyncPendingItem
```

**已知结构缺陷（详见 §8）**：

- 每组仅落 1 个用户产生的整数（`madeBalls`）；已采集的 `duration` 与 `drillNotes` 在保存时丢弃。
- 无「球形」维度：`DrillSet` 不知道自己属于哪个球形，多球形 drill 的组次无法区分。
- 无机读达标线：`standardCriteria` 是自然语言，App 不解析。
- `currentWeek` / `currentDay` 只读不写，计划无法推进。

### 4.1 目标 schema（2026-08-06 定稿，待实现）

一次性迁移，覆盖 §5.1/§5.3 裁定、§6.5 快照裁定与 §8.7 丢弃字段。**实现时须写 ADR + `MigrationPlan`。**

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

---

## 六 内容变更规则

1. **序列变更后必跑**：`make tryout-sync` → `make verify-tutorials` → 修复 C4 不一致 →
   `verify_manual_formations.py` 复核覆盖矩阵。
2. **球形增删属破坏性变更**：会使已有用户记录的球形归属失效。
   在 §5 口径裁定（含历史记录解引用策略）落地前，**避免对已发布 drill 做球形重划分**。
3. **drill 内容重构沿用原 `drillId`**，不新建 id（既有惯例，见 c053 profile `_note`）。
4. **产物目录禁止手改**：`DrillBoards/`、`DrillTutorials/`、`Previews/`、`Videos/`、
   `DrillThumbnails/` 一律由脚本生成；手改会在下次同步/回填时被覆盖。

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

---

## 七 不变量清单（应接为门禁）

| # | 不变量 | 现有检查 | 状态 |
|---|---|---|---|
| I1 | 精讲球形数/杆数 == 序列实际值 | `verify_tutorial_sync.py` C4 | ✅ 有，✅ **已接门禁**（v26 W13 转正） |
| I2 | 出片产物不早于源序列 | C1 | ✅ 有，✅ **已接门禁** |
| I3 | 回填图与产物图字节一致 | C2 | ✅ 有，✅ **已接门禁** |
| I4 | 精讲 `image` 指向最新图 | C3（含失效引用棘轮） | ✅ 有，✅ **已接门禁** |
| I5 | 精讲 formation token ⊆ 序列 token 集合 | I5（v29 W9 新增） | ✅ 有，✅ 已接门禁（legacy 豁免已于 v26 清空） |
| I6 | `sets.defaultSets` 与球形数的关系符合口径 | — | ❌ 缺（口径本身未定，见 §5 待补批次） |
| I7 | profile formation 集合 == 序列 token 集合，或 profile 标记为已退役 | I7（v29 W9 新增） | ✅ 有，✅ 已接门禁（孤儿 profile 已退役，豁免已清空） |
| I8 | `Bundle/DrillBoards` == `content/.../sequences` 的 `drill_c*.json` 子集 | I8（v29 W9 新增） | ✅ 有，✅ 已接门禁 |
| I9 | 每个 `index.json` 登记的 drill 至少有 1 个序列，或在豁免名单内 | I9（v29 W9 新增） | ✅ 有，✅ 已接门禁（豁免见 §8.5） |
| I10 | 全部 bundled drill JSON（含 `index.json`）能被 App 的 `Codable` 模型解码——必填字段齐全、类型正确 | I10（v30 X-1 新增） | ✅ 有，✅ 已接门禁（无豁免） |

**I10 说明（FL-029）**：`DrillContentService.loadDrillFromBundle` 曾用 `try?` 吞掉
`DecodingError`，34/77 条 drill 因缺 `TutorialSection.content` / `TutorialFormation.id`
而**静默不进 App**（动作库只有 43 条），且失败信息仅为「返回 nil」，无法定位字段。
I10 的必填字段表（`verify_tutorial_sync.py` 的 `MODEL_SPEC`）是 Swift 模型的 Python 镜像，
**改 Swift 模型必须同步改它**；Swift 侧同位检查为
`DrillContentValidationTests.test_allIndexedDrills_loadSuccessfully`（失败时打印 codingPath）。

### 7.1 门禁（2026-08-07 v29 W9 落地）

**入口**：`make verify-gate`（= `verify_tutorial_sync.py --gate`），由 git `pre-push` 钩子调用。
本仓库无 CI，钩子是唯一自动阻塞点。

```bash
make -f scripts/Makefile install-hooks   # 每个克隆装一次（git 不跟踪 .git/hooks）
make -f scripts/Makefile verify-gate     # 本地自查，与钩子同一入口
make -f scripts/Makefile invariant-selftest  # 构造性用例：证明每个检查项真会报错
```

- **阻塞项**：C1 / C2 / C3 / C4 / I5 / I7 / I8 / I9 / I10。
- **已知豁免（不阻塞）**：无（v26 W13：`GATE_EXEMPT_CHECKS` 已清空；I9 的 10 条无序列豁免仍在基线文件，属 §8.5 永久登记）。
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

### 8.5 10 个 drill 无任何序列，且本质上录不出

`drill_c008`（手架练习）、`c043`（高级手架稳定性）、`c059`（跳球基础）、
`c060`（安全球布置）、`c061`（解球）、`c065`（Ghost Game）、`c066`（开球）、
`c067`（9 球标准清台）、`c068`（五球连打走位）、`c070`（全台清台挑战）。

原因分别为：盘面随机/对抗性（Ghost、开球、清台类）、无特定盘面（手架类）、
物理引擎不支持腾空（跳球，见 `content/position_play/README.md` 3D 契约节）、
成功判据非进袋（安全球、解球）。

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
**处置**：随 v29 W5（cognitive 归并）一并补齐，或明确留档不同步；改 DTO 须同步后端 schema。

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
| 1.3 | 2026-08-06 | D1/D2/D7/D8 全部裁定（用户逐项拍板，均按推荐）：§5.4 按 category 分组、§5.5 机读挂球形级（内容暂不补）、D7 按完成推进、D8 token 规范不做。§9 待裁定清零；§5 全节定稿。 |
