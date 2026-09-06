# 主要入口与正式证据审计

2026-09-05；冻结基线 `build/quality-diagnosis/snapshot-002`。只读审计，不执行UI、不更新覆盖总表。截止读取时 FORMAL-B3-004 已完成8/8；FORMAL-B2-003历史编辑仍在执行，不能提前计入通过。后续运行须在本表另注执行号后才提升状态。

## 口径和结论

- **操作**：正式日志证明正常入口到达，并有指定交互断言；仍仅覆盖描述的动作。
- **根页/卡片**：只有根页、卡片标题或锁定态可见；不等于进入目的页。
- **未测**：未找到本次冻结正式UI操作证据。已有单测/静态审查另记，不转成UI通过。
- **排除**：隐藏/制作入口，说明来源和副作用。
- RUN-001～004探索、旧版本历史截图、候选选择器、新写但未运行的测试均不作为正式通过。

冻结练习页真实分区为 **学 / 理 / 练 / 打 / 解**，不是“识”。卡片数为 **9 + 12 + 6 + 4 + 5 = 36**，另有1个模拟器制作卡。当前有正式正常操作证据的练习卡为 **10/36**；这只是“入口曾完成所列动作”的计数，**不是场景完成率或全App覆盖率**。尤其翻袋/反射的当前测试主要走自由模式击球再回求解，未点击下一解或遍历库数，不应概括为求解器全面通过。

来源：`QiuJi/Features/AngleTraining/Views/AngleHomeView.swift:5–233` 定义route/卡片；`QiuJi/App/MainTabView.swift:149–275` 定义实际目的视图；`TheoryCatalog.swift`提供12篇标题和published状态。下文源码路径均相对冻结根。

## 练习36卡逐项映射

所有卡同时关联SC02，设备/外观/字号另关联SC34/35。下表列功能主SC。Free/Pro标签不代表已验真实权益。

| 分区/实际标题 | route → 目的视图 | 主SC | 正式UI状态与缺口 |
|---|---|---|---|
| 学·瞄准原理 | aimingPrinciple → AimingPrincipleView | 17/20 | 根页卡片可见；目的页未测 |
| 学·瞄准方法 | aimingMethods → AimingMethodsView | 17/20 | 根页卡片可见；目的页未测 |
| 学·瞄准修正 | aimingCorrection → AimingCorrectionView | 17/20 | 根页卡片可见；目的页未测 |
| 学·旋转与加塞 | spinAndEnglish → SpinAndEnglishView | 17/20 | 根页卡片可见；目的页未测 |
| 学·角度与瞄准 | angleDynamic → AngleDynamicView | 20 | 根页卡片可见；拖球/反馈未测 |
| 学·分离角图谱（Pro） | separationAngleAtlas → SeparationAngleAtlasView | 20/32 | 根页卡片可见；底层图谱单测不代替进入/选档/轨迹操作 |
| 学·加塞吃库图谱（Pro） | cushionEnglishAtlas → CushionEnglishAtlasView | 20/32 | 根页下缘部分卡片；目的页未测，理论单测仅切片 |
| 学·浅谈球感 | ballFeel → BallFeelView | 17 | 根页下缘部分卡片；正文/展开/导流未测 |
| 学·瞄准点对照表 | contactPointTable → ContactPointTableView | 17/20 | 目的页未测；不能从root-practice图推断屏外卡已检验 |
| 理·30° 法则 | theoryPage(.t01) → TheoryT01View | 17/20 | 未测 |
| 理·90° 法则 | theoryPage(.t02) → TheoryT02View | 17/20 | 未测 |
| 理·切线法则 | theoryPage(.t03) → TheoryT03View | 17/20 | 未测 |
| 理·母球速度分级 | theoryPage(.t04) → TheoryT04View | 17/20 | 未测 |
| 理·反向规划 | theoryPage(.t05) → TheoryT05View | 17/22 | 未测 |
| 理·关键球原理 | theoryPage(.t06) → TheoryT06View | 17/22 | 未测 |
| 理·球团管理 | theoryPage(.t07) → TheoryT07View | 17/22 | 未测 |
| 理·风险报酬决策矩阵 | theoryPage(.t08) → TheoryT08View | 17/22 | 未测 |
| 理·最少加塞原则 | theoryPage(.t09) → TheoryT09View | 17/20 | 未测 |
| 理·安全球三维度模型 | theoryPage(.t10) → TheoryT10View | 17/22 | 未测 |
| 理·清台 5 步决策流程 | theoryPage(.flow) → TheoryFlowView | 17/22 | 未测 |
| 理·清台速查手册 | theoryPage(.quickRef) → TheoryQuickRefView | 17 | 未测 |
| 练·角度预测 | geometricQuiz → GeometricAngleQuizView | 19 | **操作 B3-003**：17/28/39三次答案→结束→记录中三题对应；同进程内存，未验磁盘/取消/重复结束 |
| 练·2D 角度训练 | sceneAiming2D → SceneAimingView(topDown2DRotated) | 19 | **操作 B3-004**：答题→反馈→下一题→返回；完整成绩保存/中断未测 |
| 练·3D 角度训练（Pro） | sceneAiming3D → SceneAimingView(perspective3D) | 19/32 | **操作 B3-004**：答题→反馈→下一题→返回；forcedPro，不证明真实权益 |
| 练·瞄准点训练 | aimPointTraining → AimPointTrainingView | 19 | **操作 B3-004**：提交初始瞄准点→反馈→下一题；未实际拖动改变位置，未完整保存 |
| 练·2D 瞄准点训练 | aimPointScene2D → AimPointSceneTrainingView(topDown2DRotated) | 19 | **操作 B3-004**：提交→自动击球验证→下一题；未主动调线/剂量矩阵/完整保存 |
| 练·3D 瞄准点训练（Pro） | aimPointScene3D → AimPointSceneTrainingView(perspective3D) | 19/32 | **操作 B3-004**：提交→自动验证→下一题；forcedPro，其他同上 |
| 打·分离角与走位 | shotSimulation → ShotSimulationView | 20/28 | **操作 B3-004**：初始盘击球→回放→重打→返回；未主动改变力度打点，未听音效 |
| 打·自由走位（Pro） | positionPlayComposer → PositionPlayComposerView | 21 | 未测；AdvancedTool草稿不算执行 |
| 打·自由击球 | freePlay → FreePlayView | 21/28 | **操作 B3-004**：默认初始盘击球→回放→重打→返回；未换玩法/开完整局/球库摆球/全局规则 |
| 打·拍照建球形（Pro） | ballExtraction → BallExtractionView | 27 | 未测UI；Homography/InfoPlist单测仅几何与声明 |
| 解·思路训练 | positionPlaySolver → SiluTrainerView | 22 | 未测UI；典型求解单测不能充当正常入口操作 |
| 解·打一走二想三（Pro） | planThree → PlanThreeView | 22 | 未测UI；AdvancedTool草稿不算执行 |
| 解·防守（Pro） | snookerTactics → SnookerTacticsView | 22 | 未测UI；底层snooker切片不等于遮挡编辑/下一解/无解 |
| 解·翻袋解球器 | bankShot → BankShotView | 20 | **操作 B3-003**：求解模式→自由→击球→上一杆→求解→返回；只断言下一解按钮存在，**未点击下一解，未切1/2/3库，未选袋、构造无解** |
| 解·反射解球器 | diamondSystem → DiamondSystemView | 20 | **操作 B3-004**：同翻袋模式流程；未点击下一解/遍历库数/理想真实/无解 |

