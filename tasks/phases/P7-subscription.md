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

- [ ] `StoreKitService.loadProducts()` 可从 App Store 加载 3 个 IAP 产品
  - 月订阅：`com.yourname.billiardtrainer.premium.monthly`
  - 年订阅：`com.yourname.billiardtrainer.premium.yearly`
  - 终身买断：`com.yourname.billiardtrainer.premium.lifetime`
- [ ] 本地有 `Products.storekit` 配置文件（用于模拟器离线测试）
- [ ] `purchase(product:)` 可触发购买流程（模拟器 StoreKit Testing 环境）
- [ ] 购买完成后 `Transaction` 验证通过（`Transaction.currentEntitlement`）

---

## T-P7-02 订阅状态管理（SubscriptionManager）

- **负责角色**：Data Engineer
- **前置依赖**：T-P7-01
- **产出物**：`Data/Services/SubscriptionManager.swift`

### DoD

- [ ] `SubscriptionManager.isPremium: Bool` — App 全局可访问（`@Observable` 单例）
- [ ] App 启动时自动校验当前权益（`Transaction.currentEntitlements`）
- [ ] 订阅到期后 `isPremium` 自动变为 `false`（通过 `Transaction.updates` 监听）
- [ ] 终身买断不过期
- [ ] 状态变化立即同步至所有依赖的 View

---

## T-P7-03 订阅页 UI

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P7-01
- **产出物**：`Features/Profile/Views/SubscriptionView.swift`

### DoD

- [ ] 展示三个方案：月订阅（¥18/月）、年订阅（¥88/年，标注「最划算」）、终身买断（¥198）
- [ ] 价格从 StoreKit `Product.displayPrice` 动态读取（不硬编码）
- [ ] 高亮「年订阅」方案（推荐）
- [ ] 「订阅」按钮触发购买，加载中显示 ProgressView
- [ ] 「恢复购买」按钮
- [ ] 底部：订阅条款链接 + 隐私政策链接
- [ ] **不出现**任何引导用户去 App Store 外支付的文字或链接

---

## T-P7-04 恢复购买

- **负责角色**：Data Engineer
- **前置依赖**：T-P7-01
- **产出物**：`StoreKitService.restorePurchases()`

### DoD

- [ ] 点击「恢复购买」触发 `AppStore.sync()`
- [ ] 恢复成功时 `isPremium` 更新为 `true`，UI 提示「已恢复购买」
- [ ] 无可恢复购买时提示「未找到可恢复的购买记录」
- [ ] 不崩溃、不卡死

---

## T-P7-05 Freemium 边界逻辑全整合

- **负责角色**：Data Engineer
- **前置依赖**：T-P7-02
- **产出物**：所有 Premium 检查点统一使用 `SubscriptionManager.isPremium`

### DoD

- [ ] `BTPremiumLock` 组件使用 `SubscriptionManager.isPremium` 决定是否显示遮罩
- [ ] 角度测试每日限制：免费 20 次/天，付费无限
- [ ] 历史 60 天限制：免费，付费无限
- [ ] 动作库 L1+ 部分、L2+ 大部分按 `docs/08` 比例锁定
- [ ] 官方计划 plan_beginner / plan_cueball 免费，其余付费锁定
- [ ] **已解锁的免费功能不受影响**（不会因为添加付费墙而降级）

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
