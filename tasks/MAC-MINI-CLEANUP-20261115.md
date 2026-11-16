# Mac mini 历史任务清理 · 2026-11-15

用户要求继续清理已结束任务的历史资料，保留最终成果及关键失败证据。本轮仅回收核实已结束或被替代的队列构建、源码和不再被引用的快照。

## 结果

核查并归档46个历史任务，通过统一队列 `fetch --complete` 完成证据校验与收尾。其中44个任务已回收 `build` / `source`；2个任务因仍有进程或文件句柄引用被工具保留，没有绕过保护。删除后重新计算46份远端证据摘要，全部与已验证归档回执一致。独立远端读回确认46份任务的 evidence 和 worker.log 全部仍在。

队列实测分配量由173,956,224 KiB降至78,139,884 KiB（约178.13→80.02 GB，净减少约98.12 GB）。期间有新的远端构建和另行授权的文件传输；该差值及df均为同期观察值，不能视为严格隔离的删除量。首次df可用约27.12 GB，清理后测得约94.98 GB；后续传输还会使用部分空间。

## 完成依据

- 布局R05–R07：各IMPLEMENTATION记录已完成对应手机、iPad和共享链验证；旧全局编辑方案又由用户否决并被L00–L06替代。
- 菜单保留：UR-20261019-menu-retention记载最终8项定向测试通过，原设备数据恢复、租约归还。
- 每日入口：UR-20261019-daily-entry-stall的10-20最终收尾记录手机、SE及iPad补验完成。
- 移球r1：BALL-MOVE-AUDIT-20261019记录最终r9手机/平板完成，早期r1被替代。本轮保留后续原始失败及最终任务。
- 角度设置：UR-20261019-angle-settings记录11项单元和标准/小屏UI通过，租约释放，原分配失败和测试定位失败的结论保留。

每个任务先回传当前完整证据并校验，再提交收尾原因；队列再次检查证据回执、冻结源码一致性、进程句柄、模拟器租约与保留状态后执行删除。没有清理模拟器、当前topdown候选、未知任务、独立证据区或远端个人文件。

- 引导及休息：10-18对应UI复核记录显示最终运行完成；休息pad11的回收中断已恢复。11-10/11首发引导与计时逻辑已另做新实现和验证，旧构建无需复用。本轮回收这11个任务，原始证据不删。

- 后续核查：daily-loop四轮、rail-sights两轮、Pro品牌两轮、皇冠入口两轮，均有后续定向验证完成或新版替代记录；全部证据保留。Pro工具三轮的容量/AX定位失败已诊断并有最终权限证据；引导pad-r3由r4复验闭环，布局R05-pad-r02由r06/r07及L00–L06替代。

## 精确结果

| 队列任务 | 处理 |
|---|---|
| `angle-settings-after-20261019` | 已回收构建及源码，证据保留 |
| `angle-settings-after-r2-20261019` | 已回收构建及源码，证据保留 |
| `angle-settings-after-r4-20261019` | 保留：DTServiceHub仍持有源码目录句柄 |
| `angle-settings-before-20261019` | 已回收构建及源码，证据保留 |
| `ball-move-20261019-r1` | 已回收构建及源码，证据保留 |
| `daily-entry-baseline-20261019-r5-phone17` | 保留：DTServiceHub仍持有源码目录句柄 |
| `daily-entry-fix-20261019-r2` | 已回收构建及源码，证据保留 |
| `daily-entry-fix-20261019-r3-phone17` | 已回收构建及源码，证据保留 |
| `daily-loop-20261019-r1` | 已回收构建及源码，证据保留 |
| `daily-loop-20261019-r2` | 已回收构建及源码，证据保留 |
| `daily-loop-20261019-r3` | 已回收构建及源码，证据保留 |
| `daily-loop-20261019-r4` | 已回收构建及源码，证据保留 |
| `diamond-sights-20261019-r1` | 已回收构建及源码，证据保留 |
| `diamond-sights-20261019-r2` | 已回收构建及源码，证据保留 |
| `layout-rework-r05-pad-r02` | 已回收构建及源码，证据保留 |
| `layout-rework-r05-phone-r01` | 已回收构建及源码，证据保留 |
| `layout-rework-r05-r04` | 已回收构建及源码，证据保留 |
| `layout-rework-r05-r05` | 已回收构建及源码，证据保留 |
| `layout-rework-r05-r06` | 已回收构建及源码，证据保留 |
| `layout-rework-r05-r07` | 已回收构建及源码，证据保留 |
| `layout-rework-r06-r01` | 已回收构建及源码，证据保留 |
| `layout-rework-r06-r03` | 已回收构建及源码，证据保留 |
| `layout-rework-r07-r01` | 已回收构建及源码，证据保留 |
| `menu-retention-20261019-after-r2` | 已回收构建及源码，证据保留 |
| `menu-retention-20261019-before` | 已回收构建及源码，证据保留 |
| `menu-retention-20261019-before-r2` | 已回收构建及源码，证据保留 |
| `menu-retention-20261019-final` | 已回收构建及源码，证据保留 |
| `onboarding-r6-compact-r4` | 已回收构建及源码，证据保留 |
| `onboarding-r6-pad-r3` | 已回收构建及源码，证据保留 |
| `onboarding-r6-pad-r4` | 已回收构建及源码，证据保留 |
| `onboarding-r6-phone-r4` | 已回收构建及源码，证据保留 |
| `pro-brand-20261018-r2-phone` | 已回收构建及源码，证据保留 |
| `pro-brand-20261018-r4-small` | 已回收构建及源码，证据保留 |
| `pro-crown-entrances-20261019-r1` | 已回收构建及源码，证据保留 |
| `pro-crown-entrances-20261019-r2` | 已回收构建及源码，证据保留 |
| `pro-tools-20261019-phone16-r1` | 已回收构建及源码，证据保留 |
| `pro-tools-20261019-r1` | 已回收构建及源码，证据保留 |
| `pro-tools-20261019-se-r1` | 已回收构建及源码，证据保留 |
| `rest-style-max-r3` | 已回收构建及源码，证据保留 |
| `rest-style-mini-r3` | 已回收构建及源码，证据保留 |
| `rest-style-notch-r2` | 已回收构建及源码，证据保留 |
| `rest-style-pad11-r3` | 已回收构建及源码，证据保留 |
| `rest-style-pad13-r2` | 已回收构建及源码，证据保留 |
| `rest-style-padmini-r2` | 已回收构建及源码，证据保留 |
| `rest-style-phone-r6` | 已回收构建及源码，证据保留 |
| `rest-style-se-r5` | 已回收构建及源码，证据保留 |

[队列回执与完成原因](../output/mac-mini-cleanup-20261115/receipts.json) · [远端删除后读回](../output/mac-mini-cleanup-20261115/remote-after.json)。回执内 archive_path 指向本机完整证据归档，不应移动或删除该归档。未运行App测试；本轮验证限于资源收尾协议与实际存储结果。
