# 人工测试计划 — Phase 7 Subscription（订阅与 IAP）

> **使用方式**：在模拟器或真机上逐条执行，通过则勾选 `[x]`，失败则记录问题描述。
> **时机**：P7 功能 + 自动化测试通过后，QA Reviewer 最终验收前。
> **重点**：StoreKit 2 购买流程、订阅状态管理、恢复购买、Freemium 边界全整合、订阅页 UI。
> **测试环境**：使用 Xcode StoreKit Testing 沙盒（`Products.storekit` 配置）。
> **更新记录**：2026-04-06 — V2；新增 SubscriptionStatusView（Pro 用户管理面板）入口

---

## 前置条件

- [ ] Debug 构建成功（Scheme: QiuJi, Destination: iPhone 17 Pro Simulator）
- [ ] Xcode StoreKit Testing 环境启用（Scheme → Run → StoreKit Configuration → Products.storekit）
- [ ] 全新安装后有训练数据（至少完成 P4 流程 1 次）
- [ ] 初始状态为免费用户（未购买任何 IAP）

---

## 一、视觉与 UI

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| V-01 | SubscriptionView | 全屏深色背景 #111111 | [ ] |
| V-02 | SubscriptionView | 编号功能列表（序号金色）完整展示 Pro 功能说明 | [ ] |
| V-03 | SubscriptionView | 3 列方案卡片：月订阅 / 年订阅（绿框「推荐」）/ 终身 | [ ] |
| V-04 | SubscriptionView | 价格从 StoreKit Product.displayPrice 动态读取（¥18/¥88/¥198）| [ ] |
| V-05 | SubscriptionView | 「订阅」按钮清晰，加载中显示 ProgressView | [ ] |
| V-06 | SubscriptionView | 「恢复购买」按钮可见 | [ ] |
| V-07 | SubscriptionView | 底部：订阅条款 + 隐私政策链接 | [ ] |
| V-08 | SubscriptionView | 不出现引导用户去 App Store 外支付的文字 | [ ] |
| V-09 | ProfileView（免费用户） | 订阅管理行显示「升级 Pro」绿色文字 | [ ] |
| V-10 | ProfileView（已订阅） | 用户卡片右侧 Pro 徽章可见 | [ ] |
| V-11 | ProfileView（已订阅） | 订阅管理行显示「Pro 年度会员」灰色文字 | [ ] |

---

## 二、Dark Mode

| # | 页面 | 检查项 | 通过 |
|---|------|--------|------|
| D-01 | SubscriptionView | 深色背景 #111111 与系统 Dark 一致（不出现两层深色落差） | [ ] |
| D-02 | SubscriptionView | 金色编号 + 功能列表文字可读 | [ ] |
| D-03 | SubscriptionView | 3 列卡片边框/选中态 Dark 下对比度足够 | [ ] |
| D-04 | SubscriptionView | 按钮 Dark 下颜色正确 | [ ] |

> 注：SubscriptionView 设计为固定深色，不做 Dark Mode 反转。

---

## 三、用户流程

### 流程 1：订阅页入口

**步骤**：
1. 「我的」Tab → 点击「订阅管理」菜单项
2. 或「我的」Tab（未登录）→ 点击 Pro 推广深色卡
3. 或动作库 → 付费 Drill → BTPremiumLock「解锁 Pro」

**预期结果**：三个入口均可打开 SubscriptionView Sheet

- [ ] 从 ProfileView 订阅管理入口打开
- [ ] 从 Pro 推广卡入口打开
- [ ] 从 BTPremiumLock 入口打开

### 流程 2：购买月订阅

**步骤**：
1. 打开 SubscriptionView
2. 确认 3 列方案卡片价格（¥18/月、¥88/年、¥198 终身）
3. 默认高亮年订阅（绿框推荐）
4. 点击月订阅卡片选中
5. 点击「订阅」按钮
6. StoreKit 弹出购买确认（模拟器环境）
7. 确认购买
8. 等待购买完成

**预期结果**：购买成功，isPremium = true

- [ ] 价格动态显示正确（与 Products.storekit 一致）
- [ ] 年订阅默认绿框高亮
- [ ] 点击卡片可切换选中
- [ ] 购买中显示 ProgressView
- [ ] 购买成功后 SubscriptionView 关闭或更新状态
- [ ] ProfileView 显示 Pro 徽章

### 流程 3：购买后 Freemium 解锁验证

**步骤**：
1. 购买成功后（isPremium = true）
2. 动作库 → 找之前被锁定的付费 Drill → 进入详情
3. 确认 BTPremiumLock 遮罩消失
4. 角度 Tab → 做 21 题以上
5. 历史 Tab → 查看 60 天前的记录（如有）
6. 训练 Tab → 之前被锁的付费计划

**预期结果**：所有付费边界全部解锁

- [ ] 付费 Drill 内容完整展示，底栏显示「关闭」+「加入训练」
- [ ] 角度测试无每日 20 题限制
- [ ] 历史记录无 60 天限制
- [ ] 付费训练计划可正常激活

### 流程 4：恢复购买

**步骤**：
1. 先在 Xcode StoreKit Testing Manager 中清除所有交易
2. 重新安装 App → 免费用户状态
3. 打开 SubscriptionView → 点击「恢复购买」
4. 确认恢复结果

**预期结果**：
- 有购买记录时：恢复成功，isPremium = true，UI 提示「已恢复购买」
- 无购买记录时：UI 提示「未找到可恢复的购买记录」

