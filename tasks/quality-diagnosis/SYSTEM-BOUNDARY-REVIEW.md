# SC03/16/30/38 正常UI补充草稿

2026-09-05：新增 `SystemBoundaryDiagnosticUITests.swift`，4个方法；未编译、未执行、未触碰设备或既有文件。仅基于snapshot-002正常入口，无deeplink、无登录/认证fixture、不读取凭证、不上传资料、不调用资源生成。

## 方法白名单

前缀 `QiuJiUITests/SystemBoundaryDiagnosticUITests/`。

| 方法 | 真实操作与断言 | 局限 |
|---|---|---|
| testLibraryEmptySearchRecoversAndFavoriteSurvivesReentry | 游客→我的收藏空态→浏览动作库→唯一无结果词、0卡片→浏览全部动作恢复→搜索c012→正常详情收藏→取消收藏按钮→我的收藏出现→离开再进入仍有 | 同进程内存收藏，不是磁盘重启；无取消收藏、owner切换、加载错误伪空态覆盖 |
| testGuestNicknameUsesNormalLocalEditorAndReopens | 确认真游客→个人信息→稳定identifier昵称按钮/字段→唯一诊断昵称→实际键盘与完成可达→保存→离开重进值一致 | 游客本地偏好保存，不能称账号资料上传成功；未测跨进程和非法/失败 |
| testNotificationRealPromptAllowedWithEvidence | 全新未决定通知态→提醒开关→实际系统两选择弹框→截图+AX→允许→App权限状态与开关1 | 不证明到点通知送达/时区/后台 |
| testNotificationRealPromptDeniedWithEvidence | 另一全新未决定态→真实拒绝→无法开启提醒解释图→关闭解释→权限状态与开关0 | 不证明从系统设置恢复权限 |

## 游客昵称实际入口审计

`ProfileView` 的primaryMenuGroup不以isLoggedIn包裹“个人信息”，所以游客正常可达。`PersonalInfoView` 的avatarSection内有 `personalInfo.displayNameButton`，编辑字段/保存分别为 `personalInfo.displayNameField` / `personalInfo.displayNameSave`。`OwnerProfileStore.saveDisplayName`校验1–20字符后，save函数在 `!authState.isLoggedIn`分支更新guest并persistAll，直接返回，不走后面的backend.updateProfile。因此游客昵称可以做真实本地编辑；无需为了测试构造登录账号。

草稿每次进入资料前要求UI存在profile.login且label含游客模式，并用throwing XCTUnwrap阻止不满足身份时继续；还断言无profile.accountHeader。主控必须使用专用无登录设备，避免测试启动继承真实登录状态。launchClean本身不清凭证；本方法既不读取也不清除凭证。其它既有启动后台网络行为不在此方法控制范围，整体环境仍由主控管理。

昵称默认写入专用模拟器guest UserDefaults，即使SwiftData为内存也不会自动清掉。保留唯一诊断昵称供检查，不擅自恢复未知旧值或清库。替换从实际字段右端定位并严格核对value，无按数字过滤掩盖残留。

## P8真实通知方法审计与包装差异

旧P8的Allowed/Denied共用exerciseTrainingReminderPermission：要求首次未决定文字；真实SpringBoard alert或interruption monitor点选；handledSystemPrompt必须true；核对最终文案和开关。没有预授伪装，但缺显式成功过程附件。

新草稿不继承/运行整个P8，而重新走相同正常Profile→训练目标路径，加入请求前、真实系统弹框、最终状态截图，拒绝还拍App解释；真实弹框AX keepAlways。截图名称带实例UUID，写 `QD_SHOT_DIR` / `TEST_RUNNER_QD_SHOT_DIR`，I/O失败抛出。要求同一alert同时有允许/不允许，避免把App错误提示当权限框。SpringBoard查不到时仅尝试App承载的alert，不做静默成功分支。

每个通知方法必须独占**一个新建且权限未决定的专用设备**，不可在同一设备顺序运行允许与拒绝。不得用 `simctl privacy grant`，也不假设某版本支持reset notifications；旧同意设备显示已开启会按前提失败。运行前保存设备身份、App版本、权限前态；主控串行调度，不并行CUA。

实际系统中文按钮可能在特定Runtime变为“好/OK”而非“允许”；本草稿先严格按通知Allow/Don't Allow真实语义，遇到不同AX必须保留原图再据事实补定位，不能盲目放宽到任意确认按钮。允许分支未来排程可能留下本地通知，属于专用设备诊断产物；不要为清理而误触用户设备。

## 未实测的AX与风险

- Profile菜单标题当前为独立Text；若AX合并为按钮，精确staticTexts定位可能失败，应取证后更新诊断定位，不能直接声明入口缺失。
- 收藏列表使用BTDrillCard，c012名称可能AX合并；草稿在默认新内存库先证空态，后只新增一个目标避免已有同名满足。
- 搜索采用换行收键盘，并处理已知系统首次滑行输入提示；没有假定键盘设置值等于实际键盘已收起。
- 通知拒绝说明遮住状态时先拍解释、明确关闭后再核对状态；真正过程截图不可用最终页面补冒。
- 所有4项当前只为待编译/运行草稿，不计SC完成。最大字号可复用昵称方法补M5，但实际输入/保存/截图通过后才能下结论。
