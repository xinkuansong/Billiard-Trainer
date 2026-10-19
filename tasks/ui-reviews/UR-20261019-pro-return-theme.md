# Pro 权益返回「我的」主题闪变

用户反馈：浅色模式从「我的 → Pro 权益」返回时，先显示深色「我的」，随后切回浅色。

## 根因与修改

`SubscriptionStatusView` 原先通过 SwiftUI `onAppear/onDisappear` 请求 `RootView` 临时使用深色，以确保品牌页的系统状态栏为白色。`onDisappear` 在 pop 动画结束后才恢复宿主，导致动画中重新露出的「我的」仍为深色；该页额外的 `preferredColorScheme(.dark)` 在跟随系统时也会向宿主传播。

最终实现改用页面内的 `UIViewControllerRepresentable` 接收 `viewWillAppear/viewWillDisappear`，在转场开始前交还宿主外观，并在交互式返回取消时恢复品牌页深色。移除子页重复的 `preferredColorScheme`，保留局部深色环境、深绿背景和导航栏样式。用户外观偏好、权益及购买逻辑不变。没有修改全局颜色 token。

首轮尝试在「我的」内容 `onAppear` 恢复主题，普通返回闪色消失，但取消侧滑后 Pro 状态栏为黑色；已撤回该尝试。保留首轮证据，不将交互测试成功当作视觉通过。

## 验证

证据目录：`output/pro-return-theme-20261019/`。

- `before/`：构建与 1 项 UI 测试通过；录像明确复现返回过程中先深后浅。此测试通过仅证明导航可操作。
- `after/`：首轮构建与同一测试通过，正常返回已浅色，但 `cancelled-pro.png` 显示黑色状态栏，视觉不通过。
- `r2/` 与 `r2-small/`：最终构建通过；两设备各执行 1 项测试，0 失败、0 跳过，共 18 次返回流程。标准机 80.468 秒、小屏 83.464 秒。已打开原始取消侧滑截图，Pro 状态栏均为白色；已审查全程联系表和标准机 20fps 返回抽帧，浅色「我的」在返回动画中保持浅色，深色模式保持深色。
- UI 测试 `testProStatusReturnAppearanceTransitions` 从真实「我的」入口进入已解锁状态页，覆盖强制浅色、强制深色、跟随系统浅色，每种外观均执行按钮返回、取消侧滑后返回、完成侧滑。使用布局权益夹具，不代表真实购买。
- 测试设备：iPhone 16 Pro 与 iPhone SE 3 / iOS 26.3.1；通过生命周期管理器显式借用，录屏结束关闭并释放租约。没有清理其他设备。

未覆盖真机、iPad、iOS 17 和系统外观在页面内实时切换；未提交、推送或发布。用户最终体验另验。

代表证据：[改前转场](../../output/pro-return-theme-20261019/before/return-detail.jpg) · [改后转场](../../output/pro-return-theme-20261019/r2/return-comparison.jpg) · [取消侧滑后状态栏](../../output/pro-return-theme-20261019/r2/cancelled-pro.png)。
