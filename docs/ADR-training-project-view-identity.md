# ADR：练习项目与显示视图分离

日期：2026-10-28。状态：用户授权实施，按批次验证中。

## 问题与决定

七类练习已有共享 Swift View，但路由中的 2D/3D 决定会话、权限、偏好和恢复来源。改投影不能重新初始化题目、物理输入或成绩。沿[完整方案](../tasks/table-page-adaptation/TRAINING-VIEW-MERGE-PLAN-20261028.md)，以 `TrainingProject` 表示项目，以 `TrainingViewMode` 表示正式视图，同一个 ViewModel 和场景持有业务状态。

既有记录的 `is3D`、`quizType`、`sourceId` 和评分版本保持原值。新可选 `TrainingPresentation` 写入现有 Codable 负载，记录当前视图、题前观察集合、冻结提交视图和消费凭证；不增加 SwiftData 实体或改变 Schema。旧负载没有该字段时按原视图解释；恢复旧草稿时标明已消费题，禁止把旧 3D/Pro 成绩追扣成免费额度。

六项普通轮次/每日额度为 15，多球为 3；独立预测工具原共享额度保留。`TrainingQuotaLedger` 按既有项目桶迁移，旧 count 与 ledger 取并集不相加。生产使用 Application Support 下单个 JSON 文件的原子替换，同进程的所有窗口由共用锁串行预留。预留不计作已完成，进程身份更换后回收未提交预留。业务事实先保存，额度后幂等兑现；消费凭证冻结题目 UUID、首次接受时间及当时权益，恢复补账不会跨日再扣或重算旧 Pro 记录。

显示偏好新增项目字典，首次依据来源选择旧页值，保留旧两份字典；通用设置仍可显式覆盖项目偏好。布局以项目和正式模式定位原 2D/3D 槽，继续使用原模板 UUID 和用户坐标，不把临时俯视写成正式 2D 布局。

## 范围和验证

此决定不改物理、评分、题库内容、账户归属或同步授权。实现覆盖和具体测试结果随[执行记录](../tasks/table-page-adaptation/TRAINING-VIEW-MERGE-EXECUTION-20261028.md)更新；本 ADR 不声明七类已完成，也不把基线或单元测试当成原生交互验收。
