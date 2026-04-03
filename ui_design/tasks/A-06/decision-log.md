# 设计决策日志 — A-06

## 决策 1: BTOverflowMenu 危险项全宽分隔线
- **上下文**: 普通菜单项之间使用缩进分隔线（mx-4），而危险项「删除」上方的分隔线为全宽无缩进
- **选项**: A) 全部统一缩进; B) 危险项上方全宽分隔（有意区分）
- **决策**: 接受全宽分隔作为危险区域的视觉隔断
- **理由**: 全宽分隔线在视觉上将危险操作（删除）与普通操作明确区分，是 iOS 原生 ActionSheet 中常见的分组模式，增强误操作防护感知
- **日期**: 2026-04-03

## 决策 2: DESIGN.md 偏离延续 A-01~A-05 模式
- **上下文**: Stitch 的 DESIGN.md 继续使用 "Precise Tactician" 主题，包含 No-Line Rule、Glassmorphism、Divider Forbiddance 等
- **决策**: 延续 A-01 决策 3 — 以 code.html 和渲染效果为准，DESIGN.md 仅作参考
- **理由**: code.html 中 primary 正确为 #1A6B3C，error 正确为 #C62828，一致性处理
- **日期**: 2026-04-03
