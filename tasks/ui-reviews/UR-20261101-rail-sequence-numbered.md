# K球／解球等大序号色块与下沿对齐

2026-11-01；现行合同见 `tasks/table-page-adaptation/KICK-KBALL-FEEDBACK-20261031.md` 第四轮。用户否定初版提示偏高，最终基准为球库球面下沿，角色角标不计入球径。

最终受管包23f4711fe0324986850ed226598b4cac：SE3/iOS17.0和iPad Pro11/iOS26.3.1各2项UI通过（4项，0失败）。`output/rail-sequence-numbered-20261101/se-aligned.xcresult`、`pad-aligned.xcresult`；`gate-aligned.log`通过。首版成功测试不计入最终4项。

已逐张打开8张最终关键原图：SE两库K球、四库解球2D及3D；iPad K球横竖、四库解球横竖2D及3D。母球／色块与球库球径一致、下沿一致，内部数字清楚，四库完整、没有与球库／右状态区相撞。原图在上述目录的`se-aligned-images/`及`pad-aligned-images/`；文件映射见manifest。

首版采集脚本在安装后旧sandbox路径收尾失败，补充受管关机并修正为解析新路径；最终两轮包装exit0。iPad测试结束后的可选simctl diagnose采集迟滞，终止该采集子进程后Xcode正常输出TEST EXECUTE SUCCEEDED。构建完成后回收约1.74GB，租约归还、设备保留。

真机、VoiceOver、分屏／缩窗、完整App回归与用户接受仍未验证。此前无数字及错位截图仅为历史。
