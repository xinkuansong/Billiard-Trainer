# 两球训练库：舒适度85筛选与首杆难度顺序

用户于2026-10-26明确批准：只使用舒适度≥85的路线，低分留研究档案；沿用「[算法] 球形轨迹难度排序方法」的四项公式，对同题保留路线按首杆难度由低到高展示。当前角色：Orchestrator / Content / Test。

## 输入与边界

- 输入：`output/two-ball-comfort-refine-full-20261025/final`，summary complete/auditPassed；13570原始布局、173577 B位置、729384去重后推荐。
- 源parts-index SHA256：`e044c7917f16871deec621e9399982dcf6ad9978b2874e3559fb669750a7a63b`。
- 源summary SHA256：`509a6f35be19f402aed229c518dfe1a967c3fc24e96125c5040b93b57bd2d52e`。
- 不再搜索、不改物理或舒适度公式，不扩/改top5选集，不加18°/25°硬门槛；只在现有final中按未取整totalScore≥85取子集。
- 第二球舒适度、首杆执行难度、用户轨迹P2成绩分别存储。

## 导出与排序

- 13358有效首杆布局、166443道B题、677488条推荐引用；共享后552055条布局内独立轨迹。
- 排除51896条低分推荐；679道原有路线但全部低分的B题不入库；6455道源空题继续不入库。研究final/refinement不修改。
- s=abs(spinX)，h=max(spinY,0)，d=max(-spinY,0)，u=velocity/4.5，N=碰A后的主库次数，L=碰A后2mm关键点折线路径长度（米）。
- E=(2.5s+0.8h+1.2d)+0.8u²+(0.12N+0.06L)+(0.6su+0.15Ns)，D=100E/(E+1)。D越低越容易；是执行负担估计，不是成功率。L近似误差不等于2mm。
- 同B按未取整E升序；同E保留输入final推荐顺序，保存sourceRecommendationRank。当前没有精确同E对。
- `pack_comfort85.py`导出，`audit_comfort85.py`独立复核全部源/消费SHA、精确子集、保护字段、四分项、总分、索引与顺序。
- 消费schema `two-ball-consumer-v2`，行schema `two-ball-comfort85-execution-v1`，policy `comfort85-execution-v1`，公式 `execution-effort-v1`。
- 新fingerprint：`bba85ae413d6ededcd7c8338004538ad53d81bad92455ee2a08282e6bbe4ab2e`；gzip 364301457 bytes。
- 源始终只读；上一消费包整体存于`output/two-ball-consumer-comfort85-20261026/previous-consumer-v1`。

## App行为

现有2D/3D轨迹模式以第一条为最简单路线，点击“新轨迹”依序练习。出题继续执行原三球物理/打点可达性/重放RMS准入；过滤只移除路线，不改变余下顺序。用户配置及运行准入可能使实际可练数量小于离线库总数；不把166443/677488宣称为所有配置实时均可用。

自由模式沿用原流程，指定第二袋及实际停点舒适度评分不变。旧记录可解码、历史可读；缺少新bank policy的进行中记录结束归档，重新开题使用新库；不改写既有首答、回放或扣额。

## 验证

- 全量独立审计通过：166443题/677488推荐/552055轨迹；源物理参数、坐标、袋口、轨迹逐字段一致；最大独立E/D差2.842e-14；全部SHA和排序通过。
- 最终XCTest **19项**及2D/3D端到端顺序测试 **2项**全部通过（0失败）。含新库计数/读取、四项公式、低分/错误E/逆序拒绝、精确同E原序、20真实物理题、偏好过滤、旧记录解码和归档扣额保护。最终日志：`output/local-test-runs/2e2704fa828b462b90434e8df155188e/evidence/final-test-results.log`。
- 不涉及布局结构改动。依照既有两球页面清单复核TP题目/路线身份、状态切换及恢复；既有布局/输入/镜头规范继承。真机、VoiceOver与发布不在本轮已验证范围。

## 完成与证据

2026-10-26：已完成导出、App消费接入与本轮验证；未提交、未推送、未发布。

- [独立全量审计](../output/two-ball-consumer-comfort85-20261026/audit.json)、[安装核验](../output/two-ball-consumer-comfort85-20261026/installation.json)、[最终验证](../output/two-ball-consumer-comfort85-20261026/verification.json)。
- iPhone16ProMax / iOS26.3.1；2D/3D每题4条真实切换顺序：D=26.9032→50.9494→61.6532→64.3316；相应舒适度99.4785/95.9944/97.3014/97.8532。8张路线截图及8份状态附件已导出；目视核对2D首条与3D末条身份、题号/路线编号、目标线及控制状态。
- 对应设备已Shutdown、租约释放，固定评审设备不删除；临时构建目录按local-test-lifecycle收尾，证据保留。
- 原版和完整研究档案未修改，上一消费包保留，可整体回退。下一步为用户在新构建中体验同题逐条顺序；无须再跑全量物理搜索。
