# 2026-10-30 磁盘空间应急清理

用户反馈空间再次不足；先检查容量、Git对象、进程与目录占用，再清除确定闲置的垃圾文件。

## 已执行

- Git报告两个 garbage：`.git/objects/pack/tmp_pack_H6AEMA`（6,875,906,048字节）和 `tmp_pack_K8Tjuu`（3,801,350,144字节）。
- 删除前复查无活跃git打包进程、lsof无打开句柄，文件已稳定超过60秒；记录inode、大小、mtime并在删除前再次核对。
- 仅删除上述两个临时包：合计10,677,256,192字节，即10.68 GB / 9.94 GiB。
- 即时可用空间由1,825,034,240升至12,535,009,280字节，最终复核12,539,465,728字节（约12.54 GB / 11.68 GiB）。早期df约276 MiB，扫描期间存在其他活动，瞬时读数会波动。
- 正式对象包目录项元数据、HEAD和当前已跟踪工作区diff均保持一致；未改应用代码、媒体、验收资料、研究数据或模拟器。保留运行中的Mac mini多球首杆验证任务。

## 验证与复发控制

- `git fsck --connectivity-only --no-dangling`：退出0；这是连接性检查，不是全对象内容校验。
- `git count-objects -vH`：garbage=0，36个正式pack、34.06 GiB；8301个松散对象。
- 本机Git手册显示默认自动整理阈值约6700松散对象；此前无gc/maintenance显式配置。自动整理是可能触发来源，未取得原进程日志，不能确定临时包由哪次操作生成。
- 为缓解空间紧张时再次自动打包，本仓库本地设置 `gc.auto=0`，不改全局设置。提交和推送仍可用；这不拦截手动repack/gc，也不代替后续维护。腾出足够空间并安排维护后，可用 `git config --local --unset gc.auto` 恢复默认。
- 未运行完整App门禁或App测试，本轮不涉及应用实现。

## 占用盘点与保留

`du`显示output约529 GiB、build约67 GiB、research约55 GiB、tmp约12 GiB；用户Developer目录约122 GiB（CoreSimulator约98 GiB），Codex约63 GiB。APFS共享块使目录统计不能直接当作可释放容量。output混有构建缓存、最终验收和待复验资料，本轮未按目录大小扩删；后续应按任务状态和替代证据逐项审计。

## 证据

- `output/disk-cleanup-20261030/git-temp-plan.json`：删除前文件与正式包元数据。
- `output/disk-cleanup-20261030/result.json`：删除量、空间、代码不变、配置和连接性检查结果。
- `output/disk-cleanup-20261030/git-connectivity-after.log`：检查输出，退出码见result。
