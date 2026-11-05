# 2026-11-03 本机磁盘应急清理

用户再次要求清理。本轮清除 Git 确认的闲置垃圾临时包和应用更新缓存，并无损归档 9 份旧研究数据/日志。研究内容、源码、素材、视频、验收结论和聊天记录保留；未操作模拟器或手机。

## 实测结果

- 最初 df 显示仅 419 MiB；扫描期间继续下降，首个精确基线可用 126,255,104 字节。
- 最终可用 9,455,149,056 字节，约 **9.46 GB / 8.81 GiB**。
- 相对精确基线观察净增 9,328,893,952 字节，约 **9.33 GB / 8.69 GiB**。
- 这是实际可用空间变化；目录分配量受 APFS 共享块影响，期间其他应用也可能写盘。

## 已执行

1. 删除 `.git/objects/pack/tmp_pack_DpjXKv`，3,352,297,472 字节。Git 自身标为 garbage；首次检查距末次修改约 286 秒，两次检查身份/大小/mtime 一致，无打开句柄和打包进程，复核后仅删除此精确文件。
2. 删除闲置更新暂存 `~/Library/Caches/com.openai.codex/org.sparkle-project.Sparkle/Installation/tBk2CKSAG`。分配量 1,890,234,368 字节，无打开句柄；当前已安装应用保持。
3. 将 `build/cue-scratch-research-20261004/` 的 `results.sqlite`、`broad-001` 至 `broad-006.jsonl`、`verify-low-speed-23-20261006.jsonl`，以及 `build/landscape-camera-v31-20261003/ui-r3.xcresult/Staging/1_Test/Diagnostics/simctl_diagnostics/CoreSimulator.log` 压为各自同目录 `.gz`。9 个文件均已约 28–31 天未修改，总计 6,223,829,992 字节，压缩后 1,570,905,276 字节。

归档前及移除未压缩副本前检查无目录进程引用/打开句柄、来源身份稳定。SQLite WAL 为 0 字节，未丢弃未合并事务。每份压缩包均完整解压回读，长度和 SHA-256 与原始数据一致；先落盘校验后的压缩包及清单，再移除原件。原研究结果完整保留，读取旧数据库或原始分片前须先恢复。

## Git 验证与限制

- `git fsck --connectivity-only --no-dangling` 退出 0；这是连接性检查，不是全部对象逐字节验证。
- 最终 `garbage=0`。HEAD、正式 pack 文件集合、inode 和大小保持。
- 25 个正式 pack 的 mtime 在期间变化，已如实记录差异；本轮命令没有写这些正式包，变化来源未确认，不宣称全部元数据或全部内容前后已逐字节证明一致。
- 本仓库 `gc.auto=0` 仍在，本轮未改 Git 配置。新临时包的创建原因未取得进程日志，不将其直接归因为自动 GC。

## 研究数据恢复

归档清单及原始 SHA-256 在 `output/disk-cleanup-20261103/archive-result.json`。恢复单个文件示例：

```sh
gzip -dk build/cue-scratch-research-20261004/results.sqlite.gz
shasum -a 256 build/cue-scratch-research-20261004/results.sqlite
```

其余分片/日志同样对相应 `.gz` 使用 `gzip -dk`，并对照清单 SHA。`-k` 保留压缩备份，恢复目标已存在时不要强行覆盖。复算脚本不自动识别 `.gz`；运行旧图册重选、SQLite 查询或原分片审计前，须恢复其依赖的文件。原成片、HTML 图册、选择结果与报告不需要恢复，保持原路径。

归档提醒已补入研究入口 README 和原始数据目录。未运行 App 构建或功能测试；本轮没有更改 App/物理实现。

## 记录

`output/disk-cleanup-20261103/` 保存 Git 删除前后信息、正式包 mtime 差异、连接性输出、更新缓存记录、归档及恢复清单和 `final-summary.json`（`verification_errors=[]`）。

前两轮：[11-02](DISK-CLEANUP-20261102.md)、[11-01](DISK-CLEANUP-20261101.md)。本轮没有按大目录体积批量删除历史验收、素材、工程快照或聊天记录。
