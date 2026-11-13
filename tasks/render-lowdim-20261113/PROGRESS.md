# 3D 渲染研究进度

> 2026-11-13 续接入口已改为[3D 活动期性能优化 v1](../问题集合_3D活动期性能优化_v1.md)。下文是 R17 历史快照，不再代表当前待办；后续已完成推广与成本分析见 [ROLLOUT](ROLLOUT.md) 和 [COST-ENERGY-AUDIT](COST-ENERGY-AUDIT-20261113.md)。新方案实施尚未开始。

更新：2026-11-13，R17-r2存储故障收口。用户已恢复持续研究；当前没有正在执行的新采集或正式ABBA。

| 项目 | 状态 | 证据/边界 |
| --- | --- | --- |
| guard局部算法、双GPU真实材质、页面接线 | 已取得所列验证 | 详见[结果入口](RESULT.md)，不外推整页净收益 |
| 本机原生完整固定SceneKit场景 | 通过 | r9精确selector 1/1、864测量帧；不含SwiftUI活动与呈现 |
| 原生真实App包装启动、每日清台3D | 已验证 | r9二进制身份一致，真实UI进入16球开球准备；本轮结束已正常退出App2918 |
| R17-r1整页结构采集 | 失败后离线恢复部分可读数据 | CPU/footprint可读；App GPU=0、操作覆盖=0，原failed保留 |
| R17-r2整页结构采集 | 保存失败 | recorder8107报ENOSPC；无summary/TOC，六次真实UI动作覆盖未证实 |
| r1冗余临时文件回收 | 已完成单文件回收 | hash/inode/无句柄核对；最终trace与恢复证据保留 |
| r2残留资源 | 服务已收尾，失败原件hold保留 | owner8100/recorder8107已亡；ktrace同卷移存work后只TERM已归属的8121，现无服务/句柄。约12GiB原件和41MiB partial保留，旧run.json残留running未伪改为通过 |
| 下一轮轻CPU采集 | 未执行 | 先任务私有TMPDIR/空间门禁，再核正常结束、导出、signpost配置和真实输入覆盖 |
| 完整页面R/guard、连续多球、实际present、资源趋势 | 未完成 | 不用静态GUI、开始通知或完整固定场景替代 |

r2的[UI动作原件](../../output/render-lowdim-20261113/native-direct-smoke-r2-ui/actions.json)保留；开始通知证明录制器发出了started事件，不能在没有TOC时断言动作已采到。未击球，不能称多球动态负载。

[逐轮记录](ITERATIONS.md)保留假设和失败；[存储故障与回收报告](../../output/render-lowdim-20261113/native-trace-storage-recovery-r1/REPORT.md)记录本轮恢复边界。手机仍供用户手动试用，Mac mini不重连；本轮未改源码、发布默认或候选画质容差。
