# 当前同步与账号隔离局部结果

2026-09-07，snapshot-003；专用设备 BF4E618F-9398-4667-9082-9C1148FF442F，执行前只读 probe 1/1 通过。使用独立内存宿主 scheme，三个进程串行，共14个精确方法全部通过；设备已关闭并保留。

| 批次 | 结果 | 测试执行时间 | 证据目录（build/quality-diagnosis/ 下） |
|---|---|---|---|
| Auth | 7/7，make 0 | 1.043 秒 | formal-resume-current-sync-auth-001 |
| Coordinator | 6/6，make 0 | 0.907 秒 | formal-resume-current-sync-coordinator-001 |
| Owner queue | 1/1，make 0 | 0.715 秒 | formal-resume-current-sync-owner-001 |

精确方法、行为与夹具边界见 CURRENT-SYNC-SELECTORS.md，各运行保存 inputs.json、selectors.txt、command.json、原始 xcode-test.log 与 exit.json。时间是测试方法合计，不是构建或总体耗时。

已有证据：同步未同意时登录/前台不上传且保留队列；关闭下载时丢弃晚到响应并停止后续请求；A恢复晚到在切到B后丢弃；游客迁移必须明确选择，拒绝保留游客数据，确认只迁移一次；队列只处理当前账号所有者；退出/删除或身份世代变化后旧认证和权益响应不能恢复旧状态；同步选择持久化。

这些是私有内存容器、隔离偏好和后端/权益替身驱动的逻辑测试。不是实际云恢复、实际购买、真实账号系统，也不证明完全没有网络流量。队列底层测试不经过同步同意入口，不能把它误判成关闭开关仍上传。QD007、QD008服务端缺陷不因这些通过而关闭。

未覆盖：上传中关闭与A→B→A反复切换，所有晚到失败排列，真实UI到服务端端到端链，真实StoreKit账号/购买及生产恢复。以上按风险保留在总报告，不把14项等同整个同步模块通过。
