# E-04 Dark Mode 开发标注 — 个人中心 + 登录

> 策略变更：不再通过 Stitch 生成 Dark Mode 截图，改为基于已验证的 Token 表直接标注开发。
> 通用 Token 映射参见 `dark-mode-rules.md` DM-001 及 E-02 通用规则表，此文档仅列出**超出标准映射的特殊处理**。
>
> **排除页面**: P2-04 OnboardingView（品牌首屏保持浅色）/ P2-06 SubscriptionView（自身已深色）

---

## 页面 1: ProfileView 已登录态 — 对应 P2-03 帧1

**Light Mode 参考**: `tasks/P2-03/stitch_task_p2_03_userprofile_02/screen.png`

### 特殊处理

**1. 多色菜单图标容器**
- 每个菜单行左侧有 30pt 彩色圆形 + 白色 SF Symbol
- 各颜色在 `#1C1C1E` 卡片上的对比度需逐一验证：

| 菜单项 | 图标圆底色 | Dark 下处理 |
|--------|-----------|------------|
| 训练设置 | 品牌绿 | `#25A25A` → 保持 |
| 通知 | 红色 | `#EF5350` → btDestructive Dark |
| 数据导出 | 蓝色 | `#0A84FF` → iOS systemBlue Dark |
| 帮助 | 紫色 | `#BF5AF2` → iOS systemPurple Dark |
| 关于 | 灰色 | `rgba(235,235,240,0.3)` 底 + 白图标 |

- 原则：使用 iOS systemColor 的 Dark variant，自动适配

**2. 用户头像/昵称区域**
- 头像占位：`#2C2C2E` 背景圆 + 白色人形 SF Symbol
- 昵称：`#FFFFFF` 17pt Semibold
- 邮箱/ID：`rgba(235,235,240,0.6)`
- 如有真实头像：添加 0.5pt `#38383A` 描边避免融合

**3. 统计数字行**
- 数字（训练次数/小时数/天数）：`#FFFFFF` 22pt Bold
- 单位标签：`rgba(235,235,240,0.6)` 13pt

**4. 退出登录按钮**
- 文字色：`#EF5350`（btDestructive Dark）
- Stitch 渲染色偏已标注（D-REVIEW 观察 5），开发必须精确使用 `#EF5350`

**5. Tab 根页面大标题**
- 「我的」34pt Bold Rounded → `#FFFFFF`

---

## 页面 2: ProfileView 访客态 — 对应 P2-03 帧2

**Light Mode 参考**: `tasks/P2-03/stitch_task_p2_03_guestprofile_02/screen.png`

### 特殊处理

**1. Pro 推广卡 ⚠️ 需重点处理**
- Light：`#1C1C1E` 深色卡片在白色页面上突出
- Dark：整页已是 `#000000`，深色卡片 `#1C1C1E` 仍可区分（色差保持）
- 金色文字 `#F0AD30` + 金色皇冠图标 → 保持不变
- 如果对比度不足，添加 1pt `#38383A` 描边增强卡片边界

**2. 登录/注册 CTA**
- 「登录/注册」按钮：`#25A25A` 品牌绿填充 + 白字
- 置于页面中上部（头像占位区域下方）

**3. 访客菜单**
- 可见菜单行减少（无「退出登录」）
- 菜单图标规则同页面 1

---

## 页面 3: LoginView Sheet — 对应 P2-05 帧1

**Light Mode 参考**: `tasks/P2-05/stitch_task_02_05_loginview_02/screen.png`

### 特殊处理

**1. Sheet 容器**
- Light：白底 + 顶部圆角 + 拖拽条
- Dark：`#1C1C1E` 底 + 顶部圆角 + `#3A3A3C` 拖拽条
- 底层 dimming：`rgba(0,0,0,0.5)` → 保持不变

**2. 三种登录按钮 ⚠️ 需逐一适配（P2-05 决策 2）**

| 按钮 | Light | Dark |
|------|-------|------|
| Apple 登录 | 黑底 `#000000` + 白字 + 白 Apple Logo | **白底 `#FFFFFF` + 黑字 + 黑 Apple Logo**（Apple HIG Dark 规范） |
| 微信登录 | `#07C160` 绿底 + 白字 + 白微信 Logo | **保持不变** `#07C160` + 白字（微信品牌色不随模式变） |
| 手机号登录 | 白底 + `#1A6B3C` 描边 + 绿字 | `#2C2C2E` 底 + `#25A25A` 描边 + `#25A25A` 文字 |

- Apple 登录按钮必须遵循 Apple Human Interface Guidelines 的 Dark variant

**3. 品牌视觉区**
- Logo 区域：确保 Logo 有白色/亮色变体，或在 Dark Sheet 上可见
- 「欢迎使用球迹」标题：`#FFFFFF`
- 副标题：`rgba(235,235,240,0.6)`

**4. 底部链接**
- 「暂不登录」：`rgba(235,235,240,0.6)`
- 条款/隐私链接：`#25A25A` 下划线

---

## 页面 4: PhoneLoginView — 对应 P2-05 帧2

**Light Mode 参考**: `tasks/P2-05/stitch_task_02_05_phoneloginview/screen.png`

### 特殊处理

**1. 输入框组**
- 手机号输入框：`#2C2C2E` 底 + `#FFFFFF` 输入文字 + `rgba(235,235,240,0.3)` 占位符
- 区号前缀 `+86`：`#FFFFFF`
- 输入框焦点态：`#25A25A` 2pt 描边

**2. 发送验证码药丸按钮**
- 可用态：`#25A25A` 填充 + 白字
- 冷却倒计时态：`#3A3A3C` 填充 + `rgba(235,235,240,0.3)` 文字

**3. 登录按钮**
- 可用态：`#25A25A` 填充 + 白字，全宽
- 禁用态：`#3A3A3C` 填充 + `rgba(235,235,240,0.3)` 文字

**4. 导航栏**
- push 子页面：返回箭头 + `#25A25A` 返回文字
- 页面标题「手机登录」：`#FFFFFF`

**5. Stitch 装饰元素**
- Light Mode 中 Stitch 添加的灰色圆形装饰（D-REVIEW 观察 4）→ 开发时忽略

---

## 开发 Checklist

- [ ] ProfileView 已登录: 多色菜单图标使用 iOS systemColor Dark variant
- [ ] ProfileView 已登录: 退出登录精确使用 `#EF5350`
- [ ] ProfileView 已登录: 头像占位/真实头像在 Dark 下的边缘处理
- [ ] ProfileView 访客: Pro 推广卡 `#1C1C1E` 在 `#000000` 页面上的边界清晰度
- [ ] LoginView Sheet: 容器背景 `#1C1C1E` + 拖拽条 `#3A3A3C`
- [ ] LoginView Sheet: Apple 按钮反转为白底黑字（Apple HIG Dark）
- [ ] LoginView Sheet: 微信按钮保持 `#07C160` 不变
- [ ] LoginView Sheet: 手机号按钮 `#2C2C2E` 底 + `#25A25A` 描边
- [ ] PhoneLoginView: 输入框 `#2C2C2E` + 焦点绿框 + 占位符 30%
- [ ] PhoneLoginView: 发送验证码/登录按钮的可用/禁用/冷却三态
- [ ] 全部页面: 状态栏白色文字、无卡片阴影
- [ ] 排除确认: P2-04 OnboardingView 不做 Dark、P2-06 SubscriptionView 自身已深色
