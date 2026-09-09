# snapshot004 通知允许/拒绝/重试：独立图审

2026-09-07，UI Reviewer；实际通过 `view_image` 逐张打开三次 RUN 的全部 **10 张 PNG**，并核对 retry 的三份 AX 文本、每次 inputs.json、exit.json 和 xcode-test.log。仅审已有证据，没有运行 UI、操作设备、改测试或业务。

## 实际执行而非零测试绿灯

输入均为 snapshot-004 / QiuJi scheme / resume004-DerivedData。下面三个完整方法属于 `QiuJiUITests/SystemBoundaryDiagnosticUITests/`，每次日志实际 Executed **1 test, 0 failures**；各级 suite 重复打印不重复计数。

| RUN（均位于 archive/quality-diagnosis/runs/） | 方法 | make_exit | 方法耗时 | PNG |
|---|---|---:|---:|---:|
| formal-004-notification-allow-ui-001 | testNotificationRealPromptAllowedWithEvidence | 0 | 40.529s | 3 |
| formal-004-notification-deny-ui-001 | testNotificationRealPromptDeniedWithEvidence | 0 | 47.384s | 4 |
| formal-004-notification-deny-retry-ui-001 | testPreviouslyDeniedReminderRetryShowsAppExplanationWithoutSystemPrompt | 0 | 35.974s | 3 |

Allow 使用 `CB246F30-E917-492B-B0C4-511F473D8C15`，Deny 和 retry 使用 `0AFA3D75-DB70-405C-8E4B-B38C5221D0CF`，来自各 run 实际 inputs，不沿用早期 snapshot003 设备准备清单。

## 逐张核对

每行 stem 对应该 RUN 的 screenshots 子目录完整文件名。

| RUN / 文件 stem | 实际图像结果 |
|---|---|
| Allow / system-FC35C4C3-3119-46CD-8E9A-847CE7C27FAC-notification-before-request | 训练目标页，提醒开关灰色且圆钮左侧；说明“首次开启时会请求系统通知权限”，未显示时间选择。 |
| Allow / 同前缀 notification-real-prompt | 屏幕中央真实通知授权样式，标题“‘球迹’想给你发送通知”，通知可包括提醒、声音和图标标记；左“不允许”、右“允许”均完整可见。不是 App 错误提示。 |
| Allow / 同前缀 notification-final-status | 弹框已消失，开关绿色且圆钮右侧；出现“提醒时间 19:00”，页底灰色文案“系统通知权限已开启”可读，但已接近本截图下边缘。未据此宣称所有滚动范围/对比度合规。 |
| Deny / system-3D799483-25F6-4148-8495-F2F5B702ADD7-notification-before-request | 初始灰色关闭开关和首次请求说明，与 Allow 的前置视觉状态一致。 |
| Deny / 同前缀 notification-real-prompt | 同一真实系统授权双按钮提示完整可见。 |
| Deny / 同前缀 notification-denied-explanation | 已变成 App“无法开启提醒”提示；正文要求到设置>通知>球迹允许，只有“知道了”一个按钮；背景开关关闭，页内红色权限未开启说明。 |
| Deny / 同前缀 notification-final-status | App 提示关闭；开关仍灰色左侧，没有时间行，红字“系统通知权限未开启，请前往系统设置允许通知”完整显示。没有拒绝后仍显示已开启的视觉矛盾。 |
| Retry / system-AC2FC213-8C26-4E79-A9DB-6BBF79BE81EC-denied-retry-before | 再入目标页保持灰色关闭与红色拒绝说明。 |
| Retry / 同前缀 denied-retry-app-explanation | 重试出现“无法开启提醒”及单“知道了”；无“允许/不允许”二选项，图像为 App 解释，不是第二次系统授权。 |
| Retry / 同前缀 denied-retry-still-disabled | 知道了之后回目标页，仍关闭与红色拒绝说明、无时间行。 |

原图均为 1206×2622；显示工具缩放至 942×2048 供审阅。未做拼图、重绘或修改，图中通知授权与 App 解释的标题/按钮可直接辨认。

## 日志与 AX 交叉依据

- Allow log:342 实际 `Tap "允许" Button`，354 方法 passed；Deny log:394 实际 `Tap "不允许" Button`，408 `Tap "知道了" Button`，420 方法 passed。截图与点击日志的状态变化一致，不能单靠最终绿色开关推断发生过授权弹框。
- Retry log:332–348 等待并取得“无法开启提醒”、检查按钮存在性、采集 App 与 SpringBoard AX；349 实际点“知道了”，377 passed。此次输入还限定 `TEST_RUNNER_QD_NOTIFICATION_FOLLOWUP_STATE=DENIED_DISABLED`。
- Retry `denied-retry-before-AX.txt:46/48` 和 `still-disabled-AX.txt:46/48` 分别显示 `trainingGoal.reminderEnabled value: 0` 与完整拒绝状态文案。
- Retry `app-explanation-AX.txt:61` 为 `Alert ... label: 无法开启提醒`；69 为系统设置解释；82 为唯一“知道了”按钮。三份 AX 文本含 App 树及 SpringBoard alerts 查询片段；截图时刻没有第二个系统授权双按钮弹框。此为本次观测窗口的证据，不是连续全时段录屏证明永远不会再弹。

## 结论与范围

三个实际方法及十张截图共同支持：本轮正常目标入口触发真实系统通知授权；选择允许后 UI 开启并显示19:00；选择拒绝后 App 解释且开关保持关闭；已拒绝状态重试走 App 单按钮解释，结束后仍关闭。本图审范围内未发现阻挡授权选择、拒绝后误显开启或解释类型混淆。

没有检查 OS pending 内容/时分和数量，不能从开关绿色证明调度成功；这些属于主控独立宿主 pending 检查。允许后的时间变更、关闭取消、系统设置恢复授权不在这三 RUN 中。也未验证真实送达、锁屏/后台、声音、Focus/摘要、时区/DST、VoiceOver、其他设备字号或全部 SC38。此结论不外推截图外状态及后续运行。