- [ ] 恢复购买不崩溃
- [ ] 有购买时成功恢复 + 提示
- [ ] 无购买时友好提示

### 流程 5：订阅过期后降级

**步骤**：
1. 已订阅状态
2. 在 Xcode StoreKit Testing Manager 中「到期」或「撤销」该订阅
3. 回到 App
4. 检查 isPremium 是否变为 false
5. 检查之前解锁的内容是否重新锁定

**预期结果**：订阅过期后自动降级为免费用户

- [ ] isPremium 变为 false
- [ ] 付费 Drill 重新显示 BTPremiumLock
- [ ] 角度测试恢复 20 题/天限制
- [ ] 历史恢复 60 天限制
- [ ] ProfileView Pro 徽章消失

### 流程 6：终身买断不过期

**步骤**：
1. 购买终身买断（¥198）
2. 确认 isPremium = true
3. 不做任何过期操作
4. 重启 App
5. 检查 isPremium 仍为 true

**预期结果**：终身买断永不过期

- [ ] 购买成功后 isPremium = true
- [ ] 重启后仍为 true
- [ ] 无过期日期显示

### 流程 7：直接访问付费内容（绕过检查）

**步骤**：
1. 免费用户状态
2. 若可能，尝试通过 URL scheme 或深链直接进入付费 Drill 详情页
3. 或在收藏夹中找到之前收藏的付费 Drill 并点击

**预期结果**：非从列表进入的付费 Drill 仍有遮罩

- [ ] 任何入口进入付费 Drill 都有 BTPremiumLock

### 流程 8：Pro 用户订阅管理面板

**步骤**：
1. 已订阅状态（isPremium = true）
2.「我的」Tab → 点击「订阅管理」菜单项
3. 进入 SubscriptionStatusView（非 SubscriptionView Sheet）
4. 查看 Pro 状态卡（crown 图标 + 订阅类型 + 有效期）
5. 点击「管理订阅」按钮
6. 点击「恢复购买」按钮
7. 查看「已解锁功能」列表（6 项）

**预期结果**：Pro 用户可管理订阅状态

- [ ] 进入 SubscriptionStatusView 而非 SubscriptionView
- [ ] Pro 状态卡显示订阅类型（终身买断/年度/月度）
- [ ] 有效期显示正确（永久有效 / 自动续费中）
- [ ]「管理订阅」打开 App Store 订阅管理页
- [ ]「恢复购买」功能正常 + Alert 提示
- [ ]「已解锁功能」列表 6 项完整

---

## 四、交互响应

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| I-01 | 方案卡片 | 点击 3 个卡片切换选中态即时 | [ ] |
| I-02 | 「订阅」按钮 | 点击后显示 ProgressView，不可重复点击 | [ ] |
| I-03 | 「恢复购买」按钮 | 点击后有加载态，完成后有结果提示 | [ ] |
| I-04 | Sheet 关闭 | SubscriptionView Sheet 下拉关闭正常 | [ ] |
| I-05 | 隐私政策链接 | 点击跳转外部浏览器（或占位 URL） | [ ] |

---

## 五、边界场景

| # | 场景 | 检查项 | 通过 |
|---|------|--------|------|
| E-01 | 网络断开时购买 | StoreKit 返回错误，App 不崩溃，显示友好提示 | [ ] |
| E-02 | 购买取消 | 用户取消 StoreKit 弹窗后 App 不崩溃，无错误残留 | [ ] |
| E-03 | 重复购买 | 已订阅状态下再次点击购买，StoreKit 处理正确 | [ ] |
| E-04 | 已解锁免费功能不降级 | 购买 → 过期后，之前免费功能（基础 Drill、beginner 计划）仍可用 | [ ] |
| E-05 | App 启动时自动校验 | 冷启动后 isPremium 状态正确（通过 Transaction.currentEntitlements） | [ ] |

---

## 六、设备矩阵

| # | 设备 | 核心流程通过 | 布局正常 | 备注 |
|---|------|------------|---------|------|
| DM-01 | iPhone SE 3rd（4.7"） | [ ] | [ ] | 3 列卡片在小屏上是否挤压 |
| DM-02 | iPhone 17 Pro（6.3"） | [ ] | [ ] | |
| DM-03 | iPhone 17 Pro Max（6.9"） | [ ] | [ ] | |

---

## 七、可访问性

| # | 检查项 | 通过 |
|---|--------|------|
| AC-01 | Dynamic Type 最大字号下方案卡片价格可读 | [ ] |
| AC-02 | VoiceOver 可朗读方案名称和价格 | [ ] |

---

## 八、性能

| # | 指标 | 阈值 | 通过 |
|---|------|------|------|
| PF-01 | SubscriptionView 打开到价格展示 | < 2 秒 | [ ] |
| PF-02 | 购买完成到 UI 状态更新 | < 1 秒 | [ ] |
| PF-03 | 恢复购买耗时 | < 3 秒 | [ ] |

---

## 测试结果

| 项目 | 内容 |
|------|------|
| 测试人 | |
| 日期 | YYYY-MM-DD |
| 设备 | [型号 + iOS 版本] |
| 构建版本 | [Build number] |
| 总体结论 | 通过 / 有问题（详见下方） |

### 发现的问题

| # | 严重程度 | 页面/流程 | 描述 | 关联检查项 |
|---|---------|----------|------|-----------|
| | | | | |
