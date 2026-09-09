# 当前版提前结束保存复验

2026-09-07，snapshot-003。运行 formal-resume-partial-save-002，专用游客设备 CE76026D，独立内存容器、真实 ActiveTrainingViewModel 保存后新 ModelContext 读回。

实际执行 3 方法：2 失败、1 通过，共 7 个失败断言；make 2 / xcode 65。不是 7 个独立缺陷。

- 8×15 计划，仅显式完成第一组 5/15：保存 8 组、分母 120、成功率 0.0416667；应为 1 组、15、0.3333333。
- 8×15 计划，仅显式完成第一组 0/15：同样保存 8 组、分母 120；应保留实际完成的 0/15 一组。
- 1×15 计划，完整完成 0/15：通过，零分有效训练没有被丢弃。

QD012 在当前快照仍存在；本批证明模型保存与读回，不证明当前 UI 输入、磁盘重启或统计页面视觉。原断言及 JSON attachments 保留，未修改业务。

原始证据：build/quality-diagnosis/formal-resume-partial-save-002/xcode-test.log、inputs.json、exit.json；xcresult 路径见日志末尾。

partial-save-001 因 XcodeGen 清除自定义 scheme 在启动前拒绝，未执行测试；恢复 scheme 后使用新 run，不覆盖旧记录。
