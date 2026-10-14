# 原生截图图册恢复资料

本目录的 `verification.json` 记录冻结基线、视口与独立PNG数量、基点 `.fig` 的SHA和验证边界。`review.json` 中图片路径相对本目录；`originalPath` 等旧绝对路径仅作来源记录。整个目录一起复制后，生成导入包不依赖原项目目录。

这份资料不等于最新完整 `.fig`，也不证明Figma云同步或回导成功。评论和用户后续编辑不能由截图清单重建。同盘APFS独立克隆不是异盘灾备。

## 恢复步骤

1. 保留原待同步文件，不关闭或重载。将 `base-1773.fig` 导入独立的新文件，不能覆盖原文件；此固定文件名仅为本轮基点，不应替代核对 `verification.json`。
2. 新文件名设为「球迹｜App原生截图评审」（导入器要求），用新文件URL核对目标，避免同名误选原文件。
3. 执行 `python3 restore-package.py --batch 1 --output ../restore-001`，默认每批最多80项。总批数是review.json中images数量除80向上取整。逐批生成，避免积存base64副本；脚本只生成插件，不运行Figma。
4. 在恢复文件中加载新包的 `manifest.json`，运行后读取 `IMPORTED_READBACK_OK` 并保存回执、检查实际画板。基点已存在的相同slot+SHA会跳过；旧历史画板可能不在当前review索引，总数不一定相等。
5. 完成各批后核对节点映射、图片尺寸、布局、当前槽位及历史引用。只有实际回导和视觉核对通过才能标 `figmaRestoreVerified`；用户验收仍独立。

生成导入包、检查其中PNG的SHA只证明包正确，不等于已经在Figma恢复。
