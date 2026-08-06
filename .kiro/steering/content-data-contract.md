# 内容与训练数据 — 真源契约与数据流（Steering）

> **版本**：1.0（契约层定稿 + 现存偏差登记；结构层为占位）
> **最后更新**：2026-08-06
> **地位**：本文件是「内容资产真源归属、标识符命名、数据流向、用户训练数据口径」的**唯一契约来源**。
> 其余文档（`QiuJi/Resources/Drills/schema.md`、`content/position_play/README.md`、
> `docs/06-技术架构.md`）在与本文件冲突时**以本文件为准**，并应改为引用本文件而非重复定义。
>
> **本文件不是现状快照。** 描述性事实集中在 §8 现存偏差登记，会随收敛而清空；
> §1–§7 是约束，变更需走 ADR。

---

## 〇 为什么需要这份文件

同一个概念在本项目中曾出现多个真源并各自演化，已造成可验证的偏差：

- 「球形」同时存在于 `content/drill_profiles/*.profile.json`、drill JSON 的
  `tutorial.formations`、`content/position_play/sequences/*.json` 三处，
  当前 **11/11 个 profile drill 的三者不一致**（§8.1）。
- `make verify-tutorials` 的 C4 检查已能发现其中一类偏差，但**不是阻塞门禁**，
  当前长期处于 23 项 FAIL 状态无人处理（§8.2）。
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

校验：make verify-tutorials（C1 出片新鲜度 / C2 回填一致性 / C3 引用指向 / C4 结构对齐）
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

> 本节部分定稿。**§5.4 / §5.5 仍待裁定**，未定部分的实现不得自行定义口径。

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

⚠️ **合规连带**：`tool` 时长若经 `BackendSyncService` 上传，属"使用数据/产品交互"类个人信息，
须在 H-09 隐私政策与 H-12 App Store 隐私问卷中如实声明。是否同步见 §9 D9。

### 5.4 跨 drill 聚合口径 — 待裁定（D1）

### 5.5 达标线定义与层级 — 待裁定（D2）

`DrillSet` 已预留 `passMade` / `passTotal` 快照字段，使 D2 无论裁为 drill 级还是球形级
**都不需要再改 schema**：挂 drill 级即同一 drill 各组同值，挂球形级即逐组不同。

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
| I1 | 精讲球形数/杆数 == 序列实际值 | `verify_tutorial_sync.py` C4 | ✅ 有，❌ 未接门禁 |
| I2 | 出片产物不早于源序列 | C1 | ✅ 有，❌ 未接门禁 |
| I3 | 回填图与产物图字节一致 | C2 | ✅ 有，❌ 未接门禁 |
| I4 | 精讲 `image` 指向最新图 | C3 | ✅ 有，❌ 未接门禁 |
| I5 | 精讲 formation token ⊆ 序列 token 集合 | — | ❌ 缺 |
| I6 | `sets.defaultSets` 与球形数的关系符合口径 | — | ❌ 缺（依赖 §5） |
| I7 | profile formation 集合 == 序列 token 集合，或 profile 标记为已退役 | — | ❌ 缺 |
| I8 | `Bundle/DrillBoards` == `content/.../sequences` 的 `drill_c*.json` 子集 | — | ❌ 缺 |
| I9 | 每个 `index.json` 登记的 drill 至少有 1 个序列，或在豁免名单内 | — | ❌ 缺（豁免见 §8.5） |

**门禁要求**：I1–I4 应在 CI 或 pre-push 中阻塞；I5–I9 需新增检查项。
在接入门禁前，任何"已修复"声明必须附 `make verify-tutorials` 实际输出。

---

## 八 现存偏差登记

> 本节记录已发现、尚未收敛的偏差。收敛一条删一条，并在 `tasks/PROGRESS.md` 留痕。

### 8.1 profile 与精讲双双成为孤儿（11 个 drill）

`8293ef4` 全库退役脚本推导序列、换成人工录制后，`content/drill_profiles/` 的 11 个
profile 及与之对齐撰写的精讲 `tutorial.formations` 描述的球形**已不存在**。

