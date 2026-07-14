# W2-2 诚实反馈 P1 包 — 截图

模拟器：iPhone 17 Pro · Dark

## 文件

| 文件 | 对应条目 | 说明 |
|---|---|---|
| `before-01-training-home.png` | F-PL-01 | 基线（2026-07-13 tour） |
| `after-01-training-home-activated.png` | F-PL-01 | 激活后首页：今日安排 +「开始训练」 |
| `after-01-training-home.png` | F-PL-01 | 同会话另一帧（已激活态） |
| `before-03-plan-list.png` / `after-03-plan-list.png` | F-TR-04 / F-PL-03 | 计划列表 |
| `after-04-plan-detail-activated.png` | F-PL-03 对照 | 详情底栏「当前已激活此计划」横幅 |
| `before-60-subscription-paywall.png` / `after-60-subscription-paywall.png` | F-PF-01 | Paywall **静态**壳（购买失败 alert 见下方代码走查） |
| `after-50-profile.png` | F-ST-01 入口 | 我的 Tab（同步失败 alert 为运行时态） |
| `after-training-share-options.png` | F-TR-02 | 选项区仅保留已接线「隐藏成功率」 |

## 运行时态 — 代码走查（未能稳定截到）

| 条目 | 验证方式 |
|---|---|
| F-PF-01 购买失败 | `SubscriptionView.handlePurchase` 失败且 `errorMessage != nil` → `.alert("购买失败")`。需 StoreKit 交易失败；取消购买不弹。 |
| F-PF-02 登录中 | `PhoneLoginView` 登录钮在 `isLoggingIn` 时显示 `ProgressView` +「登录中」。 |
| F-PF-05 注销中 | `SettingsView` overlay「正在注销…」+ 按钮 disabled。 |
| F-PF-07 恢复 loading | `SubscriptionStatusView` 恢复钮在 `isLoading` 时 `ProgressView`。 |
| F-TR-01 相册真保存 | `PHPhotoLibrary.performChanges` 成功 →「已保存到相册」；失败/无权限 →「保存失败」。 |
| F-AT-01 键盘收起 | `DrillRecordView` ScrollView 已挂 `.scrollDismissesKeyboard(.interactively)`。 |
| F-ST-01 Auth 同步失败 | `ProfileView` 读 `authState.errorMessage` 弹「同步失败」。 |
