# 权益与头像004剩余补验准备

2026-09-08。Test Engineer独立只读审计，范围为REMAINING-PRIORITIES-004包6。只写本文；未联网、操作设备、创建账号、运行测试或修改生产/共享台账。以下新方法名均为建议合同，尚无实现/注册/通过，不把selector建议写成可直接选跑事实。

## 可以复用的实际结果

| 类别 | 已有结果/原件 | 可以核销与保留边界 |
|---|---|---|
| 付款取消 | STOREKIT-004-RESULT：formal-004-storekit-cancellation-001取消批1/1 38.607s；本次确认同名归档目录存在 | 实际本地Xcode付款弹框取消→Free、成功交易0；不用再跑取消 |
| Pending批准 | formal-004-storekit-pending-001，1/1 77.775s，1393文件 | 同transaction id0 pending保持Free→批准同进程Pro→分离角图谱轨迹开关成功；QD025文案矛盾保留。只证明图谱类别，不代付费动作/计划 |
| 正常购买重启恢复 | formal-004-storekit-restore-001，1/1 75.497s、113文件 | 月度正常UI购买、PID变化后Pro；sync注入失败既有Pro保持、清nil恢复成功；同id0未重复购买。无需再次跑恢复 |
| 购买错误重试 | recovery001失败188.331s；L1-002与L2均清nil后第二次失败，绕开UI/manager仍复现 | 不是已成功重试，亦非已证实真实Apple商店缺陷；停止同质SDK细分，不强行追绿 |
| 商品空集合重试 | catalog001整项失败41.513s；错误预期catch未命中，实际empty→重试三商品恢复、交易0等局部成立 | loaded.isEmpty有实证，catch/超时另缺。不得用预设截图名或末尾0tests算成功 |
| 固定离线账号 | ACCOUNT-FAILURE-004-RESULT：formal-004-account-failure-004，1/1 102.984s、123文件 | 昵称失败保旧、注销确认取消/失败重试身份保持、退出与去fixture重启游客。未验头像，不重复整账号链 |
| 本地动作库 | LIBRARY-004-RESULT及LIBRARY-BOUNDARY-004-RESULT | 空搜索恢复、9球过滤c009/c012字面集合、重置保查询、收藏/取消两次磁盘重启。过滤ballType不是category；跨owner复用原隔离测试，不能声称所有分类已验 |
| owner/迟到响应/队列 | CURRENT-SYNC-RESULT：003独立三进程14/14；ACCOUNT-OFFLINE-004-EVIDENCE-AUDIT列精确旧B4/B2方法 | 下载中关闭、A恢复晚到B、游客迁移选择/幂等、当前owner队列、旧权益不复活均有U/P证据；上传在途失败和ABA仍不在这些成功结论内 |

原始004材料均位于archive/quality-diagnosis/runs的相应run；本次阅读结果文档和源码，不重新图审/解包全部xcresult。旧B4/003的原件可用性沿EVIDENCE-AVAILABILITY边界，不把历史已跑改成未跑。

## 实际生产入口与必要前置

以下路径相对archive/quality-diagnosis/snapshot-004/source/QiuJi/。

- Data/Services/SubscriptionManager.swift：只有authenticated session（或明确Debug force）允许Pro；checkEntitlements依真实StoreKitService.currentEntitlements刷新，Transaction.updates监听后再次检查。forceNonPremium/forcePremium会短路真实权益，故到期验收两者都不能带。authenticatedProfileFixture是资料身份与API固定离线，不是真实Apple身份；本地SKTestSession独立证明交易层。
- Resources/Drills/positioning/drill_c039.json：直线球组合走位，isPremium=true/category=positioning。DrillDetailView.isLocked依据drill.isPremium && !manager.isPremium，锁态unlockProButton；Pro才有bottomTryoutButton正常入口。不能仅检查徽章。
- Resources/Plans/plan_positioning.json：走位Ⅰ·短距到一库，isPremium=true。PlanDetailView固定按钮Free为“解锁此计划”，Pro为planDetail.primaryCTA；免费仅展示第一stage及渐进锁，Pro展示全stage。正常点Pro CTA应出现真实激活确认/安排页，不能只exists就算可用。不要执行整课或制造不必要训练记录。
- Features/AngleTraining/Views/AngleHomeView.swift：selectEntry在entry.isPremium且非Pro时弹订阅，不进入destination。代表高级工具可用“自由走位”（打），或复用已实证“分离角图谱”（学）；必须以真实导航页与一个无保存的控制动作证明进入，不能用卡牌锁图标。
- Features/AngleTraining/AngleUsageLimiter.swift：当前dailyLimit=20，共享单例；recordQuestion累计并存当日偏好，isLimitReached为!isPremium && count>=20。UI -w7.forceDailyLimitNear初始化19，不是正常答了19题。跨日仅init重置，不能凭现有测试推断同进程午夜实时重置。
- Features/Profile/Views/ProfileView.swift：已登录profile.accountHeader正常进“个人信息”。PersonalInfoView.personalInfo.avatarPicker为PhotosPicker，preparePhoto后呈AvatarCropView。真实裁切title“裁切头像”、slider avatarCrop.zoom、“取消”仅dismiss、“使用”调用save。错误alert“个人资料未保存”/“知道了”。ProfileAvatarView有“默认头像”/“用户头像”可观察label。
- Data/Services/AvatarStore.swift：save先预览，authenticated backend失败恢复previous；同owner时写error、finally恢复idle。fixture默认avatarRevision=nil，因此UI可验证回滚到默认头像，不能声称验证旧服务器revision图像像素保持。后者已有V53ProfilePreferencesTests/testAvatarUploadUpdatesRevisionAndFailureRollsBackPreview：真实AvatarStore、红图成功revision2、蓝图失败后pngData等于原值；迟到A上传不得覆盖B另有testLateAvatarUploadFromADoesNotOverwriteLoadedAvatarForB。

