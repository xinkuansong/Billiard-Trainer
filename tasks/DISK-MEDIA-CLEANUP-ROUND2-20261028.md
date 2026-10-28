# 历史中间媒体清理：第二轮（2026-10-28）

用户要求继续核查剩余媒体，确认不用的历史中间产物继续清理，保留最终验收、待复验和短视频素材成片。

## 162 GB 的口径修正

此前162 GB来自路径筛选，并非逐文件确认的可删除清单。它仍包括阶段/最终验收图、暂停实验、复制到测试备份中的教学资源及重复导出。本轮通过任务状态、最终验收入口与SHA-256匹配继续分类；未把所有媒体统一判为垃圾，也未以文件夹名含final自动认定当前有效。

## 本轮确认与实际删除

- 旧操作布局B02–B10阶段媒体：13,395,100,299字节。依据`tasks/table-control-layout/LOCAL-ROLLOUT-20261019.md`中用户明确“全部替换、旧模式全部否决”的裁定，以及新实现20入口/34模式完成收口。旧B批次报告亦明确整体结论撤回、旧结果不计新版验收。保留B00旧基线、B11/B12旧最后汇总、所有新的local-rollout最终验收媒体；本轮不删除新版验收。
- 同一任务族内重复导出：4,463,908,477字节，3,868个。候选与保留副本逐文件SHA-256一致；每条删除记录附保留路径，保留副本没有出现在删除清单中。全量重复扫描检出约19.7 GB，但教学导出母图、资源/纹理、素材/备份、跨任务同图和待复验3d-v63等未按重复项删除；只清理已筛选的重复导出。
- 总计删除4,914个文件，17,859,008,776字节（17.86 GB）。逐文件存在性复核全部已删除，没有因在用或漂移跳过项。
- 7,765个保留文件清理前后SHA-256一致，包括被清理重复项的保留副本、38个识别出的短视频相关目录、旧B00/B11/B12、新local-rollout最终媒体、S250/S251暂停实验及六页整改待复验媒体。
- 清理前可用13.28 GB，清理后实测31.14 GB。并发任务仍可能消耗磁盘；未将不同时间点的净空间差当成精确删除量。
- 本轮与上一轮累计删除6,084个媒体文件，30,004,894,946字节（30.00 GB）。这不含10-27的编译产物/缓存清理。

## 保留边界

- 生产源码、日志、JSON数值、xcresult及模拟器数据不在删除范围。
- 视频台账、待发布目录、短视频素材和成片保留。教学母图/资源副本虽进入初筛媒体统计，未由本轮按截图删除。
- v62 S250/S251袋口试验暂停，约5.6 GB媒体保留；v63 W07/W08/W17等台账仍有待验边界，整个任务不走去重删除。
- 每日适配旧链仍有独立待复验问题、六页整改有暂停字号/旋转问题，未批量删除。
- 剩余媒体不是本轮全部确认有效；本轮未确认不用的文件继续保留，不把不确定性转化为删除授权。

## 按目录汇总

