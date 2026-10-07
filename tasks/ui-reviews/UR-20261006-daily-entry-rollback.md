# 每日清台入口回退（2026-10-06）

状态：回退实现、最终构建及3项原生定向回归通过；已实看最终页面。未装真机、提交或发布。全仓门禁被其它任务新增测试的写盘登记阻塞，见下。

用户授权：恢复先显示竖屏页面再旋转，取消预加载。历史来源712c3b3a的FreePlayView与DailyTableOrientation。

## 变更范围
- MainTabView和RootView直接进入FreePlayView；移除准备页、双门控、ready/failure回调。
- 场景恢复页面onAppear按需构建，方向恢复viewDidAppear请求；退出仍有scene owner校验及竖屏恢复。
- 删除DailyClearancePreloader及工程引用、App生命周期接线、VM预加载注入。三项仅测试被撤销预加载功能的单测随功能删除，现有实际入口/开球UI回归保留。
- 未恢复旧App的原型预热；普通首次加载后缓存继续保留，不清空训练或每日草稿。
- 其他会话HUD、相机、连续预览和viewport诊断修改保留；原修改文件快照在output/daily-entry-rollback-20261006/before。

## 证据
- Before：用户提供失败截图，已复制output/daily-entry-rollback-20261006/before/user-failure.png；不声称自行复现该错误。
- 构建与测试：build/daily-entry-rollback-20261006/tests.log、make.log。
- 选择既有testPortraitHomeEntryAndRepeatedReturn、testPortraitDeepLinkOpensLandscapeTable、testLandscapeFirstManualBreakBecomesShootable。
- After：最终11张原生整屏图位于output/daily-entry-rollback-20261006/final；已实看正常摆架、开球交付、导航2D/3D及返回首页代表图。

边界：本次不保证首次加载零等待；用户接受的竖屏→横屏过程恢复。模拟器通过不等于真机手感/性能验收。

初轮构建编译/签名完成，但旧模拟器AE86244C无法启动xctrunner，SpringBoard返回Busy / Application failed preflight checks，0用例执行，不能记为产品失败或通过。保留tests.log/原xcresult；改用新建独立模拟器1ECECB52-B43A-4ABE-9D09-05B64A72CDA2运行同版产物，不改超时/产品逻辑。

## 初轮原生与初始化边界复核
独立iPhone17Pro / iOS26.3.1实际3项通过、0失败（isolated-tests.log，82.927秒，TEST EXECUTE SUCCEEDED）。11张原生整屏图存after，已实看首页返回、两次2D、3D、直达、初始摆架和开球交付。准备页未出现，正常开球可交付并继续击球。

图审发现按旧setupScene直接恢复会先创建自由击球示例球形，初始摆架球库残留示例状态。最终增加setupScene的loadsDefaultLayout默认true，只有每日页传false：仍在onAppear同步按需搭建全部节点，由每日controller唯一创建/恢复对局；没有预加载或异步准备门控。普通自由击球沿用默认示例。final-tests.log/final图片用于最终验收，首轮结果不冒充最终源码结果。

fixtureSettled诊断盘面原有_2的y=0.56超过台宽0.5，导致这组导航截图出现桌外球；夹具值未改，只将该组用于导航/方向取证，不作为正常球形或物理验收。实际手动开球截图另列。

路由门禁初跑失败：仅FreePlayView签名漂移。逐条比较回退前快照及712c3b3a的路由选取文本，确认先前即漂移；历史差异是每日渲染DEBUG参数迁入configureDailyClearanceRendering，不是新增生产路由。此次删除入口wrapper另改变枚举后采样上下文。Root/MainTab已回到有效基线签名；仅更新FreePlayView签名及该行覆盖表（补首页往返/先加载后旋转测试），不重签其它文件。route-audit.json保留审计。

## 最终验证
- 独立模拟器：iPhone17Pro / iOS26.3.1，1ECECB52-B43A-4ABE-9D09-05B64A72CDA2，标准large字号。
- 最终源码make test（Debug -O）实际执行3项、0失败，76.441秒，**TEST SUCCEEDED**：首页两次进入/3D/回竖屏、竖屏直达、真实手动开球/停稳直接交付/再次可击球/切3D保留1杆。
- 最终日志：build/daily-entry-rollback-20261006/final-tests.log；xcresult：build/daily-spin-setting-20261005/DerivedData/Logs/Test/Test-QiuJi-2026.10.06_01-14-09-+0800.xcresult。
- 最终图审：正常手动摆架六袋/桌面/球杆/HUD完整，示例球库状态不再带入；散局球台与轨迹可见，按钮可用；导航退出回到竖屏首页。fixtureSettled含历史越界测试球，仅用于入口验证，未宣称该夹具球形有效。
- git diff --check及verify-doc-size通过。全仓verify-gate的内容/发布集/DTO/文案/路由签名均通过；最后写盘清单检查因其它任务两个未跟踪文件DailyAdaptivityAuditUITests.swift和DailyLayoutLifecycleUITests.swift未登记而失败，未修改/删除它们或放宽门禁。日志final-gate.log。
- 精确回退差异（相对本轮开始快照）：output/daily-entry-rollback-20261006/rollback-only.diff。入口门控、服务及注入标识在生产/测试/工程中无残留引用。

最终仍接受按需首次加载与短暂竖屏；未真机安装、未做持续性能测试，未提交或发布。