## 每缺类别最多一条最小补验

### A 三类门控与到期：一个新UI方法

建议selector：QiuJiUITests/EntitlementBoundaryDiagnosticUITests/testLocalMonthlyUnlocksThreeCategoriesAndExpiryRelocksWithoutRestart（待编写）。

新专用无真实凭据设备，显式UDID相等guard、独立输出叶目录；authenticatedProfileFixture+inMemory，resetDebugPremium而不force权益。按已审Restore001初始化本地Products.storekit，error注入全部nil、askToBuy=false、timeRate realtime、初始交易/权益0、身份确为服务端球友。沿正常入口先Free分别访问c039、plan_positioning和一个高级工具，点锁入口均进入subscription而无付费目标可操作；关闭返回。c039搜索可顺便选“走位”category，按真实catalog候选ID预先计算字面集合再比较，不扩大筛选矩阵。

正常月度UI购买一次，guard恰一purchased及实际Pro。同进程重新正常进入三个目标：c039实际试打页/重打入口后返回；plan_positioning正常CTA打开真实确认/安排页后取消，不需完成课；高级工具导航后一个可逆控制再返回。随后同session调用已在本机旧V53方法体使用的expireSubscription(productIdentifier: StoreKitService.monthlyID)，先保留交易/entitlement原件，等待有效权益消失及profile Free，再重新访问三入口均被拦截。不得在过期后重启/forceNonPremium冒充实时收回；若事件未刷新，先记录“本地到期UI未收回”，可另读服务层判别但不删除原断言。

可复用代码而不能整方法照跑：StoreKitPendingDiagnosticUITests/testAskToBuyStaysFreeUntilApprovalThenUnlocksAtlasWithoutRestart的身份/订阅/图谱helper；StoreKitRestoreDiagnosticUITests的严格本地session/交易证据；V53ProfilePreferencesTests/testStoreKitLocalSubscriptionsPurchaseAndExpire已有API购买→expire→service entitlement消失→年购，不证明正常App门控。旧XV313PremiumPlanWalkthroughUITests用forcePremium，不替代此真实本地权益链。

### B 当前额度：一个近满额UI方法

建议selector：QiuJiUITests/EntitlementBoundaryDiagnosticUITests/testLastFreeQuestionBlocksNextThenLocalPremiumBypassesQuota（待编写）。独立设备/偏好，-w7.forceDailyLimitNear明确是19题受控前置；Free正常进入一个免费2D题型，读取剩1，真实提交一题→“今日免费次数已用完”，下一题拦截且不得新建第21个答题结果；同一进程正常本地月购后，同一入口可再实际提交一次。只此代表题型，不重复六题型存储测试；若A/B共享同一购买session实现串联，必须在A到期前做B的Pro阶段，保持各oracle及标记。

现有直接可引用U选择器：QiuJiTests/AngleUsageLimiterTests/test_dailyLimit_is20、test_limitReached_at20、test_premium_bypassesLimit、test_sameDay_restoresCount、test_dateReset_clearsPreviousDayCount（源码AngleTrainingTests.swift）。本次确认方法体，不凭文件存在声称新004已跑。W7_DailyLimitUITests/testW7CompactLimitGateScreenshots会多次relaunch重置19且部分提交为if存在才点，涵盖多个旧入口；不建议整方法重跑冒充严格连续额度链。已满20→isPremium=false重新拦截可随A到期观察，不另起重复购买。

### C 头像选择/取消与固定离线回滚：一个新UI方法

