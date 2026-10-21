# 本机与 Mac mini 测试目录清理 · 2026-10-20

用户授权补齐任务完成后的自动清理，并优先处理本机。清理依据是任务已结束、旧轮次已被替代及必要证据可核验；不以进程退出或目录日期单独判断。工作从 10-19 开始，明细保存在 `output/mac-mini-cleanup-20261019/`。

## 实际空间

| 主机 | 清理基线可用 | 最终采样可用 | 两次采样净增 |
|---|---:|---:|---:|
| 本机 | 1.14 GiB | 31.56 GiB | 30.43 GiB |
| Mac mini | 9.42 GiB | 54.26 GiB | 44.85 GiB |

Mac mini 三次删除窗口的空间增量合计 46.83 GiB；最终采样净增较少，期间其他任务继续读写。目录 `du` 大小包含 APFS 共享块，不能累加作为实际释放量。最终采样见 [final-disk-status.json](../output/mac-mini-cleanup-20261019/final-disk-status.json)。采样时队列无 running/queued 项；清理过程中未停止执行器，各轮均检查未选任务原有目录仍在。

## 本机已完成

- 清理 76 个可再生缓存目录，8 个占用目录保留。
- 删除 93 份已被新轮次替代的构建产品目录；保留最新复验产品及占用版本，记录旧产品二进制与 Info.plist 指纹。
- 归档并删除 6 个展开源码快照，合计 33,202 条文件记录。按内容复用 Git 对象，逐个回读唯一 blob 并校验 SHA-256。独有配置保留在权限受限的私有伴随目录，没有加入 Git。
- 将旧布局 B00–B12 的 269 份 `.xcresult` 精简为摘要、测试列表、actions 日志及必要失败附件，11.16 GiB 目录内容缩至约 94 MiB。原旁置截图、AX、JSON、连续录像保留；4 份无法正常读取的测试包保留原件。未把旧失败结果改成通过。
- 未删除模拟器、用户设备数据、当前源码或其他项目；保留当前复验版本。

精简后的测试证据位于原测试包相邻的 `*.xcresult.summary-v2/`，含归档清单及文件 SHA-256。逐项范围和跳过原因见 [缓存清理](../output/mac-mini-cleanup-20261019/local-cache-cleanup.json)、[产品清理第一批](../output/mac-mini-cleanup-20261019/local-product-cleanup.json)、[第二批](../output/mac-mini-cleanup-20261019/local-product-cleanup-round2.json)、[测试证据精简](../output/mac-mini-cleanup-20261019/local-evidence-compaction-v2.json)。10-17 先前清理记录仍在 [原报告](../output/disk-cleanup-20261017-1949/REPORT.txt)。

### 源码恢复

归档引用为 `refs/cleanup-archives/20261020-local-snapshots`，对象提交为 `6322d392d3d15a8f5091a775692b5dfaeaea928d`。这是本地独立归档引用，没有改变主分支或主索引，没有推送。恢复同时依赖 Git 对象和 `source-archive/` 的清单、私有伴随文件，因此后者应作为必要证据保留。

```bash
# 列出六份快照及原位置。
python3 output/mac-mini-cleanup-20261019/source-archive/restore.py
# 示例：恢复到一个尚不存在的新目录；脚本逐文件校验内容与权限。
python3 output/mac-mini-cleanup-20261019/source-archive/restore.py snapshot-3 \
  --out /path/to/new-restored-snapshot
```

已实测完整恢复 snapshot-3 的 5,283 个文件，结果见 [恢复日志](../output/mac-mini-cleanup-20261019/source-restore-check.log)；验证用的临时恢复目录随后已删除。归档新增 Git 对象且原目录有共享块，因此不能宣称删除六个源码目录释放了其约 50 GiB 的逻辑大小。

## Mac mini 已完成

- 27 个旧任务的 `build` / `source` 已回收；远端原始 evidence、worker 日志、job 元数据保持不变，删除前后逐文件指纹核对通过。
- 20 个已取消且未执行的旧请求完成归档收尾；连同上述任务共回收 15 份已无保留任务引用的共享快照。
- `rest-matrix-se-r1` 与 `pro-brand-20261018-r1-phone` 仍有关联诊断模拟器，保留目录。每日清台当前测试族及其他未选任务保持原状。每一轮均断言未选任务原有 source/build/evidence 目录未被删除。
- 未清理 Figma 迁移档案、Snooker 项目、系统缓存、模拟器或无法归属的历史 incoming。

执行与核验：[旧任务第一批](../output/mac-mini-cleanup-20261019/remote-cleanup-applied.json)、[取消请求](../output/mac-mini-cleanup-20261019/remote-cancelled-cleanup-applied.json)、[旧任务第二批](../output/mac-mini-cleanup-20261019/remote-cleanup-applied-r2.json)。

