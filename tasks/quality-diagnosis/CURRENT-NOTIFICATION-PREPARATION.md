# SC38 当前通知诊断准备

2026-09-07；只读 snapshot-003；未启动设备、构建、注册或执行。新增只读宿主草稿 `NotificationPendingDiagnosticTests.swift`，原 UI 草稿未修改。所有系统文案候选尚待真实弹框 AX 确认，不能声称当前已观察到。

## 已确认的实际用户路径

`ProfileView` 对游客也呈现 primaryMenuGroup，其中 NavigationLink 文案 **训练目标**、value `trainingGoal`，目的为 `TrainingGoalView(ownerKey:ownerKey, profile:profile)`。不是从偏好设置查找，也不需要登录/Pro。

训练目标页面先显示周目标 1–7 天，提醒区域在下面，须有限滚动到真实可点控件：

| AX identifier | 类型声明/用户文案 | 行为 |
|---|---|---|
| `profile.login` | 游客按钮 | 先核实“游客模式”，拒绝真实账号环境 |
| `trainingGoal.reminderEnabled` | Toggle / 开启提醒 | 初始 false；实际点击才触发授权 |
| `trainingGoal.reminderAuthorization` | Text | 未决定：首次开启时会请求系统通知权限；允许：系统通知权限已开启；拒绝：系统通知权限未开启，请前往系统设置允许通知 |
| `trainingGoal.reminderTime` | DatePicker，hourAndMinute | 只有提醒开启后显示；变更会重新 schedule |

页面 `.task` 仅查询授权状态，**不会请求授权**。开关 setter → `updateReminder` → `TrainingReminderScheduler.enable`：notDetermined 才调用 `requestAuthorization([.alert,.sound,.badge])`，成功后 schedule；denied 不重复请求，回滚偏好 false 并显示 App 提示框 **无法开启提醒** / **知道了**，解释为“系统通知权限未开启。请前往‘设置 > 通知 > 球迹’允许通知后再试。”（实际代码使用中文双引号。）

默认 reminderEnabled false，默认时间 19:00。关闭仅取消指定 pending identifier 并保存 false，**不会撤销系统授权**。改每周目标只改 owner profile，与每日提醒时间无直接调度调用；提醒为每日 repeats，而非按本周未达标天数筛选。

## 最小执行序列

两个设备清单仅为创建时记录，开跑前主控须确认真实当前状态，不能把 JSON 的 new-shutdown 字段当实时权限证明：

- Allow：`3604866D-E66B-4677-8F96-FCCBC7B1455F`
- Deny：`6A41C3B2-0160-4A50-BF77-2609592EAFAE`

1. 每个设备先运行只读 pending 宿主方法：期望 `notDetermined / 0 / false`。仅检查，不调用 request、grant、reset、schedule。宿主 App 正常启动会初始化普通偏好，但当前 App 启动路径没有 reminder schedule/request 调用。可沿用独立内存宿主 scheme，避免无必要 disk 写入。记录 snapshot 与独立 overlay 哈希。
2. Allow 精确执行既有 `SystemBoundaryDiagnosticUITests/testNotificationRealPromptAllowedWithEvidence`；Deny 用 `testNotificationRealPromptDeniedWithEvidence`。两方法从正常我的→训练目标进入，要求未决定文案、关闭开关，点击并保留真正提示截图+AX，两允许/拒绝选项必须同时存在，才能点击预定选项。禁止预授权或条件式跳过。
3. 现有提示定位先查 SpringBoard alerts，必要时查 App alerts；候选按钮为中文 **允许/不允许** 或英文 **Allow/Don't Allow**。系统标题不硬编码为某个 OS 翻译；以含两个授权选项的真实 AX 和 screenshot 判别。若运行发现其他系统表述，保留失败后仅修候选定位，不误点“无法开启提醒”当系统弹框。
4. 每次 UI 结束后在同设备同 bundle 运行只读 pending 方法：Allow 期望 `authorized / 1 / true / 19 / 0`；Deny 期望 `denied / 0 / false`。导出 OS 实际 pending JSON，补上 UI 开关并不证明通知存在的证据缺口。
5. Allow 再正常进入目标页，记录 DatePicker 实际 AX，选一个**与原值不同且不接近现在**的固定时间（建议 20:17，仅在实际系统 picker 支持时使用）。先捕获真实 picker 再据其 wheels/text fields 操作，不能凭 SwiftUI 声明臆造系统 wheel 标签。UI 确认开启与新时间→返回重进值保持；随后只读 pending 要求仍仅 1 条，hour/minute 为选择值，证明替换而非累加。
6. Allow 正常 UI 关闭开关并重进确认 false、时间控件不显示；只读 pending 要求 `authorized / 0 / false`。允许仍有系统权限是正确结果，不能要求 denied。重复开启可复用已有 authorized，不应出现第二次授权框；随后取消收尾。
7. Deny 再次点击开关应直接 App 解释，不能再出现系统授权弹框；确认 false，pending 仍 0。不打开用户系统设置改变授权，本批不以此代表“设置中重新允许”路径。

