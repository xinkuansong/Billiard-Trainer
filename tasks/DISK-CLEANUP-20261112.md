# 磁盘清理 · 2026-11-12

本轮沿用已确认的保留策略。启动时可用 0.21 GB，首轮核验时 24.63 GB；用户另行确认两份冗余 Git 包后，最终可用 **60.09 GB**，相对本轮启动净增 **59.87 GB**。正式包清理单独实测净增 36.38 GB。并发应用写入会使该数字继续变化。

| 处理 | 数量 | 文件分配量或独占量 |
|---|---:|---:|
| Git 报告为 garbage、已无进程和句柄使用的临时 pack | 4 个 | 10.13 GB |
| 用户单独确认的冗余正式 Git pack 及配套索引 | 2 个包、5 个附属文件 | 36.38 GB |
| 闲置编译中间文件与缓存 | 11 个目录 | 1.57 GB |
| 历史成功测试原包，替换为摘要、用例树和附件归档 | 14 个 | 2.57 GB |
| 旧源码快照中内容完全一致的资源，改为 APFS 共享副本 | 3,455 个文件 | 原独占 10.51 GB |

个人 Documents 约 0.22 GB。output 本轮清理前约 344.81 GB，比 11-10 清理后增加约 0.68 GB。今天新产生的两个 Git 临时包约 10 GB，是已定位的主要新增占用之一；未确定哪个任务生成，不能将全部磁盘增长归因于它们。

## 保留与验证

- 清理前检查路径身份、更新时间、Git 跟踪状态、进程及文件句柄。当前占用的编译缓存跳过。
- 成功测试保留全部 365 份摘要、用例列表、附件和清单，SHA-256 读回全部通过。失败或不完整测试原包保留。本轮没有舍弃自动录屏附件。原包内部完整 Xcode 浏览需要重新运行测试，旧路径到归档的映射见 `more-result-bundles.jsonl`。
- 视频台账和待发布目录 193 个文件／链接逐项复核通过。
- 共享副本仅涉及 `tmp/feel-middle-build-snapshot-20261003/QiuJi/Resources`，匹配来源为 `build/table-page-adaptation/P01-C56/snapshot/QiuJi/Resources`。保持原路径、字节、权限、所有者、修改时间、flags 和扩展属性。3,455 个文件及对应来源重新读取校验通过，所有目标均为独立 inode 的常规文件，写时复制隔离探针通过。未新增符号链接或硬链接。
- 第一轮遇到一份 AppIcon 的隔离属性无法原样复制，复制件校验时中止，原件未替换。后续恢复执行对这类文件逐项保留，最终共 12 个跳过。最终已替换文件无校验错误。
- 首轮保留正式 Git 包。用户后续确认后删除两份重复包，正式包由 4 份降至 2 份，去重后的 Git 对象总数清理前后均为 79,841，无对象遗漏。refs、HEAD 和暂存区索引 SHA 未变，仓库连接完整性校验通过。garbage 为 0。

## 已按用户确认清理的 36.38 GB

两份旧正式包 `pack-3f1968e61c6731292caeac181b3674d6631b213a` 与 `pack-6a9137aeb66d0310f037aa859e4b7ca522ccabb6` 的全部对象，均被当前 multi-pack-index 所使用的两份保留包覆盖。两份保留包刚通过 `git verify-pack` 完整内容校验，`git fsck --connectivity-only --full --no-dangling` 通过。四个包的索引与头尾一致，已保存对象集合及 refs 基线。

用户明确选择“删除这两份冗余包”后执行。执行前一个保留 pack 的修改时间变化，重新计算全包内容校验值，证实与已完整验证的索引一致。Xcode Source Control 曾短暂映射旧索引，等待其自然释放后继续，未终止应用。

先将精确的两包及五个附属文件移出 Git 对象目录，再确认全部 79,841 个对象仍可枚举、refs/HEAD/index 未变，并运行 `git fsck --connectivity-only --full --no-dangling` 通过，最后删除已隔离文件。两份保留包及当前 multi-pack-index 保持完整。

执行清单 `git-approved-pack-plan.json`，删除回执 `git-approved-pack-deleted.jsonl`，结果 `git-approved-pack-result.json`，时间变化后的全包复核 `git-approved-pack-time-revalidation.json`。此前前置占用检查中止发生在任何 pack 移动之前，回滚记录 restored=0；最终执行已完成。

审计目录：`output/disk-cleanup-20261112/`。最终汇总 `verified.json`；缓存清单 `*cache-deleted.jsonl`；临时 Git 包 `git-temp-deleted.jsonl`；测试路径映射 `more-result-bundles.jsonl`；快照文件 SHA 与属性 `clone*-replaced.jsonl`；最终核验 `clone-final-verification.json`、`test-archive-verification.json`、`final-media-verification.json`。
