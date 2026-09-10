# 训练首页辅助功能实施

用户范围：训练心得、补记训练、训练提醒、使用帮助；统一当前页面风格。未提交、未发布。

## 已实现

- 首页右上角保留「更多」，替换重复计划入口，进入四项辅助功能。
- 心得按训练日期倒排，支持搜索、整次/动作心得阅读和编辑；遵循当前账号与 60 天/PRO 历史访问规则。
- 补记支持日期、分钟、球种、训练内容和可选心得；可以编辑、删除。计入训练天数与用时，不伪造成绩、动作组数或计划进度。取消零写入，保存失败保留草稿，事务与 UUID 保证重试不重复。
- 提醒支持本地时间、重复星期、下次日期、权限状态与失败恢复；首页和训练目标共用页面，点通知回训练页且保留正在进行的训练。
- 帮助使用本地展开说明，连接已有计划、设置、反馈等实际页面。

沿用 btPrimary/btBG/btText、系统分组表单及当前页面导航方式，支持浅深色；首页周卡及动态数据保持现状。

## 数据决策

见 `docs/ADR-training-utilities.md`。补记使用已有 `sourceKind=manualTraining`、`sourceTitleSnapshot`、版本化来源 payload，不新增 V5 模型字段。payload 保存日历年月日，展示/统计使用 reportingDate，避免日期随时区偏移。现有 DTO、服务端严格 schema 和还原流程保留这些字段。

## 验证证据

目录：`output/training-utilities-implementation/`。`baseline/` 保存本轮前源码；原有未提交工作保留。

- `final-roundtrip.xcresult`：7 项领域测试 + 标准手机浅/深色完整 UI 两项通过。包含补记保存、心得编辑、详情与编辑、删除返回列表、提醒星期、帮助。
- `final-standard.xcresult`：既有偏好提醒测试两项与训练目标共用入口测试通过。
- `se-final.xcresult`、`ipad-final.xcresult`：小屏及 iPad 的完整 UI 流程分别通过。
- `backend-test.log`：3 项 provenance 测试通过，含补记来源序列化。
- 最后统一辅助页隐藏 Tab 栏，`release-style`（7 单测+浅深 UI）、`se-release`、`ipad-release` 全部通过。`build-final.log` BUILD SUCCEEDED；gate/doc-size/diff 检查通过。最终截图及边界见 UI 审查报告。

早期构建锁/增量链接失败、键盘点击失焦和错误的深色启动参数均保留原日志，未作为通过证据。测试使用独立 DerivedData、内存数据和 xcresult 图片附件。

边界：真机通知到达、真实账号端到端同步、StoreKit、VoiceOver、大字号及全量回归未验。初始两个 simctl 截图为 SpringBoard，不能作为 App 前图。