|目录|删除数|GB|
|---|---:|---:|
| `output/table-control-layout-20261017` | 1046 | 13.395 |
| `output/render-quality-v62` | 2173 | 2.102 |
| `output/ui-inventory-20260915` | 478 | 0.746 |
| `output/rest-activity-design-20261018` | 158 | 0.450 |
| `output/daily-safe-area-c47-20261007` | 122 | 0.151 |
| `output/global-camera-compare-20260928` | 187 | 0.150 |
| `output/shot-camera-overlay-20261003` | 35 | 0.097 |
| `build/camera-isolation-20260929` | 31 | 0.094 |
| `output/temporary-shot-camera-20261003` | 20 | 0.065 |
| `output/v57` | 63 | 0.061 |
| `build/camera-surface-s4-20261005` | 18 | 0.050 |
| `build/camera-surface-s3-20261005` | 17 | 0.046 |
| `build/camera-surface-production-20261005` | 17 | 0.046 |
| `output/landscape-camera-v31-20261003` | 19 | 0.044 |
| `output/rest-system-matrix-20261018` | 17 | 0.036 |
| `output/table-materials-v64` | 35 | 0.034 |
| `output/render-system-audit-20261011` | 14 | 0.032 |
| `output/ball-move-audit-20261019` | 6 | 0.018 |
| `output/profile-crown-20261016` | 93 | 0.018 |
| `output/pro-return-theme-20261019` | 53 | 0.017 |
| `output/diamond-position-fix-20261019` | 6 | 0.016 |
| `output/menu-retention-20261019` | 6 | 0.012 |
| `build/daily-3d-20260927` | 12 | 0.011 |
| `output/profile-crown-20261019-r11` | 32 | 0.011 |
| `output/drill-align-dedupe` | 17 | 0.011 |
| `output/daily-figma-workspace-20261006` | 4 | 0.010 |
| `output/drill-layout-aligned` | 16 | 0.009 |
| `output/today-drill-links` | 14 | 0.008 |
| `output/profile-crown-20261019-r9` | 22 | 0.007 |
| `output/separation-eightball-20260916` | 2 | 0.007 |
| `output/daily-entry-fix-20261019` | 3 | 0.007 |
| `output/ghost-center-height` | 4 | 0.006 |
| `output/information-simplification-20261014` | 2 | 0.006 |
| `output/theory-articles-rewrite-20261016` | 15 | 0.006 |
| `output/profile-crown-20261019-r8` | 15 | 0.005 |
| `output/table-entry-memory-20261013` | 4 | 0.005 |
| `output/aim-assist-fix-20260910` | 3 | 0.005 |
| `output/profile-header-20261018` | 14 | 0.004 |
| `output/pro-unlock-style-20261019` | 12 | 0.004 |
| `output/onboarding-art-direction-20261017` | 1 | 0.003 |
| `output/pro-crown-entrances-20261019` | 4 | 0.003 |
| `output/cue-stroke-20261014` | 18 | 0.003 |
| `output/angle-assist-rail` | 2 | 0.003 |
| `build/cue-crown-20260929` | 4 | 0.003 |
| `output/profile-crown-20261019-r7` | 10 | 0.003 |
| `output/daily-capacity-c48-20261007` | 10 | 0.003 |
| `output/angle-error-colors` | 6 | 0.003 |
| `build/camera-surface-s8-20261005` | 3 | 0.003 |
| `build/camera-surface-s9-20261005` | 1 | 0.002 |
| `output/angle-recent-results` | 2 | 0.002 |
| `output/pro-button-preview-20261019` | 3 | 0.002 |
| `output/practice-type-badges-20261013` | 2 | 0.002 |
| `output/account-sync-choice` | 8 | 0.002 |
| `output/green-pot-line-20260910` | 2 | 0.002 |
| `build/quality-diagnosis` | 1 | 0.002 |
| `output/toast-dismiss` | 2 | 0.002 |
| `build/daily-blue-20260923` | 1 | 0.002 |
| `output/angle-aim-rules-20261015` | 4 | 0.002 |
| `output/p01-standard-fix-20261021` | 1 | 0.001 |
| `output/drill-layout-repair` | 5 | 0.001 |
| `output/profile-refinement-20260910` | 4 | 0.001 |
| `output/pro-brand-omissions-20261019` | 4 | 0.001 |
| `build/daily-3d-landscape-20260923` | 1 | 0.001 |
| `build/cue-visibility-20260928` | 1 | 0.001 |
| `output/account-sync-repair` | 2 | 0.000 |
| `output/snake-practice-20261015` | 2 | 0.000 |
| `output/profile-structure-20261013` | 1 | 0.000 |
| `build/rerack-cue-20261004` | 1 | 0.000 |
| `output/template-card-layout` | 1 | 0.000 |
| `output/table-control-layout-rework-20261019` | 1 | 0.000 |
| `output/history-refresh-20261018` | 1 | 0.000 |

## 审计文件

- [结果](../output/media-cleanup-20261028-round2/result.json)
- [逐文件删除清单、SHA-256、保留副本或替代依据](../output/media-cleanup-20261028-round2/deleted.jsonl)
- [保留文件哈希](../output/media-cleanup-20261028-round2/protected-before.json)
- [执行清单](../output/media-cleanup-20261028-round2/execution-plan.json)
- [第一轮记录](DISK-MEDIA-CLEANUP-20261028.md)

第一轮的保留校验是当时事实；本轮进一步确认旧方案B02–B10已被撤回并替代，因此其中部分上轮暂留的阶段媒体已清理。历史截图链接可能失效，原测试结论和失败记录不改写。未运行App功能测试，本轮验证限于媒体清理与保留文件完整性。
