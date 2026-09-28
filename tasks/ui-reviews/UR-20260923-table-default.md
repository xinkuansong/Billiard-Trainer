# 球桌默认风格验证（2026-09-23）

按用户要求，TableStyle.defaultStyle = charcoal；显示名为“标准”，设置列表置首。原 standard 显示为“经典原木”。UserPreferences 无值/未知值、AngleTrainingScene 默认请求、SequenceVideoExporter.Options 均使用统一默认。保存 rawValue 不变，已有用户选择继续生效。

内部 TableAppearance / PocketLeatherMarker 的 standard 代表尚未换肤的原始材质，保留该初始化状态，避免同值短路跳过 charcoal 应用。所有真实球桌页面、动态卡片与后续离屏生成继承共享场景；已有打包图片和已导出视频未重新生成。

验证设备：iPhone SE（QD004-M2-Startup-20260908），iOS 17.0。
- 改前 TableStyleUITests/testSelectPersistPreviewAndTrainingPages：Executed 1 test, with 0 failures。
- 改后 TableAppearanceTests：Executed 7 tests, with 0 failures；覆盖三条渲染管线默认值、保存/未知值回退、换肤隔离、原始材质还原、袋口角色与重建。
- 改后相同 UI 流程：Executed 1 test, with 0 failures；五款选择、重启保存、自由击球与分离角页面继承。
- 目视审查：新“标准”为炭黑木纹，首行名称/副标题/选择状态清晰；“经典原木”可还原，无新增文字截断。离屏 charcoal 图像与设置预览一致。
- git diff --check 与 verify-doc-size 通过。

证据：build/table-style-default/{before,after}.log、before-attachments、after-attachments。
新标准设置图：after-attachments/61B91337-C66A-4F77-ABDE-4BEEEEA9ED13.png。
经典原木设置图：after-attachments/0F53AE89-A226-4A9F-85D5-B0F975283E64.png。

边界：本轮未做真机安装、Dark/iPad 全矩阵或重新出片；不宣称这些已验收。工作区既有性能改动保留，未提交/发布。
