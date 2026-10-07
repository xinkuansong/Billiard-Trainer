# GitHub 与 Figma 保存核验（2026-10-08）

用户授权将当前代码提交并推送到 GitHub，同时将相关 Figma 文件保存到云端。

## GitHub 范围与验证

- 分支 `main`，远端 `git@github.com:xinkuansong/Billiard-Trainer.git`；提交前 fetch 后分歧 0/0。
- 收录已盘点的100个源码、测试、配置、技能、设计规范、批次记录及研究/视频脚本文件，另含本记录。包括每日适配、入口回退、Metal修复及另一任务已完成的三风格天花板实现；不对其继续改版。
- 保留本地 `output/`、`tmp/`，不上传构建缓存、运行截图和 `.fig` 大备份到 GitHub。两张约3MB的布局参考图属于任务规格，随文档提交。
- 凭据模式扫描无命中；暂存文件与盘点清单一致；构建期间工作区指纹未漂移。
- `make -f scripts/Makefile build`：`BUILD SUCCEEDED`，缺少xcpretty后Makefile自动回退成功。
- `make -f scripts/Makefile verify-gate`：FAIL 0；UI基线66截图、81路由、172写入面；DTO FAIL 0 / WARN 0。
- `make -f scripts/Makefile verify-doc-size` 与 `git diff --cached --check` 通过。
- 本次提交前重跑构建与门禁，没有重跑完整UI测试矩阵或真机测试；历史B8和房间测试证据保持各自边界。
- 提交、推送及远端一致性结果以本记录所在提交的Git回执和会话交付为准；本条不预先宣称推送成功。

## Figma 云端

在原文件中创建命名版本，未另建副本替代原链接，也未改变分享权限：

- [精调待确认](https://www.figma.com/design/IL72KwWm26hYHlRMYxxEQY)：`2026-10-07 每日清台布局优化 v4.1｜C47–49／D1–D2`。
- [用户粗调](https://www.figma.com/design/GrxszFhgQ1Bt3dkOxmNRdU)：`2026-10-07 每日清台布局优化｜用户粗调归档`。

两条版本均已在独立浏览器会话打开原文件后，从版本历史读回。精调云端页面列表包含C47、C48、C49、D1和D2，D2画板名称可读取。桌面精调端仍有重连提示，因此不以桌面提示作为成功依据，也不声称所有节点已逐字节比对；云端证据来自独立会话。

本地最新完整备份已再次导出，ZIP CRC检查通过；操作跨越午夜，版本名及证据目录保留操作开始日20261007。

|备份|字节|SHA-256|
|---|---:|---|
|daily-refined-cloud-sync-20261007.fig|71546677|6960f5812b15bce2f76d95fbdc453483bd719f173b7b27564659eeb8ca21d8c3|
|daily-rough-cloud-sync-20261007.fig|83425665|a404f9b014b98d61508ce16ccf2c3c2f6189522501c39e43241c2d9615864563|

备份、云端历史截图及构建/门禁日志：`output/github-sync-20261007/`。未做完整备份独立回导、真机手感、VoiceOver或App Store发布。
