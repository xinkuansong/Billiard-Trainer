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

- [x] `SubscriptionManager.isPremium: Bool` — App 全局可访问（`@Observable` 单例）
- [x] App 启动时自动校验当前权益（`Transaction.currentEntitlements`）
- [x] 订阅到期后 `isPremium` 自动变为 `false`（通过 `Transaction.updates` 监听）
- [x] 终身买断不过期
- [x] 状态变化立即同步至所有依赖的 View

---

## T-P7-03 订阅页 UI

- **负责角色**：SwiftUI Developer
- **前置依赖**：T-P7-01
- **产出物**：`Features/Profile/Views/SubscriptionView.swift`
- **设计参考**：`ui_design/tasks/P2-06/stitch_task_p2_06_02/screen.png`

### DoD

- [x] 使用 R0 BT* 组件，不自建临时组件
- [x] 布局对照 `tasks/UI-IMPLEMENTATION-SPEC.md` 中对应设计截图
- [x] Light + Dark `#Preview` 通过视觉检查
- [x] 如有组件 API 或设计解读变更，追加 DR/PD 至 `tasks/IMPLEMENTATION-LOG.md` 并更新 `UI-IMPLEMENTATION-SPEC.md` Changelog
- [x] 全屏深色背景 `#111111`
- [x] 编号功能列表（序号金色）+ 3 张方案卡片（年订绿框推荐）
- [x] 展示三个方案：月订阅（¥18/月）、年订阅（¥88/年，标注「最划算」）、终身买断（¥198）
- [x] 价格从 StoreKit `Product.displayPrice` 动态读取（不硬编码）
- [x] 高亮「年订阅」方案（推荐）
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

- [x] `BTPremiumLock` 组件使用 `SubscriptionManager.isPremium` 决定是否显示遮罩
- [x] 角度测试每日限制：免费 20 次/天，付费无限
- [x] 历史 60 天限制：免费，付费无限
- [x] 动作库 L1+ 部分、L2+ 大部分按 `docs/08` 比例锁定
- [x] 官方计划 plan_beginner / plan_cueball 免费，其余付费锁定
- [x] **已解锁的免费功能不受影响**（不会因为添加付费墙而降级）

---

## QA-P7 P7 验收

- **负责角色**：QA Reviewer

### 验收要点

- [x] 使用 Xcode StoreKit Testing 沙盒：完成购买 → `isPremium = true` → 付费内容解锁
- [x] 购买年订阅后：所有付费 Drill 解锁，历史无限制，角度测试无限制
- [x] 「恢复购买」在有购买记录时成功恢复
- [x] 订阅页价格动态显示（与 `Products.storekit` 文件中设置一致）
- [x] **不能绕过**：直接访问付费 Drill 详情页时仍有遮罩（非从列表进入）
- [x] 隐私政策链接可跳转（P8 前可 stub 为占位 URL）

---

## ADR 记录区

### ADR-P7-01：离线本地身份与在线认证分离
- 场景：账号恢复遇到网络故障时回退游客，导致已购用户无法访问其本地数据与 Pro。
- 选项：强制在线恢复 / 把缓存当在线认证 / 独立可信本地身份。
- 决策：新增 `offlineAccount`；仅在已有 refresh credential 且 Keychain 有最近成功认证的最小账号标识（userID/provider）时恢复。`isLoggedIn` 仍只表示服务端认证成功，云同步与资料修改沿用该条件；Pro 另验当前 StoreKit 权益。
- 生命周期：身份随成功登录或恢复替换，不另设付费缓存有效期；账号身份本身不授予会员。明确凭证失效、退出、注销、主动转游客清除；无 refresh credential 不恢复。旧版本首次升级离线且无可信标识时需先成功在线恢复一次。网络恢复后可重新 bootstrap。
- 数据：owner 在发布离线 phase 前切换，现有 owner 范围查询与 RootView 身份重建沿用；不新增 SwiftData Schema，不迁移或合并账号数据。
- 日期：2026-10-17；依据用户已确认 D01/D02。自动测试及真机状态见 Pro 执行记录，不沿用上方历史 QA 勾选作为本轮验收。


### ADR-P7-02：已开始课程的到期续练（2026-10-17）

D04 的许可保存在当前训练 VM 中，以课程 scheduleItemID、owner 与身份版本为范围。合法打开第一课时授予；切换下一课前再校验，新加 Pro 内容再校验。到期不撤销本次已授予课程的录入/保存；退出、换号、进程重启或重新创建训练 VM 不继承持久化 inProgress 的权限。混合队列启动先整体检查，保存只接受已授予课程；不引入没有产品依据的固定小时 TTL。

### 2026-10-17 Pro 增量回归状态

D01–D06 已实现；320项定向iOS单测、3项默认手机UI、完整Release模拟器构建和全gate通过。B09实际StoreKit交易受iOS26.3测试配置故障阻断，B10真机/跨设备与用户视觉验收未关闭，H-09正式法律链接仍为空。不得用本地注入测试或历史P7勾选替代本轮交易验收。见 [执行记录](../PRO-ENTITLEMENT-EXECUTION-20261017.md) 与 [补充验收单](../test-plans/TP-PRO-20261017.md)。未提交、推送或发布。
