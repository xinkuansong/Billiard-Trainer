# 多球首杆自主选择复核

状态：实施、定向测试与原图复核完成；用户体验待反馈。本会话未执行Git提交或发布，未更新真机。

合同见[页面卡](../table-page-adaptation/MULTI-BALL-OPENING-20261030.md)。多球规划开局以手选球袋确认①，首袋确认后立即进入下一步；球桌尺寸、字体、HUD、角色色和评分沿用原页面。

## 功能验证

Mac mini、Xcode 26.2、iPhone SE 3、iOS 26.2。最终job `multi-ball-opening-delivery-20261030`，源码snapshot `8058508b0f71053d6d092d7da133781a147ca94df412a08b89317c0f5a4444a9`。

- 最终30项多球逻辑、3项UI均通过：33 passed／0 failed／0 skipped。
- 覆盖空选择、仅球、球袋确认、改球清草稿、推荐刷新、瞄准切换、重开、重打、滚动承接、旧新档恢复、规则球序、自主推荐、合法多进后的手动重选与首袋后提示切换。
- UI覆盖2D/3D开局→选球→选袋→重开，以及失败评分明细打开/关闭/重打。
- 之前同业务逻辑的5项推荐复用、1项合并检查点，以及中八完整规划与追分击球/重打流程通过。最后改动仅纯提示命中与步骤文案，未以旧截图替代最终原图。
- 本地verify-gate、verify-doc-size、Swift语法及git diff --check通过；六份改动源码与最终冻结源码哈希一致。

## 原图审查

9张最终原生图均已实际打开核对；用户截图作为改前问题基线。空选择无①角色/角色袋，选球后袋仍为空，选袋后正确显示①与目标袋并提示第二球，重开清空。纯提示不会挡住3D袋口点击，有明细的评分按钮保持可点。未发现本轮新增的文字截断、控件错位或视觉样式变化。

|状态|2D|3D|
|---|---|---|
|开局未选择|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-empty-false.png)|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-empty-true.png)|
|仅选第一球|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-ball-only-false.png)|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-ball-only-true.png)|
|首球首袋已确认|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-confirmed-false.png)|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-confirmed-true.png)|
|重新开始|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-restarted-false.png)|[原图](../../output/multi-ball-opening-20261030/final-screens/opening-restarted-true.png)|

[失败反馈与明细入口](../../output/multi-ball-opening-20261030/final-screens/planning-failure-with-info.png)。

## 失败闭环与证据

前两轮测试分别暴露测试筛选误含黑八、两种诊断探针覆盖的问题；修正测试条件，保留真实点击和状态断言。一次构建通过后因本任务遗留失败设备达到容量上限而未执行测试，按登记表退役后重跑。r3的3D首袋被短提示挡住，修正纯提示触摸穿透后同位置通过（FL-233）；截图审查再修旧提示短暂残留，最终33项及原图闭环。失败记录全部保留，不把构建通过当作功能通过。

最终证据：`output/multi-ball-opening-20261030/delivery/`、`delivery-summary.json`、`final-source-match.json`。完整源码在`delivery-source.tar.gz`，4271文件哈希已核；原始xcresult保留，分析使用副本，导出的截图与summary单独保存。临时设备及远端构建按登记流程收尾，其他任务设备不动。

## 边界

本轮不代表真机手感、iPad、VoiceOver、完整App回归、真实账号同步或发布验证；用户最终体验仍待反馈。