其他路由与横切入口：

| 入口 | 定位与处理 |
|---|---|
| theoryIndex → TheoryIndexView | 首页已取消总卡，仅深链等调用路径保留；不是第37个正常卡。索引跳页未测，若正式IA不使用可单列兼容入口 |
| drillDetail(String) → DrillDetailView | 学/理页导流用例须从对应CTA操作，不能借动作库c012通过推定所有导流route正确 |
| batchDrillStudio → BatchDrillStudioView | 制作入口排除：会生产资产。条件为 `targetEnvironment(simulator)`，**不是 DEBUG**；Release模拟器仍可能显示，真机分支EmptyView。不能以模拟器Release可见直接认定真机泄漏 |
| 练习搜索/主题筛选/全部/学/理/练/打/解 | 分类“练/打/解”在工具入场时实际使用；搜索/主题交集/无结果/清除筛选/恢复滚动位置未测 |

## 训练、动作库、记录、我的二级入口

| 主入口/动作 | 目的与主SC | 正式UI证据 / 尚缺 |
|---|---|---|
| 训练根页 | TrainingHomeView；02/03 | B3-002根页截图；不证明空态所有CTA可用 |
| 自由训练→选择动作→训练→保存 | ActiveTrainingView/DrillPicker/结束心得；05/09 | B1-003、B2-002正常c012单动作部分完成、跳过心得、保存后重启备注；QD012完成组/历史分母差异确认。选择多动作、撤回、保存失败重试未测 |
| 官方计划列表 | TrainingRoute.planList → PlanListView；04 | 未测正常UI；B2相关单测仅服务/容器 |
| 官方计划详情/启用/切换/课程 | planDetail → PlanDetailView；04/07 | 未测正常UI；A→B→A、选课/加入今日、复练/预习待补 |
| 今日安排/官方建议/加入并开始/排序删除 | TrainingHomeView服务动作；06/07 | 未测正常UI；源码按钮存在、候选V54测试不算执行 |
| 今日动作详情/已完成训练详情 | drillDetail或historySelection→TrainingDetailView；06/12/18 | 未从首页对应行实际进入；动作库同页不替代源入口 |
| 模版列表/新建/编辑/删除/加入今日 | customPlanBuilder/customPlanEdit；08 | 未测正常UI；旧Builder单测通过不等于当前模版产品规则验收 |
| 每日清台 | dailyClearance → FreePlayView(entryMode:.dailyClearance)；23 | 未测本次正常UI；普通FreePlay通过不替代每日草稿/日期状态 |
| 暂停/休息/加时/缩小恢复/后台 | ActiveTraining/MinimizedTrainingChrome；10/38 | 当前旅程用“结束休息”前进，但未做时长独立核算；缩小/后台/LiveActivity未测 |
| 动作库根页/搜索 | DrillListView；16 | B3-002搜索“中袋直线出杆”定位c012并返回；空查询/无结果/组合分类与球种未测 |
| 动作详情与球形试打 | DrillDetailView→DrillTryoutView；18 | B3-002 c012入详情、3秒渲染、试打、返回列表；不等于完整试打击球或多球形不串图 |
| 精讲详情/步骤展开 | DrillTutorialView；17/18 | 未测正常UI；CONTENT-SAMPLE是12课静态/20图目视，不能当App正文交互 |
| 多球形选择sheet | formationPicker；18 | 测试有“若出现则选择”分支，但当前执行日志须证明实际发生才计；不据源码可选分支算已测 |
| 收藏/加入今日/加入模版/付费详情门控 | Detail 收藏与showAddToTraining/showSubscription；16/06/08/32 | 正常UI未测；未核对收藏磁盘重启/owner归属 |
| 记录根页/今日训练记录→详情 | HistoryCalendarView→TrainingDetailView；12 | B3-002根页；B1-003/B2-002真实备注重启及训练详情；切月份、空日、窗口门控尚未覆盖 |
| 记录→认知成绩详情 | AngleSessionDetailView；19 | B3-003角度预测3题答值对应；同进程内存，其他五题型未完整保存 |
| 历史详情编辑/删除/无效输入 | TrainingDataEditorView；12 | B2-003审计截止仍执行中，仅记录状态；不得据新测试源码提前算通过 |
| 记录→统计→周/月/年及分类 | StatisticsView；13 | UI未测。B2 Statistics单测已跑，QD012统计口径有源码证据，但统计屏幕尚未实测 |
| 我的根页/游客登录卡 | ProfileView；02/29 | B3-002根页及游客卡可见；未点登录完成身份切换 |
| 我的→登录sheet/Apple/微信/退出 | LoginView、AuthState；29/25 | UI/真实账号未测；B4隔离Auth单测不替代系统登录 |
| 我的→个人信息/头像 | personalInfo→PersonalInfoView；30 | UI未测；B4 Profile替身断言不替代输入取消/照片权限/头像实际显示 |
| 我的→收藏 | favorites→FavoriteDrillsView；16 | 未测UI；入口在登录态权限下是否与游客一致需实际验证 |
| 我的→训练目标 | trainingGoal→TrainingGoalView；14/38 | 未测UI；保存偏好/通知弹框/重进未测 |
| 我的→会员状态/解锁Pro | subscriptionStatus→SubscriptionStatusView / SubscriptionView；32/33 | 正常入口未测；B3-002仅深链forcedFree/Pro门控，不是正常订阅购买/恢复 |
| 我的→设置 | settings→SettingsView；14/28/31/38 | 未测UI；外观、声音、每日默认玩法、90°辅助线、缓存清理、注销及失败弹层均需分别记录 |
| 我的→关于 | about→AboutView；31 | 未测UI；反馈/好评/用户协议/隐私政策入口未操作；外发评价/反馈不属于本机诊断授权自动发送范围 |

