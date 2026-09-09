# 目标与提醒的测试判据核对

2026-09-08，只读规格、冻结实现与现有测试，非新增运行结果。

当前 `docs/04-功能规划.md` F9 与 `docs/05-信息架构与交互设计.md:289–299` 明确：每周目标属于当前 owner；声音、提醒、外观及教学辅助属于设备。提醒为系统权限加每日时间，不是按每周目标天数选择日期。

snapshot004 的 UserPreferences 将 reminderEnabled、reminderTime、soundEffectsEnabled 存为设备 UserDefaults；OwnerProfileStore 使用 owner 前缀存 weeklyGoalDays。TrainingGoalView 的目标选择只调用 setWeeklyGoalDays，提醒开关/时间走独立 updateReminder。SystemTrainingReminderCenter 用固定 requestIdentifier、hour/minute、repeats:true 每日排期；文案未插入当前每周目标数。

因此，**不能把“每周目标从3改5没有重新安排每日提醒”预设为缺陷**。当前规格没有要求因此改变通知的日期、时间或正文；无需为不存在的联动要求扩一套测试。原SC38权限、开关、时间与系统待发送记录证据继续引用 NOTIFICATION-004-RESULT.md；真实锁屏送达仍未验证。

现有 V53ProfilePreferencesTests 的 testLegacyGlobalProfileMigratesOnlyToDeviceGuest 明确检查 guest目标6/account目标3及旧全局键移除；testGuestProfilesAreSeparatedByOwner 只检查两个guest昵称，不可当成三个owner目标值切换的精确验证。B4.md 保存profile16全过的历史结果，其旧原件可用性仍受 EVIDENCE-AVAILABILITY-20260907.md 限制。

SC14正常目标3→5磁盘与冷启动已有独立证据，并发现QD028同进程首页仍旧目标。若补目标owner隔离，只需有限A/B/guest不同目标与重建读回，复用已有迁移/失败保存结果；不重复同一首页刷新缺陷或要求每种设备偏好随账号切换。
