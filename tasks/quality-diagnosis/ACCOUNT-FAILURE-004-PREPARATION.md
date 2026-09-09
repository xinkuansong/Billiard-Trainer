# 固定离线账号失败UI：004准备

2026-09-08，Test Engineer。仅新增本文与 `AccountFailureDiagnosticUITests.swift`；未注册/构建/运行/操作设备，无通过结果，不修改业务或共享台账。

精确选择器：`QiuJiUITests/AccountFailureDiagnosticUITests/testOfflineProfileFailureDeletionFailureAndLogoutPreserveIdentityBoundaries`，1个同步方法。范围限定正常资料改名失败、注销取消/失败/重试仍失败、退出游客；不扩头像、成功注销、联网恢复或真正Apple认证。

## 必须由主控确认的隔离前提

新专用模拟器，没有真实账号/凭据，不复用用户安装。必传：

- `QD_ACCOUNT_FAILURE_AUTH=NEW_DEDICATED_OFFLINE_FIXTURE_SIMULATOR`
- `QD_ACCOUNT_FAILURE_UDID=<新专用UDID>`，与Runner的 `SIMULATOR_UDID`相等
- `QD_ACCOUNT_API_GUARD=SNAPSHOT004_REQUESTDATA_PRETRANSPORT_THROW_VERIFIED`
- 绝对 `QD_SHOT_DIR`；上述均兼容TEST_RUNNER前缀。

最后一个guard要求主控核对实际Debug构建输入来自snapshot004、APIClient guard仍在；它是执行授权声明，不是运行时抓包或自动验证代码哈希。已重新读冻结 `Data/Services/APIClient.swift:116–129`：`-v53.authenticatedProfileFixture` 在取refresh token、buildRequest、authorize和perform之前直接throw `URLError(.notConnectedToInternet)`。`BackendSyncService.updateProfile/deleteAccount/logout`都经过该API；fixture本身avatarRevision=nil，协调器push/pull也提前return。

先不带身份fixture启动核真实游客，停止该进程后带现有fixture启动。必须看到精确 `profile.accountHeader` label“个人信息，服务端球友”；这来自冻结ProfileView :177–178，不能只凭“有某个账号”允许操作。每个变更/注销/退出前再次要求launchArguments仍含flag，任何失败throw中止。普通inMemoryStore仅隔离模型，不等于Keychain/网络隔离；专用新设备与实际guard缺一不可。不清凭据、不读取秘密、不发真实账号请求。

## 正常步骤与观察

1. 我的→个人信息，`personalInfo.displayNameButton`旧名服务端球友→`personalInfo.displayNameField`输入合法短新名，实际value必须完全等于候选，否则停止。点`personalInfo.displayNameSave`，冻结源码明确alert“个人资料未保存”及“知道了”。不硬编URLError系统本地化正文，原样PNG/AX保留。关闭alert、正常返回，账号header仍旧名；重开个人信息旧名仍在，不能用还留在编辑框的新草稿判假成功。
2. 我的→偏好设置→注销账号→“确认注销”出现后先“取消”，返回header仍合成身份。第二次重新进入确认注销，API前置离线必使Settings catch显示“注销失败”，有“重试/取消”。点重试后再观测失败alert，关闭、返回，header仍为原合成身份。源码重试会先关闭flag再Task更新，短暂alert消失未必可被AX捕获，因此不强制一个假的中间帧；**实际第二次请求尝试由按钮tap日志与源码路径支持，若需运行时精确请求计数需独立日志/探针，不从同一alert存在推出计数**。
3. Profile“退出登录”真实按钮调AuthState.logout，Backend.logout失败不阻止clearLocalSession；核真实游客和无accountHeader。随后terminate→notRunning，去掉身份fixture再启动仍游客。去掉flag是必要的诊断条件改变：保留它会按设计bootstrap重新注入合成账号。此结果不是服务端token撤销或真实账号冷启动证明。

页面名称“个人信息”“偏好设置”、alert标题/按钮均来自当前冻结源码；它们尚未在本批现场AX验证。Profile行用已知正文入口；无ID注销行先正常露出再点，不猜屏幕坐标。辅助滚动只选唯一真实纵向ScrollView，短幅拖动，保留目标完整frame/导航栏和TabBar边界。若控制类型/标题/取消按钮唯一性不符，先失败留证，主控按实际AX适配，不能自动点未知对话框。

## 记录与限制

准备检查：`xcrun swiftc -frontend -parse tasks/quality-diagnosis/AccountFailureDiagnosticUITests.swift` 退出 0。仅 Swift 语法解析；尚未类型检查、注册、构建或运行，不构成测试通过。

全部前置/业务断言通过throw中止，避免首错后级联；teardown先PNG/AX `terminal-unclassified`再终止本App，不给失败打成功标签。只有全部终态核对后才写最终verified图与日志。主控保留新设备、输入/测试源hash、真实xcresult、退出码、每阶段截图及图审。

此方法不证明数据迁移或成功删号：固定离线使Settings在后端删除前失败，根本没有到本地owner迁移/缓存清除/finishAccountDeletion成功链；旧相关U/P证据仍按 `ACCOUNT-OFFLINE-004-EVIDENCE-AUDIT.md`分层引用。它也不证明全App零网络、实时权限变化或头像操作；仅对已核APIClient路径保持固定离线。若资料意外保存成功或注销意外成功，立即以guard/构建输入异常保留失败，不继续后续变更。

## 主控预审补记（2026-09-08）

已完整阅读本草稿与UI测试源；只读复核冻结APIClient.request实际转requestData，Debug fixture检查位于refresh token读取、buildRequest与perform之前；BackendSyncService的updateProfile/deleteAccount/logout走该入口，AccountDataCoordinator在fixture下push/pull提前返回。允许下一批在新建专用设备上按上述限定执行。此时仍未注册/构建/运行，没有新增通过结论；不可与真实服务端注销混淆。

001实际失败36.212秒并1415文件归档：新模拟器键盘引导可见，中心点击光标位于旧名中，实际值离线诊断8198端球友；精确候选检查在保存前中止。002仅适配已观察Continue及输入框尾部点击，先断言清空再输入并保持原精确候选断言。不改业务，不清凭据，沿用本批专用设备（已无真实身份，旧运行未提交任何资料）。

002失败32.636秒，1337文件归档：键盘引导已消失，但尾部坐标点击仍未使光标到结尾，清空断言在保存前中止（实际端球友）。003不再猜光标；原目标是合法新名保存失败后旧名保持，并无全量替换要求。用一个短ASCII标记插入任意当前位置，严格核标记恰一次、去掉后原名逐字不变，随后仍要求保存失败及重开旧名。失败保留，不改业务断言或API路径。

003实际失败72.304秒并1373文件归档：合法11字符新名保存显示-1009，重开旧名通过且主控看两图；注销确认实际Popover仅确认注销，没有取消按钮，AX有PopoverDismissRegion。004改用已观察dismiss region，先核区域中心在popover外，再点击取消并保持身份核对。不把缺按钮视为不能取消，保留003失败。
