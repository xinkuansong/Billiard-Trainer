# Pro 权限与购买页 UI 复核 — 2026-10-17

范围：默认开发机 iPhone17Pro / iOS26.3.1，当前共享工作区 Debug 构建。没有使用强制 Pro 冒充购买；仅免费锁态与游客购买页。测试记录见 [执行记录](../PRO-ENTITLEMENT-EXECUTION-20261017.md)。

## 自动验证

`OnboardingProUITests/testAllNineProDestinationsLockedWithoutPurchase` 逐一进入 separation/cushion/scene3d/aim3d/snake/composer/photo/three/snooker，9次均 `pro.locked` 存在、`pro.authorized` 不存在。`testProPresentation` 在浅/深色验证月/年/终身选择状态、按钮周期文案、进入并取消登录后选择保留。2项测试通过，无跳过。

## 逐图审查

图片根：`output/pro-implementation-20261017/b09/phone-ui/`，文件对应见 manifest.json。已逐一查看5张原生截图：免费分离角锁页、浅/深购买页初始年度方案与切换终身方案。

- 锁页标题、Apple购买说明与解锁按钮可见，按钮和底部Tab不相交。付费目的地未构建；无障碍树未暴露被锁内容。
- 五项权益与目前范围相符，含蛇彩；没有将免费能力列为独占收费权益。
- 三方案动态测试价完整显示，选择描边与按钮周期同步；浅深色文字可读，未发现正常字号的截断或横向溢出。
- 关闭与恢复入口在顶部，底部购买按钮未遮挡当下可见方案。法律说明在滚动内容中，未出现在上述5张截图，不能据此认定已经验收法律区。

## 未关闭范围

小屏、iPad、实际购买后的状态页/九工具、页面打开后到期、VoiceOver实际朗读与用户视觉接受均未完成。辅助字号与法律状态补测结果见下一节，不以源码的自适应分支替代运行结果。StoreKit实际交易环境故障与这些普通UI验证分开登记。

## 辅助字号补测（21:39）

`testProLargeTextKeepsPlansLegalStateAndPurchaseReachable` 浅/深两态通过（1测试），截图6张已逐图核看，见 `output/pro-implementation-20261017/b09/large-final/manifest.json`。辅助字号请求激活纵向方案卡，商品、选择状态、底部购买按钮与法律状态均可滚动到达，按钮未横向溢出。现有字体 token 未证明支持全页按系统字号同比例放大，因此不将本测试当成完整 Dynamic Type/VoiceOver 验收。

两次失败如实保留：首轮屏幕外元素被 XCTest 误报可点击，测试改为同时核完整 frame 位于底栏上方；第二轮发现 H-09 正式法律地址为空，真实页面显示未发布提示。最终测试验证诚实未发布提示的可达性，**没有认定服务条款/隐私页面已经发布或链接可用**。该项仍是上线前置。
