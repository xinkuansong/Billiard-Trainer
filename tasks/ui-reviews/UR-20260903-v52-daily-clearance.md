# UR-20260903 — v52 每日清台系统验收

## 结论

问题集合 v52 W0–W4 已完成。每日清台的规则、确定性开球、恢复、首页三态、设置隔离、单人工具记录边界和普通自由击球回归均有自动化证据；iPhone SE、iPhone 17 Pro、iPad mini 的 Light/Dark 与最大字号截图已做原图目检，未发现入口、关键状态或操作控件裁切/覆盖。

## 自动化结果

| 范围 | 结果 | 证据 |
|---|---:|---|
| v52 + 规则/开球/记录边界单元回归 | 90/90 | `build/v52-qa/unit-regression.xcresult` |
| v52 首页/设置/每日页完整 UI 套件 | 9/9 | `build/v52-qa/ui-v52-final2.xcresult` |
| 普通自由击球、通用开球、两宿主开球、练习入口 | 5/5 | `build/v52-qa/legacy-freeplay-regression.xcresult` |
| SE Dark + AX 最大字号：首页/设置 | 1/1 | `build/v52-qa/matrix-se-dark-max.xcresult` |
| SE Light：无计划、每日页、普通自由击球 | 3/3 | `build/v52-qa/matrix-se-light.xcresult` |
| iPad mini Light + AX 最大字号：首页/设置 | 1/1 | `build/v52-qa/matrix-ipad-light-max.xcresult` |
| iPad mini Dark：无计划首页/返回 | 1/1 | `build/v52-qa/matrix-ipad-dark-final.xcresult` |
| iPad mini Dark：每日自动开球 | 1/1 | `build/v52-qa/matrix-ipad-dark.xcresult` |
| iPhone 17 Pro Dark：首页进行中/完成跨重启 | 1/1 | `build/v52-qa/matrix-17pro-dark.xcresult` |
| 最新源码截图写盘硬化 | 1/1 | `build/v52-qa/post-hardening-ui.xcresult` |
| 首页 AX 标签包含状态 + 玩法 | 1/1 | `build/v52-qa/accessibility-label.xcresult` |
| Debug 构建 | PASS | `make -f scripts/Makefile build` |
| 全链路门禁 | FAIL 0 | `make -f scripts/Makefile verify-gate`；v47 基线为 screenshots=66、routes=69、write-surfaces=128 |

## 设备与外观矩阵

| 设备 | Runtime | 外观/字号 | 覆盖 |
|---|---|---|---|
| iPhone SE (3rd generation) | iOS 17.0 | Light / Large | 无计划入口、返回、每日单人 HUD、普通自由击球 |
| iPhone SE (3rd generation) | iOS 17.0 | Dark / AX XXXL | 有计划首页、继续清台入口、五玩法设置 |
| iPhone 17 Pro | iOS 26.2 | Light / Large | v52 完整 9 项 UI、旧流程 5 项回归 |
| iPhone 17 Pro | iOS 26.2 | Light / AX XXXL | 有计划首页、五玩法设置 |
| iPhone 17 Pro | iOS 26.2 | Dark / Large | 首页进行中/已完成与重启持久化 |
| iPad mini (A17 Pro) | iOS 26.2 | Light / AX XXXL | 有计划首页、五玩法设置 |
| iPad mini (A17 Pro) | iOS 26.2 | Dark / Large | 无计划首页、返回、每日自动开球 |

所有矩阵运行均使用显式 UDID，并在运行前通过 `simctl ui` 回读 appearance/content_size。每日页本身保持既有黑底常量，但仍验证了不同系统外观下的启动、导航栏和系统控件。

## 视觉与无障碍复核

- 首页胶囊入口与「本周训练」标题为独立可点击元素；SE 最大字号下不相交，最小点击高度满足 44pt。
- 设置页五玩法选择器在 SE/iPad 最大字号下可见、可点，说明文案未被关键控件覆盖。
- 每日页使用单人 HUD，未出现「玩家 A / 玩家 B」；中八、9 球均完成 UI 主链。
- 首页入口的 AX 标签包含任务状态和玩法；每日 HUD 组合读出玩法、剩余球、杆数、犯规和用时。
- 截图写盘失败会触发 `XCTFail`，所有证据只写入忽略目录 `build/v52-qa/`。
- 本轮未操作真实 VoiceOver 转子或听取系统朗读；焦点语义以 SwiftUI 元素拆分、标签断言和可点击性检查为证据边界。

## 证据清单

- PNG 哈希清单：`build/v52-qa/manifest.sha256`
- 关键原图：`build/v52-qa/ios17_0/iphonese/dark/max/home-settings/`、`build/v52-qa/ios26_2/ipadmini/light/max/home-settings/`、`build/v52-qa/ios26_2/ipadmini/dark/large/final/`、`build/v52-qa/ios26_2/iphone17pro/light/large/v52-final2/`
- 证据目录为非跟踪构建产物；不回写 `QiuJi/Resources`、`content/` 或既有截图基线。

## 已知非阻塞项

- `xcpretty` 未安装，Makefile 自动回退到原生 `xcodebuild`，最终退出码为 0、构建成功。
- 仍有仓库既存的弃用/Swift 6 预警；本轮未扩大范围处理。
- 一次沙箱内 `xcodebuild` 无法连接 CoreSimulatorService，随后按相同测试范围在获授权模拟器环境重跑并通过；不计为产品失败。
