# 2026-11-02 本机磁盘清理

用户再次要求清理空间。按当前占用复查后清理闲置缓存，并无损压缩一份历史 Cursor 数据库备份。没有删除项目代码、原始素材、研究结果、验收资料、聊天数据库或模拟器。

## 实测结果

- 基线可用：3,441,848,320 字节，约 3.44 GB / 3.21 GiB。
- 最终可用：9,385,525,248 字节，约 9.39 GB / 8.74 GiB。
- 本轮观察净增：5,943,676,928 字节，约 5.94 GB / 5.54 GiB。
- 并行应用仍可能写盘；APFS 共享块及同期写入使实际净增不等于目录分配量之和。

## 已执行

1. 两个历史工作树 `render-code-optimization`、`four-layer-rendering` 中的 10 个 `Intermediates.noindex` / `ModuleCache.noindex` 目录。删除前检查真实路径、目录身份、完整进程参数、打开句柄和末次修改超过 24 小时；源码、产品、日志和结果保持。
2. 7 个闲置软件缓存目录：Cursor 编译缓存及扩展安装缓存废弃区、Edge/Codex 浏览器代码缓存、Blender Cycles 缓存、MongoDB 下载二进制缓存、Hugging Face faster-whisper-small 模型下载缓存。需要时由对应工具重新生成或下载；没有删除应用设置、登录状态、聊天历史或用户录音。
3. 2026-06-03 留下的 `state.vscdb.backup` 从 3,514,589,184 字节无损压缩到 1,255,036,795 字节。完整解压回读长度和 SHA-256 一致，删除原件前再次检查文件身份和无打开句柄。当前 `state.vscdb` 保持，不改 Cursor 聊天记录。

17 个缓存目录分配量合计 6,650,425,344 字节，不能将此量直接当作实际释放量。最终核验 `verification_errors=[]`；未运行 App 构建或功能测试。

## 历史备份恢复

- 压缩包：`/Users/song/Library/Application Support/Cursor/User/globalStorage/state.vscdb.backup.20261102.gz`
- 原始 SHA-256：`d79c200394f7c8ff7e15079740a39078edfa116f0043b4157a867dbb97f46fae`
- 用 `gzip -dc` 将该压缩包解压到一个新恢复目录内的 `state.vscdb.backup`，再用 `shasum -a 256` 核对以上值。直接 `gzip -dk` 会产生带 `.20261102` 后缀的文件，并非当前数据库路径。
- 这是旧备份的归档，不是对当前数据库的修复或迁移。

## 核查后保留

- 模拟器管理器盘点 18 台，`cleanup` 预览候选为空；未解除保护、关机、删除或擦除任何设备。评审、待录制、默认开发、用户指定和未知归属实例保留。
- 当前 Xcode 的编译/索引及两套 iPhone DeviceSupport 均有占用，保留。
- 两个准度扩展旧工作区仍有续接保护且登记身份不匹配；未绕过生命周期守卫。
- 研究 Worker.app 依赖冻结基座，构建脚本采用 APFS 克隆，目录逻辑量不代表可释放空间；本轮保留所有研究程序包与输入/结果。
- Git garbage=0，没有可清理的临时包；没有改写 Git 历史、配置或对象。
- Cursor 的当前聊天数据库和 snapshots、Codex sessions、历史工程快照、测试结果及媒体保留。
- 普通目录扫描遇到 CoreDevice 的 DeviceFS 挂载，后续统计限定同一文件系统；挂载的 iPhone 空间不计入 Mac 占用，未对手机或挂载执行修改。

## 记录与后续

本轮机器可读记录在 `output/disk-cleanup-20261102/`：`baseline.json`、三份缓存清理清单、`cursor-backup-archive.json`、`simulator-before.json` 和 `final-summary.json`。

上一轮见 [11-01 清理记录](DISK-CLEANUP-20261101.md)。安全缓存回收空间已有限；若需长期保留大幅余量，需要对历史研究、验收、工程快照和聊天数据另行明确归档或保留范围，本轮盘点不授权批量删除这些内容。
