# 球迹 (QiuJi) 补充设计规范

**生成日期**: 2026-04-05
**来源**: Phase A~E 一致性审核 + 设计决策提炼

---

## 一、组件级一致性规则

### 1.1 BTButton 使用规范

| 层级 | 样式 | 适用场景 | 禁用规则 |
|------|------|---------|---------|
| Primary (Tier 1) | 品牌绿填充 + 白字 | 页面主操作（唯一） | 同一视图最多 1 个 |
| Secondary (Tier 2) | 黑字描边 / darkPill | 次要操作 | — |
| Text (Tier 3) | 灰字无框 | 弱操作/取消 | — |
| Gold Filled | 金色填充 + 白字 | Pro 解锁/订阅 CTA | 仅 Pro 付费场景 |
| Gold Outline | 金色描边 | 渐进式 Pro 提示 | 仅 Pro 提示场景 |
| Destructive | #C62828 文字 | 退出登录/删除 | 仅不可逆操作 |
| darkPill | #1C1C1E 填充 + 白字 | 深色次要按钮 | 仅底栏/叠加场景 |

### 1.2 BTEmptyState 使用规范

| 属性 | 规范 |
|------|------|
| 图标 | 48pt SF Symbol，品牌绿 30% 圆形底 |
| 标题 | 17pt Semibold |
| 副标题 | 15pt Regular 灰色 |
| CTA（可选）| Primary 按钮，文案指向解决方案 |
| 适用 | 训练空态(P0-02)、搜索无结果(P1-02)、日历空(P1-08)、收藏空(P2-07) |

### 1.3 PRO/Premium 视觉体系

| 元素 | Light Mode | Dark Mode |
|------|-----------|-----------|
| PRO 徽章 | `rgba(212,148,26,0.12)` 底 + `#D4941A` 字 | `rgba(240,173,48,0.15)` 底 + `#F0AD30` 字 |
| 锁图标容器 | `#FFDDAF` 浅琥珀圆 + `#D4941A` 锁 | `rgba(240,173,48,0.20)` 圆 + `#F0AD30` 锁 |
| 金色填充 CTA | `#D4941A` + 白字 | `#F0AD30` + 白字 |
| 渐进式锁（P1-04）| 隐藏内容 + 金描边 | 同 + Dark 适配 |
| 全遮罩锁（P1-10）| 渐变磨砂 + 卡片剪影 + 金填充 | 黑色渐变 + 琥珀 20% |
| Pro 推广卡 | `#1C1C1E` 深色卡在白页 | `#1C1C1E` 卡在黑页（可加描边） |

### 1.4 Tab 栏规范

| 属性 | 规范 |
|------|------|
| Tab 数量 | 5 个：训练/动作库/角度/记录/我的 |
| 激活态 | 品牌绿图标 + 文字 |
| 未激活态 | 灰色图标 + 文字 |
| 隐藏条件 | push 子页面、全屏沉浸、Sheet 模态、独立全屏 |
| Tab 文案 | 固定为上述 5 个，「动作库」非「题库」 |

### 1.5 导航栏规范

| 场景 | 标题 | 返回 | 右侧 |
|------|------|------|------|
| Tab 根页 | 34pt Bold Rounded 大标题 | 无 | 视页面而定 |
| push 子页 | 17pt Semibold 居中 | 品牌绿返回箭头+文字 | 视页面而定 |
| Sheet | 17pt Semibold 居中 | 无（拖拽关闭）| 视页面而定 |
| 全屏沉浸 | 毛玻璃双行标题 | 品牌绿「结束」或关闭 | 视页面而定 |

---

## 二、已知偏差处理指南

所有偏差均由 Stitch AI 渲染限制导致，已在各阶段审核中标注。开发时必须按指定基准实施。

### 2.1 Light Mode 已知偏差（7 项）

| 编号 | 偏差描述 | 偏差页面 | 开发基准 |
|------|---------|---------|---------|
| L-1 | 底部添加按钮渲染为蓝色 | P0-03 | 使用品牌绿 #1A6B3C（参照 P0-04）|
| L-2 | 大标题居中且偏小 | P1-09 | 左对齐 34pt Bold Rounded（参照 P1-07）|
| L-3 | 卡片左侧绿线装饰 | P1-09 | 统计页面专属，非偏差，保留 |
| L-4 | 缩略图为电钻 stock 图 | P2-07 | 替换为台球场景照片 |
| L-5 | Tab 文字显示「题库」 | P2-08 | 使用「动作库」（参照 P1-01）|
| L-6 | 退出登录按钮色偏 | P2-03 | 使用 #C62828 destructive red |
| L-7 | 卡片圆角渲染为 8px | P2-07 | 使用 BTRadius.md = 12pt |

### 2.2 Dark Mode 已知偏差（7 项）

| 编号 | 偏差描述 | 偏差帧 | 开发基准 |
|------|---------|--------|---------|
| D-1 | Chip 选中态白色描边 | E-01 帧1 | #F2F2F7 填充 + 黑字 |
| D-2 | 球台区琥珀装饰边框 | E-01 帧3 | 参照 P0-04 无边框 |
| D-3 | 训练明细「详情」标签 | E-01 帧4 | 跟随 Light Mode P0-06 |
| D-4 | 底部显示 Tab 栏 | E-01 帧5a | push 子页面不显示 Tab |
| D-5 | PRO/Level 徽章合并 | E-01 帧5a | 分别独立显示 |
| D-6 | 缺少列表 chevron | E-01 帧5a | 补充 chevron 指示器 |
| D-7 | PlanDetailView Dark 未交付 | E-01 帧5b | 使用标准 Token 映射 |

---

## 三、Stitch AI 工具使用经验

### 3.1 成功模式

1. **组件文档风格**（Phase A）：Stitch 擅长生成组件参考表，截图和 code.html 质量高
2. **单页面完整生成**（Phase B~D）：给出明确的 393px 画布 + 完整布局描述，通常 1~2 轮迭代
3. **同会话修正指令**（E-01）：附图 + 明确指令（pixel-identical color remap）比长提示词更有效

### 3.2 已知限制

1. **DESIGN.md 不跟踪变更**：多轮生成后 DESIGN.md 不更新，以 code.html/screen.png 为准
2. **Tailwind primary 偏移**：Stitch 可能将 primary 渲染为默认蓝色，需显式指定 HEX
3. **精确颜色映射弱**：Dark Mode pixel-identical 场景下，长提示词约束力不足
4. **装饰元素添加**：Stitch 可能添加文档外的装饰元素（如灰色圆形、渐变背景），开发时忽略

### 3.3 策略建议

- 组件库和 Light Mode 页面：推荐使用 Stitch 生成
- Dark Mode 页面：推荐使用 Token 表 + 开发标注文档，1~2 个 Stitch 参考帧即可
- 复杂页面：v2 修正优于重新生成

---

## 四、SwiftUI 实施建议

### 4.1 颜色系统

```swift
// Asset Catalog 配置 Light/Dark 双值
// 或代码中使用条件
extension Color {
    static let btPrimary = Color("btPrimary")       // Light: #1A6B3C / Dark: #25A25A
    static let btAccent = Color("btAccent")          // Light: #D4941A / Dark: #F0AD30
    static let btDestructive = Color("btDestructive") // Light: #C62828 / Dark: #EF5350
    // ...
}
```

### 4.2 阴影处理

```swift
.shadow(
    color: colorScheme == .dark ? .clear : Color.black.opacity(0.1),
    radius: 8, x: 0, y: 2
)
```

### 4.3 缩略图边缘

```swift
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
)
```
