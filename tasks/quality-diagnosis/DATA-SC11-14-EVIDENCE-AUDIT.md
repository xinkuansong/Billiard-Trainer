# SC11–14 数据证据核销审核

2026-09-08，QA/Test Engineer。只读核原计划、结果卡、实际测试断言与现存归档，只新增本文；未写/运行新测试，未改共享台账或业务。

**结论：已有混合账本、千场、编辑删除和统计计算证据应继续复用；最小新增重点是删除后的跨页自动刷新、真实历史切月/空日，以及每周目标实际改值与持久保持。不要重建千场、重录整套历史编辑，或反复复现QD012/022。**

## 原约定与证据等级

COVERAGE-PLAN：SC11按entry计次、同动作多entry、删除/未保存/1000条；SC12切月选日/详情/备注编辑删除/空日及刷新；SC13三kind与单位、自然月/滚动区间、跨日去重；SC14同日多场仅一天、tool排除、修改目标、账号/设备偏好边界。

旧snapshot002/003的B2、DATA1、千场原run目录目前不可在原build或现archive/runs重读。历史结果文档、选择器、现存测试源码仍在；**历史已执行结论保留并标原件不可重核，不能改成没测过，也不能称当前原始图/日志可打开**。本次检索004归档实际Test Case终态，未找到这些历史History/Statistics/CrossData方法新一轮通过证据；文件名出现在编译命令不算运行。

当前004可打开的相关新证据包括template-continuation007和完整课程continuation002；不自动把这些局部通过扩张为整个SC11–14通过。COVERAGE-STATUS.csv里“千场UI未验”等旧句与后附DATA1/千场结果并存，应按实际追加终态解读，不据旧句重复启动。

## 可复用的实际方法与覆盖

### 1. SC11 entry计次与规模

- 历史B2-007 `QiuJiTests/CrossDataDiagnosticTests/testCrossKindMultipleSessionsRollingWeekAgainstLiteralLedger`：两条同日drill同动作+昨日cognitive+tool99分钟+第6日前drill；独立预期4训练场、3天65分3组、准确率10/15，今日history3行/2训练行，动作a计2次。是模型/计算投影，不是UI刷新。
- 历史B2-007 `.../testThousandPersistedSessionsIndependentCounts`：内存真实SwiftData 1000场（500drill/250cognitive/250tool），训练750场、1天1750分、500组、50%、动作500次、历史1000行。B2记4/4 make0、0.291秒，包含另一个刻画方法，不能四条都计产品符合预期。
- snapshot003 DATA1的 `Data1September7UITests/testNormalGuestHomeTodayHistoryAndEntryCount`（UI001失败53.102秒，工具静态行误当Button），已完成的首页1/3、连续2天及c001已练6次保留；`testStaticToolHistoryAndTwoEntryRecordReadback`（UI002 1/1、34.089秒、make0）补静态D99分钟、A的8/10和2/5、返回首页。A同session有两entry，跨5场drill合计6entry，不是按session或Bool计次。
- `ThousandHistoryUIDiagnosticUITests/testNormalHistorySamplesAfterScrollingAndStatisticsTotals`历史UI001失败439.125秒：999/978两条8/10及唯一note、总1天2000分1000组已到达；失败是“1,000组”格式。`testLocalizedStatisticsGroupCountAndReturnToHistory` UI002通过121.968秒，80%、8000/10000球、1,000组、返回历史，已补足该局部，不再滚动重测千条。
- B2-006已选 `QiuJiUITests/V57PracticeLibraryUITests/testPrimaryAddActionUsesTodaySheetAndDoesNotCountAsPractice`：专用内存动作库fixture，第一次加入今日/再次已在安排、返回计次仍0。可核销“加入安排不等于已练”的局部，不证明普通Root所有未保存退出。

现存可复用但**本次没有找到实际通过终态**的精确方法，不能仅因代码存在核销：`QiuJiTests/V57PracticeCountTests/`（实际文件DrillListViewModelTests.swift）下的
`testTwoSavedEntriesForSameDrillInOneSessionCountTwice`（saved+saved去重）、`testSameEntryIdentityDoesNotCountTwice`、`testSetsDoNotIncreasePracticeCount`、`testLargeCountsAndZero`（0/1/2/10/100/1000 entry）、`testOneToTwoPublishesEvenWhenDrillIDSetIsUnchanged`、`testOwnerSwitchReplacesCountsAndDeletionRefreshesThem`、`testCountsSurviveClosingAndReopeningTheSavedStore`。

