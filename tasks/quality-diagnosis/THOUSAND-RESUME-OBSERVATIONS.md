# 千场正常磁盘 UI 运行观察（进行中）

2026-09-07；snapshot-003；formal-resume-thousand-ui-001，句柄16045。结果未定。

已知前提：只读 probe1/1、千场seed1/1通过，实际manifest1000/1000/1000、队列0、guest及默认相对路径一致。安装容器根变化已单独记录；正常App启动无内存/数据fixture，forcePremium只开放游客统计。

测试启动至第一次点击记录约47秒，点击后XCTest等待空闲约35秒；首条历史详情已进入（约123秒）。不能把整段自动化时间当普通用户响应时间。

02:43:54 对专用App PID96699采样3秒：physical footprint约1.8GB。主线程采样254/254位于XCTElementSnapshotRequest→UIAccessibility递归快照/标签提取；这是自动化/AX观测开销证据，不能据此宣称业务死循环、普通操作卡死或真机内存水平。运行时其他任务模拟器也在启动状态，未操作或关闭它们。

证据：formal-resume-thousand-ui-001/app-sample.txt、xcode-test.log。后续需完成两条滚动样本、统计读回、截图审查及当前容器manifest链。此文件不是最终通过报告。
