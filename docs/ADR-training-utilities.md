# 训练首页辅助功能与补记数据契约（2026-09-10）

状态：用户批准实施；验证结果见 tasks/training-utilities/README.md。

## 决策

训练首页只保留更多菜单，顺序为训练心得、补记训练、训练提醒、使用帮助。官方计划与新建模版继续从原有内容区进入。辅助页采用现有语义色、系统分组表单、绿色导航与原生返回；首页本周训练卡不改布局或真实数据来源。

心得按当前 owner 的 drill 会话聚合整次与动作心得，日期倒排，搜索真实文本及标题快照。cognitive/tool 的 note 是功能名称，不能作为心得展示。免费沿用最近 60 天，Pro 全部；读取与编辑保持相同判定。多课相同心得按各自真实会话保留，不按文本去重。

## 补记来源，保持 V5 schema

补记是实际球台训练，kind=drill，sourceKind=manualTraining。内容用 sourceTitleSnapshot；日期型数据使用现有可同步的 sourcePayloadVersion=1 与 sourcePayloadSnapshot，JSON 为 Gregorian 的 year/month/day。reportingDate 按当前当地日历重建该日期，隐藏伪造起止时间。date 仍提供旧客户端排序兼容值；旧客户端可能显示为“训练记录”，不保证识别补记。

这套字段已被 TrainingSessionDTO、后端严格 schema、SyncRestoreService 保留，因此不增加 SwiftData 属性或改变 V5 schema。仅扩充来源语义，不改写 note 为机器标记。无 planId、scheduleItemId、lessonId、progressRole、DrillEntry/DrillSet；不调用正式课程完成事务。

新建在独立关闭 autosave 的 context 一次保存会话与待同步队列，稳定 UUID 防重复；取消零写入、失败保留草稿。编辑校验当前 owner 和历史权益。既有删除/同步按 session ID 处理。目标天数、时长包含补记；同日去重天数，时长累加；动作分类、成功率和今日课程完成数排除无成绩补记。

## 提醒

设备级偏好，不随账号同步。两个入口打开同一个页面，草稿保存后生效。默认继承旧每日/19:00 配置；持久化当地 hour/minute，weekday 使用 Foundation 周日=1，界面按周一到周日。旧 daily ID 与七个 weekday ID 统一管理，重复保存替换固定 ID；失败尝试恢复原请求，恢复失败关闭状态并提示。仅显式开启请求系统权限；回到前台、系统时间变化时核对权限并重建。通知点击回首页，保留训练 VM。

不承诺已练免打扰、远端推送或多设备通知合并；实际通知到达、系统专注模式与真机恢复另验。
