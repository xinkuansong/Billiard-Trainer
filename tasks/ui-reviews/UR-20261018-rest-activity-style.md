# 组间休息实时活动统一样式 — 2026-10-18

**实现与本轮模拟器视觉复核完成，待用户实看。** 原浅底白字问题已修复；锁屏卡片与灵动岛采用统一对比色及信息层级，结束训练后的清除在多种设备上复验通过。未安装真机、提交主仓库、推送或发布。

## 设计与实现

- [Figma 组件稿](https://www.figma.com/design/fBUN7snC3hYiuLK9eBUndl?node-id=3-18)：可编辑 Card `3:23`、Expanded `3:32`、Compact `3:39`、Minimal `3:42`，共用变量、文本样式与计时图标组件 `10:84`。
- `RestTimerLiveActivity.swift` 与四个命名颜色资源统一深灰底 `#1C1C1E`、主字白、辅字 `#C7C7CC`、品牌亮绿 `#68C88A`。主字/辅字/绿色相对背景计算对比度分别为 17.01/10.10/8.28；实际原图另审，不将数值替代视觉验证。
- 锁屏采用 44pt 原生进度环、可伸缩动作名列和固有宽度的 28pt 粗体倒计时；可用宽度不足时使用上下排列。iPad 与手机共用布局规则，系统决定外框与可用宽度。
- 展开灵动岛补全动作名，标题/图标使用亮绿，倒计时保持白色，底部使用原生动态进度；按用户圈图反馈追加展开态左右28pt、上下20pt系统内容边距，避免圆角裁切图标与进度两端；紧凑与最小态沿用系统区域。计时与进度均由系统驱动。
- Figma 服务中 SF Pro 实际渲染为零宽，预览采用 Noto Sans SC 和可编辑图标示意；App 使用系统字体、SF Symbol `timer` 和动态 ProgressView。Apple 组件库导入无权限，未使用其官方实例。设计示意资源不替代原生动态控件。
- 前轮 `endTraining() → cleanup() → stopRestTimer()` 与 `.immediate` 清除继续生效；本轮未改保存、计时生命周期或提醒策略。

## Mac mini 验证

Xcode 26.2（17C52）/ macOS 26.2，统一 FIFO。8 类代表设备、8 项 UI 测试、22 次完整训练结束流程、114 张截图；0 UI 失败/跳过（仅指最终选定结果，失败轮次另存）。系统浅/深状态有独立设置与回读，截图时间戳晚于对应配置。观察器使用本机时间、xcresult 使用 Mac mini 时间，三次 SSH 往返采样测得远端快约4.06秒；校验按采样时差统一时间基准，并独立检查 XCTest 日志中每张附件所在的 Light/Dark 阶段，原始时间戳保持不变，见 `clock-offset-samples.json`。iPad 横竖方向按 EXIF 解析后的实际像素尺寸验证。

| 设备 | Runtime | 覆盖 | 系统形态 | 原图 | 最终结果 |
|---|---|---|---|---:|---|
| iPhone 17 | iOS 26.2 | 竖屏，系统浅/深 | 锁屏卡片、紧凑/展开灵动岛 | 12 | 通过 |
| iPad Air 11 M3 | iOS 26.2 | 横/竖屏，系统浅/深 | 锁屏卡片、普通桌面 | 20 | UI 通过；回收曾中断，已恢复 |
| iPhone SE 第3代 | iOS 26.2 | 竖屏，系统浅/深 | 锁屏卡片、普通桌面 | 10 | 通过 |
| iPhone 17 Pro Max | iOS 26.2 | 竖屏，系统浅/深 | 锁屏卡片、紧凑/展开灵动岛 | 12 | 通过 |
| iPhone 16e | iOS 26.2 | 竖屏，系统浅/深 | 锁屏卡片、普通桌面 | 10 | 通过 |
| iPhone 13 mini | iOS 17.0 | 竖屏，系统浅/深 | 锁屏卡片、普通桌面 | 10 | 通过 |
| iPad mini 第6代 | iOS 17.0 | 横/竖屏，系统浅/深 | 锁屏卡片、普通桌面 | 20 | 通过 |
| iPad Air 13 M3 | iOS 26.2 | 横/竖屏，系统浅/深 | 锁屏卡片、普通桌面 | 20 | 通过 |

从正式首页开始训练，通过真实休息按钮及“+30S”延长，采集两分多钟剩余时间下的卡片，随后确认结束，验证心得页、休息浮窗消失、系统卡片移除及稳定桌面；有岛设备额外检查紧凑/展开态。排除了自然倒计时结束导致消失的情况。

114 张完整画面已通过对照板逐图核对，卡片及灵动岛细节另查看原始像素。未见本次组件文字/倒计时重叠或边界裁切，结束后无活动残留。iPad mini 深色竖屏的一张卡片恰逢末位数字过渡动画，原图保留并单独标注。心得页仅作流程证据，不等同于全 App 深色皮肤验收。iPhone 13 mini 的 iOS 17 原图顶部含运行时红色诊断条（rdar:45025538），原样保留，非本组件。

[修复后原图对照页](../../output/rest-activity-design-20261018/review.html) · [修复前记录](UR-20261018-training-end-live-activity.md)。原图、来源、SHA-256、尺寸及逐图结论见 `image-manifest.json`、`visual-review.json`、`verified-results.json`。

## 源码与失败证据

锁屏/无岛设备的生产基线快照 r3：`02042eff55724b470b5ac23ec46f079bae7eefd55ff373fb17d5a51bc4c10c8f`，私有固定 commit `d5249885205e45eb5b7243d6873cff5a170c3b6c`。13 mini 补验快照 r4：`d22554858a0cc7c3892a12fd3206888ac1d889862a576e542dba1fba9d0f7310`，commit `40d5712181e0e4c8d7987457edba28cb2f5132e3`；全集比对仅 UI 测试菜单定位不同，所有 App/扩展生产文件完全一致。SE 最终快照 r5：`2ef23d8e5fa55b2fa2be86570d6d8bfa712d68d67af86f4819d12d681897d8de`，私有 commit `14482b2c1ce5de503499d813f184c6f829f5562e`，相对 r4 仅将菜单测试触摸时长改为 150ms，生产内容仍与 r3 相同。展开态最终修订 r6：`640423da6e6c22f57d247adca6f639e2942aecfedd852ed291fa9b760da83032`，私有 commit `301cbc03fdd5739c01a52cc4a5c4516656950637`，仅增加 expanded 的 contentMargins，iPhone 17 / Pro Max 已重跑；其他六类设备沿用已验证且未变化的锁屏布局和清除逻辑。共享工作区其他变更未冒称暂停或纳入本任务差异。当前任务拥有的源码与最终快照另有哈希比对。

- 初始冻结版默认 scheme 编译既有 `CustomFormationTests` 的过期 API 失败；私有测试快照选择仓库已有 QiuJiUITour scheme。未改主工作区 Makefile、未删单测断言。本轮未重跑成功全量单测；前轮 74 项训练单测只作为历史证据。
- 初版锁屏 semantic title 字重偏轻，改明确 28pt bold 后重新验证；旧图保留 `phone-style-r1/`、`pad11-style-r1/`。
- XCTest 外观 setter 的即时回读未可靠代表系统状态；手机未确认轮移到 `phone-appearance-unconfirmed/`，补跑最终结果。环境控制器仅针对本任务租约，在每个 Light/Dark 阶段设置并回读实际系统外观；记录 `appearance-enforcement.jsonl`，不靠截图文件名判断外观。
- iPad 11 的测试本身通过，但外观轮询与释放租约相撞，触发管理器保护；经停止观察进程、关机、manager recover、queue recover 后解除阻塞。原 failed/interrupted 记录保留，已导出的 20 张图片与通过的 xcresult 可用；恢复记录 `pad11/recovery-*.json`。只回收该任务临时设备，其他设备未动。后续控制器每阶段只查询一次并在 defer 前退出，最终其余任务正常释放。
- 原展开态进度条两端斜切与图标贴边最初误判为系统表现；用户圈图指出后按裁剪缺陷返工，r6 仅收紧展开态内容边距，Figma同步。旧图在 `phone-island-edge-before/`、`max-island-edge-before/`，最终图册替换为复验结果。
- SE 首轮菜单点击后确认框未出现；等待可点击并改点行中心后，r4 浅色通过、深色仍偶发停留在菜单。录像/AX 与合成事件证明点击坐标位于正确行中心，50ms 触摸未触发选择，不能再归因于错位。最终测试改为 150ms 明确触摸，确认框与清除断言均通过，未重试点击或放松校验。此处修订的是测试触摸，不是 App 菜单逻辑；短触摸偶发不响应仍需真机确认，不能外推为该问题已消除。失败轮次 `se-failure/`；随后 r3 在测试前受同型号两台失败设备的配额阻塞，证据在 `se-r3-failure/`。仅退役已备份、已诊断且使用内存测试数据的本任务 SE r2 临时设备，再提交 r4；r4 诊断证据也完整回传后，仅回收其临时 SE，提交 r5。未动其他任务设备。取消的候选任务未计入通过数量。

全过程补充记录见证据目录 `validation-notes.md`；队列原始日志、xcresult 和回传哈希保持原样。

## 验收边界

本轮覆盖常见屏幕/硬件类别，不能外推为每个历史型号与系统版本全部验证。锁屏样式通过系统通知中心采集；物理锁定、常亮屏、熄屏恢复仍需真机。iPad 与无岛机型不标注为拥有灵动岛；多活动最小态、iPad 解锁提醒横幅、最大辅助字号和全部长动作名未单独实测。

系统规则参考 [Apple ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)、[Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities) 与 [XCUIDevice.appearance](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/appearance-swift.property)。
