# 正常计划与模版诊断（snapshot004）

2026-09-08。两类草稿已主控全文审阅，正常入口、内存库，计划使用forcePremium、空模版创建使用forceNonPremium；不代表真实权益或跨进程保存。当前仅验证激活/编排/开始和正常新建保存重开两个最小链，未覆盖课程成绩推进、模版编辑删除历史冻结、三源连续排序等剩余子项。

formal-004-plan-template-001选2个精确方法：TrainingJourneyDiagnosticUITests/testNormalOfficialPlanActivationArrangementAndStart、MenuHitDiagnosticUITests/testTemplateEmptyShelfCreateSaveAndReopen。独立注册仅8行新增，custom memory host scheme保留，overlay见archive/quality-diagnosis/snapshot-004/overlays/plan-template-001。专用iPhone17Pro/iOS26.2，执行中不预报通过。

独立子任务同步只读核对计时状态与休息裁定，准备正常计时诊断，不修改业务实现；计划/模版结果失败先记录，不用变更业务来让测试通过。

## 第一批实际结果

formal-004-plan-template-001：2 方法，1 通过 / 1 失败，make exit 2 / xcode exit 65。模版方法44.408秒通过；计划方法28.058秒在首页错误预期0 / 1处失败。首课JSON明确包含drill_c012、drill_c009两动作，首页计数是动作而编排计数是课程，实际视频26秒帧显示0 / 2动作。此项分类为测试口径不符，不计产品缺陷，原方法/失败保持。原始xcresult与1272个证据文件已归档至archive/quality-diagnosis/runs/formal-004-plan-template-001。

主控实际目视模版空态、新建保存前、保存后重开3图：唯一名称诊断模版A5440F60、中袋直线出杆、8×15均前后对应；截图重开页标题为编辑模版。空态新建入口需滚动露出，首张图中下缘尚有遮盖，不据此断言不可点。该通过仅覆盖同一进程内存库正常创建重开，不代表磁盘重启或改删历史冻结。

补测formal-004-plan-followup-002使用新增独立方法，保留编排1项断言，首页明确2动作，并核对默认折叠、展开后两个动作、正常开始训练。依据冻结plan_beginner.stage01.lesson01和真实首页；不改产品实现、不重复已通过模版用例。当前执行中。

2026-09-08计划/模版续接：plan-template001终态1通过1测试口径失配已归档；plan-followup002终态0通过1定位失配已归档（实际AX课程标题为“基本功 · 第 1 课”，空格不同）。首页0 / 2动作已验证；新方法使用实际稳定ID trainingHome.scheduleItem.plan_beginner.stage01.lesson01，保留前两失败方法。formal-004-plan-timer-003现运行精确2方法（计划展开开始、正常计时旅程）；独立Timer类注册仅4新增行，自定义memory scheme字节恢复。见PLAN-TEMPLATE-004-RESULT.md、TIMER-004-PREPARATION.md。禁止并行操作专用UI设备。

## 最终补验终态

formal-004-plan-timer-003两方法2/2通过（make0 / xcode0，126.465秒）。计划testNormalOfficialPlanObservedLessonIdentifierAndStart为34.580秒，通过实际ID展开首课后进入训练页。主控目视展开页与训练页：首页0 / 2动作，首项8组120球、次项7组105球；训练页基本功、1/2与相同两个动作/剂量对应。此项只证明激活→编排加入→展开→进入训练，不证明已完成课程/保存成绩/推进下一课。原001数字口径失败和002标签空格定位失败均保留，不误归为产品缺陷。

三run均终态归档；003真实xcresult Test-QiuJi-2026.09.08_11-23-42-+0800.xcresult及1312文件归档在archive/quality-diagnosis/runs/formal-004-plan-timer-003。模版创建重开与计划开始链获得局部有效证据；连续课程完成/切计划保留游标、模版编辑删除/历史冻结、三源队列仍待。
