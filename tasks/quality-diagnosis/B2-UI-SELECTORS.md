# B2 编排状态 UI 方法白名单

2026-09-05，只读审阅 snapshot-002，未执行。最多8项；均为明确fixture后的真实页面交互，**不称为从空库完整建立计划/模版的正常旅程**。

| 优先级 | 完整selector | 前置与实际断言 | 限制 |
|---|---|---|---|
| 1 | QiuJiUITests/V54ScheduleUITests/testV57TemplateBodyEditsAndMenuAddsOnce | todayState=templateOnly，两入口trainingHome/planList，主体进入编辑模版后返回；菜单首次加入→再次已在安排→首页0/1 | 只是编辑入口，不修改或保存模版字段；重复加入幂等，不是重复训练保存；4图 |
| 2 | QiuJiUITests/V54ScheduleUITests/testV57PlanShelfShowsSavedStatesAndCanSwitch | todayState=planStatuses，正常货架进入暂停计划，确认激活，CTA变编排今天，返回active/paused标签互换、已完成计划可达 | 预置三计划，未验证A→B→A游标保留；2图 |
| 3 | QiuJiUITests/V54ScheduleUITests/testV57MinimizedFreeTrainingRestoresSelection | freeCompleted基态→正常自由训练选动作→最小化→唯一恢复入口→恢复→动作选择仍完成(1) | 同进程状态，不等于重启持久化；2图 |
| 4 | QiuJiUITests/V54ScheduleUITests/testHistoryKeepsFrozenSourceWhenLiveSourceDisappears | official/deleted两独立历史fixture，冻结阶段/课程名可读，已删模版来源名保留且禁用 | 不是在同样本真实删来源再回历史；2图 |
| 5 | QiuJiUITests/V54ScheduleUITests/testV57SwitchPausedPlanUpdatesPrimaryAction | planDetail深链+planState=other，切换确认后CTA变编排今天、编排sheet加入按钮存在 | 页面状态转换，不是正常入口；2图 |
| 6 | QiuJiUITests/V54ScheduleUITests/testPlanDetailFourBusinessStatesAndComposerAccessibility | start/other/current/completed四fixture对应CTA；当前课默认选择1项、AX同时表达当前/已选择 | 其他三状态仅展示；VO标签不是实际朗读；5图 |
| 7 | QiuJiUITests/V54ScheduleUITests/testV57CompletedTrainingCanSaveAndStartFreeAgain | completed/freeCompleted两基态，正常新自由训练选动作→结束保存→已完成仍在→再次开始无旧选择 | 已在B1探索/正式运行过的同指纹证据优先引用；不是双击同次保存的幂等测试；6图 |
| 8 | QiuJiUITests/V57PracticeLibraryUITests/testPrimaryAddActionUsesTodaySheetAndDoesNotCountAsPractice | practiceCountFixture内存库，搜索厚球分离角→详情添加→今日第一次加入/第二次已在→返回已练计次仍0 | 真实详情入口在fixture宿主，不是普通Root；3图附件，无文件落盘 |

## 共用启动与输出约束

前7项的private launch每次先terminate，再 `launchClean(-forcePremium,-v50.inMemoryStore,appearance,args)`，不沿用真实训练库。截图由 `V54_SHOT_DIR` / `TEST_RUNNER_V54_SHOT_DIR` 指定并keepAlways，没有固定主workspace资源写盘；每selector独立叶目录。环境缺失会只留附件并静默不写PNG，所以主控必须预检环境并验收期望图数。第8项只有keepAlways附件，须从xcresult导出，不能要求V54_SHOT_DIR自动写盘。

`V54_APPEARANCE` / `TEST_RUNNER_V54_APPEARANCE`为dark时forceDark，否则forceLight；这里只代表显式测试覆盖，实际Root中主页面外观与深链处理差异仍应看截图核实，不以环境名当最终渲染证据。UI默认串行，独立UDID/日志/xcresult，测试资产烘焙开关保持关闭。

无登录、购买、真实权限或制作操作。fixture宿主中的SwiftData变更可留在测试内存；UserDefaults与既有launch网络行为不因此被完全隔离，专用设备依然必要。第8项宿主曾存在容器生命周期诊断历史，若当前冻结版本出现reset/backingData崩溃，保留堆栈并分类，不能用当前主工作区修复替换冻结业务输入。

## 排除与覆盖缺口

- 不整class调用：`testTodayScheduleSixStates`实际循环9态，empty仍找旧trainingHome.freeRecord；此前single断言也有失配历史。不能把早停后的其余态当已测。
- `testV57BrowseFiltersAndEmptyTemplateKeepPosition`循环“全部”多次写同文件名，且强依赖滚动锚点；本小批不纳入。
- 不执行任何截图制作runner或带旧绝对路径的P4等测试。
- 当前8项没有“模版实际字段编辑保存”、“正常新建→完整课程推进”、“真实来源删除→历史冻结”、“快速重复保存同一session的UI幂等”完整证据，需专门诊断方法或现有事务单测补齐；不得把名称中的Edits/Save当已覆盖全部行为。
- 计划切换唯一active与游标、三源队列口径由B2独立数据单测补强，截图标签不能代替数据库不变量。