## 后续机制

`scripts/mac_mini_queue.py` 新增任务关闭和证据收据。`fetch --complete --reason ...` 或已有归档上的 `complete --out ... --reason ...` 在回传验证后自动回收该任务源码和构建；普通 fetch 保留现场。复验用 `remote-protect` 登记原因，结束后 `remote-release` 再 complete。历史任务支持先记录关闭、预览范围再 apply。

删除前核对终态、关闭标记、归档收据、全部远端证据、源码冻结清单、进程/打开文件和模拟器登记表；有变化或检查失败就保留。共享快照须等所有引用任务回收后才删除。允许本地 xcresulttool 新生成的索引文件，但所有远端原件必须完整且内容一致。

新版 worker 启动时重试已关闭但之前被占用的任务；上传/构建前检查至少 12 GiB 可用空间。低空间时任务保持 queued，不进入注定失败的构建。每次 ingest 无论成功或失败都清掉自己产生的上传暂存，失败记录独立保存。

新版执行器已按内容哈希部署；正在执行或已入队任务原先绑定的执行器没有被改写。本次没有安装定时服务。完整命令和边界见 [队列 README](../scripts/mac-mini-queue/README.md)。Mac mini 技能及 worker 参考文档同步了完成/复验协议。

### 本地自动收尾已接入（同日追加）

按用户进一步要求，本地也从规则落到了代码：新增 `scripts/local_test_lifecycle.py`，默认接入 `make test`、`make sim-test` 和矩阵 `run`。每次创建独立 work/evidence，普通成功任务自动回收 work；失败或 hold 保留，诊断/复验完成执行 complete 即刻回收。已关闭但因占用延后的目录在下一次受管任务启动时自动重试。自定义多步任务由相同 run 入口包住整轮，build-for-testing/test-without-building 中间步骤不会误删后续产品。

删除只限新建且登记的本轮 work，保留证据 SHA-256、退出码、删除记录；检查目录身份、进程参数、打开文件、挂载点和符号链接。历史目录不按年龄擅自接管，当前运行中的旧流程也未被强制迁移。详细用法见[本地生命周期 README](../scripts/local-test-lifecycle/README.md)。

验证：新增 **17 项通过**，其中实际 Makefile/CLI/文件删除链只替换 Xcode 与日志格式化器；矩阵入口和临时构建路径有测试。既有模拟器生命周期 **23 项通过**、队列 **40 项通过**。另用真实 Python 子进程和目录执行成功、保留、失败、占用、完成后补清的完整验证，证据前后哈希一致，所有验证用 work 已回收；没有运行 App 功能测试。

证据：[本地 17 项](../output/local-test-lifecycle-20261020/tests.log)、[模拟器 23 项](../output/local-test-lifecycle-20261020/simulator-regression.log)、[队列 40 项](../output/local-test-lifecycle-20261020/queue-regression.log)、[真实文件系统与进程验证](../output/local-test-lifecycle-20261020/live-verification.json)。初轮夹具生成代码多余分号造成的 3 项失败原日志保留，修复夹具后原断言全部通过。Make dry-run 曾因递归 Make 标记执行包装器，已调整条件结构并补上不创建目录的回归测试；两份小型 dry-run 记录保留，工作目录已自动回收。

## 验证与交付边界

- 本机与 Mac mini 各 40 项 Python 单元测试通过，覆盖运行/排队/复验保护、共享快照、证据缺失或变化、路径边界、失败任务、低空间及中断重试。
- 真实 SSH/rsync 小型夹具验证通过：完成任务回收，复验/排队任务及共享快照保留，证据不变。夹具随后删除。
- 历史证据回传收据实际核验通过；额外本地 SQLite 索引导致的误拒绝已修复，未放宽远端原始文件的校验。
- 本地源码归档回读和完整恢复验证通过；各批删除清单及证据精简清单已落盘。
- 技能 frontmatter 用 Ruby YAML 校验通过；官方 quick_validate 所需 PyYAML 在当前 Python 环境缺失，未安装额外依赖。
- 本轮不涉及 App 功能改动，没有执行 iOS 功能回归，也没有主分支提交、推送或发布。

测试日志：[本机 40 项](../output/mac-mini-cleanup-20261019/final-unit-tests.log)、[Mac mini 40 项](../output/mac-mini-cleanup-20261019/remote-final-unit-tests.log)、[SSH 集成](../output/mac-mini-cleanup-20261019/remote-integration-verification.json)。下一步由各任务执行者在交付时调用完成入口；仍需诊断/复验的任务结束后按同一协议回收。
