# 2026-11-04 本机磁盘清理

> 后续只读分析发现快照内部含最终验收图，因此撤回整目录删除建议，改为逐文件资源去重。以 [output专项分析](OUTPUT-CLEANUP-ANALYSIS-20261104.md) 为准。下方历史候选表不作为删除授权。

## 已完成

清除三个确认无进程/打开句柄占用的可再生成缓存：项目 DerivedData 编译中间文件、预编译模块和 uv 下载缓存。删除目录分配量约 1.10 GB，清理前后实际空闲空间由 2.93 GB 增至 3.86 GB（净增约 0.93 GB）。其他进程仍可能写盘，目录大小不等于独占物理块。

未操作模拟器、当前源码、正式素材、Git 历史、聊天数据库。正在使用的 Xcode/浏览器缓存、Codex 更新暂存保持。两个受管失败任务明确有保留标记，保持。

## 待用户决定：历史完整副本

下表仅为候选，尚未删除。8份历史工程快照加6份研究 Worker.app，目录分配量合计 123.41 GB。APFS 克隆共享块使实际释放量可能明显低于合计，不能承诺释放123 GB。检查时均无进程参数引用或打开句柄，均非本仓库 Git 跟踪文件；这不能证明不存在独有历史内容。

删除后会失去这些旧版本的完整复跑环境，且快照内部可能含独有历史修改。候选之外的当前工程、研究结果、独立验收报告、素材母版、视频及聊天不在删除范围内。

| 精确候选路径（相对项目根） | 目录分配量 GB |
|---|---:|
| `output/table-materials-v64/W4/candidate-source` | 7.70 |
| `output/table-materials-v64/W4/baseline-source` | 6.55 |
| `output/table-materials-v64/W5/device-source` | 6.54 |
| `output/table-optimization-20261014/merged-source` | 8.05 |
| `output/table-optimization-20261014/source` | 8.05 |
| `build/table-page-adaptation/P01-C56/snapshot` | 12.20 |
| `tmp/feel-middle-build-snapshot-20261003` | 12.20 |
| `archive/quality-diagnosis/snapshot-004/source` | 12.57 |
| `research/two-ball-b42-similarity-20261024/Worker.app` | 8.26 |
| `research/two-ball-independent125-full-20261024/Worker.app` | 8.26 |
| `research/two-ball-sample125-once-20261024/Worker.app` | 8.26 |
| `research/two-ball-middle-grid18-20261025/Worker.app` | 8.26 |
| `research/two-ball-b43-trajectories-20261024/Worker.app` | 8.26 |
| `research/two-ball-strike-full-20261024/Worker.app` | 8.26 |

机器记录：`output/disk-cleanup-20261104/cache-cleanup.json`、`historical-candidates.json`。未运行 App 构建或功能测试。
