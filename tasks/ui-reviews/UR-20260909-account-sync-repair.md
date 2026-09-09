# 重新登录后的训练同步修复与验收

日期：2026-09-09。状态：代码修复及局部自动化通过，真实账号/手机事件待复测。

## 问题与范围

用户真机报告：第一次登录拒绝同步，退出重登后接受，只恢复头像、名字，训练和其他个人数据未显示。尚未取得该手机安装版本、第二次弹窗原文或该账号服务器记录，因此不声称已确定这一次事件的唯一原因，也不声称已找回用户数据。

当前源代码确认的缺口：登录身份在 sheet 内提交会同时重建 owner 页面并弹同步选择；下载异常仅记日志；历史/统计等缓存未消费恢复完成事件；前台增量会使正在执行的全量恢复失效；上传被拒绝时直接丢弃队列，失去后续重试入口。首次拒绝会被保存，本身符合已确认的同步同意契约。

## 修复

- Profile / Subscription 的登录 sheet 先收取认证结果，完全关闭后再提交账号身份，随后呈现同步选择。
- 设置保留按账号开关，新增“立即同步训练记录”；全量恢复前可重新选择游客合并。未开启时不上传或下载。
- 上传/下载失败返回编排层，展示未完成状态及弹窗；请求被拒绝仍保留待同步项，成功才出队。应答返回后复核账号与同意版本。
- 前台增量不取消正在进行的恢复。关闭同步与账号切换依旧使旧请求无权继续落盘。
- 恢复保存和游客归属迁移后按 owner 通知历史、统计和训练首页重新加载，不重建整个导航树。
- 界面明确云同步覆盖训练会话及角度/瞄准成绩；收藏、个人计划/模版、训练安排仍是本机数据，游客合并会迁移本机归属，本轮未新增这些实体的云服务。

决策见 ADR-P2-20260909。SwiftData schema、DTO、后端端点均未改。

## 功能验证

| 验证 | 结果 | 证据 |
|---|---|---|
| 最终账号/上传删除/恢复/隔离单测 | 51 项，0 失败 | build/account-sync-repair/final-standard.xcresult |
| 标准手机浅色：先拒绝、退出重登、设置开启、恢复1条23分钟记录、再次同步不重复 | 通过 | build/account-sync-repair/regression.xcresult |
| 标准手机浅色：开关选择跨启动保留 | 通过 | 同上 |
| 标准手机浅色：登录选择→游客合并→同步失败→设置重试再次提示 | 通过 | build/account-sync-repair/final-standard.xcresult |
| SE 深色：正常恢复及游客合并/失败/重试 | 2 项通过 | build/account-sync-repair/final-se-dark.xcresult |
| Debug 构建 | BUILD SUCCEEDED | build/account-sync-repair/build.log |
| verify-gate | FAIL 0 | build/account-sync-repair/gate-final.log |
| verify-doc-size / diff --check | 通过 | build/account-sync-repair/doc-size.log |

新增单测覆盖：真实 DTO 编解码后恢复 owner/UUID/心得、拒绝→退出→重登→开启、全量请求中前台激活、失败可见与成功重试清除、拒绝游客合并后再次选择、拒绝上传队列保留及关闭时队列不可上传。既有切号/下载中关闭/删除不复活测试保留。

测试使用隔离内存 SwiftData 与模拟后端。UI 的 -syncRepair.loginSheet 等路径仅 DEBUG + simulator 生效，认证/训练请求无真实凭证、无生产网络；不能替代 Apple 登录或真实后端端到端验证。

初轮 unit.xcresult 的两处失败保留：旧删除测试未显式开启新队列入口门禁；通知期望用 Swift String 作为 NotificationCenter 对象身份过滤导致未匹配，改为通知名加 owner 值比较。没有放宽数据条数/owner/内容断言，后续51项全通过。gate.log 首轮发现两个登录呈现者的路由签名改变，以及会话前已有 RootView 引导预览深色差异；逐项核对入口未删、回调职责明确后补覆盖状态与签名，未改既有 RootView 代码。

## 视觉审查

已查看标准手机（iOS26.2，1206×2622）浅色与 SE（iOS26.2，750×1334）深色实际截图；标准字号为 large。按钮44pt、文案换行及弹窗内容可见，采用现有字体/颜色。原始截图保留在 output/account-sync-repair/。

- 改前：settings-before.png（原设置仅开关，无重试/状态）。
- 标准正常：regression-attachments/49805045-0FAA-4827-812D-208284C0FBA8.png（恢复1条），5DB48330-AD8E-4BAE-93CE-288FEC42B3D5.png（历史23分钟）。
- 标准弹窗：final-standard-attachments/EF257D8F-F00C-4245-8A7C-E8F4ECC5D755.png（游客合并），7F0AA71E-79C9-4BC3-B117-3EEAE795DD05.png（失败）。
- SE状态：final-se-dark-attachments/9B97E807-72F6-4285-A789-D44A53A7AA7D.png（成功），7D05BD7A-AC71-49DE-AD5B-0B001D91F1B1.png（未完成/重试）。
- SE弹窗：final-se-dark-attachments/417504AB-9EE2-41B2-BD22-9F477876B2AD.png、05D4C1C6-CBD0-4266-8D09-211610D3ED02.png、9FAD6832-654D-4145-8CB0-531FAA1F5E08.png，均完整可读。
- SE原历史截图记录行在首屏底部，需要滚动才能完整显示；补截图测试增加滚动后可点击断言，未改变生产布局。补验 se-history-visible.xcresult 通过，见 output/account-sync-repair/se-history-visible-attachments/。

本轮未做iPad、iOS17、完整AX/VoiceOver及真实手机视觉验收。既有历史开始/结束时刻语义问题不在本次范围。

## 手机复测步骤与未完成边界

1. 用本次源码更新手机上的App，保留原安装及本地数据。记录实际版本/构建。
2. 同一账号进入“我的→偏好设置→训练数据云同步”，开启后按意愿选择是否合并游客记录，再点“立即同步训练记录”。
3. 核对显示的恢复条数、历史条目日期/心得/分组成绩，并对照同步前记录；切首页/统计观察更新。
4. 如果显示同步未完成，保留当时提示与 [SyncRestore]/[SyncQueue] 日志，核对账号云端是否存在副本。若恢复0条且本机无记录，需要检查原记录owner及是否曾成功上传。
5. 验证退出重登仍保持选择；断网重试有失败提示，恢复网络再次同步后不重复记录。

未获取真实账号记录、未安装到真机、未发布、未提交。原版本从未上传的记录无法从云端下载；旧版已经丢弃的队列不因本次改动自动重建。后端现有500条无分页上限仍是另一个已知边界，本轮未修改服务端。收藏/计划/安排的完整跨设备同步需要另外实现，不能用同步成功文案宣称已支持。保留工作区原有引导/图标/训练辅助/质量诊断修改。
