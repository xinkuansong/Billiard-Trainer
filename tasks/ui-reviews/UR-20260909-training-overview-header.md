# 训练总览顶栏精简

日期：2026-09-09

用户要求：总览去掉当前杆数，项目分数改为“共 X 项”。

实现：ActiveTrainingView 共用顶栏按 showingOverview 区分；总览隐藏 currentSetProgressText，徽章显示 drills.count（含单项），无障碍标签同步。单项记录保留杆数与项目位置。徽章按固有宽度布局，防止中文拆行。

## 功能验证

- `make -f scripts/Makefile build`：`BUILD SUCCEEDED`，日志 `output/training-overview-header/build.log`。
- iPhone 17 Pro / iOS 26.2：原六动作模版正常入口 → 总览“共 6 项”，无杆数 → 点第二项显示“第 1/7 杆”和第二项位置 → 返回总览仍为“共 6 项”，无杆数。
- `git diff --check` 通过。纯展示分支改动，没有新增测试或改动计分逻辑。

## 视觉审查

已目视原图 `output/training-overview-header/before.png`、`after.png`；同模版、六动作、深色。标题和徽章完整，移除副标题后顶栏收紧，列表与底栏显示正常。本轮所查区域无新增问题。

紧凑手机、iPad、浅色、VoiceOver 实际朗读和真机未验证；单项总览计数分支已实现，未进行单项场景截图。未提交或发布。