周目标从 3 天改另一值再重进，属于可合并的偏好持久化补验。它不应凭空产生第二条每日提醒，可在 Allow 时间变更阶段后独立查询 pending 保持 1 和同时间；不要假定改目标会调整提醒时间。

## 只读 pending 草稿与输入

精确选择器：`QiuJiTests/NotificationPendingDiagnosticTests/testObserveActualAuthorizationAndDailyPendingRequest`。

宿主中直接 `UNUserNotificationCenter.current().notificationSettings()` 与 `pendingNotificationRequests()`，外部 UI runner 的通知中心属于 runner 自己，**不能在那里读取后冒充 App 的 pending**。当前草稿只读 App 宿主，核对实际 bundle、guest，上报自身固定 identifier 的内容/时间以及其他请求数量；不导出其他通知内容、全量 defaults 或 Keychain。

必要 env（也支持 TEST_RUNNER_ 前缀）：

```
QD_NOTIFICATION_ENVIRONMENT=DEDICATED_GUEST_SIMULATOR
QD_EXPECTED_NOTIFICATION_STATUS=notDetermined|authorized|denied
QD_EXPECTED_NOTIFICATION_COUNT=0|1
QD_EXPECTED_REMINDER_ENABLED=true|false
```

当 count=1 再加 `QD_EXPECTED_REMINDER_HOUR` 和 `QD_EXPECTED_REMINDER_MINUTE`，各次值由预先计划的真实 UI 输入决定，不能从实际 pending 输出反填预期。只读断言核对固定 request identifier `qiuji.training.daily-reminder`、calendar trigger、repeats=true、选择时分、title/body/sound、显式 timezone=nil；请求总数必须等于本提醒数，避免专用环境混入其他请求。每次不同 RUN 保存真实附件 `notification-pending-observation`；没有 schedule/cancel 调用，不替产品制造正确 pending。

UI 调度可能重新安装 App，应保留安装与容器观察，不能假定授权和 pending 跨安装必然不变。若被系统安装行为重置，记录环境失效，不重设权限补成绿结果；选合适的保留安装执行方式后再测。

## 既有证据与不能外推的部分

`V53ProfilePreferencesTests.testReminderPermissionDeniedDoesNotSchedule` 与 `testReminderAllowedSchedulesAndDisableCancels` 只用 mock 计数，后者没有核对实际时分、OS请求或弹框，不能替代以上步骤。

当前 trigger 只有 hour/minute，未指定 timeZone。可报告这个配置事实；没有真实更改时区再观察调度/送达，不能声明跨时区正确。静态 `.sound` 不证明设备有声；pending 存在不证明后台/锁屏实际送达。真机通知送达、系统设置权限恢复、Focus/通知摘要、Live Activity 生命周期、时区/DST 实际行为仍单列补测，不让本地允许/拒绝两条测试覆盖全部 SC38。
