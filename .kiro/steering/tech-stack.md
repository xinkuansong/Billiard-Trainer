# 技术栈与约束（Steering）

> **状态**：进行中 | **版本**：0.2 | **最后更新**：2026-03-29（ADR-002：公开内容 CloudKit → Bundle + 自建 API）

所有实现须遵守本节；变更需 Architect 记录 ADR 并更新 `docs/06` 与讨论记录。

## 平台与语言

| 项 | 选型 |
|----|------|
| 最低系统 | **iOS 17** |
| UI | **SwiftUI** |
| 本地持久化 | **SwiftData** |
| 包管理 | **Swift Package Manager**（首选）；微信 SDK 等若需 CocoaPods 在 `tasks/dependencies.md` 注明 |

## 后端与同步

| 层 | 服务 | 用途 |
|----|------|------|
| 用户认证 + 私有数据 | **自建 REST API（腾讯云 Node.js + MongoDB）** | 微信 / 短信 / Apple 登录（JWT）；训练记录、设置、角度历史等同步 |
| 公开只读内容 | **自建 REST API + Bundle 保底** | Drill / 官方计划 JSON，OTA 与离线一致（ADR-002） |

**原则**：离线优先；自建后端处理用户认证、私有数据同步与（可选）公开内容 OTA。

## 关键能力

- **球台示意**：SwiftUI `Canvas` + `Animation`；路径数据来自内容 JSON；物理常量见 `.kiro/steering/table-geometry.md`。
- **角度模块**：本地 `sin` 等数学；自适应出题算法见 `docs/05` / `docs/00` 讨论定稿。
- **登录合规**：提供第三方登录时须保留 **Sign in with Apple**。

## 代码组织（建议）

- `App` / `Features/<TabName>/` / `Core/`（DesignSystem、Extensions）/ `Data/`（Models、Repositories、Services）/ `Resources/`（bundled fallback JSON）。

## 禁止（除非 ADR）

- 将用户训练数据发往未文档化的第三方分析 SDK（PIPL / 审核风险）。
- 在 App 内引导绕过 IAP 的外部付费链接（违反 `docs/08`）。
