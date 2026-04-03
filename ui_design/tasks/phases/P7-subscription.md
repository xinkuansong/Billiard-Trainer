# P7 — Subscription（订阅与 IAP）

> **目标**：完整的 Freemium 逻辑，StoreKit 2 IAP，订阅页 UI，恢复购买。
> **人工前置**：H-03 ✅（App Store Connect App 记录）、H-04 ✅（IAP 产品已创建）
> **前置 Phase**：P6 通过 QA

---

## T-P7-01 StoreKit 2 集成（Product 加载 + 购买）

- **负责角色**：Data Engineer
- **人工前置**：H-03 ✅, H-04 ✅
- **前置依赖**：P2 完成
- **产出物**：`Data/Services/StoreKitService.swift`

### DoD

- [x] `StoreKitService.loadProducts()` 可从 App Store 加载 3 个 IAP 产品
  - 月订阅：`com.yourname.billiardtrainer.premium.monthly`
  - 年订阅：`com.yourname.billiardtrainer.premium.yearly`
  - 终身买断：`com.yourname.billiardtrainer.premium.lifetime`
- [x] 本地有 `Products.storekit` 配置文件（用于模拟器离线测试）
- [x] `purchase(product:)` 可触发购买流程（模拟器 StoreKit Testing 环境）
- [x] 购买完成后 `Transaction` 验证通过（`Transaction.currentEntitlement`）

---

## T-P7-02 订阅状态管理（SubscriptionManager）

- **负责角色**：Data Engineer
- **前置依赖**：T-P7-01
- **产出物**：`Data/Services/SubscriptionManager.swift`

### DoD

- [x] `SubscriptionManager.isPremium: Bool` — App 全局可访问（`ObservableObject` 单例 + `@EnvironmentObject`）
- [x] App 启动时自动校验当前权益（`Transaction.currentEntitlements`）
- [x] 订阅到期后 `isPremium` 自动变为 `false`（通过 `Transaction.updates` 监听）
- [x] 终身买断不过期（非消耗型，无 revocationDate 即始终有效）
- [x] 状态变化立即同步至所有依赖的 View（`@Published` + `@EnvironmentObject`）

---

## T-P7-03 订阅页 UI

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P7-01
- **产出物**：`Features/Profile/Views/SubscriptionView.swift`

### DoD

- [x] 展示三个方案：月订阅（¥18/月）、年订阅（¥88/年，标注「最划算」）、终身买断（¥198）
- [x] 价格从 StoreKit `Product.displayPrice` 动态读取（不硬编码）
- [x] 高亮「年订阅」方案（默认选中 + 边框 + badge）
- [x] 「订阅」按钮触发购买，加载中显示 ProgressView
- [x] 「恢复购买」按钮
- [x] 底部：订阅条款链接 + 隐私政策链接
- [x] **不出现**任何引导用户去 App Store 外支付的文字或链接

---

## T-P7-04 恢复购买

- **负责角色**：Data Engineer
- **前置依赖**：T-P7-01
- **产出物**：`StoreKitService.restorePurchases()`

### DoD

- [x] 点击「恢复购买」触发 `AppStore.sync()`
- [x] 恢复成功时 `isPremium` 更新为 `true`，UI 提示「已恢复购买」
- [x] 无可恢复购买时提示「未找到可恢复的购买记录」
- [x] 不崩溃、不卡死

---

## T-P7-05 Freemium 边界逻辑全整合

- **负责角色**：Data Engineer
- **前置依赖**：T-P7-02
- **产出物**：所有 Premium 检查点统一使用 `SubscriptionManager.isPremium`

### DoD

- [x] `BTPremiumLock` 组件使用 `SubscriptionManager.isPremium` 决定是否显示遮罩（新增 `PremiumGateModifier` + `.premiumGate(isPremium:)` 便捷方法）
- [x] 角度测试每日限制：免费 20 次/天，付费无限（`AngleUsageLimiter.isPremium` 由 `SubscriptionManager` 驱动）
- [x] 历史 60 天限制：免费，付费无限（`HistoryCalendarView` 使用 `SubscriptionManager.isPremium` 传入 `HistoryAccessController`）
- [x] 动作库 L1+ 部分、L2+ 大部分按 `docs/08` 比例锁定（JSON `isPremium` + `premiumGate` 修饰符）
- [x] 官方计划 plan_beginner / plan_cueball 免费，其余付费锁定（JSON `isPremium` + `premiumGate` + 激活按钮判断）
- [x] 统计图表 Pro-only（`StatisticsView` 添加 `premiumGate(isPremium: true)`）
- [x] 角度测试历史 Pro-only（`AngleHistoryView` 添加 `premiumGate(isPremium: true)`）
- [x] **已解锁的免费功能不受影响**（未修改任何 JSON `isPremium` 字段或默认行为）
- [x] 我的 Tab 新增订阅入口（Premium banner / 管理订阅 / 升级提示）

---

## QA-P7 P7 验收

- **负责角色**：QA Reviewer

### 验收要点

- [ ] 使用 Xcode StoreKit Testing 沙盒：完成购买 → `isPremium = true` → 付费内容解锁
- [ ] 购买年订阅后：所有付费 Drill 解锁，历史无限制，角度测试无限制
- [ ] 「恢复购买」在有购买记录时成功恢复
- [ ] 订阅页价格动态显示（与 `Products.storekit` 文件中设置一致）
- [ ] **不能绕过**：直接访问付费 Drill 详情页时仍有遮罩（非从列表进入）
- [ ] 隐私政策链接可跳转（P8 前可 stub 为占位 URL）

---

## ADR 记录区