建议selector：QiuJiUITests/AvatarBoundaryDiagnosticUITests/testSyntheticPickerAndCropCancelThenOfflineUploadRestoresDefaultAvatar（待编写）。可复用Photo专用合成图原件，但新设备须重新核实际照片AX与缩略图，不跨设备硬拷贝9月08日17:03或索引。现有PhotoImportDiagnosticUITests只用于拍照建球形，不是头像路径；其设备硬编码和freePremium不能直接套入身份fixture测试。

新专用设备仅合成图、auth fixture网络隔离，初始默认头像、avatarDelete不存在、账号为服务端球友。正常我的→profile.accountHeader→avatarPicker：系统选择器打开取消→仍默认；再次正常选合成图→裁切头像→取消→仍默认且无失败alert；再次选择同合成图→实际裁切预览（可调整一次zoom且读回变化）→使用→“个人资料未保存”→知道了→默认头像、avatarDelete仍无、avatarPicker恢复enabled，返回重进仍默认/原身份。PNG先AX后留裁切和失败终态；对默认圆头像实际图审，不以全App截图hash比较。系统Cancel节点必须在本入口首次观察核身份，不能因Photo入口见过就猜唯一对象。

源细节：PersonalInfoView.preparePhoto使用defer将selectedPhoto置nil，支持再次选择同图；仍须正常UI验证重新进入裁切，不能仅按源码声称已通过。若同图不能再次进入，保留该正常流程失败，不用换图或清业务状态掩盖。固定离线请求在构造API传输前throw，失败提示和回滚可观察，不要求极短暂预览一定被XCTest捕获。旧头像非nil回滚与跨owner迟到采用已有U/P补层，不额外制造真实账号/头像成功上传。

### D 加载失败和空集合：一个服务层判别候选，暂非直接可跑UI

catalog001已有empty与重试恢复局部证据，SC03无搜索结果也有正常UI空集合证据，二者不是加载异常。当前SubscriptionManager的service私有固定StoreKitService.shared，只有entitlementLoader可注入；不能在Runner注入URLProtocol就控制App商品加载。原SKTestSession loadProducts网络错误实际返回empty，重跑同注入无法保证进入catch。

最小候选为独立本地StoreKit hosted观察一个明确的loadProducts错误响应，严格要求实际thrown与原始错误链，才可作为服务失败分支证据；若仍empty即停止，保留“正常App商品catch/timeout未具备确定注入”。不为此改生产依赖或开启真实商店。无现成精确成功selector可诚实给出；不要用延迟/强杀StoreKit进程造超时。若原包6指动作库OTA加载失败，固定fixture/APIClient错误仅证明网络层，不能替代Bundle fallback的正常页面观察，需按实际loader合同另设计而非把商品empty移过去。

### E 上传在途失败/只补传：一个新增协议层方法

建议selector：QiuJiTests/UploadBoundaryDiagnosticTests/testInFlightUploadFailureRetainsOnlyPendingOwnerItemsAndRetryDoesNotResendAcknowledgedItem（待编写）。沿真实UploadQueueService/现有backend协议、新内存ModelContainer与UUID偏好；先已确认成功项出队，再当前owner两待上传项，continuation卡住首项后释放明确失败，强断言未完成项仍在、已完成不回流；允许成功重试后每项恰一次成功、归属/provenance不变。不把“总调用两次”当无重复，必须区分失败尝试和成功确认。若另含切owner/关闭，预期以当前coordinator revision契约明确，不能凭想象所有失败都不发第二项。

已有QiuJiTests/V54TrainingTransactionTests/test_uploadFailureKeepsAtomicQueue_andRetryCarriesProvenance是单项失败→成功2尝试及payload不变，可复用，不重跑它当在途多项证据；003下载关闭/owner仅复用对应层。authenticatedProfileFixture会提前return push/pull，不得用于此P层测试。正常App固定离线→成功恢复仍缺App进程内注入能力，不是必须人工，也不允许偷偷连接生产。

## 验收/外部边界

A/C优先补当前独有UI缺口；B可与A共享一次本地交易减少昂贵UI，但不要吞掉首个前置失败。D只有可控错误前提成立才执行，避免第三轮同样empty；E仅补一个有边界的多项在途反例。所有新增源须主控全文审核后注册；关键失败PNG/AX/交易或队列证据先保存再throw，cleanup不得覆盖失败、不用try?。本报告未新增这些源。

真实Apple登录/撤销、真实Sandbox到账/到期、服务器头像更新与跨设备缓存、真实Keychain/token及远端注销成功，需指定测试身份/设备/受控服务；本地session和fixture不能替代。正常本机相册合成图、裁切取消、固定离线回滚、本地StoreKit expiry、协议在途失败可以本机做，不统一外包人工。法律/真实发布URL、上线配置与日志审计沿包8保留，不由本小批抹去。所有已发现QD025与SDK重试限制维持；不为诊断修业务或扩大成全权益组合。
