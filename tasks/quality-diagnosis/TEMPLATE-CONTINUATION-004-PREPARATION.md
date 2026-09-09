# 模版编辑、完成保存与删除后历史补证 — snapshot004

2026-09-08。**草稿未注册、未编译、未运行，不计通过。** 本子任务只写本说明与 `TemplateContinuationDiagnosticUITests.swift`，未操作模拟器/build/xcodegen/snapshot/业务或共享台账。

## 有效语义

- 数据契约 §6.5：训练记录落库时冻结所依赖内容；§9.2：今日 item 的来源名称和 payload 入队冻结，源编辑、删除不得改写队列/历史事实。
- `CustomPlanBuilderView` / `CustomPlanBuilderViewModel`：改名、添加动作、只调遍数 1...20；完整每球形剂量来自内容，用户**不能**通过正常模版编辑把 3 组强行减成 1 组。保存并加入今日走 `TodayTrainingScheduleService.addTemplate`。
- `TrainingHomeView.deleteCustomPlan`：删除 CustomPlan 和匹配的 UserActivePlan，不主动删除 TodayScheduleItem / TrainingSession。
- `TrainingDetailView` 来源按钮使用 `trainingDetail.sourceBreadcrumb`，源不在时仍显示快照名称，并标记“来源已删除”、禁用跳转；成绩卡直接渲染 entry.sets，不回查模版。
- 已有 `V54ScheduleDomainTests/test_v57_projectionReopensDiskStoreAfterTemplateDeletion` 保存队列快照后改名/改遍数/删除模版、磁盘重开验证 payload 和名称保持。它没有跑正常编辑 UI 或完成训练历史。当前新增旅程补这层，不重造另一份一样的服务层假例。

## 最小输入与预期

精确方法：`QiuJiUITests/TemplateContinuationDiagnosticUITests/testTemplateEditedDoseSavedThenDeletedKeepsHistoricalSourceAndScores`，共 **1 方法**。

为避免长动作大量填分，又不虚改内容，使用 snapshot004 `drill_c037`“走位基础”（免费）：唯一 manual01、repetition、defaultRounds 3、ballsPerRound 15。正常保存初稿 → 重开编辑 → 改名 → 通过 stepper ×1 调为 ×2 → 完整剂量为 6 组 / 90 球。六组均实际输入 5、目标字段断言 15，正常收键盘完成组、休息完成后继续，期待 6 条 5/15、总 30/90。

正常链：空史/游客前置 → 我的模版空架创建并仅保存 → 卡片真实 ID 重开 → 改名与遍数 → 保存并加入今日 → 开始这节课 → 六组计分 → 结束/跳过心得/保存 → 历史查看来源、名称、6 组及成绩 → 返回训练，按刚才实际 template UUID 打开管理菜单并确认删除 → 卡片消失 → 重开历史检查完全相同名称/剂量/成绩，来源按钮变不可导航/已删除。

不是“只创建重开”的重复测试。初稿保存是产生后续编辑对象的必要前置。首个已通过 MenuHit 用例的导航实际 frame 中心触摸复用到保存与历史返回，保留截图；普通按钮仍按可点击断言点击。

## 未验证定位风险（主控执行前需审查）

1. 当前 builder 的动作设置无专用 AX identifier；草稿用现有 `V31W5WalkthroughUITests` 的 ellipsis label/identifier 查询。仅一动作，预期唯一设置按钮。不能把旧用例“每球形轮数”文字套进当前页面；当前标题为“遍数”。
2. Stepper 增加按钮语义按系统 `Increment / 增加 / 递增` 查找；尚无本版本此弹层 AX 实测。草稿保留 ×1→×2 及总数90断言，若命名不匹配需保留首失败再读 AX 修定位，不能删剂量断言。
3. Picker 的 `searchFields.firstMatch` 对应正常 `.searchable(prompt: 搜索训练动作)`，未实测键盘/搜索完成按钮遮挡；不得用直接设置 VM 代替。
4. 历史行正常点“走位基础”，同一测试空库只有一个预期记录；删除使用从已创建卡片真实标识提取的 UUID，不猜 ID。不操作别人的模版。
5. 六组循环依赖当前键盘完成即完成本组的实际语义；绝不再点标记完成导致翻转。若第六组自动切换总结/出现不同流程，先保存 AX/录屏，按真实行为续接，不修改业务。
6. 已反查 `TrainingSummaryView.saveButtonTitle / handleSave`：保存后标题可变“完成”，但 handleSave 同时置 showSavedToast 并在 700ms 任务中 dismiss，按钮在 toast 期间禁用；这里正常保存预期自动返回，不是必需再点一次完成。草稿改为等待真实 TabBar 返回、保存训练及完成均不再存在，然后进入历史核实记录；单纯标题变化不算保存终态。若实际未返回必须取证，不做猜测性重试。
7. 最后历史 `5/15` 精确 6 条、`第7组` 不存在和总30/90是明确预期，不能为了兼容既有 QD012 放宽。本例完整完成六组，因此不应触发未完成组统计问题；若复现仍须记录。

## 隔离与交付

- 专用游客模拟器、`-v50.inMemoryStore`、`-forceNonPremium`、跟随系统外观；不用真实账号/网络、无 fixture 数据、无系统时间修改。
- 全部编辑/删除局限本次 UUID 命名模版及其唯一会话；模版删除是本条明确授权的测试动作。测试 teardown 仅关闭本次 App。
- 同进程内存库旅程，不证明杀进程重启、跨设备同步或真磁盘恢复；磁盘队列投影边界复用上述已有单测结果但须主控核查实际 run。
- 归档精确 selector、exit、xcresult、测试源 hash、每个阶段 PNG/AX。失败定位留下原结果，不计草稿为通过。
- `git diff --check` 对本说明与草稿检查无输出；未进行 Swift 编译。

## 主控审查后的准备修订（仍未编译/运行）

- 修正两处 Swift API 用法：`app.buttons.matching(identifier: "已完成").count` 和 `app.staticTexts.matching(identifier: "5/15").count`；期望均仍为 6，未减断言。
- 反查 `TodayTrainingScheduleService.addTemplate`，sourceId 为真实 template UUID；`TrainingHomeView.scheduleItemRow` 初态折叠，值“已折叠/已展开”。草稿先点精确 `trainingHome.scheduleItem.<UUID>` 展开并验证新值，再点 `.start`；该模版与课程共享待开始文案“开始这节课”。
- 模版卡、管理入口、今日条目/开始按钮与历史行点击前，检查非空 frame 完整在 window 内且 `maxY <= app.tabBars.firstMatch.frame.minY`；若被底栏遮挡则继续向上滚动。不能只凭 isHittable 真就点击落在 TabBar 的中心。主控 plan001 的误触作为定位准备证据，不归为产品删除/保存失败。
- `TrainingNoteView.onAppear` 自动聚焦，bottomBar 仅在未聚焦时显示。先正常点 `trainingNote.dismissKeyboard` 并确认 keyboard 消失再“跳过”。
- 正常保存路径自动 dismiss 的源证据已加入第6点，不以“完成”新标签替代真实返回；如实际出现不能退出需另行记录问题。
- 仍是正常 c037 每遍3组×15、×2后完整6组，全6条各5/15总30/90；无数据seed、无业务修改。
