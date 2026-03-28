# 产品共识摘要（Steering）

> 与 `docs/01`–`docs/08` 对齐；冲突时以 `docs/` 为准并更新本文件。

## 定位

- **产品**：球迹（C 端），中国大陆 App Store。
- **核心**：动作库（Drill）+ 训练记录 + 官方训练计划 + 角度感知训练。
- **不做 v1.0**：AI 摄像、B 端、社交、斯诺克（defer）、教学视频制作（占位）。

## 信息架构

- **5 个 Tab**：训练 / 动作库 / 角度 / 历史 / 我的。
- **账号**：微信 + 手机验证码 + Sign in with Apple（自建 REST API）；匿名可浏览与角度训练，记录仅本地直至登录。
- **内容**：Drill + 官方计划 — CloudKit **公开库**热更新；用户数据 — **自建 REST API（腾讯云 MongoDB）** + 本地 SwiftData 离线优先。

## 商业化

- Freemium + IAP（月/年/终身），无广告；边界见 `docs/08`。

## 视觉风格（摘要）

- **设计参照**：训记 App — 数据即主角，界面退为工具，功能主义极简风。
- **色调**：台球绿主色（`btPrimary` #1A6B3C）+ 金色辅色（`btAccent`）；暗色模式优先。
- **排版**：SF Pro Rounded 标题 + 系统默认正文；数字字号永远大于文字。
- **卡片**：圆角 12pt，无投影，背景色分层（`btBGSecondary`）。
- **唯一视觉重点**：球台 Canvas 动画；其余界面克制、无插图。
- 详细规范见 `.cursor/skills/swiftui-design-system/SKILL.md`。

## 技术栈（摘要）

- iOS 17+，SwiftUI，SwiftData，Canvas 球台动画，纯 Swift 角度计算。

## 内容规模目标

- 约 **72** 项 Drill（8 大类），**6** 套官方计划；动画路径数据工作量大，按 `content-engineering` SOP 分批交付。
