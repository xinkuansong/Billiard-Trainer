# 实施日志（IMPLEMENTATION LOG）

> Orchestrator / 各专项角色在发生返工、设计调整或模式发现时维护本文件。
> **目的**：捕获实施轨迹（失败、设计调整、可复用模式），便于规则改进与跨会话知识累积。
> **编号**：三种条目类型，各自独立递增：
> - `FL-NNN`：失败与返工（Failure）
> - `DR-NNN`：设计调整（Design Refinement）— 设计规范在 SwiftUI 实施中需要调整
> - `PD-NNN`：模式发现（Pattern Discovery）— 可复用的实施模式
>
> 与 `tasks/PROGRESS.md` 中 `⚠️ 返工（见 FL-xxx）` 交叉引用。
> 与 `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog 同步更新。

---

## 如何新增一条记录

1. 使用下一个可用编号（FL/DR/PD 各自独立计数）。
2. 必填字段：`任务`、`描述`、`日期`。
3. FL 额外必填：`现象`、`根因`、`解决`。
4. DR 额外必填：`原始规范`、`调整后`、`原因`。
5. PD 额外必填：`模式描述`、`适用场景`、`代码示例`。
6. 通用选填：`回写目标`（指向具体 `.mdc` / `SKILL.md` 文件）。
7. 同步操作：
   - FL → 在 `PROGRESS.md` 将任务标为 `⚠️ 返工（见 FL-NNN）`
   - DR/PD → 更新 `UI-IMPLEMENTATION-SPEC.md` § Changelog
   - 全部 → 触发 Orchestrator 回写流程（见 `00-orchestrator.mdc` § 实施知识回写）

### FL 模板

```markdown
## FL-NNN
- **任务**：T-Pn-xx
- **现象**：（可观测的失败）
- **根因**：（为何发生）
- **解决**：（实际修复）
- **日期**：YYYY-MM-DD
- **回写目标**：（可选）`路径/to/rule.mdc`
- **已应用至**：⏳ 待回写 / ✅ `路径/rule.mdc`（YYYY-MM-DD）
```

### DR 模板

```markdown
## DR-NNN
- **任务**：T-Pn-xx
- **原始规范**：（UI-IMPLEMENTATION-SPEC 或设计截图中的原始定义）
- **调整后**：（SwiftUI 实施中实际采用的值/行为）
- **原因**：（为何需要调整）
- **影响组件**：（受影响的 BT* 组件或页面）
- **日期**：YYYY-MM-DD
- **回写目标**：`SKILL.md` / `UI-IMPLEMENTATION-SPEC.md`
- **已应用至**：⏳ 待回写 / ✅ `路径`（YYYY-MM-DD）
```

### PD 模板

```markdown
## PD-NNN
- **任务**：T-Pn-xx
- **模式描述**：（一句话概括可复用模式）
- **适用场景**：（何时应使用此模式）
- **代码示例**：（关键 SwiftUI 代码片段）
- **日期**：YYYY-MM-DD
- **回写目标**：`20-swiftui-developer.mdc` / `SKILL.md`
- **已应用至**：⏳ 待回写 / ✅ `路径`（YYYY-MM-DD）
```

---

## FL 记录（失败与返工）

## FL-001
- **任务**：T-P1-07 / T-P2-05（用户认证 + 数据同步）
- **现象**：H-06（LeanCloud 账号注册）永久阻塞 — LeanCloud 已停止中国大陆新用户注册，无法解除阻塞。
- **根因**：架构设计（v0.3）依赖 LeanCloud 作为用户认证和数据同步托管服务，而该服务在项目开发期间停止国内新注册，属于外部服务不可用风险未在选型时充分评估。
- **解决**：执行 ADR-001（2026-03-29）— 改用自建极简 REST API（腾讯云 Node.js + MongoDB）。iOS/Android 共用同一套 API，长期架构更清晰。同步移除 LeanCloud Swift SDK，包体积减小约 5MB。
- **日期**：2026-03-29
- **回写目标**：`30-data-engineer.mdc`
- **已应用至**：✅ `.cursor/rules/30-data-engineer.mdc` § 经验教训 / ⛔ FL-001（2026-03-29）

---

## DR 记录（设计调整）

## FL-028
- **任务**：v30 W1 试点（T03 + T08）人工验收
- **用户判定**：未通过。原话「和现有的其他学页面风格完全不同，也没有说明图，很不满意」。
- **翻车事实**（主控只读取证核实，均带行号）：
  1. **零配图**：现有 6 张文档学页每页 3–8 张说明图（主范式 `BTTableFigure`：真台 USDZ 底图 + `Path` 叠线 + 球 / 点 / 标签）；试点两页配图数 = **0**。T03 视图注释还把「不新造静图、改深链」写成了策略，DR-064 与转写模板 v1.0 也把「深链代图 / 战术类无图」写成了合规口径 —— **深链不能代替页内说明图**，用户要的是页内看得到图。
  2. **风格自立体系**：页头用了 `.btHeadline` 题眼（现有学页首卡是 `.btTitle` 卡标题）；误区用 `.btWarning` 集中卡（现有是 inline `.btAccent` 三角 + 10% accent 底）；序号圆底用 `btPrimaryMuted`（现有 `.btPrimary` 实底白字）；表格用 `Grid`（现有 `HStack` 行）；多了 `.padding(.top, Spacing.md)`；页尾缺「相关页面」`.btTitle` 标题结构；无页级控件。
- **根因**：①W0 组件规范把配图写成「分级可选」（§一.3），试点时又按「成本最低」优先选了深链，等于**用规范漏洞给零配图背书**；②风格对齐只做到「用了 `LearnDoc*` 正文件」这一层，没有拿现有学页逐维度对表就自行新增视觉口径。
- **强制检查点（已回写规范）**：
  1. 每篇理论页**至少一张页内说明图**，放对应正文节的 `LearnDocSectionCard` 内；⛔ 深链只作「看更多」。
  2. 物理几何类必走 `BTTableFigure` 栈 + **几何真源函数**（⛔ 手填坐标常量凑图）+ 不变量单测 + 汇报给「图元 ↔ 真源函数」映射；战术类受红线 5 约束只能画**非球形抽象图示**，需要真实球形的图**登记文字描述交人工录制**。
  3. 新页提交前逐项对照一张现有学页截图（页壳 padding / 节卡 / 误区 / 序号 / 表格 / 页尾六项），差异要么消除要么在规范里立案。
- **返工产物**：`build/v30-w1-rework-logs/`、`build/v30-w1-rework-screenshots/`（含现有学页「瞄准原理」对比截图）。
- **日期**：2026-08-07
- **回写目标**：`docs/research/20260807-v30理论页组件规范.md`（新增 §四 配图硬性章节 + §三 风格收敛铁律）、`docs/research/20260807-v30理论转写模板.md`（§3.1 配图决策树）
- **已应用至**：✅ `docs/research/20260807-v30理论页组件规范.md` v1.2 §三/§四/§五/§六/§二 + Changelog（2026-08-07）；✅ `docs/research/20260807-v30理论转写模板.md` v1.1 §一/§3.1/§3.2/§四 + Changelog（2026-08-07）；✅ 本文件 DR-064 补「返工 r1 修订」段（2026-08-07）

## DR-064
- **任务**：v30 W1 试点定调（球理详情页 T03 切线法则 + T08 风险报酬决策矩阵 + 转写模板）
- ⚠️ **返工 r1 修订（2026-08-07，见 FL-028）**：本条第 1 项的组件清单与配图口径已被返工覆盖 ——
  1. `TheoryPageHeader` API 改 `(pageID:headline:detail:caption:)`，结论主句 = `LearnDocSectionCard` 卡标题（`.btTitle`），⛔ 不再自立 `.btHeadline` 题眼层；
  2. `TheoryMistakeCard` 改现有学页旁注范式（`.btAccent` 三角 + 10% accent 底 + 脚注级说明）；`TheoryNumberedList` 序号圆底改 `.btPrimary` 实底白字 18pt；`TheoryMatrixTable` 由 `Grid` 改 `HStack` 行范式（同 `ContactPointTableView`）；
  3. **配图从「可选 / 可深链代替」升级为硬性**：T03 落 `TangentPerpendicularFigure`（新，`BTTableFigure` 栈）+ 复用 `SeparationPathsFigure`（该件由 `private` 放开为 internal 并加 `emphasizeAll` 参数，加法式改动）；T08 落两张非球形抽象图示（`ThreeQuestionFlowFigure` / `RiskRewardZoneFigure`）；新增几何不变量用例 `QiuJiTests/TheoryFigureGeometryTests.swift`；
  4. 页尾结构对齐现有学页「相关页面」`.btTitle` + `PracticeCTA`(≤2) + `LearnDocTextLink`；去掉 `.padding(.top, Spacing.md)`；T03 加 `LearnControlStrip.Theta`（θ 只挪母球、切线不动，正是本页论点）。
- **原始规范**（`docs/research/20260807-v30理论页组件规范.md` v1.0，W0 定稿）：
  1. 组件家族真源只有 `LearnDocChrome.swift`，「⛔ 不为单页新建视觉件；确需新组件 → 先加进 `LearnDocChrome.swift`」；页头三件套、误区卡、步骤 / 矩阵表只给了**样式口径**，无落地组件。
  2. 上线状态成对维护 = **两处**（`theoryDestination` switch + `TheoryCatalog.isPublished`）。
  3. 索引页副标题「只准截断」，`TheoryCatalogTests` 以连续子串断言固化（同 ADR-P12-04 第 5 条）。
  4. 公式一律「视觉降级但**不删**」。
  5. 页尾「相关训练」无合适训练页时「直接省略该区块」。
- **调整后**（W1 落地口径，已回写规范 v1.1 与 ADR-P12-04 第 5 条）：
  1. **新增理论页专用共用件文件** `QiuJi/Features/AngleTraining/Theory/TheoryPageChrome.swift`：`TheoryPageHeader`（编号 chip 对读屏隐藏 + 一句话结论卡 + 可选边界预告）、`TheoryMistakeCard`、`TheoryNumberedList`、`TheoryMatrixTable`（原生 `Grid`）、`View.theoryPageChrome(title:)`。分工：**通用学页件仍进 `LearnDocChrome.swift`，理论页专用件进 `TheoryPageChrome.swift`**；单页内一律不复制。
  2. 成对维护面扩到**三处**（增测试侧上线清单 `TheoryCatalogTests.registeredPageIDs` + `V30W0TheoryIndexUITests.publishedPageIDs`），由 `testPublishedEntriesMatchRegisteredDestinations` 守；`V30W0TheoryIndexUITests` 的「12 条全部不可点」改为**已上线可点 / 未上线不可点**的分治断言（用例保留，不删）。
  3. 副标题纪律按 **X-v30-2** 放宽为「语义等价的限定改写 + 逐条取舍记录」，连续子串断言被四道断言**替代**（数值单位守恒 / 语义锚词 / 无拉丁字母 / 逐字与改写条目集合固定），逐字条目仍走原子串断言。
  4. 公式口径收窄：**可操作口径公式必留**（几何 / 换算，如 `d = 2R·sinθ`）；**纯解释性公式剔除**（读者不会代入计算，实例 = T08 期望值式 `EV = P(make)×P(position)×V(continue) − P(miss)×V(opponent)`），剔除须在取舍表记理由。
  5. 页尾「相关训练」改为**优先挂一个真能点的相关演示 / 解题页 + 一句现状说明**（T03 → 「分离角与走位」，T08 → 「防守」），实在无处可去才整块省略；「敬请期待」「图待补」仍禁。
- **原因**：①页头 / 误区 / 矩阵三件套是 12 篇共用形态，只给样式口径必然导致 12 份复制粘贴漂移，而它们又是理论页专用、不适合塞进通用 `LearnDocChrome`；②W0 的两处成对维护无测试护栏，试点时实测「只改 switch 不改 `isPublished`」不会红，纪律形同注释；③X-v30-2 主控裁定（英文术语上屏与 §一.4 转写纪律冲突）；④「不删公式」的一刀切在 T08 遇到反例——期望值式对球手无操作价值，硬留反而稀释三问这个真正可执行的结论；⑤「无合适训练页就省略」在试点时发现过于消极：两篇都存在真正相关的演示 / 解题页，省略等于浪费既有内容。
- **影响范围**：`Theory/TheoryPageChrome.swift`（新增）、`Theory/TheoryT03View.swift` / `TheoryT08View.swift`（新增）、`Theory/TheoryCatalog.swift`（副标题 12 条改写 + t03/t08 `isPublished`）、`App/MainTabView.swift`（`theoryDestination` 注册两页）、`QiuJiTests/TheoryCatalogTests.swift`、`QiuJiUITests/V30W0TheoryIndexUITests.swift` + 新增 `V30W1TheoryPageUITests.swift`；文档 `20260807-v30理论页组件规范.md` v1.1、新增 `20260807-v30理论转写模板.md` v1.0、`tasks/phases/P12-content-system-theory.md` ADR-P12-04 第 5 条；后续 W2–W4 十篇全部按此执行。
- **日期**：2026-08-07
- **回写目标**：`docs/research/20260807-v30理论页组件规范.md`、`docs/research/20260807-v30理论转写模板.md`、`tasks/phases/P12-content-system-theory.md`（ADR-P12-04 第 5 条）
- **已应用至**：✅ `docs/research/20260807-v30理论页组件规范.md` v1.1 §一/§二/§三/§四/§五 + Changelog（2026-08-07）；✅ `docs/research/20260807-v30理论转写模板.md` v1.0（2026-08-07）；✅ `tasks/phases/P12-content-system-theory.md` ADR-P12-04 第 5 条（2026-08-07）

## DR-063
- **任务**：v26 W1 试点二审人工验收（c032/c053/c008/c065，DR-062 返工稿）
- **原始规范**：
  1. DR-062 第④条定「力度纯数值口径」（「力度 2.1」），打点同为数值读数。
  2. 袋口中文名沿用 schema ID 直译（topLeft=左上袋…上中袋/下中袋），方位词（digest `region`/`octant`、袋口名）全部落在**横放 canvas 系**；SKILL §0a 用「参照物绕行 + 禁止写作者自行旋转」缓解竖图错位（v25 E9 遗留）。
- **调整后**（用户 2026-08-07 二审反馈裁定）：
  1. **力度/杆法定性词汇为主**：正文以定性词 + 组合表达（小力/轻力/中力/中大力/大力；中杆/中高杆/中低杆/高杆/低杆/纯高杆/纯低杆；半颗皮头/一颗皮头的左塞/右塞；如「中高杆加一颗皮头的右塞"），数值退居括号补充（首次出现或关键档）。分档阈值与 App `PowerDisplay.name` / `SpeedLevel` 同源，塞量皮头换算须先钉死 digest 读数单位契约再定阈值。整体行文更自然（教练口吻），**部分收回 DR-062 第④条**。
  2. **用户可见方位词全部改屏幕系（portrait）**：经代码链（`AngleSceneCalculator.pocketCenters` + `ShotIntent.pocketIndex` + `CameraRig.applyTopDown2DRotated` 相机基向量推导）与截图（c053 打 `bottomCenter`，屏幕显示右侧中袋）双重验证，portrait 屏幕上=世界 +X、屏幕右=世界 +Z，故 schema ID → 屏幕名为：`topLeft`=左下角袋、`topRight`=左上角袋、`bottomLeft`=右下角袋、`bottomRight`=右上角袋、`topCenter`=左侧中袋、`bottomCenter`=右侧中袋。旧中文名的「上/下」实为屏幕「左/右」，用户指认正确。修复点在**生成端与解码端**：digest（`POCKET_NAMES`/`region`/`octant`）与 App portrait 面袋口解码（`DrillCoverAnnotation.pocketShortLabel` 等）统一输出屏幕系词；写作者继续照抄事实清单，废除 §0a「参照物绕行」条款。landscape 插图面（learn 页横图）参照系本就自洽，须逐点核对后保留或注明，禁止一刀切。
  3. **文档真源纠错**：`table-geometry.md` 与 `geometry-spatial-reasoning/SKILL.md` 速查中 `canvasY = (0.635 − sceneKitZ)/2.540` 与代码真源 `AngleSceneCalculator.sceneToNormalized`（`ny = (z + 0.635)/2.540`，canvasY 增 = Z 增）**符号相反**，按代码为准修正文档（含归一化袋口表与「原点=SceneKit (−1.270, **−0.635**)」）。
- **原因**：①DR-062 把「语域去堆叠」矫枉成「纯数值」，丢了台球教学的自然语言；②方位词参照系错位的根因是**事实清单生成端**声明在横放 canvas 系，而全部 drill 用户面（精讲/封面/击打页）为 portrait 旋转顶视，v25 E9 的「参照物绕行」掩盖而非消除错位，袋口名这种无参照物可绕的词必然暴露。
- **影响范围**：`scripts/tutorial_digest.py`（袋口名/region/octant/新增定性力度杆法输出）；App 袋口 ID 解码点全仓清查（portrait 面改名）；`.kiro/steering/table-geometry.md` 与 `geometry-spatial-reasoning/SKILL.md` 公式修正；`tutorial-authoring/SKILL.md`（语域/方位/自查清单）；提示词模板 v3；c032/c053/c008/c065 三轮返工；W2–W12 全部批次。
- **日期**：2026-08-07
- **回写目标**：`.cursor/skills/tutorial-authoring/SKILL.md`、`.cursor/skills/geometry-spatial-reasoning/SKILL.md`、`.kiro/steering/table-geometry.md`
- **已应用至**：✅ `tutorial-authoring/SKILL.md` §0a 方位词 / §语域 / §模板袋口名 / §自查清单 12b·13（2026-08-07）；✅ `geometry-spatial-reasoning/SKILL.md` §速查（canvasY 公式修正 + 双屏幕系 + portrait 袋口名，2026-08-07）；✅ `.kiro/steering/table-geometry.md` v1.1（canvasY 公式/原点/portrait 映射表，2026-08-07）；✅ `docs/research/20260807-v26批量执行提示词模板.md` v3（2026-08-07）

## DR-062
- **任务**：v26 W1 试点人工验收（c032/c053/c008/c065）
- **原始规范**：`tutorial-authoring/SKILL.md` 应用课模板对所有多杆序列统一要求逐杆全文三条目 + 全组指认一个「胜负手」；对语域（面向谁写）无显式约束。
- **调整后**（用户 2026-08-07 验收反馈裁定，结构方案选「混合式」）：
  1. **序列形态二分**：写逐杆节前先按客观判据判定**走位链**（目标球距袋逐杆变化，落点因果衔接）vs **独立阶梯**（目标球距袋恒定 + 袋口不变 + 杆法锁死，单变量扫描）。判据可从 digest 事实清单机读。
  2. **独立阶梯混合式结构**：技术原理讲透唯一变量；开局节附阶梯总表；逐杆节保留（配图/params/C4 依赖）但仅锚点档（入门/教学锚点/上限/缺陷档，2–4 杆）写全三条目，中间档压成一句自检。⛔ 禁逐杆同构解说。
  3. **胜负手仅限走位链**：阶梯各档独立，最难档只是「上限档」，禁用「胜负手/关键档」措辞。
  4. **语域规则**：正文面向学员，禁内部词汇（退役/profile/manual/digest/待重录/批次号）与验收自证话术；力度纯数值口径（「力度 2.1」，禁「轻力 2.1 档」堆叠）；示范缺陷只写用户视角一句话，内部信息进交付说明。
  5. **多球形关系三问**：第 2 形起技术原理首段先答「共享什么/变了什么（数值对数值）/为何此顺序」。
- **原因**：W1 试点按旧规范产出 c032（7 档逐杆同构解说 + 伪「胜负手」）与 c053（正文出现「已退役的旧 8 球形矩阵」等内部史），用户验收指出冗余、概念错位与语域泄漏；根因是模板按杆数组织信息而非按变量数，且规范未区分写作对象。
- **影响范围**：`tutorial-authoring/SKILL.md`（形态判定/混合式结构/重点指认限定/语域节/自查清单 12·12b/交付说明）；`docs/research/20260807-v26批量执行提示词模板.md`；c032/c053 返工重写；W2–W12 全部阶梯型条目（c001–c013 新版修复、c049 力度阶梯、c075–c078 塞量递进等）。
- **日期**：2026-08-07
- **回写目标**：`.cursor/skills/tutorial-authoring/SKILL.md`
- **已应用至**：✅ `.cursor/skills/tutorial-authoring/SKILL.md` §序列形态判定 / §语域 / §重点指认 / §自查清单 / §交付说明（2026-08-07）

## DR-061
- **任务**：试打页序列演示可暂停/继续/上一杆/重播；打点力度只读上屏；顶部信息去重与播完复位（v28 Q1–Q5）
- **原始规范**：Q19.2④ 落地态——序列模式**隐藏**打点盘/力度条/瞄准轮；主键播放中显示不可点的「演示中」（`BTStrikeTitle.sequenceBusy`）；「上一杆」「回放」恒 `disabled`；台面上方另有 `tryout.sequenceStepBar` 信息条（含袋口）；整条播完停在末杆终局。
- **调整后**：
  1. **主键三态**：`PositionPlayViewModel.SequencePlayState`（`idle` / `playing` / `paused`）+ `pauseRequested`，主键 `击打 ⇄ 暂停 ⇄ 继续` 走单一入口 `toggleSequencePlayback()`。暂停请求已受理但当前杆未播完时主键置灰（`isSequencePausePending`），既防连点也是「已收到」反馈。
  2. **暂停语义 = 杆边界生效**：唯一兑现点在 `scheduleNextSequenceStep`，当前杆必定播完并落到静止位，停在该杆终局盘面与该杆参数。与 DR-060 详情页演示同语义。
  3. **上一杆 / 重播**：仅暂停态可用（`canReplayPreviousStep` / `canReplayCurrentStep`）。二者复用 `playSingleSequenceStep`——预置 `pauseRequested` ⇒ 这一杆播完在边界自动停回暂停态。原恒灰的「回放」钮改文案「重播」并接线（`BTShotActionColumn.playbackTitle`）。
  4. **打点/力度只读上屏**：序列模式恢复渲染 `BTShotInstrumentColumn`，读数为本杆真值；新增 `isReadOnly`（力度条不接受拖动但**不灰化**，灰化会让读数不可读）与 `spinTapEnabled`（仅暂停态允许点开打点盘，播放中点开会挡台面）。`BTSpinPad` / `BTSpinPadCard` / `BTSpinPadOverlay` 新增 `isReadOnly`：只读卡隐藏四向微调键与「回中」，白盘不接受拖动——演示的是录制真值，不允许改。
  5. **信息去重（Q3/Q4）**：删除 `sequenceStepBar` 与随之作废的 `SequenceStepInfo` / `currentSequenceInfo`；当前杆信息只在导航副标题出现一次，且**去掉袋口**（`sequenceStatusText` 只留「第 n/N 杆 · 打 X 号 · 打点 · 力度」，袋口由台面高亮自证）。
  6. **播完复位（Q5）**：`finishSequencePlayback` 终局停留 `sequenceFinishHold` 后自动回初始球形并预览第 1 杆；停留期内用户重摆/切模式/重开播则放弃该次复位。
  7. **求解缓存**：`prediction(forStep:)` 懒缓存，让「继续/上一杆/重播」不重复求解。**不做后台预解**——实测整条序列后台预解与主线程求解并发会打崩 App（Lost connection），已在代码注释钉死。
- **原因**：用户反馈①演示无法暂停/继续/回看上一杆；②演示时看不到本杆打点与力度；③顶部信息过挤且袋口冗余；④台面上方信息条与导航副标题重复；⑤播完停在末杆、无法直接再看。
- **影响组件**：`PositionPlayViewModel`、`PositionPlayComposerView`、`BTShotInstrumentColumn`、`BTSpinPad` / `BTSpinPadCard` / `BTSpinPadOverlay`、`BTShotPageChrome`（`BTStrikeTitle` / `BTShotActionColumn` / `BTSolverNavStatus`）
- **验证**：`make build` → `BUILD SUCCEEDED`；`DrillTryoutUITests` 3/0——新增 `testSequencePlaybackPauseResumeAndReset`（开播主键变「暂停」→ 停在第 1 杆终局、主键变「继续」→ 只读打点盘无「回中」与微调键 → 再走一杆后「上一杆」可用、重播完回暂停态且副标题回第 1 杆 → 继续播到底自动回初始球形），截图 `p01-playing` / `p02-paused` / `p03-paused-spinpad-readonly` / `p04b-after-replay-previous` / `p05-finished-reset`；`testTryoutSequenceModeSwitching`、`testTryoutC042Flow` 通过（后者原为**改动前既有失败**，本会话跑 baseline 实测确认，失败因 c042 内容已变为 2 球形 / 球形1 8 杆，本次一并把过期断言更正为真实值）；`DrillTryoutBoardStoreTests` / `SpinPadLayoutTests` / `BTShotHUDBarRenderTests` / `PositionPlayUndoSnapshotTests` 合计 22/0。
- **注**：`QiuJiTests` 全量包含 `PositionPlaySequenceExportRunnerTests.test_exportAllSequences`（重渲全部出片），会把 `Resources/DrillThumbnails/*.png` 写回仓库并耗时极长，本次未跑全量，改跑上述针对性用例。
- **日期**：2026-08-06
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-06）

## DR-060
- **任务**：详情页/训练页台面演示回放钮加播放中状态 + 杆边界可暂停
- **原始规范**：F-SC-01（`docs/ui-polish/11-台面演示与场景组件.md`）——回放**不可打断**；播放中按钮 `disabled` + `play.fill` 降透明；明确禁用 stop/pause 图标（按钮不可点，会成假 affordance，违 B3 诚实反馈）。
- **调整后**：
  1. `DrillSceneController` 引入 `PlaybackState` 四态：`idle` / `playing` / `pausingAfterShot`（已请求暂停、当前杆仍在播）/ `paused`；`isPlaying` 降为派生属性（`playing || pausingAfterShot`），继续承担拦截已排期异步回调的职责。
  2. 按钮改单一入口 `togglePlayback()`：空闲开播 → 播放中请求暂停 → 暂停请求期可再点撤销 → 暂停态点继续。图标 `play.fill` ⇄ `pause.fill`，标签「回放 / 暂停 / 本杆结束后暂停 / 继续」。**按钮不再 disabled**。
  3. **暂停语义 = 杆边界生效**：唯一生效点在 `scheduleNextStep`，即当前杆已完整播完并落到静止位；暂停停在该杆结果盘面，HUD 保留（整条序列尚未播完），`resume()` 从下一杆接上。
- **原因**：用户反馈①点播放后按钮无变化、应有播放中状态；②需要暂停，且暂停要能完成当前杆。DR-059 把演示从单杆改为整条序列后单次回放可达数十秒，「不可打断」不再合理——pause 此刻是真行动，F-SC-01 禁用 pause 图标的前提（按钮不可点）已不成立。
- **影响组件**：`DrillSceneView`（`DrillSceneController` + View）、`DrillRecordView`（复用自动同步）
- **验证**：`make build` → `BUILD SUCCEEDED`；`DrillSceneThreeBeatUITests` 4/0，新增 `testPlayButtonStateAndPauseCompletesCurrentShot`（点播放后标签立刻变「暂停」；点暂停先进「本杆结束后暂停」；当前杆播完落「继续」；静置 6s 断言 HUD 读数不变以证未擅自播下一杆；点继续回「暂停」）；截图 `build/drill-scene-three-beat/p1–p4`；`BTShotHUDBarRenderTests` 2/0。
- **日期**：2026-08-06
- **回写目标**：`docs/ui-polish/11-台面演示与场景组件.md` § F-SC-01、`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `docs/ui-polish/11-台面演示与场景组件.md` § F-SC-01「后续变更」标注（2026-08-06）；✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-06）

## DR-059
- **任务**：详情页/训练页顶栏改「整条序列逐杆演示」+ 球杆逻辑对齐试打页 + HUD 时序改版
- **原始规范**（DR-058 落地态）：点回放只演示 `DrillStaticPreview.resolveSource` 的**代表性单杆**；亮方案拍的静止球杆由 `DrillStaticPreview.showCueAtRest` 绘制；HUD 条静帧即显示、触球瞬间隐藏。
- **调整后**：
  1. **整条序列**：`DrillSceneController` 按 `source.token` 命中同一 formation 取 `steps`，播放改逐杆循环〔摆 `step.before` → 亮方案 → `runCueStroke` → 触球清线 → `TrajectoryPlayback` 回放 → 落 `finalPositions` 静止位 → 杆间停顿 0.7s〕，全部走完才复位静帧。首杆保留 1.5s 亮方案，后续杆 0.45s（与试打页 0.4s 同量级），杆间停顿取试打页 `sequenceInterShotPause` 同值。无 steps（shotIntent/animation 类）退回单杆路径。
  2. **球杆一致性**：瞄准位摆杆改 `scene.updateCueStick`（与 `PositionPlayViewModel.runSequenceStep` 同一调用），不再用静帧的 `showCueAtRest`——两者杆位/仰角算法不同，混用会在「定格 → 运杆第一帧」跳一下；运杆/出杆/减速跟杆/淡出全部交回 `CueStroke`，删掉 DR-058 自加的 `max(ballEnd, cueEnd)` 复位补偿，改为照抄试打页时序（cueAction 完成 → tail → rest → 停顿 → 下一杆）。
  3. **HUD 时序**：改为「点播放前不显示 → 播放全程显示并逐杆换成当前杆参数 → 整条序列播完隐藏」。`applyPreviewFrame` 不再置 `showOverlay = true`；`resetBalls` 一并隐藏。HUD 改条件渲染 + `Color.clear` 恒定占位（条高不跳），并挂 `drillShotHUDBar` 标识供 UI 测试断言。
- **原因**：用户反馈①一个动作序列的所有击球无法完整展示；②球杆运杆/出杆/减速/消失与试打页不一致；③要求 HUD 仅在播放期间可见。
- **影响组件**：`DrillSceneView`（`DrillSceneController` + View）、`DrillRecordView`（复用自动同步）
- **验证**：`make build` → `BUILD SUCCEEDED`；`DrillSceneThreeBeatUITests` 3/0——`testSequencePlaysAllShotsAndHUDTiming`（c001 5 杆，截图 `s4/s5` 可见球逐个减少、序列推进）、`testHUDUpdatesPerShot`（c078 16 杆逐杆参数互异，轮询到 ≥2 种力度读数，证伪「只显示首杆」）、`testActiveTrainingBallTableUsesSameHUD`；`BTShotHUDBarRenderTests` 2/0；`DrillTryoutBoardStoreTests` 9/0。
- **注**：`DrillStaticPreviewTests/test_resolveSource_multiFormationUsesA1Board` 为**改动前既有失败**（本会话已跑 baseline 实测确认），与本次无关。
- **日期**：2026-08-06
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-06）

## DR-058
- **任务**：详情页 / 训练页顶栏球桌演示对齐导出教学视频（三拍叙事 + 底部 HUD 条）
- **原始规范**：`DrillSceneView` 点回放 = 2s 预备停顿（线/杆/HUD 全程保留）→ 一次性清除**含球杆** → 球直接位移；打点盘与力度条以浮层贴母球侧 / 库边，靠避让启发式躲球（`DrillShotOverlay` / `DrillPowerBar`）。
- **调整后**：
  1. **三拍叙事**，与 `SequenceVideoExporter.Options.teachingVideo()` 同节奏：读球形 1.5s（素台，不剧透打点/力度）→ 亮方案 1.5s（预告线 + 假想球 + 静止瞄准位杆 + HUD）→ 执行（`AngleTrainingScene.runCueStroke` 真运杆/出杆/跟杆，触球瞬间清线转物理回放）。
  2. **HUD 形态**：浮层改为球桌下方固定暗条，抽出共享组件 `BTShotHUDBar`（导出与 App 单一真源）；删除 `DrillShotOverlay` / `DrillPowerBar` 及 `preferRightSide` / `spinPosition` 避让启发式与 `normScreen` / `occupiedPoints` 屏幕映射。
  3. **复位时机**取「球全停」与「球杆收完」较晚者，避免短杆时跟杆中的球杆被硬切回瞄准位。
  4. 球桌方向不变（详情/训练仍 `applyTopDown2D` 横版）；竖版仅导出档使用。
- **原因**：用户要求详情页与训练页的击球演示（球杆 / 打点盘 / 力度条显示方式）参照 2D 渲染视频；浮层避让本是遮挡妥协，底部条同时消除 E16/R1 的贴边裁切补丁。
- **影响组件**：`BTShotHUDBar`（新增）、`DrillSceneView`（`DrillSceneController` + View）、`SequenceVideoExporter`（私有 `ShotHUDView` 移除改引共享组件）、`DrillRecordView`（复用，自动同步）
- **验证**：`make build` → `BUILD SUCCEEDED`；`BTShotHUDBarRenderTests` 2/0；`DrillSceneThreeBeatUITests` 2/0，截图 `build/drill-scene-three-beat/b0–b5`（三拍逐拍）与 `t2-drill-record-table`（训练页），`build/hud-bar-render/export-k1.5.png`（导出档 HUD 无回归）。
- **日期**：2026-08-06
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-06）

## DR-057
- **任务**：动作详情页信息层级——去台面「上手试打」覆层；「查看精讲」降权
- **原始规范**：`DrillSceneView` 右下主色胶囊「上手试打」（§1.6 / E16）；训练要点卡内 `BTButtonStyle.primary` 全宽「查看精讲」。
- **调整后**：
  1. 删除台面覆层试打入口（`tryoutLocked` / `onTryoutTap` / `drillTryoutButton`）；试打仅底栏 `bottomTryoutButton`；锁态底栏「解锁 Pro」+ `unlockProButton`。
  2. 「查看精讲」改为训练要点标题行 trailing 文字链（`btCallout` + chevron，`btPrimary` 字色，非实心主钮）。
- **原因**：台面与底栏同文案主色 CTA 重复；精讲入口视觉权重与底栏主行动同级，挤压要点列表。
- **影响组件**：`DrillSceneView`、`DrillDetailView`、`DrillTryoutUITests`
- **日期**：2026-08-05
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-05）

## DR-056
- **任务**：封面深墨调浅 + 单行大字缩至约 2/3
- **原始规范**：DR-055 深墨 `darkOpacity` 0.85；练习网格水印 56pt；计划单行 scale 2 字 0.60 / 3 字 0.48。
- **调整后**：
  1. `darkOpacity` 0.85→0.52；暗底判定改为相对亮度 `< charcoalLuminanceCeiling(0.15)` 用金色。
  2. 练习 `gridAbsoluteSize` 56→37；计划单行 2/3 字 scale 0.40/0.32；4 字双行仍 0.40。
  3. `minLuminanceDelta` 随柔和深墨放宽至 0.07。
- **原因**：用户反馈深墨过深；单行大字偏大。
- **影响组件**：`CoverPalette.Glyph`、`BTPlanCover`、`AngleGridCard`（经 `btCoverWatermark`）、`CoverPaletteContrastTests`
- **日期**：2026-08-05
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog（2026-08-05）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog（2026-08-05）
- **证据**：`CoverPaletteContrastTests` → 见 `build/cover-glyph-soft-test.log`

## DR-055
- **任务**：训练 / 练习封面大字水印统一为深墨
- **原始规范**：练习页用 `Glyph.color(against:)` 在半透明白 / 深墨间自适应；训练计划 `PlanStyle` 按档硬编码白透明（0.16–0.18），仅 L2 用金色。
- **调整后**：
  1. 封面大字（训练计划 + 练习卡）一律 `CoverPalette.Glyph.color(against: top)`。
  2. 默认深墨 `darkColor` + `darkOpacity` 0.85；仅当金色对比优于深墨时回退（`goldOpacity` 0.62；炭黑 / 棕 / 红 / 石墨等暗底）。
  3. 废除半透明白水印路径；`PlanStyle.glyphColor` 改为计算属性，不再按档硬编码。
  4. 卡片下方标题/副标题与 PRO 徽标不变。
- **原因**：半透明白大字发灰发虚，观感不统一；用户要求封面大字用深色，并统一训练/练习规则。
- **影响组件**：`CoverPalette.Glyph`、`CoverPalette.PlanStyle`、`BTPlanCover`、`AngleGridCard`（经既有 `Glyph.color`）、`CoverPaletteContrastTests`
- **日期**：2026-08-05
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog（2026-08-05）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog（2026-08-05）
- **证据**：`xcodebuild … -only-testing:QiuJiTests/CoverPaletteContrastTests` → **TEST SUCCEEDED**，Executed 9 tests, 0 failures（`build/cover-glyph-dark-test.log`）。

## DR-054
- **任务**：练习首页封面水印与类型标签视觉重心调整
- **原始规范**：练习卡大字水印按封面几何中心放置；`物理 / 走位 / 2D / 3D / 识别 / SIM` 等类型标签与 Pro 徽标共同堆叠在右上角。
- **调整后**：
  1. 大字水印按 `CoverPalette.Glyph.gridAbsoluteSize * 0.06` 向下偏移，与训练计划卡 DR-050 的相对偏移口径一致。
  2. Pro 徽标继续留在右上角；类型标签独立移动到彩色封面右下角，分离付费属性与内容类型。
- **原因**：练习卡水印视觉重心偏高；类型标签属于封面内容说明，放在右下角可避开左上编号和右上 Pro 状态，并让层级更清楚。
- **影响组件**：`AngleGridCard`
- **日期**：2026-08-05
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3d/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-d/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3d/Changelog（2026-08-05）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-d/Changelog（2026-08-05）
- **证据**：`make build` → `BUILD SUCCEEDED`；`V28VisualUnificationUITests/testV28_LightScreenshots` 1/0；「练 / 打 / 解」截图目视确认水印下移、类型标签位于右下角且不与 Pro 徽标重叠。

## DR-053
- **任务**：训练计划期号去重与练习首页角标 / Pro 分层
- **原始规范**：训练计划封面同时显示两位数编号与「第 N 期」，信息重复；高级计划标题仍为「高级专项：加塞与多库」且封面水印为「高级综合」；练习卡仅有单字水印，无分组内序号，首页也未对高级入口做一致的 Pro 标识与实际门控。
- **调整后**：
  1. 计划封面只保留「第 N 期」；`plan_advanced` 用户可见名称统一为「加塞与多库专项」，水印固定为「加塞／多库」两行。
  2. 练习卡在每个「学 / 练 / 打 / 解」分组内从 01 重新编号；水印尽量使用两字语义词，避免单字显得空。
  3. 每组选择高级入口显示 `BTProBadge` 并接真实门控：非 Pro 点击弹 `SubscriptionView`，Pro 用户正常路由。当前门控为学「分离角图谱 / 加塞吃库图谱」、练「3D 角度训练 / 3D 瞄准点训练」、打「自由走位 / 拍照建球形」、解「打一走二想三 / 防守」。
- **原因**：减少封面重复信息，强化卡片识别密度，并让首页的付费提示与实际访问权限一致，避免只有视觉角标却可直接进入。
- **影响组件**：`BTPlanCover`、`PlanCoverLabel`、`AngleHomeView`、`AngleGridCard`、`QiuJiApp`（仅 Debug 门控测试钩子）、`V28VisualUnificationUITests`、`plan_advanced.json`、计划索引
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/§2.3d/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-c/§九-d/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/§2.3d/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/§九-d/Changelog（2026-08-04）
- **证据**：`make build` → `BUILD SUCCEEDED`；`V28VisualUnificationUITests/testV28_LightScreenshots` 1/0，截图确认期号去重、两字水印、分组编号与 PRO 徽标无重叠；`testPracticePremiumEntryShowsSubscription` 1/0，确认强制非 Pro 状态下弹订阅页且未进入内容页。

## DR-052
- **任务**：练习首页恢复 pre-v27 每卡独立多彩封面
- **原始规范**：DR-051 将 v28 混合球桌预览回退为 v27 分区同色系的渐变单字水印（学绿 / 练金 / 打蓝 / 解灰）。
- **调整后**：
  1. 保留 DR-051 的语义单字水印、chip，以及 v28 `BTContentGridCard` / 搜索栏 / 栏目头 / 筛选布局。
  2. 练习首页不再消费四分区色阶；改用 pre-v27 `AngleCoverPalette` 的逐卡独立配色，恢复绿、青、橙、琥珀、玫红、蓝、紫、红等历史 RGB 渐变。
  3. 历史色值收口到 `CoverPalette.PracticeMulticolor`，不在 View 内硬编码；训练计划与其他页面继续使用现有色板。
- **原因**：用户确认所指的旧版是“各种颜色”的更早版本，而非 v27 的分区同色系版本；逐卡色彩差异也能提升双列网格中的入口辨识度。
- **影响组件**：`CoverPalette.PracticeMulticolor`、`AngleHomeView`、`AngleGridCard`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3d/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-d/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3d/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-d/Changelog（2026-08-04）
- **证据**：`xcodebuild ... build` → `BUILD SUCCEEDED`；`V28VisualUnificationUITests/testV28_LightScreenshots` 1/0；截图 `build/v28-screenshots/practice-{all,学,练,打,解}-Light.png` 目视确认逐卡多彩渐变恢复。

## DR-051
- **任务**：练习首页封面图标恢复 v27 单字水印
- **原始规范**：v28 W1 将练习首页卡片封面从渐变单字水印替换为“学=几何微插图、练/打/解=真台轨迹预览”。
- **调整后**：
  1. 保留 v28 `BTContentGridCard`、共享搜索栏、栏目头与筛选布局。
  2. 仅恢复 v27 的渐变底 + 路由语义单字水印（瞄/法/偏/旋/角/走/翻等）及原 2D/3D/物理 chip。
  3. 移除练习首页对球桌背景的预热；`PracticeCoverCatalog` 暂保留供 v28 组件与测试追溯，不再作为首页生产封面。
- **原因**：双列卡片封面尺寸不足以承载真实球桌、球与多条轨迹；缩小后形成视觉噪声。单字水印在该尺寸下识别更直接，且用户明确要求恢复约 2–3 个版本前的图标。
- **影响组件**：`AngleHomeView`、`AngleGridCard`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3d/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-d/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3d/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-d/Changelog（2026-08-04）
- **证据**：`make build` → `BUILD SUCCEEDED`；`V28VisualUnificationUITests/testV28_LightScreenshots` 1/0；截图 `build/v28-screenshots/practice-{all,学,练,打,解}-Light.png` 目视确认单字水印恢复。

## DR-050
- **任务**：训练计划主题水印视觉重心下移
- **原始规范**：主题水印按封面几何中心放置；左上期号与粗圆体字形共同造成视觉重心偏上。
- **调整后**：仅对主题水印增加基础字号 6% 的向下偏移（list 默认约 5.8pt，hero 默认约 10.2pt）；期号、背景、字号、断行和卡片尺寸不变。
- **原因**：通过水印自身的相对偏移修正视觉重心，避免移动整个封面内容层或引入按卡片高度写死的 magic number。
- **影响组件**：`BTPlanCover`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog（2026-08-04）

## DR-049
- **任务**：训练计划主题水印缩小并为四字主题改用双行
- **原始规范**：DR-048 将 2/3/4 字统一单行展示，字号分别为基础字号的 72%/58%/46%；两字仍偏大，四字横向占幅过宽。
- **调整后**：
  1. 2/3 字主题继续单行，字号缩小为基础字号的 60%/48%。
  2. 4 字主题固定按 2×2 断行（中级／综合、高级／综合、全能／综合），字号为基础字号的 40%，居中显示。
  3. 保留原 `Spacing.xl` 水平安全区、六色背景、期号与卡片尺寸。
- **原因**：主题水印应辅助识别而非充当第二标题；四字单行即使缩放仍会形成横向满幅，固定双行可保持紧凑视觉重心。
- **影响组件**：`BTPlanCover`、`PlanCoverLabel`、`CoverPaletteContrastTests`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog（2026-08-04）

## DR-048
- **任务**：训练计划封面从等级单字改为课程主题标签
- **原始规范**：`CoverPalette.PlanStyle` 同时按 `targetLevel` 决定颜色与「入/初/进/中/高/专」等级水印；`BTPlanCover` 不接收计划身份，同等级计划只能显示相同字样。
- **调整后**：
  1. 颜色继续由 `targetLevel` 决定；封面文字改由 `planId` 经 `PlanCoverLabel` 单点映射为课程主题：入门、杆法、准度、控力、分离角、加塞、走位、中级综合、高级综合、全能综合。
  2. `BTPlanCover` API 新增必填 `planId`；训练首页、计划列表、计划详情与共享卡片 Preview 全部接线。
  3. 水印按 2/3/4 字分别取基础字号的 72%/58%/46%，并保留水平 `Spacing.xl` 安全区，避免铺满封面或压住左上期号。
- **原因**：等级单字过度抽象，双字等级又与卡片标题重复且铺满封面；课程主题标签能提供第二层信息，同时不重复完整标题。
- **影响组件**：`BTPlanCover`、`PlanCoverLabel`、`CoverPalette.PlanStyle`、`TrainingHomeView`、`PlanListView`、`PlanDetailView`、`BTContentGridCard`、`CoverPaletteContrastTests`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog（2026-08-04）

## DR-047
- **任务**：训练计划封面回归六色大字杂志卡
- **原始规范**：DR-045 将训练计划 6 档封面收敛为 teal→indigo 单色相明度阶梯；大字与期号结构不变。
- **调整后**：
  1. 保留 v28 的 `BTContentGridCard` 共享外壳与 `BTPlanCover.Mode` list/hero API。
  2. `CoverPalette.PlanStyle` 恢复 v27 W2 前六色编辑式色板：入门绿、初级蓝、进阶青、中级黑金、高级棕金、专家红；恢复原有低透明度大字水印。
  3. 放弃文生图封面方向；生图仅用于方案比较，未纳入 App 资源。
- **原因**：用户目视对比后确认文生图在双列缩略图中无法稳定表达训练主题；teal 单色阶又削弱计划间识别。旧六色大字方案在小尺寸下信息最直接，且与现有标题/期号结构兼容。
- **影响组件**：`CoverPalette.PlanStyle`、`BTPlanCover`（视觉消费，API 不变）、`CoverPaletteContrastTests`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog（2026-08-04）

## DR-046
- **任务**：训练首页「今日安排」内容层级与动作缩略图重设计
- **原始规范**：周/天/完成数、栏目标题、计划名、周主题分散为多行弱文本；动作卡仅有序号、名称与组数，没有球形预览，且「第 N 项 / 共 N 项」与序号重复。
- **调整后**：
  1. 当日信息压成两行白色摘要卡：首行「今日安排 + 计划名 + 完成数」；次行「周主题 + 周/天/时长」；删除元信息胶囊，进度改为不占行高的 2pt 卡片底边线。
  2. 动作卡接入 `BTBakedDrillTable(drillId:contentMode:.fill)` 的 90×50pt 专用裁口：仅裁烘焙 PNG 左右透明留边，六袋与四边库完整；不使用底部暗角，不启动 SceneKit / VM / 求解器。
  3. 删除图上序号；动作元信息改为中性阶段文字 + 5pt 语义色点 +「N 组 × N 球」，保留完成 / 当前 / 排队状态。
- **原因**：底层问题是当日训练缺少单一视觉焦点与球形辨识能力，不是单纯缺一张装饰图片；现有 `TodayDrillItem.drillId` 与离线缩略图缓存已能零数据改动实现真实预览。
- **影响组件**：`TrainingHomeView.todayScheduleHeader`、`todayDrillCard`、`BTBakedDrillTable`（复用）
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` Changelog（2026-08-04）

## DR-045
- **任务**：问题集合 v28 — 三 Tab 表层语法与专业内容封面（W0–W4）
- **原始规范**：
  1. 练习 / 动作库 / 训练计划卡片各自实现外壳；练习封面为大字水印渐变海报；动作库双行 chip（球种+等级）；计划色复用学/练/打/解色对。
  2. 旧版/新版角标叠在烘焙台面四角；完成态同叠右上。
- **调整后**：
  1. 共享 `BTContentGridCard` / `BTLibrarySearchBar` / `BTLibrarySectionHeader`；练习混合封面 `PracticeCoverVisual` + `BTPracticeCover`（学=几何微插图，练/打/解=真台静态预览，分区色仅 tint）。
  2. `CoverPalette.PlanStyle` 独立 teal→indigo 等级阶梯；`BTPlanCover.Mode` 分 list/hero；训练首页/计划列表接共享壳。
  3. 动作库只留一行等级 chip；球种+精讲进筛选菜单；完成/旧新版移到标题下元信息行。
- **原因**：v27 统一了 token，但三 Tab 骨架/密度/内容表达仍割裂；大字水印无法预告目的页。
- **影响组件**：`BTContentGridCard`、`BTLibrarySearchBar`、`BTLibrarySectionHeader`、`BTPracticeCover`、`PracticeCoverCatalog`、`BTPlanCover`、`CoverPalette`、`AngleHomeView`、`TrainingHomeView`、`PlanListView`、`DrillListView`、`BTDrillGridCard`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog + §2.3c；`.cursor/skills/swiftui-design-system/SKILL.md`
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c/§2.3d/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/§九-d/Changelog（2026-08-04）

## DR-044
- **任务**：问题集合 v27 W2 — 封面色板分区收敛（E2/E3/E4 相框）
- **原始规范**：
  1. `AngleCoverPalette` 24 组独立高饱和 RGB 色对（橙/紫/玫红/蓝青混杂）；`BTPlanCover` 内联私有 `CoverStyle` 6 档色。
  2. 封面 glyph：`BTPlanCover` 内联 `system(size: 96, weight: .black, design: .rounded)` + 白 0.16；`AngleGridCard` 用 `btCoverWatermark` 56pt + 白 0.22。
  3. 动作库网格台面有 36pt 底渐变压暗；`BTDrillThumbnail` 64×64 仅 Dark 描边、无暗角。
- **调整后**：
  1. 合并为 `CoverPalette`（`typealias AngleCoverPalette = CoverPalette`）：学=绿 / 练=金琥珀 / 打=蓝青 / 解=石墨；`PlanStyle.forLevel` 同文件；Light/Dark 共用 RGB。
  2. `CoverPalette.Glyph` + `btCoverWatermark(size:)`；`BTPlanCover` 删内联 `system(size: 96)`。
  3. `BTThumbnailFrame`：网格卡与行卡同款相框。
  4. **返工（主控验收标准 4 未过）**：区内阶梯改为每区独立 `ZoneLadder`（练区 B 地板防泥褐；解区起点压暗）；水印 Constraint A = sRGB `|ΔL|≥0.14`，`Glyph.color(against:)` 在白/深 token 间选择；白 opacity 0.20→0.26。单测 `CoverPaletteContrastTests`。
- **原因**：三 Tab 封面色彩情绪割裂；glyph/相框规范分叉；共用明度公式使暖金变褐、石墨首档过浅。
- **影响组件**：`CoverPalette`、`BTPlanCover`、`AngleGridCard`、`Typography`、`BTThumbnailFrame`、`BTDrillGridCard`、`BTDrillThumbnail`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §1.4/§2.3/Changelog + `.cursor/skills/swiftui-design-system/SKILL.md`
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §1.4/§2.3c/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §九-c/Changelog（2026-08-04）

## DR-043
- **任务**：问题集合 v27 W1 — 浅色组件收口（E5/E6/E4 徽章）
- **原始规范**：
  1. 筛选 Chip 在训练页 / 动作库等级 / 动作库球种三处各自实现，球种另用旧字号与描边。
  2. `BTButtonStyle` 无 `goldFilled`；`DrillDetailView` 私有 `GoldFilledButtonStyle`；formationPickerSheet 用系统 `.primary/.secondary/.tertiary` 与 `Font.system(size:15,…)`。
  3. `BTLevelBadge` 仅浅卡配色（彩字 + 15% 底），叠深绿台面对比不足。
- **调整后**：
  1. 新增 `BTFilterChip`（训练页样式为基准：`btFootnote14.medium` / `Spacing.xl` 水平内边距 / 选中 `btChipActiveFill*`）；三处调用方切换，私有配色函数删除。
  2. `BTButtonStyle.goldFilled`（btAccent 胶囊 48 高，原页面私有样式原样收编）；formationPickerSheet 改 `btText*` + `.btCTALabelRounded.weight(.bold)`；保留 `.preferredColorScheme(.dark)`。
  3. `BTLevelBadge(onDarkSurface:)` 默认 `false`；`BTDrillGridCard` 左上角覆层传 `true`（白字 + 黑 45% 底）。
- **原因**：三 Tab 浅色筛选控件与详情页 token 割裂；网格卡覆层徽章不可读且不能反伤列表白卡。
- **影响组件**：`BTFilterChip`（新）、`BTButtonStyle`、`BTLevelBadge`、`BTDrillGridCard`、`TrainingHomeView`、`DrillListView`、`DrillDetailView`
- **日期**：2026-08-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.1/§2.4/Changelog + `.cursor/skills/swiftui-design-system/SKILL.md`
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.1/§2.4b/§2.4/Changelog（2026-08-04）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` §七/§九/§九-b/Changelog（2026-08-04）

## DR-042
- **任务**：打点盘全宽贴库边 + 防误触关闭
- **原始规范**：控件瘦身 v2 / G16——卡片 `maxWidth: 228`、白盘框 104×104；`BTSpinPadOverlay` 用近透明 `Color.opacity(0.001)` + `onTapGesture` 点盘外关闭。
- **调整后**：
  1. 卡片宽 = `ShotStageProxy.playingRect.width`（击球区内框 / **库边内侧**；外框用 `tableRect`，打点盘不贴外沿）。
  2. 卡片底边贴击球区下沿：`bottomPadding = proxy.spinPadBottomPadding`（= `sceneHeight − playingRect.maxY`；取代固定 80）。
  3. `ShotTableLayout.playingRect`：外框同心缩放，比例 = `innerHalf / outerHalf`（横轴 Z=`innerWidth/2`）。
  4. `SpinPadLayout`：白盘直径封顶 **168pt**，几何上永不挤掉四向键间距；多余宽度 Spacer 居中。
  5. Overlay 铺满 stage 的**透明**拦截层（`Color.clear` + `DragGesture(minimumDistance:0)`）吞 tap/drag→`onClose`，挡住台面瞄准与力度柱误触；**无视觉压暗**。
  6. 9 处交互式调用点传 `tableWidth` + `bottomPadding` + `zIndex(20)`（图谱只读迷你盘不动）。
- **原因**：窄卡片易在手动瞄准时误拖台面；点力度条无法关闭；白盘相对背景过小；外框过宽应收到库边内侧；固定 bottomPadding 80 悬空，应贴下沿。
- **影响组件**：`BTSpinPad`、`ShotTableLayout`/`ShotStageProxy`、9 击打页、SPEC §9.1-④ / G16 注记
- **日期**：2026-07-31
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog + §9.1-④
- **已应用至**：✅ SPEC Changelog + §9.1-④ / G16 注记（2026-07-31）
- **证据**：`make build` SUCCEEDED；`SpinPadLayoutTests` + `ShotTableLayoutTests`（含 `playingRect`）

## DR-041
- **任务**：正常进袋页 — 直击几何失败时翻袋备选
- **原始规范**：编排台 / 自由击球 / 思路 / 打三的袋口进袋为直击 only；切角 ≥89° 即「当前角度无法进袋」，不枚举翻袋。
- **调整后**：
  1. 新增 `DirectPotBankFallback`：闸门 + 文案 + `asPositionPlaySolutions`；求解一律 `BankKickSolvePipeline.solveBank`（不另写管线）。
  2. `PositionPlayViewModel`：直击 `feasible==false` 后跑翻袋目录；状态「翻袋备选 · 库序」；≥2 解左下「下一解」。
  3. `SiluTrainerViewModel` / `PlanThreeViewModel`：`PositionPlaySolver` 空且直击几何不可行时补翻袋目录（`satisfiesConstraint=false`）。
  4. 自由瞄准 / 直击可行但不满足走位约束 → **不**触发。
- **原因**：切角过大时直击物理不可行，但目标球吃库进袋常仍可打；翻袋页管线已成熟，作备选复用成本最低。
- **影响组件**：`DirectPotBankFallback`、`PositionPlayViewModel`、`SiluTrainerViewModel`、`PlanThreeViewModel`、`FreePlayView`、`PositionPlayComposerView`、SPEC §8.9 i
- **日期**：2026-07-30
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §8.9 i + Changelog
- **已应用至**：✅ SPEC §8.9 i + Changelog（2026-07-30）
- **证据**：`make build` SUCCEEDED；`DirectPotBankFallbackTests` **6/0**（`build/direct-pot-bank-fallback-test.log`）

## DR-040
- **任务**：问题集合 v24 — 动作库网格裁桌修复 + 列表大球
- **原始规范（DR-039 热修后）**：列表/详情 `ballScale=1.0`；网格卡封面槽 **4:3** + `BTBakedDrillTable` `.fill` → 裁掉 2:1 烘焙图左右库边。
- **调整后**：
  1. **E1**：`BTDrillGridCard` / `BTDrillGridCardSkeleton` 封面 **4:3→2:1**；`BTBakedDrillTable` 增可选 `contentMode`（默认 `.fill`）。
  2. **E2**：`Options.thumbnail.ballScale=1.8`；全量重烘 **77/77**。
  3. **E3**：`Options.detail.ballScale` 仍 **1.0**；详情顶栏 live，不双套 PNG。
  4. **D-v24-1=C**：方槽行卡本轮零行为变更（维持 fill 中心裁），契约留档。
- **原因**：裁桌是显示槽比例错误；列表小槽需更大球可读，详情需真尺寸观感。
- **影响组件**：`BTDrillCard`、`BTShimmer`、`BTBakedDrillTable`、`DrillStaticPreview`、`DrillThumbnails/*.png`
- **日期**：2026-07-29
- **回写目标**：`docs/research/20260729-drill缩略图静帧契约.md`；SPEC Changelog；`问题集合_v24.md`
- **已应用至**：✅ 契约文档；✅ SPEC Changelog；✅ 真源 v24.2
- **证据**：W1 `build/v24-w1-{build,test}.log` + `build/v24-w1-evidence/`；W2 bake **77/77**（`build/v24-w2-rebake.log`）+ `build/v24-w2-evidence/` + `make build` SUCCEEDED

## DR-039
- **任务**：Drill 缩略图 / 详情首帧静帧对齐现行渲染
- **原始规范**：`DrillThumbnailRenderer` / `DrillSceneView` 强制 `hideCueStick`、实心折线、`targetBallNumber=8`、无 ghost；多序列扫目录无代表性语义。
- **调整后**：
  1. 新增共享真源 `DrillStaticPreview`：代表性选源（A1 → legacy → A* → manual）+ 真球键摆桌 + `TrajectoryRenderer` 线语言 v2 + ghost/接触点 + 瞄准位球杆（elevation/穿模）。
  2. `DrillThumbnailRenderer` / `DrillSceneController` 首帧同契约；列表仍一 drill 一 PNG。
  3. `DrillTryoutBoardStore.representative`；`TrajectoryRenderer.draw(detailOverride:)`。
  4. 全量重烘 **77/77**。
- **原因**：缩略图停在 DR-016/017，未跟上球杆同现 / 线语言 v2 / 多球形代表性语义。
- **影响组件**：`DrillStaticPreview`、`DrillThumbnailRenderer`、`DrillSceneView`、`DrillTryoutBoardStore`、`TrajectoryRenderer`、`DrillThumbnails/*.png`
- **日期**：2026-07-29
- **回写目标**：`docs/research/20260729-drill缩略图静帧契约.md`；SPEC Changelog
- **已应用至**：✅ 契约文档；✅ SPEC Changelog（2026-07-29）
- **证据**：`make build` SUCCEEDED；`DrillStaticPreviewTests` **5/0**；bake **77/77**（`build/thumb-rebake.log`）；抽查 c001/c053/c073 含杆+线+ghost。

## DR-038
- **任务**：问题集合 v23 W1b 热修 — 空象限对角 + 瞄准线 keepout（D-v23-5.1）
- **原始规范（DR-037）**：单轴最大边距定方位；keepout 仅进球线/袋口。
- **调整后**：
  1. **空象限**：`openHorizontal × openVertical` 对角优先（四边距仍用来判哪边更大，但落点进「更大一块」而非单轴）。
  2. 候选按 `freeRun`（沿方向到台边的 Norm 距离）排序；轮侧过滤保留。
  3. `SightKeepout` 增 `aimStart/EndNorm`；`keepoutOverlap` 同时避瞄准线；AimPoint `fromWorld(..., cue:aimEnd:)`。
- **原因**：单轴边距不够——空旷是象限；且只避进球线仍会盖瞄准线。
- **影响组件**：`AimCloseupPlacement`、`AimPointSceneTrainingView`。
- **日期**：2026-07-29
- **回写目标**：SPEC Changelog；`问题集合_v23.md`
- **已应用至**：✅ 真源 v23.13；✅ SPEC Changelog
- **证据**：Placement 套件 **19/0**（`build/v23-open-quadrant-test.log`）。

## DR-037
- **任务**：问题集合 v23 W1b 热修 — HUD 四边空旷方位（D-v23-5 formal）
- **原始规范（5‴/5⁗）**：方位靠象限对角 / −potDir；距离 0.92d；keepout 硬过滤进球线/袋口。
- **调整后**：`EdgeClearance` 单轴最大边距定方位（过渡）；后由 DR-038 升为象限对角。
- **原因**：用户点明「算到四边距离即知空旷方位」。
- **影响组件**：`AimCloseupPlacement`。
- **日期**：2026-07-29
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`问题集合_v23.md`
- **已应用至**：✅ 后由 DR-038 覆盖
- **证据**：`build/v23-edge-openness-test.log`。

## DR-036
- **任务**：问题集合 v23 W1b 热修 — HUD 进球视线避让（D-v23-5⁗）
- **原始规范（D-v23-5‴）**：loupe 相对焦点偏移（0.92×直径），仅避焦点球 / 瞄准轮 / 提交热区。
- **调整后**：
  1. 新增 `AimCloseupPlacement.SightKeepout`（potStart/End Norm + 线段 margin + 袋口盘半径）；世界系工厂 `fromWorld(object:pocket:halfLength:halfWidth:)` 走与 `focusNorm` 同一 `mapRotated` 契约。
  2. `center(..., sightKeepout:)`：硬过滤 loupe∩进球线段/袋口盘；全挂放大 gap 1.1×/1.25× → 最小重叠软降级。无 keepout 时与 5‴ 等价。方位选择后由 DR-037（四边空旷）接管。
  3. `AimCloseupSnapshot.sightKeepout`；`BTAimCloseupOverlay` 透传；`AimPointSceneTrainingView` 用 `potLine` 同源填 keepout。自由瞄准页场景无进球线 ⇒ keepout nil（层集政策不变）。
- **原因**：特写弹出时若盖住进球线/袋口，用户无法在全景完成进袋判断——与「加 HUD 而非推近相机」的结构性理由冲突。
- **影响组件**：`AimCloseupPlacement`、`AimCloseupSnapshot`、`BTAimCloseupOverlay`、`AimPointSceneTrainingView`。
- **日期**：2026-07-29
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog；`问题集合_v23.md` D-v23-5⁗
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-07-29，DR-036）；✅ `问题集合_v23.md` v23.11
- **证据**：`make build` SUCCEEDED；`AimCloseupPlacementTests`+Coords+Axis **16/0**（`build/v23-w1b-sight-keepout-test.log`）。模拟器点验待用户。

## DR-035
- **任务**：问题集合 v23 W3 — 瞄准特写扩页至自由瞄准四页（D-v23-13）
- **原始规范**：D-v23-1b 只接 `AimPointSceneTrainingView`，其余页 backlog；定位/开关/层集代码写在该页内。
- **调整后**：
  1. **快照真源** `AimCloseupBuilder.freeAim(cue:direction:balls:ballRadius:railEnd:halfLength:halfWidth:previouslyNear:)`（纯平面几何，无 SceneKit 依赖 ⇒ 可单测）：焦点 = 首碰球（沿射线最先碰到者），无接触则取近区内垂距最小者并标「打空」；层集 = 瞄准线 + 假想球圈 + 接触点，**不发明**进球线/垂线/瞄准点十字（D-v23-2′ 按页实况）。
  2. **显隐门** `AimCloseupGate`（近区 ∧ 正在改瞄准，280ms sticky，`reset()` 用于离开自由模式/播放）：宿主 VM 持有并把 `onSnapshotChange` 转发进自己的 `@Published closeupSnapshot`（嵌套 ObservableObject 不会 republish）。`isNear` 回传做 3R/3.5R 滞回。
  3. **共享浮层** `BTAimCloseupOverlay(snapshot:sceneSize:)`：三点菜单开关 + `AimCloseupPlacement.center` 定位 + 圆心滞回一处收口；`AimPointSceneTrainingView` 同步改用它，删掉页内重复定位代码。
  4. 接入页：`FreePlayView`（非开球模式）/ `PositionPlayComposerView` / `ShotSimulationView`（共用 `PositionPlayViewModel`）/ `SolverStageChrome`（Bank/Diamond 自由模式，经 `SolverStageHosting` 新增 `closeupSnapshot` + `setAimWheelDragging`）。四页三点菜单加 `showsAimCloseupToggle: true`。开球页**不接**（球堆无可读接触几何）。
- **原因**：满台俯视下近球接触几何不可读的问题在自由瞄准各页同样存在；若各页自写定位/层集会重演 FL-028（贴球、发明层）。
- **影响组件**：新增 `AimCloseupBuilder`、`AimCloseupGate`、`BTAimCloseupOverlay`；改 `PositionPlayViewModel`、`BankShotViewModel`、`DiamondSystemViewModel`、`SolverStageChrome`（协议）、`FreePlayView`、`ShotSimulationView`、`PositionPlayComposerView`、`AimPointSceneTrainingView`、`BTShotPageChrome`（pageExtras init 透传开关）。
- **日期**：2026-07-28
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-07-28，DR-035）
- **证据**：`make build` SUCCEEDED；新单测 **12/0**（`build/v23-w3-test.log`：层集/近区带/滞回/多球首碰优先/换目标切构图/取景 + 门 3 例）。`QiuJiTests` 全量：瞄准 · 走位 · 翻袋反射 · 开球相关全绿；余 7 例失败（DrillList 计数 77≠72、试打序列、统计跨日）为**既有红**，已 `git stash --include-untracked` 基线复现同样 7 例（`build/v23-baseline-unrelated.log`）⇒ 与本轮无关，未修。已 `make run` 装模拟器；抽样点验待用户。

## DR-034
- **任务**：问题集合 v23 — 特写开关并入三点菜单（D-v23-11）+ W2 轮增益铺开（D-v23-12）
- **原始规范**：特写常显不可关；毫米增益仅 AimPointScene，其余 6 处 `BTAimWheel` 写死 0.15°/pt + 整度震。
- **调整后**：
  1. `UserPreferences.showAimCloseup`（键 `showAimCloseup`，**默认开**）+ `BTAimCloseupMenuToggle`；由 `BTSolverMoreMenu(showsAimCloseupToggle:)` 并入既有 §显示 Section（不新开 Section，与「台面网格 4×8」同处）。关特写**不**关毫米增益（两条瓶颈可独立取舍）。
  2. **杠杆臂真源** `AngleSceneCalculator.aimLeverMeters(cue:dir:balls:)`：首碰球（`freeAimFirstContact`）→ 射线前方最近球 → 最近球 → nil；nil ⇒ 调用方回落 `defaultDegreesPerPoint`。多球场景由首碰锁定，不用「选中目标」。
  3. 接入 5 页：`FreePlayView` / `PositionPlayComposerView` / `ShotSimulationView`（三者共用 `PositionPlayViewModel.aimWheelDegreesPerPoint`）、`SolverStageChrome`（Bank/Diamond，经 `SolverStageHosting` 新增只读要求）、`BreakInstrumentsOverlay`（`BreakFlowRunner`，杠杆 = 母球→球堆首碰）。均同时 `degreeHapticEnabled: false`（D-v23-6 同口径）。`BatchAuthoringView` 按 D-v23-1a 排除，调用点未改 ⇒ 旧手感。
  4. `BTAimWheel` **手势开始锁档**（`lockedGain`）：单次拖动内增益不变，满足 E2「无中途速度突变」红线（换球/换目标导致的档位跳变只在下次拖动生效）。
- **原因**：固定角增益在远/近台输出毫米不一致（同 1pt，1m 处偏移是 0.5m 的 2 倍）；特写属辅助显示，需可关（部分用户嫌遮挡）。
- **影响组件**：`UserPreferences`、`PracticeStorageKey`、`BTShotPageChrome`（`BTSolverMoreMenu` / 新 `BTAimCloseupMenuToggle`）、`BTAimWheel`、`AngleSceneCalculator`、`PositionPlayViewModel`、`BankShotViewModel`、`DiamondSystemViewModel`、`BreakFlowRunner`、`AimPointSceneTrainingView` 及 5 处轮调用页；SPEC §9.3。
- **日期**：2026-07-28
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-07-28，DR-034）
- **证据**：`make build` SUCCEEDED；单测 **31/0**（`build/v23-w2-test.log`）——`AimLeverTests` 4 例（杠杆臂选球规则）+ `AimWheelGainWiringTests` 5 例（**逐页真实场景接线实证**：走位系首碰球胜过更近侧球、空桌回落 0.15°/pt、翻袋、反射、开球顶球杠杆，均断 0.4 mm/pt 且细于旧档）。已 `make run` 装模拟器；抽样点验（5 页拖轮手感）待用户。

## DR-033
- **任务**：问题集合 v23 W1b — HUD 契约重做（同源几何放大 / 分层 / 避让定位）
- **原始规范（DR-032）**：自绘扁平橙球示意卡；固定右上；内容固定为目标+线+ghost。
- **调整后**：
  1. **放大** = 同步画主场景用户瞄准几何 + 紧取景（`halfWorld≈3.2R`），非截图、非示意卡。
  2. **`AimCloseupSnapshot` 可选层**：目标球 / 瞄准线 / 进球线 / 辅助线 / 假想球 / 母球 / 标记；页只填实况有的层（AimPoint 瞄准态无假想球圈 ⇒ HUD 不发明）。
  3. 外观：`BTFigureBall` / `FigureLine` / `BTGhostCircle`；底色见下。
  4. 定位：见 v23.7 / v23.8；**HUD 隐藏时 `previous=nil` 重新选角**（禁止默认 `.topTrailing` 滞回钉死）。
  5. **坐标（点验热修）**：`AimCloseupCoords.mapRotated` 与 `topDown2DRotated` 同轴（screen-up=+X、screen-right=+Z）；禁止 landscape 映射（+X→右）导致 loupe 整盘约 90° 错向。轴向由 `AimCloseupAxisContractTests` 用**真实相机投影**反查，不靠注释声明。
  6. **定位（v23.7，FL-028）**：滞回 = 中线 ±0.08 **模糊带内**保持 previous；`blockedSide` 钉死刻度轮对侧。
  7. **底色（v23.7→v23.8）**：实测 plain 台呢扁平填充 RGB(25,111,18)；去掉径向变暗与重阴影（径向边缘仍会把 loupe 衬成贴纸）。`AimCloseupFeltParityTests` 像素比对（现逐通道一致 0.098/0.435/0.071）。禁止 `btTableFelt`。
  8. **定位（v23.8）**：由屏角对齐改为 **`AimCloseupPlacement.center`**——相对焦点球屏幕位置偏移（默认间距 0.92×直径），钳入避轮/提交安全区；clamp 压塌时换候选方向。产品意图＝真放大镜（靠球但不盖球），非四角 chrome。
- **原因**：用户点验要求「纯粹局部放大、按实际情况展示、位置有逻辑」；示意卡与钉死右上不符合共享瞄准组件目标；v23.7 后仍报位置/颜色——根因是圆心间距 0.58×d 只留 ~10pt 边隙（看起来仍贴球）+ 径向渐变把底色衬暗。
- **影响组件**：`BTAimCloseupHUD`、`AimCloseupSnapshot`、`AimCloseupCoords`、`AimCloseupPlacement`、`AimPointSceneTrainingView`；SPEC §9.3。
- **日期**：2026-07-28
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 / Changelog（2026-07-28，DR-033）
- **证据**：`make build` SUCCEEDED；单测 **14/0**（`build/v23-w1b-v238-test3.log`）；合成图 `build/v23-evidence/w1-position-color/composite.png`；felt 像素一致

## DR-032
- **任务**：问题集合 v23 W1 — 近球瞄准特写 HUD + 瞄准轮连续毫米增益（AimPointScene 端到端）
- **原始规范**：全景台面球占比小 + `BTAimWheel` 固定 0.15°/pt / 整度触感；无近区辅助。
- **调整后**：
  1. `AimProximityMath`：垂距 + `proj > 0`；**2R = 接触边界**；HUD 近区 enter **3R** / exit **3.5R** 滞回；擦身带（≥2R）标「打空」。
  2. `AimWheelGain`：目标 **0.4 mm/pt**，`°/pt ∝ 1/d`（d 下限 0.08 m、上限 0.6°/pt）；AimPoint 页关闭整度触感。
  3. `BTAimCloseupHUD`：**自绘 Canvas**（不复用 `BTTableFigure` 静态底图）；仅用户几何；训练态不泄正解；锚点场景区右上。
  4. `BTAimWheel` 增参：`degreesPerPoint` / `degreeHapticEnabled` / `onDragActiveChanged`；未传参页行为与旧 0.15°/pt + 整度震一致。
- **原因**：全景取景受 `rotatedUnifiedScale` 契约约束不可推近相机；固定角增益在远/近台输出毫米不一致；特写与精调须成对。
- **影响组件**：`AimProximityMath`、`AimWheelGain`、`BTAimWheel`、`BTAimCloseupHUD`、`AimPointSceneQuizViewModel` / `AimPointSceneTrainingView`；SPEC §9.3。
- **日期**：2026-07-28
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 / Changelog（2026-07-28，DR-032）
- **证据**：`make build` SUCCEEDED；`AimProximityMathTests`+`AimWheelGainTests` **9/0**（`build/v23-w1-test.log`）。截图点验待用户模拟器。

## DR-031
- **任务**：瞄准点场景测验验证击球「几何瞄对却常不进」
- **原始规范**：提交后 1.5s 按**用户瞄准线**、`ShotTuning.aimPointVerifyVelocity`（= `defaultVelocity` 1.5 m/s）中杆无塞物理击球；评分 = 假想球几何 mm。
- **调整后**：
  1. 验证杆速 **3.3 m/s**（对齐 `DrillShotResolver.defaultVelocity`），压低 CIT。
  2. `|errorMM| ≤ 2`（与 `BTFeedback.outcome(forMM:)` success 档同口径）时验证出杆用**几何正解** `correctDir`；超出仍打用户线。
  3. 结果 HUD：「几何瞄准验证」/「按你的瞄准验证」；评分仍 mm，不引入物理补偿瞄准（与「瞄准修正」课分工）。
- **原因**：评分真源（无摩擦假想球）与验证真源（含 CIT 的引擎）不一致，再叠加软力放大投掷，导致「几何已对」时进袋正反馈失真。
- **影响组件**：`ShotTuning.aimPointVerifyVelocity`、`AimPointSceneQuizViewModel` / `AimPointSceneTrainingView`；SPEC §9.3 瞄准点场景契约。
- **日期**：2026-07-28
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 / Changelog（2026-07-28，DR-031）

## DR-030
- **任务**：问题集合 v21 W5「收口与接线」— 学区 CTA → 动作库 drill
- **原始规范**：学页 `PracticeCTA` 仅走 `AngleRoute` 练习域目的地；SPEC §9.3.1 CTA 密度写「不新增动作库/蛇彩深链」；动作库详情仅在动作库 Tab 的 `navigationDestination(for: String.self)`。
- **调整后**：
  1. 新增 `AngleRoute.drillDetail(String)`；`MainTabView.angleDestination` 内嵌 `DrillDetailView(drillId:)`，练习 Tab 栈内可达，无需切 Tab。
  2. 「瞄准修正」「旋转与加塞」各一条 `PracticeCTA`→`drill_c073`（免费钩子）；页末大卡仍 ≤2（旋转页「分离角图谱」降为 `LearnDocTextLink`）。
  3. AX：`aimingCorrection.squirtDrillCTA` / `spinAndEnglish.squirtDrillCTA`；UI 测断言详情标题含「挤偏认知」。
- **原因**：v21 加塞课入库后，学区概念页若不能一键进跟打 drill，用户仍感知「没有加塞课」；切 Tab + 搜索改动面更大且难测。
- **影响组件**：`AngleRoute`、`MainTabView`、`AimingCorrectionView`、`SpinAndEnglishView`、`DrillDetailView`（复用）；SPEC §9.3.1。
- **日期**：2026-07-28
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3.1 CTA 密度 + 旋转与加塞契约 + Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §9.3.1 / Changelog（2026-07-28，DR-030）

## DR-029
- **任务**：问题集合 v20 W2「加塞吃库图谱」
- **原始规范**：线语言 v2（SPEC §8.9 / 设计稿 §1.2）——线色 = 球的身份（白=母球路径；目标球本色=该球路径）。
- **调整后**：**页内专用豁免**——「加塞吃库图谱」8 条母球轨迹用页内 8 色板（`CushionEnglishAtlasGeometry.trackColors`，左塞暖→右塞冷）区分 spinX 档位身份，**不**改全局 `TrajectoryStyle`，也不影响「分离角图谱」或其它页。碰前/库后均同序上色（v20.5：废止淡灰单条预览）；瞄准线仍白实线、进球线仍目标球本色虚线。
- **原因**：本页教学语义是「同一母球、8 种左右塞并排对比库后扇形」；若 8 条皆白则无法辨认塞量差异，与 E1 验收语义冲突。仿 DR-025（高低杆轴豁免）。
- **影响组件**：`CushionEnglishAtlasView` / `CushionEnglishAtlasViewModel` / `CushionEnglishAtlasGeometry`；全局线语言与 `TrajectoryStyle` 不变。
- **日期**：2026-07-27
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 页面契约 + § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 / Changelog（2026-07-27，DR-029）

## DR-028
- **任务**：球杆显隐与瞄准线绑定 + 运杆/回放衔接（问题集合 v19 W1）
- **原始规范**：各页自行决定何时 `updateCueStick` / `hideCueStick`；Bank/Diamond 求解只画线不摆杆；开球瞄准期无杆；Composer G14 预览硬藏杆；AimPointScene 瞄准期无杆；回放/序列出杆前常先 `hideCueStick`；Bank 求解主击喂球心。
- **调整后**：
  1. **契约**：有稳定瞄准方向且台面正在画瞄准线 ⇒ 同步摆杆；无线/无方向 ⇒ 藏杆。写入 SPEC §8.9 **h**。
  2. **调用点**：`BankShotViewModel`/`DiamondSystemViewModel.drawSolution` 末尾摆杆；`BreakFlowRunner.drawAimLine` 成功后摆杆、清线/取消藏杆；`PositionPlayViewModel.showGeometryPreviewOnly` 自由预览跟杆；`AimPointSceneTrainingView.redrawLines` 瞄准/结果停留跟杆（用户 aim，`spinX:0`）。
  3. **C7 衔接**：瞄准与出杆同一 `aim` + `strikePosition(spinX:)`；禁止 `runCueStroke` 前无故 hide；上一杆短定格 ~0.1s；序列每步 ~0.4s 定格再运杆。
  4. **例外不变**：SceneAiming/AimingQuiz 继续无杆；`.blocked` 仍藏杆（DR-027）。
- **原因**：根因是「画线与摆杆生命周期未绑定」，不是球杆组件坏了。
- **影响组件**：Bank/Diamond VM、BreakFlowRunner、PositionPlayViewModel、AimPointSceneTrainingView、SPEC §8.9；**不改** CueStick/CueClearance/CueStroke 公式。
- **日期**：2026-07-27
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §8.9 h + Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §8.9 h / Changelog（2026-07-27，DR-028）

## DR-027
- **任务**：球杆穿模修复（球遮挡抬杆 + 通用碰撞收杆 + 跟杆前向钳制）
- **原始规范**：`CueStick.requiredElevation` 只算库边、上限 31.5°；`followThroughPull` 固定 −3R；收杆硬切 `hide()`；无球-杆碰撞守卫。
- **调整后**：
  1. **抬杆**：`CueElevation = angle | blocked`；库边与球遮挡取 max；上限 **60°**，超限 **隐藏球杆**（不硬画）；遮挡区间覆盖 `maxPullBack=0.15m`（≈v=2.9m/s）；`updateCueStick` 内部取 `visibleBalls()`，调用点零改；`elevationOverride` 冻结整杆仰角（导出跟杆循环）。
  2. **碰撞守卫**：`CueClearance.firstCollisionTime` 遍历**所有**球；`runCueStroke(clearanceProbe:)` 默认 nil 时 pullBack 序列与改前等价；预测碰撞则 `t*−0.12s` 起 0.18s 抽杆淡出；正常收杆改为短淡出。
  3. **跟杆钳制**：`clampedFollowThroughPull = −min(3R, 前方表面间隙)`，下限 0；实时与 `SequenceVideoExporter` 共用。
- **原因**：杆后有球平放穿模；跟杆定格时倒旋/吃库/连锁球撞进杆身；前方贴球时 −3R 捅进目标球。
- **影响组件**：`CueStick` / `CueStroke` / `CueClearance`（新）/ `AngleTrainingScene.updateCueStick` / `SequenceVideoExporter`；接线 VM：PositionPlay / Silu / SnookerTactics / PlanThree。
- **已知不自洽（本轮不改物理）**：大仰角渲染时引擎仍按平杆积分——强力低杆与立杆姿态物理上不兼容。未接 UI「需架杆/立杆」提示（跨 VM 成本高，仅代码注释 + 本条留档）。
- **返工 r1（2026-07-27，主控验收打回）**：
  1. **软杆误报**：`tipOffset=R+1mm` 已小于碰撞阈值 `R+tipR+margin`；仅跳过 i=0 不够，v≲1.4 在 τ=1/60 误报 → 跟杆整段被跳过。修复为**按球分离闩锁**（曾经出过阈值才成为候选）；探针改为 `[String: SCNVector3]`。
  2. **`worldPoint` 交叉验证**：新增 `test_shaftSegment_matchesSceneKitNode`（真实 SCNNode.convertPosition，含 30°/37°）。
  3. **`.blocked` 可达性**：合法盘面球遮挡峰值 ≈32.3°（s=2R）；库边因 `max(0.05, dist)` 地板峰值 ≈23.2°。**.blocked 在合法盘面不可达**，仅作防御性护栏保留，禁止为可达而放大仰角公式。
- **验证**：`make build` ✅；`CueClearanceTests` 全绿（含软杆 v 档无误报 + 倒旋回撤捕获 + SceneKit 交叉）；`SpinExportParityTests` + `TrajectoryPlaybackSpinTests` 不回归。证据：`build/cue-clearance-evidence/rework_latch_draft.txt`。
- **主控独立验收（2026-07-27）**：逐文件读全量 diff；亲跑 `make build` **BUILD SUCCEEDED** ×2；亲跑 `CueClearanceTests` **12/0**、`SpinExportParityTests` 2/0、`TrajectoryPlaybackSpinTests` 8/0；亲跑 **`QiuJiTests` 全量 684 tests / 0 failures / 2 skipped**（基线 672 + 新增 12，无回归）。r1 前的软杆误报由主控数值草稿独立复现（v=0.4~1.2 均在 τ=1/60 误报）后打回。**未验**：无 SceneKit 离屏/真机截图，抬杆姿态与提前收杆时机待用户点验。
- **日期**：2026-07-27
- **回写目标**：`.cursor/skills/geometry-spatial-reasoning/SKILL.md`；`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `.cursor/skills/geometry-spatial-reasoning/SKILL.md` § 经验教训 / DR-027（2026-07-27）；✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-07-27）

## DR-026
- **任务**：品牌 Logo Mark / App Icon 摆位修正（用户反馈「logo 里的 O 看着不居中」）
- **原始规范**：snail-QJ 图形按**整体外接框居中**摆放（`brand.logo-mark{,-dark}.svg` 用 `translate(-559 -443) scale(1.492)`；App Icon 白色图形外接框中心 x=505 ≈ 画布中心 512）。
- **调整后**：两步。**① 摆位**：改为**光学折中**——按「环（O）」而非整体外接框对中，回收约 60% 偏差。SVG transform → `translate(-456.4 -443) scale(1.492)`（x 平移 +102.6，scale 不变）；App Icon 白色图形整体右移 34px（1024 画布）。**② 占比**（用户同轮追加「占比有点小」）：App Icon 图形以环心为中心等比放大 **1.25×**（图形宽 58.7%→73.7%，环直径 48.8%→60.9%）；应用内 `BTBrandLogo` `.onTile` 内边距 **16%→10%**（图形宽 57.2%→67.8%，环直径 47.0%→55.4%），`.onDisc` 保持 16%。
- **原因**：图形由「环」+「向右下伸出的尾撇」组成，尾撇把整体外接框中心拉向右，于是环被挤到画布左侧。实测（解析 bezier 极值 + 最小二乘圆拟合）：SVG 环心偏左 7.8% 画布宽，App Icon 环心偏左 5.5%——这就是「O 不居中」的成因，不是错觉。未做 100% 居中，因为环严格居中需把 scale 压到 1.4658 且尾尖会贴死画布右边缘、左侧留大片空白，反而更失衡。
- **实测验收**（环圆最小二乘拟合）：
  | 对象 | 环心 dx（前 → 后） | 图形宽占比 | 环直径占比 |
  |---|---|---|---|
  | `AppIcon.png`（@1024） | −56.3px（−5.50%）→ **−22.5px（−2.20%）** | 58.7% → **73.7%** | 48.8% → **60.9%** |
  | `brand.logo-mark{,-dark}.svg`（@1024 裸渲染） | −79.7px（−7.78%）→ **−28.4px（−2.77%）** | 84.7%（未变，SVG 只改摆位） | 69.2%（未变） |
  | `.onTile` 成品观感（@400 方块） | −2.0% → −2.3% | 57.2% → **67.8%** | 47.0% → **55.4%** |
  App Icon 四边留白 L177 R92 T205 B205，未裁切、未触 squircle 圆角；竖直位置不变（环心 y 515）。
- **App Icon 重建方式**（两步都不做位图缩放）：**摆位步**先对背景做逐通道线性渐变最小二乘拟合（rms 0.325/255），据此反解白色图形 alpha（保住抗锯齿与极细尾尖）后在重建底上平移合成，背景保真最大差 2/255、均值 0.10/255。**放大步**直接从矢量路径重渲染（避免二次重采样发虚）：先在裸路径空间拟合环圆 `center=(954.365, 990.360) r=475.288`，据此算出 1024 画布内的摆放 `translate(-137.259 -135.195) scale(0.656917)`（令环心落在 `(489.68, 515.39)`、环半径 249.78→312.2），4× 超采样渲染后 Lanczos 降采样取 alpha，再合成到同一拟合渐变底。
- **影响组件**：`BTBrandLogo`（OnboardingView / LoginView / AboutView / BTShareCard；摆位步经资产生效无需改码，占比步改了 `.onTile` 内边距——`tile(_:inset:)` 新增 inset 参数，`.onDisc` 显式保持 0.16）、主 App Icon。
- **未纳入范围**：`QiuJiLiveActivity/Assets.xcassets/AppIcon.appiconset/` 三张图是**旧版 3D 写实图标**（绿呢台面 + 白球黄球轨迹），与扁平 snail-QJ 不同源、不含环，本次不动；另这三张文件字节完全相同（1590215 B），即 Dark / Tinted 变体实际未做区分——属独立待办，未在本条修复。
- **日期**：2026-07-25
- **回写目标**：`/Users/song/projects/18.qiuji_icon_design/ICON-INVENTORY.md` § 7.1 摆位契约（防止上游重新导出时回退）
- **已应用至**：✅ `18.qiuji_icon_design/ICON-INVENTORY.md` § 7.1（2026-07-25，DR-026）；✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-07-25，DR-026）

## DR-025
- **任务**：问题集合 v11 Y3「分离角图谱」
- **原始规范**：线语言 v2（SPEC §8.9 / 设计稿 §1.2）——线色 = 球的身份（白=母球路径；目标球本色=该球路径）。
- **调整后**：**页内专用豁免**——「分离角图谱」8 条母球碰后轨迹用页内 8 色板（`SeparationAngleAtlasGeometry.trackColors`，高杆暖→低杆冷）区分 spinY 档位身份，**不**改全局 `TrajectoryStyle`，也不影响打区「分离角与走位」等其它页。瞄准线仍白实线、进球线仍目标球本色虚线。
- **原因**：本页教学语义是「同一母球、8 种杆法并排对比」；若 8 条皆白则无法辨认高低杆差异，与 N2 验收语义冲突。
- **影响组件**：`SeparationAngleAtlasView` / `SeparationAngleAtlasGeometry`；全局线语言与 `TrajectoryStyle` 不变。
- **日期**：2026-07-18
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 页面契约 + § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 / Changelog（2026-07-18，DR-025）

## DR-001
- **任务**：T-R0-02
- **原始规范**：SKILL.md 中 `btBGTertiary` Light = `#F2F2F7`、`btBGQuaternary` Light = `#E5E5EA`、`btSeparator` Light = `#C6C6C8`（α1.0）
- **调整后**：`btBGTertiary` Light = `#E5E5EA`、`btBGQuaternary` Light = `#D1D1D6`、`btSeparator` Light = `rgba(60,60,67,0.18)`。与 UI 设计交付物（`UI-IMPLEMENTATION-SPEC.md` § 1.1）对齐。
- **原因**：原始 SKILL.md 使用了旧 Token 值，背景层次向下偏移了一级；`btSeparator` 应为半透明以适配不同底色叠加。设计交付物 44 帧已统一使用新值。
- **影响组件**：全局 — 所有使用 btBGTertiary/btBGQuaternary/btSeparator 的视图
- **日期**：2026-04-05
- **回写目标**：`SKILL.md` § 二·色彩系统
- **已应用至**：✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 二（2026-04-05）

## DR-002
- **任务**：T-R0-03
- **原始规范**：`UI-IMPLEMENTATION-SPEC.md` § 2.1 定义 `case segmentedPill` 无关联值
- **调整后**：`case segmentedPill(isSelected: Bool)`，需传入选中状态以区分填充/描边渲染
- **原因**：ButtonStyle 协议无内建选中态；不使用关联值则无法在同一枚举中区分选中/未选中视觉
- **影响组件**：BTButton、BTTogglePillGroup（T-R0-04 将使用此 API）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § 2.1、`SKILL.md` § 七
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § 2.1 + `SKILL.md` § 七（2026-04-05）

## DR-003
- **任务**：T-P4-05
- **原始规范**：`UI-IMPLEMENTATION-SPEC.md` § 2.11 BTSetInputGrid API 仅含 `onAddSet` 和 `onComplete` 回调，madeBalls/targetBalls 显示为静态 Text
- **调整后**：新增 `onDeleteSet: ((Int) -> Void)?` 回调；非已完成行的 madeBalls/targetBalls 改为 TextField（支持数字键盘输入）；溢出菜单列提供删除功能；`RowState` 从 `private` 改为 `internal` 以支持文件级 SetRow 访问
- **原因**：T-P4-05 DoD 要求「长按可删除某组记录」和「进球数（数字键盘输入）」和「目标球数（可调）」，原组件 API 不支持这些交互
- **影响组件**：BTSetInputGrid、DrillRecordView（新建）、ActiveTrainingViewModel（drillSetsData 替代 ballsMadeRecords）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § 2.11、`SKILL.md` § 十三
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-004
- **任务**：T-P4-06
- **原始规范**：TrainingNoteView 早期实现包含大图标 header + 统计徽章行 + 有边框输入框 + 纵向堆叠全宽按钮；"完成"空文本时禁用
- **调整后**：匹配 `code.html` 设计——极简布局：顶部 2 行引导提示 + 全屏无边框 TextEditor + 固定底栏左"跳过"右"完成"；"完成"始终可点击；新增 `onBack` 返回训练功能；移除 `drillCount`/`elapsedSeconds` 参数
- **原因**：原实现未对照 `code.html` 精确布局，偏离设计意图（设计强调沉浸式写作体验，无装饰性元素）
- **影响组件**：TrainingNoteView（API 简化 5→3 参数）、ActiveTrainingView（toolbar 新增 note 阶段返回按钮）、ActiveTrainingViewModel（新增 `resumeTraining()`）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-005
- **任务**：T-P4-07
- **原始规范**：TrainingSummaryView 使用简化的 `DrillSummary`（仅聚合 totalBallsMade/totalBallsPossible），`hasNote: Bool` 标记，无"生成分享图"入口，无总进球统计卡
- **调整后**：匹配 `code.html` 设计——2×2 统计网格 + 全宽成功率进度条卡；`DrillSummary` 新增 `level: DrillLevel?` 和 `sets: [SetResult]` 支持每组明细展开；`ActiveDrill` 新增 `level` 属性；API 改为 10 参数（+totalBallsMade, trainingNote, onGenerateShareImage; -hasNote）；底部固定操作栏包含保存/分享/历史三入口
- **原因**：code.html 设计要求每个 Drill 卡片展示分组明细和等级徽章，原模型数据粒度不足；设计底部有"生成分享图"入口对接 T-P4-10
- **影响组件**：DrillSummary（新增 SetResult + level）、ActiveDrill（新增 level）、TrainingSummaryView（API 重构）、ActiveTrainingView（调用更新）、ActiveTrainingViewModel（新增 totalBallsMade）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-006
- **任务**：T-P4-10
- **原始规范**：BTShareCard R0 版本：date → title → stats → drill-dots → footer（简约列表布局）；`TrainingSessionSummary.DrillResult` 无 `setsCount`；无 `totalBallsMade` 计算属性
- **调整后**：匹配 `code.html` 设计——logo header（绿色 Q 徽章 + 品牌名 + 日期）→ title + 概要 → separator → drill 行（白色 5% 背景圆角卡片，显示名称 + 组数 + 成功率%）→ stats grid（总进球 / 总组数 / 平均成功率三列）→ footer（品牌名 + 副标题 + QR 占位）；新增 `fontChoice: ShareCardFont` + `hideSuccessRate: Bool` 参数支持定制；`DrillResult` 新增 `setsCount`；`TrainingSessionSummary` 新增 `totalBallsMade` 计算属性
- **原因**：T-P4-10 实际实现时对照 code.html 发现 R0 骨架布局与设计差异较大（顺序、样式、数据展示方式全部不同）
- **影响组件**：BTShareCard（布局重构 + API 扩展）、TrainingSessionSummary（DrillResult + computed prop）、新增 ShareCardFont 枚举、新建 TrainingShareView
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

---

## PD-001
- **任务**：T-P4-06
- **模式描述**：设计参考三步流程——每个页面实现前必须依次查看 `screen.png` → `code.html` → `UI-IMPLEMENTATION-SPEC.md`，避免仅凭截图猜测布局
- **适用场景**：所有涉及 UI 实现的任务（P4-P8、R-UI）
- **代码示例**：无（流程规范，非代码模式）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § 文件头优先级声明
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § 文件头（2026-04-05）——已更新为三步流程

## DR-007
- **任务**：T-P4-09
- **原始规范**：CustomPlanBuilderView 使用 List(.insetGrouped) + 标准 Stepper + 内联 Stepper 行调整组数/球数；无缩略图；无设计设置弹层
- **调整后**：匹配 `code.html` 设计——ScrollView + VStack 自定义布局；Plan Info Card（编辑图标 + 名称 TextField + 统计摘要）；自定义 -/数字/+ 步进器替代原生 Stepper；Drill 行含拖拽手柄图标 + 56pt 迷你球台缩略图 + 名称 + 「X组·Y球」+ 齿轮图标；新增 DrillSettingsSheet（半屏 .medium detent，Stepper 调组数/球数 + 移除按钮）；ViewModel 新增 totalSetsCount/totalBallsCount/updateDrillSettings/removeDrill
- **原因**：原 List 实现偏离设计意图（code.html 使用卡片式分区、自定义步进器、缩略图行布局）；齿轮设置弹层替代内联 Stepper 提升操作精度和视觉清洁度
- **影响组件**：CustomPlanBuilderView（布局完全重写）、CustomPlanBuilderViewModel（新增 4 个方法/属性）、新增 DrillSettingsSheet
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-008
- **任务**：T-RUI-03
- **原始规范**：ActiveTrainingView 底部工具栏仅图标无文字标签；顶栏 2 图标（play/gear）；无计划名显示；热身标记使用 btAccent 金色
- **调整后**：底部 5 键工具栏添加可见文字标签（最小化/更多/添加/心得/切换）；顶栏扩展为 4 图标（play、timer、filter、checkmark）；frostedTopBar 新增计划名 + 进度文字区；drillRecordContent 共用 frostedTopBar 替代独立 drillRecordHeader；热身「热」标记改为 btWarning 橙色
- **原因**：匹配 P0-03/P0-04 设计截图——底栏需要文字标签辅助识别；顶栏图标数量与设计一致；计划名是设计中的显著信息层级
- **影响组件**：ActiveTrainingView（frostedTopBar/bottomToolbar 重构）、BTSetInputGrid（warmup 色值）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-009
- **任务**：T-RUI-04
- **原始规范**：ProfileView 使用居中大头像 + 纯文本菜单行（MenuRow 无彩色图标背景）；LoginView 使用卡片式选项列表（LoginOptionButton），非全宽按钮；三种登录方式视觉层级无区分
- **调整后**：ProfileView 重构为横向用户卡片（头像+名称+Pro 徽章） + 月度概览统计区 + 双分组彩色圆底图标菜单（ProfileMenuRow：32pt 圆底 + SF Symbol + 标题 + 详情文字）；访客模式新增警告横幅 + Pro 推广深色卡；LoginView 重写为三按钮分层设计（Apple 黑底 > 微信 #07C160 > 手机号灰描边）+ App 图标 + 法律文案底栏；PhoneLoginView 输入改为药丸形（Capsule）+ 发送验证码按钮内嵌 + 底部品牌标识
- **原因**：匹配 P2-03/P2-05 设计截图——彩色图标菜单提升信息层次；三按钮分层设计建立清晰的登录优先级；药丸形输入更现代
- **影响组件**：ProfileView（完全重写）、LoginView（完全重写）、PhoneLoginView（输入样式 + 布局重构）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-010
- **任务**：T-RUI-05
- **原始规范**：OnboardingView 使用 `figure.pool.swim` 大图标 + btBGSecondary 卡片背景 FeatureRow + 文案「台球训练，从记录开始」
- **调整后**：匹配 P2-04 设计——QJ Logo 圆形标识 + 品牌绿圆底图标 FeatureRow（`rgba(26,107,60,0.12)` 48pt 圆底 + SF Symbol，无卡片背景）+ 文案「你的台球训练伙伴」+ 按钮文案「开始使用」/「登录已有账号」+ `.preferredColorScheme(.light)` 强制浅色
- **原因**：原实现未对照设计截图；Onboarding 为品牌首屏需保持浅色一致性（DM-009）
- **影响组件**：OnboardingView（完全重写）
- **日期**：2026-04-05
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## DR-011
- **任务**：DrillLibrary Renovation（参照训记 ref-screenshots 04-exercise-library）
- **原始规范**：DrillListView 单列横向卡片列表 + BTDrillCard 渐变色+SF Symbol 缩略图
- **调整后**：
  1. 新建 `BTMiniTable.swift` — 缩略图专用 Canvas（球径 0.034 vs 0.01125，路径宽 0.007 vs 0.003，无库边，目标袋口 btPrimary 光环高亮）
  2. `BTDrillGridCard` 竖向卡片 — BTMiniTable 缩略图 + 左上 BTLevelBadge + 右上 PRO/收藏 + 底部渐变 + 名称/球种/推荐组数
  3. `DrillListView` 布局重构 — 训记风格左侧分类侧边栏（72pt，选中 btPrimary 绿字+左竖线）+ 右侧 `LazyVGrid` 2 列网格
  4. `DrillDetailView` 新增 — 备注输入卡片、训练维度 5 进度条（准度/力量控制/走位判断/杆法技巧/心理素质）、查看精讲 Pill、真人示范横滚占位
  5. `BTDrillListSkeleton` 更新为 2 列网格骨架
  6. `BTDrillThumbnail` 改用 BTMiniTable 替代旧渐变+图标占位
- **原因**：参照训记 ref-screenshots（04-exercise-library 共 11 张），用户要求"图鉴式"2 列网格 + 左侧分类侧边栏，而非原设计稿的单列列表
- **影响组件**：BTMiniTable（新建）、BTDrillGridCard（重构）、BTDrillThumbnail（重构）、DrillListView（布局重构）、DrillDetailView（新增 4 个 Section）、BTDrillListSkeleton（网格化）
- **日期**：2026-04-06
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog + `PROGRESS.md`
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-06）、✅ `PROGRESS.md`（2026-04-06）

## PD-002
- **任务**：T-P8-11
- **模式描述**：Dark Mode 全面通刷标准化流程
- **适用场景**：新页面开发或 Dark Mode 审计
- **代码示例**：
  1. 阴影必须 Dark 条件化：`.shadow(color: colorScheme == .dark ? .clear : .black.opacity(X), ...)`
  2. 缩略图 Dark 描边：`.overlay(RoundedRectangle(...).stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0))`
  3. Apple 登录按钮 HIG Dark：白底+黑字（Dark），黑底+白字（Light）
  4. 图标容器 opacity：Light 12% → Dark 15%（深色表面需更高对比）
  5. darkPill 按钮 Dark 使用 btBGTertiary（#2C2C2E）而非固定 #1C1C1E
- **日期**：2026-04-05
- **回写目标**：`20-swiftui-developer.mdc` § Dark Mode 模式
- **已应用至**：✅ `UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-04-05）

## FL-001
- **任务**：QA-P2（人工测试）
- **现象**：Apple 登录请求 URL 为 `http://auth/login-apple`（API_BASE_URL 未正确注入），后端不可达
- **严重程度**：P1
- **关联检查项**：TP-P2 流程8-①
- **根因**：xcconfig 中 `//` 被当作注释，`http://106.54.3.210:3000` 被截断为 `http:`；`URL(string: "http:").appendingPathComponent("/auth/login-apple")` 产生畸形 URL
- **解决**：✅ 使用 `$()` 空变量打断双斜杠：`API_BASE_URL = http:/$()/106.54.3.210:3000`；构建后 Info.plist 验证正确
- **日期**：2026-04-10
- **规则改进建议**：xcconfig 中含 `://` 的 URL 值必须使用 `$()` 打断双斜杠（`http:/$()/...`），否则后半段被丢弃
- **已应用至**：✅ `60-devops-release.mdc` § 经验教训 / FL-001（2026-04-10）

## FL-002
- **任务**：QA-P2（人工测试）
- **现象**：Sign in with Apple 登录成功后未弹出数据迁移 Alert
- **严重程度**：P2
- **关联检查项**：TP-P2 流程6-⑤
- **根因**：(1) `AuthState.login()` 中 `wasAnonymous` 仅检查 `provider == .anonymous`，但首次用户 `currentUser` 为 `nil`，条件不满足；(2) `LoginView` 在 `authState.login()` 后立即 `dismiss()`，Sheet 动画中 ProfileView 无法弹 Alert
- **解决**：✅ 条件改为 `!isLoggedIn`（覆盖 nil 和 anonymous）；新增 `pendingMigration` 标志，在 Sheet `onDismiss` 回调中触发 Alert
- **日期**：2026-04-10
- **规则改进建议**：Sheet 中修改全局状态后需 Alert 时，应通过 pending 标志 + onDismiss 延迟触发，避免 SwiftUI 动画冲突
- **已应用至**：✅ `20-swiftui-developer.mdc` § 经验教训 / FL-002（2026-04-10）

## PD-003
- **任务**：图标体系重设计（Phase A–D 全周期）
- **模式描述**：**SwiftUI Shape + Canvas 取代 PDF/SF Symbol 自定义包** 作为品牌图标资产的产出方式
- **适用场景**：需要扁平、矢量、Light/Dark 双模适配、且与既有 Design Token 强耦合的品牌图形（Logo Mark / Tab 图标 / Drill 分类图标 / Onboarding 装饰）
- **代码示例**：见 [`BTLogoMark.swift`](../QiuJi/Core/DesignSystem/BTLogoMark.swift)、[`BTTrainingIcon.swift`](../QiuJi/Core/DesignSystem/BTTrainingIcon.swift)、[`BTDrillCategoryIcon.swift`](../QiuJi/Core/DesignSystem/BTDrillCategoryIcon.swift)
- **优势**：
  1. **零 PDF / imageset 资产** — 完全规避 [FL-010](FAILURE-LOG.md) xcodegen folder reference 风险
  2. **Design Token 直接绑定** — `Color.btPrimary` / `Color.btAccent` 自动 Light/Dark 切换，无需双套资产
  3. **共享几何参数** — 8 个 Drill 分类共用 `Tokens.strokeWidth` / `Tokens.ballRadius`，视觉权重 100% 一致
  4. **Tab Bar 集成** — `ImageRenderer` 把 SwiftUI 视图转为 `UIImage(...).withRenderingMode(.alwaysTemplate)`，让系统着色行为与 SF Symbols 一致
- **关键陷阱**：
  - `cos(angle)` / `sin(angle)` 在 `CGFloat` 与 `Double` 间存在二义性 — 必须显式注解：`let angle: CGFloat = .pi * 1.65; let cosA: CGFloat = cos(angle)`
  - 涉及 `CGFloat(i)` 而非 `Double(i)` 才能避免类型升格
- **日期**：2026-05-25
- **回写目标**：`.cursor/skills/swiftui-design-system/SKILL.md` § 图标资产生产 SOP
- **已应用至**：⏳ 待回写

## DR-012
- **任务**：图标体系重设计（Phase A–D）
- **原始规范**：Tab Bar 训练 Tab 使用 `dumbbell.fill`（U-01 已知问题）；Drill 8 分类的 SF Symbol 已在 `DrillContentService.icon` 定义但未接入 UI；Onboarding/Login/About 的应用内 Logo 用 `Text("QJ")` 占位
- **调整后**：
  1. 训练 Tab 使用 `BTTrainingIcon`（SwiftUI 自定义图标，球+轨迹隐喻）
  2. Drill 8 分类引入 `BTDrillCategoryIcon` 接入 `DrillListView` 侧边栏（图标 + 文字双行）+ Section Header 前缀 + `StatisticsView.categoryComparisonCell`
  3. 应用内 Logo 替换为 `BTLogoMark(size:style:)`，含 `markOnly / onDisc / onTile` 三种 style
  4. App Icon 重塑：从 3D 写实+青色激光 → 3D 写实+金色轨迹弧（`AppIcon.png` 1024×1024，台呢绿 + 金色 = 与 `btTableFelt` / `btAccent` 一致）
  5. Launch Screen：通过 `UILaunchScreen.UIImageName = "LaunchLogo"` + `UIColorName = "btBG"` 实现，新增 `LaunchLogo.imageset`（@1x/@2x/@3x = 360/720/1024）
  6. Live Activity Extension AppIcon：补齐三态 PNG（复用主 AppIcon）
  7. 全局清理 `figure.pool.swim`（5 处 Swift 源码）→ 替换为 `BTTrainingIcon` 或 `scope`
- **原因**：原图标体系 App Icon 与 App 内主色割裂（青色激光 vs 品牌绿+金）；DrillCategory.icon 的"已设计未接入"是体感最差的缺口；Tab `dumbbell.fill` 与台球语义不符
- **影响组件**：`BTLogoMark` / `BTTrainingIcon` / `BTDrillCategoryIcon` / `IconToken` 全新；`MainTabView` / `OnboardingView` / `LoginView` / `AboutView` / `DrillListView` / `StatisticsView` / `BTExerciseRow` / `TrainingHomeView` / `TrainingSummaryView` / `DrillTutorialView` 受影响；`Info.plist` / `project.yml` / `LaunchLogo.imageset` 配置变更
- **日期**：2026-05-25
- **回写目标**：`UI-IMPLEMENTATION-SPEC.md` § Changelog（U-01 关闭）+ `docs/09-UI设计交付文档.md` § 已知 UI 问题清单（U-01 移除）
- **已应用至**：⏳ 待回写

## FL-003
- **任务**：T-P9-03（角度与打点 / 2D 顶视图袋口标记）
- **现象**：未选/选中袋口的黄色阴影圆盘没有落在球桌真实袋口洞内，而是卡在击球区角点（库边交汇处），与皮革开口偏离 4–5cm
- **严重程度**：P2
- **关联检查项**：TP-P9 视觉对位 / `现有问题.md` § 角度与打点 第 1 条
- **根因**：(1) `AngleSceneCalculator.pocketPositions` 长期返回的是「击球区角点」`(±halfL, ±halfW)`，而中式八球真实袋口中心位于该角点沿对角线 **外侧 42mm**（中袋外侧 53mm），见 `.kiro/steering/table-geometry.md`；(2) `PocketGeometryExtractor` 试图从 USDZ 网格反推真实洞中心（最大空圆 / Pole of Inaccessibility），结果不稳定且依赖模型材质命名，掩盖了第 (1) 项的根因
- **解决**：✅ `pocketPositions` 改为基于解析公式直接返回真实袋口中心（`±(halfL+0.042)`, `±(halfW+0.042)` / 中袋 `±(halfW+0.053)`）；新增 `cornerPocketRadius=0.042`、`middlePocketRadius=0.043`、`pocketMarkerRadius(index:)`；`AngleTrainingScene.addPocketMarkers` 移除 extractor 调用，圆盘半径升级到 42/43mm 对齐皮革开口；`PocketGeometryExtractor.swift` 删除（含 pbxproj 4 处引用）
- **日期**：2026-04-25
- **规则改进建议**：球桌 / 袋口几何 **必须** 来自 `.kiro/steering/table-geometry.md` 唯一事实来源的解析常量；不得用模型网格反推（模型可能因比例、材质命名变化破坏）。新增几何相关常量时，先检查 steering 文档是否已有定义。
- **回写目标**：`.cursor/rules/20-swiftui-developer.mdc` § 经验教训
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-003（2026-04-25）

## PD-004
- **任务**：图标体系重设计 v2（Recraft 独立设计仓）
- **模式描述**：**把图标体系剥离为独立的设计交付仓**（解耦设计与开发），主工程仅消费 `final/` 中已验收的资产，避免设计迭代污染主工程代码
- **适用场景**：图标数量 ≥ 30 项、需要统一品牌化、设计工具与 iOS 工程链路无直接耦合（如使用 Recraft、Figma 等外部工具）
- **决策背景**：PD-003 的 SwiftUI Shape 自绘方案在快速迭代品牌一致性时不够灵活（每次调整都需 Swift 代码 + xcodegen），且无法满足 App Icon 这种 3D 写实场景；改用 Recraft 矢量产出更适合品牌图标的迭代节奏
- **设计仓位置**：`/Users/song/projects/18.qiuji_icon_design`
- **设计仓产出物**（已交付）：
  - 三大核心：`README.md` / `BRAND-SYSTEM.md` / `ICON-INVENTORY.md`（60+ 项穷举清单）
  - 13 个 spec 文档：`specs/01-app-icon.md` ~ `specs/13-marketing.md`
  - 工作流：`RECRAFT-WORKFLOW.md`（Recraft SOP + Prompt 模板 + 失败模式速查）
  - 验收：`ACCEPTANCE-CHECKLIST.md`（每图 12 项 DoD）
  - 回写：`INTEGRATION-PLAN.md`（4 个 PR 的回写步骤）
- **本期阶段**：仅交付**完整需求文档**；Recraft 实际生图与回写主工程为后续阶段
- **主工程过渡策略**：当前 SwiftUI 自绘占位（`BTLogoMark` / `BTTrainingIcon` / `BTDrillCategoryIcon` / 替换后的 `AppIcon.png`）**保留作为占位**，不阻塞开发；待 Recraft 成品验收通过后按 INTEGRATION-PLAN 分 4 PR 回写
- **覆盖范围**（A + B = 68 项待 Recraft 出图）：
  - A 类（必须 Recraft）：App Icon 三态 + Marketing + Live Activity / Logo + Wordmark / Tab 5×2 / Drill 8 分类（共 26）
  - B 类（推荐 Recraft）：Plan 4 阶段 / Drill L0–L4 / Angle 4 模式 / Feature Cards 4 / Tutorial 4 / Profile 4 / Empty States 6 / ShareCard 2 / Marketing 3（共 42）
  - C 类（保留 SF Symbol）：65 个纯功能图标，集中管理在 `IconToken.swift`，**不在 Recraft 范围**
- **代码示例**（回写后调用模式）：
  ```swift
  // 旧（SwiftUI 自绘占位）
  BTLogoMark(size: 80, style: .onTile)
  BTDrillCategoryIcon(category: .fundamentals)

  // 新（Recraft 矢量资产）
  Image("brand.logo-mark.on-tile").resizable().scaledToFit().frame(width: 80, height: 80)
  Image(category.icon)  // category.icon 返回 "ic.drill.fundamentals"
  ```
- **关键约束**：
  1. 主工程 `Resources/Assets.xcassets/` 新增 ~50 个 imageset，每个含 Light/Dark SVG + Contents.json appearances 数组
  2. SVG 必须配置 `preserves-vector-representation: true`，否则放大模糊
  3. Tab Bar 图标 imageset 必须 `template-rendering-intent: template`，让 iOS 自动按 tint 着色
  4. 命名规范：`ic.<group>.<name>[.<state>]`（与 BRAND-SYSTEM §7 同步）
- **日期**：2026-05-25
- **回写目标**：
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 图标资产生产 SOP（更新 PD-003 → PD-004 的策略演进）
  - `.cursor/rules/20-swiftui-developer.mdc` § 图标引用规范（新增）
- **已应用至**：⏳ 待回写（等 Recraft 实际成品验收通过后，PR 1 时同步回写规则文件）

## DR-013
- **任务**：训练计划编辑式排版升级（Round 1 + Round 2，无 Phase 编号 — 用户驱动 ad-hoc 任务）
- **原始规范**：训练计划 4 个屏幕（PlanDetailView / PlanListView / TrainingHomeView 计划浏览 + 今日安排 Drill 卡）的文本展示「过于平铺」：所有文本同一字号差档、缺少 hierarchy、无装饰母题、`Circle().fill(opacity 0.3)` 风格的 system Form Row
- **调整后**：确立"中文编辑式排版语言（Chinese Editorial Typography）"：
  1. **极致字号差**：主标题用 `btDisplaySmall (36pt rounded bold)`，章节序号用 `btChapterNumber (32pt rounded bold)`；次级标题 `btTitleMedium (19pt semibold)`；用 17pt+ 落差替代英文 small caps tracking（用户偏好纯中文）
  2. **数字英雄化**：所有计数（周/天/分钟/组/球/序号）一律 `.monospacedDigit()`；统计数据采用「奥运记分牌」式（数字大、单位下移小字）
  3. **细金线分隔**：`BTGoldRule` 组件（1pt × 32pt-wide × `Color.btAccent.opacity(0.6)`）替代 system Divider
  4. **首句加粗**：`splitFirstSentence(_:)` 工具函数按中英文句号切分，首句 `btTitleMedium` 主色 + 余文 `btBody` 次色
  5. **章节序号化**：每个 plan 在所属 level 中的位置作 `01 / 02 / ...` 序号，缩略图改为「序号刻度」式而非纯渐变方块
  6. **Drill tracklist 化**：`01 02 03` 序号 + `3×15` monospaced 单元，替代 `Circle().fill` 装饰点
  7. **Round 2 装饰**：`BTPlanWeekTimeline`（横向四态进度条 + 虚线连接）、`BTPhaseTimeline`（纵向 1pt 虚线 + 8pt 染色圆点 + 阶段类型染色：warmup/focused/combined/review）、`BTArcSeparator`（金色弧形台球母题章节分隔）、hero 区右上角 `BTTrainingIcon` 透明度 0.08 / 旋转 -15° 水印、每周首个 drill 的 `coachingPoints[0]` 作为 italic pull quote + 2pt `btAccent` 竖线
  8. **Typography 新增 token**：`btDisplaySmall (36pt)`、`btChapterNumber (32pt)`、`btTitleMedium (19pt)`
- **原因**：用户反馈训练计划文本展示「过于平铺，没有艺术风格」；调研后确定参考 Apple Fitness+ / MasterClass 编辑式排版 + 杂志专辑 tracklist 风格，但保持纯中文（用户选择 chinese_only）
- **影响组件**：
  - 新增：`BTPlanWeekTimeline`、`BTPhaseTimeline`、`BTPhaseEntry`、`BTGoldRule`、`BTArcSeparator`
  - 修改：`PlanDetailView`、`PlanListView`、`TrainingHomeView`、`Typography.swift`
  - 数据：`PlanDetailView` 新增 `coachingQuotes: [Int: String]` 缓存模式（每周首个 drill 的 coachingPoint）
- **日期**：2026-05-25
- **回写目标**：
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 中文编辑式排版语言（新增章节）
  - `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：
  - ✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 十四 中文编辑式排版语言（2026-05-25）
  - ✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 三 字体系统（2026-05-25，新增 btDisplaySmall/btChapterNumber/btTitleMedium）
  - ✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 十三 组件清单（2026-05-25，新增 BTGoldRule/BTArcSeparator/BTPlanWeekTimeline/BTPhaseTimeline）
  - ✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-05-25，9 条 DR-013 条目）

## PD-005
- **任务**：训练计划编辑式排版升级（同 DR-013）
- **模式描述**：**「中文编辑式排版语言」可复用模式**——在没有英文 small caps tracking 的中文界面中，通过「极致字号差 + tabular monospaced 数字 + 1pt 金色细线 + 首句加粗 + 大序号刻度」五件套，把 list/form 平铺升级为编辑式 hierarchy
- **适用场景**：长文本主导的列表/详情页（如训练计划、教程、文章列表、Drill 详情），需要打破 list row 同质感、引入 hierarchy 与 brand 装饰，但不能依赖英文小型大写
- **代码示例**：
  ```swift
  // 1. 编辑式上眉 + 主标题 + 金线
  HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
      Text("入门系列").font(.btCaption2).foregroundStyle(.btTextTertiary)
      Circle().fill(Color.btAccent).frame(width: 3, height: 3)
      Text("第 1 期").font(.btCaption2).foregroundStyle(.btTextTertiary).monospacedDigit()
  }
  Text(plan.nameZh).font(.btDisplaySmall).foregroundStyle(.btText)
  BTGoldRule()  // 1pt × 32pt × Color.btAccent.opacity(0.6)

  // 2. 首句加粗描述（concat Text）
  let (lead, rest) = splitFirstSentence(text)
  (Text(lead).font(.btTitleMedium).foregroundStyle(.btText)
   + Text(rest).font(.btBody).foregroundStyle(.btTextSecondary))
   .lineSpacing(4)

  // 3. tracklist 序号化（替代 Circle 装饰点）
  HStack(spacing: Spacing.sm) {
      Text(String(format: "%02d", index + 1))
          .font(.btFootnote).monospacedDigit()
          .foregroundStyle(.btTextTertiary)
          .frame(width: 24, alignment: .leading)
      Text(itemName).font(.btCallout)
      Spacer()
      Text("\(sets)×\(balls)").font(.btFootnote).monospacedDigit()
  }

  // 4. 奥运记分牌式数字（数字大 + 单位下移小字）
  VStack(spacing: Spacing.xs) {
      Text("\(value)").font(.btDisplaySmall).monospacedDigit()
      Text(unit).font(.btCaption).foregroundStyle(.btTextSecondary)
  }
  ```
- **关键约束**：
  1. 全场必须 `.monospacedDigit()`，否则数字宽度抖动会破坏奥运记分牌感
  2. `BTGoldRule` 默认宽度 32pt（不要太长，否则像 Divider）；`.padding(.bottom, 6)` 与基线对齐
  3. 章节序号字号建议 ≥ 主标题字号（32pt vs 22pt），否则反客为主
  4. 首句切分应同时支持中英文标点（`["。", "！", "？", ".", "!", "?"]`）
  5. Light/Dark 都要测：`btAccent` 在两种模式下饱和度差异较大，金线 opacity 0.6 是经验值
- **日期**：2026-05-25
- **回写目标**：
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 中文编辑式排版模式
  - `.cursor/rules/20-swiftui-developer.mdc` § 编辑式排版铁律
- **已应用至**：
  - ✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 十四 中文编辑式排版语言（2026-05-25，含 5 件套铁律 + Section Header 模板 + 装饰母题 + 反例）
  - ⏳ `.cursor/rules/20-swiftui-developer.mdc`（待主动触发该 rule 时再回写，避免一次性扩张过多规则）

## DR-014
- **任务**：全局字体密度优化（用户驱动 ad-hoc 任务 — 截图反馈：训练首页、动作库、计划详情字号偏大、整体拥挤）
- **原始规范**：DR-013 编辑式排版引入的展示级字号（`btDisplay 48` / `btDisplaySmall 36` / `btChapterNumber 32`）在真机截图中显得过强；标题级 `btTitle 22` / `btTitle2 20` / `btTitleMedium 19` 三档落差大，但被广泛用于列表卡片标题，导致页面密度过高；`btStatNumber 28` 在卡片统计场景压迫感强
- **调整后**：以角度训练首页（34 → 17 → 13 紧凑层级）为基准，全局字号下调一档：
  - 展示级：`btDisplay` 48→44、`btDisplaySmall` 36→30、`btLargeTitle` 34→32、`btChapterNumber` 32→26
  - 标题级：`btTitle` 22→20、`btTitle2` 20→18、`btTitleMedium` 19→17（与 `btHeadline` 同字号，按语义互换）
  - 数据级：`btStatNumber` 28→24
  - 辅助级（新增文档化）：`btSubheadlineSemibold 15` / `btFootnote14 14` / `btMicro 10`
  - 页面层面：`TrainingHomeView.todayDrillCard` 标题从 `btTitle2` 降为 `btHeadline`；序号从 `btTitleMedium` 降为 `btSubheadlineSemibold`；`issueThumbnail` 硬编码 26pt 改为 `btStatNumber`；`PlanDetailView.statCell` 数字 `btDisplaySmall` → `btStatNumber`；描述 lead 句 `btTitleMedium` → `btBodyMedium`
- **原因**：截图反馈页面整体拥挤、字号层级偏重；以"角度训练首页"为视觉舒适基准做收敛，让数字仍是主角但避免压迫感
- **影响组件**：
  - `QiuJi/Core/DesignSystem/Typography.swift`（Token 值全面下调）
  - `QiuJi/Features/Training/Views/TrainingHomeView.swift`（卡片标题、序号、issueThumbnail 数字）
  - `QiuJi/Features/Training/Views/PlanDetailView.swift`（statCell 数字、描述 lead）
- **日期**：2026-05-26
- **回写目标**：
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 三 字体系统
  - `tasks/UI-IMPLEMENTATION-SPEC.md` § 1.4 字体 Token + Changelog
- **已应用至**：
  - ✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 三 字体系统（2026-05-26）+ Changelog 节新增
  - ✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § 1.4 字体 Token + § Changelog（2026-05-26）

## PD-006
- **任务**：全局字体密度优化（同 DR-014）
- **模式描述**：**"字体 Token 全局收敛 + 局部用法校准"双层修法**——当出现「页面整体拥挤、字号偏强」反馈时，先做 Token 值下调（保留 token 名称不变以避免大规模重命名），再针对错配场景做 token 替换（如 list 卡片不该用 title2、卡内数字不该用 displaySmall）
- **适用场景**：当设计系统已有完整字体 Token，但截图反馈显示「整体偏重」时；避免简单地把所有 `btTitle2` 全局替换成 `btHeadline`，那样会过度收缩；分两层修法可同时保留 Token 语义又避免单点过度展示
- **代码示例**：
  ```swift
  // 第一层：Token 值下调（保留名称）
  // Typography.swift
  static let btDisplaySmall = Font.system(size: 30, weight: .bold, design: .rounded)  // 36 → 30
  static let btTitle        = Font.system(size: 20, weight: .bold, design: .rounded)  // 22 → 20

  // 第二层：错配场景替换 token（不是降低值）
  // ❌ 错：列表卡片标题用 btTitle2（语义偏强）
  Text(drill.nameZh).font(.btTitle2)
  // ✅ 对：列表卡片标题用 btHeadline（默认列表语义）
  Text(drill.nameZh).font(.btHeadline)

  // ❌ 错：卡片内统计数字用 btDisplaySmall（语义偏强）
  Text("\(value)").font(.btDisplaySmall)
  // ✅ 对：卡片内统计数字用 btStatNumber（明确"卡内大数字"语义）
  Text("\(value)").font(.btStatNumber)
  ```
- **关键约束**：
  1. Token 下调幅度建议单档 4-6pt（48→44、36→30、34→32），避免整体过度收缩
  2. 修法过程中保留 token 名称的语义连续性，避免破坏大量页面代码
  3. 必须同时更新 SKILL.md 和 UI-IMPLEMENTATION-SPEC.md 的 Token 表，否则后续会再次失配
  4. `.system(size:)` 硬编码字体保留场景固定：Canvas/SceneKit、数字键盘、SF Symbol 大小、live monospaced 计时器
- **日期**：2026-05-26
- **回写目标**：
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 三 字体系统「使用原则」
- **已应用至**：
  - ✅ `.cursor/skills/swiftui-design-system/SKILL.md` § 三（2026-05-26，新增四条避坑指引）

## PD-007
- **任务**：QA-P9 验收时补 `AngleSceneCalculator` 往返 XCTest，发现整套 `QiuJiTests` 命令行从未跑通
- **模式描述**：**「PRODUCT_NAME 用 CJK / 与 target 名不同」时，测试宿主与 @testable 模块名的双重修正**。当 App target 名为 `QiuJi` 但 `PRODUCT_NAME = 球迹`（中文）时会出现两个隐藏故障：
  1. `TEST_HOST` 默认按 **target 名** 生成 `$(BUILT_PRODUCTS_DIR)/QiuJi.app/QiuJi`，而真实产物是 `球迹.app/球迹` → `xcodebuild test` 报 `Could not find test host`。
  2. Swift 模块名默认取 `PRODUCT_NAME` 经 sanitize（CJK 被吃掉）→ `@testable import QiuJi` 报 `Unable to find module dependency: 'QiuJi'`。
- **适用场景**：任何 App 显示名用中文/与 target 名不一致、且有单测 `@testable import` 的工程。两处都要显式钉死，缺一不可。
- **代码示例**（`project.yml`）：
  ```yaml
  # App target
  settings:
    base:
      PRODUCT_NAME: 球迹
      PRODUCT_MODULE_NAME: QiuJi        # 模块名钉死，保 @testable import QiuJi 可解析
  # 单测 target
  QiuJiTests:
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/球迹.app/球迹"   # 指向真实产物
        BUNDLE_LOADER: "$(TEST_HOST)"
  ```
- **关键约束**：
  1. 同步改 `QiuJi.xcodeproj/project.pbxproj`（避免每次都得 `make xcodegen`）；`make xcodegen` 会从 `project.yml` 重生成，两边须一致。
  2. cmdline 传 `TEST_HOST=` 是全局的，会污染 `QiuJiUITests`（USES_XCTRUNNER 冲突）；正确做法是写进 target 设置而非命令行覆盖。
  3. 改 `PRODUCT_NAME` 时必须同步 `TEST_HOST` 路径与 `PRODUCT_MODULE_NAME`。
- **效果**：修复后 `xcodebuild test -only-testing:QiuJiTests` 全量 **241/241 通过**（此前命令行从未编译过，历史"235/235"为改名前或 Xcode GUI 跑出）。
- **日期**：2026-06-02
- **回写目标**：
  - `.cursor/rules/60-devops-release.mdc` § 经验教训（构建/测试宿主配置）
- **已应用至**：
  - ✅ `project.yml`（QiuJi.PRODUCT_MODULE_NAME + QiuJiTests.TEST_HOST/BUNDLE_LOADER）+ `QiuJi.xcodeproj/project.pbxproj`（2026-06-02）；待回写 `60-devops-release.mdc`

---

## PD-008
- **任务**：T-P10-A4 动作库内容管线雏形（ADR-P10-01）
- **模式描述**：**「物理引擎作为离线内容烘焙器，以 XCTest 为命令行载体」**。当 App 内已有物理引擎（依赖 SceneKit），需要把它从「运行时消费」扩展为「离线内容管线」（意图→精确轨迹回填 JSON）时，不要新建 SPM 可执行 target（会被迫单独打包 SceneKit 依赖、且无法 `@testable import` 复用 App 类型）。改用一个**烘焙跑测**（`@testable import` App 模块、复用既有 test host）：测试读取内容 → 调引擎门面 → 在控制台 `===BAKE …===` 标记间打印回填用 JSON + 校验报告行，人工拷回内容文件。既得「命令行可引用」，又零额外打包成本，并自带回归断言。
- **适用场景**：任何「App 内算法/引擎需被离线内容生产复用」的场景（轨迹烘焙、坐标预计算、内容物理校验等），尤其当算法依赖 UIKit/SceneKit 等只在 App target 可用的框架时。
- **代码示例**（要点）：
  ```swift
  // 门面：纯函数，值类型进出（ShotBaker.bake(_:surfaceY:) -> BakeResult）
  // 跑测：从 Bundle 读内容 → bake → XCTAssert(feasible) → print 回填 JSON（带标记）
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  print("===BAKE \(id) shot=\(i)==="); print(json); print("===END \(id)===")
  ```
- **关键约束**：
  1. 坐标桥复用既有归一化↔场景映射（`AngleSceneCalculator.normalizedToScene/sceneToNormalized`），不另起坐标空间。
  2. 回填到**现有**渲染字段（此处 `DrillAnimation`）+ 仅追加**可选**元数据（`source`/`generator`），保证渲染层与旧内容零回归。
  3. 力度等作者参数按真实可调诉求选型——本任务按用户要求用**连续 velocity(m/s)** 而非离散枚举（精准走位）。
- **效果**：5 条多类别试点（c001/c002/c005/c014/c024）烘焙 5/5 feasible，`QiuJiTests` 203/203；新增 `ShotIntent.swift`/`ShotBaker.swift`/`DrillBakeRunnerTests.swift`，`DrillContent`/`DrillAnimation` 仅加可选字段。
- **日期**：2026-06-04
- **回写目标**：
  - `.cursor/skills/content-engineering/SKILL.md` § Drill JSON Schema（shotIntent 与烘焙 SOP）
- **已应用至**：
  - ✅ `.cursor/skills/content-engineering/SKILL.md` + `QiuJi/Resources/Drills/schema.md`（2026-06-04，新增 `shotIntent` 章节 + 作者 SOP）；ADR-P10-01 见 `tasks/phases/P10-physics-content-pipeline.md`

## DR-015
- **任务**：动作库 2D 球桌渲染升级（用户驱动 ad-hoc — 反馈「我没看到动作库里改了哪里」「原来的 BTMiniTable 要废弃掉，使用现在真实的 2D 球桌」）
- **原始规范**：动作库网格卡 / `BTDrillThumbnail` / 计划详情迷你台用 `BTMiniTable`（平涂台呢 + 实心扁圆 + 手画虚线）；详情页 / 记录页用 `BTBilliardTable`（木纹观感库边 + Canvas 扁球）。两套观感与角度训练页那套拟真台（`BTAimTableView` feltOnly + `BTRealisticBall`）割裂。
- **调整后**：新建统一拟真渲染器 `BTDrillTableView`——`BTAimTableView` feltOnly 拟真台呢 + `BTRealisticBall` 球体高光 + 烘焙/手画轨迹（圆头圆角虚线）+ 简洁袋口标记 + 目标袋 `btPrimary` 光环。单一组件双模式：`animationProgress == nil` 静态缩略图（球停起点 + 全画轨迹）；`!= nil` 动画/回放（轨迹逐段绘制 + 球随相位移动）。
  - 删除 `BTMiniTable.swift`；`BTBilliardTable` 退化为薄封装委托 `BTDrillTableView`（保留 `animationProgress` 绑定 API，`DrillDetailView`/`DrillRecordView` 零改动）。
  - `TableRender` 常量保留（`BTAngleTestTable` 仍依赖）。
  - 去掉 `BTDrillCard` 的 `BTDrillPreviewPlayer` PNG 帧短路（此前 c005 的烘焙轨迹被旧 PNG 盖住，用户无法看到改动）。
- **原因**：用户明确要废弃粗糙的 BTMiniTable、动作库统一用已认可的拟真 2D 台；之前对木纹库边/皮革袋口那套「low 爆了」，故拟真路线统一走 feltOnly 干净台呢。
- **影响组件**：
  - `QiuJi/Core/Components/BTDrillTableView.swift`（新建，统一渲染器）
  - `QiuJi/Core/Components/BTBilliardTable.swift`（退化为薄封装，保留 `TableRender`）
  - `QiuJi/Core/Components/BTMiniTable.swift`（删除）
  - `QiuJi/Core/Components/BTDrillCard.swift`（网格卡 + `BTDrillThumbnail` 改用 `BTDrillTableView`，去 PNG 短路）
  - `QiuJi/Features/Training/Views/PlanDetailView.swift`（迷你台改用 `BTDrillTableView(showsBalls:false)`）
  - `QiuJiUITests/ScreenshotTourUITests.swift`（新增 `testDrillLibraryOnly` 聚焦截图测试）
- **验证**：`make build` ✅、lint 0、`testDrillLibraryOnly` UI 截图测试通过（网格 + 详情页拟真渲染确认）。
- **日期**：2026-06-04
- **回写目标**：
  - `tasks/UI-IMPLEMENTATION-SPEC.md` § 组件库（BTMiniTable → BTDrillTableView）+ Changelog
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 组件（拟真台 = `BTAimTableView` + `BTRealisticBall` + `BTDrillTableView`）
- **已应用至**：
  - ✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-06-04，DR-015）
- **后续**：被 DR-016 取代（用户进一步明确要 USDZ 真台 2D 顶视那套，而非 SwiftUI 拟真 Canvas）。

## DR-016
- **任务**：动作库 2D 球桌渲染再升级 → 复用角度页「USDZ 真台 2D 顶视」那套（用户驱动：「不要用这种，要用角度页面里的 2D 视角的 usdz 球桌那一套」）
- **原始规范（DR-015）**：动作库网格/详情用 SwiftUI Canvas 拟真渲染器 `BTDrillTableView`（`BTAimTableView` feltOnly + `BTRealisticBall`）。
- **调整后**：统一改用 `AngleTrainingScene`（`TaiQiuZhuo.usdz` 真台 + 抽取球节点 + plain 光照）切正交顶视相机的真渲染：
  - **缩略图（网格卡 / `BTDrillThumbnail` / 计划迷你台）**：**离线烘焙 PNG**。新增 `DrillThumbnailRenderer`（`DrillAnimation` → 配置 2D 顶视场景 + 摆球（放大 1.8×）+ 画烘焙/手画轨迹 → `SCNRenderer` 离屏快照 UIImage）。`DrillThumbnailBakeRunnerTests` 作为命令行烘焙载体，遍历 `index.allDrillIds` 渲染 72/72 PNG 写入 `QiuJi/Resources/DrillThumbnails/<id>.png`。运行时 `BTBakedDrillTable` + `DrillThumbnailStore`（NSCache）秒加载，**零 SceneKit 运行时成本**（不能把 N 个 USDZ 场景塞进可滚动网格——`setupScene()` 每次解析 USDZ 开销大）。
  - **详情页**：**live 场景**。新增 `DrillSceneView` + `DrillSceneController`，复用 `AngleSceneView`（`interactionMode .none`）渲染 USDZ 2D 顶视 + 摆球（放大 1.3×）+ 烘焙轨迹，播放按钮按相位回放母球/目标球沿轨迹运动。
  - **记录页「球台示意」**：改用轻量 `BTBakedDrillTable(drillId:)` 静态烘焙图。
  - **打包**：`patch-pbxproj-folder-refs.py` 新增 `DrillThumbnails` folder ref（D）。
  - **退役**：删除 `BTDrillTableView.swift`（DR-015 产物）；`BTBilliardTable` 整体移除，`BTBilliardTable.swift` 仅保留 `TableRender` 常量（`BTAngleTestTable` 仍依赖）。
- **原因**：DR-015 的 SwiftUI Canvas 拟真台仍与角度页真 USDZ 台观感割裂；用户要求动作库与角度页**同源同观感**。性能约束决定缩略图必须离线烘焙、详情页用单个 live 场景。
- **影响组件**：
  - `QiuJi/Core/Scene/DrillThumbnailRenderer.swift`（新建，离屏烘焙器）
  - `QiuJi/Core/Scene/DrillSceneView.swift`（新建，详情页 live 场景 + 回放）
  - `QiuJi/Core/Components/BTBakedDrillTable.swift`（新建，运行时烘焙图视图 + `DrillThumbnailStore`）
  - `QiuJi/Core/Components/BTDrillTableView.swift`（删除）
  - `QiuJi/Core/Components/BTBilliardTable.swift`（移除 `BTBilliardTable` 视图，仅留 `TableRender`）
  - `QiuJi/Core/Components/BTDrillCard.swift`、`QiuJi/Features/Training/Views/PlanDetailView.swift`、`QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift`、`QiuJi/Features/Training/Views/DrillRecordView.swift`（改用烘焙图 / live 场景）
  - `QiuJiTests/DrillThumbnailBakeRunnerTests.swift`（新建，全量烘焙载体）
  - `QiuJi/Resources/DrillThumbnails/*.png`（72 张烘焙缩略图）
  - `scripts/patch-pbxproj-folder-refs.py`（新增 DrillThumbnails folder ref）
- **验证**：`make build` ✅、lint 0、烘焙 72/72 ✅、`testDrillLibraryOnly` UI 截图测试通过（网格烘焙 PNG + 详情页 live USDZ 2D 顶视确认）。
- **日期**：2026-06-04
- **回写目标**：
  - `tasks/UI-IMPLEMENTATION-SPEC.md` § 组件库（BTDrillTableView → BTBakedDrillTable + DrillSceneView）+ Changelog
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 组件（动作库 2D 台 = 离线烘焙 USDZ PNG + 详情 live 场景）
- **已应用至**：
  - ✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-06-04，DR-016）
- **后续**：轨迹来源被 DR-017 再修正（DR-016 渲染消费的是 `DrillAnimation` 折线——72 条里仅 5 条试点为物理烘焙，其余 67 条仍是手画贝塞尔，故"看着像画的线"）。

## DR-017
- **任务**：动作库轨迹/走位改为物理引擎真算（用户驱动：「现在球的运动轨迹，看起来不是通过物理引擎计算出来的，而是画出来的线，请修正」）
- **原始规范（DR-016）**：缩略图烘焙器 `DrillThumbnailRenderer` 与详情页 `DrillSceneController` 直接消费 `DrillAnimation.cueBall/targetBall.path`（含手画贝塞尔控制点）采样成折线绘制；详情页回放沿该折线 `SCNAction.move` 匀速移动。72 条 Drill 中仅 5 条试点经 `ShotBaker` 物理烘焙，其余 67 条 `path` 仍是历史手画曲线 → 视觉上是"画出来的线"，无减速/吃库/分离角/真实走位。
- **调整后**：渲染与回放统一**以物理引擎 `ShotPredictor` 为轨迹来源**：
  - 新增 `DrillShotResolver`：把一条 Drill 解析为 `ShotInput`——优先用已标注的 `shotIntent`（精确：连续力度+塞+仰角）；缺失时从既有 `DrillAnimation` 反推（母球/目标球摆位+选袋，默认中等力度 3.3 m/s、无塞）。
  - `DrillThumbnailRenderer.render(drill:)`（签名由 `animation:` 改为 `drill:`）：跑 `ShotPredictor.predict`，画 `prediction.cuePath`（白）/`objectPath`（橙）真实折线；`feasible == false` 才退回手画 `DrillAnimation`。72/72 重新烘焙。
  - `DrillSceneController.setup(drill:)`（详情页）：后台 `ShotPredictor.predict` → 主线程画物理轨迹；`play()` 用 `prediction.recorder` + `TrajectoryPlayback` 按**真实模拟逐帧位置**回放（与分离角页同源，含减速/吃库/走位），不可行才退回沿手画折线移动。
- **原因**：物理升级（ADR-P10-01）已建立"意图→引擎→精确轨迹"管线，但渲染层仍消费旧手画 `path`，导致绝大多数 Drill 的画面未体现物理引擎结果。轨迹来源前移到 `ShotPredictor` 后，动作库与分离角页**同一物理引擎同源**。
- **影响组件**：
  - `QiuJi/Core/Physics/DrillShotResolver.swift`（新建，Drill→ShotInput 解析）
  - `QiuJi/Core/Scene/DrillThumbnailRenderer.swift`（改 `render(drill:)`，物理轨迹 + 手画兜底）
  - `QiuJi/Core/Scene/DrillSceneView.swift`（`DrillSceneController` 物理求解 + `TrajectoryPlayback` 回放；`DrillSceneView` 入参 `drill:`）
  - `QiuJi/Features/DrillLibrary/Views/DrillDetailView.swift`（`DrillSceneView(drill:)`）
  - `QiuJiTests/DrillThumbnailBakeRunnerTests.swift`（`render(drill:)`）
  - `QiuJi/Resources/DrillThumbnails/*.png`（72 张物理重烘焙）
- **验证**：`make build` ✅、lint 0、烘焙 72/72 ✅（c001 母球直线进底中袋、c040 切球母球分离 + 目标橙线进右底袋，几何自洽）。
- **遗留**：67 条无 `shotIntent` 的历史 Drill 用默认力度/无塞反推，轨迹是"真物理但非作者原走位意图"；补 `shotIntent` 后即精确还原（后续内容任务）。
- **日期**：2026-06-04
- **回写目标**：
  - `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
  - `.cursor/skills/swiftui-design-system/SKILL.md` § 组件（动作库 2D 台轨迹来源 = `ShotPredictor`）
- **已应用至**：
  - ✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-06-04，DR-017）
- **后续（同日，shotIntent 全量补齐）**：用 8 个 content-engineer 子智能体并行为剩余 67 条 Drill 补 `shotIntent`（按各 Drill 描述/杆法推断 velocity+spin），加上 5 试点 = **72/72 全有 shotIntent**。新增可行性扫描 `DrillThumbnailBakeRunnerTests/test_scanFeasibility`（每条 resolve→predict 打印 feasible/cut/potted）。结果 **67/72 引擎干净落袋**；修正 2 条几何颠倒（c039 选袋反向→改上中袋；c062 水平母球选竖直袋 cut90→母球移到目标正上方）+ 6 条 follow 误推致乱弹（c035/c037/c065/c067/c068/c070 改中心球，c070 加力）。**5 条特殊球路**（c055 翻袋/c057 K球吃库/c058 贴库/c061 解球/c066 开球）单杆直瞄物理模型无法干净进 → c055 退回手画兜底、其余渲染真实物理近失/散球（v1 烘焙器固有限制：不支持翻袋/吃库瞄准；记入 H-11 待物理核查）。72 缩略图按新 shotIntent 全量重烘焙。

## PD-009
- **任务**：P10 Track B-1 物理保真进球管线（ADR-P10-02）
- **模式描述**：**「物理判定用真实结构涌现、不要调大判定圆糊弄；求解器评分量纲一致；先测量证伪假设再改几何」**。可复用纪律：
  1. **真实结构优先于调参**：袋口进/rattle 应由**真实几何**（jaw 库 + 喉腔侧壁/后壁 + 物理落袋孔，`throatCushions`）涌现，而非「把捕获半径调大到能进球」（用户判定后者为偷懒、非真实物理）。先尝试的「放宽捕获半径到 0.055」被用户驳回，改建喉腔结构（穿库飞出 8%→2.7%，rattle 自然产生）。
  2. **分清正向判定(A)与反向求解(B)**：A＝球来时由真实袋口几何决定进/rattle；B＝固定力度+塞采样/寻优最优接触点、在 A 下让球落袋。B 评分调用 A（真实模拟），不另算一套。
  3. **评分量纲纪律**：连续主距离项（米，~0.01–0.1）的附加惩罚（scratch/出界）必须 mm 级（0.002）；误用 1.0 大值会压过主项把求解逼到「啥也不沾的远解」（本任务 45° 切角回归坑）。硬优先级用离散基线（进袋 −10 / 未进 ≥0）。
  4. **测量先于改几何**：把"jaw 错位 17mm"当待证伪命题，先程序化实测（USDZ 网格遍历）核对——实测证明库边/袋心/jaw 自洽，根因实为「袋口缺真实结构 + 求解器坏局部最优」，避免了对正确几何的高风险改动。
- **适用场景**：任何「物理判定 / 模拟+搜索多目标评分」的求解（袋口、瞄准、走位）；任何「报告把现象归因到某处、但改动成本/风险高」的标定任务。
- **关键约束**：
  - 进袋判定用**显示同源的钳制轨迹**最近点（轨迹基），而非裸 pocket 事件（穿库假阳性）；物理**落袋孔半径**与**视觉标记半径**解耦（`*DropRadius` vs `*PocketRadius`）。
- **效果**：真实袋口物理（喉腔模型）下 E-solver 角袋 cut0–45 全力度进、cut55 个别力度敏感、中袋全力度进、c002 转 ✅、`QiuJiTests` 291/291；新增 `PhysicsEngineTests` 3 条保真断言 + `TableGeometryProbeTests` 实测/诊断。
- **日期**：2026-06-04
- **回写目标**：
  - `.cursor/rules/10-ios-architect.mdc` § 经验教训（物理求解器评分量纲 + 测量先于改几何）
- **已应用至**：
  - ✅ `.cursor/rules/10-ios-architect.mdc` § 经验教训（2026-06-04，PD-009）；ADR-P10-02 见 `tasks/phases/P10-physics-content-pipeline.md`

## PD-010
- **任务**：P10 Track B-2 截图诊断驱动的漏斗袋口模型 v3（ADR-P10-03）
- **模式描述**：**「先可视化再优化；真实袋口=jaw 闸口+导球漏斗（非弹珠箱）；求解 sim 与上报 sim 同保真度；直接进袋优先于绕库；噪声景观治几何而非硬刚求解器」**。可复用纪律：
  1. **截图/2D 诊断渲染驱动**：物理「时好时坏、对参数敏感」时，照相级渲染遮几何。用纯 CoreGraphics 2D 顶视接触表（库边/jaw/落袋孔/标记/真实轨迹/进袋判定全可见，`ShotScenarioRenderTests`→`build/shot_probe/*.png`）对多袋口×切角×塞×力度矩阵出图，肉眼 + 偏移扫描定位根因。
  2. **漏斗袋口替代弹珠箱**：高恢复系数喉腔侧/后壁把对准球反复弹射 → 进袋带斑点状碎裂（每 0.1° 翻转）。改为 jaw 库作闸口 + 落袋捕获圆覆盖 jaw mouth + 落袋吸心 → 进袋带连续宽、画面=物理。
  3. **求解=上报同保真度**：搜索 sim 与最终 sim 事件/时间预算一致，否则两进袋带错位致「判进画面不进」。
  4. **粗扫步长 ≤ 进袋带宽**（0.5°→0.2°，带宽实测 0.2–0.4°）。
  5. **直接进袋优先**（`objCushionsBeforePocket` 计入评分），不为躲 scratch 选绕库 banking 解；近全直球如实报「母球进袋（失误）」。
  6. **慢进袋不截断**：显示钳制器有效时长按运动态判定（去 0.02m/s 速度阈值），缓行入袋完整显示。
- **适用场景**：物理引擎/袋口/求解器调试；任何「现象对参数敏感、肉眼说不清」的仿真问题。
- **关键约束**：物理落袋孔半径（角 0.070/中 0.075）与视觉标记半径解耦；落袋吸心使进袋判定与画面同源。
- **效果**：4 张接触表肉眼全部物理自洽（干净直进 + 真实走位 + follow/draw/squirt + 无穿库/碎裂）；`QiuJiTests` 物理套件全绿（Benchmark 14/14 E-solver 5/5、穿库扫描、DrillBake 5/5、新增非单调回归断言）、`make build` 通过、lint 0。
- **日期**：2026-06-04
- **回写目标**：`.cursor/rules/10-ios-architect.mdc` § 经验教训（截图诊断 + 漏斗袋口 + 求解=上报同保真度）
- **已应用至**：
  - ✅ `.cursor/rules/10-ios-architect.mdc` § 经验教训（2026-06-04，PD-010）；ADR-P10-03 见 `tasks/phases/P10-physics-content-pipeline.md`

## DR-018
- **任务**：打点盘真实化（用户驱动：「按真实母球尺寸、皮头尺寸、皮头弧度，相当于按相同比例，不同加塞大小对应真实加塞点，让用户真实感受到加塞多少和母球反应」）。
- **原始规范**：`SpinPadView`（`ShotSimulationView.swift`）把击球点 `spinX/spinY` 约束在**单位圆**内（`mag ≤ 1`），红点是固定 **18pt** UI 手柄（与皮头尺寸无关），`spinX/spinY` ∈ [-1,1] 直接作为 pooltool `a,b`（接触点偏移/R），**允许打到球的赤道边缘 (1.0R)** ——物理上打不出（必 miscue），且满塞 squirt 偏大。打点盘也无皮头/打滑极限的真实比例参照。
- **调整后**：打点盘按真实物理比例重做，`spinX/spinY` 语义不变（接触点/R）但**可拖区域钳到打滑极限 0.5R**：
  1. **统一参数源**（`CuePhysics`）：新增 `tipDiameter=0.011`(11mm 中八皮头)、`tipContactRadius=tipDiameter/2`、`tipCurvatureRadius=0.0105`(nickel)、`miscueLimitFraction=0.5`（满塞≈半个半径，由皮头/巧粉摩擦决定）。删除旧的无用且撞名的 `tipRadius=0.0106`；`CueStick.Constants.tipRadius` 改引用 `CuePhysics.tipContactRadius`（单一来源，3D 杆头也变 11mm）。
  2. **真实比例渲染**：盘面=母球正面；新增**打滑极限虚线圈**（半径 0.5R，圈外打不出）；红色**皮头接触斑**直径 = 皮头/母球真实比例（11/57.15≈0.19）取代固定 18pt，让用户直观看到「一个皮头多大、最多几个皮头」。
  3. **拖动钳到打滑极限**：超出 0.5R 的拖动按比例钳回 0.5R 边界（之前钳到 1.0）。读数 `spinReadout` 改为「占满塞(打滑极限)的百分比」（满塞=100%）。
- **原因**：旧打点盘的「红点中心=接触点、但范围到球边缘、红点尺寸与皮头无关」让用户无法对应真实击球点与加塞反应；按真实皮头/母球比例 + 打滑极限收敛后，加塞量与 squirt/旋转回到真实区间（满塞 squirt≈1.9°，旧版到 1.0R 偏大且不可达）。
- **皮头曲率精确换算（同任务第二步，用户「两个都做，更严谨」）**：接入两球相切几何——`CuePhysics.tipContactPullFactor = R/(R+ρ)`（ρ=`tipCurvatureRadius`=10.5mm，≈0.731）。打点盘现以「用户摆放的**皮头中心**」为操作量，真实接触点 = 皮头中心偏移 × pullFactor（曲率把接触点**拉向球心**，平头趋 0、越圆越接近 1），存入 `spinX/spinY`(pooltool a,b) 喂物理；红色接触斑画在皮头中心、虚线打滑圈画在皮头中心可达边界(0.5R/pullFactor≈0.684R)。
- **shotIntent 内容 miscue 体检 + 守门（同任务第二步）**：扫描全部 Drill `shotIntent`，**4 条** |spin| 幅值 √(x²+y²) 超 0.5R（c004/c017 y=-0.6；c020 (0.5,0.5)=0.707；c021 (-0.5,-0.6)=0.781）→ 按方向等比钳回 0.5R 改 JSON（c004/c017→-0.5；c020→0.35/0.35；c021→-0.32/-0.38）；并在内容→引擎单一入口 `ShotIntent.Shot.shotInput()` 加 `clampToMiscueLimit` 守门（幅值钳到 0.5R、方向不变），保证动作库烘焙/回放与打点盘同一真实约束。4 条缩略图重烘焙。〔`CueBallStrike` 保持 pooltool 忠实、不在物理基元层钳制（其单测用 spin 到 1.0 验数学）；钳制放在意图层（打点盘 + shotInput）。〕
- **影响组件**：
  - `QiuJi/Core/Physics/BTPhysicsConstants.swift`（`CuePhysics` 皮头几何 + 打滑极限 + `tipContactPullFactor` 曲率系数）
  - `QiuJi/Core/Scene/CueStick.swift`（`tipRadius` 引用单一来源）
  - `QiuJi/Features/AngleTraining/Views/ShotSimulationView.swift`（`SpinPadView` 真实比例 + 打滑极限圈 + 皮头接触斑 + 皮头中心→接触点曲率换算 + 钳制；`spinReadout` 百分比基准改打滑极限）
  - `QiuJi/Core/Physics/ShotIntent.swift`（`clampToMiscueLimit` 守门 + `shotInput()` 应用）
  - `QiuJi/Resources/Drills/cueAction/drill_c004|c017|c020|c021.json`（spin 钳到 ≤0.5R）+ `QiuJi/Resources/DrillThumbnails/drill_c004|c017|c020|c021.png`（重烘焙）
  - `QiuJiTests/PhysicsEngineTests.swift`（+`test_miscueLimit_maxEnglishSquirtIsRealistic` / `test_tipCurvature_pullFactorLessThanOne` / `test_clampToMiscueLimit_boundsMagnitudeKeepsDirection`）
- **验证**：`make build` ✅、lint 0、`PhysicsEngineTests` **21/21**（含 miscue 守护 + 曲率系数 + 钳制方向）；4 条违规缩略图重烘焙。
- **遗留**：无（曲率换算 + 内容 miscue 体检均已完成）。物理基元 `CueBallStrike` 仍按 pooltool 忠实（不钳制）——这是有意为之：钳制只在意图层（打点盘 / shotInput）。
- **日期**：2026-06-05
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（打点盘语义：接触点/R，可拖区=打滑极限 0.5R，红点=真实皮头比例）。
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-06-05，DR-018）。
---

## DR-019
- **任务**：图文精讲结构化渲染升级（用户驱动：「精讲的文本样式不太好看」——应用课模板的为什么/怎么打/自检与关键参数被压扁在一段平文本里成字墙）。
- **原始规范**：`TutorialSection` 仅 `title + content + image` 三字段，`DrillTutorialView.sectionCard` 把 content 渲染为单段 `Text`（btCallout，lineSpacing 4），无段落、无列表、无参数展示；配图无图注。
- **调整后**（向后兼容，旧 drill 无新字段照常走旧路径）：
  1. `TutorialSection` 新增可选字段：`items: [TutorialItem]?`（{label, text} 结构化条目）、`params: TutorialShotParams?`（{spinX, spinY, velocity} 本节击球参数）、`caption: String?`（图注）。
  2. `DrillTutorialView` 新渲染：content 按 `\n\n` 分段 + 段内 inline markdown（**加粗**）、lineSpacing 4→5；`items` 渲染为「彩色标签胶囊 + 正文」行（为什么=blue / 怎么打=btPrimary / 自检=orange / 其余中性灰）；`params` 渲染为「`BTSpinMiniIcon`(40pt, trueScale) + 打点读数胶囊 + 力度胶囊」参数行（与导出 HUD 同组件同口径：`SpinDisplay.readout` / `PowerDisplay.name`）；图注 btCaption 灰字。
  3. drill_c042 内容迁移到新结构（逐杆节 items+params+caption，常见错误转 items 列表，平文本节加粗+分段）。
- **原因**：「应用课」精讲模板（ADR-P11-14）的信息是结构化的（原理/操作/检验 + 击球参数），展示层必须有对应容器；参数胶囊与导出 HUD 同源，图文互证。
- **影响组件**：`QiuJi/Data/Services/DrillContentService.swift`（TutorialSection +3 可选字段、新增 TutorialItem/TutorialShotParams）、`QiuJi/Features/DrillLibrary/Views/DrillTutorialView.swift`（paragraphs/itemRow/paramsRow/paramChip + 图注）、`QiuJi/Resources/Drills/positioning/drill_c042.json`（内容迁移）、`QiuJi/Resources/Drills/schema.md`（TutorialSection 字段表）。
- **验证**：`xcodebuild test testDrillC042TutorialDemo` Passed，截图 8 张核验：参数行（打点icon+「高43% · 右1%」+「轻推 · 0.8 m/s」）、三色标签行、常见错误结构化列表、加粗/分段、图注全部正常。lint 0。
- **遗留**：存量 72 个 drill 的「常见错误与纠正」1.2.3. 字符串待批量转 `items`（等用户对 c042 新样式定稿后脚本迁移 + 抽查）。
- **日期**：2026-06-13
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog + `Resources/Drills/schema.md` + `.cursor/skills/content-engineering/SKILL.md`（应用课模板 SOP）。
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-06-13，DR-019）；✅ `Resources/Drills/schema.md` TutorialSection 字段表（2026-06-13）；✅ `.cursor/skills/content-engineering/SKILL.md` §「图文精讲应用课模板」（2026-06-13，含序列→drill 接入清单 + 媒体落位表 + 红线）。

## DR-020
- **任务**：「角度」Tab 改名「练习」+ 首页布局改为动作库同款（用户驱动：「将角度的页面布局修改为类似于动作库的那种布局和样式吧，而且感觉现在叫角度有点不合适了」；名字用户拍板「练习」）。
- **原始规范**：Tab 名「角度」（icon `angle`）；`AngleHomeView` 为 ADR-P18-01 的「大标题 + `BTSegmentedTab` 四分段（学/练/打/解）+ 双列海报卡（`AnglePosterCard`：渐变全幅 + 大字水印 + 底部白字标题）」，一次只见一个分段。
- **调整后**：
  1. **Tab 改名**：`AppTab.angle` title「角度」→「练习」，icon `angle`→`scope`（瞄准准星，贴合练习定位）；枚举 case / 路由 / 代码标识符不动（英文标识符纪律，改名只动用户可见字符串）。
  2. **布局对齐动作库 `DrillListView`**：左侧 76pt 图标分类侧栏（全部 + 学/练/打/解，选中=btPrimary + 左侧 3pt 竖条 + btBG 底）+ 右侧双列分组网格（`LazyVStack` pinned section headers，分组头=filled 图标 + 单字分类名 + 灰字说明）；默认「全部」纵览四分组。四分类 IA（ADR-P18-01）不变，仅呈现方式变。
  3. **卡片对齐 `BTDrillGridCard` 上图下文式**：新 `AngleGridCard`——封面区 4:3 保留渐变 + 大字水印 + 右上 chip；底部 btBGSecondary 白底区放标题（btHeadline）/ 副标题（btCaption，`minimumScaleFactor 0.65` 防截断）；Dark 0.5pt 描边、Light 阴影，与动作库网格卡同规格。
  4. **AX 兼容**：侧栏项沿用 `angleHomeTab_<label>` 标识 ⇒ `P5_AngleTrainingUITests` / `ScreenshotTourUITests` 分段选择器零改动；仅同步 Tab 名相关三处（`XCUIApplication.Tab.angle`、P2 tab 巡检列表、P5 标题断言）。
  5. **搜索框（同日追加，用户驱动「加个搜索框吧」）**：大标题下增动作库同款搜索框（占位「搜索练习」，btBGTertiary 圆角 + 放大镜 + 非空时 xmark 清除）；搜索按标题/副标题大小写不敏感匹配，跨分组过滤且只保留有命中的分组（分组头保留以标示归属）；无命中显示 `BTEmptyState`（「没有找到相关练习」+「浏览全部练习」清空动作）。新增 UI 测试 `testSearchFiltersEntries` / `testSearchEmptyState`。
- **原因**：页面早已不止「角度」（物理沙盘/反解工具/球理知识），命名失准；分段 Tab 一次只见一段，侧栏+分组网格可纵览全部入口且与动作库形成一致的「浏览型页面」语言。
- **影响组件**：`QiuJi/App/AppRouter.swift`（title/icon）、`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift`（重写：`PracticeSection` 枚举 + 侧栏 + 分组网格 + `AngleGridCard`，删 `BTSegmentedTab` 用法与 `AnglePosterCard`）、`QiuJiUITests/{Helpers/XCUIApplication+Extensions,P2_DataLayerUITests,P5_AngleTrainingUITests}.swift`。
- **验证**：`make build` ✅；`P5_AngleTrainingUITests` 8/8 + `ScreenshotTourUITests/testUnifiedDesignPages` 全绿（9 tests, 0 failures）；UI 美观性验收：明/暗 × 全部/学/练/打/解 截图逐张核验（发现暗色副标题「随开随练」截断 → minimumScaleFactor 0.8→0.65 修复后复跑复验通过）。搜索框追加后：build ✅ + 新增 2 条搜索 UI 测试全绿（2 tests, 0 failures），空闲/命中/空态三张截图核验通过。
- **遗留**：截图导览产物名仍带 `angle-home` 前缀（内部命名，不影响用户）；「记录」日历标记 `"角度"`（指角度测验会话，语义仍准确）未随 Tab 改名。
- **日期**：2026-07-03
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog。
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-07-03，DR-020）。

## PD-028
- **任务**：问题集合 v29 W9 不变量补全与门禁（2026-08-07）——把 C1–C4 + 新增 I5/I7/I8/I9 接成 git `pre-push` 阻塞门禁，同时消化「存量偏差未收敛，门禁却要立刻生效」这一矛盾。
- **模式描述**：**「棘轮豁免 + 影子库构造性用例」——给存量债接门禁的标准做法**：
  1. **棘轮豁免（ratchet exemption）**：存量偏差不能靠放宽判定放过去，也不能等它清零再接门禁。做法是把豁免写成机读清单（本轮 `scripts/content_invariant_baselines.json`），**并钉到最小粒度**（具体 token / formation id / 计数），而不是「整个 drill 免检」。这样存量条目照常放行，同一对象出现的**新**偏差立刻 FAIL。清单只许缩短、计数只许下调，每条豁免在契约 §8 有解除条件，检查项发现某条豁免已可解除时主动提示删除。
  2. **影子库构造性用例**：新增检查项极易写成永远 PASS 的空壳。做法是给校验脚本加 `--root` 使全部内容目录可重基，用例在 `build/*-fixtures/<case>/` 用「小目录真副本 + 大目录符号链接」搭影子内容库（本轮 DrillTutorials 4.7G / export 8.5G 只能链），在副本上制造一处不一致后断言退出码与输出片段，真源全程只读、零污染。同时必须有一条**对照组**（未改动的影子库 → 退出码 0），否则用例可能只是在测「脚本总是报错」。
  3. **豁免与阻塞分层**：根因需要另一条工作流才能消化的检查（本轮 C4 精讲重写归 v26）降级为「已知豁免、不阻塞 push」，但默认模式仍计入退出码——降级只发生在门禁入口（`--gate`），不改判定本身。
- **适用场景**：任何要给存量债接 CI / pre-push 门禁的场合（内容校验、lint 迁移、类型检查分批开启）；任何新增静态检查项。
- **效果**：`make invariant-selftest` 9/9 用例符合预期；`make verify-gate` 在故意制造的 I8 孤儿产物 + I9 无序列登记上拦下 `git push`（FAIL 2），还原后放行；真实内容库门禁终态 FAIL 0（C4 的 23 项为已知豁免）。
- **日期**：2026-08-07
- **回写目标**：`.cursor/rules/40-content-engineer.mdc` § 经验教训。
- **已应用至**：✅ `.cursor/rules/40-content-engineer.mdc` § 经验教训（2026-08-07，PD-028）

## PD-027
- **任务**：问题集合 v29 主控审核（2026-08-06）——方案放行前的锚点核验暴露两类可复用的方案级缺陷。
- **模式描述**：**「方案审核两问：①完成标准含『全量测试零 diff』时，先盘点全部写盘测试；②方案要改/删某断言时，先验证断言前提」**：
  1. **写盘测试盘点**：v29 W1 原文只 gate 了 `DrillThumbnailBakeRunnerTests` 一处，实际 `V21W2/3/4BakeTests` 同样无 gate、写 PNG 且改写 git 跟踪的 drill JSON——按原范围执行，完成标准「全量测试零 diff」必然失败。盘点方法：`rg -l "\.write\(|FileManager.*create" <TestTarget>/` 列全写盘用例 + 查 scheme/testplan 确认默认执行集，再定 gate 范围。
  2. **断言前提验证（FL-027 的方案层延伸）**：v29 原文断定 `XCTAssertNil(session.planId)`「固化缺陷、新功能落地后必然失败」并计划删除——实读该测试是裸构造的默认值断言，新功能不改默认构造，断言不会失败；照原方案删它反而构成「删断言求绿」。FL-027 管实现期，本条把同一纪律前移到**方案撰写/审核期**：任何「改/删断言」子任务必须附断言原文与失败机理。
- **适用场景**：`issue-collection-restructure` 产出的批次方案审核；任何完成标准依赖「测试后工作区干净」的批次；任何含「修正/删除既有断言」的批次。
- **代码示例**：（方案审核为文档动作，无代码；盘点命令见上）
- **日期**：2026-08-06
- **回写目标**：`.cursor/skills/issue-collection-restructure/SKILL.md` § 经验教训。
- **已应用至**：✅ `.cursor/skills/issue-collection-restructure/SKILL.md` § 经验教训（2026-08-06，PD-027）

## PD-026
- **任务**：B4 drill_c053 中袋角度 8 球形落地——精讲/试打 UI 截图核验时暴露两个既有 SwiftUI 渲染缺陷（c012/c042 亦复现，非 B4 内容问题）。
- **模式描述**：**「跨数据源切换的 Lazy 容器行要复合 id；sheet 内容依赖动作时刻的 state 就用 sheet(item:)」**：
  1. **LazyVStack + `ForEach(id: \.offset)` 跨数据源切换不重建行**：精讲 formations 分段切换后正文仍显示旧球形内容——Lazy 容器按 offset 复用已实例化行，外层 `.id(selection)` 不足以强制重建。修法：行级复合 id（`.id("\(selection)-\(index)")`）。
  2. **`.sheet(isPresented:)` 内容闭包以陈旧 state 求值（iOS 26 复现）**：动作里先写 `@State` 数组再置 `isPresented=true`，sheet 呈现时列表渲染为空。修法：改 `.sheet(item:)`，用 `Identifiable` payload 携带数据快照，内容闭包从 payload 取数。
- **适用场景**：任何「分段/Tab 切换驱动 Lazy 列表换内容」的视图；任何「点击动作先算数据再弹 sheet」的流程。
- **效果**：drill_c053 精讲 A1→A5→A8 分段切换正文正确刷新；试打球形选择 sheet 8 项完整渲染（含 c042 回归 `testTryoutC042Flow` 通过）。
- **日期**：2026-07-16
- **回写目标**：`.cursor/rules/20-swiftui-developer.mdc` § 经验教训。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训（2026-07-16，PD-026）

## PD-025
- **任务**：P10 真实袋口重建（ADR-P10-09）——CAD 单一真源 + 「球心入孔圈即落袋」纯几何判据。
- **模式描述**：**「收紧宽容判据前先审计它掩盖了什么；CCD 数值护栏必须与子步策略匹配」**。可复用纪律：
  1. **宽容判据是缺陷掩体**：大捕获圆/速度阈值/settle 特判这类「宽容判据」会长期掩盖底层求解器缺陷（本轮：QuarticSolver 近双二次塌缩漏根、弧 CCD `epsilon=1e-4` 拒真根）。收紧判据时**必须预期暴露存量缺陷**，把「判据收紧后新出现的失败」优先当作被掩盖的旧 bug 排查，而不是回退判据。
  2. **CCD 时间下限 epsilon 与自适应子步耦合**：高保真近墙子步会把球渐进逼近到碰撞前 ~1e-5s 量级，任何「拒绝过小碰撞时间」的护栏（防重复检出）下限必须远小于最小子步余量（本轮统一 1e-6，与直线库对齐）；重复检出应由逼近方向检查（v·n）防护，而非放大时间下限。
  3. **求根器塌缩要有播种兜底**：解析求根（Ferrari）在退化邻域（近双二次、大项浮点抵消）会漏根；用退化形式的近似根播种 + Newton-Raphson 抛光兜底，并与外部权威（numpy roots）全范围比对验证。
  4. **判据变更后的测试失败三分**：①被掩盖的旧引擎 bug（修引擎）；②真实物理的合法新结局（如 65° 大切角双吻——改断言口径，需轨迹诊断确证）；③混沌区求解器容差放大（加敏感度自测门，平缓区仍强断言）。禁止不分类直接改断言。
  5. **物理真源与视觉标记分离**：CAD 孔心供物理/瞄准（`pocketPositions`），USDZ 视觉袋心仅供标记/点选（`pocketMarkerPositions`），两者禁止互串。
- **适用场景**：任何收紧几何/物理判据的重构；CCD/求根器数值调试；仿真测试失败归因。
- **效果**：矩阵出界 9→0；`PhysicsEngineTests` 含 3 个历史失败一并转绿；新增 3 条落袋不变量护栏。
- **日期**：2026-07-02
- **回写目标**：`.cursor/skills/geometry-spatial-reasoning/SKILL.md` § 经验教训。
- **已应用至**：✅ `.cursor/skills/geometry-spatial-reasoning/SKILL.md` § 经验教训（2026-07-02，PD-025）

## DR-024
- **任务**：问题集合 v8 X1 / K4（D-v8-4）— 3D 场景每题进场机位契约变更。
- **原始规范**：v5 Q5/Q9：`CameraRig.enterAiming` 每题进场目标恒 `zoom=1`（stand 远景，站立观察上界），用户可竖滑压低。
- **调整后**：`enterAiming` 目标改为**确定性近景 `zoom=0`**（aim 梯：`minRadius`/`minHeight`/`aimPitch`/`aimFov`）；竖滑/捏合仍可在 `[0,1]` 调整。配套修复：`SceneAimingView.onChange(questionIndex)` defer 到下一 runloop（`DispatchQueue.main.async`），消除 `advanceToNext` 先改 index、`nextQuestion()` 尚未 `applyBallLayout` 时 `cueBallNode==nil` 早退不复位的竞态；`AimPointSceneTrainingView` 同源同修。
- **原因**：v5 契约叠加早退路径与 0.6s smoothToPose 竞态后，同页表现为「有的题正常（保住上一题近景）/ 有的特别远（成功拉到 zoom=1）」忽近忽远 bug（用户 D-v8-4 澄清）。取证文档 `build/x1-evidence/k4-reproduce-path.md`（路径 A ENTER→远 / 路径 B EARLY_RETURN→近）。
- **影响组件**：`CameraRig.enterAiming`、`SceneAimingView`、`AimPointSceneTrainingView`；`AimingCameraConfig` zoom 梯定义未动。
- **验证**：`X1_CameraAndAngleArcTests` 3/0（`entryZoom=0.00 prevZoom=1.00` 日志断言）；连续 5 题进场截图机位一致（`build/x1-screenshots/k4-q01..05`，MD5 互异证非同帧）。
- **日期**：2026-07-17
- **回写目标**：`问题集合_v8.md` K4 条目（真源）；v5 相关注释已在 `CameraRig.swift` 代码内更新。
- **已应用至**：✅ `CameraRig.swift` 代码注释（2026-07-17，DR-024）；✅ `问题集合_v8.md` 波1 状态行。

## DR-023
- **任务**：问题集合 v7 W3 / G22 — 动效与设计 token 收编（C19/C20/C21）。
- **调整后**：
  1. **`BTMotion` 新 token**（值=原字面量，禁止调参）：`springLayout`（0.35/0.75）、`easeInOutFast`（easeInOut 0.2）、`easeInOutChrome`（easeInOut 0.25）、`easeInstant`（easeOut 0.12）、`easePress`（easeInOut 0.1）；既有 `springPanel`/`easeFast`/`easeChrome` 消费点扫齐。
  2. **`AngleCoverPalette`**：练习首页 40 处封面 `Color(red:)` → 常量组（明暗同值，不发明 Dark 变体）。
  3. **Typography**：`btCoverWatermark` / `btHeroSymbol` / `btCTALabelRounded`。
  4. **HUD**：`HUDStyle.metricSeparatorHeight=12` + `BTHudMetricSeparator`（D5）；`BTDailyLimitGate` 字号 token 化。
  5. **SPEC 红线（D6）**：新代码禁止新增字面量字号；全量迁移不入本轮。
- **留档豁免（低频独特）**：`easeInOut(0.35).delay(0.6)` Composer brief；`easeInOut(0.3)` Onboarding；`easeOut(0.08)` NumericKeypadHUD；`easeInOut(0.83).repeatForever` BTPlanWeekTimeline；`easeInOut(1.5).repeatForever` BTFloatingIndicator。
- **影响组件**：`BTMotion`、`AngleCoverPalette`、`Typography`、`HUDStyle`/`BTHudMetricSeparator`、`BTDailyLimitGate`、练习首页与各页动画消费点。
- **验证**：`make build`；`QiuJiTests`；grep 已登记字面量仅剩 `BTMotion.swift` 定义；首页 Light/Dark 截图 `build/w3-screenshots/`。
- **日期**：2026-07-16
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §1.4 + Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` Changelog。
- **已应用至**：✅ SPEC §1.4 红线 + Changelog（2026-07-16，DR-023）；✅ `swiftui-design-system/SKILL.md` Changelog。

## DR-022
- **任务**：问题集合 v7 W2 / G20 — `BTSolverNavStatus` 支持无副行简化形态（暗色测验页）。
- **原始 API**：`statusText: String`（必填）+ `isBusy`；副行始终渲染。
- **调整后**：`statusText: String? = nil`；`nil` 且非 busy 时仅显品牌绿标题（组件同源，禁止页内另写 `navStatus`）。
- **原因**：五暗色测验页无状态副行，强塞空串仍占副行高度；G20 允许简化变体但须组件同源。
- **影响组件**：`BTSolverNavStatus`（`BTShotPageChrome.swift`）；既有传 `String` 的沙盘/解球页兼容（隐式升为 `String?`）。
- **验证**：`make build` ✅；暗色五页截图 `build/w2-screenshots/` 导航黑底+绿标题；`private var navStatus` = 0。
- **日期**：2026-07-16
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §8.3 + Changelog。
- **已应用至**：✅ SPEC §8.3 / Changelog（2026-07-16，DR-022）。

## DR-021
- **任务**：B3.5 线语言修正——90° 分离角释义线锚点与颜色（用户裁决：「90 度分离角是针对母球的，相当于是穿过假想球的球心，不是目标球；颜色也要换，不然会和母球的轨迹线重合」）。
- **原始规范**：设计稿 v4 §1.2 / T-P18-41 落地：90° 释义线 = **白**短虚线；`AngleTrainingScene.perpLineNode` 与分离角页 `drawPottingPerpendicular` 均锚在**目标球球心**、垂直于进球线。
- **调整后**：
  1. **锚点 = 假想球球心**（母球碰撞瞬间位置）：90° 法则讲的是母球碰后沿切线离开，切线过碰撞瞬间的母球球心。`updatePerpLine` 签名加 `ghost:` 参数；`drawPottingPerpendicular` 改锚 `p.firstContact ?? p.ghost`；`addSeparationAngleLine` 原本就锚 `firstContact ?? ghost` 不动。
  2. **颜色 = 品牌绿短虚线**（`TrajectoryStyle.separationColor` token 单点换色，全部消费方自动生效）：定杆时该线与母球白色轨迹线**共线重合**，白色无法区分；绿与假想球圈/接触点/角度弧同「教学标注」家族，语义自洽（线过绿圈圆心）。
- **原因**：物理语义错误（锚错球）+ 白色与瞄准线/母球轨迹冲突（定杆场景完全重合不可辨）。
- **影响组件**：`TrajectoryStyle.separationColor`（PoolBallFace.swift）、`AngleTrainingScene`（perpLineNode 注释/`updatePerpLine(ghost:targetBall:pocket:)`/`separationLineColor` 注释）、`ShotSimulationViewModel.drawPottingPerpendicular`、设计稿 v4 §1.2 行同步。
- **验证**：`make build` ✅；`testB3PlusGate` + `testB2ShotControls` 复跑 TEST SUCCEEDED；b3p-06 与 b2-01 裁剪核验——绿短虚线过假想球绿圈圆心、垂直于进球线，与母球白轨迹可辨。
- **日期**：2026-07-05
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog；设计稿 `docs/research/20260704-练习Tab功能契约梳理.md` §1.2。
- **已应用至**：✅ 设计稿 §1.2 行（2026-07-05）；✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-07-05，DR-021）。