尤其OwnerSwitch方法：内存A2/B1→切B1→删除A一个entry后显式fetch并vm.update→A1→删A session后再次显式update→空。它可作有界删除/owner计算对照，**显式调用update不证明界面会自动收到删除刷新**，不能替代最小跨页UI观察。

### 2. SC12 历史编辑、删除、来源保持与日历

- `QiuJiUITests/QualityDiagnosticUITests/testHistoryEditCancelSaveRejectAndDeleteOwnSample`：B2-003/004为取消控件定位失配，B2-005 1/1、152.929秒、make0。实际读源码：改分母9/进球7/150秒取消→重开旧值；再改保存→正常进程重启读回；99>9拒绝保存且草稿保持；取消删除保留；确认删除后回历史、不再见独特marker；重启无该记录。历史SQLite旁证目标无残留、孤立entry/set0、此前两条样本逐字段未变。
- 该方法**并未在删除后检查首页训练日、动作库计次或统计数值减少**；详情关闭+marker消失是历史页面局部刷新，不是全App数据刷新。它还不等于编辑备注正文：实际修改是组成绩与时长，唯一note用于定位。
- `QiuJiTests/LocalTrainingSessionRepositoryTests/test_delete_removesPersistedEntriesAndSets`、V29W2b编辑校验方法在B2-001明确选中且历史全171通过，可复用级联删除/数据编辑规则；不重新做一次完全同样的编辑旅程。
- `QiuJiTests/HistoryViewModelTests/test_selectedDateSessions_filters_by_selected_date`：当日2条、昨日1条，赋值selectedDate后过滤2条；`test_previousMonth`/`test_nextMonth`/`test_previousMonth_then_nextMonth_returns_to_same`仅核currentMonth月偏移/返回年月；`test_loadSessions_empty_database`核空库数组和loading结束。这些均在B2-001历史通过名单；**没有真实UI点月箭头和有数据/无数据日的完整链**。空数据库也不是有数据库内选空日。
- 004 `QiuJiUITests/TemplateContinuationDiagnosticUITests/testTemplateEditedDoseSavedThenDeletedKeepsHistoricalSourceAndScores`：template007实际日志1/1 passed，3487.563秒；归档tested-source/日志/图/AX/xcresult现存。6组30/90及原模版名，正常删除模版后仍可读历史、来源按钮disabled。这是删**来源模版**，不是删**历史记录**；不能用来核销删除记录后的聚合刷新。

备注初次保存/重启读回有CURRENT-JOURNEY-RESULT与认知004磁盘链可交叉引用，但本次未重新审核后者全部方法；若SC12最终要求“已有记录备注实际编辑”，需区分初次保存备注与修改已有备注，不能用原数据编辑方法的名字推断。

### 3. SC13 统计范围、kind与单位

- DATA1 `Data1September7UITests/testNormalGuestStatisticsRangeValuesAndProfileBoundary`历史UI001通过118.396秒：绑定真实标题和对应数字，滚动周3天65分4组、月4天105分5组、年5天185分6组；工具99分钟不计入，游客无登录月卡。7条固定账本在真实磁盘，1认知题、6entry/6set、队列0。不是7场正常UI输入，也没遍历B/C/E/F/G每条详情。
- B2-007 `CrossDataDiagnosticTests/testNaturalMonthAndCalendarWeekUseLiteralBoundaryLedger`：固定UTC，8/31及10/1排除在9月自然月外，同日两场仅一天、tool排除；自然月3天65分最长2天，截至9/5自然周4天。预期字面账本独立，不能把这个自然月口径与统计滚动月混为一谈。
- B2-001 `StatisticsViewModelTests/test_monthlyOverview_usesCalendarMonthAndTrainingKinds`实际独立9条账本→5天125分/2h5m、最长3天；`test_monthlyOverview_longestStreakDoesNotCrossMonthBoundary`8/30–9/2中仅9/1–2算2天。可按历史证据核销自然月kind过滤/日去重/边界。
- B2-001 `V29W6HistoryStatisticsKindTests/test_categoryRate_isSumRatio_notAverageOfSetRatios`、`test_addingToolSession_leavesEveryAggregateUnchanged`等已在精确历史名单；不需要为了SC13再重复全类。旧月4箱/年12箱断言仅刻画旧形态，不自动满足后续规格的完整分箱。
- `CrossDataDiagnosticTests/testCharacterizeMixedUnitsAndUnfinishedPlannedSetsNotAcceptance`明确是刻画9/82球+局混合及未操作组信息损失，不能视为单位正确通过。QD012、QD022已有诊断：保留影响与历史证据限制，不为本审核要求再次制造同一失败。