## 证据复核及补测顺序

审计读过 `EXECUTIONS.md` / `B4.md` / 当前诊断测试源码，直接核对B3-002/003/004原始日志的passed/failed行和截图路径；**没有把源码中的未执行分支当执行记录**。独立重新打开两张截图：B3-002 `root-practice.png`，确认首屏为学区卡片而不是36目的页；B3-003 `testBankSolverModeStrikeUndoReturn…returned-to-solve…png`，确认回到求解态，画面显示1库/解1/2，但该图不证明曾点下一解或独立验证线路几何。其余截图仅核对文件存在和主控已写审查范围，本审计未重新逐图审美验收。

优先建议：

1. **补学9页、理12页正常卡片→目的页→一个明确交互/展开或滚动到关键末段→返回**，每页固定证据名；只有标题可见时仍标“目的页标题”，不宣称内容已验。总计21页，适合一次受控巡游后逐图审查。
2. 补自由走位/思路/三球/防守4卡（已有独立草稿，待实际运行）；翻袋/反射另补选袋/库数/下一解/无解，不重复仅切模式。
3. 正常训练计划/模版/今日编排/每日清台、动作收藏与加入、统计及设置/目标/关于优先于再扩大同类单测数量。可用fixture建立必要历史，但要把“fixture抵达页面”与“正常入口建数据”分开。
4. 拍照权限/照片选择可在无私人素材的新模拟器验证；真机摄像/真实购买/账号恢复保留条件缺口。执行不能串到制作工具或真实账号注销。

文档中的“未测”是截止此审计的**正式UI证据缺口**，并非断言功能有缺陷。全部38个SC还包含数据、失败、设备与内容维度，入口清单收齐仍不等于方案全部完成。
