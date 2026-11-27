> 2026-11-27 用户复审：轨迹标准验收撤回（FL-294）。本轮实际全部实线且到滚动才显示，与标准不符；原测试输出保留，仅证明原断言范围。修订见../feedback-r5/RESULTS.md。

# v73.7 实施与验收

2026-11-27，三项用户反馈已实施并完成本轮定向验证。未提交、发布或安装真机；真机手感及用户最终复验未验。

## 行为

1. 扎杆规则v4：首次碰目标前弧线偏离>1mm，且没有形成跳过黑八。删除离台高度上限和起终点直线必须被黑八遮挡两项；跳球技术及共同完成/犯规规则保持。失败短提示改为“未形成扎杆弧线”。旧成绩冻结，旧规则活动不混作新规则继续计分。
2. 两练习页训练设置移除演示/击球过程，固定播放正常击球。旧playsStroke字段保留解码兼容，但false不再跳过播放。成功或三杆后解锁的示范保留。
3. 提交保存成功后，击球进入滚动时显示本杆真实空间轨迹，停稳保留；重打保留上一杆，下一题清空。上一杆菜单仍可手动显隐。示范/回放消费当前播放杆，停止/自然结束恢复玩家现场及其显隐状态。恢复已有本题记录时默认可见实际路线；未答新题不提前展示预测或参考解。

轨迹复用SpatialShotRendering；没有修改共享相机、手势、材质或物理算法。before/及before.json保留本轮前源码，changes.diff为本轮局部差异，tested-source.json固定最终测试源。

## 题库

复用v3完整物理审计的保留题实测技术证据，经生产v4判定逐行重分类：扎杆1,196、跳球8,127，合计9,323全部通过。manifest升级v4并保存v3/v1审计来源；两个题目gzip包字节不变，四个先库后碰旧排除题不恢复。

本轮是规则重分类，未重新模拟全部9,323题；共同物理事件规则沿用已核旧审计，SpatialQuizPhysics与旧审计源码SHA相同。测试另外包含真实引擎正反例、分层参考及边缘/排除案例。证明见两份v4-reclassification.json、reclassification-input.json及physics-evidence-identity.json。

## 测试与视觉

受管run：ab04b72c393a4184990ad577965319e8；日志和xcresult在output/local-test-runs/<run>/evidence。

- test-results：55/55逻辑与集成方法通过，0失败。包括曲率阈值、无阻挡直线也允许扎杆、非越障离台弧线、跳球排除、共同规则、9,323条证据复核、旧配置、保存/计次/历史/示范/场景恢复。
- ui-standard：iPhone17Pro/iOS26.3.1，3/3原生方法通过（389.066s），每个覆盖两个练习页。包括设置去演示、实际击球/结果/重打/下一题、上一杆显隐/详情、示范切镜/观察/停止恢复及个人回放。
- ui-compact：iPhoneSE3/iOS17，1/1原生方法通过（96.209s），双模式设置与实际播放/结果/重打/换题。两设备共4次方法执行、3个不同方法，不冒称4个独立方法。
- verify-gate通过；git diff --check通过。
- 原生原图分别在ui-standard-images/、ui-compact-images/，已实际打开关键结果/播放/设置图，见VISUAL-REVIEW.md。没有新增遮挡或文字裁切；不是全App、全尺寸/主题或真机验收。

旧Session夹具原用playsStroke=false直接进入idle，本轮改为断言接受后playing，再显式调用playbackFinished；离屏VM集成验证playing后调用stopPlayback。实际自然播放到结束由原生UI验证，没有删除失败断言或用测试开关恢复旧跳过播放行为。

## 收尾

共享工作区其他改动保留。临时构建由local_test_lifecycle complete收尾，结果见cleanup.json；设备租约释放，核心模拟器和数据保留。后续唯一入口是用户体验本轮页面反馈，不需要重新跑上一轮全量题库物理搜索。

代表截图：[跳球结果](ui-compact-images/jumpPractice-actual-routes-result.png)、[扎杆结果](ui-standard-images/massePractice-actual-routes-result.png)、[训练设置](ui-compact-images/massePractice-settings-no-demonstration.png)。
