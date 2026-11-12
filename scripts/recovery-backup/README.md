# CuePhys 定期备份与恢复

所有时间使用北京时间。2026-11-10 已在上海服务器、Mac mini 和主开发 Mac 启用。[上线验收](../../tasks/launch-20261110/备份恢复验证.md) 记录真实归档和故障演练。

| 机器 | 任务 | 运行位置 |
|---|---|---|
| 上海轻量服务器 | 每分钟读取注销记录簿头，有变化即生成独立加密归档；即使无变化也在约 24 小时后刷新。每天 03:15 起生成当日业务库、被账号引用的头像、注销库与检查点。每分钟半点独立检查生成状态和 mini 回执。 | `/opt/cuephys-backup/`；systemd 的 `cuephys-backup.timer` 与 `cuephys-backup-watchdog.timer` |
| Mac mini | 开机后台每 60 秒优先拉注销证明，再拉业务归档。校验长度和 SHA-256，写盘并同步目录成功后再回执。中断后重拉，原有有效副本保留。 | 系统 LaunchDaemon `com.cuephys.backup.pull` 以 song 用户运行，密文在 `~/.local/share/cuephys-backups/managed/archives/` |
| 两台 Mac | 用户登录后每 120 秒查云端状态，mini 还核自己的下载任务。异常首次通知，持续异常每小时提醒，恢复后提示。云端保留最近 30 天内最多 100 个异常变更，登录后可收到错过的异常摘要。 | 用户 LaunchAgent `com.cuephys.backup.monitor`；`managed/status.json` 留存本机状态 |

云端任务超过 4 分钟没更新、生成出错、mini 超过 10 分钟无心跳、未及时确认新注销证明或新业务包、每日业务备份逾期均纳入检查。两台 Mac 同时关机、睡眠或未登录时，桌面通知要等设备可用；通知权限和专注模式影响横幅可见性。两台 Mac 都无需向外部消息服务传输资料。

### 权限与恢复点

服务器侧使用单独的 MongoDB 只读身份读取业务库、注销库及 oplog。提取完整业务包前后比对同一副本集的非空操作时间戳及注销记录簿头，若备份期间有写入，丢弃本次候选并在下一次运行重试；这不要求定时停服。变更太频繁会延迟业务快照，需要关注生成失败提醒。头像只归档本次快照所引用的版本。注销证明包含完整的最少注销事件和独立检查点，可脱离旧业务包更新。归档内有内容校验清单和 recovery-point.json，包含时间、记录簿标识、序号和摘要。

传输使用固定 SSH 主机公钥和两把强制命令密钥。mini 可读取当前密文归档并回执；主开发 Mac 只可读状态。两把钥匙都不能执行 shell 或端口转发。服务器只有本次加密所需的收件人证书。mini 的长期恢复材料位于 `~/.local/share/cuephys-backups/keys/w9-20261110/`。加密私钥的口令在主开发 Mac 登录钥匙串的 `CuePhys Mac mini 域名项目恢复演练 20261110 W9` 条目。后台传输不需要解锁私钥。

意外失去服务器时，以 mini 已验证的副本为恢复依据。需分别核实业务快照的可接受丢失窗口、最新注销证明的可信截止点。每分钟拉取存在间隔；未获回执的注销事件可能仍只在服务器。如不能证实注销覆盖到停写点，先保持恢复库隔离。计划切换时应先停止业务写入，确认最新记录簿头和 mini 的序号、摘要相符，再恢复放行。

### 清理

- mini 常规业务包满 30 天、旧注销证明包满 7 天可清理。服务器中转密文满 2 天可清理。各端保留最近的有效业务包和注销证明，持续故障时最后一份可能超过上述期限。任务成功后检查清理，mini 恢复运行后补做。
- 只按本任务的归档文件名和时间清理。原始注销记录簿、最新证明里的累计事件、解密材料及先前手工备份另行管理。不能把上述期限直接用于承诺全部用户数据届时清除。
- 云端工作目录只供 root 使用；下次运行会清除上次异常退出留下的本任务暂存文件。下载不完整的文件不会产生回执，mini 下次运行会清理残留。

### 复查与恢复

1. 在云端用 `systemctl list-timers 'cuephys-backup*'`、`journalctl -u cuephys-backup.service` 检查运行；`/var/lib/cuephys-backup/export/manifest.json` 记录最新归档，`receipts/{full,proof,pulse}` 及 `watchdog.json` 在同一基础目录。mini 的 `managed/verified.json` 有本地校验时间和摘要。
2. 检查 `launchctl print system/com.cuephys.backup.pull`（mini）及 `launchctl print gui/$(id -u)/com.cuephys.backup.monitor`（两台 Mac）；可用 `/usr/bin/python3 managed/bin/mac_worker.py observe --test-alert` 在对应路径发送标明演练的通知。正式任务每次从安装路径读取脚本。
3. 选一份合适的 full 密文和截止点已知的最新 proof 密文。用私钥在加密临时卷内解包，各自核 `SHA256SUMS`、记录簿标识与序号。选取 full 的 `business.gz` 和 `avatars.tar.gz`，使用最新 proof 的 `ledger.gz` 和 `checkpoints.tar.gz`。业务库与注销库分别还原到隔离实例，头像和检查点分别解到空目录。校验最新证明后运行 `reconcileRestoredAccounts`，验证数据与旧凭据再放行。
4. 一次恢复成功后清除临时明文、测试数据库及临时加密卷。真实归档、私钥和数据库连接配置均留在指定机器的私有目录。项目中仅记录脱敏证据。

2026-11-12：官网上线收尾已形成[邮件/网站日志及历史备份管理流程](/Users/song/projects/23.website/company-site/docs/OPERATIONS-RETENTION.md)。本脚本的30/7/2天与最后有效副本保护不变；历史手工包、云快照及注销事件裁剪仍需独立核对和执行。本轮未删除真实备份。
