# 开球玩法菜单观察草稿

仅准备/parse-only；不注册、不运行、不操作设备。测试源 `BreakModeObservationDiagnosticUITests.swift`。

唯一selector：`QiuJiUITests/BreakModeObservationDiagnosticUITests/testObservationNormalFreePlayBreakEntryPickerForAXReview`。

主控已创建但尚未启动的新专用设备 `9DC47676-D81A-4F3D-AF31-352180B69344`。测试同时核固定UUID、runner实际SIMULATOR_UDID和显式`QD_BREAK_MODE_DEVICE_UDID`（大小写忽略），授权`QD_BREAK_MODE_AUTH=NEW_EMPTY_BREAK_MODE_DEVICE`；QD环境支持direct优先/TEST_RUNNER_回退。`QD_SHOT_DIR`必须绝对非根目录，代码新建不覆盖的`break-mode-observation-UUID`叶目录。主控串行执行，不与类别UI重叠。

一次普通launch，中文/zh_CN、完成onboarding、内存库、跟随系统外观；无账号/权益/盘面fixture、无deep-link。先正常我的页面核profile.login游客模式、无accountHeader，再练习→打→自由击球。库入口源`AngleHomeView.playTools`明确正常freePlay卡，选tab强验selected。`RepeatedShotDiagnosticUITests`普通链与实际`formal-004-repeated-shot-001`原件已证明自由击球导航、击球/回放/重打初态及break.entry。具体原始AX见BREAK-MODE-CLOSURE-004-AUDIT；不复用其中的截图坐标。

首页卡frame必须完整位于真实打分类/TabBar及ScrollView交集，最多4次双向露出；进入工具后不错误要求隐藏TabBar。正常初盘回放/重打存在且disabled、击球ready，再核Button break.entry全框在实际window内并hittable/enabled。**仅点击一次break.entry**，随后取得完整PNG/AX，不查猜测的picker子节点，不选择9球/中八，不击球、不点完成、不猜取消。

输出guest、卡入口、工具初盘、点击后菜单观察、终止前五阶段PNG+完整AX及observation-contract.json；每张PNG先落盘并读回，再取可能较慢的AX，附件同时留xcresult。失败也先图后AX，不吞错误。tearDown采集后仅终止自己的App，不尝试未知关闭控件。主控需图审确认菜单实际出现及各选项的节点类型、identifier和可视frame。

方法绿只代表观察采集结束，**不代表菜单打开已经人工验收，更不代表玩法变化/seed/开球交付覆盖完成**。正常玩法picker源码`BreakGamePickerSheet`说明选中即摆架，但本次无任何选中操作；真实节点待观察归档后才能写下一条有限9球开球交付链。不再重复每日清台入口、不改生产/资产/共享台账。

语法 `swiftc -frontend -parse` 通过；没有类型编译或实跑，主控须独立审查并注册。无新技能或外部服务依赖。


002 correction: original001 failed before FreePlay entry. Actual AX has sidebar and content ScrollViews; content contains unique FreePlay card at (88,355,145,163.7). Replace obsolete sidebar-as-header viewport with actual containing scroll/window/TabBar intersection. No product assertion removed; original source and failure preserved in archive. Same dedicated in-memory guest device reused, no account or scene seed change.