### 4. SC14 目标与偏好

- 同日多场只一天、drill+cognitive计日而tool不计已有DATA1/CrossData与 `V29W6HistoryStatisticsKindTests/test_weeklyGoal_excludesToolSessions`（明确3种各一天→2训练日）历史通过，可核销计算规则。
- 当前 `SystemBoundaryDiagnosticUITests`多次进入“训练目标”测试的是通知开关、权限/提醒时间；**没有点击每周天数选项**，不能把通知测试通过计作目标改值通过。
- 源 `TrainingGoalView.weeklyGoalSection`实际1…7天Button调用 `OwnerProfileStore.setWeeklyGoalDays`；不是Stepper。没有稳定weeklyGoal identifier，后续UI需按实际按钮与顶部分母取证，不要求只读数字hittable或凭checkmark不可见就猜选中。
- 现存 `V53ProfilePreferencesTests/testLegacyGlobalProfileMigratesOnlyToDeviceGuest`明确旧weeklyGoalDays6→设备guest6、账号A默认3、全局key移除；`testGuestProfilesAreSeparatedByOwner`实际只改显示名，不是目标隔离。`ProfileContractTests`JSON字段5只是序列化契约，不是目标保存/服务失败回退。这些代码可复用，但本次未找到相关目标方法新旧可核实执行终态，不把源码当实测。

## 最小必要补证（避免无限矩阵）

**A：一个小账本历史/刷新链，替代重复七场或千场。** 独立诊断库只需3条带唯一标记的drill记录：当日A两entry、当日B一entry、上月C一entry（均同一明确drill，每entry一组，成绩/球单位固定并逐条列入独立预期表）。正常历史上一月→C对应日/详情→本月A/B→选一个明确空日显示当日空态→回有数据日。编辑A的已有备注并重开读回可并入，前提当前UI确有该入口并先核真实源，不猜按钮。确认删除A后，本月只剩B、A marker消失；同进程返回动作库计次4→2，训练日当天仍1（B仍在），统计相同范围组/成绩按独立账本减少，C保持。只删除本次新建A，留B作不误删对照。可在末尾一次进程重启验证一致，不再完整重复7/9/150非法编辑链。

这条同时补SC11删除自动刷新、SC12真实日历/空日与既有备注编辑、SC13删除后读侧更新；注意自然周与上月C可能跨界，执行方案应在实际日期固定预期，不能照抄2026-09-07过期DATA1脚本。无需为了跨月等到下月，允许既有受控磁盘播种流程，但不能将合成记录称为正常用户录入。

**B：一个正常guest目标修改链。** 在同一专用guest环境正常进入训练目标，将原3天改5天，核顶部/首页分母更新、已有训练日分子与记录数不变；返回重进及一次正常进程重启仍5。若使用A的同日B，独立预期保持1/5；不需要1…7每值、Light/Dark每组合都重测。失败须记录实际存续与提示，不改变记录日期或统计让它通过。

**C：仅在最终仍无owner目标证据时，一条隔离服务对照。** 复用OwnerProfileStore与既有替身backend/独立UserDefaults，验证A目标改值后切B/guest各自值、失败不展示假成功。真实账户服务保存与第二物理设备恢复仍单列指定账号/真实服务边界；无需现在建立完整多设备全组合，也不能由guest本机重启推断跨设备同步正确。A/B是主要UI缺口，C不应扩成新大范围账号工程。

若主控只要求可打开的当前原件，对历史数据方法做证据恢复性补录应选最少精确方法；不把它们重命名成“以前未测”。优先新A/B真正新增行为，而不是再次1000条、DATA1全部截图、QD012或QD022同质失败。

## 核销建议

- 可按现有历史结论复用：多entry/同日去重、kind排除、独立周/月账本、千场局部读回、历史编辑校验/取消/确认删除/重启、来源删除后历史保持（此项004原件现存）。
- 真正仍缺：正常历史切月选空日链、删除后的跨页自动刷新、目标实际修改重进/重启；已有记录备注修改与owner目标隔离需按上述精确边界补，不能由相近测试名代替。
- 已知问题不等待修复即可形成诊断：QD012/022及template007发现的时间显示问题按已有报告关联，不重复复现。
- 本审核不是SC11–14全部通过声明，未更改共享状态；同时保留“历史已测但原件不可重核”和“行为本身仍缺”的两种限制。
