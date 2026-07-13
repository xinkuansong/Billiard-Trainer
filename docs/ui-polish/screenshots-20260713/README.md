# App 全页截图基线（2026-07-13）

> 由 `ScreenshotTourUITests` 在 **iPhone 17 Pro** 模拟器生成。
> **外观由模拟器控制**：`xcrun simctl ui booted appearance light|dark`（测试内反复设 `XCUIDevice.appearance` 易把 Runner 打崩，已避免）。
> 落盘：`echo light|dark > /tmp/qiuji-uitest/appearance` → `snap()` 写入本目录对应子文件夹。

## 目录

| 子目录 | 张数 | 说明 |
|--------|------|------|
| `dark/` | 43 | 完整（含订阅 Paywall 60/61） |
| `light/` | 41 | 缺 `60`/`61` 订阅（§8.1-③ 强制深色，与 dark 观感相同，未强求） |

软链：`docs/ui-polish/screenshots-latest` → 本目录。

## 明暗策略（看图前先读）

按 `UI-IMPLEMENTATION-SPEC` §8.1：

| 档 | 行为 | 示例 |
|---|---|---|
| ① 场景页 | **设计上恒黑底**，浅/深系统外观下观感几乎一样 | 分离角、自由走位/击球、思路/打三/斯诺克、翻袋/反射、2D/3D 瞄准… |
| ② 常规页 | **跟随模拟器外观** | 训练首页、动作库、练习首页、记录、我的 |
| ③ 特例 | 强制配色 | 订阅 Paywall=强 dark；Onboarding=强 light |

因此：对比浅/深应主要看 **常规页**（如 `01-training-home`、`05-drill-library`、`08*-angle-home*`、`40-history*`、`50-profile*`）。场景页两套截图都会偏黑，属预期而非漏切外观。

## 复跑

```bash
# 深色
xcrun simctl ui booted appearance dark
mkdir -p /tmp/qiuji-uitest && echo dark > /tmp/qiuji-uitest/appearance
xcodebuild test -project QiuJi.xcodeproj -scheme QiuJi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:'QiuJiUITests/ScreenshotTourUITests/testFullScreenshotTour'

# 浅色（SceneKit 连开易崩时用分段补拍）
xcrun simctl ui booted appearance light
echo light > /tmp/qiuji-uitest/appearance
xcodebuild test ... -only-testing:'.../testFullScreenshotTour'
# 若中断：-only-testing:'.../testScreenshotTourPlaySolveRemainder'
```

## 文件命名

与初版相同：`00` 启动 → `01–07` 训练/动作库 → `08–28` 练习全入口 → `40–41` 记录 → `50–55` 我的 → `60–61` 订阅。
