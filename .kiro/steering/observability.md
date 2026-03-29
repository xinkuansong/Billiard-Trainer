# 可观测性策略（Steering）

> **版本**：0.1 | **最后更新**：2026-03-24

## 原则

- **不引入第三方分析 SDK**（Crashlytics、Amplitude 等）— 避免 PIPL 用户数据出境风险与 Privacy Manifest 复杂度。
- 使用 Apple 原生工具链，零额外权限，审核友好。

## 崩溃上报

| 工具 | 接入方式 | 查看位置 |
|------|----------|----------|
| **Xcode Organizer** | 无需集成，TestFlight / App Store 自动收集 | Xcode → Window → Organizer → Crashes |
| **MetricKit** | 可选，用于收集挂起率、启动时间等指标 | App 内回调，写入本地日志文件 |

**实现规范**：
- 不做自定义崩溃上报；依靠 TestFlight + App Store 的符号化崩溃日志。
- 发布前在 Archive 步骤上传 dSYM（由 `scripts/Makefile` 中 `archive` target 处理）。

## 用户行为分析

| 工具 | 用途 |
|------|------|
| **App Store Connect Analytics** | DAU、留存率、订阅转化漏斗、功能下载量 |
| **StoreKit 2 Transaction 回调** | 本地记录 IAP 购买时间点，不上传第三方 |

**Freemium 转化关键指标**（App Store Connect 内追踪）：
- 动作库 L1+ Drill 查看量（触发付费引导）
- 角度测试每日次数上限触碰次数
- 订阅页打开率 → 购买完成率

## 本地日志

```swift
// 使用 os_log，不收集用户标识，不上传
import OSLog
private let logger = Logger(subsystem: "com.yourname.billiardtrainer", category: "DataSync")
logger.info("Drill content refresh completed: \(drillCount) drills")
```

- Category 规范：`Auth` / `DataSync` / `AngleTraining` / `Subscription` / `UI`
- 日志仅在 Debug 构建完整输出；Release 构建隐去 `.private` 标记字段。
- **不**在日志中出现用户 ID、手机号、微信 openid 明文。

## Privacy Manifest 关联

- 不使用需要声明的系统 API（如 `UserDefaults` 用于跟踪目的）时，Privacy Manifest 的 `NSPrivacyAccessedAPITypes` 为空或仅含必要项。
- 详见 `tasks/compliance-checklist.md`。
