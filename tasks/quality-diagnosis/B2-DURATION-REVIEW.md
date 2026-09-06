# B2 组用时编辑与会话时长复核

状态：冻结 snapshot-002 只读核查，未改业务、未运行测试、不新增问题编号。

**结论：当前证据不能认定“组用时改为150秒后总时长仍0分钟”是保存失败或统计刷新bug。两者在冻结实现中是独立字段，既有测试甚至明确要求编辑组成绩后保留会话总时长。** 应记录为口径解释/产品语义待确认，同时将不足一分钟显示0与秒级精度损失单独保留为展示/计量风险。

## 实际证据

- 本轮实际查看 `build/quality-diagnosis/formal-b2-003/screenshots/history-297EB291-3305-4BC7-A843-455E9ECCD91E-saved-detail.png`：备注QD-845CF7A4、第一组7/9、顶部0分钟、时段22:03–22:03；其余7组0/15，总7/114。
- 实读 `formal-b2-003/stored-values.json`：对应QD-845CF7A4的第一组 made7/target9/durationSeconds150，证明150已写入该组。该JSON**没有session.totalDurationMinutes字段**，不能单凭它声称已经SQL验证会话时长。
- 本轮实际查看 `formal-b2-004/screenshots/history-83FE589B-E9BA-4B8B-8134-15C6A4BDE47F-saved-detail.png`：QD-44C092F3，第一组7/9、0分钟、22:11–22:11，复现相同展示。编辑器重启仍150及原始总训练十几秒由主控正式测试提供，本轮未自行重跑。004未单独读取组值SQL结果。
- 上述绿勾/未操作组影响沿用 `PARTIAL-TRAINING-FINDING.md`，不是本轮新增时长问题。

## 数据链与确定事实

以下代码路径均相对 `build/quality-diagnosis/snapshot-002/`。

| 层次 | 来源 | 语义与结果 |
|---|---|---|
| 会话计时 | `QiuJi/Features/Training/ViewModels/ActiveTrainingViewModel.swift:520–545` | 使用开始时间差+暂停前累计；暂停后不继续累计。准确说是会话计时器累计有效时间，并非无条件结束减开始的纯wall time。没有求和各组duration。 |
| 首次保存 | 同文件`:1048–1049,1094` | `session.totalDurationMinutes = elapsedSeconds / 60`整数截断；每组`durationSeconds`独立由setData.duration四舍五入存入。十几秒保存为0分钟可由此直接解释。 |
| 组计时 | `…/Training/Views/DrillRecordView.swift:388–399` | 启用组计时时完成该组记录Date-startTime；取消完成会清nil。未开启计时或旧记录允许nil，因此组时长并不是完整session时间账本。 |
| 模型 | `QiuJi/Data/Models/TrainingSession.swift:12`；`DrillSet.swift:20–21,38` | 会话Int分钟与组可选Int秒是独立持久化字段，没有自动衍生关系。 |
| 编辑器 | `…/History/Views/TrainingDataEditorView.swift:22–23,80,106–109,141–167,267,306–310` | UI明确“第N组用时秒”；150合法并写`model.durationSeconds`，不改session。nil表示未记录。 |
| 保存调用 | `…/History/Views/TrainingDetailView.swift:497–500` | 调用draft.apply；draft内不重算会话字段。 |
| 历史详情 | 同文件`:185,457,563–564` | 顶部、分享用session分钟；时段结束按session.date加分钟推导，因此0分钟呈现相同起止时刻。未用组用时汇总。 |
| 统计/个人/首页 | `…/History/ViewModels/StatisticsViewModel.swift:173–177,199–201`；`…/Profile/Views/TrainingGoalView.swift:39–50`；`…/Training/ViewModels/TrainingHomeViewModel.swift:98` | 汇总session.totalDurationMinutes。编辑组秒数没有理由触发不同数值，这不是异步刷新遗漏。 |
| 既有回归意图 | `QiuJiTests/V29W2bTrainingDataEditTests.swift:101–139` | `test_apply_persistsScoreEdits_andKeepsSnapshotFields`将第一组改150、第二组清空，并在136–137明确“session级字段不开放编辑”，断言totalDurationMinutes仍20。此处只读方法，未声称本轮运行通过。 |

## 有效预期与不应采用的旧说法

`docs/04-功能规划.md:58`保留真实训练时长记录与历史统计；`docs/05-信息架构与交互设计.md:250–259,281`规定显示训练时长/总时长/月概览，但本轮定向查阅没有找到“修改组时长必须重算会话总时长”的产品裁定。

现行`.kiro/steering/content-data-contract.md:266`提出每组可选durationSeconds，与冻结模型相符；但其`:231,822`仍写“模型无字段、采集即丢”，已被冻结实现和本次150落库事实替代，是历史偏差段未更新，不能用作当前丢数据判据。契约没有明确要求二者相等；既有测试支持编辑范围只在组数据。

## 分类与后续处理建议

1. **确定：本次组用时保存成功。** 不应登记“150没保存”或“统计未刷新”。会话计时独立、编辑不联动是可追踪的实现/回归测试选择。
2. **待明确：用户纠正组用时是否也意在纠正训练总时长。** 若产品希望两者独立，需要让用户理解总计时含休息/组外时间、部分组可未计时。若希望更正总训练时间，应有明确总时长编辑规则；不能简单将可选组秒数求和覆盖，因为会漏掉休息/组外时间及未计时组，也会改动原时段。这是产品决策，当前不能擅自修复。
3. **确定精度事实、缺陷等级待定：小于60秒的session永久存0分钟。** 每场先截断再汇总，例如三场各59秒记录总0分钟而实际177秒；这并非本次组编辑导致。会话没有原始elapsedSeconds字段，历史无法分辨真正0秒与59秒。是否接受分钟粒度需有效阈值/规格判断。
4. **展示疑点：同次训练总结页与历史页口径表达不一致。** `TrainingSummaryView.swift:25–31`已经特意用“不足1分钟”，历史详情直接“0分钟”，可能让用户误以为没计时。建议先作为可复现体验观察，不扩展为未经授权的修复，也不假设把历史所有0值改“不足1”都正确（存在未计时/旧数据）。

若主控继续取证，可只读取已生成专用store中该session的totalDurationMinutes，与相同记录组秒数并列；再用既有编辑测试佐证字段保留。只有产品明确要求联动，才新增“修改组时长应改变总时长”的失败断言。当前无需为确认已知两条赋值链再启动模拟器。
