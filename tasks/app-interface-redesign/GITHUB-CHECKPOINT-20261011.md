# 当前版本 GitHub 保存记录

2026-10-11。用户要求先提交并push当前版本，再重写原生截图详细方案。

## App 断点

- 提交：[f75cbafd](https://github.com/xinkuansong/Billiard-Trainer/commit/f75cbafdc455e5521a248d2187943956456dcaaa)。
- 远端：`git@github.com:xinkuansong/Billiard-Trainer.git`，`main`；推送输出 `2cd43617..f75cbafd main -> main`，命令退出0。
- 内容：222文件变更；当前App/测试/配置、模型试用资源与已有设计记录。保留原有跨会话工作，不将其称为本轮新实施。
- 不包含：忽略的output截图/Figma/构建缓存、未跟踪的tmp临时目录；已跟踪的历史tmp文件未删除。GitHub代码保存不等于本机证据全量备份。
- 验证：Debug `BUILD SUCCEEDED`且make真实退出0；`verify-gate`通过（UI基线66、路由81、写盘175）；文档体积通过；暂存diff检查通过。未重跑完整单测/UI矩阵、未安装或发布。
- 门禁首轮发现 `ModelAssetPerformanceTests.swift` 未登记写盘范围；已读源码补齐目录、触发条件和覆盖风险，第二轮通过。没有删除测试或降低门禁。
- 本次推送曾被自动审批因远端归属未核实而拒绝；随后GitHub SSH确认登录账号xinkuansong，与既有origin所有者一致，再次审批通过后正常推送。

## Git LFS

新增两项候选模型按精确路径纳入LFS，原文件字节未变；上传回执 `100% (2/2), 130 MB`。本机安装git-lfs 3.8.0，仅本仓库配置过滤器。已有pre-push门禁保留，在其末尾追加LFS上传；版本化钩子同步更新。

| 文件 | 字节数 | SHA256 |
|---|---:|---|
| ModelTrial20261010_TaiQiuZhuo.usdz | 128835793 | 704bd98b17534c8046ab5027da63655e2867964760f893c1240a753742384586 |
| ModelTrial20261010_CueUV.usdz | 1239924 | 9288907e666d897e4f3be5b94e7ec989eb5a75116f74a07d3790e4340f2e117e |

其他机器拉取本次模型需安装Git LFS并执行`git lfs pull`，安装项目钩子仍用`scripts/Makefile`既有install-hooks入口。未改远端可见性、未强推或改写历史。

## 新方案

[PLAN v3.0](PLAN.md)是后续需求真源，代码断点不变。方案另作文档提交；N00采集盘点、试采及代码修复尚未启动。新提交详情以Git历史和本轮最终回执为准。

本地原始日志：`output/github-checkpoint-20261011/`（build.log、verify-gate.log、verify-gate-r2.log、push-current.log）。
