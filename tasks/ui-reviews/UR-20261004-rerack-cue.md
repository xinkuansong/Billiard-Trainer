# UI 审查报告 — 每日清台运动中重开

日期：2026-10-04。范围：球杆重置及可见性；iPhone 17 Pro / iOS 26.3 / Debug。

## 证据与观察

证据根目录：`build/rerack-cue-20261004/`（仓库根目录下）。

- 修前构造性迟到回调 `before-attachments/C4FD23E6-377D-454E-A28D-C97C86EF5736.png`：母球已摆回，旧杆仍偏向侧方，与新母球脱离。`2B69C2AB-54DB-4E17-9E29-E96ED91DD0CD.png`：尾帧新杆被旧收杆隐藏。
- 修后同场景 `after-attachments/73BE4BEC-EE65-4394-AF7A-288E40B9722E.png` 与 `6BDDD6B1-9353-42B8-8EDB-298300CDD04D.png`：新杆沿新母球至球堆方向摆放，迟到动作排完仍保持可见。场景尺寸均 640×400，固定同机位对照。
- 真实页面 `before-screens/cue-restart-new-rack.png` 及 `after-screens/cue-restart-new-rack-0.png`、`cue-restart-new-rack-4.png` 已查看：正常重开均完整显示球桌、母球及瞄准杆，修后杆头贴近新母球，沿默认开球方向。
- `after-screens/cue-restart-new-stroke.png` 已查看：可再次击球，球堆散开，球杆处于正常跟杆阶段。

## 审查结果与边界

本次目标相关新增视觉问题 0 项。没有改动布局、Token、文案或交互触摸尺寸；页面截图中现有控件保持可用，未观察到本次引入的截断/遮挡。Dark Mode、Dynamic Type、多尺寸与真机观感未专项覆盖，不作全页面设计验收结论。

数值/交互证据独立于目视：9 核心 + 1 UI 测试通过，UI 对每次重开在两个时间点检查实际杆轴、位置与透明度。修前构造性回调测试失败、修后通过；正常页面旧版测试修前也通过，因此不将修前正常页面图冒充自然复现截图。

实现及日志索引：[任务记录](../DAILY-RERACK-CUE-20261004.md)。真机用户原始操作待复验；未发布。
