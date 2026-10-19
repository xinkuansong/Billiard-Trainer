# 本周训练背景宽屏修复

日期：2026-10-18。范围：训练首页周卡摄影背景，手机保持现有效果，iPad 横竖屏白球完整且尺寸协调。用户已授权实施并要求原生截图复阅。

## U-01 · iPad 白球放大与裁切（P2）

- 旧原生证据：`output/weekly-background-review-20261018/E15-pad-portrait-light-003.png` 与 `E15-pad-landscape-r4-light-003.png`。来自 Mac mini 归档的 E15 原生采集，回传 SHA-256 与原清单一致。横屏原始 PNG 编码方向需顺时针旋转 90° 查看。
- 根因：固定 2:1 摄影随卡片宽度等比铺满；卡片高度由原生内容决定，iPad 横向扩宽使白球过大且顶端被裁切。
- 实施：`BTTrainingAtmosphere.keepsWeeklySubjectScale` 默认 false，仅周卡开启；regular 宽卡将照片主体的球径控制为约 64pt（原1774×887图中球宽262px），保留整张照片中球、阴影与球杆的关系。左侧空台呢半幅交替镜像延展，接缝两侧来自同一源边缘。窄卡与 compact 手机沿用原有 scaledToFill，登录背景默认行为保持。
- 未修改字体、卡片高度、按钮、数据口径或原始图片；不新增图片资产。

## 验证

已完成：本地 Xcode 26.2 专项 App/UI 测试构建通过；构建产物 1,238 个文件校验一致后，使用 Mac mini 的 iOS 26.2 运行同一产物。三次专项 UI 测试全部通过，0失败、0跳过；10张截图回传 SHA-256 全部一致。源码与构建前记录的哈希仍一致。

| 设备 | 范围 | 结果 |
|---|---|---|
| iPad Pro 11-inch (M4) | 浅/深色各竖→横→竖，6图 | 白球完整、球杆/阴影连续、横竖球径约64pt，无按钮/日期遮挡；转回深色竖屏与首次竖屏截图逐字节一致 |
| iPhone 17 Pro | 浅/深色竖屏，2图 | 保留原scaledToFill构图，白球完整 |
| iPhone SE 3 | 浅/深色竖屏，2图 | 保留原构图，白球完整 |

UI 用例检查页面身份、44pt清台入口及可点击性与方向；球形、位置和台呢接缝另经原生截图目视检查。浅色iPad/SE顶部有系统“Apple智能已就绪”通知，周卡未被遮挡，保留原图；对外展示无通知的深色图。测试为默认字号large，未覆盖超大辅助字号、分屏、其他iPad尺寸及真机。

首次普通测试构建被并行开发中的`CustomFormationTests.swift`缺失成员编译错误阻断；为本次视觉验证临时建立只含App/UI测试的scheme，专项构建成功后已移除临时scheme，副本和失败日志保留在证据目录。本次通过不代表全量单元测试通过。本机模拟器池达到容量上限，未占用其他任务设备；远端使用共享worker锁串行运行，三台任务临时设备在证据导出后由生命周期入口回收。

原图与完整测试结果：`output/weekly-background-review-20261018/remote/{pad,phone,compact}/`；每组含`result.json`、`test-summary.json`、`result.xcresult`、`test.log`和`shots/`。构建日志为`build-focused.log`，一致性摘要为`verification.json`。

- [iPad竖屏原图](../../output/weekly-background-review-20261018/remote/pad/shots/weekly-responsive-Dark-0-portrait.png)
- [iPad横屏原图](../../output/weekly-background-review-20261018/remote/pad/shots/weekly-responsive-Dark-1-landscape.png)
- [手机原图](../../output/weekly-background-review-20261018/remote/phone/shots/weekly-responsive-Dark-0-portrait.png)

证据根：`output/weekly-background-review-20261018/`。未装真机、未提交、未发布；用户视觉复阅待截图交付。