| drill | profile 球形 | 精讲 formations | 实际序列文件 |
|---|---|---|---|
| c016 | 4 | 4 | 1 |
| c018 | 6 | 6 | 1 |
| c020 | 4 | 4 | 1 |
| c021 | 4 | 4 | 1 |
| c053 | 8（A1–A8） | 8（A1–A8） | 2（manual01 10 杆 / manual02 13 杆） |
| c073 | 4 | 4 | 2 |
| c074 | 4 | 4 | 2 |
| c075 | 6 | 6 | 3 |
| c076 | 6 | 6 | 2 |
| c077 | 6 | 6 | 1 |
| c078 | 4 | 4 | 1 |

profile 与精讲 **11/11 完全一致**；两者与实际序列 **11/11 全部错位**。

**处置**：按 §1.1 以序列为准重写精讲；profile 标注为已退役设计档案或删除。

### 8.2 C4 长期 FAIL 且无人处理

`make verify-tutorials --only C4` 当前：**通过 2 / 不一致 23 / 待迁移或无序列 52**。
不一致清单涵盖 c001、c002、c005、c010–c015、c017、c022–c030、c035、c039、c041、c042。

### 8.3 缩略图产物由测试用例生成

`Resources/DrillThumbnails/*.png` 由 `DrillThumbnailRenderer` 烘焙，触发方式是运行
`DrillThumbnailBakeRunnerTests` / `PositionPlaySequenceExportRunnerTests.test_exportAllSequences`。
`tasks/IMPLEMENTATION-LOG.md` 已记录该副作用（跑全量测试会把 PNG 写回仓库）。

**问题**：测试带写副作用，无法接 CI（一跑即产生 diff）。
**处置**：拆为显式 make 目标，测试侧改为只读校验。

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

### 8.12 Bundle 同步陈旧

`drill_c073` 球形 1 上游为 7 杆、Bundle 内为 6 杆。重跑 `make tryout-sync` 即可。

---

## 九 待裁定事项

> 以下需用户拍板；未裁定前 §5 保持占位，相关实现不得开工。

| # | 事项 | 备注 |
|---|---|---|
| D1 | 跨 drill 聚合口径：达成度等权平均 / 达标率 / 维持球数加权 | 现为球数加权，权重被 `defaultBallsPerSet` 扭曲 |
| D2 | 达标线是否机读化，挂 drill 级还是球形级 | c053 原设计已是逐球形不同阈值 |
| ~~D3~~ | ~~录入原语~~ | ✅ **已裁定 2026-08-06：仅计数型**，见 §5.1 |
| ~~D4~~ | ~~走位判据是否量化~~ | ✅ **已裁定 2026-08-06：不量化**，目标区仅供自评，见 §5.1 |
| ~~D5~~ | ~~角度训练是否并入 `TrainingSession`~~ | ✅ **已裁定 2026-08-06：并入**，加 `kind` + `sessionId`，见 §5.3 |
| **D9** | `tool` 类时长是否经 `BackendSyncService` 上传后端 | 上传才有产品分析数据，但需在 H-09 / H-12 声明；不上传则仅用户本机可见 |
| ~~D6~~ | ~~内容变更时历史记录解引用~~ | ✅ **已裁定 2026-08-06：存快照**，见 §6.5 |
| D7 | 计划推进规则：按完成推进 / 按自然日推进 / 混合 | 阻塞 §8.8 修复 |
| D8 | 球形 token 规范是否重做 | 成本见 §3.1，需 ADR |

---

## 十 版本记录

| 版本 | 日期 | 变更 |
|---|---|---|
| 1.0 | 2026-08-06 | 初版。真源裁定（球形几何 = 出片台录制序列，用户拍板）；数据流三链路；标识符契约；不变量清单 I1–I9；现存偏差登记 8.1–8.12；待裁定 D1–D8。§5 训练量与计分口径留占位。 |
