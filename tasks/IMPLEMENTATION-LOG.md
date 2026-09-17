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

## FL-038
- **任务**：问题集合 v51 W5 模拟器矩阵可信性收口。
- **现象**：Light 目录可能被 App 持久外观偏好渲染成 Dark；源码/selector 漂移后的旧绿叶子和并发摘要可能污染最终统计；多 Booted 设备引发 AX/tap 假阴性。
- **根因**：系统设置、App 最终渲染和证据指纹没有形成同一闭环；旧叶子采用覆盖策略且摘要无锁；模拟器资源没有按主机承载能力限流。
- **解决**：巡游用 `-v51.followSystemAppearance` 穿透所有软重启并做像素亮度核验；指纹纳入 selector 文件；旧叶子归档、摘要加锁并从有效单元重建；最终按最多两台 Booted、单 worker 运行。最终指纹下 A/B/C/AX 与双 Runtime 安全回归全绿。
- **日期**：2026-09-04
- **回写目标**：`.cursor/skills/simulator-matrix-qa/SKILL.md`
- **已应用至**：✅ 技能、矩阵执行器、巡游入口、RootView 测试外观边界与 v51 最终报告（2026-09-04）。

---

## DR 记录（设计调整）

## DR-083
- **任务**：问题集合 v56 W0 — 全 App 色彩语义与 Premium 生成材质契约。
- **原始规范**：DR-043 将筛选 Chip 锁定为 Light 黑底白字 / Dark 白底黑字，并以单一 `btAccent` 同时承担 Pro、warning、收藏、图表、教学、HUD 与品牌装饰；Pro 入口使用纯橙黄金色。
- **调整后**：品牌绿 Light `#1A6B3C` / Dark `#25A25A` 不改色相；导航、筛选、主操作按三级强度表达。筛选跨外观统一为 `btPrimaryMuted` 弱绿表面 + `btPrimary` 字/边框，明确覆盖 DR-043 的反相规则。Pro 拆为 `btPremiumForeground` / `btPremiumSurface` / `btPremiumBorder`，保留 `star.fill` / `crown.fill` SF Symbol mask；≥24pt 可用细拉丝香槟金材质，小尺寸、增强对比度或材质不可用时回退纯色。Pro 文字始终纯色；warning、success、chart、physics 不再借 Premium。Apple 登录、固定暗场 HUD、彩球/轨迹与 `BTBrandLogo` 保持例外。
- **原因**：全量 Light/Dark 截图显示，基础品牌绿并非问题；杂乱来自同一状态多套选中色，以及 `btAccent` 一色多义。用户同时确认“保留原样式，只换更有质感的生成金色”，因此生成结果只能提供材质，不得决定图标轮廓。
- **影响组件**：`Colors`、`BTFilterChip`、`BTTogglePillGroup`、`BTButton.goldFilled`、`BTPremiumLock`、`BTProBadge`、`BTIconBadge`、Profile / Subscription 入口；教学与暗场只做语义归类。
- **日期**：2026-09-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §1.1a / §2.4b / §2.6 / §6.3 / Changelog；`docs/research/20260904-v56-color-semantic-ledger.md`。
- **已应用至**：✅ 上述规范与台账；✅ 生产 token、共享筛选/切换、Premium mask、Profile/Subscription、warning/teaching/physics/data 语义及暗场 Chrome（2026-09-04）。

## FL-040
- **任务**：问题集合 v57 W2 — Simulator 手动补验与 XCTest 焦点干扰。
- **现象**：标准手机测试中动作选择面板在已检测到行后消失，6 项中 1 项失败。
- **根因/边界**：主控试图切换另一 UDID 的窗口，但 Xcode 切换了 Simulator 前台；同一时段有 Escape/窗口快捷键。录像与 AX 证明弹层消失，强烈怀疑共享焦点干扰，未把因果推测当作产品缺陷。
- **解决**：停止手动 UI 控制、关闭补验 iPad；原失败测试在相同源码下隔离通过（56.813 秒，exit 0），随后重跑完整单元。证据见 FAILURE-LOG FL-040 与 output/v57/W2/phone-free-isolated.log。
- **日期**：2026-09-05
- **回写目标**：`.cursor/rules/55-test-engineer.mdc` §经验教训 / Changelog。
- **已应用至**：✅ `.cursor/rules/55-test-engineer.mdc` v0.5；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## FL-039
- **任务**：问题集合 v57 W2 — iPad 自由训练动作选择。
- **现象**：iPad 的动作选择行点击中间留白时不切换选择，完成按钮一直无数量；标准手机同一流程通过。
- **严重程度**：P2
- **根因**：`DrillPickerSheet` 使用 `.plain` Button，标签 HStack 的透明 Spacer 未声明矩形命中区。iPad 行为 580pt 宽，中心 x=516pt 落在标题结束 x=453.5pt 右侧的留白；默认命中不覆盖该处。初次测试的宽泛“添加”前缀还可能匹配弹窗外操作，改为明确动作名后仍复现，因而没有把产品缺陷归咎于测试。
- **解决**：在标签完整行上增加 `.contentShape(Rectangle())`，保留行中心点击与选择数量断言。失败 iPad 上“添加→保存→再次开始”和“最小化→恢复原选择”两项均通过，日志 `output/v57/W2/ipad-picker-fix.log`；相邻尺寸与完整矩阵正在复验。
- **证据**：`output/v57/W2/matrix/ios26-ipad-light-r2` 的 AX 树/录像；`output/v57/W2/ipad-picker-before.png`；修复后 8 张流程图在 `output/v57/W2/ipad-picker-fix/attachments`。
- **日期**：2026-09-05
- **回写目标**：`.cursor/rules/20-swiftui-developer.mdc` §经验教训 / Changelog。
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` v1.7、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-05）。

## DR-085
- **任务**：问题集合 v57 W2 — 首页三源展示、完成态入口与官方计划状态。
- **原始规范**：DR-082 完成后用庆祝替换数量；官方卡缺当前/保留进度状态；模版主体点击直接加入今日。
- **调整后**：完成数/总数与预计或记录用时持续显示；已加入课块与未加入建议明确分开；完成态右下「自由训练」直接打开选择动作，保存后可再次开始空白训练。`BTPlanActivationBadge(status:)` 区分进行中、已激活、已完成。模版主体为编辑按钮，加入操作留在独立三点菜单。筛选/Tab 保持真实 offset，短结果补足 UIKit 可滚动范围，详情返回仍恢复对应卡片。
- **原因**：落实用户 R01/R03/R05/R06/R15 的明确反馈；状态与历史事实不可用空态替代。iOS 26 实测仅 SwiftUI 几何高度补偿仍漂移约 201pt，改用宿主 UIScrollView 的实际 offset、bounds 和 adjustedContentInset 后，聚焦切换通过 ≤2pt 断言。
- **影响组件**：`TrainingHomeView`、`PlanListView`、`BTPlanActivationBadge`。
- **日期**：2026-09-05
- **验证边界**：标准手机九种状态、自主训练保存再开始与筛选位置已通过；模版双入口回归和多尺寸/外观/字体矩阵仍在进行，W2 未全量验收。
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3 训练计划封面 / Changelog。
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` 组件定义和 Changelog（2026-09-05）。

## DR-084
- **任务**：问题集合 v56 W4/W7 — Light 页面内固定炭黑 Pro 表面的前景对比修正。
- **原始规范**：`btPremiumForeground` 按全局 Light/Dark 动态切换；Light 值 `#8C6B2F` 对白底可读，但同一 Light 页面内的固定 `#1C1C1E` Pro 卡与 badge 也会取得该深金，实测对比仅约 `3.45:1`。
- **调整后**：保留 `btPremiumForeground` 供随页面外观变化的普通表面；新增固定浅香槟 `btPremiumOnDark = #E7D3A0`，只用于始终为炭黑/黑色的 Pro 卡、badge 与其 CTA 前景，对 `#1C1C1E` 约 `11.52:1`。不改变品牌绿、不扩大金色面积。
- **原因**：组件自身表面可能与页面全局 color scheme 不同；语义动态色不能仅按页面外观推断局部背景。
- **影响组件**：`BTProBadge`、`ProfileView` Pro 卡/CTA、`PlanDetailView` Pro tag。
- **日期**：2026-09-04
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §1.1a / Changelog；`tasks/ui-reviews/UR-20260904-v56-color-implementation.md`。
- **已应用至**：✅ Asset Catalog、组件消费点、Light/Dark/高对比截图与本报告（2026-09-04）。

## DR-082
- **任务**：训练首页本周训练与今日安排信息分层
- **原始规范**：本周训练使用一张品牌绿四列统计卡，同时展示本周训练、连续训练、今日训练和预计用时；周数据与日数据混在同一视觉层级，今日动作标题右侧只显示项目数或完成庆祝。
- **调整后**：本周训练改为独立白色周进度卡，上行仅显示本周完成天数与连续天数，下行按周一至周日展示真实训练日期勾选并高亮今天；今日训练与预计用时移到「今日安排」标题右侧，仅在今日未完成时显示，全部完成后切回庆祝标志。周统计数字与轨迹统一以周一为起点。
- **原因**：周目标、连续性和逐日轨迹属于周维度；完成数与预计用时属于当天任务维度。按时间尺度拆分后，用户不需要在同一卡片里辨认两套上下文，官方计划也能更早进入首屏。
- **影响组件**：`TrainingHomeView.weeklyProgressCard`、`todayTrainingSection`
- **日期**：2026-08-31
- **回写目标**：`.cursor/skills/swiftui-design-system/SKILL.md` / `tasks/UI-IMPLEMENTATION-SPEC.md`
- **已应用至**：✅ `.cursor/skills/swiftui-design-system/SKILL.md` Changelog；✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-08-31）

## DR-081
- **任务**：训练计划 / 练习封面去掉叠字
- **原始规范**：卡面静物图上再叠主题水印（入门 / 准度 / 控力 / 练习两字）+ 计划「第 N 期」+ 练习 01 编号与类型 chip。
- **调整后**：封面去掉主题水印（入门 / 准度 / 控力）与练习 chip。编号保留：计划列表「第 N 期」、练习卡左上 01、模版缩略图序号。卡下标题仍由 `BTContentGridCard` 承担识别。`PlanCoverLabel` 映射保留作数据，不上屏。
- **原因**：用户要看完整生成图，不要封面上的「入门 / 准度 / 控力」类字。
- **影响组件**：`BTPlanCover`、`AngleGridCard`、`CustomPlanThumbnail`
- **日期**：2026-08-30
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c / Changelog；`.cursor/skills/swiftui-design-system/SKILL.md`；`20-swiftui-developer.mdc` Changelog
- **已应用至**：✅ 同日回写上述三处

## DR-080
- **任务**：问题集合 v46 W0 — 一卡一真实静物、去彩色罩
- **原始规范**：v45 六母题 `AtmosphereKey` + `CoverPalette` 色罩（`opacity 0.58`）铺官方/练习/模版封面；水印对照罩色 `top`。
- **调整后**：
  1. `AtmosphereKey` 仍 6 个 `felt*`，只给 Tab 矮顶带（可留色罩）。
  2. 新增 `CoverArtKey`（60）+ `AtmosphereImage`；官方/练习/模版走 `coverArt` / `image`，缺图回退渐变。
  3. `BTAtmosphereLayer`：`showsColorWash`（Tab 默认 true）、`showsNeutralScrim`（卡片 0.12 黑）。卡/hero/模版关色罩。
  4. `CustomPlanAtmosphere.art(for:)` hash 到 `templatePool` 12 张，禁止再读 `AtmosphereKey.allCases`。
  5. `CoverPaletteContrastTests` 只守色板 token / Tab 罩路径，不再要求卡面水印对照彩色罩 `top`。
- **原因**：用户要看完整照片，不要绿/蓝/棕膜。
- **影响组件**：`AtmosphereCatalog`、`CoverArtKey`、`BTAtmosphereLayer`、`BTPlanCover`、`AngleGridCard`、`CustomPlanAtmosphere`
- **日期**：2026-08-29
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §2.3c / Changelog；`.cursor/skills/swiftui-design-system/SKILL.md`；`20-swiftui-developer.mdc` Changelog
- **已应用至**：✅ 同日回写上述三处

## DR-079
- **任务**：训练结束「生成分享图」同时落库 + 分享卡浅色背景
- **原始规范**：总结页「保存训练」与「生成分享图」分立；`ShareCardTheme` 四档（炭灰/黑白/暗夜蓝/深紫）全是深底，默认炭灰；卡内文色写死 `.white`；选择器标签「颜色」、色圈只画 accent。
- **调整后**：
  1. 点「生成分享图」（含顶栏图标）先 `persistIfNeeded()` 再出分享页；已保存则幂等。`saveTraining` 见 `didSaveSuccessfully` 直接返回，禁止二次 insert / 二次推进计划。保存钮在已落后改「完成」。
  2. `ShareCardTheme` 增 `paper`（浅色），排第一且为默认。文色走 `primaryText` 等，禁止卡内再写死白字。选择器改标「背景」，色圈 = 底色 + 强调色芯。
- **原因**：用户要分享时一并保存；四个主题全深底，看起来像没有背景选项。
- **影响组件**：`ShareCardTheme`、`BTShareCard`、`TrainingShareView`、`TrainingSummaryView`、`ActiveTrainingViewModel.saveTraining`
- **日期**：2026-08-27
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog / §2.14 / §6.4；`.cursor/skills/swiftui-design-system/SKILL.md`；`20-swiftui-developer.mdc` Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` §2.14 / §6.4 / Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` Changelog；`.cursor/rules/20-swiftui-developer.mdc` Changelog v1.4（2026-08-27）

## DR-078
- **任务**：动作库类别短名 + 官方计划货架改教学序
- **原始规范**：`DrillCategory.nameZh` 为「基础功 / 准度训练 / 杆法训练 / 走位训练 / 控力训练」；`PlanListView.groupedPlans` 按 `targetLevel` 分节（DR-072）
- **调整后**：
  1. 动作库展示名改为「基础 / 准度 / 杆法 / 走位 / 控力」。enum rawValue 与 JSON `category` 不动。分离角 / 特殊球路 / 综合球形未改。
  2. 货架顺序以 `Plans/index.json` 为真源：基本功 → 准度Ⅰ → 准度Ⅱ → 力度 → 杆法Ⅰ → 杆法Ⅱ → 准度Ⅲ → 分离角 → 走位Ⅰ → 走位Ⅱ → 特殊球 → 全能精选。`PlanListView` 取消档位分节，单节「官方计划」按 index 序排；训练首页本就走 `loadAllPlans` 保序。
- **原因**：用户要短标签，以及一条跨档位的教学路径。按档位分组无法排出「准度Ⅱ在力度前、杆法在准度Ⅲ前」。
- **影响组件**：`DrillCategory.nameZh`、`PlanListView`、`Plans/index.json`
- **日期**：2026-08-26
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`.cursor/skills/swiftui-design-system/SKILL.md`；`20-swiftui-developer.mdc` Changelog；`.cursor/skills/content-engineering/SKILL.md`
- **已应用至**：✅ 上述文件（2026-08-26）

---

## FL-033
- **任务**：组间休息卡最小化
- **现象**：休息卡「最小化」把整场训练收到浮标，并和训练 Tab（计划货架）绑在一起；二次最小化掉回计划页。
- **根因**：把「训练页面」（记分页 `ActiveTrainingView`）当成「训练 Tab」；休息卡最小化接到会话级 `minimizeActiveTraining()`。
- **解决**：休息卡只切 `isRestOverlayMinimized`，人留在记分页。底栏仍负责整场离页。从浮标回来时 `expandRestOverlay()`。撤回训练 Tab 挂会话。
- **日期**：2026-08-27
- **回写目标**：`.cursor/rules/20-swiftui-developer.mdc`
- **已应用至**：✅ `.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / FL-033（2026-08-27）

## FL-032
- **任务**：问题集合 v40 W2–W7
- **现象**：用户否决 W2–W7 交付——主控把规范拆成填空步骤派给子智能体，W2 还用应用脚本灌盘；门禁绿了，精讲仍不是「按规范语义写出来的」。
- **根因**：把「遵守规范」做成了「主控代写改法」。规范原文已经禁止按模块填空；digest 之外的回写脚本、以及派发词里的锚点档/五问排版说明书，都会让写作者不再读规范、不再对每一形做判断。
- **解决**：W2–W7 全量返工。派发只给范围 +「先通读规范再逐课逐形直接改 JSON」。⛔ 禁止任何生成/回写 tutorial 正文的脚本（digest 仅供几何事实）。W1 四条过目样板不动。
- **日期**：2026-08-18
- **回写目标**：`.cursor/agents/tutorial-writer.md`；`.cursor/skills/tutorial-authoring/SKILL.md`；`00-orchestrator.mdc` § 经验教训
- **已应用至**：✅ `.cursor/agents/tutorial-writer.md` / `.cursor/skills/tutorial-authoring/SKILL.md` v1.8 / `00-orchestrator.mdc` § 经验教训（2026-08-18）

## FL-031
- **任务**：精讲配图 HEIC 化（DR-070）落地后包体回涨——用户报「安装又变成 5G 多了」
- **现象**：DR-070 交付时实测 285 MB，次日构建产物回到 **5.2 GB**。查 `project.yml` 第 79 行 `- path: QiuJi/Resources/DrillTutorials` folder reference **原样复活**，`make xcodegen` 据此把 4.9 GB PNG 母版（含 633 张孤儿帧）重新写进 `project.pbxproj` 打包。
- **根因**：DR-070 的改动经提交 `5d79ac8` 入库，逐文件核对发现 **只有 `project.yml` 那一处丢了**（`git diff project.yml` 为空且 `HEAD:project.yml` 即旧内容），Swift / 脚本 / Makefile / `.gitignore` / 测试 / 710 张 HEIC / manifest 全部在库。该文件同期被并行的 v36 线程改动，丢失发生在提交前的合并环节。
- **为什么没被拦住（本条的真正教训）**：当时的门禁只校验**发布目录的磁盘内容**（发布集 / 新鲜度 / 孤儿产物），而真正决定「谁进包」的是 `project.yml` 的 folder reference 与它生成的 `project.pbxproj`——**这两处当时无人看守**。回退发生后 `make verify-gate` 依旧 FAIL 0、`verify-tutorials` 依旧 FAIL 0，全绿地放行了一个 5.2 GB 的包。⛔ 唯一能发现它的是 `TutorialFiguresBundleTests`（要跑构建产物），但没人在改 `project.yml` 时想到去跑它。
- **修复**：① 恢复 `project.yml`（发布目录 folder ref + `sources.excludes` 登记），并在母版目录原位置写死禁止性注释（含 FL-031 编号与后果量级），让下次误恢复的人在动手处就看见；② `publish_tutorial_figures.py --check` 新增 `check_packaging_config()`——直接校验 `project.yml` 声明了 `TutorialFigures` 且**未**声明 `DrillTutorials`，同时校验 `project.pbxproj` 有前者的资源引用、无后者（后半段顺带覆盖「改了 yml 忘跑 xcodegen」这一独立故障）。
- **实证**（构造性，两条分支都真报错）：
  - 在**事故现场原状**（yml 已修、pbxproj 未重生成）跑 `--check` → `打包配置 2`：「pbxproj 无 TutorialFigures 资源引用」+「pbxproj 仍在打包 DrillTutorials 母版」，退出码 1。
  - `make xcodegen` 后 → FAIL 0。再把 yml 的发布目录换回母版目录模拟原始回退 → `打包配置 2`：「yml 未声明 TutorialFigures」+「yml 声明了 DrillTutorials」，退出码 1；还原后 FAIL 0。
  - 修复后 `make build` **SUCCEEDED**，包体 **5.2 GB → 285 MB**（产物内已无 `DrillTutorials` 目录）；`TutorialFiguresBundleTests` **4/4 TEST SUCCEEDED**。
- **规则改进建议**：产物/内容层面的门禁不等于配置层面的门禁。凡「某资源是否进包 / 是否上线」由一份**生成式配置**决定时，必须把该配置本身纳入门禁，且要连同「配置真源」与「生成产物」两头一起校验——只查其一会漏掉「改了真源没重新生成」。
- **日期**：2026-08-13
- **回写目标**：`.cursor/rules/00-orchestrator.mdc` § 经验教训（通用教训，待路由到 DevOps/Release 角色规则）；`project.yml` 原位禁止性注释；`scripts/publish_tutorial_figures.py`。
- **已应用至**：✅ `.cursor/rules/00-orchestrator.mdc` § 经验教训 / FL-031（2026-08-13）；✅ `project.yml` 母版目录原位注释（2026-08-13）；✅ `scripts/publish_tutorial_figures.py` `check_packaging_config()`（2026-08-13）

## FL-030
- **任务**：v30 W2 T01「30° 法则」页配图返工（用户实机反馈：「瞄准线没有，而且调整角度，30 度角那条线也不动，其他类似的也有问题」）
- **现象**（用户截图 + 主控读码复核，均可定位）：
  1. **瞄准线看不见**：`RollThirtyDegreeFigure` 画的不是母球→假想球，而是以假想球为中心
     后延 0.08 m / 前伸 0.18 m 的一小截（`Metrics.aimExtendBack/Front`）。母球距假想球
     0.42 m ⇒ 线与母球**断开 0.34 m**，反而擦着目标球伸到碰撞点前方；再叠加
     `opacity(0.55)` + `lineHintWidth`，屏上只剩 1 号球旁一小段白痕，而「瞄准线」
     标签落在 t=0.85 处（球的右侧），观感是标签指着一条不存在的线。
  2. **拖切角滑杆时滚动线不动**：滚动线取 `departureDir(.follow)` = `rotate(potDir, ±60°)`。
     `potDir`（目标球→袋口）与假想球都不随 θ 变 ⇒ 该线在屏上钉死；随 θ 动的只有母球。
  3. **角标说谎**：标签是硬编字符串 `"约 30°"`，而实际画出的夹角 = `|60° − θ|`
     （θ=45° 时只有 15°，θ=14° 时 46°），与页内表「半球偏折约 34°」也自相矛盾。
  4. T02/T03 同族图的瞄准线画法正确（cue→ghost）但 `opacity(0.35)` + hint 线宽，同样近乎不可见。
- **根因**：`departureDir(.follow)` 的 60° 是**「相对进球方向 n」**的教学折线，来自「旋转与加塞」页
  （那里 stun ⊥ n 是真不变量，60/90/120 一组自洽且页面已诚实标注「示意角·教学折线」）。
  T01 的命题却是**「相对原瞄准线偏约 30°」**——基准是瞄准线。把 n+60° 直接拿来用，
  等价于把「θ=30° 的半球特例」硬编进了通用公式（60° = θ + 30° 只在 θ=30 成立），
  于是非半球档既不动也不对。锁这条的单测注释写着「滚动出发方向随 θ 变化」，
  但**没有对应断言**，只测了 θ=30 一个点，硬编因此长期未被发现。
- **解决**（几何真源加法式扩展，教学折线一行未动）：
  1. `SpinAndEnglishGeometry` 新增 `rollingDeflectionDegrees(cutAngleDeg:)`，取
     `Theory/contracts/theorem-tags.json` T01 `key_formula`
     `tan δ = sinφcosφ / (sin²φ + 2/5)`；新增 `rollingFollowDir` = `rotate(aimDir, s·δ)`
     与 `rollingFollowEnd`。⛔ 不改 `departureDir`，「旋转与加塞」页读数与文案不受影响。
  2. T01 图改画 **cue→ghost 白实线主线（带「瞄准线」标签）+ 过假想球的白虚线延长**
     （延长线即量角基准），滚动线改取 `rollingFollowDir`，角标改为按 δ 实时格式化；
     角标锚点改「角平分线外推 + 朝滚动线侧让位」，否则小切角（δ≈12°）时标签会压住目标球与进球线。
  3. 滑杆说明与图注改为按 δ 与 14°–49° 区间动态生成，不再有写死的 30°。
  4. T02/T03 瞄准线提到 `opacity(0.75)` + `lineMainWidth`，T02 补「瞄准线」标签。
- **实证**：数值草稿 `build/t01-fix/draft.txt`（公式逐档对齐 contract `key_data`：
  27.65@14.5° / 33.75@28.1° / 27.05@49°，极值与 33.7°@28.1° 吻合；`rotate(aimDir, s·δ)`
  与「5/7 切线 + 2/7 瞄准线」向量法误差 ≤3e-15，θ 正负号两侧均验）；
  `make build` BUILD SUCCEEDED；`TheoryFigureGeometryTests` + `SpinAndEnglishGeometryTests`
  13/13 TEST SUCCEEDED（新增 4 项：contract 对账、向量法对拍、方向随 θ 变、θ 全域取景不出框）；
  UI 实机截图 θ=5/30/45/75 四档逐档核验（偏 12°/33°/27°/11°，线随 θ 转、标签不叠）。
  全量 `QiuJiTests` 14 项失败经 **stash 前置基线实跑**证明与本次改动无关（同一批 14 项，
  均为既有 drill 内容 / 重放 / 特写红项）。
- **强制检查点（回写规则）**：
  1. ⛔ **教学示意角必须写明基准，且跨页不得盲借**：同一条绿线在 A 页以「进球方向」为基准、
     在 B 页命题却以「瞄准线」为基准时，**不是同一条线**。复用前先核对基准，
     否则会把某一档的特例值硬编成通用公式。
  2. ⛔ **可交互图上的角度/数值标签一律由几何实测格式化**，禁止写死字符串——
     滑杆一动标签就说谎，且与页内表格自相矛盾（FL-027 同源）。
  3. ⛔ **注释承诺的不变量必须有对应断言**：本例注释写「随 θ 变化」却只测一个点，
     等于零覆盖。写下「随 X 变化 / 与 X 无关」就必须配扫描断言。
  4. ⛔ **教学图的线要连到它所属的实体**：瞄准线画 cue→ghost，别只在 ghost 附近留短截；
     台呢底图上 hint 线宽 + opacity<0.5 的白线实机近乎不可见，主体线一律 `lineMainWidth`。
- **日期**：2026-08-10
- **回写目标**：`.cursor/skills/geometry-spatial-reasoning/SKILL.md` § 经验教训；`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `.cursor/skills/geometry-spatial-reasoning/SKILL.md` § 经验教训 / ⛔ FL-030（2026-08-10）；✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-10）

## FL-029
- **任务**：X-v30-1 生产缺陷修复（插队批，`问题集合_v30.md` §七；用户裁定「立刻修 + 完整修」）
- **现象**：`DrillContentService.loadDrillFromBundle(id:)` 对 **34/77 条 drill 返回 nil**——
  App 动作库实际只有 43 条，将近一半题目在线上**不存在**。相关单测长期红（56 项），
  但失败信息只有「这些 drill 加载失败」，无人能从中定位到字段。潜伏时长以月计。
- **根因（两层，缺一不成灾）**：
  1. **内容层**：`TutorialSection.content` 缺失 45 处（全为「常见错误与纠正」纯 items 节）、
     `TutorialFormation.id` 缺失 7 处（c073/c074/c075），而 Swift 模型把两者定义为必填。
  2. **工程层（红线违反，才是致命的一层）**：L325 `try? JSONDecoder().decode(...)`
     把 `DecodingError` 吞成 `nil`。⛔ 违反 `00-orchestrator.mdc` 工程底线第 3 条
     「禁止空 catch / `try?` 吞错误」。内容缺陷天天存在，但因为它被静音，
     退化成「drill 凭空消失」这种**无法归因**的症状。
- **解决**（四项，全部加法式，旧内容零改动）：
  1. `TutorialSection.content` 放宽为 `String?`。**判定依据（实测，不是猜）**：45 处缺 content
     的节 **100%** 是「常见错误与纠正」且键集恰为 `{title, items}`，items 数 3–4、**无一为 0**；
     同名节在别的 drill 里有 54 处显式写 `content: ""`——即「本节无正文」早就是既定内容形态，
     缺陷只是「省略键」而非「写空串」。⛔ 因此不给这 45 处补正文（那是编造内容）。
     渲染端 `DrillTutorialView` L215 原本就是 `!content.isEmpty` 守卫，改 `if let` 即可。
  2. 7 个 `TutorialFormation.id` **从序列侧反查**得出，非自拟：每个 formation 自身的
     `image` 字段已含 token（`drill_c073_manual01_s01`），且逐球形杆数与序列文件
     完全吻合（7/8、6/9、7/5/5），三重互证唯一解 `manual01/02/03`，符合契约 §3.1「`manualNN` 为既定稳定键」。
  3. `loadDrillFromBundle` / `loadDrillIndex` 的 `try?` 改 `do/catch` + 新增
     `DrillContentDiagnostics`（os_log，`.kiro/steering/observability.md` 口径），
     打印 drill id + `DecodingError` 类型 + codingPath。函数签名不变，调用方零改动。
  4. **门禁不变量 I10**（契约 §7）：`verify_tutorial_sync.py` 新增 `MODEL_SPEC`——
     Swift `Codable` 模型的 Python 镜像，递归校验必填字段与类型；直接列入阻塞项，无豁免。
     Swift 侧同位强化 `test_allIndexedDrills_loadSuccessfully`，失败时打印确切 codingPath。
- **实证**：`make build` BUILD SUCCEEDED；全量 `QiuJiTests` 失败 **56 → 7**，且 7 条经
  **stash 前置基线实跑**证明全部在本批之前就已 FAIL（`build/x-v30-1-logs/baseline-prefix-7classes.txt`）；
  构造性验证：破坏 c001 → gate FAIL 且测试打印 `keyNotFound 'start' at animation.cueBall`
  → 还原后 gate 绿（`gate-BROKEN.txt` / `gate-RESTORED.txt`）；I10 构造性用例 3/3。
- **批外发现**：`animation.pocket` 空串 6 处，其中 c045/c049 是解码修好后**新暴露**的存量
  内容缺陷（此前整条 drill 加载失败，断言根本没跑到）。已登记契约 §8.16，另立批次。
- **强制检查点（回写规则）**：
  1. ⛔ **模型放宽/收紧必须同步门禁**：改 `Codable` 模型的必填性，必须同步改
     `verify_tutorial_sync.py` 的 `MODEL_SPEC`，否则 I10 立刻在全库暴露差异。
  2. ⛔ **内容与模型不匹配时，先判定「谁错了」再动手**：内容里同一形态出现 45 次
     且自洽，那是模型的约束过时，**不是内容缺 45 处**。⛔ 禁止为了满足必填约束批量补写正文。
  3. ⛔ **长期红的测试不是背景噪音**：断言红了却没人能从失败信息定位字段时，
     第一步是修**可诊断性**（让失败自己说出是哪个字段），不是绕过。
- **日期**：2026-08-07
- **回写目标**：`.cursor/rules/00-orchestrator.mdc` § 经验教训（第 3 条工程底线的 `try?` 禁令补可执行检查点）、`.kiro/steering/content-data-contract.md` §7（I10）
- **已应用至**：✅ `.kiro/steering/content-data-contract.md` v1.8 §7 I10 + §7.1 阻塞项 + §8.16 + 版本记录（2026-08-07）；✅ `QiuJi/Resources/Drills/schema.md` `TutorialSection.content` 行（2026-08-07）；✅ `.cursor/rules/00-orchestrator.mdc` § 经验教训 / ⛔ FL-029（2026-08-07）

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

---

## DR-077
- **任务**：动作库已练过卡片去灰标题，改封面角标
- **原始规范**：DR-045 / v28——完成态写入标题下元信息行（灰色「已完成」）；台面覆层只留等级 + Pro/收藏
- **调整后**：已练过改封面右下 `BTPracticedBadge`（✓ 已练）。角标强制 Dark 下的 `btPrimary`（`#25A25A`）——台面 ≈ Light primary，浅色绿会隐进呢面。网格卡课名一律 `.btText`，Pro 只留右上 `BTProBadge`，不再把课名洗成三级灰。元信息行只留精讲种。筛选「已完成」不动。
- **原因**：灰色「已完成」看起来像把标题洗灰；Pro 课名三级灰是同一错觉的另一条通路。角标要在深绿台面上认得出，必须用比呢面亮一档的品牌绿。
- **影响组件**：`BTDrillGridCard`、`BTPracticedBadge`
- **日期**：2026-08-25
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`.cursor/skills/swiftui-design-system/SKILL.md`；`20-swiftui-developer.mdc` Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog + §2.3d；`.cursor/skills/swiftui-design-system/SKILL.md`；`20-swiftui-developer.mdc` Changelog（2026-08-25）

---

## DR-076
- **任务**：精讲多球形切换时阅读位置串台
- **原始规范**：一条共用 `ScrollView` + sticky 分段；行 `.id` 只保证正文刷新（B4），偏移跟着上一个球形走
- **调整后**：
  1. 每个访问过的球形自带 `ScrollView`，未访问的不建（从头）。
  2. 分段提到滚动外并常驻；Picker 与 `visitedFormations` 同步写入，避免 `onChange` 晚一拍闪空页。
  3. 缓存只活在本次 `@State`：退出再进全部从头。禁止对共用 ScrollView 写 `.id(selectedFormation)`（那会每次回顶）。
- **原因**：共用 `contentOffset` 是根因；用户要的是「按球形记阅读位置，会话级，退出清」。
- **影响组件**：`DrillTutorialView`
- **日期**：2026-08-24
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`20-swiftui-developer.mdc` Changelog + 经验教训
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`20-swiftui-developer.mdc` Changelog + 经验教训（2026-08-24）

---

## DR-075
- **任务**：加塞吃库图谱增加高低杆打点盘，按该打点重算允许加塞量的八条轨迹
- **原始规范**：本页 `spinY` 锁 0（中杆）；右缘纯力度柱 `onSpinTap=nil`；8 档 `spinX` ∈ [±miscueLimit]
- **调整后**：
  1. 右缘迷你打点图可点开 `BTSpinPadOverlay`；新增 `locksSideSpin`：拖动锁竖轴、隐藏左右微调，只选高低杆。
  2. `allowedSpinXLimit(spinY) = √(L² − spinY²)`；`spinXLevels(spinY:)` 在该弦上均匀 8 档（端点在打滑圆上）。满高/满低弦长为 0，八档塌成中心。
  3. `simulateFree` 喂选定 `spinY` + 各档 `spinX`；左缘 8 盘红点画在该弦上（高杆偏上、弦更短）。
  4. 顶栏增「打点 / 可加塞%」；学卡副标题改为「高低杆 · 左右塞 · 吃库后出射」。
- **原因**：中杆只是打滑圆一条直径。高低杆占掉半径预算后，能加的左右塞是圆上剩下的水平弦——这是误杆极限的第一性原理，不是另设档位表。
- **影响组件**：`BTSpinPad` / `BTSpinPadCard` / `BTSpinPadOverlay`（`locksSideSpin`，默认 false）；`CushionEnglishAtlasGeometry` / `View` / `ViewModel`；`AngleHomeView`
- **日期**：2026-08-24
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog；`20-swiftui-developer.mdc` Changelog（`locksSideSpin` API）
- **已应用至**：✅ SPEC §9.3 / Changelog；`20-swiftui-developer.mdc` Changelog（2026-08-24）

---

## DR-074
- **任务**：精讲逐杆静帧补瞄准位球杆
- **原始规范**：v19 C6 把「缩略图/图文渲染」列为例外藏杆；`renderStills` 只画预告线 + HUD。缩略图已由 DR-039 补杆，精讲静帧未跟上。
- **调整后**：
  1. `SequenceVideoExporter.renderStills` 逐杆帧与视频「亮方案」拍同口径：有预告线且 `showCueStroke`、杆可解时 `showCueAtRest`。
  2. 开局/终局无线，不摆杆；拍完藏杆，终局图不得残留上一杆杆位。
  3. C6 例外收窄：图谱等无瞄准任务页继续无杆；精讲逐杆静帧不再例外。
- **原因**：用户点验全部精讲图有轨迹线、无球杆。根因是静帧出口漏调 `showCueAtRest`，不是内容漏画。
- **影响组件**：`SequenceVideoExporter.renderStills`；现网图须 `make position-export-stills` + 回填发布后才变。
- **日期**：2026-08-24
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §8.9 h + Changelog；`tutorial-authoring` / `content-engineering` SKILL
- **已应用至**：✅ SPEC §8.9 h / Changelog；`tutorial-authoring` v1.10；`content-engineering` v1.4（2026-08-24）

---

## DR-073
- **任务**：分离角图谱 / 加塞吃库图谱左缘 8 盘点选开关轨迹
- **原始规范**：左缘 8 只读迷你打点盘（`allowsHitTesting(false)`），台面恒画 8 色轨迹
- **调整后**：
  1. 左缘盘可点选开/关对应色轨迹；未选盘降透明，对应线消失。
  2. 默认 8 档全开；关掉最后一档为 no-op（至少留 1 档）。
  3. 开关只挡画线，不重跑并行 `simulateFree`；缓存最近一次 paths 后即时重画。
  4. 共享规则 `AtlasSpinTrackSelection`（两页同源）。
- **原因**：8 线叠在一起看不清；用户要自己勾选只看一档或几档。
- **影响组件**：`SeparationAngleAtlasView` / `CushionEnglishAtlasView` 左缘盘
- **日期**：2026-08-20
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog
- **已应用至**：✅ SPEC §9.3 / Changelog（2026-08-20）

---

## DR-072
- **任务**：v37 W4 计划货架 11 份上屏（新 `targetLevel` 与封面标签）
- **原始规范**：`PlanListView.groupedPlans` 只枚举旧 6 档；`PlanCoverLabel` 映射 10 套（走位/中级/高级为「走位」「综合」等）
- **调整后**：
  1. `groupedPlans` 覆盖 `L0→L2` / `L1→L3` / `L2→L3` / `L2→L4`，未知档追加到末尾，禁止静默丢卡。
  2. `CoverPalette.PlanStyle.forLevel` 新档别名到现有 6 色，不扩 `planLevelKeys`（对比度测试仍 6 色）。
  3. `PlanCoverLabel`：走位Ⅰ / 走位Ⅱ / 准度Ⅱ / 特殊球 / 全能综合；杆法/准度封面仍为「杆法」「准度」（不加 Ⅰ）。
- **原因**：11 份目录引入跨档 `targetLevel`，旧枚举会把准度Ⅰ/走位Ⅰ/杆法Ⅱ/准度Ⅱ/走位Ⅱ/全能从列表页丢掉。
- **日期**：2026-08-14
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`.cursor/skills/swiftui-design-system/SKILL.md` PlanCoverLabel / Changelog
- **已应用至**：✅ SPEC Changelog；✅ `swiftui-design-system/SKILL.md`（2026-08-14）

---

## DR-071
- **任务**：v37 W2 动作页六轴雷达（用户拍板删除假五维「训练维度」+ 页底雷达；D-v37-6 展示分 +1）
- **原始规范**：详情「训练要求」卡含启发式五维（分类 + difficulty/5 → 准度/力量/走位/杆法/心理），与真实六轴负荷无关。
- **调整后**：
  1. 删除 `trainingDimensions` / `dimensionGroups` / `DimensionData` 及「训练维度」文案。
  2. 新增 `BTLoadRadarChart`：自绘六边形；轴序顶起顺时针为进球/杆法/加塞/走位/约束/力度。
  3. **展示映射**：存储 0–4 → 展示 1–5（半径 = 展示/5）。JSON / I12 不变。
  4. 无 `load` 时网格仍在、不填充、不崩。
  5. **上屏文案**（2026-08-14 用户点验）：标题「难度画像」+ 副题「这项动作难在哪」；契约层仍称执行负荷。
  6. **视觉**（同日）：台呢径向底、主色径向填充 + 外发光、峰值轴（展示≥4）金色顶点；轴名小字 + 分数大字。
- **日期**：2026-08-13
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`.kiro/steering/content-data-contract.md` §5.7.6；`.cursor/skills/swiftui-design-system/SKILL.md`
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-08-13 / 2026-08-14）；✅ `.kiro/steering/content-data-contract.md` §5.7.6（2026-08-14，契约 2.7）；✅ `.cursor/skills/swiftui-design-system/SKILL.md` Changelog（2026-08-13 / 2026-08-14）

## DR-070
- **任务**：精讲配图压缩与打包瘦身（v25 W4 执行，触发于用户问「当前 app 为什么会 5.43G」）
- **原始规范**：`Resources/DrillTutorials` 以 folder reference 整目录打包，1343 张无损 PNG 共 4.90 GB 全部进包；`DrillTutorialImageStore` 硬编码 `withExtension: "png"`。
- **根因（实测，非猜测）**：
  1. **格式错配**。配图是 3D 渲染图而非照片：alpha 通道恒为 255（纯浪费），球布区相邻像素 83% 不同、平均差 4.3/255——是渲染噪点，它让 PNG 的行内预测失效（1440×2720×4 = 14.9 MB 原始数据只压到 3.76 MB）。有损编码恰好抹掉这层不可见噪点。
  2. **打包集错配**。1343 张里仅 **710 张（2.60 GB）**被精讲 `image` 引用，**633 张（2.30 GB）是孤儿**（`_still` 旧命名遗留 387 张、`_final`/`_initial` 等）。D-v25-10 早已裁定孤儿不进包，但 folder reference **整目录打包、无法挑文件**，母版与发布图同处一室时该裁定物理上无法执行。
- **调整后**：
  1. **母版与发布图分目录（D-v25-14）**：`Resources/DrillTutorials`＝PNG 母版（回填目标，不进包不进 git）；新增 `Resources/TutorialFigures`＝发布目录（仅被引用者，HEIC q70，进包进 git）。Bundle 子目录名随之变更，`DrillTutorialImageStore` 与 `DrillContentService.tutorialClipURL` 统一读 `TutorialAssets`（`bundleSubdirectory` + `imageExtensions` 顺序回退 heic→png→jpg）。
  2. 新增 `scripts/publish_tutorial_figures.py`（`make tutorial-figures`）：按 JSON 引用筛选 → sips 转 HEIC → 写 `content/tutorial-figures-manifest.json`（记源 md5，供增量与门禁）→ 清理不再被引用的旧产物。`import-engine-export-to-app.py` 回填后自动串接（`--skip-publish` 可关）。
  3. **质量档取 q70（v25 W4 拍板值），保持原始 1440×2720 不降分辨率**。定档依据是实测而非默认值：q45/60/75 体积 64/115/198 KB，HEIC 回转 PNG 与母版逐像素 PSNR 41.7/42.7/43.4 dB，底部小字带 41.8–42.9 dB。q45→q75 体积翻三倍而 PSNR 仅 +1.7 dB——码率增量几乎全花在复现那层不可见噪点上，故无需追高档位。
- **门禁（本条的关键，避免换格式把既有约束换没）**：
  - 转 HEIC 后源与产物**不可能字节相等**，`verify_tutorial_sync.py` C2 的 md5 字节比对若直接指向发布目录会 710 项全部降级成 warn（`BYTEWISE_SUFFIXES = {".png"}`）。母版目录保持 PNG 不动使 **C2 原样有效**（实测仍为「通过 925 / 不符 0」），发布链路另设 `--check`（发布集 / 新鲜度 / 孤儿入包三查）接进 `make verify-gate`。
  - 构造性实证（不是空壳门禁）：混入一个 `__stray.heic` → FAIL 1「多余产物(孤儿入包)」；篡改清单 `src_md5` 模拟「母版已变未重发布」→ FAIL 1「过期」；`make verify-gate` 退出码非 0。还原后 FAIL 0。
  - `TutorialFiguresBundleTests`（4 条）在**构建产物**上复验：710 张全部经 `DrillTutorialImageStore` 解出 `UIImage`、包内无 PNG 母版、HEIC 数 == 引用去重数、样本解码宽度 1440。
- **验证**：`make xcodegen` + `make build` **BUILD SUCCEEDED**；`-only-testing:QiuJiTests/TutorialFiguresBundleTests` **Executed 4 tests, with 0 failures**、`** TEST SUCCEEDED **`；`make verify-tutorials` 改动前后均 FAIL 0（C2 925 / C3 710 未退化）。**包体实测 5.1 GiB → 285 MB**（`TutorialFigures` 114 MB + `TaiQiuZhuo.usdz` 94 MB + dylib 53 MB），发布目录 112.5 MB ≤ W4 DoD 的 150 MB。
- **已知限制 / 遗留**：
  1. 710 张 HEIC（112 MB）按 D-v25-2 应入 git，本次**未执行 `git add`**（未获提交授权），当前仍是未跟踪状态。
  2. `TaiQiuZhuo.usdz` 94 MB 现已是包内第二大项、占 33%，尚未评估（P18 T-P18-28 可一并看）。
  3. 633 张孤儿母版按 D-v25-10 保留磁盘未删；`build/position_play_export`（8.9 GB）与 `archive/`（11 GB）同为本地产物，不影响包体。
- **日期**：2026-08-12
- **回写目标**：`.kiro/steering/content-data-contract.md` §一 真源表 + §6.4 产物纪律；`.cursor/skills/content-engineering/SKILL.md` 落位节；`.cursor/skills/tutorial-authoring/SKILL.md` 输入表；`问题集合_v25.md` W4 / D-v25-14；`.gitignore` 注释。
- **已应用至**：✅ `.kiro/steering/content-data-contract.md` §一 + §6.4 第 4/5 条（2026-08-12）；✅ `.cursor/skills/content-engineering/SKILL.md`（2026-08-12）；✅ `.cursor/skills/tutorial-authoring/SKILL.md`（2026-08-12）；✅ `问题集合_v25.md` W4 完成标准 + D-v25-14（2026-08-12）；✅ `.gitignore`（2026-08-12）

## DR-069
- **任务**：训练分享图改长图（用户反馈「太简陋了，期望和训练详情差不多并带统计数据，字体和布局要美观，可以是长图」）
- **原始规范**：`BTShareCard` 固定 361×480pt 单屏卡；内容仅「品牌头 + 计划名 + drill 聚合行 + 三格统计 + 页脚」，根部 `Spacer(minLength: 0)` 顶开版面。
- **调整后**：
  1. **尺寸契约由「定宽定高」改「定宽 + 高度随内容」**。`ShareCardImageRenderer.cardHeight` 常量删除，改 `cardWidth = 375` + `maxCardHeight = 3000`（仅供测试断上界，**不做裁切钳制**——真超了说明折叠规则错了，裁切等于静默丢内容）。删掉卡内 `Spacer(minLength: 0)`：480pt 死高原本就是它导致 width-only 渲染失控时的止血手段（见 `ShareCardImageRendererRootCauseDiagTests`），根因修掉后死高失去存在理由。
  2. **六段式长图**：品牌头（日期 + 时段）→ Hero（标题 + 四大数字：分钟/组数/进球/成功率）→ 成绩概览（多项时逐项成功率对比条 + 最佳一组 + 组间波动）→ 训练明细（每项一卡：烘焙缩略图 + 聚合分 + 逐组网格，6 格一行，底色深浅表达该组成功率）→ 训练心得 → 品牌页脚。
  3. **分享图独立字阶** `ShareType`（写死 pt），**不复用** `.bt*` 字体 token：导出图必须在任何系统动态字体档位下排版一致。
  4. **高度封顶靠折叠规则而非魔数**：`maxDrillCards = 8`、`setGridBudget = 36` / `foldedSetsPerDrill = 12`、`noteLineLimit = 8`，超出显示「还有 N 项 / +N 组」。首版取 12 张卡时极端用例实测 3175pt > 3000 上界，**收紧折叠而不是抬高阈值**。
  5. **「未登记」与「0%」分离**（本次真正的正确性修复）：`hasScoredBalls == false`（全部 target = 0）时成功率显示「—」而非 0%——未定义 ≠ 0；`SetResult.rate` 返回 `Double?`；整项 `hasRecordedSetData == false`（逐组全 0/0）时不画逐组网格，避免一屏无信息量的「0/0」。
- **原因**：单屏死高既压扁长内容又给短内容留大片空白；聚合口径的 `TrainingSessionSummary` 使卡片无逐组/心得/缩略图可展示。
- **影响组件**：`BTShareCard`（含 `TrainingSessionSummary` 扩字段 `note` / `DrillResult.drillId` / `DrillResult.sets`）、`ShareCardImageRenderer`、`TrainingShareView` 预览区、`TrainingDetailView.shareSummary`、`ActiveTrainingView.buildShareSession`。
- **已知限制**：`ActiveTrainingView` 侧计划名仍是「训练记录 / 自由训练」占位——`TrainingMode.plan` 不携带计划展示名，取真名需新增计划查询，本次未做（范围纪律），历史详情页入口已是真实标题。
- **验证**：`make build` BUILD SUCCEEDED；`ShareCardImageRendererTests`(7) + `TrainingSessionSummaryStatsTests`(5) + `ShareCardImageRendererRootCauseDiagTests`(2) = 14/14 通过。像素高断言换成「宽度精确 = cardWidth × scale + 高度随 drill 数/心得单调增长 + 极端用例仍 < maxCardHeight」。
- **日期**：2026-08-11
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog。
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-11，DR-069）

## DR-068
- **任务**：练习页三小修——搜索框高度统一 / 练习页主题筛选 / 解球器击球中打点盘消失
- **原始规范**：① `BTLibrarySearchBar` 输入框高度随内容（~36pt），动作库因右侧 44pt 筛选按钮把整行撑高，练习页无 trailing 显得矮一截；② 练习页搜索框无筛选 accessory；③ `SolverStageChrome.canOpenSpinPad` 含 `!vm.isPlaying`，击球中 `onSpinTap` 传 nil ⇒ `BTShotInstrumentColumn` 整个不渲染打点迷你图（打点盘从仪表柱上消失，力度条却只是灰化）。
- **调整后**：① `BTLibrarySearchBar` 输入框固定 `fieldHeight = 44pt`（= 筛选按钮边长），有无 trailing 各页高度一致；② `AngleHomeView` 搜索框旁新增与动作库 `libraryFilterMenu` 同视觉的主题筛选 Menu（单选：准度 / 加塞 / 走位 / 吃库 / 防守 + 全部），`AngleEntry` 加 `topics: Set<PracticeTopic>`（学/练/打/解逐条标注、理区按 `TheoryPageID` 逐页映射；综合条目如自由击球 / 流程速查不挂主题、仅在未选主题时出现），空态动作同时清搜索词与主题；③ `canOpenSpinPad` 改为结构性条件 `showsSpinSlot`（自由模式 / 求解有解——求解无解仍是纯力度柱），击球中的不可用态改走 `spinTapEnabled: !vm.isPlaying`，与力度条一起禁用灰化、不消失。
- **原因**：①②用户对照两页反馈不一致 + 希望练习页可按主题横切筛选（与侧栏「学/理/练/打/解」形态分区正交）；③「消失 vs 禁用」语义错位——`onSpinTap == nil` 的组件语义是「该页无打点位」，不是「暂时不可点」。其余击打页均走 `isDisabled`，仅此壳（翻袋 + 反射解球器）有该问题。
- **影响组件**：`BTLibrarySearchBar`（新增 `fieldHeight`）、`AngleHomeView`（`PracticeTopic` / `topics` / `topicFilterMenu`）、`SolverStageChrome`
- **验证**：`make build` → `BUILD SUCCEEDED`；lint 0；grep 确认无 UI 测试断言解球器击球中打点盘不存在。
- **日期**：2026-08-11
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-11）

## DR-067
- **任务**：动作库筛选菜单去掉无区分度的「有精讲」
- **原始规范**：`DrillBadgeFilter` 含 `hasTutorial = "有精讲"`（E19 / v26 W0），与模板种（单杆技术课 / 应用课 / 规则流程课）及「已完成」并列。
- **调整后**：移除 `hasTutorial` case 及匹配分支；菜单「精讲与进度」仅保留：全部角标 / 单杆技术课 / 应用课 / 规则流程课 / 已完成。
- **原因**：全库 83 条 drill 均有精讲，`有精讲` 命中 83/83，筛了等于没筛。球种与三类精讲种仍有内容命中，不删。
- **影响组件**：`DrillListViewModel.DrillBadgeFilter`（`DrillListView` 经 `allCases` 自动收敛）
- **日期**：2026-08-09
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-09）

## DR-066
- **任务**：动作库 Drill 详情页信息层级与 Light/Dark 统一
- **原始规范**：球桌下方为 `BTShotHUDBar` 永久预留约 50pt 黑色空条；正文标题、简介、标签与三张同权卡按统一 20pt 间距平铺；「达标标准」把长目标与短建议量强制二等分；训练维度用五个胶囊网格呈现。
- **调整后**：
  1. 保留导航标题 + 正文标题；正文标题、15pt 次级简介、标签收成一个 8/12pt 关系明确的信息组。难度徽章移到正文标题 trailing，球种/分类仍在下一行；标题组底部用 `btSeparator` 弱分隔，不再新增卡框或无语义标题图标。
  2. HUD 仅在回放期间动态插入球桌下方，空闲态不占高度、播放态不遮台面；播放钮空闲/暂停态常显，播放约 2 秒后自动隐藏，轻点球桌只唤出控制，再点才请求杆边界暂停。
  3. 「达标标准」与「训练维度」合并为「训练要求」卡：达标目标全宽纵排，建议量单行右对齐，维度按重点/中等/辅助分组为只读文字，避免伪按钮；三个同级子标题统一为 `Label` + SF Symbol。
  4. 两张内容卡 Light 用 `btBGSecondary`，Dark 同 token 并补 0.5pt `btSeparator` 描边；底栏与正文统一 16pt 水平边线。
  5. 详情球桌废除固定 `frameAspect=1.81 + orthoScale=0.77` 的裁切取景：画框改用 USDZ 外框实测兜底比例，`CameraRig.fitLandscapeTable` 按运行时外框与容器宽高双轴计算正交半高，并保留 1.2% 抗锯齿安全余量；首帧 fallback 同样使用完整外框尺度。
- **原因**：原页面同时存在固定黑色空洞、16–20pt 扁平字号层级、左右栏信息量失衡与三张同形卡堆叠，导致阅读路径不清；维度胶囊又产生可点击误解。共享 `DrillDetailView` 改一次即可覆盖全部 Drill。
- **影响组件**：`DrillDetailView`、`DrillSceneView`、`BTShotHUDBar` 注释、`DrillSceneThreeBeatUITests`
- **验证**：`make build` → `BUILD SUCCEEDED`；`ShotTableLayoutTests` 9/0（含新增横向完整取景 2 条）+ `BTShotHUDBarRenderTests` 2/0；Light 与 Dark 详情布局 UI 测各 1/0；播放控制/HUD UI 测 1/0，覆盖 2 秒自动隐藏→轻点球桌唤出→杆边界暂停，并断言 `hud.minY ≥ table.maxY - 1`；改前/后截图与 xcresult 见 `build/drill-detail-{before,controls-framing,controls-final}*`。
- **日期**：2026-08-09
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog
- **已应用至**：✅ `tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog（2026-08-09）

## DR-065
- **任务**：问题集合 v32 — 练习 Tab 五分类「理」区独立（16 体系）
- **原始规范**：ADR-P18-01 四分段（学/练/打/解）；ADR-P12-01 / v30 选址「理论之家 = 学区、不加与学并列的新类别」；球理入口在 `learnEntries` 首卡。
- **调整后**：
  1. `PracticeSection` 增 `theory = "理"`，声明序 **学 → 理 → 练 → 打 → 解**。
  2. 理区 `theoryEntries` 由 `TheoryCatalog.entries`（已上线）映射为 **12 张** `.theoryPage` 卡；**无**「球理」索引总卡；`learnEntries` 无球理。
  3. caption：学「交互弄懂瞄准、旋转与走位」；理「定理、流程与速查：分主题看懂原理」。icon：理用 `scroll` / `scroll.fill`。
  4. 分篇两字 glyph（三十/九十/切线…）；UITest 用 `TheoryIndexNavigation.openPage(cardTitle:)`。
  5. `TheoryIndexView` 路由保留，仅深链可达。
- ⚠️ **修订（v32.2，2026-08-08）**：首版曾拍「单卡进索引」；用户改为每页单独卡片后按上条落地。
- **原因**：12 篇理论已撑起独立心智；与交互学页抢「学」会糊化；用户拍板理与学平级且学区不留卡，并要求理区网格即目录。
- **影响范围**：`AngleHomeView`、`CoverPalette` 注释、P5/V28/ScreenshotTour/V30W0–W4 UITests、ADR-P12-01/P18-01、`问题集合_v30/v32`、SPEC §9.3。
- **日期**：2026-08-08
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 + Changelog；`tasks/phases/P12-content-system-theory.md`；`tasks/phases/P18-release-convergence.md`
- **已应用至**：✅ SPEC §9.3 + Changelog（2026-08-08）；✅ P12/P18 ADR 修订注记（2026-08-08）；✅ `问题集合_v32.md` v32.2；✅ `swiftui-design-system/SKILL.md` §九封面 + Changelog（2026-08-08）

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

## PD-030
- **任务**：模拟器 iPhone 17 Pro 解锁 Pro
- **模式描述**：**「`simctl launch` 不注入 StoreKit，Debug 解锁必须走启动参数 + 持久位」**：
  1. Scheme 的 `Products.storekit` 只在 Xcode Run / `xcodebuild test` 时注入。`make run` → `simctl install` + `simctl launch` 会去问真商店，商品为空，付费墙 CTA 灰掉。
  2. 日常启动默认带 `-forcePremium`，并写入 UserDefaults；点桌面图标仍是 Pro。免费档用 `-resetDebugPremium`（`make run PREMIUM=0`）。
  3. UI 测试 `launchClean` 必须先 `-resetDebugPremium`，避免手动解锁污染免费档用例；`-forceNonPremium` 仍优先于 `-forcePremium`。
- **适用场景**：任何 IAP / Freemium 门禁在模拟器上用 `make run` / 点图标验证。
- **代码示例**：`scripts/Makefile` `run` 目标；`SubscriptionManager.applyDebugPremiumLaunchOverrides`；`XCUIApplication.launchClean`。
- **日期**：2026-08-19
- **回写目标**：`.cursor/rules/60-devops-release.mdc` § 经验教训
- **已应用至**：✅ `.cursor/rules/60-devops-release.mdc` § Changelog v0.4 + § 经验教训 / PD-030（2026-08-19）

## PD-029
- **任务**：问题集合 v33 W3 / W5（2026-08-09）——`tutorial_digest.py` 的派生字段与真源不符，连续两批写作者都必须绕开它（v33 §七 遗留 L7）。
- **模式描述**：**「派生事实脚本的声明值字段必须交叉验证，冲突即上报」**：
  1. **声明值 ≠ 实测值**。`tutorial_digest.py` 的「开局布局 母球」读的是序列 `initial` 字段，而编排台录制常把它留成占位（实测 c079 / c080 / c060 均为 `0.300/0.300`），与**第一杆 `before`** 及 `initial.png` 三方互不相符。凡「一个字段有独立来源、另一个字段由录制流程顺带写入」的情况，必须以**逐步快照（实测）**为准，声明值只可作交叉验证的对照。这与 FL-027「解元数据必须取实测」同源，本条是它在**内容写作侧**的落地。
  2. **退化输出不是结论**。同一脚本的「形态判定」「击打顺序与袋口」在多杆 `freeAim` 序列上会退化——c060 八杆里仅一杆有 `targetKey`/`pocket`，脚本据这一杆输出「独立阶梯（目标球距袋恒定 15.6 颗球）」，该结论对另外七杆无意义。判据字段的输入覆盖率不足时，脚本会**照常给出一个自信的结论**；使用者必须先问「这个判据的输入齐全吗」。
  3. **修法的选择**：本轮未改脚本（W5 范围外），改为在技能里立硬约束 + 在方案 §七 留条目。真正的收口是二选一——修脚本（`initial` 缺失/占位时回落到首杆 `before`）或修序列 `initial` 字段；⛔ 不接受「让每个后续写作者各自记得绕开」。
- **适用场景**：任何「脚本产出事实清单供人写作」的管线；任何同一事实存在「声明字段 + 实测快照」双来源的数据结构。
- **效果**：v33 W2–W5 四批精讲的开局摆位全部改用首杆 `before` 并与 `initial.png` 交叉验证，未出现开局描述与配图不符；c060 形态经客观复核判为「八个独立场面」而非脚本给出的「独立阶梯」。
- **日期**：2026-08-09
- **回写目标**：`.cursor/skills/tutorial-authoring/SKILL.md` § 第1步 + Changelog。
- **已应用至**：✅ `.cursor/skills/tutorial-authoring/SKILL.md` § 第1步 硬约束段 + § Changelog v1.1（2026-08-09，PD-029）

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

## FL-041 — 位置测试混入 XCTest 自动揭露滚动
- **任务**：v57 W2 低位筛选补验。
- **现象**：SE 初始官方标题 Y=507pt，切到空模版后 Y=444.5pt，原 ≤2pt 断言失败。
- **根因证据**：点击前截图 83D4DEB1-E10C-42A9-8513-52369E65A343.png 显示“我的模版”被悬浮自由训练按钮遮挡；test.log 9.15s 明确 `Scroll element to visible`，随后才点击。入门/全部均保持原 Y。此失败不能证明内容切换自身漂移。
- **修正**：测试准备阶段先让官方、入门、模版三个完整控件位于悬浮按钮上方，再记录低位锚点。原 ≤2pt 断言及少/多/空/返回步骤均保留。生产源码未改；三尺寸补验正在重新运行。
- **证据**：`output/v57/W2/matrix/ios26-se-light-supplement` 原失败完整保留；复跑独立目录 r2。
- **日期**：2026-09-05
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` v0.6 位置测试起点检查与 UI 规格 Changelog。

## DR-086
- **任务**：v57 W3，计划课序与动作详情往返。
- **决定**：每阶段按 lesson.order 展示第 N 天；课题独立一行，移除页面 summary；课序仍按完成推进。动作主体通过 TrainingRoute.drillDetail 留在训练 NavigationStack，剂量展开独立 44pt 按钮。返回仅刷新数据，不销毁已有 ScrollView 或重置折叠集合。
- **依据**：R04 原图/原话、问题集合 v57.2、PlanDetail 旧单球形点击空操作与 loadPlan 全展开路径。
- **验证状态**：标准 build、标题非目标字段指纹通过；导航/视觉运行中，尚未验收完成。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md 计划交互补充及 Changelog；docs/design/v47/route-coverage.csv 与路由签名经四文件审计更新。

## FL-042 — 测试根页不一定存在 NavigationBar
- **任务**：v57 W3 首轮导航测试。
- **根因/证据**：深链 PlanDetail 是 NavigationStack 根页，无导航标题/返回项；reveal helper 无条件取 navigationBars.firstMatch.frame，两个测试在点击前即快照查询失败。`output/v57/W3/matrix/phone-light-first/test.log` 保留原失败，未对产品导航作推断。
- **修正**：先判断 bar.exists，存在时用其下缘，否则用 window.minY；仍检查目标 isHittable/底部 CTA 边界，原返回 Y 与折叠断言不变。复跑待验证。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` v0.7 与 UI 规格 Changelog（2026-09-05）。

- **FL-042 同批补充**：完整五方法首轮 4/5 通过，锁态启动检查错误地只查普通 CTA，未进入动作详情；实际 Pro 计划为“解锁此计划”。测试改为等待日序内容，并按真实 CTA 分支测量底部边界。原四条通过结果和锁态失败保留于 phone-light-full，完整复跑另存 phone-light-full-r2。原权限与返回断言未删减。

## FL-043 — XCTest 环境变量前缀导致深色取证误标
- **任务**：v57 W3 导航矩阵。
- **根因**：新测试只读 TEST_RUNNER_V54_APPEARANCE；Xcode 注入测试进程时使用去前缀 V54_APPEARANCE，因此 dark 运行仍传 -v54.forceLight。旧 W2 helper 已兼容两名，新 helper 未复用这一约定。
- **证据**：phone-dark 5/5 行为测试通过，但 14 张实际截图均为浅色；左侧空白边缘灰度均值 243。图片视觉核对发现后，停止后续调度，让当前 AX5 子测试正常结束，再终止暂停的驱动（exit 143），未打断 XCTest 或改产品。
- **修正**：读取 V54_APPEARANCE 并兼容 TEST_RUNNER 前缀；图像门禁增加实际背景灰度的外观检查。旧错误深色目录在新增检查下 14/14 明确失败，保留原绿色图像门禁为 image-gate-before-appearance-check.json，证明新检查会抓出原失误。
- **状态**：七单元同源码矩阵重跑待验收，不将旧 phone-dark 计为深色通过。
- **已应用至**：.cursor/rules/55-test-engineer.mdc v0.8、UI 规格 Changelog、review_navigation.py（2026-09-05）。

## FL-039 补充 — W3 阶段标题宽屏留白命中（2026-09-05）

W3 ipad-light 五项回归中四项通过，阶段折叠在首次行中心点击后仍为已展开。原日志、点击事件、截图保留于 output/v57/W3/matrix/ipad-light。chapterHeader 含 Spacer，标签未声明完整 contentShape，iPad 行中心为透明留白；与 FL-039 同类。已在 Button 标签完整 chapterHeader 上声明 Rectangle 命中区，保持原中心点击和折叠断言不变。待 iPad 原失败及相邻尺寸复验。已应用至既有 .cursor/rules/20-swiftui-developer.mdc § FL-039 规则；本次是该规则补充实例。

## DR-087
- **任务**：v57 W4，R08/R09/R10。
- **决策**：BTDrillGridCard 由 isCompleted 改为 practiceCount:Int=0；0 不显示，正数显示彩色勾选“已练 N 次”，与单杆/多杆/规则标签同行。覆盖 DR-077 封面右下角标位置。
- **数据口径**：当前 owner 已保存 TrainingSession 内的独立 DrillEntry.id 计次，同场同动作两个不同 entry 计2，组数不叠加。字典观察覆盖1→2，重复ID去重，owner隔离。移除动作库 completed 筛选分支，保留其他类型/球种/等级筛选。
- **操作**：DrillDetail 可用态加入训练使用 primary；回调、sheet、保存服务、Pro门控保持原路径。
- **验收**：聚焦数据/渲染首轮进行中（session 30331），UI保存删除刷新/加入训练待运行；不标完成。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md §网格卡契约与 Changelog（2026-09-05）。

## FL-044 — SwiftUI 测试宿主的容器生命周期
- **任务**：v57 W4，保存条目刷新 UI。
- **证据**：se-light-first 原日志/诊断保留；StandardOutputAndStandardError-com.xinkuan.qiuji.txt 明确 SwiftData BackingData fatal：model instance was destroyed by calling ModelContext.reset。菜单和加入今日安排2项通过，首次保存entry时退出。
- **根因**：DEBUG宿主以普通let创建ModelContainer，视图重新构造可换容器，而@State session保留旧容器模型，旧context释放后对象不可用。不是计数算法异常。
- **修正**：容器改为@State绑定宿主身份，与session同生命周期；保留真实SwiftData保存删除、原0→1→2→1→0断言。复跑待验证。
- **已应用至**：.cursor/rules/55-test-engineer.mdc v0.9 与UI规格Changelog（2026-09-05）。

## FL-045 — 元数据增高压缩网格卡标题
- **任务**：v57 W4，类型与次数同行。
- **证据**：31单测通过，但render-contact.jpg小屏有次数卡的同一动作标题被压成一行省略，0次卡仍为两行；不能仅据单测绿交付。
- **根因假设**：新增胶囊提高meta固有高度，网格对卡片的纵向提议压缩标题；titleMinHeight只保留框高，没有要求完整卡片采用固有纵向尺寸。
- **修正**：仅BTDrillGridCard声明fixedSize(horizontal:false,vertical:true)，保持实际列宽、两行标题约束及其他卡片不变；待同一12图渲染和真实界面复验确认假设。
- **已应用至**：.cursor/rules/20-swiftui-developer.mdc v1.9 与UI规格Changelog（2026-09-05）。

## DR-088 — 全页面球库密度统一（v57 W5，2026-09-05）
- **需求**：球库太散适用于全部相关页面，包括练习页；保持两行球序、既有点选/拖动语义。
- **变更**：共用球库族与 AngleDynamic 私有布局统一40pt球面、44pt独立槽、额外行间距0；每行352pt，宽屏不再将8列撑至440pt。compactDiameter/regularDiameter保留调用兼容但同值40；提球页Token与标球槽随共用尺寸同步。拖动幽灵仍42pt。
- **验证边界**：iPad自由击球改前截图 output/v57/W5/before/ipad-freeplay.png；本次聚焦测试运行中，全部页面截图/交互、窄屏提球布局与3D问题尚未验收，不标W5完成。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md §Changelog / DR-088（2026-09-05）；该条覆盖旧D7/v51的30/36pt与440pt尺寸。

## FL-046 — 提球测试会员前置（2026-09-05）
旧W4提球测试未注入Pro，AX证实停在订阅页。增加既有forcePremium测试参数后复验，不改产品门控。原失败证据见FAILURE-LOG；已应用至.cursor/rules/55-test-engineer.mdc §FL-046及UI规格Changelog。

- **DR-088补充**：新增BTBallPaletteWithActions，按真实可用宽度在右列/下方横排按钮间选择，两提球页标球和确认步骤已接入；Token AX值提供真实在台状态以验证拖放。W5验证中。

## FL-047 — DR-088 视觉方案撤回（2026-09-05）
用户否决球库放大及底栏增高引发的球桌比例失衡。DR-088停止生效，生产视觉文件已恢复W4最终指纹；原补丁/测试/失败截图均留档。后续方案必须同时比较球桌可视区域和球库占比，不能只审球间距/触控。已应用至.cursor/rules/20-swiftui-developer.mdc §FL-047、UI规格Changelog与v57 R07需求。

## DR-089 — 中性游客账号卡与会员信息层次（v57 W6，2026-09-05）
- 游客卡改用btBGSecondary/btText/次级文字，保留56pt头像和原登录sheet。
- 登录账号卡将Pro状态从右侧窄胶囊移到卡内独立行，使用现有Premium token和星形；有效期可自然换行。读取既有entitlementStatusLabel，不改StoreKit/账号逻辑。
- Guest改前SE截图已归档output/v57/W6/guest-before-attachments；Pro原反馈R11-2已重看。当前聚焦测试运行中，不标W6完成。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §Changelog / DR-089。

## FL-048 — 虚拟账号界面测试触发真实云同步并被401退出

- **任务**：v57 W6，内存空库的Pro账号卡测试。
- **证据**：output/v57/W6/profile-r2-process.log，进程41221在21:34:19–20收到401；附件AX显示游客。AuthState虚拟身份完成登录后，AccountDataCoordinator在无游客数据时发起同步，APIClient认证失效通知清除该身份。
- **修正**：APIClient仅DEBUG且显式-v53.authenticatedProfileFixture时抛离线错误；虚拟身份不访问真实服务，正常401/刷新逻辑保留。R3原失败UI通过，截图已目视；真实认证仍由独立测试验收。
- **已应用至**：.cursor/rules/55-test-engineer.mdc §FL-048、UI-IMPLEMENTATION-SPEC Changelog。

## v57 W6 验收收口（2026-09-05）

R11中性游客卡和真实Pro状态完成；最终27单测、四组16 UI/44图通过并目视，Debug build与完整门禁通过。DR-089/FL-048，证据output/v57/W6/REPORT.md。Profile路由目标未改，签名上下文布局变动已审计并更新；原封面/诊断基线保留。固定字号、真实Apple/StoreKit与VoiceOver人工边界保留。W5/W7/W8未完成，未提交。

## DR-090 — 球库收紧保持球体及球桌占比（2026-09-06）

- **原因**：FL-047否决放大球体与增高底栏。新方案只收敛多余间距：8×44pt最大宽352pt，行额外间距3→0；compact30/regular36、94/140pt底栏保持。
- **范围**：共享交互/参考/装饰球库、AngleDynamic独立行同步；12个消费页初始化前亦使用同一宽度，避免临时铺满。两提球页原来即44pt固定槽，继承行间距调整，不增按钮行。
- **边界**：小屏接近44pt触控最小槽，收紧幅度小于宽屏；不得把所有页面仅查调用点就称视觉验收完成。3D取景仍未实施。
- **验证中**：output/v57/W5/proportion-preserving；首轮14单测通过，但UI selector不存在，实际0 UI，不算UI验收；已用真实testCompactShotStageRailsAndPaletteDoNotOverlap复跑。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md Changelog（2026-09-06）。

## FL-049 — 系统时间文本宽度造成锁屏文字缺失（2026-09-06）
用户真机反馈进度已动但文字消失；r1/r2系统截图印证。r3仅取消水平fixedSize后标题/数字恢复，但右侧仍挤压；r4用普通等宽模板测宽加动态Text overlay恢复所有文字。系统探针增加标题/品牌断言；四图已目视。已应用至.cursor/rules/20-swiftui-developer.mdc § FL-049、UI规格Changelog。保留全部过程证据，不以早期脚本通过代替视觉通过。

## DR-091 — 时间进度与单行灵动岛（2026-09-06）
- **用户最新方向**：大于1分钟锁屏数字正常；进度按剩余时间比例变化；灵动岛收紧，长按标题和时间单行。
- **实现**：锁屏系统ProgressView(timerInterval:countsDown:true)采用内置circular；r4展开态bottom单行仍被用户指出上方空白；r5将标题/时间分别放leading/trailing，bottom仅保留无重复时间标签的进度条，移除额外展开边距；紧凑态使用文字自然宽度。临时四种DEBUG对照变体已撤回，长休息入口fixture保留。
- **验证边界**：r4实际系统截图锁屏2:49→2:07圆环同步变化，完整文字和单行岛已核对。r5系统UI测试1例通过，4图已目视；展开标题/时间进入顶部两侧，锁屏2:47→2:05全文字保留。尚未完成全runtime/真机最终矩阵。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md § Changelog / DR-091。

## DR-092 — SceneAiming 三目标投影取景（2026-09-06，验证中）
- **覆盖**：v57 R02覆盖v8固定zoom=0近景的页面语义，保留每题确定性进场；AimPoint与其他enterAiming默认调用保留原契约。
- **实现**：AimingFramingSolver用SCNView实际投影及球/孔/标记包围体，对40/50/60度俯角和45/55度FOV求可行距离，75度作为显式回退候选；选择较大的最小球投影尺寸。拟合结果作为CameraRig可选题目姿态，动画结束和后续更新共用同一姿态，支持环绕和拉远。
- **触发**：SceneAiming提交题目修订号，AngleSceneView只在题目、球位、视口或键盘测得高度变化时求解；该页停用逐帧母球anchor，防止覆盖拟合结果。其他页不启用。
- **HUD**：局部辅助/答题44pt高、15pt字号；列高度96pt同步。BTTextActionButton默认尺寸不变。3D预留实际测得键盘高度与按钮列底部高度的较大值。
- **证据**：framed-pose-tests-raw.log 4测试通过（新投影/动画/环绕18场景及3旧相机测试）。SE2 UI/9图、标准手机最终4单测+1 UI/6图通过，15图已目视；仅局部验收，iPad/旧系统/固定种子完整矩阵仍待。实际使用SCNView本地坐标，不再预设Y翻转；旧r8诊断安全区结果仅保留历史诊断用途。

- **DR-092补验 04:29**：iPad/SE17新增15图已目视；生产矩阵215场景，两runtime通过。16模型球顶点验证发现母球表面标记超出物理R约0.192mm，增加0.25mm渲染包围余量，最终3单测通过；极端小球与窗口/手势UI仍待。

## FL-051 — 自动取景替换姿态曲线，漏验纵向升降
- **任务**：v57 W5，用户指出默认视角更低、纵向滑动只剩缩放。
- **根因**：framedAimingPose 固定 pitch、radius/height 同比缩放；求解器采用0.30m高度下限，低于既有0.45m瞄准配置。原测试只验横向环绕，未验纵向姿态变化。
- **修正**：用户再次打回额外叠加角度方案，撤销。恢复原22°–45°俯仰曲线与40°–50°FOV；自动取景只在原45°观察端求距离/居中，空间行程按取景结果缩放，最低观察高度沿用1.5m配置。首次/换题落观察端，手动仍沿原曲线升降。
- **证据**：vertical-before-raw.log，新增纵向测试1例1失败，pitch在滑动后仍为-40°；第一次改后3/4单测通过，持续渲染测试未等动画落定失败，且方案已被用户否决；最终 original-curve-tests-raw.log：4单测+1 UI通过（TEST SUCCEEDED）；包含215几何场景、18姿态、原曲线五档对拍、升降往返和生产renderUpdate持续帧保留手动状态。3张场景原图与6张真实训练页图已目视；仅iPhone SE/iOS26模拟器，真机手感待复验。
- **已应用至**：.cursor/skills/geometry-spatial-reasoning/SKILL.md §FL-051；UI规格Changelog。

## 2026-09-06 用户最终裁定：撤销自动取景
- 用户明确要求自动取景也恢复，效果不接受。已撤回DR-092相机方案及FL-051两轮后续方案。
- CameraRig、AngleSceneView恢复HEAD原文；SceneAiming恢复原enterAiming、锚定及键盘结构，保留球库宽度/辅助答题按钮修改。
- 新求解器和专用诊断测试移出编译目录并归档到output/v57/W5/withdrawn-camera；重新生成工程。此前自动取景测试是已撤销方案的历史证据，不代表最终交付。
- 回退验证完成：原相机3项单测通过；最终重新编译并运行3题真实训练页UI通过，6截图已核对。CameraRig/AngleSceneView与修改前HEAD逐字一致，证据camera-rollback-source.json、camera-rollback-tests-raw.log、camera-rollback-final-ui-raw.log。恢复旧视角与键盘覆盖行为，不再保证三目标自动入镜。 不再继续设计新取景方案。

## DR-093 — 动作卡已练次数靠右（2026-09-06）

- **用户裁定**：“已练 X 次”放在卡片右下角、贴住右侧。
- **实施**：BTDrillGridCard.metaRow 在类型与次数胶囊之间加入弹性留白，胶囊与卡片右内边距对齐；保持底部行、标题尺寸、计次口径及零次隐藏行为。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md § 2.3 / Changelog。
- **验证证据**：output/drill-badge-trailing/（改前/改后组件渲染及日志）。


## DR-094 — 训练浮层统一胶囊与底栏避让（2026-09-06）

- **用户裁定**：训练 / 继续 / 自由 / 继续+累计时间 / 休息+倒计时，共用紧凑等高胶囊；宽度按内容，右侧和下方等距；详情页不得挡住底部操作。
- **实施**：BTTrainingPill 固定高44pt、边距12pt，统一图标/文字/时间、实色、阴影、按压样式；删除持续浮动。BTTrainingPillOverlay 在窗口坐标读取可见Tab、安全区与页面实际操作栏，btTrainingPillObstacle 随可见生命周期清除占位。动作/计划/历史详情、会话底栏与试打底栏/右侧操作柱接入。
- **回写目标 / 已应用至**：.cursor/skills/swiftui-design-system/SKILL.md 训练浮层规范；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。
- **验证**：SE最终4 UI、17 Pro最终2 UI、计时语义2单测通过；截图发现返回Tab显隐迟于布局后已修复，并补足五Tab不相交与真正休息胶囊定位。最终证据 output/hud-unification/REPORT.md。

## DR-095 — 课程右侧完成进度（2026-09-06）

- 用户确认：右侧增加细线与每课小圆点，未完成白心、完成填品牌绿；原有课内点线保留。
- `PlanDetailView` 通过课程首行 bounds anchor 定位圆点，预留16pt轨道，阶段独立连接；折叠及课内明细变化跟随真实布局。
- 完成语义沿用现有课程显示状态（已完成/提前练过填绿，当前/未开始白心），不改变存储或推进逻辑。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §课程右侧完成进度 / Changelog。
- 验证：独立目录Debug `BUILD SUCCEEDED`；iPhone17Pro浅/深色及阶段折叠已目视；完整证据见 output/lesson-progress-right/REPORT.md。未运行完整自动化矩阵。

### DR-095 用户位置细化（2026-09-06）

- 右侧线改为贯穿每阶段课程区顶部至底部；圆点改用整张卡片 bounds 中心，随展开内容高度变化。保留8pt尺寸、完成色及原课内时间线。
- 详情Pro角标文字10pt改为btSubheadline.heavy（15pt），胶囊内边距12×8pt，保留黑金材质和安全区。
- 已同步 UI-IMPLEMENTATION-SPEC 的课程右侧完成进度与Changelog。验证证据：output/lesson-progress-right/revision2/REPORT.md。

## DR-096 — Pro角标与会员权益统一（2026-09-06）

- 用户要求计划详情右上角与外部一致，并在训练卡片、动作库、练习及统计按未购买/已购买区分闭锁和开锁。
- BTProBadge新增必传isUnlocked及prominent参数；上层观察SubscriptionManager并传入可复用卡片。收藏动作卡同步。统计分段右侧显示同款权益标志，历史锁定行复用。
- 计划详情删除封面私有纯文字proTag，使用导航栏topBarTrailing同款prominent，免除封面/导航安全区重复定位。
- 原付费门控保持；无障碍输出未解锁/已解锁。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §Pro角标会员状态；tasks/UI-IMPLEMENTATION-SPEC.md §Pro权益角标/Changelog。
- 证据：output/pro-lock-unification/REPORT.md；完成状态以报告实际结果为准。


## DR-097 — 记分完成键属于数字键盘内部（2026-09-06）

- 用户明确纠正上方独立完成按钮；撤销toolbar/FocusState方案，进球与总球使用私有UITextField桥接及UIInputView，底行完成/0/删除。
- 完成仅结束编辑，保留现有Binding验证和即时计分，不触发组次完成或休息。数字输入、粘贴限定ASCII数字。
- 固定记分框和按键使用标准类别字号；初版受模拟器辅助字号影响溢出，已修正并目视最终截图。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §2.11与Changelog。验证见output/score-keyboard-done/INTEGRATED-REPORT.md。

- **DR-096最终验证**：iPhone17Pro/iOS26.2最终2 UI通过，12张Free/Pro页面图及1张深色详情图已目视；额外工具栏玻璃背景已关闭。报告output/pro-lock-unification/REPORT.md，真机交易未验。

- **DR-094后续裁定（2026-09-06）**：带时间的胶囊去掉可见标题，只留图标+时间；无时间的训练/继续/自由保留文字，无障碍说明保留。SE计时/休息2 UI通过并目视，证据output/hud-unification/icon-time-only/；已同步swiftui-design-system与UI-IMPLEMENTATION-SPEC。


## DR-098 — 训练输入状态与心得流程分离（2026-09-06）

- 用户确认统一处理键盘遮挡，并明确训练中心得只写整场备注、返回继续训练。
- ActiveTrainingView键盘通知控制底栏显示；休息浮层按active/键盘/心得编辑状态退场，业务计时继续。
- VM新增独立编辑状态和进入/返回动作；心得sheet直接绑定trainingNote，避免原endTraining暂停计时并转总结。结束流程保留。
- 数字键改收起图标；本项心得有焦点限定的键盘图标；整场TextEditor独立滚动并使用safeAreaInset收起区。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §训练输入状态与心得 / Changelog。证据output/training-input-flow/REPORT.md。

## FL-052 — 心得sheet键盘工具栏缺失（2026-09-06）

- 首轮UI测试明确失败于trainingNote.dismissKeyboard不存在；录屏note-end.png显示键盘和正文已出现但工具栏缺失。
- 保留失败证据output/training-input-flow/ui-raw.log及failure/；改用焦点控制的safeAreaInset底部收起区，不使用等待时间掩盖工具栏缺失。
- 复验涵盖真实keyboard存在、编辑区≤收起区≤键盘上沿、收起后键盘消失、文字保留与返回训练。
- 已应用至：.cursor/rules/55-test-engineer.mdc §FL-052、UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-099 — 输入确认与显式保存心得（2026-09-06）

- 用户追加数字输入收键盘即勾选本组并开始休息；复用现有onComplete→handleCompleteSet→VM completeSet，不另起休息逻辑。Coordinator仅当前firstResponder可确认，行回调仅未完成组可执行，避免重复切换。
- 用户随后明确心得应收键盘后显示保存；放弃收起即已保存提示方案。TrainingNoteDraftView持有本地副本；保存才写回VM并返回，直接返回或dismiss丢弃副本，保留旧心得。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §输入确认与整场心得保存 / Changelog。
- 验证以output/training-input-confirm/REPORT.md最终结果为准；se-raw.log含被替换的提示方案，仅数字确认结果仍适用。


## DR-100 — 训练心得布局及动作衔接（2026-09-06）

- 依据用户最新两张截图和六项要求：整体心得保存缩为右侧按钮；单项心得取消四行上限；标题去除冗余进度；动作序号品牌绿。
- 完成当前动作最后一组即进入下一动作，不再等待休息结束。第一个动作原按用户指定向左滑返回总览；现按用户后续纠正改为右滑返回，左滑进入第二项（见下方补充）。
- “宽度自动增加”按上下文解释为固定页面宽度、内容高度随换行增长，避免横向溢出。
- 已应用至UI-IMPLEMENTATION-SPEC DR-100。最终验证见output/training-refinement/REPORT.md。

### DR-100 小屏自动化等待记录

首轮SE多行动作心得输入完成后，XCTest反复报告App animations complete notification not received，每个操作等待60秒；断言未失败，现场se-live.png显示六行及收起入口完整。保留se-raw.log，主动中止该未完成轮次，不计为通过。复跑将小屏文字测试在进入编辑前通过真实“暂停计时”按钮暂停，保留全部布局、保存/放弃断言；生产源码未改。标准手机运行计时场景与68单测已通过。此隔离不证明小屏持续计时状态已完成验收。


## DR-101 — 未开始训练直接退出（2026-09-06）

新增hasStartedTraining判断，计时启动标记保留至会话结束，并兼顾无计时记录数据。未开始的确认弹窗显示继续训练/退出；退出清理计时及休息后dismiss，不进入心得/总结。原已开始训练结束逻辑保留。

首轮编译遗漏计时标记声明（自动替换未匹配带Bool类型的原行），编译器明确报cannot find hasStartedTimer；已补声明。原test-raw.log保留，最终验证以final-raw.log为准。UI规格DR-101同步。


## DR-102 — 两层心得共用自动编号输入（2026-09-06）

使用BTNumberedNoteEditor包装UITextView，在delegate精确处理回车和空编号退格；markedText不改写，粘贴与普通段落保留。NoteNumbering纯函数使用NSRange/UTF-16，覆盖中文emoji、两位编号及中间插入/选择替换。SwiftUI使用同一绑定焦点保留收起与显式保存行为；本项高度继续自适应。新增源文件经Makefile xcodegen生成工程。最终验证见output/numbered-notes/REPORT.md。

DR-102截图复查发现FL-053：初版SE系统AX字体继承使UIKit输入巨字；已修正为页面标准字体类别，新增六行高度上限。此前SE测试通过不代表视觉通过，最终证据改用se-final/phone-final。


### DR-096 补充 — 退出登录收回当前会话 Pro（2026-09-06）

根因：SubscriptionManager只读取StoreKit/DEBUG持久开关，未订阅AuthState，退出不会收回权益。App初始化时绑定认证阶段；账号切换同步清空会员展示并增加会话版本，权益异步返回必须版本一致；重登刷新。游客购买/恢复提示先登录。DEBUG显式启动夹具保留，但账号退出后不能重新解锁。未改Apple交易、后端或账号购买归属模型。验证见output/pro-logout/REPORT.md。

DR-102最终：用户指出普通SE字号配置残留，simctl确认最大AX并恢复large。撤去小屏文字用例暂停计时临时隔离，默认字号+运行计时1 UI通过，无动画等待通知超时。17Pro最终1 UI及最终源码5单测通过；FL-053将环境遗漏与字体契约对齐分开记录。最终图phone-final/se-default已目视，未提交。


### DR-095 补充 — 右侧细线随完成进度变绿（2026-09-06）

连续完成前缀决定绿色线终点，部分完成止于最后连续完成课圆心，全部完成贯穿课程栈。非连续提前练过保留独立绿圈，不跨越未完成课。圆点尺寸、居中锚点及内侧原点线不变。验证见output/lesson-progress-green/REPORT.md。

DR-102图标对齐修正（2026-09-06）：按用户截图，将noteInputRow的HStack改为.top，仅调整文档图标与第一行对齐。验证证据output/note-icon-top/。

DR-100范围纠正（2026-09-06）：此前把“第几颗拿掉”误解为整行删除，用户明确球形和杆数要保留。恢复currentSetProgressText的显示，仅删除重复型的颗数部分；沿用走位链遍数/杆数，更新既有三项口径单测和数字录入UI期望。证据output/training-progress-restore/。


## DR-103 — 训练来源标题（2026-09-06）

ScheduledTrainingBlock解析既有冻结数据时提取计划全名/模版名称，ActiveTrainingViewModel统一trainingTitle供页头与导航使用；自由训练保留原文。计划安排的sourceTitle本来是课程名，不能直接用于该需求。旧plan入口以Bundle名称兼容，不扩展保存/分享语义。测试包含两种加入顺序的计划/模版标题及真实首页启动两种训练。证据output/training-source-title/。

DR-103首轮测试编译遗漏capture的try，已补齐并复跑；原test-raw.log保留，最终结果以final-raw.log为准。


## DR-104 — 今日安排统一标题与折叠行（2026-09-06）

用户四项要求：移除动作数/完成状态冗余副标题，历史记录改为与编排项目同款图标折叠行，标题按计划名与课号、模版名与模版、自由名与自由组合。TrainingHomeView共用trainingDisclosureHeader，历史展开后保留查看训练记录入口；计划优先冻结payload，旧记录无课号不臆造。单课默认展开但支持收起；历史参与多项判定。已应用至tasks/UI-IMPLEMENTATION-SPEC.md §今日安排统一折叠行及Changelog。验证证据output/today-schedule-unified/REPORT.md：最终17Pro浅色2项UI、SE深色2项UI通过；SE九状态回归通过，截图已目视。

DR-104测试校正：首轮误以为sheet打开会移除底层首页AX元素；实读原有sheet路由后改验详情累计进球和返回状态。第二轮发现既有xmark与文字关闭均使用“关闭”标签，依据失败AX树改为导航栏xmark标识。未修改产品弹窗、未放宽数据断言，两轮失败日志均保留。

DR-104小屏测试校正：九状态及详情返回已通过，历史行定位因单向大幅swipe越过目标失败；导出xcresult录屏确认已滚至计划货架底部。按已有视口定位模式改用实际行frame与顶部/浮层边界做双向有界拖动，保留失败与录屏，不改产品布局来迎合测试。


## DR-105 — 今日安排独立展开与统一明细（2026-09-06）

用户要求三来源展开样式一致、支持同时点开全部且默认折叠。根因是历史与编排的明细各自实现，且单个UUID充当手风琴状态。改为Set维护每项展开，共用明细行，模版/自由明确标类型、一组亦显示组数；编排通过既有会话关联补查看训练记录。未保存项不制造记录。已应用至tasks/UI-IMPLEMENTATION-SPEC.md §DR-105及Changelog；验证见output/today-disclosure-multi/REPORT.md。


## DR-106 — 键盘收起入口尺寸（2026-09-06）

用户指出整场心得收起键盘太小，并要求处理同类入口。根因为18pt图标与UIKit默认工具栏符号尺寸，整场原44pt布局也未显式覆盖透明命中区。三处改为共享28pt半粗品牌绿图标，心得56×44pt命中；数字键盘保留原按键尺寸。已应用至tasks/UI-IMPLEMENTATION-SPEC.md §键盘收起尺寸及Changelog。验证结果见output/keyboard-dismiss-size/REPORT.md。

DR-105最终验证：同源码17Pro浅色2 UI、SE深色3 UI通过（TEST SUCCEEDED），23图已目视；包含三来源记录打开/返回、多项开关、单项和建议默认折叠、九状态。首轮后并行输入组件变更已通过标准手机同步补验覆盖，未回退其他任务改动。真机/iPad/AX未验，未提交。


## DR-107 — 今日安排优先级、记录关闭与完成摘要（2026-09-06）

根因：编排先按原orderIndex全部输出，建议后插；sheet外层重复添加关闭文字；摘要完成态仍累加计数与时长。用户要求未完成/建议置顶、记录只留X、全部完成只留提示。实施仅在TrainingHomeView展示层分组、移除外层toolbar、完成态互斥输出；未改持久队列和统计算法。已应用至tasks/UI-IMPLEMENTATION-SPEC.md §DR-107与Changelog。验证见output/today-order-summary/REPORT.md。

DR-107最终：iPhone17Pro/iOS26.2/Light/large两项UI通过（TEST SUCCEEDED），6图已目视；源码无漂移，git diff --check与文档体积门禁通过。未做本轮小屏/深色/真机验收，未提交。


### DR-100 手势方向纠正（2026-09-06）

用户纠正此前左右方向描述：首个动作右滑回动作列表，左滑到第二个动作。ActiveTrainingView仅反转首项返回的水平位移判断，保留阈值、手势起始索引、纵向及键盘保护；原UI测试更新为左滑第二项、右滑第一项、再右滑列表的连续流程。已应用至tasks/UI-IMPLEMENTATION-SPEC.md §DR-100及Changelog；证据output/training-swipe-direction/REPORT.md。


## DR-108 — 今日自由训练按日编号（2026-09-06）

用户要求同一天的自由训练区分“自由训练 · 第1次”等。TodayTrainingProjection增加只读编号映射，按时区自然日、当前归属、真实drill记录筛选，再按日期/UUID排序去重；首页已保存独立自由与关联编排共享序列。计划与模版不占号，未保存不虚构次数。已应用至tasks/UI-IMPLEMENTATION-SPEC.md §DR-108及Changelog；验证见output/free-training-ordinal/REPORT.md。

DR-108最终：1单测+2 UI通过（TEST SUCCEEDED），6图已目视，源码无漂移。验证跨日重置、来源/归属筛选、去重、同时间稳定编号与第1/2次各自记录导航；17Pro/iOS26.2浅色，真机未验，未提交。


## DR-109 — 今日安排与计划逐动作入口（2026-09-06）

用户要求今日安排恢复动作图标并可进入详情、返回原页面，计划既有入口补轻量可点击提示。共用trainingDrillRow新增drillID并用原TrainingRoute.drillDetail导航；复用40×20烘焙缩略图、右箭头、44pt整行命中，剂量放名称下方保留阅读空间。覆盖编排/历史/官方建议。计划缩略图右下角补右箭头小标，行内间距收紧、长名称允许换行，保持球形展开独立。已应用至tasks/UI-IMPLEMENTATION-SPEC.md §DR-109及Changelog。验证见output/today-drill-links/REPORT.md。

DR-106用户尺寸微调（2026-09-06）：用户认为28pt偏大，共享图标调整为24pt，56×44pt命中区及半粗/品牌绿保留。UI规格同步，最终证据output/keyboard-dismiss-size/refined-raw.log与refined/。


## DR-110 — 动作图与双箭头整体排版（2026-09-06，FL-054返工后）

今日安排：状态、自然宽度来源文字、64×32球台图、名称/剂量、右侧居中箭头。来源与图之间仅常规8pt，不预留固定类型列。计划：左侧64pt图片列内放图、弱序号及多球形展开按钮；名称、球形数和各剂量共用右侧文字列。剂量为连续文本，优先单行，不拆成独立字段竖列，也不另起到图片下方。文字列末尾统一详情箭头，按多行整体居中；图片与正文都可进入同栈详情，返回保持展开状态。保持正常字距字号。取消曾尝试的左侧44pt空占位及下方通栏剂量方案，旧截图不得作为最终视觉证据。验证见output/drill-layout-aligned/REPORT.md。


## DR-111 — 图列对齐、稳定折叠与每日计划建议去重（2026-09-06）

今日安排使用52pt右对齐类型列，类型与64×32图之间8pt，图和名称各自同列；不使用左对齐短类型造成大间隙。计划动作删除01/02序号，根行和图片按顶部对齐；标题/球形数量位置固定，切换仅增减剂量内容，详情箭头仍对多行内容居中。

官方自动建议按当前owner、本地日期、planId去重：当天任何已编排课（含完成/放弃）或独立训练历史已含该计划，则不再提示下一课；切其他未编排计划仍显示建议，次日重新计算。昨日补入共用carryForwardCandidates，排除今日已有计划和已有其他来源，完成项也参与去重；提示数量与写入使用同一筛选。手动计划页主动编排/复练契约保持；不自动删除既有重复记录。测试见output/drill-align-dedupe/REPORT.md。


## DR-112 — 今日安排标题分隔点对齐（2026-09-06）

名称不超过4个字时，保持左对齐并按当前标题字体的4个汉字宽度预留，后缀分隔点共用同一横向位置；超过4字维持整段自然排版。使用隐藏四字文本度量宽度，不补空格、不截断名称，保留完整辅助功能标题和原折叠/导航行为。验证见output/schedule-title-dot/REPORT.md。


## DR-113 — 模版卡片动作分列与整次训练计数（2026-09-06）

按用户最终裁定：首页「我的模版」与计划列表共用BTTemplateCard。封面保持正方形，先给动作列预留当前字体七个汉字宽度，再用剩余空间放大封面（最大112pt）；不压缩字间距。两列按行排列（第1/2个同一行、第3/4个下一行），6个以内动作区域预留三行、标签在第四行；7/8个动作占四行、标签第五行，更多动作自然顺延；品牌绿圆点、单行动作，超出七字截尾但辅助功能保留完整名称。方图顶边与模版名称顶边对齐；标题/菜单行收为24pt，首行动作紧接标题，去掉此前44pt标题行造成的空白；标签前间距8pt，动作区与标签共上移约一行。标签减薄；右侧动作区下方只保留「已在今日安排」「已练N次」，移除模版标签。宽度不足时状态标签自然换行。封面/标题/动作区均可编辑，菜单与标题为独立同层控件，避免叠在编辑按钮命中区。

TemplatePracticeCounts按当前owner的非空drill类型TrainingSession计数，每个模板会话UUID一次；显式template来源使用sourceId（缺失时planId），旧记录nil来源兼容UUID型planId。加入队列或浏览编辑不增加次数，零次数隐藏，删除记录后随Query刷新。动作库仍使用原DrillPracticeCounts按DrillEntry累加，不改其口径。

首轮方形+通栏标签方案计数单测通过，但叠加菜单在返回后短暂打开又消失；保留失败证据se-raw.log/xcresult录屏。改成菜单与标题并列后，两入口菜单/编辑/重复加入UI复验通过；后续恢复方形后的最终证据见output/template-card-layout/REPORT.md。竖向封面与通栏标签旧截图不作为最终版本。

- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md §DR-113及Changelog；BTTemplateCard/BTTemplateStatusRow API。

DR-113补充：新建模版入口改为居中、内容宽度的紧凑按钮，高度至少44pt；保留原新建导航。去除原通栏灰色按钮背景。

## DR-114 — 五个 Tab 共用几何线稿背景（2026-09-06）

- **需求**：用户确认将训练页现有瞄准圈、虚线路径、刻度与圆弧延伸至其他四个 Tab。
- **实现**：新增 `BTBlueprintBackground(style:)`，含 training/library/practice/history/profile；训练构图沿用原实现，动作库/练习边缘布局，记录无虚线，个人页仅瞄准圈与圆弧。统一 btBG 底色、btPrimary 线色、Dark 0.13 / Light 0.08 与 1pt 描边。页面背景位于滚动内容后，不占布局、不响应点击、不进入无障碍树。
- **范围**：仅五个 Tab 根页及共享组件；XcodeGen 注册新文件。原有并行变更保留。
- **验证**：证据与最终结论见 `tasks/ui-reviews/UR-20260906-tab-blueprint.md`；复用五 Tab 导航回归，新增真实页面截图采集与内存数据/系统外观前置。
- **已应用至**：`.cursor/skills/swiftui-design-system/SKILL.md` § Tab 根页线稿背景；`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog。


## DR-115 — 启动直达主界面，训练数据云同步单独选择（2026-09-06）

- 用户裁定：不要“恢复账号”或登录阻挡，主动在「我的」登录；拒绝云同步必须阻止上传和下载。
- 变更：RootView 常态主界面；AuthState 按账号本地持久化未知/开启/关闭偏好，后台认证不弹选择；设置开关；游客迁移另询。协调器及请求前/返回后门禁；启动异步结果不得覆盖新登录。
- 依据：ADR-P2-20260906；数据契约 §2.5、信息架构末尾修订。
- 验证：最终47单测、两设备共4次UI通过（TEST SUCCEEDED），8张改后截图已目视；真实Apple/双设备/iPad/深色同步控件/AX未验。证据 `output/account-sync-choice/REPORT.md`。旧401/refresh响应凭证校验亦纳入APIClient及2项新增回归。
- 已应用至：`.cursor/rules/30-data-engineer.mdc` § 同步同意门禁；`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog。


## DR-116 — 我的普通菜单图标中性化（2026-09-07）

- 用户裁定：除头像、会员与订阅外，普通菜单不再填品牌色。
- 实现：ProfileMenuRow 默认 tint 从 primary 改为 neutral；收藏、个人信息、训练目标、关于与反馈与偏好设置统一。会员显式 accent 保留。
- 验证：Debug BUILD SUCCEEDED；iPhone17Pro/iOS26.2游客页Light/Dark前后4张截图已目视，文字布局保留；无业务变更，未新增测试、未测真机。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md § 我的菜单配色 / Changelog。证据 output/profile-neutral/。


## DR-117 — 角度训练辅助瞄准线延伸到球桌（2026-09-07）
- **用户要求**：2D和3D角度训练点击辅助后的瞄准线延伸到球桌。
- **调整后**：白色瞄准线从母球沿假想球方向延伸到台呢边界。辅助调用显式传 `extendStrikeLineToRail: true`；共用射线算法新增 `inset`，默认仍为球半径，教学延伸取0。
- **回写目标 / 已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog / DR-117；API参数在 `AngleTrainingScene.updateVisualization` 原位说明。
- **验证**：见 `output/angle-assist-rail/REPORT.md`，以实际记录为准。


## DR-118 — 假想球可见标记与球心同高（2026-09-07）
- **用户确认**：假想球虚线圈及中心标记抬到台面上方一个球半径。
- **根因**：父节点已在球心高度，但圆环子节点局部Y为-R+2mm，中心标记为-R+4mm，导致可见标记落在台呢附近。
- **实现**：两者局部Y统一为0，沿用父节点的台面+R高度；共享假想球节点的消费者同步生效。
- **已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog / DR-118，以及节点定义原位注释。
- **验证**：见 `output/ghost-center-height/REPORT.md`，以实际记录为准。


## DR-119 — 真实截图引导与列表式 Pro（2026-09-07）
- **任务**：用户确认“合适截图放进去”“Pro 版本还是用列表”“先搞一个版本”。
- **描述 / 原始规范**：旧引导为三页示意图并耦合登录状态；旧付费页强制深色，包含与当前门控不符的自定义计划、分享和云同步权益描述。
- **调整后**：四页真实裁切截图（瞄准点、动作详情、自由走位、分组记录），在我的提供“认识球迹”；跳过和完成只关闭介绍。保持启动直达首页。Pro 改为五项权益列表、三套餐、固定绿色购买按钮，跟随浅深色；游客先登录并保留所选套餐，使用 StoreKit 返回价格。示例记录和 Pro 工具明确标注。
- **原因**：用户要求与 App 整体一致，并基于现有可用功能讲解，不将免费能力包装成付费权益。
- **日期**：2026-09-07
- **已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`docs/05`、`docs/08`；详见 `tasks/ui-reviews/UR-20260907-onboarding-pro-v1.md`。


## DR-120 — A2 五页深色引导试装（2026-09-08）
- **用户确认**：选择 A2，第三/四页真实感球桌，第四页横向蛇彩围8，并要求放入 App 看效果。
- **调整**：认识球迹扩为五页，沿用可选 sheet；引导独立墨绿/暖白色板，内置 OFL 思源宋体子集可缩放标题，原生分页/继续/跳过；A2 位图仅用作图解，布局不改变账户状态。
- **范围**：仅引导页使用固定深色品牌表面；其他页面保留原外观策略。生成球桌仅表达产品介绍，不用作物理教学精度证据。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md Changelog / DR-120；.cursor/skills/swiftui-design-system/SKILL.md 引导特例；docs/05 可选产品介绍。
- **验证**：output/onboarding-app-a2，构建及 UI 结果以最终报告为准。


## DR-121 — 训练辅助立体假想球与小点分色（2026-09-08）
- **用户裁定**：3D 角度训练辅助开启同现球杆；假想球为母球同尺寸半透明乳白球，瞄准点青蓝、接触点橙黄，直径约减半。
- **实现**：`setupVisualizationNodes(usesTrainingAssistStyle:)` 显式启用训练样式；默认消费者保留旧圈与配色。球心沿用 DR-118；球杆跟随当前观察 yaw，关闭辅助/结果/换题清理。两点按真实投影位置作为覆盖标记，保证半透明球和目标球不吞掉小点。
- **瞄准点页**：按 3D 瞄准点训练解释，保留既有球杆、G1 垂足和射线球面交点定义；未新增辅助开关或假想球。其 2D 共用页及近区特写同步小点配色。独立拖圈练习不变。
- **回写目标 / 已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` § 训练辅助 / Changelog；颜色与半径真源 `TrajectoryStyle.TrainingAssist`。
- **验证**：见 `tasks/ui-reviews/UR-20260908-training-assist.md`；模拟器结果不外推真机。


## DR-122 — 记录页分段标题图标（2026-09-09）
- 用户要求历史/统计文字前加图标；复用 BTIcon.clockHistory / chartBar。
- BTSegmentedTab 新增可选 systemImage，默认 nil；图文共享原字体/配色，图标不重复朗读。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §2.7 / Changelog。
- 验证证据：output/history-tab-icons/，最终结果见 tasks/ui-reviews/UR-20260909-history-tab-icons.md。


## DR-123 — 统计 PRO 角标留位与顶部对齐（2026-09-09）
- 用户确认：保留右侧边距，将图标与统计略左移，PRO 顶部对齐文字。
- 根因：整栏 trailing overlay 不参与宽度分配，并受下划线影响垂直居中。
- 实现：BTSegmentedTab 可选 proBadgeState，按固有宽度留位，8pt间距和顶部对齐；可见角标独立无障碍元素保留。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §2.7 / Changelog。
- 验证：见 tasks/ui-reviews/UR-20260909-statistics-pro-alignment.md。


## DR-125 — 角度预测本轮表现（2026-09-09）

- 后续用户要求按误差着色：最近每题与当前结果共用 `AnswerRecord.rating` / `ErrorRating(error:)`，≤3° 为 btSuccess，>3°且≤10° 为 btWarning，>10° 为 btDestructive；按未舍入绝对误差判定，最新题只额外加粗，原偏大/偏小文字保留。验证证据 `output/angle-error-colors/`。

- 用户确认保留现有题面样式，在无键盘的下半区展示最近5题；不采用生成式整桌候选。
- 复用 `sessionResults`，最新在前，展示估角、实际角度与方向偏差；不足5题按实际数量显示，未答题显示轻量引导。
- 键盘期间隐藏该区域及其无障碍元素，保留布局占位避免滚动位置钳制造成题面跳动；取消或提交后恢复。换题保留本轮成绩，重置沿用原清空行为。
- 小屏首轮检出固定320pt画布遮挡操作，改为由可用高度扣除实测统计/操作/键盘高度与间距计算画布高度（上限320pt），无键盘时同样预留以稳定题面。SE原失败与修复复验均保留于证据目录。
- 已应用至：`GeometricAngleQuizView.swift`、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；实际验证见 `tasks/ui-reviews/UR-20260909-angle-recent-results.md`。

## DR-124 — 今日课程加入与多选连续训练（2026-09-09）
- 用户要求推荐课只加入、课内开始文案统一，以及今日多项未完成时自主勾选/排序后串联。
- 推荐入口“加入今日安排”；唯一未完成项直接开始，多项进入本次临时选择sheet，排序按钮提供上移/下移，取消不更改编排。多课动作不去重，来源用稳定动作身份归属；追加动作归本次末课，删掉必练动作不提前完成该课。
- 单场UI对应每课一条冻结来源记录，一次事务保存课程完成/计划游标/同步队列。部分完成保留记录不推进；后续完成仅最终记录计入今日课程动作数，避免重复累计。整场分钟分摊后保持总和。
- 已应用至：`docs/05-信息架构与交互设计.md` §今日编排、`.kiro/steering/content-data-contract.md` §9.2、`tasks/UI-IMPLEMENTATION-SPEC.md` §Changelog（2026-09-09）。
- 验证：`output/course-selection-20260909/`；最终验收范围见 `tasks/ui-reviews/UR-20260909-course-selection.md`。


## DR-126 — 本周训练时段摄影与头像玩法球（2026-09-09）
- **用户裁定**：参考正绿色台呢不随时段换色；晨光/日间光/夜间灯罩感。批准在App试装。
- **实现**：训练卡摄影背景与原生紧凑周进度/日历分离（按追加约束恢复原布局，移除增高的圆环）；沿用真实周数据与每日清台路由。当地06–11/11–18/其余对应三张素材，分钟刷新；DEBUG预览覆盖不改时钟。头像读取dailyClearanceGame，中八黑八，其他九号，普通菜单不变。
- **回写目标/已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md § DR-126摄影训练卡与Changelog；2026-09-09。
- **验证**：构建成功，时区边界与全部玩法素材2项单测通过；最终紧凑版SE浅色UI及5截图通过，标准手机浅深图审及清台入口已验；原宽高布局恢复，最终证据见tasks/ui-reviews/UR-20260909-daypart-implementation.md。


### DR-126 追加：登录卡局部背景
- 用户指定仅游客头像登录卡增加背景，保持宽高与原布局。独立image_gen生成空台面，沿用原球体overlay；深色压暗，其他卡片不变。
- 验证与素材提示词：`output/profile-header-backdrop-20260909/`。

- 后续用户否决浅色拼贴，改为同周卡整体绿色摄影：球与桌面共同生成的profilePhoto8/9，guestHeader移除球overlay、文字白色；只替换该卡装饰，不改变布局。提示词prompt-photo-v2.md。


## 模版封面同批调色补齐（2026-09-09）
- 用户授权我的模版封面一起更新；coverTemplate02/03/07/09/10/11/12使用内置image_gen保留球/杆/桌/构图，仅改同#197009草绿细台呢；01/04/05/06/08灰白静物不变。
- 原资源名称、UUID哈希映射、卡片布局保持；12/12 SHA核对。原图与generated/edited交付证据在output/template-cover-felt-20260909/。

- 模版07后续用户指出漏球号：仅该图补红3/黄1/蓝2/紫4，白球保持红点；修正“台呢全量更新”等于“球号全部修好”的表述。number-fix目录保留前后图、提示词与新哈希，原delivery-manifest为调色批次当时记录。


## 24封面球号批修（2026-09-09）
- 用户明确批准核验清单24项批修；23项按美式/中八配色补/纠号码，斯诺克封面改无号码球及纯白母球。使用当前台呢正式图编辑，原背景/构图基本保留；静物灰白背景不变。
- 24项均逐图目视，60/60 SHA核验，24替换36不变。输出/完整提示词/比较页：output/cover-number-fix-20260909/。原卡片布局/UUID封面映射不改。


## DR-127 — 本周训练卡片最终摄影与米白控件（2026-09-09）
- **依据**：用户从“优化继续清台按钮”延续并明确要求实现；最新标准比赛绿参考优先于此前墨绿候选。
- **变更**：训练周卡复用原布局、数据、清台路由与时段解析；共用最终摄影与轻度时段光照。新增米白/深绿命名色；按钮和已完成圆点同色，今天10%深绿底。照片构图修订后白球避开实体按钮，分隔线保留占位而隐藏。
- **回写目标/已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` § DR-127 与 Changelog（2026-09-09）。
- **验证**：最终Debug构建已通过；局部UI/图片与局限见 `tasks/ui-reviews/UR-20260909-weekly-training-final.md`。原有dirty工作保留，不提交/发布。

## DR-128 — 登录弹窗绿色台呢与真实台球摄影（2026-09-09）
- 用户确认以绿色台呢和真实台球风格延伸登录视觉。
- LoginView 的208pt品牌图替换为既有BTTrainingAtmosphere照片、米白标识/说明；保留外围布局、文案及认证行为。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-128 与 Changelog（2026-09-09）。
- 验证：BUILD SUCCEEDED；17Pro浅色/SE浅深整页目视；SE暂不登录返回与重开通过。真实Apple登录、真机/iPad/AX未验。证据 output/login-photographic-20260909/。

## DR-129 — 动作卡已练次数去品牌底（2026-09-09）
- 按用户截图要求删除BTPracticedBadge绿色底和胶囊裁剪，白字改btTextSecondary；保留勾选、字体、padding及计数逻辑。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-129 与 Changelog。
- BUILD SUCCEEDED；17Pro/iOS26.2浅深色整页原图已审，布局无变化。证据output/practice-count-plain-20260909/；真机未验。

### DR-129 后续确认：品牌色文字
用户批准勾选与已练次数改为btPrimary，字重从bold/heavy降至medium，保持无底色。BUILD SUCCEEDED；17Pro浅深色整页已目视，次数1/2/5/6正常；证据output/practice-count-brand-text-20260909/。已应用至UI-IMPLEMENTATION-SPEC.md §DR-129及Changelog。

## DR-130 — 我的游客登录卡纯白背景（2026-09-09）
- 用户否决绿色台呢强背景，指定纯白；guestHeader移除整体摄影背景，复用透明BTProfileGameBall装饰，深色语义字和浅色头像。卡片局部light环境保证白底可读，不影响整页主题。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-130 与 Changelog。
- BUILD SUCCEEDED；17Pro浅深色整页截图已审，点击登录弹窗正常。证据output/profile-white-card-20260909/；真机/iPad/小屏未验，未提交发布。


## DR-131 — 瞄准特写等待真实松手（2026-09-10）

- **问题**：台面及共享瞄准轮最后一次有效移动280ms后即隐藏，手指停住不松开也触发。
- **实现**：Gate按table/wheel保存活跃手势，最后释放才计时；AngleSceneView补完整生命周期，BTAimWheel补取消/离页收尾，AimPoint页移除重复计时并复用Gate。
- **范围**：2D/3D瞄准点训练、自由击球/每日清台非开球阶段、自由走位/试打、分离角与走位、翻袋/反射自由模式。近区判定与画面几何保持原契约。
- **验证**：详 `output/aim-closeup-diagnosis-20260910/` 和 `tasks/ui-reviews/UR-20260910-aim-closeup.md`；以最终记录为准。
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3瞄准特写手势生命周期 / Changelog。
- **已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` §9.3 / Changelog（2026-09-10）。


## DR-132 — 训练瞄准线白色与观察/击球方向分离（2026-09-10）
- 用户明确纠正 DR-121：瞄准线白色，转相机不能转球杆，2D辅助也显示杆；核对假想球尺寸及相关页。
- 删除辅助杆逐帧跟随相机 yaw 的状态与回调；辅助开启/刷新后沿母球到假想球摆杆，继续复用击球点与避障抬杆。关闭辅助、结果、换题清理不变。
- TrainingAssist.aimLine 改白；2D/3D瞄准点训练与特写同步；结果参考线白虚线区分用户白实线。假想球保持R=28.575mm，仅不透明度32%→50%，不改碰撞/球位。
- 实测模型球直径约56.8–57.5mm，标准假想球57.15mm；模型网格细分/母球红点导致的小差异不足1%。未用放大半径修正透视。
- 最终2单测+4UI通过，标准17Pro关键原图已审；结果见 `tasks/ui-reviews/UR-20260910-aim-assist-fix.md`。改前3D开关失败、r2测试测量/流程失败保留；真机/iPad未验。
- **回写目标/已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` §训练辅助 / Changelog；2026-09-10。


## 2026-09-10 — v59 W0 停球状态前置修复与覆盖诊断

- 根因实证：零时长 slide/roll/spin 转换被 `>0` 过滤；速度为零仍保持 spinning，延长60秒不收敛，终态不可供示范准入。
- 修改：EventDrivenEngine 接纳解析零时长转换，全部停稳即结束；新增 PhysicsRestTransitionTests，诊断默认通过RUN门关闭。无物理常量/评分/页面变更。
- 验证：修复前3项9断言失败；修复后停球/不变量/一致性17项及物理引擎33项/矩阵3项通过。471冻结球形复扫通过，11次逐速度事件差异保留，不宣称只是动画时长变化。
- 覆盖：距离补采纠正了收窄参数导致的fallback误标样本，原失败保留；最终67合法新球形仍有9个中袋距离组未找到可用示范。W0诊断完成，W1覆盖准入未通过，需按v59.3裁定。
- 证据：output/aim-point-theory/W0/REPORT.md、各原始日志与JSON；未提交发布。


## DR-133 — 仅绿色系列训练进球线及文字改白（2026-09-10）
- 用户确认只改易混淆颜色及进球线/瞄准线文字，不全球号改白。
- TrainingAssist.potColor仅6/14返回白色，其余走原potColor；AngleTrainingScene训练样式的进球线/同名标签、AimPointScene进球线及训练特写同源。“瞄准线”文字本已白色，保持。
- 默认教学、求解、多球轨迹及模型球颜色不变。现有布局、线型、球位、相机、显隐不变。
- 验证完成：构建及4项定向测试通过；全15球号×训练/默认场景线与文字颜色断言通过，6/14/3号的2D/3D共6张真实SceneKit渲染原图已审。证据 `output/green-pot-line-20260910/`；本轮不是完整App UI流程，真机/iPad未验，未提交发布。
- **回写目标/已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md` §训练辅助 / Changelog。


## FL-055 — 皮革子网格保留整桌缓冲导致 iOS 17 日志洪泛崩溃
- **任务**：v60 W1，2026-09-10。
- **现象**：几何结构测试和部分首帧通过，但连续进入每日清台/打三时于 `__C3DMeshDeindex` → libtrace runtime-issue callback 崩溃。
- **根因**：每个皮革子网格仍引用整桌177346个位置；iOS17逐个报告未被元素引用的顶点，15秒日志26万余行，触发高日志量隔离回调。不是模拟器资源不足，也不能靠禁用诊断解决。
- **解决**：逐独立索引通道压缩到实际使用的属性，逐字节保留每个多边形角点的位置/法线/UV和面序；缓存紧凑几何，实例材质隔离。新增全角点字节守恒与无未使用位置测试，iOS17三个实际页面复验通过。
- **证据**：`output/pocket-leather-integration-20260910/W1/compact-fix/`（最终归档）；首次日志/崩溃另存，未删除失败记录。
- **已应用至**：`.cursor/rules/20-swiftui-developer.mdc` SceneKit兼容性要求。


## DR-134 — 六袋原皮革选中反馈（2026-09-10）
- **任务/原始规范**：v60，红色圆盘遮盖袋洞；打三另绘双色袋环。
- **调整后**：原USDZ的Leather面在加载后分为六袋，保留面角属性和原位。单目标采用btAccent深色暖金在线性空间混合65%原贴图；打三①绿/②青，同袋分区。恢复原材质，不重叠绘制、不覆盖洞口/网圈，不改物理袋心或历史资源。
- **状态/API**：既有addPocketMarkers/setPocketHighlight调用共享替换；setPocketRoles和clearPocketHighlights支持双角色及清理。清桌、无目标、自由/开球、逐杆恢复与角色推进由当前状态驱动。球优先命中；六袋AX自定义动作沿用各页选择权限。
- **原因**：将选中状态落在真实皮革，保持台桌完整和角色含义；预制材质变体避免渲染中修改材质。
- **验证**：见 `tasks/ui-reviews/UR-20260910-pocket-leather.md`（22类场景、标准/SE/iPad/iOS17回归及最终构建/门禁完成）。
- **已应用至**：`tasks/UI-IMPLEMENTATION-SPEC.md`；SceneKit故障护栏见FL-055。

### 2026-09-10：中袋近沿对齐校准

- 两中袋孔心改为实测近侧洞壁632.96474mm+原43mm半径；物理孔、理论瞄准、视觉交互中心共源。独立保留688mm喉壁连接常量，碰撞墙、圆角、半径、反弹系数和皮革不变。
- 4080次固定球路对照：原值/前移9mm/近沿对齐分别410/510/580进球（各1360杆），无原进变不进、未停稳或两侧不对称。
- 51项定向回归通过，再追加2项挂袋/近袋角碰撞/实际点选验证通过。测试构建通过；未完整UI矩阵/真机/重扫v59球形，未提交发布。
- 证据：`output/middle-pocket-alignment-20260910/compare/REPORT.md`。诊断RUN标志关闭。


## DR-135 — 我的概览、菜单与默认玩法（2026-09-10）

- **用户裁定**：本月概览数字/单位分级，三项浅绿/浅蓝/浅暖橙；收藏、设置改短名称，认识球迹位于关于与反馈之上；默认玩法初始跟随个人信息，尊重后续手动选择。
- **实施**：概览直接接收整数，保留训练统计口径与原AX标识；极窄长值采用紧凑数据行。UserPreferences 读取当前 owner 资料，显式选择与自动推导分键持久化；资料提交成功才联动。旧显式偏好、已有草稿与完成状态保持。
- **验证**：证据与失败边界详 `tasks/ui-reviews/UR-20260910-profile-refinement.md`；并行瞄准/球桌几何工作未纳入本任务改动。
- **回写目标**：`tasks/UI-IMPLEMENTATION-SPEC.md` § DR-135 / Changelog，`docs/05-信息架构与交互设计.md` § Tab 5。
- **已应用至**：上述两处（2026-09-10）。

## DR-136 — 当前视角瞄准特写与实时理想方向（2026-09-10，v61）
- 用户授权：特写与3D投影一致；自由瞄准增加浅灰无箭头直虚线，止于首次库袋事件；瞄准点练习不加方向层。
- 实施：SCNView真实投影+统一屏幕放大，投影焦点及走廊避让；可见时刷新。球体深度缩放按同一投影计算。理想方向共用生产库袋零加速度求交，不启动整杆预测。
- 生命周期：三条ViewModel路径共用方向层；最新预测接替，旧解代际保护保留；解球器自由模式隐藏旧参考路线；minimal档隐藏新方向层，档位由ViewModel传入避免跨主线程隔离读取。模式/播放/开球/序列清理。
- 验证：最终45项功能/几何/布局单测通过；SE3/iOS17与iPad/iOS26.3各3项UI和5张按住原图通过。标准机最终10项UI通过，17张按住原图已审；构建、diff及文档体积门禁通过。小屏真实坐标回归覆盖更近的无遮挡空位选择；临时诊断代码已移除。
- 证据：output/aim-preview-v61/；范围及边界详 问题集合_v61.md。未提交发布。
- **回写目标/已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md §v61 当前视角特写与理想方向。

## DR-137 — 训练心得按日日记页（2026-09-10）
- **需求**：用户最终批准轻纸感日记稿，取代单列表分隔线与此前按会话卡片提案。
- **设计**：当天一页，衬线日期数字、品牌绿短线、语义纸面与轻叠页边缘；正文与导航沿用系统样式。列表显示最多两次摘要，详情显示当天全部有效心得，搜索不截断详情。
- **交互**：原页统一编辑整次与动作心得；取消不落盘，整天变更一次事务保存；补记不展示合成时间；空编号仅显示过滤。
- **组件**：新增 btJournalPaper（浅暖白/深灰）和 btJournalDay，仅用于心得日记；未改全局正文或其他页面背景。
- **验证**：见 output/notes-cards-20260910/ 与对应 UI 审查报告；范围为本地代码/模拟器，不含发布。
- **规则改进建议 / 回写目标**：tasks/UI-IMPLEMENTATION-SPEC.md 日记专用组件与 Changelog。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md § 训练心得日记页 / Changelog（2026-09-10）。

## DR-138 — 手机3D材质隔离实验候选（2026-09-11，v62）

- **授权**：用户执行v62全部任务，固定背景/镜头/几何，动态至少60fps；尚未认可最终画质。
- **实施**：场景显式mobileRendering默认false，3D角度诊断入口可选；共享材质保留旧默认。原创HDR与台呢原粗糙度、单投影参数候选独立，不调用旧增强整包。DEBUG或专用RENDER_QUALITY_VALIDATION可固定题目；普通Release无诊断入口。
- **验证与限制**：实际两Runtime目标页、材质/相机隔离及皮革功能测试通过；球底分离与暗部/木框仍弱，画质未最终通过。真机锁定且设备矩阵缺失，未接正式默认、未改最低刷新策略，v62整体未完成。
- **回写目标/已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md §v62候选隔离；证据见 tasks/render-quality-v62/README.md。


### DR-138 v62.2补记（2026-09-11）

用户新增目标先在模拟器达到效果。按实际网格定位台呢低于物理面约5.26mm，候选仅渲染台呢/White印记共面校准，不改USDZ/物理/球位/库袋；材质收敛为半球灯带HDR、单顶灯、原台呢细纹和连续木框漆面。S21最终17单测+2UI通过，另iOS17/iPad真实页面及动态回放通过，build/gate/doc-size通过；模拟器画质达标，审美认可待用户审阅。真机60fps/热/内存和正式共享接入仍未完成，正常Release默认原版。详执行记录及UI审查v62.2，未提交发布。


## FL-056 — 把局部渲染改善误判为参考质量达标（2026-09-11）
- **任务/状态**：v62，用户否决后返工，未解决。
- **失败**：相对原版改善、功能/构建测试通过后，主控给出2/2/2/1/2并结束模拟器目标；用户真机审阅明确指出与Shooterspool仍相差很远。
- **根因**：验收把目标缩窄为相对原版提升；缺少每轮与桌面参考的直接图像差距检查，自评分替代了参考质量证据。
- **处理**：撤回画质达标结论、重开持续目标。每轮保存同镜头/球位/曝光A/B，并同时展示用户参考；不以测试通过、成本小或修掉单个几何缺陷宣布总体视觉达标。拒绝的候选及理由保留。
- **已应用至**：`.cursor/rules/57-ui-reviewer.mdc` §FL-056，以及问题集合v62.3/UI规格/进度/执行记录。


- FL-058（2026-09-11，S98）：静态双球诊断二次摆球随机重置母球姿态，首轮A/B作废；最终摆球后固定姿态并重拍12图，日志S98-fixed.log通过。生产未改，详FAILURE-LOG.md。

## DR-139 — 虚拟训练辅助几何不参与投影（2026-09-11，S155）

- 侧向主灯实际UI暴露瞄准线平行暗影，答题后仍存在；共享指南节点默认castsShadow=true。
- 统一关闭辅助线/标记/网格/角度注释几何的投影，保留实体球杆桌；不改位置、颜色、深度规则或评分。
- 红绿测试及26.3/iOS17实际训练UI通过，前后原图确认；完整消费者矩阵和手机性能未验。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §虚拟辅助几何 / Changelog。证据output/render-quality-v62/S155-guide-shadow/。

### DR-138 / S157补记

保留灰面校准后的偏置单主灯为候选局部改善，S154/S155实际页面及iOS17、S156回放、S157接触/隔离与gate通过。材质S95、辅助投影修复S155保留；完整参考目标与手机60fps未验收。已应用至tasks/UI-IMPLEMENTATION-SPEC.md Changelog；证据tasks/render-quality-v62/README.md S156–S157。


## S209–212：真实高亮分区与黑木法线伪影修复 — 保留

S209使用588×1000 RGBA16Float+深度采集真实场景，同时渲染材质分类ID。独立校准确认该路径是曝光后的线性值：输入1→.731445，4→2.927734（EV-.45），因此显示超范围阈值为1，不是1.366。球体入口/近景分别4/1345与8/3646像素>1（约.30%/.22%），不支持以大片截白解释整个球体塑料感；近木框入口约5.54%的采样超范围。分区数据包含非有限数量，统计有限值单列，不把NaN当0或正常像素。

发现木框下缘980像素RGB均NaN。S210重复仍980，移除两木材normal后0；S211仅移除BlackWood后0，保持Wood纹理。原USDZ BlackWood_normal全部(128,128,255)，Wood_normal有非零变化。S211全景及相同下缘裁剪前后已审：异常黑线消失。根因范围定位到BlackWood平坦法线采样路径；尚未确定内部切线/UV/框架的具体数值原因，不推广为所有法线贴图问题。

S212为当前entry加入浮点有限断言：未修代码真实TEST FAILED（S212-red.log，980像素异常），生产移动候选仅将BlackWood.normal.contents置nil。修后S212-ios17.log和S212-ios26.log均TEST SUCCEEDED，6个原始浮点图均0非有限像素；iOS17入口原图已打开。实际页S212-ui.log TEST SUCCEEDED，S201/S212入口/辅助/手势/答题4组前后图全审，原绿/木纹/球/功能色保持。没有新资产和渲染pass，真实资源收益/60fps未测。

保留此局部修复，当前=S201原绿与等值颜色绑定+S212黑木法线修复；其他仍S157光照/S95环境/S155辅助投影修复。证据output/render-quality-v62/S209-scene-linear-audit、S210-wood-normal-audit、S211-blackwood-normal-audit、S212-blackwood-fix。整体逼真度仍未达标，不能把局部伪影修复当总体验收。

## DR-140 — 自由击球3D开球试点（2026-09-12）
- **用户决定**：将分离角与走位的2D/3D试点扩到自由击球，重点核验开球。
- **实现**：ShotPlayCamera共用相机切换，普通杆读取VM击球方向，开球读取BreakFlowRunner.aimDir；忙碌/停稳态不重设瞄准视角。ShotPerspectiveLayout共用视口边缘仪表定位；BreakInstrumentsOverlay新增默认false的isPerspective，只自由击球标准入口传入3D。每日清台及其他宿主保持原模式。
- **交互**：3D桌面滑动/捏合只控制相机，刻度轮调瞄；2D移母球。开球中可换视角，取消/重开/完成沿用runner状态机，底栏按钮保持。
- **验证**：三项状态测试已通过；UI与视觉最终结果见UR-20260912-freeplay-3d.md，不以测试代替真机体验。
- **回写目标**：swiftui-design-system技能共享开球仪表接口、UI-IMPLEMENTATION-SPEC。
- **已应用至**：`.cursor/skills/swiftui-design-system/SKILL.md` § DR-140；`tasks/UI-IMPLEMENTATION-SPEC.md` § 自由击球3D试点与Changelog。

## DR-141 — 2D/3D共享观看状态独立保存（2026-09-12，v63 W01）
- **行为**：同杆模式往返保存CameraRig的当前/目标/过渡状态；显式focus替换观察姿态，新盘面/清空/重置/开球/杆结束使旧上下文失效。同模式请求幂等，延迟相机回调按UUID代次拒绝过期写入。
- **约束**：不持有或修改击球参数/业务时钟；初次进入保留既有沿杆入口。页面完整3D接入与独立手势在后续批次。
- **验证**：W01 r7十二单测通过；r4真实UI含前后台/模式往返/击球/回放/重打；隔离红控制捕获旧投影覆盖；gate/doc-size通过。见tasks/3d-v63/W01-acceptance.md。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` § 共享观看状态；`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog。


## DR-142 — 独立观察轨道、焦点与移动端相机入口（2026-09-12，v63 W02）
- **行为**：CameraRig手动轨道分别存distance/elevation/pitchOffset/FOV，竖滑与捏合独立；observe(at:)只换观察焦点，observeWholeTable按真实视口拟合台面包围范围。手动操作接管当前可见姿态，PerspectiveState保存该状态。
- **接口**：ShotObservationMenu(vm:identifierPrefix:)共用于自由击球和分离角与走位，提供全桌/母球/目标球/目标袋，保留独立focus按钮。观察命令不调用选球/选袋业务处理器。
- **自动行为**：自由击球仅在开球racked→computing/breaking时请求一次全桌；后续settled不抢镜。AngleSceneView自动母球锚定仅在rig.allowsCueScreenAnchor时允许，手动Orbit或自动过渡期间让出控制，回到瞄准再恢复。
- **验证边界**：标准/SE菜单完整流程已通过；标准自动开球19单测+1UI通过；标准锚点/低角度18单测+2UI通过；加载模型间隙28组合通过。SE扩大回归9单测+3UI通过；2D开球首次3D补充分支20单测+1UI通过，完整批次结论见tasks/3d-v63/W02-acceptance.md。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` § DR-142；`.cursor/skills/swiftui-design-system/SKILL.md` § DR-142；`tasks/UI-IMPLEMENTATION-SPEC.md` § DR-142与Changelog。

## FL-059 — 规划页截图测试停在会员弹窗仍报通过（2026-09-12）

- **来源**：v63 W03 consumers-ui-r1，PlanThree/Snooker两张原图为Pro弹窗，工具结果却通过；属于测试覆盖失败，不能计作台面验收。
- **根因**：旧openCard只验证首页卡片可点，launchClean清除Pro后未注入目标页面所需权限，也没有目标台面断言。
- **处理**：S2布局套件使用既有-forcePremium测试夹具；进入后必须确认table.scene存在且可点、没有解锁Pro弹窗。原失败覆盖证据保留，补测consumers-ui-r2。截图迁移至output并让写盘错误显式失败。
- **规则改进建议**：布局/视觉回归必须核实目标内容，而非只核实入口点击成功；会员入口测试与目标页面布局测试明确分开。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-059（2026-09-12）。
- **状态**：✅ 测试覆盖缺口修复。consumers-ui-r2两项0失败/TEST SUCCEEDED，打三与防守目标台面原图均已打开确认；不代表规划全流程已验收。


## DR-143 — 台面辅助层保持实体遮挡并采用固定显示优先级（2026-09-12）
- **来源**：v63 W03 overlap-r1，同面反向实线和不同节距虚线对照确认深度写入导致重叠三角片竞争。
- **变更**：AngleTrainingScene.TableAssistLayer固定fill/reference/route/aiming顺序；贴台线只读深度、不写深度。addLine/addDashedLine新增可选layer，默认route；网格/90度参考线用reference，训练持久进球/撞击线用aiming，填充用fill。空间线仍使用原路径。
- **约束**：原始物理高度/预测向量不变，球/库边仍参与遮挡；不同节距在空隙露出下层颜色是合法叠加，不当成深度错误。相同语义多路线不承诺一条完全遮盖另一条，需按图谱语义验收。
- **验证**：depth-policy-r1，TableAssistSurfaceV63Tests 14项及TrainingAssistSceneTests 4项，共18项0失败/TEST SUCCEEDED；生产重合虚线、全桌和低角度密集原图已打开。小屏/iPad及整页最终验证尚待。
- **已应用至**：.cursor/skills/swiftui-design-system/SKILL.md §DR-143、tasks/UI-IMPLEMENTATION-SPEC.md Changelog（2026-09-12）。本条不宣称W03完成。


## DR-144 — 捕获前状态与绝对运动时间（2026-09-12）
- **来源**：v63 W04。入口速度/自旋在旧捕获时丢失；兜底进袋和无下一事件末帧使用推进前时间。
- **变更**：PocketEntrySnapshot保存真实入口BallState、袋ID、来源、绝对时间、完整几何快照和planar-capture-v1标记；正常/兜底/解析rollout入口均记录。SpatialMotionSegment只表示无接触空间段，按绝对时间闭式查询，越段返回nil。
- **时钟**：推进内兜底使用currentTime+dt；无下一事件先提交maxTime再记帧；已捕获球不重复确认同一事件。保留原平面运动和捕获几何。
- **验证**：contract-r2五项与parity-r1四项均0失败/TEST SUCCEEDED，含入口无损/兜底时间/自由段能量与乱序查询/旧回放/预测一致性/Bundle球形解码；verify-gate FAIL=0。
- **边界**：旧捕获入口不是支撑丢失，更不是自然入袋。W05/W06必须接入真实局部几何与求解；W08再统一播放。BallFrame/二维内容未改。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-144及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-145 — 局部袋口连续接触原语（2026-09-12）
- **来源**：v63 W05实测袋口有有限支撑边缘与独立袋壁，球心捕获圈不能替代空间接触。
- **接口**：PocketContactTriangle.closestPoint/firstContact使用世界米与Double；匀加速段针对面、边、顶点求根，有限三角形距离与接近速度过滤。持续支撑/碰撞响应由后续局部求解器负责，不给静止接触硬塞一次碰撞。
- **验证**：geometry-r1一项通过且剖面图已审；contact-r1七项通过（含W04四项）。W05未完成，尚未接主引擎。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-145与tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-146 — 局部接触响应与加载网格代理（2026-09-12）
- **来源**：v63 W05。连续检测之后需要自旋/摩擦响应与有支撑状态，袋网细节不适合硬碰撞。
- **接口**：PocketContactResponse.impact更新v/omega并限制切向冲量；planarSupport仅处理局部平面受力，调用方负责有限边缘/曲率/停滑边界。PocketContactMesh加载TaiNi/Leather，dominant-plane耳切保留凹边界，按手机实际台呢条件对齐Y；不改USDZ。
- **证据**：response-r1六项通过；mesh-r1/r2保留失败诊断，角袋径向探针擦库、旧袋心会碰原Leather，不能先验要求无碰撞。mesh-r3两项通过，内侧平分线探针支撑正确、无虚构朝上封口面、竖直凹口不填平。
- **边界**：网格片数仍大、无加速结构；完整局部求解器和动态进袋未实现，W05保持进行中。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-146及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-147 — 局部支撑集与收敛失败（2026-09-12）
- **来源**：v63 W05真实网格动态探针。单面支撑造成同时间同面重复冲量；容差内未接触边缘与分离接触参与摩擦又造成接触力不收敛。
- **接口**：LocalPocketSimulation提供单球时间推进、完整支撑集、速度单向投影、法向/切向力迭代、CCD冲击和有界漂移检查。空间误差预算不能充当支撑激活距离；支撑只允许机器舍入范围内的实际接触，速度投影后须重新去掉分离约束并重算曲率。未收敛显式抛出时间/阶段/接触数/残差。
- **证据**：local-r1基础两测通过；manifold-r2至r6保留失败，凹槽双面/反序测试通过。r4实测伪支撑间隙9.3199843e-7m；r6投影后分离速度5.313644e-7m/s，不能继续施加支撑。r7四项通过，实际角中袋推进/无重复/收敛守卫通过；gate/doc-size通过，W05仍未验收。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-147及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-147续验：2026-09-12 adaptive-r1，加入超预算穿透的完整状态拒步/减半重算。12条直入轨迹均完成但矩阵3断言失败（慢角袋能量/收敛、高速中袋收敛），W05未验收；结果与下一步见W05-working。拒步契约同步ios-architecture技能。

DR-147续验：精确有限面边缘分段已加入，edge-analytic-r1闭式时间测试通过；实际高速中袋高度/纵向收敛后暴露多面同时冲击的左右排序依赖，edge-event-r1仍1失败，保留待修。规则契约此前已同步ios-architecture。


## DR-148 — 同时多面冲击联合响应（2026-09-12）
- **来源**：v63 W05，真实中袋两面对称TOI仅差1.8e-18秒，单面最早排序引发左右分叉。
- **接口**：PocketContactResponse.simultaneousImpact按共享冲击前状态、恢复目标、库仑限幅做同步松弛Jacobi冲量迭代；迭代耗尽抛错。局部模拟器按机器舍入级同TOI收集并记录全部面。
- **验证**：joint-impact-r1五项局部测试通过，包括9组e/摩擦的对称反序与能量；高速中袋两步长轨迹一致约1e-13米。矩阵仍有慢中袋左右分叉1失败，持续支撑/位置投影顺序待诊断，W05未验收。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-148与tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-148续验：持续支撑改同步速度/力/末态投影并保持收敛失败；完全同法线同摩擦内部接缝保留最小曲率约束。symmetric-support-r2基础5测通过，矩阵仍慢中袋12.145824mm分叉1失败；已保留进一步首次偏移诊断，W05未验收。契约同步ios-architecture技能。


## DR-149 — 曲面支撑接触导数与新位置约束（2026-09-12）
- **来源**：v63 W05慢中袋短时对称诊断，旧支撑面不能代表推进后的几何约束；曲面无滑动加速度漏掉法线转动。
- **变更**：末状态按新位置全候选最近面重建约束；normalRate统一给出有限边/顶点法线导数，曲率=v·nDot，切向接触加速度包含omega×(-R*nDot)。力求解与停滑时间共用完整导数。
- **验证**：onset-r1/r2保留失败；onset-r3六项通过，慢中袋0.46s末横向偏移约1e-23m，基础/同时冲量/离边回归通过。完整矩阵待终态，W05未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-149与tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-149续验：relative-force-r1和friction-constraint-r1均保留受力尾差失败，后者基础5测通过；完整矩阵/短时尚未通过，W05继续。试验约束与下一步诊断已同步ios-architecture及W05-working。


## DR-150 — 广义运动与接触可行性联合收敛（2026-09-12）
- **来源**：v63 W05，内部接触力分量不唯一，分量残差1.1559e-10时实际广义加速度变化仅1.8108e-16。
- **变更**：受力解要求广义加速度相对变化<1e-10，同时法向互补/库仑圆盘投影加速度残差满足0.5*residual*duration²<=空间tolerance；不要求相互抵消的内部力唯一。独立能量、穿透与全轨迹步长断言不改。
- **验证**：feasible-motion-r1七项0失败/TEST SUCCEEDED，含12条真实角/中袋直入矩阵、短时对称、5项基础；慢中袋左右分叉消除，gate通过。W05悬袋/返回/慢放/加速等未完成，主引擎未接入。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-150及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-151 — 袋口碰撞候选空间索引（2026-09-12）
- **来源**：v63 W05实测网格数千三角面逐步扫描成本。
- **接口**：PocketContactIndex保存不可变AABB树，返回原始面编号有序候选；LocalPocketSimulation.useSpatialIndex默认true，false供严格穷举对拍。
- **验证**：index-r1七项通过，1302状态/全部接触与拒步次数逐项相同，12轨迹矩阵通过；单次模拟器Debug含建树2.1079s→.9057s，非真机验收。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-151及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-152 — 有限特征碰撞根校正（2026-09-12）
- **来源**：W05中袋返回撞击把未接触边缘收为同TOI，联合冲量不收敛。
- **变更**：有限三角形距离Newton抛光解析种子，机器舍入距离过滤，抛光后重新选择最早接触。原1e-7距离宽容不能作为实际碰撞激活。
- **验证**：finite-root-r1九项通过；return-contract-r1六项通过，包括50um偏心边缘延迟碰撞闭式回归、12直入轨迹及两袋4m/s返回并重获平面支撑。W05视觉/偏心/参数等仍未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-152及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-153 — 局部轨迹候选使用实际加速度（2026-09-12）
- **来源**：W05支撑/摩擦可产生水平加速度，纯重力候选范围不能覆盖实际抛物段。
- **变更**：先查询当前支撑，再以求解后线加速度和当前分段时长重建可达AABB，供CCD和末态约束使用。索引与穷举共用查询范围。
- **验证**：near-frames-r2三项通过，1302状态及事件严格对拍、12偏心/返回能量与步长轨迹通过，42张近袋帧留证；主引擎未接入。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-153及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-154 — 局部接触迭代加速与积分误差控制（2026-09-12）
- **来源**：W05临界外沿新增回归：冷Jacobi慢收敛；首阶曲面支撑在1s末粗步差约2.1mm；分段尾差把不可分辨滑速放大为摩擦请求。
- **变更**：接触力使用深度1 Anderson候选并以真实不动点残差下降为接受条件，仍保留原严格运动/接触收敛守卫。一步/两半步比较位置、dt乘速度及R*dt乘自旋差，拒绝的试算不写事件/轨迹；局部误差预算不代替全轨迹步长与能量验收。内部子步使用原整段convergenceHorizon。静态单球自主平衡可休眠至请求末时刻，不能把该规则直接用于未来存在其他球/外部事件的调度器。
- **数值时间**：绝对时间加减使末步略超cap时，把舍入尾差合入末步；切向滑速低于其v/omega运算尺度的舍入界时记零，求解与校验同源，禁止以固定可见速度阈值代替。
- **验证**：anderson-support-r1三档临界轨迹均完成，严格守卫通过，但粗步2mm断言失败；error-control-r1/r2保留微小尾步失败。r2五项基础通过、角袋步长差降至1.056mm/0.533mm。error-control-r3验证滑速舍入修正中，不能据这些中间结果关闭W05。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-154及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


DR-154续验：error-control-r3六项0失败，原2mm粗细步标准通过，角/中袋误差约减半；gate/doc-size/scoped diff-check通过。完整原场景与近袋帧回归运行中，W05尚未验收。


DR-154最终续验：error-control-r3六项与acceptance-regression-r1六项均0失败；84帧留证并实看16张关键帧。W05原型按W05-acceptance.md验收；参数实物标定、手机预算、App链路与多球调度不在本次完成声明内。


## DR-155 — 空间球球接触与分离约束激活（2026-09-12）
- **来源**：v63 W06，局部球必须与台面球/其他局部球按真实高度接触。
- **接口**：SpatialBallContact.firstContact以B-A相对位置/速度/加速度求连续接触，返回A→B法线；resolve保留三维速度；resolveCoupled的Constraint法线为B/静态面→A，等质量等半径球共享初态联合求冲量。
- **激活**：初始分离接触不参与冲量，避免恢复条件与错误支撑联合制造能量；响应后新接近的约束须同绝对时刻重新调度。此函数不负责主事件循环或几何穿透修复。
- **验证**：separating-support-red-r1原反例4断言失败；coupled-contact-r3完整6项0失败，包括竖向交换、真实高度CCD、守恒/摩擦矩阵、支撑联合冲击、三球对称与分离支撑反例。r2因SettingsView类型检查超时未执行测试；等价抽取roomStyleRow后构建恢复，保留既有样式行为。
- **范围**：主引擎尚未接入，W06未验收。r3为标准模拟器Debug证据。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-155及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-156 — 球房风格设置（2026-09-12）
- 用户选定极简赛事并授权可选风格。S428扩展为④极简赛事（tournament）/②温润木质（walnut，保留旧持久值）/⑥当代东方（eastern）；默认tournament，未知持久值回退默认；本地key为roomStyle.v1。
- SettingsView使用实际渲染缩略图卡片，44pt以上整行命中与已选择无障碍值。仅Debug展示，与当前球房消费开关一致。
- AngleSceneView观察偏好；installReferenceRoom(style:)只替换外围节点，同款幂等，保留相机/球桌/球材质及2D隐藏。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-156及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


DR-155续验：resolveInstant补齐同时间冲量闭环，固定几何候选逐轮重建激活；返回rounds，maxRounds不足抛convergence。instant-contact-r1七项0失败，覆盖两轮终态、逐轮能量、顺序与失败预算。主引擎接入仍未完成。已同步ios-architecture与UI Changelog。


## DR-156 — 静态袋口几何注入（2026-09-12）
- **来源**：v63 W06，物理网格不应依赖完整训练场景生命周期。
- **接口**：PocketContactMesh.load(table:worldRoot:pocketID:center:surfaceY:bedY:alignCloth:)解码独占静态节点树，返回纯数值Patch；既有scene入口只提取参数后委托。坐标转换、TaiNi对齐、候选窗口与有限面剖分保持原路径。
- **所有权**：调用方负责节点树独占访问及实测bedY；结果不保留SceneKit引用。此步未提供资产缓存或无场景bedY测量，不宣称物理后台全链路已就绪。
- **验证**：geometry-injection-r1八项0失败：角/中袋克隆静态树与现有scene入口逐顶点/材质完全一致，快照不随原节点移动，非有限坐标拒绝；七项空间接触回归通过。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-156及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


DR-156续验：PocketGeometryAsset提供无AngleTrainingScene的资产初始化，使用同源TableModelLoader变换和MobileClothAlignment静态树bedY测量，锁保护进程级纯数值快照；失败不缓存。geometry-asset-r1九项0失败，六袋逐顶点/材质/高度一致及缓存身份复用通过。主引擎尚未消费。已同步架构技能与UI Changelog。


## DR-157 — 局部运动区间与跨轨迹连续检测（2026-09-12）
- **接口**：LocalPocketSimulation.Result.intervals保留accepted运动段的起态、线/角加速度、右端冲量/投影后状态；sample(beforeEndpoint:)提供碰前左极限。firstPairContact合并两条不同分段轨迹并求最早球球CCD，返回绝对时间及碰前状态。
- **约束**：拒步不得泄漏段；检测不等于响应；碰撞后未来段必须失效。段端点静态接触需主调度联合解算，不可直接使用独立单球预测的碰后速度。此步尚未接入EventDrivenEngine。
- **验证**：local-interval-r1十三项通过；interval-pair-r1十四项0失败，落地前后速度闭式值、区间连续时钟、不同步长双轨迹碰撞时间7.2s及交换对称通过。普通局部求解/接触回归通过。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-157及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-158 — 局部多球最早事件推进（开发中，2026-09-12）
- **接口**：LocalPocketSimulation.advanceTogether预测同窗、选最早球球事件、截断所有未来段，重建同时静态/球球约束并resolveInstant；返回时刻/状态/accepted区间/约束，后续须重新预测。
- **验证**：coupled-advance-r1十五项0失败，下落球撞受支撑球后反弹的接触时间与重算末态符合闭式值。
- **未解决**：pair-support-red-r1一项两断言失败。初始竖直静止双球，上球从0.3m下移到0.2875m、vy=-0.5；独立预测无法提供持续球球支撑力。禁止把本接口接入正式App或宣称W06通过，先解决持续接触及其步长/能量边界；保留原断言。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-158及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-159 — 持续球球/静态面联合接触力（2026-09-12）
- **接口**：SpatialBallContact.resolveSupport接收运动、外力加速度与SupportConstraint(contact,normalRate)，返回线/角加速度及每约束作用于A的单位质量力。法向互补含曲率项，切向按实际滑速选择库仑滑动或静摩擦投影；求解失败显式抛convergence。
- **边界**：冲击须先解算；只有法向相对速度在舍入界内的持续接触承力，分离无力。几何与normalRate由调用者提供，不能以此函数替代几何检测或时间积分。
- **验证**：support-force-r1九项0失败，双球静态传重Fn=10/20、加速度为零、约束反序一致、分离无拉力、滑动摩擦与角加速度、曲率失支撑通过；含七项冲量/CCD回归。
- **未完成**：尚未接入advanceTogether的演进，pair-support-red-r1失败仍然有效。下步接入持续力及步长误差控制后必须重跑原失败，不得以本次力级单测替代。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-159及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


DR-159演进接入：advanceTogether按maxStep刷新持续力，只把球间力/力矩传给各独立局部求解器，静态面自行重算，避免重复反力；LocalPocketSimulation新增缺省零externalAngularAcceleration，所有接触力迭代和运动段使用该外力矩。pair-force-integration-r1十八测一失败：残差被识别为0.005s伪碰撞；r2将力迭代收紧到64ulp尺度并只忽略整个重叠区间运动均低于舍入速度界的零时刻根，十八测0失败，原静止双球时间/位置/速度断言均保留。移动曲面接触的漂移、共同步长误差、性能仍待验；主引擎未接入。


## DR-160 — 持续压力接触几何修正（2026-09-12）
- **来源**：moving-support-red-r1三档步长均穿入，末球心距约0.189–0.192m而非0.2m；舍入级激活下曲面漂移丢失持续力。
- **变更**：持续力计划保留正法向力对应的球球/静态面引用；在单个有界试算内压力球对不重复走冲量CCD，末态联合修正实际距离与法向速度。修正总位移超过4*tolerance则丢弃整个试算、半步重试，不扩大激活距离。
- **验证**：pressure-projection-r1十九项0失败，原静止反例、移动接触三档距离/收敛、瞬时碰撞重算与已有局部/接触回归通过。
- **仍需**：共同积分误差控制、机械能与真正脱离边界；本次使用步首压力集合，不能据此宣称整个步内不会失去支撑。主引擎未接入。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-160及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-161 — 多球共同误差控制（2026-09-12）
- **接口**：advanceTogether默认整步/两半步对比，比较全部球位置、dt速度、R*dt自旋及碰撞时差速度界；状态或事件判定不同则减步，只有接受的半步进入结果；rejectedTrials记录整组拒绝次数。
- **测试前提审核**：旧固定步长断言fineDifference<=coarseDifference+1e-8在自适应步长下不再具备原前提，r2出现7.75um>5.22um；未放宽断言。保留useSharedErrorControl:false作为固定组步长对照，仅该原测试显式选择；默认自适应路径以独立误差预算收敛和原动态/静止案例验证。
- **验证**：r1测试能量闭包缺return，构建未通过；r2二十测一失败（上述前提），能量误差1e-5/1e-6/1e-7预算分别0.000337/0.000102/0.000051，未增加能量；shared-error-r3二十项0失败，固定对照原断言保留，默认路径拒步和轨迹时间范围通过。
- **边界**：局部预算不是全程同精度承诺；真实失压/脱离、实际网格多球、性能和主引擎接入仍未验。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-161及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-162 — 脱离独立参考与局部索引复用（2026-09-12）
- **变更**：临时外力求解器通过private init(base:)共享不可变surfaces/index，仅改变外力和力矩；保留父求解器索引/穷举选择。
- **验证**：release-reference-r1二十一项0失败；高速直接脱离自由落体、运动中失压后两球位置对照独立动量/能量约化参考（0.1mm）通过。real-mesh-coupled-r1一项0失败，在真实角/中袋附近台呢网格验证球球与台面联合响应，TOI与反弹闭式值通过。
- **参考**：release-reference.json保留无摩擦等质量模型公式、释放时间0.0987335019和0.12s坐标；不以待测引擎输出生成期望值。
- **边界**：真实网格案例只是近袋支撑/球球响应，尚非两球自然进袋；手机预算与主引擎接管/返回仍未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-162及tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-163 — 空间球球有界根隔离（2026-09-12）
- **任务**：v63 W06。
- **证据**：tiny-root-red-r1一项失败，2ns返回接触被旧通用根处理遗漏；bounded-root-r1构建及18测通过。
- **调整**：SpatialBallContact按导数临界点划分单调区间并二分至相邻可表示时间，仅精确相同根去重；保留接近方向与几何过滤。普通平面QuarticSolver不变。
- **边界**：实际双球袋口r5/r6均三处失败尚未验收，需继续定位首次穿透区间；不得以基础测试替代实际入口和主调度验收。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-163；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-164 — 多球事件的联合几何（2026-09-12，开发中）
- **任务**：v63 W06。
- **实测根因**：r7记录t=0.090068953s处单球袋沿修正将球间隙由+3.3477e-11m改为-3.3246e-10m，后续CCD从重叠起态漏检。数值代入见W06/first-overlap-projection.json。
- **调整**：联合事件在冲量前投影静态/球间单边位置约束，保留入射速度；无事件试算末态若球间穿透超过舍入界则整步拒绝减步，总修正预算不变。静态小反弹策略与单球入口一致。
- **验证边界**：基础18项通过；r1真实案例触发100事件守卫，r2/r3定位三接触瞬时冲量残差2.643e-10，独立反例已稳定复现失败，下一步诊断联合冲量迭代。尚未证明持续接触稳定、完整自然入袋或主引擎接入。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-164；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-165 — 冲量互补残差与接触转换精度（2026-09-12）
- **任务**：v63 W06。
- **根因与证据**：near-rest输入的释放约束冲量卡在5e-324，lambda>0分支错误要求分离速度为零；独立数值复算保留near-rest-residual-analysis.json。contact-transition-r1另验明冲量1e-11与持续力64ulp激活精度不同，微小残速反复生成事件。
- **调整**：法向使用速度单位的自然投影互补残差；冲量和同时间闭环收敛收紧至64ulp，与持续力一致。球球反弹按实际区间相对法向加速度及曲率估计分离高度，恢复方向且高度在空间误差预算内时采用非弹性冲击，持续力仍自主决定释放。
- **验证**：contact-transition-r2构建及20项0失败；原断言保留。真实案例r8仍触发100事件守卫，中袋未执行，完整多球入袋/主引擎未完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-165；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-166 — 压力投影量纲与激活一致性（2026-09-12）
- **任务**：v63 W06。
- **根因**：projectPressure混用位置/速度尺度，位置模长放宽了速度残差，下一半步resolveSupport却不接受该残速。r9捕获真实状态，单平面复现0.1ms请求在49ns后返回碰撞。
- **调整**：位置与法向速度分别按各自64ulp尺度归一化，速度尺度同持续力激活；不改空间误差预算、材料或事件上限。
- **验证**：pressure-scale-red-r1两断言失败；pressure-scale-r1构建与21项通过。实际r12定位0.155366s反复拒步至local-half时间精度耗尽，待查拒步分类，W06主引擎未接入。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-166；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-167 — 联合接受状态的静态几何（2026-09-12）
- **任务**：v63 W06。
- **证据**：r13拒步穿透不随dt减小；固定起态诊断显示旧压力投影接受了0.206/0.237微米静态穿透，下一单球修正进入邻球。
- **调整**：入口及压力投影后联合恢复全部静态/球间单边几何；两阶段总修正保持4*tolerance预算。仅校正位置，不借此清零速度或吞碰撞。
- **验证**：joint-static-r1构建及22项通过；追加总预算守卫后r2正在跑22项及真实案例，整体未完成。固定历史输入初态断言改为历史穿透前提，输出几何断言保留严格精度。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-167；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-168 — 相对CCD继承世界位置舍入界（2026-09-12）
- **任务**：v63 W06。
- **证据**：联合几何容许的-2.2e-14m间隙超出相对坐标CCD默认舍入界，仍以约0.03m/s接近却漏掉零时刻冲量。world-roundoff-red-r1捕获状态反例失败。
- **调整**：firstContact新增positionUncertainty缺省0；firstPairContact传入两球世界位置尺度的舍入界，几何投影也按各接触自身尺度检查，远处第三球不放宽此球对误差。该界不使用积分tolerance。
- **验证**：world-roundoff-r1构建与23项通过，包含总修正预算守卫、历史静态状态及新漏检反例。真实r14重验中；W06整体未完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-168；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-169 — 支撑由联合接触力决定（2026-09-12）
- **任务**：v63 W06，涉及W05共享单球求解回归。
- **根因**：重力对斜面法向分量指向分离，不代表台面反力/摩擦不会加载该面。r14活体采样确认真实袋沿极短碰撞，固定floor+overhang平衡反例由红证实。
- **调整**：触碰候选交给联合力求解，不预先以gravity+curvature排除；段末投影使用已求解的接触几何。仅正支撑力接触进入持续支撑跳检集合，未承力面保留CCD。
- **验证**：overhang-support-red-r1/r1三处失败；r2构建及28项通过。r15实际双球待验，W05实际网格回归待验，未声称整体完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-169；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-170 — 最终几何上的压力速度（2026-09-12）
- **任务**：v63 W06。
- **根因证据**：pressure-half-red-r1两断言失败；diagnostic-r1显示完整位置修正旋转球间法线，法向残速越过持续力激活精度，导致半步新冲击。
- **调整**：最终几何完成后，对仍在接触舍入界内的旧压力集合做仅速度投影；不移动最终位置，不恢复已离开的有限特征。保持原容差、迭代上限与事件一致性检查。
- **验证**：pressure-half-r1原反例通过；final-normal-regression-r1构建及33项通过，含W05临界/速度矩阵/返回能量三类实网格回归；gate/doc-size/diff通过。r16仅初态fixture失败，按实际网格定位初始Y后r17近袋全段通过；consecutive-fall-r1前后双球角/中袋真实下落通过。连续间隙、共同下落接触和主引擎未验收。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-170；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-171 — 局部球心区域与几何覆盖（2026-09-12）
- **任务**：v63 W06主调度前置。
- **问题**：原18cm网格候选窗是表面覆盖，若直接作为球心区域，球在边界会接触窗外未加载几何。
- **调整**：显式PocketLocalRegion横向球心区域，几何筛选窗再加球半径；通过真实袋ID提供区域。firstCrossing按恒加速度边界根和开区间成员关系取连续穿越，不用捕获圆或时间epsilon判接管；切触不切换所有权。
- **验证**：local-region-r1三项通过（穿越/资产/速度矩阵），r2新增映射与下落追撞/复杂近袋连续间距三项通过；gate/doc-size/diff通过。进入早于所有支撑变化的全几何证书、返回条件和主调度尚未完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-171；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-172 — 局部Double所有权与台面返回（2026-09-12）
- **任务**：v63 W06。
- **调整**：LocalPocketOwnership保留Double状态、单球唯一所有权及revision；组提交先检查全部时钟/版本再原子写入，重入后拒绝旧事件。planarReturn须离域或向外过边界、有有限台面支撑、无墙沿接触且沿实际面运动；只有通过才移除局部所有权。
- **实测修订**：真实边界r1和diagnostic-r1失败；角袋台呢大三角形Y差一个Float ULP，产生1.16e-7法线斜率。仅认可全部顶点在标准台面一Float ULP内的面，并检查竖直脚点仍在有限面内及实际法向速度。返回到标准平面允许既有空间预算内高度修正、清除该微斜率竖向速度；XZ/水平速度/自旋/时间保留。
- **断言前提**：真实边界fixture原水平速度并非该微斜面的切向速度；改为按实测接触法线构造受支撑切向速度。原全向速度相等改为水平分量相等、竖向归零；理想水平面测试仍保留完整p/v/omega/time相等。没有放宽腾空或真实墙沿拒绝条件。
- **验证**：ownership-r1两项通过；r2三项通过，包含真实六袋中心方向代表边界，最大Y校准约5.96e-8m。主引擎未消费该接口，全方向未验，W06未完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-172；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-173 — 主引擎显式局部接入入口（2026-09-12）
- **任务**：v63 W06。
- **调整**：EventDrivenEngine.simulateWithLocalPockets使用Double spatialTime与LocalPocketOwnership，选择区域进入与既有平面事件较早者；局部期间不调用旧bounds/吸袋清零。离域处截断预测并验证真实支撑返回；普通平面演进抽取共享evolvePlanarBall，旧simulate仍复用原方程与bounds顺序。TrajectoryRecorder保留Double局部区间和entered/returned交接。
- **开发边界**：当前显式入口只允许单球，混合多球立即抛groupIntegrationPending，尚未启用正式App；未实现权威规则capture，不把已经下落标成pocketed。该临时限制必须随共享调度实现移除，不缩小v63范围。
- **验证**：main-local-entry-r1角袋下落/中袋返回通过，中袋正入暴露接缝不收敛；DR-174处理后r2两类主引擎路径已通过，完整回归运行中。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-173；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-174 — 消除物理台面的一ULP接缝（2026-09-12）
- **证据**：main-local-entry-diagnostic-r2给出中袋z=-0.51188004处六个台呢面，同一支撑层的顶点仅相差一Float ULP，形成微小折面并导致投影残差2.41635e-10不收敛。原12cm局部fixture从接缝内侧开始，未覆盖真实18cm接管后过接缝。
- **调整**：仅数值物理代理中，TaiNi顶点距标准surfaceY不超过surfaceY.ulp者对齐到标准Y；更低袋沿曲面与所有其他材质保持原值。共享顶点采用同一规则，maximumBedAdjustment记录最大变动上界。显示模型/USDZ不变；没有改迭代上限或残差。
- **验证**：r2主引擎角/中袋下落与中袋返回通过，六袋数值代理对拍/调整上界通过，普通PhysicsEngine/RestTransition已通过；临界/速度网格矩阵仍运行中。其他实际多球/收敛回归尚待刷新。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-174；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。


## DR-175 — 局部续算保留已求解尾段（2026-09-12）
- **证据**：main-local-entry-r3共25项中只有续算测试4断言失败；0.6s切段使随后积分网格重置，1.1s末态位置约2.4微米、速度约5.8微米每秒差异。真实多球和基础接触均通过，不是Double状态转Float后重建。
- **调整**：局部试算保持完整步，仅发布到请求时间；剩余Result带所有权revision保存，下次继续消费同一多项式区间。到真正边界仍截断并检查支撑。相同Double时间请求直接无操作，不添加重复快照。新外部事件必须使预测失效；混合组调度仍待实现。
- **验证**：r4主下落/返回/原续算断言三项通过；r5追加p/v/omega逐分量精确相等及无操作快照数量检查，通过；gate/doc-size/diff通过。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-175；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-176 — 跨所有权预测与平面方程一致性（2026-09-12）
- **范围**：findNextEvent增加局部owner排除集合，保留球数据；firstLocalPlanarContact用真实高度连续检测，预测止于下一平面事件，接触自旋从实际平面方程查询。当前为混合调度基础接口，尚未接入多球主循环。
- **失败机理**：EngineNumerics加速度仅在速度>0.001时启用，而AnalyticalMotion滑动/滚动在>0.0001时仍减速。0.0005m/s滑动反例预测接触22.351740729微秒，独立方程23.428689391微秒，原1e-10s断言失败。
- **修复**：预测加速度的两个域边界与现有演化方程一致，分类阈值不变；未放宽断言。
- **验证**：cross-owner-low-speed-red-r1终态失败保留；green-r1终态exit0，39项0失败，覆盖跨owner高度/先行事件截断/不删球过滤、普通PhysicsEngineTests及PhysicsRestTransitionTests。先前planar-owner-filter-r1为37项通过，cross-owner-prediction-r1为3项通过，属于重复执行不能累计为独立功能覆盖。
- **边界**：不代表混合组事件响应、外部变更缓存失效、全低速域或App自然进袋验收。正式入口仍未切换。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-176；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-177 — 共用接触时刻联合响应（2026-09-12）
- **范围**：从advanceCoupledTrial提取resolveContactGroup(initial,accelerations,pairRestitution,pairFriction)，原局部推进改为调用同一入口；接收同一时刻的碰前状态和加速度，联合处理实际静态几何与球球接触，返回碰后速度/自旋与约束，不生成运动区间。
- **原因**：跨owner预测之后不能仅交换球速；受支撑接收球的台面反作用必须与球球冲量共同求解。低反弹的有界处理继续使用各球真实预测加速度，不改旧接触参数或误差预算。
- **验证**：cross-owner-response-r1终态exit0，两项通过：理想平面向下0.5m/s撞击、e=0.8后落球向上0.4m/s且台面球vy=0，异步输入拒绝；真实角/中袋落球与受支撑球联合案例。r2在加入有限状态检查后回验新入口、真实离台追撞、持续压力半步及复杂近袋连续间距。
- **边界**：此入口不推进主引擎时钟、不提交所有权、不负责缓存失效。混合主循环与覆盖域外邻球的实际静态几何仍待接入，W06未完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-177；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

DR-177补充验证：cross-owner-response-r2终态exit0，4项0失败；复杂近袋连续间距/能量、真实离台追撞、持续压力半步与新入口通过。gate/doc-size/diff通过。

## DR-178 — 域外接触组的全桌数值几何（2026-09-12）
- **范围**：PocketContactMesh.Coverage新增fullTable选项，默认仍pocket；PocketGeometryAsset缓存tablePatches，用同一TaiNi/Leather筛选、移动台呢对齐及一Float ULP规范契约提取全桌候选。局部球心所有权域未扩大，原六袋patch保持。
- **原因**：区域边缘的局部球可以接触域外邻球。只扩大所有权区域不能消除跨区接触；共用响应必须拥有邻球所在位置的真实支撑/袋沿几何。全桌值快照供空间索引查询，不代表全桌球都改用空间积分。
- **验证**：full-contact-geometry-r1终态exit0，两项通过：六袋原网格是全桌候选逐顶点精确子集；桌心及沿六袋朝桌内方向越过所有权边界两球半径处均有实际竖直球体CCD台面支撑；六袋Scene加载对拍保持通过。r2追加同七处的联合落球响应及单球主入口回归，尚须读取终态。
- **边界**：保留既有碰撞材质范围，不宣称袋底/装饰材质或全方向已验收；主混合调度尚未使用tablePatches，性能预算仍未验。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-178；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

DR-178验证更正：r2终态exit0但仅执行1项，七处全桌几何联合响应通过。命令误写testMainEngineBeginsNaturalPocketDescentBeforeLegacyCapture（真实名称为Owns），Xcode未报不存在筛选项，不计主入口验收。full-contact-main-r3使用源码准确名称补跑主下落与Double精确续算，session_id=8644。

full-contact-main-r3终态exit0，准确名称两项执行均通过：主入口角/中袋下落及单球精确续算。DR-178三轮共5次执行（含重复几何测试），全桌七处联合支撑通过；gate/doc-size/diff通过。所有句柄终态。下一步使用tablePatches构建共享接触求解器并接入多球主时钟，暂不能移除单球限制或标W06完成。

## DR-179 — 混合多球主循环验证入口（2026-09-12）
- **范围**：EventDrivenEngine.simulateMixedWithLocalPockets(maxTime,maxStep,pairRestitution,pairFriction,maxEvents)新增显式验证入口。台面事件/局部域进入/局部组最早球球接触/跨owner CCD共用Double时钟；普通台面球仍由evolvePlanarBall演化。全桌接触索引用于局部组及域外邻球，接触邻球沿接触关系加入同一联合响应，复制所有权账本完成共同提交后发布Float镜像，每轮清理旧平面事件缓存。
- **参数**：球球系数由验证调用者显式传入，尚未取代生产碰撞材质契约；静态接触沿用既有W05原型参数。正式simulate以及单球simulateWithLocalPockets未切换。
- **返回**：局部球需满足真实台面返回判据，且与其他局部球离开4*tolerance接触预算；此边界仍需实际返回/重入回归。新增球球事件写入既有事件/时间记录，首次碰撞时间使用当前绝对时间。
- **验证**：mixed-main-r1终态exit0，真实中袋域内腾空球撞域外台面球通过：动量传递、台面支撑、邻球空间接管与无旧捕获。r2因新测试直接比较非Equatable的SCNVector3编译失败（保留）；改为逐分量精确断言后r3补跑两地区下落+远处静止球和跨区单次事件。
- **尚未完成**：混合续算完整步缓存、外部setBall输入生命周期、同时事件/静态事件记录审计、返回再入、接触组多球连续间距/能量和生产参数一致性。多球单次输入已有实际推进代码，不等于整批W06或App进袋已验收。不可用新入口的一例通过移除正式门控。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-179；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

mixed-main-r3终态exit0，两项0失败：两个不同袋口在同一Double时间推进到1.1s均下降，远处静止球逐分量保持；真实跨owner接触动量/支撑/晋升及单次球球事件记录通过。r2编译失败已修为逐分量断言，未改物理断言预算。gate/doc-size/diff通过，所有进程终态。下一步混合主循环连续段/同袋多球/返回再入和任意时间续算：当前主混合入口已接通但未完成这些验收，正式simulate与原单球入口仍保持。

## DR-180 — 混合完整步骤缓存与前缀提交（2026-09-13）
- **根因**：混合入口使用maxTime裁积分末步，后续从裁点重新积分，旧反例最终位置差约4.4e-16m。精确断言保留。
- **实现**：PendingMixedStep保存共同步骤起止、局部原始区间/完整终态、平面原始状态/完整终态、晋升与事件待提交动作、参数和版本。固定完整maxStep或最早物理事件决定求解边界，请求只决定消费前缀。局部前缀从原区间sample，平面前缀从原步骤初态演化；完成时采用缓存终态，不从已发布前缀续积分。只有到完整事件时间才发布碰撞/晋升/进入。部分提交更新owner revision，后续匹配续用。
- **输入保护**：缓存绑定maxStep/球球系数/ballInputRevision和owner revisions；参数或外部setBall变更不能继续使用旧预测，当前明确抛staleUpdate。setBall正常路径只增加revision计数。单球局部入口拒绝混合缓存，反向混合入口原有pendingLocalResult检查保持。完整外部修改后重新接管/重算流程仍待验证，不声称已支持任意运行中编辑。
- **验证**：mixed-continuation-green-r1终态exit0，原精确p/v/omega续算反例及跨owner单次碰撞两项通过。green-r2追加事件前多次截取（不得提前发布事件/晋升）、系数变化拒绝后正确续算、同时间无帧变更，并回验同袋双球、返回、不同袋口与原单球精确续算；尚须读取终态。
- **边界**：正式App入口未切换。多球同刻静态/球球事件完整日志、连续再入及整批性能/确定性矩阵仍待验，W06不标完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-180；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

mixed-continuation-green-r2终态exit0，5项0失败：混合多次截段p/v/omega精确一致、事件前不提前发布/晋升、系数失配拒绝后正常续用、同时间不增帧、同袋双球连续间距/最终能量、返回台面、双袋共同推进和原单球续算。两轮7次执行含重复续算，不当作7个独立功能。gate/doc-size/diff通过，全部句柄终态。下一步继续同刻事件/连续再入与外部输入生命周期：缓存失配目前拒绝，不能宣称自动重建已完成；正式入口/规则捕获仍未切换。

## DR-181 — 连续再入接缝支撑与首次碰撞时钟（2026-09-13）
- **实际反例**：混合球从中袋局部返回台面，与迎面球碰撞后重新进入。mixed-reentry-r1终态exit65，在t=0.7118319298395155s支撑projection失败，4个共面三角候选、residual=1.7340928696757009e-9。原始状态/三角顶点在日志保留。
- **几何机理/修复**：球的垂足已处于某一面内部，邻接共面三角的边缘距离却因舍入被列入同一nearest+roundoff投影集；这要求多个实际不能同时成立的法线速度为零。exposedSupportCandidates仅在确有垂足位于有限三角内部时，排除同平面上离该垂足有可分辨距离的边缘候选。共面判据使用既有64ulp空间尺度，不扩大投影残差阈值。没有面内部覆盖的真实袋边、非共面面和孔洞仍保留。当前使用点为无撞击步的支撑投影。
- **首轮验证**：mixed-reentry-r2终态exit0，进入→返回→平面球碰撞→再次进入及同pocketID/顺序通过。
- **时间反例**：新增同源时间断言后mixed-reentry-clock-red-r1终态exit65：firstBallBallCollisionTime=0.0003577754，而事件列表绝对时间0.27785778。resolveEvent误用相对event.time；改为调用方已推进的currentTime，普通与混合平面入口共用此修复。
- **回归**：mixed-reentry-regression-r1运行中；包含再入/混合精确续算、实际复杂双球连续间距、W05临界袋口和返回能量、普通PhysicsEngineTests，尚须读取终态。原红证据与精确断言保留。
- **边界**：没有变更显示几何/材质，没有调物理接触参数。W06同时事件完整记录/外部输入生命周期及全面验收仍待完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-181；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

mixed-reentry-regression-r1终态exit0，38项0失败（211.164s）：33项普通物理、混合再入+绝对首次碰撞时间、混合精确续算、复杂近袋连续间距及W05临界/返回能量。两次原红证据保留；未改变误差断言预算。gate/doc-size/diff通过，全部进程终态。下一步W06事件完整性审计：advanceTogether目前只向主循环返回球球约束，单球run内部静态contacts未随CoupledAdvance向上传递，主记录存在袋沿碰撞事件缺口；须保留接受前缀内的静态接触及ID/时间，拒绝试算/未来事件不能上报。外部编辑生命周期仍不可宣称已支持。

## DR-182 — 已接受局部静态接触向主记录传播（2026-09-13）
- **缺口**：LocalPocketSimulation.run已有Contact时间/面索引/法线，但advanceTogether只回传轨迹和球球约束，主循环丢失静态接触。
- **实现**：CoupledAdvance.staticContacts按球保留已接受半步/试步的静态事件；拒绝试算不入结果。遇到更早球球接触时只保留严格早于该时刻的旧静态事件，同刻以联合响应接触重建。resolveContactGroup保留实际向静态面逼近的接触，静止支撑约束不直接当成新撞击。
- **主记录**：TrajectoryRecorder.localStaticContacts带ballName、geometryID和原始Contact。混合PendingMixedStep独立保存逐球静态列表，含刚晋升邻球的联合接触；按已消费计数只发布time<=请求截止的前缀并依时间排序，续算不重复发同一条。面索引对应缓存tablePatches，geometryID当前为运行时全桌快照标识；持久化版本映射和业务吃库/音效分类不是此字段自动完成的。
- **验证**：static-event-pipeline-r1终态exit0，再入/混合精确续算两项通过；r2终态exit0，实际落地静态事件时间与独立自由落体方程匹配，事件前为空，一次/多次续算记录时间/面索引/法线精确一致，真实离台追撞/受支撑接触共3项通过。r3在补晋升邻球独立事件列表后验证编译、落地续算及跨owner，尚须读取终态。
- **边界**：同一物理接触可能含多个几何面记录，尚未将几何接触自动等价于业务吃库事件；正式App与规则capture未接入。W06不因数据管线绿而直接完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-182；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

static-event-pipeline-r3终态exit0，3项0失败；新增主事件前缀/续算一致性、跨owner与实际支撑通过。三轮8次执行含重复用例，不当作8个独立功能。gate/doc-size/diff通过，所有进程终态。下一步按W06 DoD集中审计高速/同刻组事件与确定性，明确几何接触日志和业务事件的边界，再确认进入W07的前置；不能把静态面索引直接当库号或自动计分。

## DR-183 — 同刻独立台面事件直接提交（2026-09-13）
- **审计结论**：coincident-entry-baseline-r1终态exit0，初始t=0区域进入与不相关已接触球对的碰撞均保留，旧重查在该用例有效；此前只是风险假设，不能记作已复现漏报。
- **调整**：混合入口用事件涉及球集与最终局部owner集判定。无关同刻平面事件直接随PendingMixedStep保留并提交，不再被dueEntry或cross的互斥条件丢弃；涉及新owner的旧事件交新局部/联合求解，不双算。零时刻进入同样可在该时刻处理独立事件。规则capture仍未切换。
- **验证**：coincident-entry-r2终态exit0，4项0失败，含初始同刻碰撞和独立参考结果逐分量一致、高速三球三档/重复/半步矩阵、混合精确续算与真实连续再入。工作区原失败及探索记录保留。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-183；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-184 — 确认捕获记录与持续运动分离（2026-09-13）
- **接口**：TrajectoryRecorder.ConfirmedCapture保存ballName/pocketID/geometryVersion及Double完整state；recordConfirmedCapture只录已经由物理判定确认的事件，重复相同输入幂等，冲突/非法状态拒绝。记录操作不吸袋心、不清速度/自旋、不改现有运动帧。
- **查询**：isBallPocketed新增可选Double查询时间；有新捕获记录时用确认时刻，截止前为false；无新记录沿用旧帧.pocketed语义。confirmedCaptures按时间/球名确定排序。当前没有生产求解器调用新录入接口，不能把契约完成当自然进袋判据完成。
- **验证**：capture-record-r1终态exit0，共3项0失败；新捕获仍有非零速度/自旋和sliding尾帧、时间前不泄漏、重复不多计、冲突不覆盖、无效输入拒绝、旧帧查询及原自然停稳回放通过。测试捕获为明确手工fixture，不是实物捕获判据证明。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` DR-184；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-185 — 袋内多面接触的亚分辨率反弹（2026-09-13）
- **问题证据**：bag-floor-red-r1从精确失败状态复现；斜壁瞬时响应使底面vn约3e-10，严格分离筛选移除底面支撑，重力又生成约30ns碰撞，触发迭代上限。
- **内部契约**：LocalPocketSimulation.integrate对已几何接触且有恢复加速度的法向，用vn²/(2a)与既有空间tolerance比较。仅在反弹不可分辨时考虑共同切空间正交投影；保留自旋及共同切向速度。总速度改变量的动能尺度不得超过g*tolerance，且不得违反其他单侧约束，否则保留原响应。不是固定速度阈值、球整体清零或扩大袋口。
- **实现修订**：首版迭代投影导致近乎平行接触不收敛（regression-r1保留），改为两遍正交化构建法向空间，直接投影并按能量/可行性拒绝过大调整。超过空间预算的真实离地仍保留。
- **验证状态**：精确状态短时测试green-r1通过；regression-r2四项中精确状态/可见离地/旧返回能量三项通过；完整1s停稳失败。延长4s后1.366s三面projection失败，仍待修；见W07-working。正式App尚未切换。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-185；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-186 — 非共面公共边支撑与外层末步时钟（2026-09-13）
- **根因**：袋内长测1.365928889792294s的三面投影失败。精确几何分析显示第一面最近点在公共边，第二面垂足已进入面内；两者距离因舍入相同，但法向有约5e-10差异，产生±4.35e-12速度残差。原exposedSupportCandidates仅排除共面边，不处理这种已被邻面覆盖的非共面公共边。
- **改变**：若候选最近点位于另一有效面的平面且被其有限三角区域覆盖，同时与该面的垂足可区分，则移除这条冗余支撑。最终仅用于末步投影；对比实验发现提前过滤支撑候选导致同刻重复CCD记录，已撤回该提前过滤。未来碰撞候选不删除，真正不同面接触点仍保留。
- **时钟**：精确2ms状态复现越过投影后暴露末尾1ULP：半步舍入到终点，第二半步duration=0。外层与原内层一致采用8ULP末步剩余合并，并明确检查中点可表示，不能以零时长调用积分。
- **验证**：noncoplanar-seam-r3三项0失败（独立几何复现/微反弹/真实离地）；真棱角通过；长测推进到3.028s出现接触力收敛失败。撤回提前过滤后noncoplanar-isolation-r1两测（精确接缝/旧返回能量）通过；长测仍待修，见W07-working。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-186；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-187 — 接触力的可行边界加速（2026-09-13）
- **根因调查**：两面force失败状态的独立NumPy小样显示原单步Anderson、严格下降、多历史4/8均在4096步后保持约9.18e-7残差。不是简单放宽判据可接受的问题；近中性接触力分配在摩擦约束激活前变化过慢。
- **数值方案**：沿当前forceMap增量，解析求法向非负与Coulomb圆锥的下一可行边界。二次系数缩放后用稳定q公式，不调用带固定1e-12退化阈值的旧通用二次函数。候选投影回法向/摩擦约束，只有残差严格低于当前值和已有候选才采用。系数、空间预算和4096上限均不变。
- **证据**：reproduce_force_iteration.py及force-iteration-comparison.json记录独立小样；boundary模式28步、残差4.47e-13。Swift force-boundary-regression-r1四项中真棱角/接缝/旧返回三项通过；完整4s运行结束但角袋仍滚动导致停稳断言失败，数值收敛已越过原3.028s失败点。随后DR-188补滚动耗散，小样平移停稳通过，见W07-working。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-187；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-188 — 局部表面滚动阻力原型（2026-09-13）
- **缺口**：袋内4s角袋末态v与omega满足纯滚动关系，只有滑动摩擦无法使其继续耗能。Surface新增rollingFriction，默认0保留所有旧调用；袋内候选显式使用SpinPhysics.rollingFriction=0.01作参考，未实物标定。
- **原型**：在局部持续支撑forceMap和实际加速度中同时加入反向滚动力偶。以无滑动平面减速度mu_r*N定义系数，对实心球对应力偶(7/5)*R*mu_r*N（单位质量），设置有限步力偶上界并保留自旋轴分量。
- **验证**：rolling-resistance-r1因错误类型名编译失败保留，改为真实SpinPhysics常量；r2解析减速度/停止距离/不倒退1测通过；rolling-couple-boundary-r1零滑动摩擦原地转动能量用例1测通过。bag-rolling-r1角袋/中袋4s承接1测通过（约99s），平移速度近零、底面高度和原能量预算通过。
- **边界**：当前单球局部原型；角袋仍omega.y=-2.8911rad/s，未宣称全运动停稳。自旋耗散、持续球球支撑预求解与滚动力偶一致性、多球/步长/手机性能、捕获与正式入口尚未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-188；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-189 — 局部自旋耗散与共享表面阻力矩（2026-09-13）
- **接口**：Surface新增spinFriction默认0；PocketContactResponse.surfaceResistance统一滚动/法向自旋力矩，法向自旋采用既有AnalyticalMotion的5*mu_sp*N/(2R)，有限步截断至停止。SupportConstraint新增两个默认0表面系数；resolveSupport新增可选duration，有非零表面系数时必须正有限且不能用于球球接触。
- **一致性**：局部forceMap、实际角加速度与球球持续支撑预求解使用同一表面公式。多球预求解仍只向单球积分器传递球球力/力矩，避免桌面反力及阻力矩重复计算。
- **验证边界**：单面正反自旋/零系数/停止时刻spin-decay-r1两项通过；新增双球叠放解析支撑力、角加速度与能量用例，完整袋候选新增角速度停稳断言，执行结果持续记录于W07-working。spin-pair-r1因换行运算符编译失败已修正，原日志保留。候选袋系数仍未实物标定，正式App未接入。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-189；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-190 — 多球持续摩擦与单球有限步一致（2026-09-13）
- **证据**：连续双球叠放测试初始绝对速度1e-4阈值过宽，低速0.0002m/s的末态随步长出现约3e-5差异。收紧低速空间预算与相对速度判据后旧代码可收敛，但10ms推进每组约1.2万细分，测试约100s。日志stacked-advance-r1保留测试闭包编译失败；r2保留原宽断言结果；r3保留收紧后高成本结果。
- **根因与修订**：局部单球forceMap按slip/dt+切向加速度求当前步末滑动并投影Coulomb圆盘；多球resolveSupport却对任意非零slip使用满额滑动摩擦，近静止反复切向翻转。提供duration时多球改用同一有限步方程；未提供duration的独立连续力调用保持既有行为。所有显式duration均验证正有限，法向约束/系数/迭代上限不变。
- **验证**：stacked-advance-r4两项通过（连续两速度/三步长及双球解析），执行约0.726s；低速末态跨步长差约1e-8m/s。pair-friction-regression-r1四项通过，覆盖正反滑动一步停零/保留滑动的解析值、真实落球支撑、跨域同刻支撑、原角袋联合修正。没有把提高预算或放宽断言作为修复。
- **边界**：10ms双球局部验证不等同完整袋内多球或手机性能通过；正式捕获/几何生产构建/主入口仍待做。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-190；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-191 — 内置袋网的数值承接轮廓构建（2026-09-13）
- **接口**：PocketContactMesh.load新增materials默认TaiNi/Leather，默认调用不变；独立提取White后，纯数值PocketBagEnvelope.build从水平截面凸包生成环/侧面及显式底部封口。配置保留原型40mm顶部、2.5mm层高、64径向点与30度最大观测空隙；这是承接近似，不是捕获边界。空/非有限/退化数据拒绝。
- **采样**：截面中心采用面积重心，避免凸包顶点平均随三角化附加点改变；边与截面相交使用半开区间以保留恰过顶点的截面。物理默认几何/主入口未切换。
- **证据与差异**：bundled-bag-r1/r2六袋构建通过，37环/4672面，与测量底部一致；旧脚本顶点平均相对新三角化轮廓出现最高4.68mm对应点偏差、0.75mm轮廓偏差。双方改面积重心后最大对应点差仍0.607mm，严格1e-10等价断言失败已记录；需进一步核对非平面原始多边形的三角化差异及几何细分误差，不能宣称两构建完全等价。
- **去本地依赖**：原完整承接测试已改用内置模型即时构建，移除output JSON读取。normal-bag-entry-r1角袋/中袋台面正常进入0.7s的高度及能量验证通过；改后的完整4s停稳尚需重跑。
- **边界**：正式缓存/捕获调用尚未接入；底部封口是显式近似，材料仍未实标，完整多球袋内/手机预算未验。后续回归详W07-working。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-191；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-191补充证据（2026-09-13）：独立脚本同样三角化后，六袋逐点与Swift最大差3.14e-16m，原0.607mm差异已定位为三角化契约。新构建完整4s两袋停稳已通过（bag-input-and-settle-r1）。独立分辨率加密仍在中袋台面下40–45mm上缘产生4–5mm差异，不能据此前单球通过判几何收敛；详W07-working及bag-resolution-finer-comparison.json。

## DR-192 — 按深部连通性提取袋网，排除同材质浅层部件（2026-09-13）
- **根因**：White并非袋网专属材质。中袋两个独立352面部件在台面下41.56–43.90mm，仅高2.34mm，XZ约2.76×21.21mm，不延伸至袋底；它们被截面凸包连接到袋腔，造成4–5mm分辨率差异。截面图、轮廓叠图及bag-component-bounds.json保留证据，不把材质名当语义分类。
- **修订**：PocketBagEnvelope按精确共享顶点建立连通分量，保留触及“测量最低点以上一球半径”深部带的完整分量。浅层独立部件不进入袋网代理；保留真实上段，不平移40mm顶部或扩大捕获阈值。build新增默认既有球半径参数及原始/保留三角面数诊断字段，验证半径正有限。
- **独立验证**：raw面连通筛选后的三档参考，2.5mm/64→1.25mm/128点最大角袋.335mm/中袋.490mm，下一档.625mm/256点最大角袋.188mm/中袋.420mm。采样轮廓比较不等于严格全表面误差上界或动力学验收。
- **边界**：此提取适用于当前已测量Bundle；将来资产变化须重新验证深部带与分量语义，不能认为所有White均可放入代理。完整捕获/主入口/袋内多球仍待做。Swift回归与独立三角面选择一致性见W07-working。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-192；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-193 — 纯数值袋网资产缓存（2026-09-13）
- **接口**：PocketGeometryAsset新增bagSourceTrianglesByPocketID，从已校准坐标的独立球桌节点一次性提取White原始三角面；持有值数据，不持有房间、相机、灯光或SceneKit节点。原台面/袋口patches与默认物理入口不变，连通分量语义仍由PocketBagEnvelope负责。
- **使用**：长时几何分辨率测试直接消费该缓存，不再构建完整AngleTrainingScene。numeric-bag-parity-r1六袋与可见场景逐三角点1e-12内一致、缓存身份与六袋ID检查通过。
- **边界**：上轮SIGKILL只确认进程退出，未证明OOM；本次减少渲染依赖不能预先宣称修复终止原因。完整运动比较、参数默认升级及实际手机资源预算分别验证。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md DR-193；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。


## DR-194 — 六套可选球贴纸（2026-09-13）
- 用户授权：按六宫格参考在 Blender 实现六套，并接入 App 供选择。
- 契约：现代赛事/极简现代/经典美式/粗描边徽章/电视竞技/复古怀旧；保持球号色族；母球红点不变。默认 modern，设备偏好 ballStickerStyle.v1，与球房/球桌样式独立。
- 接入：SettingsView → BallStickerSettingsView，预览为实际 Blender 球网格渲染；AngleTrainingScene 初始化应用，AngleSceneView 更新时只替换编号球 diffuse/multiply，不重建场景或改球位/相机/物理。
- 资产：90张1024×512 sRGB底色PNG + 六张预览，约3.2 MB。Blender 4.5.6 packed工程回读通过，源USDZ SHA保持。
- 验证：iOS26模拟器3项单测通过；iOS17同3项通过；六款选择/重启及自由击球2D/3D/击球/回放/重打通过。最终SE/iOS17浅深色取证通过；03:12 iPhone16Pro Debug安装/正常启动成功，详见UR-20260913-ball-stickers。
- 证据：output/ball-stickers-20260913；首轮缓存对象身份断言改为PNG内容校验；深链默认强制Dark须显式Light参数，不能据文件名认定外观。
- 回写目标：.cursor/skills/swiftui-design-system/SKILL.md 球贴纸选择契约；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。
- 已应用至：上述两处（2026-09-13）。

## DR-195 — 球桌饰面配套袋口与瞄准点（2026-09-13）

- **用户裁定**：深桌浅点、浅桌深点，袋口与桌框拉开明暗对比。
- **实现**：TableStyle统一提供木纹、皮革和White瞄准点配色；标准可还原。未选中皮革随桌切换，训练角色材质从原材质独立派生，主题变化保留角色状态。
- **范围**：材质与预览；不改皮革几何、袋口物理、选袋语义或母球颜色。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md § 球桌配套饰面（2026-09-13）。

## FL-060 — 球贴纸仅检查正面导致单侧号码遗漏（2026-09-13）

- **用户反馈**：六套设计粗糙，要求改用文生图，贴图不得自带高光，每球两个号码必须位于相对位置。
- **实查**：旧build_ball_stickers.py只在UV中心画一次号码；旧底色无烘焙灯光，但展示预览带灯光，不应与底色混为一谈。旧测试只看正面和切换行为，未覆盖球背面。
- **处理**：保留旧资源/证据；文生图生成数字图稿，Blender投影到归一化球的±Z，修复折叠UV后EMIT-only导出底图；补正反双侧可读性和无烘焙高光检查，重新验收。
- **规则改进建议**：球面贴图必须验证完整旋转与相反面，原始albedo和光照渲染分开展示；功能测试通过不得代替视觉验收。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` §FL-060；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-13）。
- **状态**：🔄 双面号码与集成已修复并验证；照片级视觉仍未达标。

DR-195补充裁定：粉色款例外使用白色袋口，仍配深梅色瞄准点；其余三款保持原配套方案。

## DR-196 — 整杆外观选择与固定尺寸约束（2026-09-13）

- 用户授权Blender贴图并接入App，明确小头/大头各五款、前节及后把都覆盖、所有尺寸和物理参数不变。
- 设计从整幅主题彩绘修正为真实球杆分区；新增CueStyle/CueStyleModel与独立选择页，本地保存并在共享场景更新。
- Blender仅重排UV、输出底色与粗糙度；运行时保留节点/姿态，原款可恢复，十款逐一比较实际顶点位置并渲染验证。
- 已应用至：`tasks/UI-IMPLEMENTATION-SPEC.md` §球杆外观（2026-09-13）。详 `tasks/CUE-STYLES-20260913.md`。

## FL-062 — 球杆风格先入为主，缺少实物分区依据（2026-09-13）

- 用户指出不能只做后把、不能用尺寸区分小头大头，随后要求实物参考及更密更深的剑纹；此前误将参考要求理解成否决主题，现纠正。
- 原因：将贴纸主题当成整杆设计，在核对常见木材/插花/握把结构前生成了候选；原UV烘焙还出现纹理扭曲。
- 处理：保留被否决产物在output；从原模型仅修改UV，参考白蜡木/乌木及枫木/握把分区重做；单独检查前节近景，加入十款位置/姿态不变断言与实际iOS渲染。
- 已应用至：`.cursor/rules/57-ui-reviewer.mdc` §FL-062（2026-09-13）。

## FL-061 — 球桌White共材质误染台呢置球点（2026-09-13）

- **现象**：深色瞄准点首轮按White材质整体染色，实际训练近景显示台呢上的置球点也变深。
- **根因**：材质名不等同于单一视觉区域；White同时覆盖库边和台内标记。
- **修复**：改色限定于有效X-Z台面外，台内保留原始diffuse；不改几何。
- **证据**：output/table-styles-20260913/contrast/ui-r1；修复后rail-only批次。
- **已应用至**：.cursor/rules/55-test-engineer.mdc § FL-061（2026-09-13）。

## DR-197 — 球体重复静态冲量约束去重（2026-09-13）
- **反例**：W07 occupied-bag-r1中袋底三角扇共点为同一球产生重复向上支撑，联合冲量残差7.997558904015989e-08，原4096次预算内不收敛。
- **原因**：完全相同的接触雅可比/材料律不增加物理自由度，却增加同步Jacobi的全局松弛分母；多份非唯一反力分配拖慢与球球接触的耦合。
- **改动**：resolveCoupled仅对同一A、nil B、完全相同normal/restitution/friction的静态约束去重；不同法线/材料与球球约束保留。不改CCD、几何/位置、恢复/摩擦参数、残差或迭代上限。
- **验证**：原真实袋底反例保留。occupied-bag-r3三项通过；同构建test-without-building补充四项通过，前后包哈希一致；完整台面入口双球/生产捕获尚未完成。duplicate-impact-red-r1与occupied-bag-r2被共享BallStickerTests编译表达式挡住，不算物理执行；仅拆分该误差表达式中间变量以解编译，计算/断言不变。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-197及`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-13）。

## DR-198 — 承接袋网默认精度采用已验证候选（2026-09-13）
- **原因**：64/2.5mm→128/1.25mm完整轨迹超过原2mm标准；128/1.25mm→256/.625mm的完整角/中袋.7s对照已通过，最大0.178/0.826mm，见numeric-bag-motion-isolated-r1。
- **改动**：PocketBagEnvelope.Configuration默认128径向/1.25mm层高；不改顶部、底部、材料筛选或捕获语义。默认构建预期72环/18304面由六袋测试复验。
- **测试契约**：testBagMotionConvergesAcrossEnvelopeResolutions继续默认→两倍比较、2mm断言不变；删除现在与它重复的旧“finer”测试包装（原128→256完整原始证据保留），短时历史诊断显式固定64基准防默认漂移。正常入口及六袋/细分不变量三测通过（bag-default128-r1）；完整台面双球承接仍在验证。此默认仍是候选物理构建，不切换正式simulate。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-198与`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-13）。

## DR-199 — 持续接触舍入尺度包含两颗球（2026-09-13）
- **原因**：resolveSupport的scale第二行以一元+开头，Swift将其视为独立未使用表达式，第二球的速度/自旋幅值未参与接触滑速舍入界。
- **反例**：A静止、B近纯滚动，交换编号/法线后应一致。独立原样源码Swift小样旧版exit1，力差3.172065784643305e-11；修复换行运算后exit0，误差0。原型从真实PocketContactResponse/SpatialBallContact源码提取，无mock；macOS编译执行不代替iOS回归。
- **改动**：二元+留在上一行，第二球项按原设计参与求和；16ulp界、摩擦、时间步、迭代预算不变。
- **测试**：testPairSupportSlipRoundingIncludesBothBodies已在wall-floor-pair-red-r1通过，原有限步/近停回归通过；该套件仍因独立三约束现场反例失败。运行中的consecutive-bag-entry-r1使用修复前构建，不能将其结果标为修复后验证。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-199及`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-13）。


## FL-063 — 着色器参数未隔离函数声明（2026-09-13）
- 台呢换色参考光照截图出现洋红球，r2测试断言通过但视觉失败，未作为有效预览交付。
- 根因：在含全局函数的Metal surface shader前增加#pragma arguments后，未用#pragma declaration结束参数区；SceneKit把函数内声明误解析为外部参数。
- 修复：按本机Apple SCNShadable.h契约分开参数/函数/主体，新增实际渲染洋红坏色断言；保留r2日志与原图，重新出片。
- 已应用至：.cursor/rules/55-test-engineer.mdc §FL-063；ClothAppearanceTests与UI规格Changelog。

## DR-200 — 文生图双面球贴纸与照片参考材质候选（2026-09-13）

- **用户授权**：重做六套、使用文生图、禁止贴图烘焙高光、每球两个相反号码；随后明确照片级目标。
- **设计**：六张原始号码图稿，Blender双色制版/球面投影/EMIT-only烘焙90图；原背部UV折叠导致首轮撕裂，改为球面展开、缝置侧面并按面拆分UV索引。SceneKit新UV显式翻转V以匹配图像原点。所有原顶点/法线/面索引保留，母球不改。
- **材质**：编号球采用0.12抛光候选；当前手机参考灯光原0.34太哑，实际同光照对照后收窄原有GGX反射。照明、球位、相机、物理不改。材质参数为照片参照外观选择，不冒充实测树脂数据。
- **证明**：90图独立回读/无透明洞/无光照色带/相反图案均通过；最终6项单测及2项实际页面UI（手机参考灯光）通过，设备Debug构建通过。实际截图无shader错误色，但App与照片目标仍有差距；六套Blender实景与文生图目标分栏展示。照片级视觉未完成，详见UR-20260913-ball-stickers-v2。
- **回写目标**：swiftui-design-system 球贴纸契约；UI-IMPLEMENTATION-SPEC Changelog；FL-060持续记录。
- **已应用至**：`.cursor/skills/swiftui-design-system/SKILL.md` §DR-200；`tasks/UI-IMPLEMENTATION-SPEC.md`（2026-09-13）。

## DR-201 — 顶点与边线求根前的保守位移界（2026-09-13）
- **依据**：两次活跃长测采样都主要落在firstContact逐特征四次求根。独立原算法/筛选版12000随机与退化输入、217736真实袋网候选查询逐值一致；实际网格小样约.546s→.160s，不代表完整轨迹或手机性能。
- **改动**：内部roots计算距离与|v|dt+|a|dt²/2，距离大于R+全段位移界+世界尺度64ulp余量时才返回无根；仍可能接触时保持原QuarticSolver。只跳过可证明达不到的顶点/无限边线，不更改球半径、几何或碰撞阈值。
- **验证范围**：真实网格来自默认128档输出环，状态取正常台面入口样本；加速度覆盖零/重力假设，并非重演所有受力段。原同输入命中TOI/点/法线严格相等。新增转向/精确端点/短区间测试，iOS待当前长测终态后执行。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-201与`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-13）。

## DR-202 — 联合冲量的受保护外推加速（2026-09-13）
- **反例**：consecutive-bag-entry-r1袋壁/底面/球球三个独立约束，4096次后残差7.532151475080169e-11；wall-floor-pair-red-r1快速复现，不是重复约束或初始穿透。
- **分析**：独立analyze_wall_floor_impulse.py复现缓慢固定点收敛，深度一Anderson候选约252次达到原量级精度；力分配缓慢变化而运动接近稳定。数值草稿不代替Swift验收。
- **改动**：resolveCoupled保留原松弛映射，外推候选投影到非负法向/Coulomb圆盘，仅实际固定点残差比原下一步更小时采用。原4096预算、64ulp运动变化与自然互补残差验收均不变；无跨事件热启动，无接触参数变化。
- **验证**：impulse-acceleration-r1四测0失败（9.001s），现场反例0.007s通过，另含重复约束/正反序、跨owner支撑、高速同刻确定性。完整consecutive-bag-entry-r2仍在执行，不宣称W07完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-202及`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog（2026-09-13）。

## DR-203 — 有限步法向支撑与受保护持续力外推（2026-09-13）
- **反例**：完整双球r2四约束持续力残差3.3094123584862303e-13，bag-force-red-r1快速iOS复现；增至8192的独立诊断仍失败，生产4096预算不变。
- **修正**：单球forceMap与多球resolveSupport在有duration时共同使用vn/dt+法向加速度+曲率的步末条件，与既有切向slip/dt一致。单球最终残差检查同步；无duration保留连续力契约。多球持续力加入深度一Anderson，候选投影到非负法向/摩擦圆盘，仅原自然残差优于普通下一步才接受。64ulp阈值、4096预算及材料参数不变。
- **验证**：normal-support-step-r1五测通过；扩展21档dt后r2六测中一方法失败，保留失败日志。独立bag-force-normal-evaluation证实SIMD归一化与标量除法的微小vn差异在极小dt下被1/dt放大：最小档标量约1.05e-13、SIMD约1.46e-9。r3保留1e-12加速度断言并统一系数计算方式，另以独立SIMD计算步末速度、按64ulp速度尺度检查；六测零失败（0.906s）。没有提高原求解器阈值。
- **范围**：快速现场/双球舍入/有限步摩擦/近停推进/折面/跨owner通过；完整台面入口双球consecutive-bag-entry-r3另验，不能据此关闭W07或宣称生产自然进袋。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-203、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog与W07-working（2026-09-13）。

## DR-204 — 多球压力投影排除被面覆盖的边特征（2026-09-13）
- **反例**：完整双球r3在.689322s、五个压力约束达到投影4096上限；pressure-edge-red-r1用原始现场4.340s精确复现。13230垂足在面内、13231垂足在面外，二者共享边而非同法线重复面。
- **修复**：projectPressure每轮按修正后的球心调用既有exposedSupportCandidates，仅排除被当前相邻面覆盖的边特征；真实折面保留。不改变持续力候选、CCD、4096上限、64ulp或4tol修正预算。PressureContact与projectPressure为internal以便@testable直接复现，不是公开App API。
- **验证**：pressure-edge-r2四测0失败（7.001s），含现场独立间隙/法向速度、非共面边、真实折面、堆叠近停。原红日志和四面坐标附件保留；完整双球r4另验，不据快速绿关闭W07。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-204、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog与W07-working。

## DR-205 — 最近点查询去除临时数组（2026-09-13）
- **依据**：连续双球r3两次采样主要落在projectContactPositions的closestPoint。独立原源码/同序直接计算版10万随机退化输入、217736真实袋网候选查询逐值相同。
- **改动**：closestPoint展开三边面内测试，逐边求最近点并保持相等时首边优先；保留所有算式、退化阈值、面内余量及比较顺序。未改变几何、求根、接触模型或迭代预算。
- **边界**：macOS真实查询-O约.018829→.004034s、-Onone约.473010→.218360s，不代表完整轨迹或手机性能。生产替换后的iOS与完整双球在consecutive-bag-entry-r4执行，未提前宣布通过。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-205、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog与W07-working。

## DR-195 补充：球袋组件统一配色（2026-09-13）
用户批准以袋口配色统一圆环和承球支架，取代四款固定金黄色五金。胡桃木暖驼色、炭黑香槟色、象牙白深灰褐、粉色白色；白网继续固定白色。TableAppearance 捕获 Gold/Black 材质槽并按 pocketColor 设置柔和金属色，标准款恢复原金色基线。皮革仍用现有材质着色与角色高亮路径，不改变物理或台呢。实现来源：tasks/TABLE-STYLES-20260913.md；已应用至 tasks/UI-IMPLEMENTATION-SPEC.md 本补充契约。

## DR-206 — 袋承接代理的共享数值快照（2026-09-13）
- **目的**：生产混合调度下一步需要完整袋代理，避免消费者各自从SceneKit重建或采用不同精度。
- **接口**：PocketGeometryAsset.bagEnvelopes() throws按既有默认128/.00125构建全部袋ID；独立实例锁保护懒缓存，全部成功才发布，失败不保存半套结果。只缓存纯数值，不持有场景节点；自定义精度仍显式构建，不能覆盖默认快照。
- **验证准备**：既有六袋几何测试增加缓存ID全集及与独立可见场景提取的rings/bottom/面数对照。middle-split-red-r2中该六袋测试通过（8.281s）；同套件中袋现场仍有两断言失败。r4已因重复异常模式主动取消并留证，不代表正式捕获接入完成。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-206及`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-207 — 受压球组的新静态冲击是共享事件（2026-09-13）
- **证据**：middle-split-diagnostic-r1显示球0在.66438714895碰到新袋壁21489；旧整步继续到.6644058267。末态新壁vn约-8.165e-6、袋底间隙5.718e-12，导致下一步丢失底部支撑/球球压力并重新冲击。不是应提高静止阈值的舍入问题。
- **修正**：advanceCoupledTrial将受球球压力连接物体的首次静态接触纳入最早共享事件；按接触前状态联合resolveContactGroup，只提交事件前缀，下一次调用重建受力。无新增恢复/摩擦系数，无精度/预算放宽。
- **断言纠正**：旧现场测试断言whole/fine都不应有冲击，隐含“没有新静态接触”，被原始staticContacts记录推翻。改为testMiddleBagNewWallContactInterruptsLoadedGroup，要求whole与half均在首个新壁接触时结束并产生联合约束；旧红日志/诊断保留。没有靠删除真实接触通过测试。
- **验证**：middle-shared-impact-r1三测0失败（11.120s），包括现场/原无新接触持续压力/堆叠近停。追加现场后1ms连续推进与连续间隙检查，middle-shared-continuation-r1待终态；完整台面入口仍须复验。
- **接口**：PairForcePlan/sustainedPairAcceleration改internal供@testable核对真实支撑集合，不是公开业务API。生产事件接入须区分参与约束与实际冲击事件，不能把新静态事件的所有压力邻居都无条件计成新的业务碰撞。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-207与`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-208 — 受载接触组的有条件微反弹消除（2026-09-13）
- **证据**：DR-207正确截断首次新壁事件，但middle-shared-continuation-r1仍在后续微秒段重复事件差异，主动取消exit73保留。独立现场全组法向投影将动能由9.28868646468e-5降至9.28868640820e-5，反弹重力上升高度4.203e-14m；原样Swift持续力求解在三个dt下四接触均正压力，见group-microrebound-projection.json/support-r1.log。
- **接口/算法**：preparedGroupSupport在整个线速度空间构造静态/球球接触法向，用重正交基投影消除低于既有tolerance高度预算的向外微反弹。任何真实向内接触先回原冲量流程；大分离不纳入投影；校验全部法向无新穿入、总平动能不增加，并要求每个被消除的微反弹接触在候选状态的持续力解中实际承压。位置/角速度/时间不变，未增加容差、迭代预算或改变摩擦恢复系数。
- **范围**：原单球行为保留；内部PreparedGroupSupport用于复用已计算的力计划，避免候选接受后重复求力。算法仍需完整双球/跨域等验收，不是正式捕获接入。
- **验证**：group-microrebound-r1三测0失败，14.155s；现场后1ms在2次推进到达终点，连续间隙、能量、位置/自旋保持、真实入射不消除断言通过；原无新接触支撑与堆叠近停通过。完整consecutive-bag-entry-r5复验中。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-208、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog与W07-working。

## DR-209 — 设置外观组合预览（2026-09-13）
- **需求**：球房保持组内首位，与球桌选择样式一致；选择台呢等选项时显示已选搭配。
- **实现**：AppearanceCombinationPreview独立场景，直接消费当前roomStyle/tableStyle/clothColor/showsTableSights；SCNView按需重绘。设置外观入口合组并下移至常规设置后、数据管理前，详情共用预览和选择列表。保留球房Debug范围与其他设置行为。
- **规则回写**：组合预览不得退回固定标准球桌图；独立存储不等于独立视觉上下文。修改一项应保留其他已选项，须验证跨页、返回、重启及参考点开关。
- **已应用至**：`.cursor/skills/swiftui-design-system/SKILL.md` §DR-209及`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。
- **验证**：见tasks/SETTINGS-APPEARANCE-20260913.md，执行中。

## FL-064 — 组合预览的正交机位被房墙遮挡（2026-09-13）
- 首轮UI功能通过，但加入房间后旧独立球桌相机的图像平面部分越出近墙，遮挡球桌；本轮不宣称视觉通过。
- 保持取景方向和正交尺度，按源房间范围将相机沿视线移入，四角边界数值校验后复拍。
- **已应用至**：`.cursor/skills/swiftui-design-system/SKILL.md` §DR-209及`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；设置记录持续保存前后证据。

## DR-210 — 共享碰撞时刻保留承压几何（2026-09-13）
- **根因证据**：完整双球r5及diagnostic-r1在角袋.64016249185出现1.954e-12m球间隙，缺球球约束抛invalidInput。真实起点短回归固定整步通过、共享半步red-r2在9.107s复现；不能用固定步通过替代运行时路径。
- **变更**：advanceCoupledTrial事件前缀与普通步末同样投影已承压几何，采用projectPressure原有4*tolerance护栏/有限特征释放；只取校正位置，保持原入射速度、自旋、时间供联合冲量。未放宽接触阈值、删除入口guard或增加迭代预算。
- **验证**：event-pressure-geometry-r1三测通过（角袋现场、中袋持续1ms、跨owner支撑）。完整双球仍需复验，正式生产未接入。
- **回写目标 / 已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-210、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；W07-working保留完整失败及修复证据。

DR-209 / FL-064最终补充：三设备最终定向UI各1项0失败，实际房间/台呢原图已审；六项按用户纠正下移；verify-gate/doc-size/diff-check通过。本地完成，真机/旧Runtime/VO/持续能耗未验；详tasks/SETTINGS-APPEARANCE-20260913.md。

## DR-211 — 持续接触受力的可行载荷重分配（2026-09-13）
- **根因证据**：完整双球r6在228.525s自然失败，time=.65215138，五约束持续力残差1.3440359936112145e-12；独立原样Swift及iOS短现场0.188s同残差复现。沿原迭代方向求可行边界仍失败，实验保留support-r6-boundary。
- **实现**：resolveSupport在现有投影/Anderson后尝试同一物体连接的活动约束之间转移载荷，投影到非负法向力/摩擦锥并检查原完整互补残差；只有残差更小才接受。不合并近似法向、不删除约束、不激活分离接触、不更改4096/64ulp或材料参数。
- **验证**：support-transfer-r1实际3测通过14.206s（五约束现场0.012s、角/中袋），boundaries-r1实际1测3.272s，正确类名boundaries-r2实际5测1.300s。合计9项，涵盖原21步持续力、双体舍入、停滑、近停及无新壁压力；完整双球仍待r7，生产未接入。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-211、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog、W07-working。

## FL-065 — 测试筛选类名不匹配导致数量误报（2026-09-13）
- **现场**：support-transfer-r1命令选择5项，实际执行3项；边界r1选择4项实际1项。评论曾误称5项通过，发现后立即更正；不将未命中项算作通过。
- **修复/证据**：按源码所属PocketGeometryV63Tests补跑boundaries-r2，实际5测0失败；上述合计9项。保留全部日志。
- **强制检查点**：报告选择性XCTest结果前，对照实际Test Case名称及Executed计数；xcodebuild退出0不能证明所有-only-testing筛选均命中。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` §FL-065及Changelog、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-212 — 保留球球碰撞预测见证及范围复核（2026-09-13）
- **证据**：r7自然失败145.795s，time=.64395061返回接触采样差1.12e-12m；起点相对法向速度+.00031579，事件前-.00033285，属于分离后重新碰撞。pair-witness-red-r1在6.787s复现。
- **变更**：advanceCoupledTrial保存产生最早TOI的球对；仅该时刻的见证球对加入原承压几何校正，沿用4*tolerance界限并保留入射速度/自旋/时钟。跨owner独立路径另验，未宣称全面修复。
- **验证**：pair-witness-r1四测中一项失败来自复制的新静态冲击断言；该场景实际是原壁支撑中的球球返回，改验静态约束、先分离后接近、碰后不相向与动能不增加，原红记录保留。r2实际4测0失败15.123s，新现场0.938s；无完整r8。
- **范围复核**：用户指出袋内固定终态投入过长，确有优先级失衡。按既有v63§5.7先落实不可逆捕获/必要可见运动结束后的停止边界；不再把袋底长期多球堆积的完整求解作为正式3D接入前置。现有全程失败保持未通过，不能用范围调整改写成通过。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-212、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog、W07-working。

### FL-066 — 海报需保留原图语义，并检查缓存复制后的文字（2026-09-13）

- **现象**：AI海报出现袋口夹角/缺号，用户要求改用已有计划和练习卡片原图。改为原图+SCNText后，场景断言通过但截图文字为空。
- **原因**：写实生成未逐项约束实体结构；当前SceneKit的SCNText.copy丢失string，原测试仅检查图片和朝向。
- **修复**：原Asset Catalog图直接复用，不重画号码/几何；文字单独排版，克隆显式保留string/font/flatness/extrusionDepth，增加克隆后文字非空与几何宽度断言。card-verified四项通过，仍以实际截图判断视觉。
- **规则改进/已应用至**：`.cursor/rules/57-ui-reviewer.mdc` § FL-066：追溯图像版本、语义近景与实际文字可见性；同步UI规格Changelog。
- **范围**：四面墙装饰，不改球桌USDZ、物理、卡片原始图片；真机未验。

## DR-213 — 软袋收集边界（2026-09-13）
- **实现**：PocketCaptureBoundary按hardSurfaces最低Y及bag.top减球半径确定中心平面，袋网层间插值截面限定XZ；firstCandidate用原空间区间的二次运动求向下穿越，保留绝对时间/速度/自旋；isClearOfActiveBalls检查同钟与邻球间隙。
- **验证**：collection-boundary-r1实际3测6.879s（六袋实测、向下/上升/袋外、活动邻球），normal-entry-collection-r1实际1测6.705s（角袋/中袋真实台面入口及能量）。捕获候选time=.25849/.28942，Y≈.71519/.71522；附件导出并生成/目视核对collection-boundaries.png。当前未接入调度或收尾。
- **决策**：见ADR-P10-10与v63.10；软袋吸收近似，保留硬质袋口物理及临界返回，袋底长期堆积不再阻塞正式3D。原失败保持原结论。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-213、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog、W07-working。

## DR-214 — 混合调度提交软袋捕获（2026-09-13）
- **实现**：simulateMixedWithLocalPockets新增显式collectsPocketedBalls（默认false，保留验证基线）；按轨迹候选与同钟所有活动邻球选择最早捕获，与跨owner事件竞争，截断预测并通过PendingMixedStep延迟至实际请求时间提交。pending校验收集配置；LocalPocketOwnership.completeCapture移出活动集合。
- **记录契约**：记录ConfirmedCapture后只发一次pocket事件，保留真实入口Double位置/速度/自旋；运行时球设pocketed并停止v/omega。收集截面/半径/高度的稳定位模式摘要形成soft-bag-v1几何版本；没有调用旧平面捕获。可见收尾尚未接入，不能把停在收集平面当最终画面。
- **验证**：mixed-collection-r1实际2测14.463s（角/中普通进袋、唯一事件、停止及分段逐值一致）；boundaries-r1实际3测15.561s（角/中连续两球+远端不动、旧任意边界续算、返回台面）。默认旧App入口尚未切换，临界吐袋/物理系数/预测及显示统一仍待验。
- **已应用至**：`.cursor/skills/ios-architecture/SKILL.md` §DR-214、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog、W07-working。

## DR-215 — 吸收式收集的共享可见收尾（2026-09-13）
- **实现**：PocketCollectionTail继承ConfirmedCapture的位置/速度/自旋，按重力继续至bag.bottom+R，之后位置固定、速度及自旋归零。Recorder.spatialStateAt统一局部区间与收尾；TrajectoryPlayback.stateAt/action及SequenceVideoExporter新记录分支保留XYZ，共用模拟时间停顿0.35s与淡出0.25s，避开旧平面入洞路径。正式simulate仍未切换。
- **验证**：collection-tail-r1实际3测12.328s全部通过：重力连续/终态固定、共享查询/倍率时长、精确分段续算。collection-visual-r1实际1测11.697s通过，导出两张角/中袋各7帧接触表并目视核验；下落后球逐渐被袋沿遮住，固定终态已不可见。普通两例收尾分别约11.5/12.0ms，不需要长时间袋底求解。
- **证据边界**：截图是SceneKit组件静态位置/透明度采样，没有验证逐帧自转、实际页面交互、视频成品或真机性能；不能把这四项测试当W07/W08完成。临界袋口/邻球/正式入口/预测与规则仍待验，原硬袋堆积失败保持原结论。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md §Changelog/DR-215（API与验证口径），tasks/3d-v63/W07-working.md与执行台账。

## DR-216 — 局部规则碰撞与支撑约束分离（2026-09-13）
- **根因/修复**：本地trial.constraints原样映射ballBall，而跨owner原有分支只上报碰前接近。EventDrivenEngine.spatialImpactEvents统一既有closing<0语义；本地从接受区间的beforeEndpoint左极限取碰前速度，零时刻取起态，跨owner复用同一入口。保留全接触组求解、冲量、位置、材料与持续支撑；不是移除静止约束。
- **证据**：rule-events-red-r1上报层短例实际1测2断言失败（静止/分离均错误上报），失败保留。rule-events-r1实际4测14.947s通过（上报三态、高速同刻2/8/12m/s、跨owner真实接触、捕获精确续算）。此红例证明映射错误，不声称已在正式页面复现误判。
- **限制**：正式simulate/预测/规则消费者仍未切换；参数与局部静态接触到业务吃库的映射另须处理，不能把静态面数量当吃库次数。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-216及Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

DR-216补验：rule-events-local-r1实际1测4.671s通过，纯局部双球验证beforeEndpoint不会漏碰、首次碰球时间一致、请求前缀不提前发布及分离续算不重复上报。

## DR-217 — 共用既有球球材料律（2026-09-13）
- **实现**：BallPhysics.contactFriction抽取现有Alciatore Float表达式，旧平面resolver同值调用。SpatialBallContact.MaterialSource提供supplied/ballPhysics；后者使用既有恢复系数.95与包含双方自旋的三维切向接触滑速计算摩擦。LocalPocketSimulation在球球冲量及持续力构建时取材料，临时力求解器继承配置；混合入口及PendingMixedStep绑定该配置，缓存中途改配置明确拒绝。
- **验证**：ball-material-r1/session12977终态0，实际4测7.224s：0–10m/s共1001个Float旧公式逐位一致、接触自旋/交换双方、独立斜碰冲量与自旋解析值、混合标准配置续算/拒绝切换、旧固定参数局部碰球回归。
- **范围**：统一材料系数，不宣称平面约束响应与空间响应逐值相同；空间保留Y方向运动。supplied仍为验证入口缺省，正式simulate未切换。台面/库鼻/皮革静态材料分类、业务吃库与预测消费者另待接入；未以四项测试宣称完整生产标定或手机性能通过。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-217/Changelog，tasks/UI-IMPLEMENTATION-SPEC.md §Changelog，W07-working。

## DR-218 — 静态表面的拓扑角色（2026-09-13）
- **依据**：同一TaiNi材质包含中央台面及袋口下沿、六段独立库边。旧网格附件先做精确顶点连通分析发现7部件，再用当前PocketGeometryAsset.tablePatches独立验证，未按材质名直接把全部TaiNi算作台面或库。
- **实现**：PocketSurfaceRoles.classify按精确顶点连通，包含中央台面点的唯一部件标clothBed，另外六个须具有实测库边高度；Leather单独标记。未知材质/不符当前模型的部件契约抛错，不按大小猜测或焊接近邻。PocketGeometryAsset.surfaceRoles以独立锁缓存纯值，未改原几何/材料/响应。
- **验证**：surface-roles-r1/session10472实际1测3.094s通过：当前模型分类/缓存、低于台面的cloth lip保留、反转面序与绕向一致、缺失结构拒绝；9701 clothBed/9963 cushion/24584 leather面。导出附件并用plot_surface_roles.py绘制surface-roles.png，顶视/侧视均已打开核验。
- **限制**：这是当前模型的消费契约，不是通用网格语义识别。静态材料响应、库鼻细分/主库索引、吃库事件去重及正式入口仍待实现。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-218/Changelog，tasks/UI-IMPLEMENTATION-SPEC.md §Changelog，W07-working。

## DR-219 — 局部吃库事件与既有库边索引（2026-09-13）
- **实现**：TableGeometry.nearestCushionIndex只把已确认的物理库边接触点映射到有限CAD直段/圆弧的原索引，包含有限端点，不使用无限延长线。混合已接受静态接触中仅cushion角色上报ballCushion；clothBed/下沿与Leather不直接计库。按球/Double接触时刻/库索引去重并跨pending续算保留；正常事件时间不依赖显示帧。业务normal为实际法线的XZ单位投影，三维原法线仍保存在原始接触记录中。
- **验证**：cushion-events-r1/session6386终态0，实际4测7.328s：六主库/全部有限圆弧中点索引、真实当前中袋旁直库碰撞反弹且只计一次、整段/分段同事件时间、落回台呢有物理接触但不计吃库、既有静态接触接受前缀回归。
- **范围/取舍**：映射不移动接触或新增碰撞检测，尚未改变局部Surface响应系数。既有库边.94是Han响应下的输入标定，不能把相同数值当三维实际反弹率已验；需以真实响应对照衔接。正式simulate/预测消费者仍未切换，特殊同刻多库及全袋范围另验。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-219/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-220 — 静态材料候选与真实响应对照（2026-09-13）
- **实现**：PocketStaticMaterial.prototype保持原.3/.2；tablePhysics(clothRestitution:)为显式候选，台呢共用滑动/滚动/自旋阻力，皮革复用袋道系数，库边按原有限CAD绑定取段/弧系数。surface索引/三角面不变；纯值按材料配置缓存，未知竖向系数拒绝；混合入口pending绑定staticMaterial。正式simulate未切换。
- **验证**：static-material-r1因测试误用旧函数名编译失败，修正为resolveCushionCollisionPure。r2实际4测/3断言失败，失败集中台呢对照；另三项（材料索引/旧默认吃库/新响应取证）通过。独立Float计算确认输入中心比Double支撑面高3.7252903nm，落地时间27.558815μs，自旋差预测.000300391rad/s与实测相符；改为从真实接触起计台呢阻力，保留全部原误差标准并新增解析落地时刻断言。static-cloth-r3实际1测3.929s通过。未改求解器或放宽误差。
- **物理发现/限制**：真实库边同输入局部出射vz=.947101/旧Han=.875972m/s，局部vy=.167700m/s；原法线约(-.00000167,-.070568,.997507)。同材料数值不保证同响应，本轮只完成候选与差异取证，不认定静态响应标定/正式发布通过。台呢竖向恢复仍显式使用.3作原型对照，不是实物测定值。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-220/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-221 — 接缝支撑见证与平面步长预算（2026-09-13）
- **问题/根因**：普通台呢接缝上的边缘距离加上共同半径后舍入近等；以宽同距集合投影且固定初始候选，会把面外边缘或修正后已分离的面当作等式支撑。标准材料与再入/捕获续算因此失败；不是袋底堆积问题。
- **变更**：PocketContactTriangle暴露projectedInteriorPoint，保留原内部判据与closestPoint行为；支撑过滤区别真实面内见证、共面面外边缘及近重合见证。末态投影用距离平方差的因式表达式比较，误差由运算尺度给出，并在每次位置修正后重建候选。未放宽投影/穿透阈值。无局部owner时复用原adaptiveEvolveCap，真实区域穿越仍截断，局部仍用maxStep。
- **验证**：cloth-seam-r4/session70824终态0，实际8测22.193s：角/中袋.5与4m/s标准材料组合的捕获/吐袋/能量、远端32事件预算和旧平面对照、捕获续算、任意截断续算、独立同刻事件、完整再入、两项折角回归。r1/r2/r3及planar-budget-r2失败均保留，数值草稿与接缝图已核验。仅显式混合入口，未宣称正式App或全部参数标定通过。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-221/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-222 — 混合入口保留搜索早停语义（2026-09-13）
- **问题**：现有ShotPredictor依赖首次指定球碰撞早停和兴趣球行程上界早停；混合入口缺少对应参数，直接替换会丢失反解预算能力。原平面能量证明不能直接覆盖空中球及尚未接管的袋口静止球。
- **变更**：simulateMixedWithLocalPockets新增earlyStopBallNames/stopAfterContactBetween，缺省nil。共用原无序球对判定；在接受完整同刻事件和记帧后检查本次新事件，未提交预测与历史事件不触发。兴趣球证明只在无pending、无空间owner、所有在场球处于平面高度/无竖向速度且不在局部接管区时复用；空间状态保守继续。
- **验证**：mixed-search-stop-r1/session83715终态0，3测7.069s：指定球碰前截断/碰后状态与整程记录对照/续算逐值/历史事件不重停、空中势能保护、既有同刻独立事件。mixed-search-group-r1/session73475终态0，1测3.544s：指定其中一对早停仍保留完整同刻三球双碰。mixed-interest-stop-r2/session87218终态0，1测4.620s：扩展远端静止/空中/袋口静止失撑三态。4个不同测试，兴趣测试扩展后复跑；不将5次执行说成5个不同测试。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-222/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。正式simulate/ShotPredictor调用尚未切换。

## DR-223 — 引擎停止原因贯通真实预测结果（2026-09-13）
- **问题/范围**：simulate原来无返回值，预测无法区分完整停稳、时间/事件截断与主动早停。审计确认SimulationWorker当前无实例化消费者，优先处理ShotPredictor两条真实路径，不扩建闲置Worker。
- **API**：EventDrivenEngine.Termination包含settled/timeLimit/eventLimit/contactResolved/interestResolved；simulate与显式混合入口均返回该类型，@discardableResult保持调用兼容。混合工作预算/数值错误仍显式throw，不转成成功。ShotPrediction.termination经simulateFree及runShot→buildPrediction传递；nil表示未执行模拟，feasible继续只表达几何可行性。
- **验证**：simulation-termination-r1/session38350终态0，实际3测6.655s，覆盖旧平面/混合停稳与时间截断、旧事件预算/新工作预算异常、真实simulateFree状态与非零尾速、既有碰后续算。主动早停返回原因补验见W07-working最新条目。
- **边界**：此次只贯通结果契约，尚未实现页面错误提示/重试，也未将生产simulate切换混合模型；不能凭新增状态字段宣称已阻止所有截断轨迹上屏。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-223/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-224 — 未完成预测的实际消费者检查（2026-09-13）
- **问题**：末速度接近零不能独自证明模拟完成；实时解/序列缓存与导出可能把截断轨迹当作完整一杆。不能仅给ShotPrediction添加状态而不检查消费者。
- **变更**：hasFinalTableState仅接受settled，hasResolvedSearchState接受settled/interestResolved。PositionPlaySolver落区及防守停点同时检查搜索完成状态与原末速条件；PositionPlayViewModel异步求解、翻袋切换、序列呈现四处通过applySolvedShot统一写入，未完成可行预测清理旧解/辅助显示、禁止出杆并提示调整参数；序列缓存只接完整状态。SequenceVideoExporter共同运动帧路径明确抛incompleteTrajectory，避免把截断的可行模拟当正常过渡跳到after。
- **验证**：prediction-consumers-r1/session71231编译失败（测试缺MainActor），未执行通过；r2/session88107终态0，2测.142s：真实预测的完成/截断与未知/搜索状态拒绝、有效结果恢复、导出校验及真实落区求解。统一实际写入入口后prediction-delivery-r1进一步验证原有效solvedShot被清除，终态见W07-working。
- **边界**：此次为ViewModel/求解器和导出前置校验，未执行实际页面截图或完整视频导出；其他专项页面、开球与最终混合入口切换继续在全范围内待办。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-224/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-225 — 真实预测路径的统一模拟入口（2026-09-13）
- **变更**：simulatePrediction以SimulationModel选择planarReference或显式localPockets(material:)。ShotInput携带模式贯穿runShot的搜索与buildPrediction；simulateFree新增同一模式参数，两条真实路径均通过该入口。当前缺省仍为planarReference，全面切换未验收，禁止把显式局部测试说成默认页面已切换。
- **局部入口**：采用标准球球材料、软袋收集与共享尾段，初次模拟沿用50次初始重叠分离。业务事件预算maxResolvedEvents与迭代保护maxLocalSteps分开；同刻组完整提交后才检查事件预算。局部异常记录诊断并返回Termination.failed(String)，不重跑旧捕获规则、不冒充成功；失败状态由已有完整性检查拒绝。
- **验证**：predictor-local-entry-r1/session1129因模拟器ID抄写错误，核对PID8962后主动终止，exit143，无产品测试结论；r2/session96281终态0，3测13.312s：真实simulateFree角/中袋捕获/收尾且旧pocketEntries为空（2.598s）；真实指定袋口predictForPositionSolve保留模型并捕获目标球（2.777s）；零业务预算/局部工作失败/远端32预算（7.937s含加载）。默认兼容及失败消费者补验见W07-working。
- **边界**：局部材料仍显式选择tablePhysics(clothRestitution:.3)，不宣称实物标定；局部路径使用已有自适应平面步长，未承诺与旧非高保真搜索逐位相同。默认切换、其余消费者、完整预算/同刻截断/手机成本继续验收。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-225/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-226 — 固定局部物理准备数据复用（2026-09-13）
- **实测问题**：每次局部预测重建同一BVH与六袋收集边界。preparation-baseline-r1/session43985终态0，1测8.877s；5次短预测首轮3719.895ms，后四轮551.304–554.484ms，均值553.059ms。该微场景无袋口接触，主要暴露固定准备成本。
- **变更**：PocketGeometryAsset.localSimulation按静态/球球材料缓存只读LocalPocketSimulation（固定面、常量、BVH）；MaterialSource增加Hashable。captureBoundaries缓存固定六袋边界与版本，完整构建才发布。独立NSLock保护缓存；球状态、轨迹、pending与事件留在各Engine，不共享运动状态。非法静态参数先验证再作为缓存键。
- **验证**：preparation-cache-r1/session96881终态0，3测10.437s，热均值26.621ms；收集边界复用后r2/session33052终态0，3测9.990s，热均值.16175ms（范围.147625–.220708ms）；真实自由预测角/中袋捕获及精确续算均通过。comparison JSON在output/3d-v63/W07/preparation-comparison.json；所有原始结果保留。
- **边界**：模拟器Debug、同一简单短预测的热准备成本；不是全杆吞吐/真机帧率证明。首次加载、复杂接触和真实手机内存/热量仍未验；不因此放行默认全面切换。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-226/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-227 — 袋口支撑静止球允许整杆结束（2026-09-13）
- **根因**：混合调度只在owner为空时判整桌停稳；实际目标已进袋、母球速度/自旋归零但仍处于局部区域时，仍标sliding并跑满maxTime，最终被完整性检查拒绝。初始袋口附近静止球也复现。
- **变更**：从planarReturn提取同一planarSupport支撑证明，区域退出/接管规则不变。无pending时，所有未捕获球须为台面支撑且严格零速度/零自旋的local owner，或已静止且不在待接管区的平面球，才标记stationary、记帧并返回settled。没有增加阈值或强制清零运动，没有释放局部所有权。
- **验证**：local-rest-red-r1/session63291终态65，两个真实用例失败，母球末速0却timeLimit，原日志保留；local-rest-r1/session76049终态0，4测11.846s：完整目标进袋母球停稳、袋口静止支撑、空中/失撑不早停、完整再入。输出状态stationary，已有停止前缀/区域退出含义保留。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-227/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

## DR-228 — 翻袋与反射消费者完整性检查（2026-09-13）
- **范围/变更**：BankShotViewModel与DiamondSystemViewModel在自由预测返回、运杆前及回放时共用acceptFreePrediction；未完成/无recorder时保留before球形、结束播放态、恢复瞄准并显示simulationNotice。有效结果清提示。求解演示/播放仅接受完整桌面状态，解目录过滤截断结果，微调展示另行校验；全部候选被过滤时明确提示模拟未完成。
- **验证**：bank-kick-consumers-r1/session7749终态0，实际3测5.314s：两页未知/时间/预算/碰撞早停/兴趣早停/failed状态拒绝、球形恢复及有效结果恢复；真实翻袋微调目录不变/循环恢复（3.919s）、反射同项（1.385s）通过。gate/session67132终态0，81 routes/146 write-surfaces及文案门禁通过。
- **边界**：未以模型测试替代页面视觉验收；图谱只消费特定前缀，不能无条件套用全桌settled要求，须按其碰撞终点核验。瞄点验证/开球/其他消费者、默认混合切换和全面手机验收仍未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-228/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-229 — 开球统一预测入口与完整结果交付（2026-09-13）
- **根因**：BreakSimulator独立调用旧simulate，并按XZ末速<0.3推断settled；低速但时间预算截断时可误报完成。BreakFlowRunner未在运杆前检查结果。
- **变更**：breakShot增加随请求传递的simulationModel，经simulatePrediction调用；BreakResult保留termination，settled仅等于引擎settled。只有完成才执行原静止重叠清理。runner在起播前共用acceptCompletedSimulation，拒绝未完成结果并恢复racked，保留现场摆位/方向/力度/打点、禁止确认及交付，显示重试提示。
- **验证**：break-unified-entry-r1退出0，4测/0失败/7.511s；真实低速maxTime=0截断不会交付，正常结果可再次接受；无效局部材料failed无平面回退；旧开球确定性和手动确认通过。break-local-full-r1退出0，1测/0失败/8.564s；实际9球seed7默认6m/s显式局部模式正常settled、10球完整，计算8.536s（含本进程准备成本），本杆pocketed为空，不能作为开球进袋证据。gate退出0，81 routes/146 write-surfaces及文案门禁通过。
- **边界**：默认仍planarReference；未证明所有玩法局部开球、进袋开球、真机耗时或提示的实际UI。没有新增袋内微接触求解。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-229/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-230 — 图谱按所需事件片段验收（2026-09-13）
- **根因**：图谱把cuePath末端当停点，不检查模拟是否截断；但要求整桌settled也会丢弃已完整的教学片段。
- **变更**：两图谱增加hasCompleteSlice；分离角接受完整桌面或已记录碰后首库；加塞吃库接受完整桌面、已记录二库或已有0.40m库后片段。原切片几何/教学盘面/打点/颜色不变。切片入口拒绝不完整结果，VM逐档检查，仅保留完整档位并提示部分模拟未完成，拒绝档位不画碰前stub。
- **验证**：atlas-completion-r1/session25506退出0，实际14项测试/0失败/0.414s。新增真实时间截断验证分离角首库前拒绝/首库后虽timeLimit仍接受，加塞首库后短截断拒绝；完成路径改为timeLimit的契约用例证明完整片段不依赖全桌状态。原低力度停点、切片端点、8档吃长库、打点边界与挤偏补偿回归通过。
- **边界**：未改最近点切片算法；当前测试为默认平面预测与模型契约，不代表图谱新版局部物理预算、实际提示UI或所有3D图谱验收。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-230/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-231 — 瞄准点验证失败保留当前题目（2026-09-13）
- **根因**：验证击球只检查recorder/duration，无记录时直接advanceAfterStrike，截断预测也会播放并自动换题。
- **变更**：acceptVerificationPrediction在进入striking/清除辅助线/运杆前检查完整结果；失败取消自动击球任务、保持showingResult与原答案，verificationErrorMessage驱动系统弹窗。重试仅重复strike，不重复submit/计分/保存；下一题由用户明确选择。新题清错误态。
- **验证**：aim-verification-r1/session41669退出0；2测/0失败/1.335s，未知/时间/事件/failed结果保留题目坐标、误差和答案数量，完整预测恢复清错误；原2D/3D练习不泄露理想方向回归通过。
- **边界**：系统弹窗实际页面视觉与按钮流程未验，尚不能声明本页面全部完成；正常后续播放结束时机仍由W08统一审查。默认局部物理切换仍未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-231/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-232 — 三个规划页完整结果检查（2026-09-13）
- **范围**：SiluTrainerViewModel、PlanThreeViewModel、SnookerTacticsViewModel。
- **变更**：canStrike要求hasFinalTableState；展示目录/微调结果前共用acceptCompletePrediction，未完成时清轨迹/藏杆/清瞄准方向并提示。上一杆回放同样在修改场景与播放态前检查；原解目录、草稿与撤销模型保留。
- **验证**：planning-completion-r1/session14075退出0；5项/0失败/25.846s。三页未知/时间/预算/兴趣早停/failed结果拒绝与完整结果接受；真实三个页面微调目录与循环恢复、连续微调保留前次打点均通过。Snooker完整测试23.352s，包含求解/微调/断言，不是单次预测或真机性能指标。
- **边界**：页面错误提示实际视觉、局部模式求解预算与默认切换未验；不把消费者守卫视为W07完成。仍须核对EngineCushionTracer旧直接入口，SimulationWorker目前无实际实例不可冒充用户链路。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-232/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-233 — 反射追迹统一入口与截断终点（2026-09-13）
- **变更**：EngineCushionTracer.launch经simulatePrediction，Launch携带termination；shoot的模式参数贯穿miss搜索与build重建。仅settled追加自然末点，时间/事件截断或failed不把最后记录帧补成停点，既有已完成库间片段与斜库截断规则保持。显式局部材料失败不回退。
- **验证**：reflection-entry-r1/session60323退出0，11测/0失败/14.053s。短时截断只留下起点；显式局部低速球正常停稳、无效材料failed；原单库求解、长库分类、翻袋/反射真实模式及力度响应回归通过。局部测试是低速无库球，不替代局部多库反解验收。
- **边界**：默认planarReference仍待切换验证；当前产品实际直接旧simulate只剩无实例的SimulationWorker（本轮检索），不得据此称全物理完成。W07默认切换、性能与临界捕获回归、提示UI仍未完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-233/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


## DR-234 — 默认预测切换局部进袋（2026-09-13，全面验收中）
- **变更**：SimulationModel.appDefault为不可变.localPockets(tablePhysics(clothRestitution:0.3))；ShotInput/simulateFree、BreakSimulator、EngineCushionTracer.launch/shoot共用默认策略，显示2D/3D不选择物理。显式planarReference保留作旧基准对照。删除ShotPredictor“主线程可直接跑且极快”的过期注释，页面后台调用需继续审查。
- **切换前证据**：local-search-r1/session82634退出0；实际单库局部射击法（搜索与build）6.597s到达目标，中袋完整predict瞄准搜索7.795s、settled且真实捕获；2测/0失败/14.448s，计时含进程准备差异，非真机预算。
- **切换后证据**：default-local-r1/session1079退出0；默认simulateFree中袋确认捕获/无旧pocketEntries1测7.247s，实际S2_ShotPagesLayoutUITests.testShotSimulation3DPilot 1测90.259s/0失败。完整观察/手势/后台恢复/击球/回放/重打通过；本轮after-3d-pocket与after-replay-3d原图已目视，独立附件位于output/3d-v63/W07/default-local-r1-attachments。页面流程击打自由球，不能当动态进袋验收。gate/session49022退出0，81 routes/146 write-surfaces及文案检查通过。
- **未完成**：W07临界旧基准差异分类、全页面/开球玩法/反解吞吐、同步主线程调用、错误提示UI；W08动态进袋/遮挡/任意定位/实际导出及后续完整范围。静态台呢e=.3为候选，未宣称实物标定。当前源码默认已切换，不能再沿用“生产默认未接入”描述；全面验收仍在进行。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-234/Changelog；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；ADR-P10-11；W07-working；v63.11。


## DR-235 — 局部静止残差与阻力矩平衡候选（2026-09-13，验收中）
- **根因证据**：低杆目标球v约1e-178但严格零判据导致timeLimit；独立单平面小坡度复现步长相关爬行，排除袋口网格依赖。surfaceResistance仅按起始omega/dt制动，未平衡接触力产生的角加速度。
- **当前变更**：EventDrivenEngine仅在已验证台面支撑的全桌静止条件下归零64ulp范围内线速/球面自旋速并提交所有权状态。LocalPocketSimulation在每次接触力候选下共同求解压力有界的滚动/旋转力矩，投影保持各接触力矩容量，使用求得的角加速度校验接触约束。极短步的force相对残差考虑速度舍入除以dt的下限，原约束位移预算保留。单球快捷分支已撤下，既有117.600/166.445s不能作当前性能值。
- **验证**：coupled-moments-r1/session39754终态0，实际4项/.519s：小坡度两步长位移降至1e-21m量级，大坡度解析运动、原平面滚动减速及无滑动摩擦时不造能通过。低杆恢复此前在rest-only回归验证；本候选真实袋口/多球/性能尚未完成，prototype临界投影失败仍保留，不能宣称进袋验收完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-235；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。


### DR-235 补充验证：优化测试构建结果（2026-09-13）
- optimized-test-build-r4/session19879终态0，TEST BUILD SUCCEEDED；优化级别-O、Release配置但保留DEBUG测试入口与testability，不能称正式Release验收。源hash与optimized-build-r3-source.txt逐项匹配。
- optimized-tests-r1/session67857：实际4项/1失败/21.018s。两个15球用例通过：方向响应5.100s、重复确定性3.029s，每项2杆，新增a/b.settled断言确实执行通过（四杆正常结束）；角/中六种边界通过11.137s，同源码Debug对照286.016s；旧临界步长1.752s仍同t=.0009999999999981044、dt约1.896e-15、force错误失败。
- 已区分编译与算法成本：当前优化构建能完成15球与正式默认边界，但仍需手机实测与页面后台等待审查；默认边界11.137s包含六种输入，不能称单杆11秒或正式性能验收。旧临界尾段数值错误与优化无关，继续处理，W07及后续范围未完成。


## DR-236 — 空间进袋导出不再重复追加旧动画时长（2026-09-13，验收中）
- 根因：SequenceVideoExporter只按pocketedBalls非空追加旧pocketSettleDuration，同时空间捕获已自带下落、停顿与淡出绝对结束时刻，形成重复等待。
- 修改：motionEndTime按球区分空间尾段与旧帧轨迹；空间使用collectionPresentationEnd，旧捕获才加旧动画预算；保留全桌运动和跟杆结束上限。
- 验证：角/中袋共用测试补.5/1/2倍速与实时SCNAction时长一致、早捕获不延长其他球停稳后等待、混合旧轨迹仍留预算。首轮编译失败因测试未标MainActor，未运行断言；已按导出器隔离要求修正，export-tail-r2运行中。未宣称实际视频验收。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-236；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

- DR-236验证补充：export-tail-r2/session57196终态0，实际1项/0失败/9.245s，角/中袋各三种速度及早捕获/混合旧轨迹时长断言通过；gate/session1754终态0，doc-size与diff-check通过。首轮export-tail-r1/session49664编译失败，未执行测试。当前证明生产导出结束时间计算，实际编码视频/暂停恢复尚未验收。


## DR-237 — 序列页面按全桌动作结束收尾（2026-09-13，验收中）
- 根因：详情/试打序列页面在母球action结束后无条件按进袋球非空等待旧尾段，空间捕获重复等待；独立Task.sleep也脱离节点动作取消。
- 修改：DrillSceneController.playStep、PositionPlayViewModel.runSequencePlayback取所有球action.duration最大值，与母球动作组共同结束；只有旧帧捕获保留旧预算。移除额外sleep，试打回调检查sequencePlayState仍playing。未改变杆边界暂停、杆间停顿与最终复位语义；未宣称已解决所有跨轮回调竞态。
- 验证：修改前两实页测试通过（sequence-boundary-r1，281.462s），修改后sequence-boundary-r2/session15475运行中。首次编辑脚本完成详情页后因试打方法名匹配失败退出，已按实际runSequencePlayback补齐并核对两个位置。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-237；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

- DR-237验证补充：sequence-boundary-r2/session15475终态0，TEST SUCCEEDED，实际2项/0失败/279.608s；详情49.674s、试打229.933s（含固定测试等待，不能作性能提升值）。暂停/继续/上一杆/整段复位通过，12截图已导出，最终复位图已查看。gate/session14588、doc-size、diff-check通过。实际3D切换、硬停快速重启竞态、编码视频仍待验；当前无活跃句柄。


## DR-238 — 手机竖版3D教学视频俯角（2026-09-13，验收中）
- 实际编码视频显示30°整桌入镜在竖版中台面过短、留黑多；算法已是固定俯角下最小可行距离，直接拉近会裁两侧。
- 用同一杆402×761教学静帧对比30/45/60°，portrait-framing-r1/session79484实际1测12.119s通过；45/60原图已审，60°台面路线更易读，桌体完整。仅Options.teachingVideo3D（及继承预设）用60°，通用Perspective3DConfig默认30°保持。
- SequencePerspectiveFitTests的独立角点/最小距离矩阵补60°；portrait-fit-r1/session92541运行中。新预设动态编码/原生1080视频及手机实际观看仍待验，不将静帧对拍称为全部完成。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-238；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W07-working。

- DR-238验证：portrait-fit-r1/session92541终态0，实际5项/0失败/.004s；独立角点/最小距离矩阵已含60°，其余既有测试通过。doc-size和diff-check通过。尚未用新预设重编码视频，原encoded-sequence-r1仍为30°基线，禁止混用。

- DR-238实际视频验证：encoded-sequence-r2/session16922终态0，实际1项/0失败/16.530s；60°新预设30fps=8.700s、60fps=8.683333s，均有真实空间捕获。视频与8帧中袋抽帧在output/3d-v63/W08/encoded-sequence/232C8959-D0EE-4C73-8AA5-94960F5C346C，已实看目标球接近袋口、消失后不再出现。ffprobe核验60fps/521帧/402×761。与30°基线时长一致；旧基线保留。此为402宽验证，1080原生/真机观看及逐世界状态跨帧率仍未验。


## DR-239 — 3D开球保留模拟失败提示（2026-09-13，验收中）
- 现场：w09-disabled-r1的9球模拟返回racked；2D显示未完成错误，3D被固定“刻度轮调方向”提示覆盖。
- 修改：BreakFlowRunner新增只读发布simulationFailure:Termination?，失败保存具体停止原因，成功/重摆清空；FreePlayView仅在无失败时用3D操作提示覆盖racked默认说明。不把失败结果交付，不改变物理阈值。
- 验证：现有不完整开球测试补失败原因与成功/重摆清理断言。r1误用类名运行0项（不计通过）；r2/session45354正确选择器运行中。当前修复提示遮蔽，原数值失败/散局求解仍未解决。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-239；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W09-working。

- DR-239验证：w09-failure-status-r2/session45354终态0，实际1项/0失败/16.164s，失败原因保存、成功清理和重摆清理断言通过；gate/session45934终态0，doc-size与diff-check通过。修复后实际3D失败现场尚未重拍。开球初始seed来自随机值，需在下一次失败时记录seed及击球输入才能固定重现数值失败，不能把前后不同结果归因于一次代码修改。当前全部句柄终态。


## DR-240 — 3D打点面板改为浅横排（2026-09-13，验收中）
- SE截图复现旧十字盘遮母球，旧UI断言只验证微调与主要按钮位置，未覆盖球体可见性。
- BTSpinPadCard/Overlay新增usesCompactLayout（默认false），3D调用选择球盘与完整方向十字并排，盘径3×keyHit，卡宽不超过2×maxPadDiameter；保留拖动、四向±1%长按、回中、只读与锁侧塞语义。2D保持原布局。
- 接入BreakInstrumentsOverlay、FreePlayView、ShotSimulationView三个实际消费点。compact-pad-r1/session5338终态65：分离角流程通过88.342s；自由击球开球计算60.495s超时后settled。已看15球展开图和分离角after-spin，母球完整露在面板上方；固定慢种子及证据见W09-working。未用一图宣称标准/iPad/任意相机姿态全部验收。
- **已应用至**：.cursor/skills/swiftui-design-system/SKILL.md §DR-240；tasks/UI-IMPLEMENTATION-SPEC.md §Changelog；W09-working。

## DR-241 — 实时击球与上一杆回放等待全部球收尾（2026-09-13，验收中）
- 审计发现PositionPlayViewModel.launchBalls/runPlaybackAnimation仍在母球动作后固定Task.sleep旧尾段，空间捕获重复等待，其他球晚结束也未纳入结算时钟。
- 两条路径沿用DR-237：聚合全部球action.duration，以母球group wait承载可取消等待；仅旧记录捕获保留历史收尾余量。主线程结算前检查isPlaying，不声明解决全部快速重启竞态。
- live-tail-r1运行中，包含共享空间收尾单测及实际分离角3D击球/回放；母球落袋完整页面仍待补。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-241；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-242 / FL-067 — 自由击球落袋母球补回入口（2026-09-13，验收中）
- P1：FreePlayView.paletteBar对全部离场球只提示不支持手动摆球；母球落袋后虽规则提示自由球，实际无法通过球库补回。此前VM补球测试不能覆盖此页面拦截。
- 非每日清台的离场母球点击球库允许placeFromPalette；目标球继续只读。3D母球离场时底栏提示切回2D补回母球。无需新增玩法或恢复任意目标球摆放。
- DEBUG专用-v63.freePlayScratch仅准备已验证固定中袋球形和中八规则；真实UI点击击球/回放/模式切换/球库，落袋与结算仍由生产链路产生。不得把夹具启动作为正常入口验证。
- scratch-page-r1/session99832运行中。
- **已应用至**：.cursor/skills/swiftui-design-system/SKILL.md §DR-242；tasks/UI-IMPLEMENTATION-SPEC.md Changelog；tasks/FAILURE-LOG.md FL-067。

## DR-243 — 落袋提示复用瞄准信息位（2026-09-13，验收中）
- scratch-page标准/SE图显示四个并排胶囊导致自由按钮及母球进袋换行、比分省略。
- 普通自由击球cuePocketed提示显示时以scratchPill替代aimCapsule，而非增加第四胶囊；模式切换与落袋提示保持单行固有宽度，对局信息保留。预测已提示母球进袋时同样优先警告，消除同类拥挤。每日清台状态信息分支保留。
- scratch-header-se-r1/session33966实页验证中。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-243；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-243补充：r1玩家仍截断，r2省略重复轮到、保留完整无障碍标签后，SE实页31.055s通过且原图全部单行；标准最终及长比分待验。

## DR-248 — 试打页3D观看与控件（2026-09-13，验收中）
- r3只读卡修复：紧凑且只读时移除可编辑双列的固定宽度，按白盘/读数本征尺寸布局；新增实际卡片边界与继续按钮不重叠断言。r3/session16252实际48.224s、SE/session50073实际49.395s通过，两张暂停原图已核；gate/session9684通过。
- PositionPlayComposerView仅试打变体增加cameraToggle；独立自由走位入口尚未开放切换，W12仍待完成。复用ShotPlayCamera/ShotObservationMenu和ShotPerspectiveLayout，序列首入3D全桌观察，普通模式可回到瞄准。
- 3D解除台面瞄准拖动和拖球，保留明确目标球/袋选择；摆球返回2D。仪表、动作列、瞄准轮、重摆按钮按透视视口定位；底部改为观察/提示行，打点用已有紧凑布局并保留序列只读。
- 改前tryout-baseline-r1/session10518，原完整暂停/两杆/上一杆/播完复位UI230.515s通过，截图已保留。新testPerspectiveSequencePauseReplayAndModeRoundTrip在tryout-3d-r1/session96400实际42.488s通过；原图存在裁切/遮挡疑点，增加截图前过渡等待后r2/session62298实际48.130s通过，稳定原图确认读数完整，撤回读数缺失判断；全桌贴边/只读卡背景重叠仍待处理，生产布局尚未因此修改。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-248；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-247 — 动作详情观看模式（2026-09-13，验收中）
- DrillSceneController.cameraMode改为Published只读，setCameraMode只改观看；首次3D使用共享rig全桌取景，同杆往返复用scene观察缓存。全桌按钮不修改击球目标；stepLabel显示当前杆/总杆数。
- DrillSceneView增加44pt观看工具行；3D启用cameraControl，透明回放层停止命中，单击由场景回调唤出播放控件；2D保持原轻点唤出与杆末暂停规则。
- DrillStaticPreview.Options.adjustsTopDownCamera默认true，详情3D传false，防异步静帧把已选3D强切正交；缩略图等旧调用保持原契约。
- detail-3d-r1/session96139：控制器模式/投影/球位/播放状态单测0.515s通过，实页观察及原2D暂停回归执行中。
- r1最终1单测+2UI通过，但原图取景窄小，未通过视觉；r2改朝向仍被首次beginManualOrbit覆盖，1单测+1UI通过不代表取景修复。r3改observeWholeTable(yaw:nil)在接管后应用显式朝向，增加真实yaw断言；详情-π/2保持屏幕右+X，验证中。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-247；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-246 / FL-068 — 动作详情先摆球再解算（2026-09-13，验收中）
- 改前detail-baseline-r1实际暂停UI测试通过49.965s，但p1-playing-state原图台面无球；测试只验证控制状态/HUD，不能证明球形可见。
- 根因：setup在后台首杆解算返回后才applyPreviewFrame填homePositions；提前play时restoreHomePositions为空。switchFormation又通过applyPreviewFrame在后台派发前同步求解，违背其先摆球说明。
- preparePreviewBoard只从保存board摆球和建立homePositions，setup/switchFormation统一使用；预览解算返回只在idle时重绘，避免干扰已开始/暂停的演示。
- 新增主线程无挂起测试，setup返回及立即play后逐球验证visible/parent/opacity；实际暂停UI复验中。本次未增加3D控件；W10基线缺陷先修复。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-246/FL-068；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-245 — 视频杆末保留已播放结果（2026-09-13，验收中）
- 根因：renderFrames有完整预测时仍在杆末无条件placeBoard(step.after)，旧内容和新模型进袋结果不同会凭空移除未进球。
- 已播放运动的杆末改用该预测的pocketedBalls/finalPositions，匹配PositionPlayViewModel与DrillSceneController；不重置球体朝向。保存before/after及不可行分支未改变，多杆换杆兼容仍未完成。
- DEBUG settledFrameObserver只提供编码前可见球的boardKey/worldPosition值。新增c039前两杆真实编码测试逐个静帧比对独立预测；旧双角袋必须进球的失败测试保留。
- predicted-rest-r1/session19401终态0，实际2测0失败：c039两杆48静帧19.081s、原30/60fps及半速运动帧17.567s；末帧原图已查看。跨杆衔接未验完。
- **已应用至**：.cursor/skills/ios-architecture/SKILL.md §DR-245；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-244 — 实际导出节点状态观测（2026-09-13，验收中）
- SequenceVideoExporter.Options增加仅DEBUG的motionFrameObserver，编码前提供实际球节点worldPosition/opacity的值快照，按预测球名索引；不暴露节点或允许修改输出。
- 原30/60fps实片编码测试增加独立预测记录的逐帧捕获球世界坐标/透明度比较、完整淡出观测；不能用只比较时长代替导出消费正确性。
- export-states-r1/session55756正在执行。无发布构建API或正常导出行为变化。
- 已应用至：.cursor/skills/ios-architecture/SKILL.md §DR-244；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-249 — 全桌观察跟随真实视口尺寸（2026-09-13，验收中）
- 改前tryout-camera-diagnostic-r1/session87082实际UI52.764s通过，但DEBUG实页投影记录：viewport402×632，首次角点x413.86005超宽；再次全桌后x397.9658入框。根因是2D底栏94pt→3D底栏46pt，首次拟合发生于真实视口更新之前。
- CameraRig新增全桌拟合意图，observeWholeTable启用；viewport实际变化时重拟合，手动orbit/pinch/独立焦点及预设smoothToPose退出该意图；PerspectiveState保留意图，避免2D/3D往返丢失。没有增加任意缩放边距。
- 独立三视口八朝向投影测试加入旧尺寸→新尺寸，另验证手动旋转缩放及保存恢复后resize不抢回相机。tryout-camera-resize-r1/session55013执行中，尚未验收。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-249；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-249复验：合并r1为5单测通过/1UI TERM失败，原结果保留；独立ui-r2实际48.053s通过，首次角点397.8384进入402pt视口，改后原图已核。gate通过；跨尺寸与共享消费页回归待验。

## DR-250 — 3D序列参数移至顶部只读行（2026-09-13，验收中）
- 3D序列不需要可拖力度尺，但原只读长尺遮挡右侧袋口。Composer将本杆打点迷你图、力度名称与速度读数放在模式行右侧，暂停后仍能展开只读打点。2D序列及普通自由/进袋的编辑仪表保持原消费。
- 标准tryout-readout-r1/session72274执行中；新UI断言参数行在实际SCNView的FPS诊断标记上方，且3D序列无长仪表列，原暂停/重播/2D/3D及自由往返继续验证。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-250；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-250补充：标准readout-r1为测试器启动Busy失败；iPad模式往返49.079s通过且原图参数移顶、右袋清楚。新增逐杆测试误把末杆暂停当自动复位，源码确认应继续后复位，修正测试后eight-shots-ipad-r2/session12964复验中。生产播放逻辑未改。

DR-250验收补充：标准48.338s、SE47.506s、iPad49.079s同流程通过，三张序列原图均已查看，顶部参数完整、右袋无遮挡。iPad逐杆8杆98.707s通过，最终复位原图已核；原错误末杆测试失败保留。仅该参数行和指定流程接受，W10及全范围未完成。

## DR-251 — 非录制重打恢复击球前视角（2026-09-13，验收中）
- tryout-pocket-r1/session68146实际45.923s通过，但原图重打后母球离开画面：applyBoard恢复球形且作废视角缓存，镜头仍停在击球后的取景。
- lastPlaybackContext伴随本杆保存可用PerspectiveState，非录制replayCurrent恢复球形后恢复该视角；2D重打只保存到下一次3D切换，击球前无3D状态而当前在3D时用本杆记录aimDirection取景。播放/物理结果/参数保持原语义。录制多级撤回仍为原分支，未声称覆盖其历史视角。
- AngleTrainingScene新增capturePerspectiveView/restorePerspectiveView，供同一球形与观看状态一起恢复。tryout-pocket-undo-view-r2/session31104实页复验中。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-251；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-251验收补充：r2因回放上下文四字段传给三字段helper编译失败，已明确传入before/shot/prediction后修正；r3实页1项45.665s通过，击球前/重打后原图已直接比较，母球/球杆回到原取景。2D重打实际SCNView生命周期1项14.868s通过，保持正交且再次进入3D完整相机矩阵一致，规则只判定一次/补球正常。gate、diff-check及doc-size通过。接受标准机非录制重打范围，录制多步撤销/其他尺寸仍待验。

## DR-252 — 3D教学视频杆号与观察阶段（2026-09-13，验收中）
- Options新增showSequenceProgress，默认关闭，仅teachingVideo3D及继承的Hi开启。在台面之外、原参数条之上独立追加杆号行，观察球形时保留杆号并说明阶段，参数仍到亮方案时出现；不可行杆明确提示。
- 保留场景分辨率及参数条尺寸，手机档输出1080×2106；原2D/card/GIF预设不变。运动记录、球形和时长未修改。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-252；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。实际双杆编码复验中。

DR-252验收补充：实际双杆实时/导出31.981s通过；编码402×786、16.233333s，四阶段原图已直接查看，第一/第二杆正确、参数出现时机正常、台面无遮挡。gate通过。接受3D教学视频杆号行；完整多杆、不可行杆实际视频分支及高分档视觉仍待验。

## DR-253 / FL-069 — 软袋收集遗漏球体截面接触（2026-09-13，完整回归中）
- c039完整8杆第4杆失败：timeLimit15s，目标球自由下落至Y=-1033.2992m。收集平面Y0.715221m处，球心距袋截面8.312mm，半径28.575mm，球体已接触软袋但球心在轮廓外，旧containsProjection漏收。
- firstCandidate改用球体圆截面与袋多边形相交：内部点或线段最近距离≤真实R。角点用线段最短距离，避免矩形扩张误收。整球低于硬表面、向下穿越及活动球接触排除保留；未修改袋口/材料/上限。geometryVersion改soft-bag-v2。
- 3测通过：第4杆9.093s，穿越/外侧/圆角与活动球排除两测通过；完整8杆与六袋回归运行中。图sphere-collection-section.svg.png已查看，原失败完整保留。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md §FL-069；.kiro/steering/table-geometry.md §DR-253；UI-IMPLEMENTATION-SPEC Changelog。

DR-253/FL-069验收补充：完整8杆实际实时与导出113.321s通过，八杆共192停稳帧及观察帧对照通过，原第二杆返回而保存进球差异仍保留；六袋边界/正常入口2项通过。实际67.233333s视频及末杆原图已核，gate/diff-check/doc-size通过。局部修复接受，其他临界物理案例/跨设备完整验收不外推。

## DR-254 — 3D瞄准点提交按钮44pt（2026-09-13，验收中）
- 实际三次自动换题72.773s通过且三张next原图已核，母球/目标球均在取景内；旧按钮默认30pt高。3D浮动提交显式height44，保留56pt宽、位置、瞄准轮与评分/自动验证逻辑。
- 实页增加提交按钮宽高≥44断言，三轮复验中。
- 已应用至：swiftui-design-system SKILL §DR-254及UI-IMPLEMENTATION-SPEC Changelog。

DR-254验收补充：标准机实际三循环72.619s通过，提交宽高≥44；第三次换题原图已核，按钮与母球/目标球可见。gate通过；其他尺寸和W11完整范围未验收。

## DR-255 — 角度与瞄准点训练观察菜单（2026-09-13，验收中）
- 两页3D页内状态栏共享BTSceneObservationMenu(scene,targetNode,pocketIndex,identifierPrefix,onReturnToAim)。提供全桌、母球、目标球、目标袋、回到瞄准；固定题目不提供摆球/选袋编辑。
- 角度仅observing且有效题目启用，瞄准点仅aiming且未满额启用；回到瞄准调用原页相机入口，瞄准点保持用户方向。菜单只调用CameraRig，不改题目、答案、球位或评分。
- r1/r2实际两测均仅菜单36pt<44pt失败。外层frame/fixedSize无效已撤回，HStack自定义工具栏容器r3也失败；最终候选改放已有页内状态栏，r4验收中。新增下缘点击打开和键盘阶段禁用断言；不删除尺寸要求。
- 已应用至：`.cursor/skills/swiftui-design-system/SKILL.md` §DR-255组件API、`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。证据与未完成范围见`tasks/3d-v63/W11-working.md`。

DR-255标准机验收补充：r4/session58135终态0：瞄准点三循环103.444s、角度三题78.364s，两测0失败；菜单≥44pt、下缘点击打开、五项切换及角度键盘期禁用通过。12张菜单/观察原图已逐张查看：标题完整、全桌入框、焦点可见、返回原瞄准；页内状态栏不增加高度。final-gate/session34230终态0。SE/iPad、评分回归及节点/投影不变量仍待验，W11保持进行中。

## DR-257 — 球库放下按手指终点判定（2026-09-13，验收中）

- 问题：W12 iPad摆球→3D→2D后拖回球库，r2/r3原图显示9号仍停在下库边；旧UI只验导航，未证明移除。
- 证据：`output/3d-v63/W12/ipad-drop-diagnostic-r2-coordinates.log`，手指scene-local y=951，指球锁定偏移-53.5、抓取偏移-12，旧sample y=885.5；scene原点y=46、palette起点y=928，实际接收余量仅3.5pt。该轮36.758s通过，证明是边界敏感，不能声称恒定失败。
- 调整：AngleSceneView.onDragEndedAt传递SCNView本地手指终点，台面onDragMoved的指球偏移不变。全部既有消费者均用于球库hitPalette，统一消除偏移侵蚀接收区域；不扩大球库、不改球位/物理。
- 验证：新UI明确断言移除反馈，并逐图检查9号移除和1号保留；iPad/紧凑复验待完成。临时日志已移除；首次诊断构建因旧UIKit字符串函数失败已修正，原失败日志保留。
- 已应用至：`.cursor/skills/swiftui-design-system/SKILL.md` §DR-257及`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## DR-256 — 自由走位开放已有3D观看（2026-09-13，分阶段验收）
- PositionPlayComposerView不再仅为试打显示cameraToggle；按sourceDrill区分tryout/composer标识，观察菜单与返回瞄准同样分域。复用现有3D布局、相机手势、底部观察栏及2D摆球路径，不复制盘面或序列。
- 实际页目前未暴露录制/目标区编辑，虽然ViewModel保留录制能力；按当前已有能力验收，不据过时注释新增功能。重命名保存仍修改当前内存序列名，未扩大为持久化草稿。
- baseline-r1实页与原图已核；roundtrip-compact-r1实页44.755s通过，改名→自由→3D拖动观察→2D→改名框回读一致，4张原图已核。原相机不改球位/参数预测单测3.936s通过。
- 新录制草稿测试首轮缺运行SCNView和视口，动作不推进导致失败；保留日志，补真实window/SCNView后recorded-draft-r2 14.775s通过：一杆录制后3次切换，完整序列JSON/球位/选球选袋不变，stop返回同序列。未写内容JSON。
- 已应用至：swiftui-design-system SKILL §DR-256与UI-IMPLEMENTATION-SPEC Changelog；其余编辑动作、标准/iPad与完整W12待验。

DR-257验证补充：iPad-drop-fix-r1/session20308终态0，35.252s；compact-drop-fix-r1/session78381终态0，34.395s。两设备返回/移除原图各两张已直接查看，均9号离桌、球库9号亮态、1/2/母球保留。drop-fix-gate/session10282终态0，diff/doc-size通过；本地修复通过，其他共享消费页随对应批次回归，完整W12未完成。

## DR-258 — 清空桌面同步清除角度结果（2026-09-13，验收中）
- W12 iPad与紧凑生命周期原图确认：所有球清空后仍显示上一杆11°。clearTable仅清除solvedShot/轨迹，未清空cutAngleDeg。
- 最小修复：clearTable同步将cutAngleDeg置nil，现有胶囊自然显示—°；参数、球形默认值和求解逻辑不变。
- 实页测试新增空桌不显示旧角度断言；compact-edit-lifecycle-r2运行中。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-258；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-258复验：compact-edit-lifecycle-r2/session71463终态0，52.481s，空桌—°断言及3D/2D/默认恢复三张原图通过。edit-lifecycle-gate/session4966终态0；本地修复通过。

## DR-259 — 思路训练3D编辑/观察分离（2026-09-13，首页面验收中）
- W13三页SE基线通过并直接审图。先接SiluTrainerView：2D/3D入口、首次全桌、透视侧栏布局；3D关闭约束绘制overlay及球体拖动，保留activeTool与约束数据。
- 3D底栏使用查看全桌与编辑返回提示，2D保留球库；未修改求解/规划规则，未宣称完整W13完成。
- silu-roundtrip-r1运行中，真实求解/击球及其余两页待验。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-259；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-259首轮补充：silu-roundtrip-r1/session87635终态0，28.120s；四张落区/3D/旋转/返回原图均已查看，区域和球形保持，求解仍可用。完整解算/击球、观察菜单、其他两页未验，W13继续。

## DR-260 — 思路训练上一杆恢复观察视角（2026-09-13）
- UndoContext新增可选perspectiveView；makeUndoContext取实际相机快照，restore在球形/解恢复后应用。2D恢复时暂存至下一次3D，沿用DR-251接口。
- silu-undo-camera-r2：5项0失败8.469s；含相机两模式恢复、三页完整字段、不完整预测拒绝。r1旧夹具遗漏termination失败保留，修正夹具前提且原断言全部保留，见W13-working；不冒充物理验证。
- silu-shot-r1实际完整UI98.125s通过发生在该相机修改前；不能证明修改后的整页相机体验。求解约60秒仍待性能处理。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-260组件行为与Changelog。

## DR-261 — 思路训练当前解观察入口（2026-09-13，验收中）
- 底栏替换单一全桌按钮为共享观察菜单，播放期间禁用；canReturnToAim默认true保证既有调用兼容，思路按完整可击球解和实际杆向开放。
- 无解不推测沿杆方向，返回瞄准仅使用lastAimDirection调用CameraRig.enterAiming。
- silu-observation-r1真实UI运行中；未宣称全W13完成。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-261；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-261复验补充：silu-observation-r1实际UI1项108.730s通过；沿杆/上一杆恢复/2D返回三张原图已审，无解禁用/有解启用通过。gate/doc-size/diff通过；完整W13与其余观察项仍待验，求解64.4s未达标。

## DR-262 — 打一走二想三保留规划角色的3D观察（2026-09-13，验收中）
- 3D角色行可见且禁用编辑，绘图/拖球/点按改派挂起；底部观察菜单取①球/袋，当前解杆向用于回瞄准。现有击球推进逻辑保留。
- UndoContext追加可选perspectiveView，沿用DR-260恢复时序；完整角色快照及UI往返复验中。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-262组件行为与Changelog。

DR-262复验补充：r1两项角色/相机单测通过，UI因深链夹具误走主Tab导航失败；RootView事实核验后r2页面身份/观察往返30.005s通过，三图已核。gate/doc-size/diff通过。全流程/3D底栏空白与前袋侧栏遮挡仍待验，不作W13完成声明。

## DR-263 — 中八防守3D观察与无目标袋契约（2026-09-13，验收中）
- SnookerTacticsView新增2D/3D与共享透视控件；3D暂停编辑，恢复视角不改目标球/安全球规则。
- BTSceneObservationMenu.pocketIndex改为Int?，nil不显示目标袋；既有Int调用保持原行为。UndoContext保存可选PerspectiveState并沿用DR-260恢复顺序。
- 实际默认入口与快照测试snooker-shot-r1运行中。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md §DR-263；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-263首轮补充：两个快照测试通过；防守真实默认求解超90秒，UI未通过，随后主动中断无意义后续操作。采样/原图/日志保留于W13；测试改为前置失败即停，未删或放宽断言。优先W07求解性能，整页保持未验收。

### DR-264 — 规划页取消开球保留草稿（2026-09-13）
- 原因：开球入口提前销毁规划，取消仅载入球位，导致已有目标/角色/约束/解丢失。
- 调整：Silu/PlanThree在开球期间保留原VM规划，仅清可视化；取消恢复原球位和相机并重画当前解，完成才载入新球形。计算中禁止进入；开球期间停用绘制覆盖层但保留工具选择。
- 验证：两页全字段状态2测通过1.344s；实页复验见W13-working。
- 回写目标：swiftui-design-system技能与UI实施规范。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-264；tasks/UI-IMPLEMENTATION-SPEC.md Changelog（2026-09-13）。

## DR-265 — 3D线条文字面向观察者（2026-09-13）

- 来源：v63 W14角度与瞄准实页07D59C3E，固定俯视朝向使3D瞄准线文字倒置。
- 调整：沿线锚点不变；显示的线条标签复用角度数字的SCNBillboardConstraint，3D面向相机，2D恢复创建时flatYaw和文字平放旋转。重建角度弧时清除旧标签引用。
- 验证：labels-r1四方位渲染不变量与SE实页进行中，未验收。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-265；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

- DR-265验证补充：SE实页labels-r1/33.241s及两张原图通过；该run单测0项不计通过，纠正类名后的labels-unit-r2实际1项/1.182s通过四方位朝向、锚点及2D恢复。

## DR-266 — 每日清台终态停止击球（2026-09-13）
- 来源：W15 results-r1完成页CE628850显示示例球形且击球可用；控制器虽拒绝终态回调，页面仍可继续模拟。
- 修复：FreePlayView.isDailyResult统一约束击球工具、台面编辑与瞄准模式；完成记录重新进入不展示初始化示例球形（记录只含汇总）。保留完成/失败底栏与相机切换，不修改计分与记录。
- 验证：重复终局/恢复落库1项0.018s通过；终态实页复验results-r2进行中。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-266；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

- DR-266验证补充：results-r2实际UI1项25.933s通过，完成/失败两原图已核；结果入口可点、2D/3D无击球工具；门禁通过。真实终局及再开局仍归W15。

## DR-267 — 自动开球交付不重夺镜头（2026-09-13）
- 来源：W15 final-ball-r1新局沿用近袋视角，部分球出屏。FreePlayView监听breakRunner.seed时对nil交付也focus。
- 修复：仅非nil种子响应；每日自动开球建立/更新球架使用全桌，手动开球保留瞄准构图；交付时不focus。
- 验证：final-ball-r2真实末球→完成→真实再开球1项34.632s通过；6A4BF33B原图全部球在全桌构图内。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-267；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

## DR-268 — 每日清台自由球补回与草稿一致（2026-09-13）
- 根因：普通母球进袋后VM隐藏母球，daily规则仅提示自由球；daily球库禁止手动补球，无法继续。
- 修复：DailyClearancePlayingHost.restoreDailyClearanceCueBall调用现有安全空位补球；controller仅在真实cuePocketed且ballInHand且非终态时执行，之后再保存board。
- 验证：scratch-controller-r1实际14项0.062s通过，新增继续犯规补回/终局犯规不补回及保存内容断言；物理入袋实页未验。
- 已应用至：.cursor/skills/ios-architecture/SKILL.md § DR-268；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

- DR-268实页补充：scratch-ui-r1真实入袋/补回/第二杆/重启1项33.249s通过，三原图已核；计时保存点差异另归W15。

## DR-269 — 每日清台已放弃旧局后不提供开球取消（2026-09-13）
- 根因：v52规定确认重开即清空旧草稿，FreePlayView却复用cancelBreakFlow恢复旧桌面；控制器仍manualRacked并拒绝杆末计分。
- 修复：BreakControlBar新增showsCancel（默认true），每日清台传false；普通自由击球及规划页保持原取消行为。每日清台保留顶部返回和待开球草稿恢复。
- 验证：manual-r2正在验证待开球退出恢复、真实手动开球交付及交付后恢复。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-269；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

- DR-269补充：开球栏重开原先只改runner.seed，DailyClearanceController.handleBreakOutcome要求草稿seed相等，会拒绝交付。BreakControlBar新增可选onRerack，每日清台复用confirmRerack同时创建并保存新草稿/球架；其他宿主默认runner.reRack。manual-r2取消隐藏/待开球恢复实测通过，r3验证重开后恢复与真实交付。

DR-269复验纠正：manual-r4/session79206终态65；普通自由击球105.177s通过，每日清台51.193s失败于最终重启后HUD不存在。交付图A2C8A401显示余0/旧待开球文案，不能接受。根因进一步定位：startBreakFlow守卫breakRunner==nil，controller重开保存新seed但host未拆旧runner，启动被拒。每日host现在在替换前cancelBreakFlow，再startBreakFlow；仅每日路径变动。manual-r5/session17950验证失败原路径及控制器/规则/存储。

- DR-269最终复验：manual-r5控制器/规则/存储31项及实际直接重开/交付/重启38.303s通过；BCAB2FEC原图已核，direct-gate-r1通过。普通自由击球取消等105.177s通过。W15本地验收见tasks/3d-v63/W15-acceptance.md，完整平台仍W16。

## DR-270 — 销毁SceneKit视图时解除场景引用（2026-09-13）
- 根因：详情controller/coordinator已释放，SCNView仍保留渲染场景关联；三轮各等待1秒均未释放scene。
- 修复：AngleSceneView.dismantleUIView在停止displayLink/isPlaying后，将pointOfView和scene置nil。
- 验证：lifetime-r3三轮失败，r4同一三轮weak释放断言通过；真实导航重入与真机内存仍待验。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-270；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

- DR-270实页补充：reentry-r1三轮详情3D播放中退出/重新进入36.188s通过，首末原图已核，无黑屏或球形丢失。真机内存不外推。

## DR-271 — 大字号每日清台结算栏（2026-09-13）
- 根因：默认动态字体按钮与固定94pt横排结果栏不匹配，AX5文字被省略。
- 修复：辅助功能字号使用纵排，结果栏高度随ScaledMetric增加，保留按钮动态字号；普通字号保留横排。
- 验证：ax5-r2功能绿但图审失败；ax5-r3视觉复验进行中。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-271；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

- DR-271复验：ax5-r3两结果21.012s通过，C2A3A713/9E9BC962原图按钮四字完整；门禁通过。普通字号最终回归仍待。

## DR-272 — 瞄准轮无障碍增减（2026-09-13）
- 原因：BTAimWheel只有朗读标签，VoiceOver无法调整；allowsHitTesting不能替代AX禁用状态。
- 实现：adjustableAction按页面degreesPerPoint增减、成对触发拖动生命周期；六个调用点同步原播放/摆架可编辑条件为disabled，瞄准训练继续按作答阶段显示。
- 验证：Debug构建通过，实际SwiftUI AX元素调用验证中；真机VoiceOver朗读未验。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-272；tasks/UI-IMPLEMENTATION-SPEC.md增量条目。

- DR-271普通字号复验：iPad large/light结果26.122s及两原图通过，保持横排完整文案；同轮实际开球/交付/恢复42.917s通过。

## DR-273 — 自由击球比分按宽度折行（2026-09-13）
- 根因：SE进袋模式下，瞄准胶囊与单行比分/当前玩家同时争用顶栏宽度，9球玩家得分尾部被省略；改前实图2DE01428确认。
- 候选：gamePill使用ViewThatFits，宽时横排，窄时比分和当前玩家分两行；保留文字、12pt字号及46pt顶栏，组合无障碍标签。无规则/评分变化。
- 验证：score-layout-r1实际15/9球完整开球与继续流程运行中，未验收。
- 已应用至：.cursor/skills/swiftui-design-system/SKILL.md § DR-273；tasks/UI-IMPLEMENTATION-SPEC.md增量记录。

DR-273复验：score-layout-r1/session71745终态0，SE实际15/9球开球、模式往返、交付、继续击球、重打与取消1项102.817s通过，无确认超时。CAC5CA18九球/D7465C22中八原图已直接查看，比分和当前玩家完整两行，原46pt顶栏内无越界。gate/session94944终态0。仅接受SE普通字号这两类状态，宽屏横排/更长比分仍待验证。

DR-273 iPad复验：score-layout-ipad-r1/session92487终态0，实际1项127.817s通过，15/9球开球、交付、续打/重打/取消及2D/3D往返。simctl读回large/light；F564ED35九球与010755C7中八原图已查看，两状态比分/玩家完整横排，位置正常。附件output/3d-v63/W09/score-layout-ipad-r1-images。与SE两行证据共同覆盖宽窄布局，未证明所有长比分或最大字号。

## DR-274 — 单局部球避免嵌套误差检查（2026-09-13）
- 根因实证：求解中段栈与源码确认advanceTogether的whole/half/tail各自调用run，而run内部已有同类自适应检查；单球无球间耦合时重复执行。
- 候选：states.count==1使用已有advanceCoupledTrial，保留run误差标准、接触投影、外层穿透重试和时钟检查；多球不变。useSingleBodyShortcut=false保留旧路径作独立对照，生产默认true。
- 证据：改前六袋30状态两路径对照2.247s通过；改后六袋对照0.125s/双球2.089s通过，默认标准防守内部19.192s，相比同轮基线37.186s约降48%，五组完整杆法参数逐字一致且硬约束通过。原部分候选穿透失败仍存在，不宣称物理缺口关闭。完整序列/续算/连续进袋回归进行中。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md § DR-274；tasks/UI-IMPLEMENTATION-SPEC.md增量记录。

DR-274回归：single-control-regression-r1/session68645终态0，实际3项57.540s通过：完整8杆实时/导出事件与首尾球位57.403s、连续入袋0.133s、任意分段续算0.004s。未移除既有断言。候选保留为本地性能改进；五组输出参数一致，完整W07临界物理、实际页面与真机性能仍未完成。

defense-device-r1/session44078终态0：锁屏等待后同一进程自行恢复，实际iPhone16Pro/iOS26.6.2运行1项70.448s通过，内部systemUptime求解68.763s，5组PlannedShot与模拟器逐条相同，首触/母球不进袋/完整停稳断言通过。成功包含设备构建、测试宿主安装和真实执行；不是触控/帧率/温度验收。配置Debug -O、无代码覆盖率，仍含DEBUG诊断；未取得本机优化前基线，不能把模拟器48%套用至手机。68.76秒不可作为手机性能达标，W07/W16保持未完成。

## DR-275 — 同刻最后提交帧作为预测终态（2026-09-13）
- compatibility-r1四项中搜索比较失败2断言：两组±0.3塞/2.7m/s的cueFinalSpeed为0与约5.2e-5m/s，原1e-5容差未改。默认六袋沿/旧平面孔圈/自由早停比较通过。
- scoring-residual-r1诊断证实：同一时刻先记录rolling非零末速，再提交spinning零平移帧；frames.max(time)取到了前者。引擎已正确停止，非物理误差或提前停止错误。
- 修复：ShotPredictor两个终态聚合入口选择最大时间戳且同刻最后写入的BallFrame；保留输入顺序，兼容非排序数组，不改变物理或早停条件。原断言及诊断保留；测试日志改为中性已比较数量，不在断言失败后打印全部一致。
- r2编译/门禁通过但模拟器Busy预检拒绝，0项执行；同产物iPad r3复验中。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md § DR-275；tasks/UI-IMPLEMENTATION-SPEC.md增量记录。

DR-275同产物iPad r3/session28553终态0，默认六袋沿4.257s、搜索54输入5.413s、自由提前停止20输入1.530s三项通过，原末速容差未变。随后scoring-completion-r1/session72414新增有效终态断言：实际2项/2失败，54组中的±0.3侧塞、spinY0、5.4m/s完整预测timeLimit，其余字段比较及20组自由早停通过。新断言保留；它揭示现有15s上限下两组完整模拟未结束，不是DR-275末帧读取仍失败。下一步记录这两组15s末状态，判明平移/自旋/局部所有权，不能直接调大上限求绿。


## DR-276 — 完整呈现承接台面原地自旋尾段（2026-09-13）
- 原因：scoring-time-limit-r1两组15s末态只有母球绕Y轴自旋，平移均为零；完整预测只认settled使播放/导出拒绝。
- 新增EventDrivenEngine.completePlanarSpinTail：只接timeLimit，要求无局部所有权/待提交步、所有活动球stationary或spinning、零平移/水平角速度、台面球心高度且不处于袋口区域；按既有spinToStationaryTime和evolvePlanarBall逐个记录自旋结束事件。运动碰撞模拟预算不延长，其他终止原因不放行。ShotPredictor完整呈现两入口调用，搜索提前停止路径不调用。
- 验证：新增双球反向自旋与原长时间平面引擎逐时刻对照，以及平移未完/eventLimit拒绝检查；保留原54/20组断言。spin-tail-r1编译失败：插入点误落另一postStart，未执行测试；已定位修正，r2验证中。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md § DR-276；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-276验证收尾：r2编译器无法及时推断tuple map/sort，改显式类型循环；r3实际4项/2失败（8.902s），纯平面对照/未完运动保护通过，但默认混合路径在预算末端保留纯自旋待提交步，原54组仍失败。r4允许且仅允许无局部预测/接触/晋升/入袋/球球事件、事件为空或spinning→stationary的待提交步，经活动球检查后以已提交状态重建解析尾段。新增对照改走appDefault预算截断，原54/20组断言未弱化。r4/session3847终态0：实际4项0失败/8.062s，54组6.525s、默认混合自旋对拍.001s、未完运动/eventLimit保护.000s、20组自由对拍1.535s。gate-r2/session69533终态0；真实页面/导出操作及真机性能仍待验。


## DR-277 — 已有有效直击解后的候选下界淘汰（2026-09-13）
- 根因：独立常规进袋报告中未命中候选继续碰库/局部模拟占70.8%/78.0%的总耗时。原评分无目标接触时保留100+距离梯度，因此不能一律碰库早停。
- 改动：仅solveAimOffset各层bestOf当前bs<invalidCandidate时，允许引擎在母球先于任何球球碰撞吃库后返回candidateRejected。这种候选的旧完整评分只能是100或100+非负距离，严格不可能改善已有有效解；尚无有效解时仍完整计算。候选顺序、网格、同分选择、最终完整仿真均不改。其他搜索/反射/开球默认不开此项。predict的useAimCandidatePruning=false保留旧搜索用于对照。
- 第一轮：aim-pruning-r1/session51338终态0，实际1项12.159s/0失败；中袋/角袋/弱杆/障碍球各三档塞共12组，选中方向、完整帧、事件、进袋/末速/时长一致。预热后累计baseline5.9165s/pruned5.0472s，首轮约14.7%改善，仅模拟器量级，不作为真机达标。
- 补验：新增先碰库拒绝/先球球接触保持旧评分边界，平面参考和appDefault均覆盖；aim-pruning-r2正在执行完整ScoringOnlyConsistencyTests。gate-r1/session34709终态0。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md § DR-277；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-277扩展回归：aim-pruning-r2/session12866终态0，完整ScoringOnlyConsistencyTests实际6项19.586s/0失败。12组优化开关对拍12.408s、两模型先碰库/先球球边界.004s、54组5.629s、自旋长时对拍.001s、未完运动保护.000s、20组自由早停1.544s。第二轮累计baseline5.9879s/pruned5.1113s，约14.6%减少，与首轮方向一致。未降低预测精度/缩网格/改评分；新候选淘汰仍不是斯诺克防守68.763s问题的完整解决，真机和实际页面交互性能待验。diff-check/doc-size通过。


## DR-278 — 接触力矩使用可观测运动误差界（2026-09-13）
- sliding-control-r1/session87399终态65：真实滑动初态角袋两路径均推进0.1s，中袋单体快捷关闭/开启都报完全相同surface-moment残差9.04971189702637e-09，排除DR-274单体快捷造成此失败。r2/session17945诊断仍2失败，原断言未改；dt=.0024724411846112726，内部roundoff阈值2.4393437553329006e-12，运动误差界7.760759339543737e-11m，对照现有tolerance=1e-6m。
- 原因：内部力矩分配要求接近机器精度，强于实际积分运动精度；接触分配可以慢收敛而整体角加速度已准确。
- 修改：保留4096轮严格收敛优先；剩余时计算凸目标F=|omega/dt+free+Σm|²/2在每个接触滚阻圆盘×自旋区间上的Frank-Wolfe gap。可行力矩下g≥F-F*，且F-F*≥|Σm-Σm*|²/2，因此角加速度误差≤sqrt(2g)。只有R*dt²*sqrt(2g)≤原tolerance、有限值且gap负值不超舍入余量时接受。每轮力矩投影/凸组合保持容量约束；不调整材料、空间容差、预算和捕获断言。
- moment-bound-r1/session58696终态65：4项中默认捕获1.803s、自由局部捕获.047s、两路径滑动对照.118s通过；指定模型近袋仍convergence residual2.9487523534044158e-12失败（3派生断言），来自CollisionResolver，不能报告全部修复。
- moment-bound-r2验证坡面、滚阻能量、六默认袋沿及已修入口；单测之外完整实时/导出及真机另验。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md § DR-278；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-278扩展验证：moment-bound-r2/session94468终态0，实际8项/0失败，总4.339s。默认六袋沿4.118s、默认捕获.028s、自由近袋捕获.044s、滑动态新旧单体对拍.118s；坡面静止/超临界加速、滚阻不反转、不增自旋能四项共.031s。gate-r1/session9023终态0。原指定模型近袋的CollisionResolver convergence失败仍未解决，不得以此8项绿覆盖。


## DR-279 — 双球支撑误差尺度包含有限步滑移率（2026-09-13）
- 原失败定位为SpatialBallContact.resolveSupport（force阶段），不是瞬时冲量：residual2.9487523534044158e-12，duration=.0025000000000000022。force-scale-r1/session98805终态65，1项3失败；诊断外加速度scale9.8100004，实际切向算式中的slip/dt量级591.3211758。旧64*ULP*scale遗漏有限步除法与抵消涉及的输入量级，要求了计算中已丢失的精度。
- 修复：scale取外加速度与有限步slipRateScale的最大值；保留原64*ULP倍数，duration=nil时原尺度不变。未调整碰撞恢复、摩擦、空间积分容差或捕获判据。失败日志保留两种尺度便于复核。
- force-scale-r2/session1884终态0，实际5项1.087s/0失败：默认捕获.955s、未完预测拒绝.026s、原指定模型近袋.101s、双球滑移停点不反转.005s、两物体交换舍入边界.000s。原断言全部保留。gate-r1/session67360终态0。
- 实时/导出整段复验contact-regression-r1/session42730已启动，完成前不宣称完整W08通过。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md § DR-279；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

DR-279完成本轮入口修复：force-scale-r2/session1884实际5项/0失败1.087s，原指定模型近袋.101s通过，双球滑移/顺序交换与未完预测拒绝保留。contact-regression-r1/session42730终态0，真实c039完整8杆实时/导出事件、起止球形与192静止帧对比1项57.338s通过；旧保存第二杆离场与当前返回台面差异断言仍通过。未新审MP4视觉，不据此宣称全部W08/W16完成。


## DR-280 — 独立空间击杆初始冲量接口（2026-09-13）
- H01预检查后对照pooltool当前instantaneous_point源码：vB保留-v*sin(theta)，由台面响应产生跳起，不直接造正vy。加入executeSpatialStrike输入验证及独立入口；executeStrike仍固定旧平面分量，新接口未接页面/模拟调度。0仰角沿旧表达式保持signed zero。坐标SceneKit XZ水平/Y上、rad、m/s。
- strike-r1/session20787终态65：PhysicsEngineTests实际36项，26通过/10失败，19断言失败，总10.239s。新增3项全部通过：27组零抬杆逐位兼容、21组向下冲量/能量边界及中心45度样例、非法输入拒绝。不能称整个类通过；常规默认/角袋等10项失败详FL-070。gate-r1/session76927终态0。
- 只验点冲量，不代表台呢压缩/杆头驻留/抬杆起跳高度已校准。H01整体未完成，W07重新复核期间不接正式页面。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md § DR-280；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## FL-070 — 选择性兼容测试不足以关闭W07
- final-compatibility-r1的24项和入口/八杆对照真实通过，但遗漏PhysicsEngineTests常规进袋基准；随后strike-r1实跑36项，10项19断言失败。此前W07完整本地验收结论覆盖过宽，现撤回并标返工。
- 新失败包含默认球形、近直/中切角袋、多力度、中袋高力度、边路障碍/侧塞及显示轨迹端点。先区分合理新模型结果、消费假设与实际物理回归，不改弱原断言，不直接归因新空间接口（现有executeStrike仍走旧平面路径）。
- 改进：模型兼容验收必须以生产预测调用反查全部既有基准类，逐类记录执行/未执行/失败归因；新命名的v63测试与若干页面绿不能替代旧常规输入矩阵。
- 已应用至：.cursor/rules/55-test-engineer.mdc § FL-070；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-281 — 收集平面求根禁止台面误捕获（2026-09-13）
- 真实反例：中袋3.3m/s在t=.152577、Y=.828575仍为台面球心高度时被捕获，收尾将XZ推进至z=1.364903，导致原显示路径偏离袋心.688938m。path-endpoint-red-r1/session7373 exit65，1项失败。不是单纯预测线采样越过隐藏终态，不采用裁线掩盖。
- 根因：PocketCaptureBoundary.firstCandidate复用全局二次求根的绝对判别式阈值1e-12，微小支撑残差下a=-2e-12、b=0、c=.1被误作重根t=0；缺少捕获高度复核。capture-root-red-r1/session86066 exit65，1项失败，球高于平面10cm仍被捕获。
- 修复：仅收集边界用单位区间时间/归一化系数、稳定q形式求根，精确零判退化，不改全局解析引擎。候选复核Y不高于收集平面（仅64ULP坐标舍入界）。几何、收集深度、材料与固定尾段不改。
- 验证：capture-root-green-r1/session1111 exit65，完整PhysicsEngineTests 40项/10项失败、22断言失败15.178s。新增反例与12组线性/加速跨平面尺度样例通过；原10项常规失败保留，中袋3.3/4.4过去的误捕获不再计进。不能称整类通过。
- capture-root-regression-r1/session90103 exit0，实际4项1.114s通过：反例/12尺度、默认近袋捕获、真实吐袋不捕获、分段续播。另一个筛选项类名误写Injection，未执行；使用源码真实PocketGeometryV63Tests补跑boundary-r2。gate/session36098 exit0。
- 回写：geometry-spatial-reasoning技能DR-281、UI-IMPLEMENTATION-SPEC Changelog。W07仍FL-070返工；不能用旧误捕获支持已完成声称，之前受该路径影响的兼容/回放证据需重验。

DR-281补验：capture-root-boundary-r2/session97595 exit0，实际2项0.004s通过：正常向下穿越/外侧拒绝及有在场邻球接触时延后捕获。联合前轮实际4项为6项定向验证。完整40项仍10失败；新求根下marker两档仍进（但吃袋角），并未因此采纳视觉点为物理真源。所有句柄终态；gate/doc-size/diff通过。

## DR-281 后完整八杆实时/导出复验（2026-09-13）
- capture-root-sequence-r1/session60463 exit0，实际1项56.298s。使用当前已构建DR-281产物；真实c039八杆逐杆实时播放/暂停/换杆与导出同事件种类/对象/顺序/时间、同起始球形、同杆末XYZ和可见球集合。八杆各24个杆末帧，共192帧。旧保存第二杆进袋与当前返回的差异断言仍通过。
- 实际输出predicted-rest-856E57EF-6C59-41B6-993F-0C56FA0ECAB4.mp4，ffprobe确认402×786、30fps、67.233333s；输入options.size402×716为表区，最终含底栏，勿将视频高度误报716。
- 已直接查看capture-root-sequence-r1-contact-sheet.png（0.5/5/15/25s）及late-frames.png（40/55/67s），覆盖杆1/2/3/5/7/8。桌体与球、杆序/打点/力度可见；第7杆辅助线与球杆可见，第8杆末帧完整。仅离散抽帧，未声明连续近袋视觉、低机位遮挡或真机帧率/热量验收。
- 本次复验不关闭W07普通物理10项失败，也不以数据/抽帧通过代替W08/W10/W16所有要求。

## DR-282 — 轨迹按钮点击区域与放置带一致（2026-09-13）
- 根因：SE/iOS17/AX5实页点2D/3D的(337,87)点，实际轨迹档位全→双，模式未切换；轨迹按钮点击区域进入上一行。原失败保留shot-se-ax5-r1.xcresult，实际1项失败。
- 修复：BTTrajectoryDetailChip标签显式minHeight 44/contentShape；btChipBandPlacement高度至少44点，容纳点击区域。外观胶囊仍使用原尺寸，无相机/物理修改。
- 复验：shot-se-ax5-r2实际1项74.802s、0失败，包含切换、观察/旋转/缩放、后台恢复、瞄准/击点、击球/回放/重置。70D2/9433/C25E三原图已查看：模式、底部操作与击点面板在屏幕内。仅此设备/流程，不外推所有共享消费者或真机VoiceOver/FPS。
- 门禁：chip-hit-gate-r1日志全部通过；共享消费者普通字号复验待补。W16仍未完成。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-282组件契约与Changelog。

DR-282普通字号补验：chip-ipad-r1/session35955 exit0，实际自由走位入口19.743s、分离角完整3D流程91.619s，共2项111.362s、0失败。iPad字号实读large；C4E78253/3A755280/5280897F原图已查看，轨迹按钮与模式行分开、击点操作与底栏文字可见。自由走位只覆盖入口布局，不能称其完整交互回归。小屏after-replay原图6F6521CD也已查看。所有本轮测试终态；其余共享消费者/真机/VoiceOver及W07失败仍待验。

## DR-283 — 有限三角面距离保守筛选（2026-09-13）
- 根因：包围盒重叠仍包含本步不可能接触的斜面边角，继续进行面/边/顶点求根。有限三角面距离满足1-Lipschitz；若初始距离>半径+|v|h+0.5|a|h²+原64ulp尺度余量，可拒绝整面求根。含加速/反向，不缩时间窗、不改接触容差。坐标为SceneKit世界XYZ、Y-up、米。
- 变更：PocketContactTriangle.firstContact默认启用距离筛选；useDistanceBound=false供同函数原求根路径对照。坐标尺度只算一次，复用于边/顶点原有保守界。无捕获规则、袋底/堆球或参数标定变更。
- triangle-distance-r1/session56284 exit0，实际3项18.251s：5400组对照（128命中/5272未命中）时刻/接触点/法线完全一致；旧反向/端点测试通过；实际标准防守内部16.583s、5解。五组shot描述与上一轮恢复版完全一致；单次时差不构成稳定百分比收益或真机达标。
- triangle-distance-r2/session64451 exit0实际仅1项2.045s：任意边界暂停续算通过。其他选择器误指类；不计为额外测试，正常进袋另补。
- triangle-distance-regression-r1/session82747 exit65：实际42项，PhysicsEngineTests41项中仍原10个失败方法/22断言失败（与capture-root-green-r1失败方法集合严格相同，无新增/消失）；正常进袋收集边界1项0.019s通过。保留全部原失败，W07仍FL-070返工。
- triangle-distance-gate-r1/session97251 exit0；doc-size/diff另核。所有测试句柄终态。下一步仍为手机等待时间和剩余正式页面/高度范围，不因此关闭W07/W16。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-283；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-284 / FL-071 — 3D开球失败提示被普通说明覆盖（2026-09-13）
- current-se-ax5-r1/session69731 exit65：SE/iOS17/AX5两条实页流程，开球流程128.875s失败、母球落袋/补回26.914s通过。15球已完成散局交付，9球默认8.0求解失败后无法确认；失败截图CC4206FD及AX树6A51AF0A显示普通操作提示，错误未显示。不是等待时间不足。
- 系统日志current-se-ax5-r1-break-system.log给出9球seed=17829163102452725902、cue=(.635,.828575,0)、aim=(-1,0,3.304183e-05)、spin=0；终态failed(penetration(0.0011684512086055138))，模拟时刻0.34930834。15球seed=4712397786635757473正常settled，未把同一流程的9球失败抹掉。
- 反馈根因：statusText(isPerspective:)只看racked便返回普通文案，acceptCompletedSimulation失败也回racked。修正为仅simulationFailure==nil时替换；保留原错误和未完成禁止交付。
- failure-feedback-r1/session9303 exit65，实际2项3.200s：未完成开球保持球架/禁止确认/2D与3D均保留失败提示测试2.404s通过；新增真实种子测试0.796s失败，精确复现上述穿透值/时刻。原断言与失败证据保留；没有降力度、换种子或扩大容差。
- 状态：反馈映射修复已构建及状态验证，修后真实失败页截图待补；物理穿透未修，W09不能接受当前完整开球范围。W07既有10失败之外增加独立9球实页回归，不能称全部基准只有10个问题。所有句柄终态。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md §DR-284组件契约/Changelog。下一步定位固定种子穿透涉及的球与接触阶段；不返回袋底堆积研究。

## DR-285 / FL-071 — 球体触及袋口窗口时接管（2026-09-13）
- 固定9球失败源定位：nine-ball-contact-source-r1/r2实际各1项失败。交接初态t=.34930834149434303、p=(-1.2414212226867676,.8285750150680542,-.49699997901916504)，直库鼻边三角面13888–13895距离已小于球半径约1.35–1.41mm；projectContactPositions第一轮修正1.168mm超过原4µm预算。不是袋底/收集尾段问题。
- 根因与修正：旧局部窗口只在球心越界时接管；改为中心域半径=原窗口半径+球半径，保守覆盖球体前缘到达窗口的时刻。全桌接触网格覆盖此边界，未改实体网格、恢复系数、捕获面或容差。临时穿透打印已撤去，原诊断日志保留。
- nine-ball-ownership-r1/session88220 exit0，原失败种子实际1项2.678s，settled，模拟时长16.162428s。
- regression-r1/session88931 exit0，实际6项7.243s：原9球种子、原15球种子、另一慢15球、全桌几何覆盖、任意时刻续算、正常进袋；原9球全部5次进入交接按完整实体网格检查，重叠不超过原4µm预算。
- final-r1/session58995 exit65：实际PhysicsEngineTests41项出现原10方法及新增低力度勾球前提差异（11失败方法/22失败断言）；SE/iOS17/AX5实际15/9球开球→交付→续打/重打/取消完整UI 1项92.369s通过。01059FE9、80B9986F、2F4850D4三原图已审：球形交付、比分和操作可见。随机UI球架与固定失败种子测试分别记证，不冒充同一输入。
- 新增差异核对：low-power-kick-current-r1/session79474原断言1项2.289s失败，输入杆头速度.6实际母球初速约.923，右库后t=3.1890607有真实球球事件。旧测试把.6无条件当作必然不足不成立。保留该输入为新物理见证测试；原“不足力度不接触”断言保留，输入改.1并增加空桌无碰库/完整停稳/最大行程小于目标可达距离的前提检查。不是生产降力度或删原失败证据。
- low-power-kick-premise-r1/session81038 exit0，实际2项2.209s；.6碰库后记录球心间距.05715998m，与2R在10µm内一致；.1行程前提及未接触断言通过。其余原10物理失败尚未裁定，不标W07完成。
- gate/session95245 exit0；所有句柄终态。FL-071固定9球穿透与反馈映射本地修复，跨设备/性能及完整W09仍待核。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-285；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-286 — 并发碰撞检测计时起点改为调用内局部值（2026-09-13）
- 根因：EventDrivenEngine.findNextEvent在并行搜索中使用共享label的begin/end，起点被其他线程覆盖/移除，出现负耗时及不同调用次数；原报告不能用于判断两类检测相对成本。
- 变更：两处DEBUG检测段以本地CACurrentMediaTime计时、recordSample汇总。计时加锁次数由每段两次减为一次；Release与物理、搜索代码路径不变。
- 验证：defense-local-timing-r1/session14556 exit0，2项23.881s；当前3组解描述与修改前逐字一致，旧5杆均停稳，实际遮挡断言通过。内部21.948852s是一次模拟器结果，不能宣称稳定加速或真机达标。两类记录各2557648次，最小耗时非负。库边累计54781.6ms/球球8581.7ms为跨线程累计，不是墙钟。
- 已应用至：.cursor/rules/55-test-engineer.mdc §并发性能计时；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-287 — 恒定球心跳过静态边界求根（2026-09-13）
- 根因：findNextEvent对速度/加速度严格全零的球重复求直库、圆弧与袋口交点。球心为常量时不可能产生新的正时间边界接触；原直库需逼近速度、圆弧需径向逼近，袋口退化常量方程无正根。
- 变更：仅这三处循环在计算a后跳过v与a的XYZ六分量均精确为零的球；没有速度阈值。球球检测/状态转换不跳过，带旋转产生非零a的滑动球照常检测，受撞后新v继续查询；局部空间接触与既有重叠处理保持。
- 验证：stationary-boundary-r1/session29195 exit0，4项25.295s：真实15/9种子开球、默认防守与旧五杆通过。三组返回参数及25球终位与DR-286日志逐字数值相同。r2/session79352 exit0，2项24.884s，搜索/全保真一致性与完整默认防守通过。两轮内部19.484/21.075s，修改前21.949s是单次样本，不声称稳定百分比或手机达标。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-287；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。常规旧失败及其他候选penetration仍有效，不以省算修复名义关闭。

## DR-288 — 袋角圆弧求根前使用保守运动范围（2026-09-13）
- 根因：混合调度小时间窗仍反复对远处袋角求四次方程；跨步缓存存在演化/失效风险，不移除eventCache.clear。
- 变更：ballCircularCushionTime增加当前时间窗位移上界；distance>D+|v|h+|a|h²/2+舍入余量才拒绝。h保留原maxTime+1e-6接触时间容差；转向加速由三角不等式覆盖，非有限窗不使用筛选。useReachBound=false仅供旧求根路径对照。未改弧几何、碰撞阈值或物理材料。
- 验证：arc-reach-r1/session36356 exit0，17280对照/825命中，命中时间完全一致；默认搜索/旧五杆通过，3组返回参数与25个终位与DR-287相同。内部20.937882s，不宣称稳定吞吐提升。
- arc-reach-regression-r1/session52170 exit65：实际47项21.460s，PhysicsEngineTests44项内仍原10个失败方法/21断言；失败方法集合与triangle-distance-regression-r1一致。9/15开球及scoring-only/full一致性3项通过。断言数22→21跨越DR-285/H01/DR-287等变化，不能归因本次或声称修复。检测调用次数与DR-287不完全一致，也不宣称所有中间候选逐位相同。
- 已应用至：.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-288；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。W07仍返工，下一步优先常规进袋失败分类，停止以小幅耗时波动代替主问题进展。

## DR-289 — 新引擎接续绝对时钟（2026-09-13）
- 场景：H01空间落台状态传给新建EventDrivenEngine时，原初始化只能从零时刻开始，无法直接保留此前飞行时间。
- 变更：新增throwing convenience init(tableGeometry:startingAt:)，校验非负有限且Float可表示，保留Double spatialTime及兼容Float currentTime。原初始化不变；不恢复球、历史事件或空间记录，也不证明球已受台面支撑。
- 验证：landing-planar-chain-r1为测试误访问private属性编译失败，改用既有getTrajectoryRecorder后r2实际2项2.152s通过。时间非法/默认零时钟、六组真实抬杆落台状态进入appDefault继续到stationary，首帧时间/部分位置速度自旋及原落台两步长检查通过。无正式页面接入；完整前缀合并和全台运动仍待验。
- 已应用至：.cursor/skills/ios-architecture/SKILL.md §DR-289；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。verify-gate通过，不关闭W07/H01/H02。

## DR-290 — 主调度接管初始腾空球（2026-09-14）
- 根因：初始非台面球远离袋口时没有空间owner，仍走平面滑动。main-airborne-r1的重力/水平速度4断言失败证明此缺口。
- 变更：LocalPocketOwnership.Domain区分pocket(id)/airborne；Handoff保留domain，空中pocketID为nil。混合入口无pending时对竖直速度非零或高度偏离超过既有4*tolerance预算的球建立airborne owner。沿用全桌空间网格、联合碰撞与接触晋升；相邻球继承实际域。真实支撑且脱离空间接触组后交回；空中捕获遍历实际六袋边界，仍经候选/邻球复核才提交。
- 验证：main-airborne-r2实际1项2.337s通过。airborne-main-regression-r1执行PhysicsEngineTests 50项17.670s，仍原10方法/21失败断言，与arc-reach-regression-r1失败方法集合精确相同；新重力/越球与低位碰撞通过。airborne-ownership-r1五项2.423s通过，含四组抬杆主入口落台/交回/停稳、旧所有权/过期状态/原子交回、捕获分段续算与混合任意截段续算。
- 已应用至：.cursor/skills/ios-architecture/SKILL.md §DR-290；tasks/UI-IMPLEMENTATION-SPEC.md Changelog；ADR-P10-12。gate通过。仍缺出界、空中库边、更多接触/性能、正式输入和动画导出，不声明H01或W07完成。

## DR-291 — v62 移动端渲染管线转正：单一闸门 + 全交互页默认 + 球房独立装配（2026-09-14）
- 任务：v62 收口（用户裁定「真机上没问题，收口吧」）；决策见 ADR-P5-01（`tasks/phases/P5-angle-training.md`）。
- 原始规范：四层渲染（移动基础光照 / S267 参考光照 / 表面质感 / 烘焙球房）各自 `#if DEBUG` 闸门（`previewRequested`、`requested`、`surfaceFinishesRequested`，模拟器还需 `-v62.s267Lighting`），仅 `FreePlayView`（非每日清台）、`ShotSimulationView`、`SceneAimingView`（仅 3D）逐页 opt-in；球房随 `applySurfaceFinishes` 装入；设置「球房风格」入口与组合预览球房为 `#if DEBUG`。
- 调整后：`MobileTableRendering.isEnabled` 单闸门（Release 恒开；Debug `-v62.legacyRendering` / `V62_LEGACY_RENDERING=1` 对照），`MobileReferenceLighting.requested` 为其别名，其余闸门与启动参数删除。`AngleTrainingScene.setupScene(mobileRendering:)`、`PositionPlayViewModel.setupScene`、`AimingQuizViewModel.setupScene` 默认 `isEnabled`；`FreePlayView`（含每日清台）、`ShotSimulationView`、`SceneAimingView` 去掉逐页参数，`contentIsAnimating` 节流恒开。球房 `installReferenceRoom()` 成为 `setupScene` 独立步骤（`roomMs` 计时）。离线渲染器（`DrillThumbnailRenderer`、`TableFigureRenderer`、`BallFaceRenderer`、`SequenceVideoExporter`、`BallFeelView.snapshot`）显式 `mobileRendering: false`。设置入口与预览去 `#if DEBUG`。球面非贴纸粗糙度固定 0.34（原 `surfaceFinishesRequested ? 0.34 : 0.30`，二档合一）。
- 原因：试点闸门叠加是「同页不同观感 / Release 不可见 / 大半球桌页仍旧管线」的根因；真机预算已由用户确认，试点策略应回收而非逐页补丁。
- 验证：`make build` BUILD SUCCEEDED（`build/v62-closeout-20260914/build.log`）。定向单测 `TableAppearanceTests` 7 / `ClothAppearanceTests` 4 / `BallStickerTests` 6 / `TrajectoryRendererTests` 6 / `PocketLeatherIntegrationTests` 8 项 0 失败（`test-targeted-2.log`，跳过 2 项见下）。`RenderQualityV62Tests` 非证据采集项 15 通过、223 项按既有 `V62_SHOT_DIR` 门跳过、0 失败（`test-rq62.log`）。Release 配置构建见 `build-release.log`。
- 已知/未验：① 模拟器 iOS 26.3 对主线程连续阻塞 ≥~30s 的测试宿主发 SIGKILL（legacy 场景 + 45s 忙等亦复现，`test-exp.log`），`testArchivedPocketAndFreeSequenceStepsRestoreSelection`（主线程同步跑 v63 空间物理 ~33s）与 `testNeutralThumbnailAfterSelectedScene`（首帧 `SCNRenderer` 热身 ~8s，偶发拉长）因此不稳定，`testPlanRealSolvePlayAndUndoRestoreLeather` 在 legacy 环境下同样失败（求解 >15s），三项属 v63 线程；② 未在真机复测本次改动后的其余页面（动作库详情、翻袋/颠球、拆球、开球、规划页）能耗与帧率，仅有用户口头「真机没问题」（基于三试点页）；③ `RenderQualityV62UITests.capture(mobile:reference:)` 的 `reference:false` 档位随中间档删除而失去区分意义，尚未清理。
- 回写目标：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`QiuJi/Resources/TrainingRoom/README.md`；`tasks/render-quality-v62/README.md` 当前结论段。
- 已应用至：`tasks/phases/P5-angle-training.md` §ADR-P5-01；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`QiuJi/Resources/TrainingRoom/README.md`；`tasks/render-quality-v62/README.md`（2026-09-14）。

## DR-292 — 袋口内衬耗能体模型（2026-09-14）
- 根因：空间模型把 USDZ Leather 面当刚体墙，球被竖直半圆杯壁切向导回；leather-contact-trace-r1 显示 15 次擦碰法向从(-.957,0,-.290)连续转到(.707,0,.707)，绕壁 180° 后仍 1.9m/s。leather-sweep-r1：μ 0.2–2 × e 0–0.45 共 16 组全部弹出，μ≥0.5 逐位相同——e/μ 不是杠杆。实物照片（output/3d-v63/W07/liner-audit/joy-corner-pocket-real-20260914.jpg）证明皮革是台框外的软革围裙，非碰撞结构。决策见 ADR-P10-13。
- 变更：TablePhysics 新增 pocketLinerRestitution=0 / pocketLinerRetention=0.4；LocalPocketSimulation.Surface 新增 tangentialRetention（默认 1）；PocketContactResponse.linerSink 于单球（LocalPocketSimulation.run）与多球（resolveContactGroup）刚体解之后按逼近接触施加；TrajectoryRenderer.contactSurfaces 仅 .leather 绑定。pocketThroatRestitution 只剩平面喉壁使用。test_predictor_objectPath_reachesPocketWhenPotted 窗口由 dropRadius-R+6mm 改为 dropRadius（球心在洞口内），依据：球贴后壁落洞距袋心 29.8mm，与实物大力进袋在后壁消失一致，断言目的不变。
- 验证：liner-retention-sweep-r1 exit0（保留 ≤0.6 八组落洞、1.0 两组弹出）；liner-regression-r2（-O，同 arc-reach-regression-r1 选择集）55 项 1 失败→窗口修正后该项通过依据见上；liner-regression-r4（QiuJi-v63-iOS17 专用模拟器）61 项 57 过 3 跳过 1 失败 0 重启。唯一残留 test_R2_railFrozenEndToEnd 穿透 5–11mm：liner-r2-ab-old 用旧参数重跑穿透值逐位相同，为既有贴库穿透，归入 W07 待分类清单。liner-regression-r1/r3 在 UI 开着的 iPhone 17 Pro 上出现 15 项 30s SIGKILL，与 DR-291 记录的 iOS 26.3 主线程阻塞击杀一致，属环境，不计入。
- 已应用至：tasks/phases/P10-physics-content-pipeline.md §ADR-P10-13；tasks/3d-v63/W07-working.md、W07-liner-contract.md、README.md；tasks/UI-IMPLEMENTATION-SPEC.md Changelog（无 UI API 变更）。真机性能、六袋偏入全矩阵仍未完成，不关闭 W07。


## DR-293 — 求解裁定回归平面判据，空间袋口改显式模型（2026-09-14，W17-A）
- 根因/动机：用户裁定「对求解器而言球心进袋口圈即进」——既有求解/评分/规则全部按平面判据标定，袋内严格物理成本过高；DR-292 后内衬为耗能体，平面判据成为空间结论的合理代理。
- 变更：`EventDrivenEngine.SimulationModel.appDefault = .planarReference`；原策略保留为显式 `spatialPockets`。`EventDrivenEngine.simulate` 循环退出前补评早停判据（纯自旋尾段跨过 maxTime 时循环内检查永不触发，scoring-only 误报 `.timeLimit`）。14 条测试改显式模型 / 6 条改写为新契约 / 1 条按 DR-292 结果更新前提，清单与逐条依据见 `tasks/3d-v63/W17-working.md`。
- 验证：w17a-regression-r2 83 项 0 失败（切默认后原 5 失败逐条归因处理）；w17a-injection-r2 改写 6 条通过 1 skip；性能 A/B 单杆 204→4 ms、满台 6898→27 ms、斯诺克 7.51→0.63 s、翻袋最坏 1.763→0.062 s（`output/3d-v63/W17/perf-spatial-baseline.log` vs `w17a-injection-r1.log`）。w17a-full-r1 另有 20 条既有失败经 A/B 与历史日志核实与本次无关，逐条留证于 W17-working，不闭合、不归因给 W17-A/DR-292。
- 已应用至：tasks/phases/P10-physics-content-pipeline.md §ADR-P10-14；问题集合_v63.md v63.14；tasks/3d-v63/W17-working.md、README.md；tasks/UI-IMPLEMENTATION-SPEC.md Changelog（无 UI API 变更；进袋回放暂回 pre-v63 视觉腿，待 W17-B/D）。


## DR-294 — 平面判进后的脚本化网兜落位（2026-09-14，W17-B/D）
- 动机：用户要求「球进袋后有完整轨迹、最后停在袋口支架中」并选定确定性落位 + 超容量先进先出。方案 v63.13 W17-B 原写「判进后跑 ≤0.3 s `LocalPocketSimulation`」，实施改为脚本（偏离已在方案批次表与 W17-working 声明）：①空间求解器袋底+内衬双接触 `supportConvergence` 停滞未闭合，正是下落段末态；②平面默认下 App 不再加载 USDZ 资产（首载 ~2 s）；③脚本天然实时/导出同源且确定性。
- 变更：新增 `PocketNetPresentation.swift`（`PocketNetProfile` 角/中袋 4 环剖面 + 静止深度，全部来自 `PocketGeometryAsset` 探测 `bag-probe.log`；`NetPocket.wall/slots`；`descent` 240 Hz 步进用 `TablePhysics.gravity` / `pocketLinerRestitution=0` / `pocketLinerRetention=0.4`；容量 2、FIFO 淘汰置 `fadeStart`、其余下移）。`PocketCollectionTail` 增 `samples`/`fadeStart`；`TrajectoryRecorder.recordPlanarCollectionTail`（须有 `pocketEntries`、无 `confirmedCaptures`、起点时刻一致）；`TrajectoryPlayback.init` 幂等挂尾，`collectionOpacity` 网兜球恒 1，仅淡出球 `removeFromParentNode`。
- 坐标陷阱：`TrajectoryPlayback.surfaceY` 是球心平面（调用点传 `yLevel = surfaceY+R`），首版据此算落位差一个 R，被端到端用例（y 0.7259 vs 0.6973）抓出；改为读 `PocketEntrySnapshot.geometry.pockets[].center.y`（台呢面）。已回写 `geometry-spatial-reasoning` 技能。
- 验证：`net-r2.log` 7/7；`w17bd-r2.log` 41 项 0 失败（含补回的三处默认路径呈现断言与新开球用例）；剖面常量由 `testProfileMatchesBundledBagEnvelope` 对 24 环门禁（轴 3 mm / 半径 4 mm / 网口与静止高 0.5 mm）；出图自检三例（未入库）。
- 未做：跨杆保留（页面层 8 处 `isHidden`）、W03 裁剪例外截图、用户实看样片、真机目测。
- 已应用至：tasks/phases/P10-physics-content-pipeline.md §ADR-P10-15；问题集合_v63.md v63.15、§5.5、§10；tasks/3d-v63/W17-working.md、README.md；.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-294；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-295 — 支撑求解约束残差的舍入下界须含 v/dt 操作数（2026-09-14，W17 附带）
- 根因：`LocalPocketSimulation.integrate` 支撑迭代的 `constraintResidual` 含 `dot(v,n)/dt` 与 `slipT/dt`，但收敛判据只给 `motionResidual` 设了 `velocityRoundoff/(dt·forceScale)` 下界（DR-279）。绝对时钟相减产生的 dt≈1e-15 s 「时钟碎片步」上，速度舍入 ÷ dt 变成数 m/s² 的伪残差（w17a-full-r1：6.78 / 0.107 / 0.00116 m/s²，与 64·ulp·|v|/dt 量级一致），3 条 `PocketGeometryV63Tests` 因此 `supportConvergence`。
- 变更：两处收敛判据改用 `max(0, constraintResidual − velocityRoundoff/dt)`。不改 tolerance、不改迭代，不影响 dt 正常步（dt=2.4e-4 时下界 ~6e-11 m/s²）。
- 验证：`w17bd-r1.log` 该舍入族 3 条消失，`testBagMotionConvergesAcrossEnvelopeResolutions` 首次通过；dt≈2.4e-4 / 1.6e-8 的真实停滞族（残差 3–5e-6 m/s²，4 条）**仍失败**，为既有求解器停滞，未归因、不闭合。碎片步的上游来源（Float/Double 时钟差）未定位。
- 已应用至：tasks/3d-v63/W17-working.md；.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-279 补注。


## DR-296 — 3D 辅助线可见性与 2D/3D 交互统一（2026-09-14，用户 7 条反馈）
- 触发：用户反馈 ①上半台（+X）沿两条长库的带状区域内**所有**投影线断掉；②3D 假想球虚线环悬空；③接触点太大；④球杆打点只有左右塞、无高低杆；⑤虚线段太长；⑥所有 2D 球桌应可放大/平移，现状为最小尺寸；⑦部分模式 2D 与 3D 上下方向相反。
- 根因 ①（实测，非猜测）：`TableAssistSurface.load` 用 `|y − bedY| < 1e-5` 认定台呢底面。**内置 USDZ 的头半台（+X）长库旁床面 quad（x∈[0.03,0.635]、|z|∈[0.512,0.640]）有一个顶点被抬到物理面 0.80001（bedY 0.79474，+5.3 mm）**——模型缺陷，非导出抖动（我此前「1.2e-5 抖动」的判断是错的，`hitTestWithSegment` + 逐面 dump 推翻）。这些帐篷面被过滤掉 ⇒ footprint 出两块 13 cm × 60 cm 空洞 ⇒ 所有投影辅助线在此被裁掉；−X 半台同位置是 5 点平面多边形，无此问题。修法：接受 `y ∈ (bedY − 1 mm, max(bedY, surfaceY) + 1 mm)` 的 TaiNi 面（库边台呢 ≥ +31 mm、袋口斜坡 −55 mm 均不会混入），并记录 `topY`；`displayedClothY` 在非移动管线下改用 `topY`，避免帐篷角深度遮挡。门禁：`testLoadedClothFootprintHasNoHolesOrOverlapsInsidePlayfield`（全台 1 cm 网格零空洞零重叠 + 用户报错线段 ribbon 面积精确）。
- 变更 ②–⑤：假想球虚线环子节点 y = −R + 线宽（贴台呢，`DR-118` 球心契约不变）；**补（同日用户追加）**：假想球球心红点 `ghostAimDot` 同样下沉到台呢（X/Z 仍是球心），球心高度的红点在透视下悬空；接触点 9→4.5 mm、瞄准点 6.5→4 mm，单一真源 `TrajectoryStyle.contactPointRadius/aimPointRadius`（覆盖 D8 拍板）；`CueStroke.strikePosition` 增 `spinY`（+高杆 = 抬高 `spinY·R`，与 `BTSpinPad`/`CueBallStrike` 约定一致），全部 12 处调用点透传；`CueStick.update(tipInset:)` + `AngleTrainingScene.cueTipInset(forStrike:)` 由击球点相对球心偏移推得杆头前伸 `R(1−√(1−a²−b²))`，避免偏心打点杆头悬空（`CueClearance` 碰撞搜索仍按名义 tipOffset，保守）；虚线 main 50/26→20/12、hint 28/20→14/10，清除 4 处字面量；`.table` 放置的虚线（单线/折线）合并为**一个**裁剪几何节点，节点数不随加密增长。
- 变更 ⑥：`CameraRig` 新增 `topDownFitScale/topDownZoom(1–4×)`，取景值为**下限**（无自适应的页面把当前 scale 视为下限）；`applyTopDownZoom` 以捏合中心为锚点、`applyTopDownScreenPan` 按模式映射屏幕轴（**修正 rotated 模式下平移轴对调的旧 bug**）、`clampTopDownPan` 按可见半宽钳到球桌外框（取景态平移恒为 0）、双击 `resetTopDownZoom`。`AngleSceneView` 新增双指平移 + 双击识别器；捏合/双指平移在 `tapsOnly` 页也可用，单指语义不变。删除 `applyCameraPan/applyTopDownAreaZoom`。
- 变更 ⑦：`CameraRig.overviewYaw = π`（相机在 −X 脚端看向 +X，开球线在远/上方，与 rotated 2D 的 screen-up=+X 一致）；init 与 `observeWholeTable()` 默认用它，视口变化的重取景传 `targetYaw` 不转向；`DrillSceneView` 横向 π/2 不动；横屏 2D（`applyTopDown2D`，screen-right=+X）未改。
- 验证：`make xcodegen` 后 build-for-testing 通过；`TableAssistDR296Tests` 10/10（取景下限/缩放钳制/锚点不动点/分模式平移方向/钳制/俯瞰相机位/spinY/杆头 inset/环高/合并几何）；22 套相关 147 项：**仅 4 条既有失败**（`TableAssistSurfaceV63Tests` 四条期望 `measuredBedY+0.001`，与 DR-291 移动管线抬升到 `surfaceY` 的现状不符，已 stash 到 HEAD 复现为既有、本次不闭合）；`AimCloseupEvidenceTests/FeltParity` 2 条亦为 HEAD 既有。出图自检（未入库）：2D 取景/3× 锚点缩放、3D 俯瞰、球杆与假想球近景——+X 带内白/黄虚线连续，2D 与 3D 同向。
- 未做：真机手势手感；横屏 2D 页与 3D 的方向一致性（当前 screen-right=+X，用户口径「开球线一侧在上」在横屏无定义）；四条既有高度期望测试的修订。
- 已应用至：tasks/UI-IMPLEMENTATION-SPEC.md Changelog；.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-296。

## DR-297 — 网兜下落脚本：极坐标真实袋壁 + 只吃水平速度的内衬接触（2026-09-14，W17-B/D 返修）
- 触发（用户实看）：①球撞皮革后**穿模**进皮革；②撞后垂直下落远慢于重力；③要求「吃掉水平速度后，按重力 + 壁型 + 支架轨迹落到底，多球按先进先出」。
- 根因（实测，非猜测）：
  1. 穿模：DR-294 把网口以上按「平面落袋圆（R 42 mm、圆心=平面袋心）→ 网口环」的漏斗建模。对资产做球体-网格洪泛探测（`leather-probe.log`）发现**角袋皮革杯在台呢高度的球心自由区是半径 ≈18 mm、圆心在平面袋心内侧 ≈24 mm 的区域**，平面袋心本身已在皮革内 0.3 mm；落袋圆远端在皮革里 ≈48 mm。中袋自由区是沿库方向拉长的非圆形（后壁 30.5 mm、颚口 15 mm，圆拟合 rms 8.6 mm）。
  2. 慢落：`descent` 触壁时对整个切向速度（含 `v.y`）每步 ×0.4（240 Hz），角袋内倾壁上球以 ≈0.07 m/s 蠕动。
- 变更（`PocketNetPresentation.swift`，仅呈现层）：
  - `PocketNetProfile.Ring` 改为**极坐标环**：深度（球底低于台呢）每 5 mm 一环、0–130 mm 共 27 环；每环 (dx,dz) 轴 + 12 方向球心可达距离，全部来自对皮革+库颚+网绳三类三角形的球体-网格探测（2 mm 网格 + 0.5 mm 射线，`leather-probe-polar.log`）。朝台面开放的方向按落袋圆 +2 mm 封顶。去掉漏斗/`mouthDepth`。
  - 接触力学：法向按极坐标曲面切向叉积求（壁收窄法向朝下、外扩朝上）；到达冲击（前一步未接触且 `vn > 0.05`）整体切向 ×0.4（与空间 `linerSink` 同）；持续滑动只去法向分量，切平面分解为**沿坡向**（重力驱动，仅 Coulomb 摩擦 μ=`cushionFriction` 0.2 × 法向载荷）与**环向**（内衬握持、时间常数 0.05 s）；`v.y` 不再被任何保留系数乘。入袋快照若已在壁外，60 ms 内线性收回，不瞬跳。
  - 落槛/FIFO/`PocketCollectionTail`/`TrajectoryPlayback` 契约不变；`settle`/`shift` 末样本精确等于槛点（修浮点 1 ulp 偏差）。
- 验证（`net-r5.log`、`net-related-r1.log`）：
  - `testProfileMatchesBundledPocketMeshes`：6 袋 × 9 环 × 12 方向，轴与 90 % 可达处球体离网格 ≤ 3 mm，可达 +6 mm 处必被挡（非封顶方向）。
  - `testDescentBodyStaysOutOfTheBundledMeshes`：6 袋 × 3 速 × 3 角，入袋收回期后**球体**最大侵入网格 **1.0 mm**（DR-294 漏斗版同口径最坏 ≈48 mm）。
  - `testDescentFallsUnderGravityAfterLinerContact`：到达时水平速度 1.2→<0.1 m/s；离壁步 dvy 恰为 −g；近垂直壁持续滑动 dvy ≤ −0.8 g；触底用时角袋 0.19 s / 中袋 0.25 s（自由落体 0.16 s；旧脚本 >1.5 s 上限触发）。中袋 1.5× 来自资产网兜在网口下方的真实内收段（法向 y ≈ −0.6），是壁型不是阻尼。
  - 相关 6 套 87 项 0 失败（PocketNetPresentation 9、TrajectoryRenderer、CueScratchLifecycle、BreakFlowRunnerV6、PhysicsEngine）。
- 未做：真机/页面目测仍未做（用户上次实看的是漏斗版）；跨杆保留、W03 裁剪例外同 DR-294。
- 已应用至：tasks/phases/P10-physics-content-pipeline.md §ADR-P10-15 补记；问题集合_v63.md v63.16；tasks/3d-v63/W17-working.md §W17-B/D 返修、README.md；.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-297；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-298 — 网兜下落脚本：穿过网兜底环、沿回球支架滚到底挡（2026-09-14，W17-B/D 二次返修）
- 触发（用户实看 DR-297 版）：「重力挺像了，但球停在袋网底部；我要的是继续往下滚，直到支架底部」。用户附图：内置桌型是**开口网兜 + 金属回球支架**（两根杆从网兜底沿台边斜向下到桌腿处的挡头）。
- 根因：DR-294/297 把 `restingDepth`（资产捕获边界的球心最低点 = 网兜底环）当作槛点地板，脚本在网兜底停球；支架从未建模。
- 实测（球体-网格支撑探测，`output/3d-v63/W17/rail-probe.log`，对全部六袋）：
  1. 支架杆为材质 `Black`（挡头/悬挂件 `Gold`），**沿内向 X 轴**（`NetPocket.axisX`，中袋两侧均为 +X）从袋心下方到挡头；球心槽线在袋心竖直平面内（横向偏差 ≤ 3 mm），为直线：角袋 s 0.030→0.160 时 y 0.6190→0.5635，中袋 s 0.015→0.145 时 y 0.6170→0.5615，斜率均为 −0.427（23°）；挡头接触位角袋 s ≈ 0.162、中袋 s ≈ 0.148。
  2. 网兜底环（`White`）在球心 y ∈ [exit−32 mm, exit−17 mm] 挡球、再往下无白色几何 ⇒ 资产底环内径 ≈ 50 mm，**比球（52.5 mm）小 ≈2.5 mm**；真实产品为开口。脚本按开口处理让球穿过底环（呈现层取舍，见「未做」）。
- 变更（`PocketNetPresentation.swift`，仅呈现层，裁定/规则不动）：
  - 新增 `PocketRailProfile`（`startDrop`/`slope`/`stopDistance`/`firstClearDistance`，角/中袋两表）；`NetPocket` 增 `rail`、`netExitY`、`railPoint(atDistance:)`、`railTangent`/`railNormal`、`railDistance(of:)`、`railHeight(under:)`。
  - `slots`：改为**支架槛点链**——第 1 球靠挡头，之后每球沿斜面 2R 相接，直到球体仍在底环内的 `firstClearDistance` 为止；角/中袋各 **3 个**（容量由此派生，删除 `netCapacity=2` 与 `upperSlotLean`）。
  - `descent` 三段：网兜段（DR-297 不变，去掉槛点地板）→ 球心低于 `netExitY` 后自由落体（无壁）→ 触槽线即着陆：零恢复、只保留沿杆切向分量且不允许倒滚回网（`max(0,v·t)`）、横向由两杆 V 槽在 10 ms 内对中；随后 a = g·sinθ·5/7 滚下，到槛点**死停**（挡头/下方球，0 恢复，末样本精确 = 槛点）；自旋取纯滚动 ω = (n × v)/R。
  - `attach` FIFO 容量改为 `slots.count`；eviction 时上方球沿直线支架下移一槛（`shift` 不变）。
- 验证（`rail-r6.log`、`rail-related-r1.log`）：
  - 新 `testRailProfileMatchesBundledRods`（加载内置 USDZ）：六袋槽线每 1 cm 站点球体离所有材质 ≤ 1.5 mm、下 4 mm 必在 `Black` 杆内；槛 1 + 6 mm 必碰 `Gold` 挡头；底环在 exit−25 mm 处存在、exit−40 mm 以下无白；脚本支架段在清空区（`firstClear`+5 mm、着陆 20 ms 后）球体侵入 **0 / 1.0 mm**，着陆瞬态 ≤ 2.0 mm（离轴 7 mm 着陆骑杆 2–3 帧）。
  - `testDescentFallsUnderGravityAfterLinerContact` 扩展：离网后有自由落体步、支架上每步 Δv∥ = g·sinθ·5/7（1e-6）且速度严格沿杆、末样本 = 槛点；全程角袋 0.54 s / 中袋 0.63 s。
  - `testSlotsLieOnTheRail`、216 次下落不变量（高度单调、不低于槛点、网兜段在壁内）、FIFO 四球（第 4 球进时最早球淡出、其余下移一槛）、端到端默认进袋停在支架槛 1。PocketNetPresentation 10/10；TrajectoryRenderer/BreakFlow 默认开球/走位 scratch/CueScratch 共 35 项 0 失败。
- 未做：①返修版仍未经用户实看；②底环穿过是脚本取舍，若要严格不穿模需改资产（底环放大 ≥ 3 mm）；③杆间距/杆径未测，横向对中按时间常数而非几何 V 槽高度；④挡头零恢复（真实钢挡会有轻微反弹声/回弹）；⑤跨杆保留同 DR-294。
- 已应用至：tasks/phases/P10-physics-content-pipeline.md §ADR-P10-15 补记；问题集合_v63.md v63.17；tasks/3d-v63/W17-working.md §W17-B/D 二次返修、README.md；.cursor/skills/geometry-spatial-reasoning/SKILL.md §DR-298；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-299 — 支架驻留：进袋球是「球库」，跨杆保留、球回桌即离架、满链 FIFO（2026-09-14，W17-D 跨杆保留）
- 触发（用户实看 DR-298 版）：「球到支架底端后，只有一颗球也会自动消失」。随后澄清规则：**永远只有 16 颗球**；进袋球就算进了球库（留在支架上）；同一颗球再被放回球桌时，支架里的它要消失、后面的球按顺序向前补位（1,2,3,4 拿走 2 → 1,3,4）。
- 根因（事实）：不是 FIFO 判错。DR-294～298 的槛点/淡出逻辑都对，但支架上的球用的是**盘面球节点本身**；各页 finish 处理器（`PositionPlayViewModel.finishStrike`、`DrillSceneView`、`BankShot`/`Diamond`、`placeStepBoard` 等 8 处）在回放到 `duration` 时对进袋球一律 `isHidden = true` / 复位重摆——节点被页面拿走，支架就空了。这是 DR-294 记录「跨杆保留未做」的直接后果。
- 变更（呈现层，裁定/规则/计分不动）：
  - 新增 `Core/Scene/PocketRailInventory.swift`：每个 `AngleTrainingScene` 一份（`scene.railInventory`，`setupModelBalls` 重建球时 `clear()`）。支架上的球是盘面节点的 **`clone()`**（外观同源、号码同源），驻留记录 `Resident{clone, weak source, pocketID, slot}` 按袋 FIFO 排列。
  - `TrajectoryPlayback(recorder:surfaceY:railInventory:)`：有库存时 `attach(preOccupied:)` 用占位项把已驻留球放进最低槛（时间 −∞ = 最老），本杆新球从其上排起、满链先淘汰驻留球再淘汰本杆球；`railResidencyAction`：盘面节点只播台面段、到袋口 `.hide()`；克隆体自己跑网兜/支架段动作（不受页面 `removeAllActions()` 影响），到槛点 `commit` 为驻留；本杆内被 FIFO 淡出者 `discard`；对已驻留球的挤出由 `inventory.evict` 在新球开始下落的实时刻同步动画（淡出 + 后方球前移）。
  - 回桌即离架：`commit` 后克隆体挂一条逐帧 `railWatch` 动作，发现源节点 `isOnTable`（挂在场景、自身及祖先未隐藏、opacity>0.5）即 `release`：克隆淡出、其后驻留球沿 `slots` 前移一槛；`occupancyByPocket` 读取前先 `reconcile()`，保证新杆布槛时库存已反映盘面。再次进袋时 `makeClone` 先释放同源旧克隆，一颗球在支架上永不重复。
  - 12 个场景回放创建点（PositionPlay/Silu/PlanThree/Snooker VM、DrillSceneView、AimPointSceneTrainingView）传入 `scene.railInventory`；求解器、导出、BreakFlowRunner、PositionPlaySolver 保持 `nil`（无跨杆语义）。
- 验证（`/tmp/dr299*.xcresult`）：PocketNetPresentation 14/14（新增：占位槛点让新球停槛 2；满链 3 驻留 + 2 新球时驻留先淘汰、本杆球不淡出且前移；库存回桌释放 1,2,3−2→1,3 且槛位 [0,1]、opacity 0/隐藏不算回桌、重进袋替换不重复；溢出淘汰最老 + `clear`）；BreakFlowRunnerV6 19/19；TrajectoryPlaybackSpin/Settle、TrajectoryRenderer、PositionPlayFreeAim、SpinExportParity、RenderQualityV62 共 268 项 0 失败（225 skip 为原有条件跳过）。App 目标 `** BUILD SUCCEEDED **`。
- 未做：①用户实看（单球驻留、连杆多球补位、回桌离架）；②导出（`SequenceVideoExporter`）无库存，单杆内正确、不含前几杆驻留球；③`railWatch` 在渲染线程回调里改库存字典（已用 `weak` + 幂等 `release` 兜底，未加锁）；④页面「重置/重摆」不清支架（按用户口径：球回桌才离架，桌型重建才清空）。
- 补记（同日，用户实看：「两颗球重叠」）：根因是 **`ShotPredictor` 的预览回放先建了 `TrajectoryPlayback`（无库存）**，`attach` 幂等 ⇒ 尾迹已按空支架排在槛 0，场景回放再传库存也不重排，新球压在驻留球上。修：`TrajectoryRecorder.planarTailOccupancy` 记录尾迹布槛时的占用；`attach(preOccupied:)` 改为 `nil`（求解/导出）只补缺失尾迹，非 nil 且与记录不同则**重排全部平面尾迹**。另把逐帧 `repeatForever` 观察动作换成 10 Hz 主线程 `Timer`（动作会迫使 SceneKit 永久逐帧渲染）。新增 `testScenePlaybackRelaysTailsAttachedBySolverWithoutRailKnowledge`；PocketNetPresentation 15/15 + BreakFlow/Playback/Renderer/FreeAim 共 53 项 0 失败。
- 已应用至：tasks/phases/P10-physics-content-pipeline.md §ADR-P10-15 补记；问题集合_v63.md v63.18；tasks/3d-v63/W17-working.md §W17-D 跨杆保留、README.md；tasks/UI-IMPLEMENTATION-SPEC.md Changelog。

## DR-300 — 支架着陆改为角动量守恒的滑→滚（2026-09-14，用户实看「支架滚动稍快」）
- 触发：用户实看 DR-299 版，「球在支架中的滚动速度稍微有一点点快」。
- 实测（临时探针，已删）：内置支架在球心正下方有一根 `Black` 承托杆（d = R，z = 0），两侧 z = ±30 mm、球心高度处各一根护杆（间隙 0.6–1.1 mm）——是「中托 + 双护」三杆结构，**滚动半径 = R**，5/7 因子与资产几何一致，不能用「双杆 V 槽减小有效半径」解释偏快。中袋槽线在承托杆上方约 4.5 mm、倚靠 +z 护杆（DR-298 槽线横向偏差，未改，间隙非侵入）。
- 根因（模型错误）：DR-298 着陆时把切向速度全部保留并**瞬时赋予纯滚动自旋**（无中生有的角动量）。正确做法：接触点摩擦冲量使滑转滚、关于接触点角动量守恒 ⇒ v_roll = 5/7·v_t + 2/7·R·ω_t；无自旋落下的球起滚速度应损失 2/7。
- 变更：`PocketNetPresentation.descent` 着陆段按上式取 `vAlong`（仍不许倒滚回网）；测试新增着陆断言（起滚速度 = 公式值、必小于到达切速）。角袋全程 0.54→0.57 s、中袋 0.63→0.66 s；末速主要由 23° 斜面重力决定（≈0.9 m/s），本修只压起滚段。
- 未做：①用户复看；②若仍觉快，剩余物理自由度只有资产斜度（23°）与滚动阻力系数（钢杆/酚醛球典型 0.002–0.005，需给出来源后才加，⛔ 不做视觉调参）。
- 验证：PocketNetPresentation 15/15（`/tmp/dr300.xcresult`）。
- 已应用至：tasks/3d-v63/W17-working.md；tasks/PROGRESS.md 头部注释。

## DR-301 — 回球支架按「有摩擦的耗能体」处理：滚阻 + 着陆耗能（2026-09-14，用户实看 DR-300 仍嫌快）
- 触发：用户「还是太快了，可以认为支架也是有摩擦力的」。
- 分析（数值）：支架段时长由**着陆沿杆速度**主导——球从底环自由落体 ≈0.25 s、≈2.4 m/s 砸到 23° 斜杆，刚体零恢复 + 滑→滚后仍有 0.57 m/s（角袋），L/v₀ ≈ 0.22 s；单加滚阻 μ=0.2 只把滚动段 0.167→0.19 s（+12%），μ 再大也压不下去且 μ ≥ tanθ=0.427 球到不了挡头。
- 变更（`BTPhysicsConstants.swift` 两个呈现参数 + `PocketNetPresentation.descent`，裁定不动）：
  - `TablePhysics.railRollingResistance = 0.2`：`railAcceleration = 5/7·g·(sinθ − μ·cosθ)`，净加速度减半。
  - `TablePhysics.railLandingRetention = 0.4`：着陆滑→滚后沿杆速度只保留 0.4（与内衬 `pocketLinerRetention` 同口径的耗能体处理）。
  - 两者都是按观感定的呈现参数（注释已写明不是实测系数）。
- 效果：角袋滚动段 0.167→0.30 s、全程 0.57→0.70 s，到挡头末速 ≈0.89→0.65 m/s；中袋滚动段 0.22→0.36 s、全程 0.66→0.80 s。着陆瞬态/稳态侵入仍 0 / 0.8 mm。
- 验证：PocketNetPresentation 15/15 + BreakFlow 默认开球网尾 1/1（`/tmp/dr301b.xcresult`）。过程记录：一次 xcodebuild 增量构建未重编改动文件（打印未出现），`touch` 后重建才生效——凡计时/数值断言无变化即怀疑陈旧二进制。
- 未做：用户复看；若仍嫌快，下一个自由度是 `railLandingRetention` 再降或资产斜度。
- 已应用至：tasks/3d-v63/W17-working.md；tasks/PROGRESS.md 头部注释。

## DR-302 — 球面反射改为球房烘焙探针，去掉 v62 解析灰世界（2026-09-14，用户实看「球像蒙了一层膜」）
- 触发：用户对灯光/球桌/球房满意，唯独球「上面好像有一层膜」。要求先分析再做，并确认不影响其他效果后动手。
- 根因（代码事实）：`MobileReferenceLighting.sampledBallShader` 中 `v62Reflection` 对未打到台呢/灯板的反射方向一律回退到解析函数 `v62World(d)=0.06+1.2·(1−|d.y|)²`——一个无色、地平线最亮（1.26）的灰渐变；漫反射环境项 `v62worldIntegral(n.y)` 同源。该模型是 v62 S267 在空房间+绿呢下校准的，球房换成烘焙实景后球反射与画面脱节：球腰均匀灰带 + 掠射角 Fresnel 放大成均匀白环 = 「膜」。放大器：编号球粗糙度 0.12 把两块灯板反射抹成灰斑。
- 变更（只动球材质链路，桌呢/木边/球杆/皮口/球房 shader 一行未改；共用的 `applyHighlightHeadroom` 按约定本轮不碰）：
  - 新增 `QiuJi/Core/Scene/RoomReflectionProbe.swift`：在球房装配后，从桌心球高处用 `SCNRenderer` 渲 6 面 128² LDR 快照（`wantsHDR=false`，sRGB 解码回线性；球/球杆/覆盖层临时隐藏，球桌与灯保留），CPU 重采样为 512×256 等距柱状 `rgba16Float` MTLTexture（blit 生成 mip），上半球投影为 SH9 并预乘余弦卷积（着色器直接得 E/π；下半球是台呢，仍由解析 `bounceIntegral` 负责，避免重复计光）。按 `RoomStyle` 缓存，首个场景烘焙、后续复用；`neutral` 探针复刻旧灰世界，仅作球房装配前的过渡。
  - `sampledBallShader`：`v62Reflection` 回退改为 `v62Room(texture, d, lod)`（`lod = roughness·5`），漫反射 `env` 改为 SH9 球房照度；参数块统一为 `ballShaderArguments`（`selectedClothAlbedo` + `roomReflection` + `roomSH0…8`）。`#pragma arguments` 在 declaration 函数内不可见，纹理经参数传入。
  - `stickerBallRoughness` 0.12 → 0.05（酚醛树脂近镜面）；母球 0.34 不动。
  - `AngleTrainingScene.installReferenceRoom` 末尾 `installRoomReflectionProbe`，换球房风格时球材质重新绑定；`enhanceBallMaterials`/`MobileReferenceLighting.apply` 传入 `scene.roomReflectionProbe`。
- 验证：`RoomReflectionProbeTests` 7 项（等距柱状映射往返、六面实色落位、屏幕朝向 = `cross(forward, up)`、SH9 半球均匀光 E/π 上=L·1.000/侧=L/2·1.000/下=0、binary16 编码、场景烘焙+全部球材质绑定+换风格重绑；1 项证据渲染门控）0 失败；`BallStickerTests` 6/6（生产粗糙度断言改引用常量）、`ClothAppearanceTests` 4、`TableAppearanceTests` 7、`PocketLeatherIntegrationTests` 14、`RenderQualityV62Tests` 15 通过/223 门控跳过，全部 0 失败；`RenderQualityV62UITests/testReferenceShotSimulationPlayback` 真页面 4 张截图通过、着色器编译 0 错误。日志 `build/room-probe-after.log`、`room-probe-regress*.log`、`room-probe-ui.log`。
- 证据渲染（模拟器）：`output/render-quality-v62/S490-room-reflection-before/` vs `S491-room-reflection-after/`（三风格 × 瞄准/13 号球特写/母球特写）。特写对比：灰带与白环消失，灯板高光收成两条锐利亮条，橙色饱和度恢复，球腰出现球房墙面/库边的弱结构反射；母球（0.34）保持柔和无灰环。
- 成本（模拟器 Debug，首个场景一次性）：每风格烘焙 200–470 ms（渲染 90–350、CPU 投影 ≈95、上传 16），首次含着色器热身偏高；进程内缓存后为 0。⚠️ 真机帧率与 Release 冷启开销**未测**（H-26 真机离线）；着色器每样本多一次 2D 纹理采样，理论增量小。
- 已知限制：探针从桌心单点采样（局部 cubemap 无视差修正）；台呢颜色/桌型变化不触发重烘（只影响库边区域与探针中的台呢，不影响解析台呢项）；`RenderQualityV62Tests` 历史消融对 `v62World`/`worldIntegral` 的字符串替换现已无目标（门控跳过，作历史证据保留）。
- 未做：真机帧率复测；用户实看；若高光顶部仍显平，下一步再单独讨论共用的 `applyHighlightHeadroom` 曲线。
- 已应用至：tasks/PROGRESS.md「当前状态」；hub 状态卡「最近完成」。

## DR-303 — 球落到网兜/回球支架后仍被台呢染色：台呢项按球心高度淡出（2026-09-14，用户实看「进袋后像包了一层绿」）
- 触发：用户实看 DR-302 版，台面上正常，进袋到支架的球（赛事蓝台呢）整颗青绿。
- 根因（代码事实，与 DR-302 无关、历史即有）：球 shader 的两处台呢项都写死「球在 `y=0.8` 台面上」——①漫反射 `clothRadiance*v62bounceIntegral(n.y)` 对任何朝下法线都灌一份被灯照亮的台呢色补光；②`v62Reflection` 朝下分支 `q=p+reflected*((0.8-p.y)/reflected.y)` 不检查 t 的符号，球在平面以下时把光线**倒推**回台面，边界判定仍常命中，返回台呢色。青色反照率打在黄球上是绿、在黑 8 上是青绿环。
- 变更（仍只在球 shader + 探针内部）：
  - `clothWeight=clamp((center.y-0.8)/R,0,1)`：球心 ≥ 0.8+R 为 1、≤ 0.8 为 0；`clothRadiance` 乘该权重（同时压掉漫反射与镜面台呢项），掉网兜/滚支架过程中自然淡出。
  - 镜面台呢分支补 `t>0` 判定（独立正确性修正）。
  - 新增探针参数 `roomFloor`：烘焙时**多渲一张隐藏球桌的向下面**取平均线性辐亮度（桌下地毯）；朝下反射 `mix(roomFloor, result, clothWeight)`，漫反射补 `roomFloor*(1-clothWeight)*bounceIntegral`。中性探针取 `environmentBase`。
- 验证：`RoomReflectionProbeTests` 7 项 + `BallStickerTests` 6 项 0 失败（新增断言：地面辐亮度非黑、暗于室内照度、不带台呢绿主导；球材质须绑定 `roomFloor`）；着色器编译 0 错误；`RenderQualityV62UITests/testReferenceShotSimulationPlayback` 真页面通过。日志 `build/room-probe-dr303.log`、`room-probe-dr303-ui.log`。
- 证据：`output/render-quality-v62/S492-rail-ball-cloth-fade/<style>-rail-ball.png`（13 号球置于台面下 25 cm、支架高度）：下半球为深灰地毯反光、无青绿环，灯板高光保留；同批 `<style>-closeup.png` 台面球与 DR-302 无差异。「前」以用户两张实机截图为据。
- 成本：每风格烘焙多一张 128² 快照（模拟器 Debug 首次总计 300–580 ms，缓存后 0）。
- 未做：用户实看；桌身对支架球的灯板遮挡（球在支架上仍按台面亮度被直射）另议；`roomFloor` 为单一平均色，不含地毯纹理。
- 已应用至：tasks/PROGRESS.md「当前状态」（并入 DR-302 条）；hub 状态卡。

## DR-304 — 球体姿态是桌面状态：收尾禁止重置贴纸朝向（2026-09-14，用户实看「球停住后隔零点几秒贴纸原地转一下」）
- 现象：任意 3D 回放页，球停稳后 0.2–1 s 贴纸瞬跳到另一朝向，母球与目标球都有。
- 根因（事实，读码 + 定向测试）：`AngleTrainingScene.applyPosePolicy` 对非母球**无条件** `resetPose`，`CueBallPosePolicy.unchanged` 只保护母球；各页面收尾（`finishPlayback → applyBoard/loadBoard → place → showBall`、`BankShot/DiamondSystem.finishStrike → restoreBall → restoreNodePose`）在**最后一颗球自然静止 + 0.2/0.45 s 缓冲（有进袋 +1.02 s）**后触发，把逐帧积分出的终态四元数覆盖成单位姿态 / home。「home」是新摆球时抽的随机朝向，桌面前进后早已不等于击打前姿态。物理层 `.spinning` 尾段（残余竖轴塞原地减速自转）是连续运动，不是本次现象。
- 调整：
  - 场景层：`.unchanged` 对所有球生效；新增 `BallPoseSnapshot`（键→四元数）、`captureBallPoses()` / `restoreBallPoses(_:)`、`BallRestState`（位置+姿态）；`restoreNodePose` 明确只供静帧契约（Drill 静帧页/缩略图），击球/回放收尾禁止调用。
  - 走位页：`lastShotBeforePoses` 与 `lastPlaybackContext.beforePoses` 记击打前姿态；回放起点恢复击打前姿态、收尾恢复回放前抓的 `afterPoses`；重打/退回/临时回上一杆恢复击打前姿态（仅本会话实拍的杆有姿态可考，存档重放的杆保持 `.home`）。
  - 思路/三球/斯诺克：`UndoContext.ballPoses`（默认 `[:]`，测试构造不受影响）随 `makeUndoContext` 抓取，`restore(from:)` 与回放起点恢复；`replayAfterPoses` 收尾写回。
  - 翻袋/颛星：球形快照值类型 `[String: SCNVector3]` → `[String: BallRestState]`，`restoreBall` 写回位置+姿态，不再走 `restoreNodePose`。
  - 未改：`finishStrike` 桌面前进型收尾本就不碰姿态；Drill 静帧页 `restoreHomePositions`、`SequenceVideoExporter` 的确定性静帧口径保留。
- 验证：`make build` BUILD SUCCEEDED；定向 39 项 0 失败——`TrajectoryPlaybackSpinTests` 10（新增 `test_scenePose_unchangedKeepsObjectBalls_captureRestoreRoundTrips`）、`PositionPlayUndoSnapshotTests` 9（`assertSceneBoardEqual` 新增姿态往返断言）、`AdjustmentDraftLayerTests` 5、`PocketLeatherIntegrationTests` 14、`PocketGeometryInjectionV63Tests/testBankKickRejectIncompleteFreePredictionsAndRecover` 1。日志 `/tmp/pose-tests.log`。
- **补漏（同日，用户实看）**：分离角与走位页已正常，动作库「上手试打」仍跳。漏掉的是**逐杆序列演示**的杆间摆盘：`PositionPlayViewModel.runSequenceStep` / `presentSequenceStep` / `applySequenceRest(nil)` 与 `DrillSceneView.runStep` / `applyStepRest(nil)` 在杆间停顿 0.7 s 后用 `place`（默认 `.home`）重摆下一杆 `before`——位置几乎不变、姿态被重置，正是「停住后隔一下原地转」。改为 `placeSequenceBoard` / `placeStepBoard(preservePoses: true)`：先 `captureBallPoses` 再摆、摆完 `restoreBallPoses`，姿态只随物理回放变化；静帧落座（`preparePreviewBoard`）与序列结束回初始球形仍走确定性静帧。补验：`make build` 通过，`PositionPlayFreeAimTests` 11 + `PerspectiveStateV63Tests` 12（含 `enterSequenceMode` 用例）+ `BTShotHUDBarRenderTests` 2 + `TrajectoryPlaybackSpinTests` 10 = 35 项 0 失败（`/tmp/pose-tests-2.log`）。
- 未做：用户实看（肉眼验收口径：实打后母球/目标球停下不跳；序列演示杆间不跳；回放结束朝向与实打一致；重打后回到击打前朝向）；从存档重放得到的「上一杆」退回时姿态仍为 `.home`。
- 规则改进建议 / 回写目标：`.cursor/rules/20-swiftui-developer.mdc` § 经验教训 —「节点上由动画积分出的状态（姿态/位置）即事实；恢复局面必须从快照恢复，禁止用默认值/home 代替」。
- 已应用至：`.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / DR-304（2026-09-14）；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`tasks/PROGRESS.md`「当前状态」；hub 状态卡。

## DR-305 — 球桌单指 pan 与祖先 UIScrollView（训练翻页 TabView / 纵向 ScrollView）的手势仲裁显式化（2026-09-14，用户报「训练页球台示意 3D 下左右滑想转视角，和其他区域左右滑切换训练页面冲突」）
- 现象：`ActiveTrainingView.drillRecordContent` 用 `.tabViewStyle(.page)` 翻动作页，页内 `DrillRecordView › 球台示意` 嵌 `DrillSceneView`（3D 时 `interactionMode = .cameraControl`）。在 3D 球桌上横向拖动，翻页与相机 yaw 争同一根手指。
- 根因假设（推测，读码）：SwiftUI 分页 TabView 与 `ScrollView` 均由 `UIScrollView` 承载，其 `panGestureRecognizer` 与 `AngleSceneView` 装在 SCNView 上的 `UIPanGestureRecognizer` 之间只有 UIKit 默认仲裁（无 delegate、无 `require(toFail:)`），谁先认出谁赢，且 `interactionMode == .none`（训练页 2D）时 pan 仍会被识别并空转、反过来可能吞掉本该翻页的滑动。代码里没有任何显式契约，行为取决于系统实现。
- 调整（仅 `AngleSceneView.swift`）：Coordinator 成为 pan 的 `UIGestureRecognizerDelegate`：
  - `gestureRecognizerShouldBegin`：`panClaimsSingleFingerTouch = gesturesEnabled && interactionMode != .none` 为假时直接失败，滑动交给祖先滚动（训练页 2D 球台示意上左右滑 ⇒ 翻页）。
  - `shouldBeRequiredToFailBy(other)`：pan 有活可干且 `other` 是祖先 `UIScrollView` 的 `UIPanGestureRecognizer` 时返回 true（= 动态 `other.require(toFail: pan)`），翻页/纵向滚动等待球桌 pan，3D 起手在台面即只转相机；`tapsOnly` 页的移球/瞄准调整同样受保护。SCNView 自身兄弟手势、SwiftUI 的 `simultaneousGesture` 不受影响。
  - `.cameraControl` 全仓只在 3D 使用（grep 核实 17 处调用点），故不会出现「2D 1× 空转 pan 挡滚动」。
- 验证：`xcodebuild test -only-testing:QiuJiTests/AngleSceneViewPanArbitrationTests` BUILD + TEST SUCCEEDED，6 项 0 失败（3D cameraControl 阻断翻页 / tapsOnly 保护移球 / `.none` 与 `gesturesEnabled=false` 让路 / 仅 UIScrollView 的 pan 被要求等待 / 非本 pan 的识别器不受影响）。日志 `/tmp/pan-arb-test.log`。
- 未做：模拟器/真机真实手指验证（单测只覆盖 delegate 策略，UIKit 是否按预期把 `UIScrollViewPanGestureRecognizer` 置为等待未实测）；3D 下台面区域纵向滑动同样被相机 pitch 占用，需要滚页面得从台面外起手（口径与「滑动球桌视角」一致，但未与用户确认）。
- 规则改进建议 / 回写目标：`.cursor/rules/20-swiftui-developer.mdc` § 经验教训 —「UIViewRepresentable 内自装 pan 且宿主可能是分页 TabView / ScrollView 时，必须用 delegate 写出显式仲裁契约，禁止依赖 UIKit 默认先到先得」。
- 已应用至：`.cursor/rules/20-swiftui-developer.mdc` § 经验教训 / DR-305（2026-09-14）；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`tasks/PROGRESS.md`「当前状态」；hub 状态卡。

## DR-306 — 2D/3D 角度训练的假想球改用标准贴台呢虚线环（2026-09-14，用户要求「2D瞄准和3D瞄准的假想球样式也换成标准的贴球桌的」）
- 现象：`SceneAimingView`（路由 `sceneAiming2D/3D`，「2D/3D 角度训练」）经 `AimingQuizViewModel` 以 `setupVisualizationNodes(usesTrainingAssistStyle: true)` 建场景，DR-121 给该分支配的是**半透明整球**（`SCNSphere` r=R、透明度 0.5、blinn）；其余全部页面（走位/翻袋/颛星/思路/三球/斯诺克/瞄准点场景）都是 DR-296 定型的**贴台呢 16 段虚线环 + 落点小球**。3D 透视下整球假想球与真球争辨识，用户要求统一。
- 调整（仅 `AngleTrainingScene.setupVisualizationNodes`）：删掉 `usesTrainingAssistStyle` 的球体分支，所有调用方共用虚线环（环色仍 `TrajectoryStyle.contactColor`，环底 `-R + lineHint + 0.0005` 贴台呢）；`ghostBallNode` 仍位于球心高度（DR-118 位置/可见性契约不变）。训练态**其它**差异（瞄准点青色小球、接触点琥珀色、进球线 6/14 号改白、白瞄准线）一律保留。删除已无引用的 `TrajectoryStyle.TrainingAssist.ghostBall` / `ghostOpacity`。
- 测试：`TrainingAssistSceneTests.testGhostMatchesModelBallsAndWhiteLineReachesRail` 原断言 `ghost.geometry as? SCNSphere`（钉住旧设计）改为断言无自有几何、虚线段在 XZ 半径 = R 且底面贴台呢。
- 验证：`xcodebuild test`（iPhone 17 Pro 模拟器）`TableAssistDR296Tests` 10/10、`TrajectoryRendererTests` 6/6、`RenderQualityV62Tests/testTrainingGuidesDoNotCastShadows` 1/1、`TrainingAssistSceneTests` 4 项中 3 通过；`testGhostMatchesModelBallsAndWhiteLineReachesRail` 新增的假想球断言全部通过，但同测试末尾 **既有** 断言（瞄准线端点 y = `MobileClothAlignment.measuredBedY + 0.001`，实测 0.801 vs 期望 0.7957）失败 246 次——把本次 hunk 反向打回后复跑同测试仍在同一断言同样失败（日志 `/tmp/ghost-ring/baseline2.log`），判定为 DR-302 同日提交（球房探针/台呢测量）带入的既有失败，与假想球无关，未在本条修。
- 未做：模拟器/真机实看 2D/3D 角度训练页；HUD 特写 `BTAimCloseupHUD` 的 `BTGhostCircle` 本来就是圆环，未动。
- 注：本次改动被并行会话的提交 `a1fd2915`（DR-302–305）顺带带入，代码注释里 DR 编号已由误写的 302 更正为 306。
- 已应用至：`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog；`tasks/PROGRESS.md`「当前状态」；hub 状态卡（2026-09-14）。


## FL-072 — 支架库存跨线程与杆末提交竞态（2026-09-15）

- **触发**：W17-D 八杆真机对拍出现随机杆间丢失库存，模拟器曾通过；首次补终态提交后同一字典被主线程/SceneKit renderingQueue 同时修改而崩溃，真机 .ips 两线程栈确证。
- **根因**：把 SCNAction 回调误认为只在主线程；同帧等时长球动作的完成顺序也没有依赖保证，杆末可先保存旧快照。
- **候选修复**：PocketRailInventory 自有递归锁保护集合与节点操作；withActiveShot 把代次检查和源节点更新合并；正常收尾显式 finishPlayback，取消保持恢复杆前；Timer 只在主线程建立。详情、试打/自由击球、三规划页、翻袋/反射自由击球的正常终态接入。
- **验证**：真机 diagnostic-r2 保留状态差异；fix-r3/r4 .ips 保留无效修复证据；修正释放测试前提后 0.137/0.146s 内通过（裸节点对照也需一次主线程让出）。最终回归见 W16-device-20260914，不预支通过。
- **规则改进**：SceneKit 线程安全不扩展到自有 Swift 集合，必须以真实 callback 线程验证；立即弱引用判空须先验证框架自身延迟释放，不能用取消/清空消除待验证循环。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-072（2026-09-15）；`.cursor/skills/ios-architecture/SKILL.md` § FL-072。

FL-072最终定向验收（2026-09-15）：真机fix-r5六项通过，含八杆四档4638帧；optimized-final-r6全部23核心+3UI通过，库存/动作释放也通过。此前竞争与杆末漏球在本轮复验闭合；完整平台/持续性能边界仍见W16-device-20260914。


## DR-307 — 翻袋/反射页内 2D/3D
- **任务**：v63 W16 漏页补齐
- **日期**：2026-09-15
- **描述**：两页原共享容器写死 2D，新增页内观察切换。
- **原始规范**：SolverStageChrome 只提供俯视摆球和击球。
- **调整后**：VM 保存 cameraMode，共享 setViewingMode 仅操作相机；首次全桌，往返恢复观察。3D 隔离摆球/袋口点选/拖屏瞄准，保留击球与瞄准轮；底部观察行替代球库，透视布局与紧凑打点沿用已有组件。返回瞄准读取当前解或自由杆向；反射无目标袋选项。
- **原因**：用户要求继续补齐实际遗漏的 3D 页面，保持解/球形/参数/播放状态。
- **验证**：2模型+真机/SE4最终UI通过，32张最终截图和视觉修正复核通过；gate/doc-size/diff通过。结果及未覆盖范围见 W16-mode-coverage-20260915.md。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md § DR-307 / Changelog。

## FL-073 — 共享开球入口遗漏支架库存（2026-09-15）
- **证据**：真实 runner.breakNow 回归修前 12.742 s 红（库存空），修后模拟器 25 项绿；最终手机验证见 W17-break-rails-20260915。
- **根因**：BreakFlowRunner 未传共享库存，PositionPlay 完成交付又经 loadBoard 清库存；旧默认开球测试只验证 recorder 尾段，没有验证实际宿主交付。
- **修复**：正式回放接入、杆末提交、新架清空、三宿主取消恢复及自由击球完成保留。
- **规则改进**：跨杆状态必须检查入口→实际播放→交付→下一阶段→取消/新局，而非只检查构造 recorder 或 playback。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-073；`tasks/UI-IMPLEMENTATION-SPEC.md` § FL-073 / Changelog。

## DR-308 — 角度与瞄准球杆、延伸线与台面标注（2026-09-15）
- **用户裁定**：同时实现球杆、命中目标轮廓后虚线延伸至库边、不同切角/球距/位置的2D/3D文字避让；顶部栏不改。
- **实现**：AngleDynamicViewModel 开启 usesAdaptiveDiagramLabels。瞄准中心线按目标球 R（非母球碰撞2R）分段；AngleSceneCalculator.aimRayTargetEntry 限制前向线段。球杆拖动隐藏、松手恢复。DiagramLabelOverlay 以世界锚点投影、完整文字框、可见球、假想球/角度区域、三条辅助线及台面/视口作约束，联合选择三个标签，优先保留原候选。短线增加端点周围候选；极端拥挤时按角度/瞄准/进球优先级保留可读标签，不强行覆盖。
- **影响范围**：只开启交互式「角度与瞄准」；其他共享场景默认关闭，原3D朝向/2D恢复接口保留。上轮两个图谱球杆保留。
- **验证**：见 tasks/ui-reviews/UR-20260915-angle-diagram.md；早期候选搜索在短球距贴库漏标签，保留测试并补齐候选，未放宽完整显示断言。
- **已应用至**：tasks/UI-IMPLEMENTATION-SPEC.md § DR-308（2026-09-15）。

- **DR-308 用户追加裁定**：角度数字放两线夹角内并加角度标志，3D复用2D标志；字号收小为角度11pt/线名10pt。增加前向夹角范围及屏幕弧路径断言，窄角贴库保留实际球避让并用底托隔开线条。

DR-308 最终用户微调：角度11pt、线名10pt；角度值无阴影/无底托，保持前向夹角并沿该方向稍向外（候选从42pt开始），额外避开进球线4pt。瞄准线名改母球—假想球中段，进球线名保持贴线。此条覆盖此前底托/前半段方案。

DR-308 局部稳定性补充：用户允许小夹角放不下时侧标。角度候选限制距交点42–60pt，先尝试夹角内，再尝试同侧附近；禁止沿射线无限向外搜索。仍有效的侧标候选优先复用，夹角内可放下时恢复内部。弧保持原前向夹角，字号/无阴影/两线名中段贴线不变。新增连续1–20°的小角度变动测试；最新日志angle-local-label及angle-local-motion。

DR-308 拖动球杆实时跟随：角度与瞄准、分离角图谱、加塞吃库图谱取消dragBegan及可视化更新中的拖动隐藏条件。dragMoved已有同步几何更新，直接驱动球杆；图谱物理重算仍按原节流执行，不等待轨迹计算。无有效瞄向仍隐藏。新增三个真实ViewModel逐步拖母球/目标球、松手前验证杆位置及姿态变化的回归，见build/cue-live-drag.log。此规则覆盖之前的拖动隐藏描述。

## DR-309 — 所有相关场景共用 3D 拖球（2026-09-15）
- 用户裁定：拖球应是通用交互，应用到所有相关场景。
- 根因：共享拖球入口已有，10处页面接入以 is3D 清空可拖球集合，翻袋/颗星共用其中一处；基线实页 testAngle 拖球位移为0，断言失败留证 before.log。
- 改动：移除维度限制，保留业务球集合；透视最近可见球抓取、拖球相机隔离、终态释放、隐藏球库删除保护与说明同步。
- 已应用至：`.cursor/skills/swiftui-design-system/SKILL.md` § DR-309，`tasks/UI-IMPLEMENTATION-SPEC.md` § Changelog/DR-309，`docs/05-信息架构与交互设计.md`。
- 验证：acceptance.log中13项单测+15项UI回归通过，截图及门禁完成；见 `tasks/ui-reviews/UR-20260915-shared-3d-drag.md`。未安装真机/未提交。

DR-309 追加（用户触摸容错要求）：球心周围48pt为共享抓取容错区；点选/拖过的可移动球保持优先，近邻区域起手继续拖该球，直接命中另一颗球优先切换，点/拖空白处解除优先；单次抓取后直到松手均不切换对象。遮挡/隐藏/只读不因容错放开。

## FL-074 — 角度视频遗漏屏幕标注层与镜头过近（2026-09-15）

- **任务**：角度与瞄准竖屏视频，用户要求固定机位、保留球房环境和教学信息。
- **现象**：首轮导出静帧只有SceneKit线条，缺“瞄准线”“进球线”、角度文字/角弧；用户同时指出镜头太近。
- **根因**：把“隐藏按钮”扩大解释为精简教学信息；SCNRenderer只取场景帧，没有合成实际页面的UIKit `DiagramLabelOverlay`，且显式关闭了line labels。以球桌占画面优先替代用户要的环境空间。
- **处理**：接回生产标注层并做投影一致、3个标签均可见断言；恢复顶部指标；重新校准较远且更低的3D固定机位。用户追加指出信息框遮挡台面及右侧空白过多，2D预留独立顶部区域，框宽按最大内容计算；用户进一步要求五行纵排，采用紧凑纵向信息栏。静帧复验中，不宣称视频完成。
- **规则改进**：导出复用SceneKit不等于复用整页可视信息；开始前区分场景内节点、UIKit/SwiftUI叠层和操作控件，按用户范围保留。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-074；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

## FL-075 — 2D 角度视频球杆扫过区域残留杆色楔形（2026-09-15）

- **任务**：角度与瞄准竖屏视频六档交付后，用户在 2D 成片看到球杆扫过的区域呈杆色楔形；3D 正常。
- **现象**：楔形随角度增大而扩大，边界一侧贴当前杆身、另一侧固定；关键帧 PNG 同位置像素 alpha=0，视频同位置为杆色 (200,154,90)。
- **根因**：①合成用 `UIGraphicsImageRendererFormat.opaque = true` 但未铺底色，2D 场景台面外透明 → 合成结果背景 alpha=0；②`VideoWriter.append` 从 `CVPixelBufferPool` 取复用缓冲后直接 `context.draw`（source-over），未清空，alpha=0 区域露出该缓冲区旧帧里的球杆像素。3D 有球房背景全画面不透明所以掩盖了缺陷。
- **处理**：`VideoWriter.append` 追加前 `fill` 不透明黑；合成显式 `UIColor.black` 铺底。2D/3D 重新导出，原楔形位置像素 (0,0,0)，PNG 背景 (0,0,0,255)，`verify-angle-aiming.py` passed。
- **规则改进**：①向复用像素缓冲绘制的写入器必须先清空，不能依赖池缓冲初始为零；②视频抽帧验收要包含**场景透明区/背景区**的像素采样，并与单帧 PNG 对照——「元信息全对 + 关键对象可见」不能证明背景没有污染；③我此前用成片抽帧目视 4 帧却漏看了楔形，因为注意力只在教学主体上，验收清单须显式列「画面非主体区域」。
- **已应用至**：`.cursor/rules/55-test-engineer.mdc` § FL-075；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。

DR-308 3D圆弧贴台面：仅圆弧与端刻线改为台呢平面(surfaceY+2mm)上的XZ几何投影，随相机透视变化。沿用2D线条样式；2D圆弧及所有文字位置、朝向、字号均不改。新增3D弧起点对台面世界点投影的数值校验，日志build/angle-cloth-arc.log。

DR-308 圆弧遮挡与间距最终补充：3D用SceneKit台面平面线条并开启深度读取，关闭屏幕圆弧，球体可遮挡弧，不会覆盖球像素。半径4.5R，按用户追加要求稍离开目标球；仅圆弧改变，文字保持现状。2D仍用原屏幕圆弧。回归检查3D弧节点可见、深度开启且屏幕弧隐藏；UI转视角手势移到空白区，适配已支持3D拖球的现状。日志angle-depth-arc。

DR-309 试打修复：原生SceneKit视图不继承进场/模式切换的隐式布局动画，避免可见球桌与触摸布局偏移；transaction.log真实拖球、固定相机、2D球位留存通过。最终完整回归见共享3D拖球审查报告。

## FL-076 — 动画球的阴影参数晚一帧

- 日期：2026-09-15；用户指出球像跳起。
- 根因：MobileContactOcclusion 在渲染回调中嵌套显式 SCNTransaction，球体动画已进入当前帧，而材质 contactGroup 参数延后生效。模型/阴影参数读回一致仍不能证明GPU实际帧一致。
- 证据：SCNAction 8m/s、120Hz取13帧，最后一帧与相同时间/姿态再次渲染相比，最大通道差184；去掉嵌套事务后 <=3，5项通过，移动/停住原图已核对。flush与调整回调阶段均无效，候选日志保留。
- 修复：保留 didApplyAnimationsAtTime，在现有帧事务中直接更新变化的矩阵；不改球高、物理或回放轨迹。最终两倍平面灯下标准模拟器与iOS17各5项通过；真机最终复验见报告。
- 已应用至：`.cursor/rules/55-test-engineer.mdc` §FL-076；`tasks/UI-IMPLEMENTATION-SPEC.md` Changelog。
- 证据目录：`output/canopy-light-20260915/lag-{red,flush,willrender-r2,no-transaction}.log`，最终 `output/double-table-light-20260915/`。

## FL-077 — 序列视频误用旧离线外观（2026-09-16）
- 用户要求：高级蛇彩15球清台，逐杆瞄准，沿用现有视频风格；用户随后指出背景/灯光。
- 根因：把可复用的轨迹导出器当成完整外观模板，遗漏其mobileRendering=false与旧studioLook；未接renderer.delegate=scene.contactOcclusion。黑背景和旧材质因此进入预览。
- 改正：本片显式useAppAppearance，复用现有房间/灯光/材质；保留旧批量资产默认配置。重新生成首帧、15个瞄准帧、成片及封面。
- 规则改进建议：视频复用入口前逐项对照当前参考片的场景构建、房间、灯光、材质、相机、阴影委托；不能只检查轨迹和分辨率。求解候选还须遵守CuePhysics.miscueLimitFraction。
- 已应用至：`.cursor/rules/55-test-engineer.mdc` §FL-077（2026-09-16）。

- FL-077最终证据：export-build.log记录1测0失败；1080×1920/60fps/116.6秒成片及封面完成。verification.json编码/时序验证通过，45张实际MP4抽帧已审阅；白球旁打点盘与力度条在全部15段瞄准中呈现。

- 高级蛇彩r2用户修订：导出Options增加局部外观、FOV、透明提示、连续相机参数；观察机位按当前杆方位拟合整桌，极坐标绕台与五次缓动衔接瞄准。运动时间改整数帧推导，跨杆保持所有球朝向。静帧、前三杆转场及最终全片各1项通过；兼容回归7项通过，89张实际MP4抽帧/编码验证完成，21286帧/120fps/177.383秒。

## FL-078 — 切点辅助线平行参照误读（2026-09-16）
- 现象：将用户要求的切点辅助线画成水平；用户明确纠正为垂直。
- 根因：把“现在的线”误指向水平参考虚线，实际应平行白色竖直瞄准线。
- 修正：固定 x=contactPoint.x，端点 y 与白色瞄准线一致；红点与原水平参考线保持。
- 规则改进建议：同图多条线时，平行关系必须明确参照线的颜色、方向和作用，再用端点向量验证。
- 已应用至：`.cursor/skills/geometry-spatial-reasoning/SKILL.md` §FL-078。
