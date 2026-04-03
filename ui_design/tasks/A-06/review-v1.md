# 审核报告 — A-06 v1

**审核日期**: 2026-04-03
**截图**: ⚠️ screen.png 缺失，基于 code.html 结构审核
**整体评分**: ⭐⭐⭐☆☆ (3/5)

## ✅ 通过项

1. **三个核心组件区块完整**：BTSegmentedTab、BTTogglePillGroup、BTOverflowMenu 三个区块均存在，结构正确
2. **品牌色正确**：Tailwind config 中 primary 为 `#1A6B3C`，code.html 中实际引用正确
3. **危险色正确**：error 为 `#C62828`，BTOverflowMenu 删除项使用了红色图标和红色文字
4. **BTSegmentedTab 下划线 2pt**：`h-[2pt] bg-primary rounded-full` 正确
5. **BTSegmentedTab 双示例**：2 标签（历史/统计）和 3 标签（官方计划/自定义模版/个人计划(AI)）均展示
6. **BTTogglePillGroup 三组示例**：2/3/4 胶囊示例均展示，高度 36pt、圆角 full、选中绿色/未选中白底灰边框
7. **BTTogglePillGroup 边框色**：使用 `#D1D1D6` (outline) 符合规范
8. **BTOverflowMenu 浮层**：白色圆角卡片 + 阴影 + 5 项菜单（含 1 项危险操作）
9. **各区块均有规格摘要和使用场景注释**
10. **无渐变**：所有颜色填充均为纯色

## ⚠️ 问题项（需修改）

### P1: 存在顶部导航栏（必须移除）
- **当前表现**: 有一个 sticky 导航栏，含 glassmorphism 毛玻璃效果（`bg-white/70 backdrop-blur-xl`）、"Component Reference" 标题和 "QiuJi UI v1.0" 文字
- **期望表现**: 无导航栏，页面直接从第一个区块标题开始（与 A-01~A-05 一致的纯文档风格）
- **来源**: A-02 决策 1，A-03~A-05 延续

### P2: 存在多余的 "Drill Setup Reference" 区块
- **当前表现**: 页面底部有一个额外的 "Drill Setup Reference" 区块，包含一张球台照片和 "START DRILL" 按钮
- **期望表现**: 页面只包含 3 个指定组件区块（BTSegmentedTab、BTTogglePillGroup、BTOverflowMenu），不应有额外内容
- **影响**: 偏离任务定义，添加了与组件表无关的内容

### P3: 存在底部 Footer
- **当前表现**: 底部有 "© 2024 QiuJi (球迹) Design Guidelines" 版权信息和 "Precise Tactician System" 文字
- **期望表现**: 无 Footer，最后一个组件卡片后即结束

### P4: BTOverflowMenu 触发图标方向错误
- **当前表现**: 使用 `more_horiz`（水平三点 "⋯"）
- **期望表现**: 使用 `more_vert`（垂直三点 "⋮"），与设计文档 3.6.8 描述一致（三点「⋮」图标按钮）

### P5: BTOverflowMenu 图标圆底尺寸偏大
- **当前表现**: 图标圆底为 `w-8 h-8`（32px）
- **期望表现**: 24pt 圆底（设计文档 3.6.8 明确标注 "24pt 彩色圆形底"）

### P6: 卡片使用了绿色调阴影（与 A-01~A-05 风格不一致）
- **当前表现**: 所有白色卡片使用 `shadow-[0_4px_20px_rgba(26,107,60,0.08)]`（绿色色调阴影），这是 Stitch "Precise Tactician" 创意发挥
- **期望表现**: 与 A-01~A-05 一致的简洁白色卡片，不使用彩色阴影（对照 A-05 截图，卡片无可见阴影）

## 💡 建议项（可选优化）

1. **BTSegmentedTab 字重**: code 中使用 `font-semibold`（600），设计文档标注 16pt Medium（500）。视觉差异较小，不阻塞通过
2. **BTTogglePillGroup 文字字重**: 同上，使用 `font-semibold` 而非 Medium。不阻塞
3. **BTOverflowMenu 最后一条分隔线未缩进**: 危险项上方的分隔线没有 `mx-4` 缩进，与其他分隔线不一致。可视为有意区分危险区域，或统一缩进
4. **缺少 screen.png**: Stitch 导出应包含 screen.png，请确认是否需要重新导出

## 验收标准核对

- [x] BTSegmentedTab：水平文本标签（16pt）+ 活跃项品牌绿文字 + 底部 2pt 品牌色下划线 + 非活跃项灰色
- [x] BTTogglePillGroup：选中品牌绿填充白字 / 未选中白底灰边框黑字，36pt 高，999pt 圆角
- [ ] BTOverflowMenu：白色圆角浮层 + 菜单项含彩色圆形底图标 + 危险项红色 — **图标方向错误(P4)、圆底尺寸偏大(P5)**
- [x] 标签间距 24pt
- [ ] 组件表不含导航栏/Tab 栏 — **存在导航栏(P1)**
- [ ] 整体视觉风格与 A-01~A-05 一致 — **绿色调阴影(P6)、多余区块(P2)、Footer(P3)**
- [x] 品牌色确认为 #1A6B3C，纯色填充无渐变

## DESIGN.md 偏离项（延续 A-01 决策 3：以 code.html 为准）

| 偏离项 | DESIGN.md 声明 | 我方规范 |
|--------|---------------|---------|
| "No-Line Rule" | 禁止使用 1px 边框 | 我们的分隔线/边框按需使用 |
| "Glassmorphism" | 导航栏毛玻璃效果 | 组件表无导航栏 |
| "Divider Forbiddance" | 禁止列表分隔线 | BTOverflowMenu 需要分隔线 |
| 文字颜色 | 不用纯黑 #000000，用 #1A1C1A | 我们使用 #000000 |

## 结论

- [ ] **通过** — 可标记为 done
- [x] **需修改** — 修改后重新生成

**共 6 个问题项**，其中 P1/P2/P3 为结构性问题（多余元素），P4/P5 为组件细节问题，P6 为跨任务一致性问题。建议在 Stitch 同一对话中发送修正指令。
