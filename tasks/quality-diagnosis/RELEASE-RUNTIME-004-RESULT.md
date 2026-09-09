# Release普通运行诊断004：普通启动与代表导航已验

## 2026-09-08 20:35 最新结果

下方18:23“未启动/交互待续”为历史检查点，已由本轮直接证据更新。

专用设备36379572-4169-495D-A5A5-D47869ED9FDE仍只有原Release安装。CUA再次明确返回Mac锁屏；主控先以simctl launch无参数启动既有包，退出0、PID48888，训练首屏与五Tab完整可见。984项安装文件SHA改变/缺失均0。启动命令耗时0.268秒仅为命令返回时间，不是首屏性能SLA；约39秒时进程仍在，RSS873MiB左右是单点观测，不作泄漏结论。

启动证据：`archive/quality-diagnosis/observations/release-runtime004-launch001/`。主控已审首屏，535条该PID日志的Bearer值/JWT/邮箱模式均0候选；只代表无真实凭据的新游客路径，不是全面隐私保证。

随后完成 `formal-004-release-navigation-001`，**1方法通过36.374秒，xcodebuild test-without-building退出0**。实际App PID49651，正常无参数启动→训练→我的游客→记录空态→训练→我的→偏好设置→返回游客。主控已审5张完整PNG及AX，实际页面和返回正常。测试结束实际安装包再次984项全比对，改变/缺失0；主二进制仍为原 `c4bc0d171173fc7d62b8849f109c4b42d3866bff3ec6bb295b946b4cc79a42cf`。

驱动边界：新增ReleaseRuntimeDiagnosticUITests是Debug编译的**外部UI自动化驱动**，被测App仍为已归档-O/无DEBUG的优化包。build-for-testing只生成驱动及本地构建产物，没有运行/安装Debug宿主。主控随后审查并保存独立xctestrun：删除整个单元测试目标，只留一个UI方法；UITargetAppPath及依赖App均指向归档Release包；App参数和显式环境均空，依赖里没有Debug球迹.app或其测试插件。运行采用test-without-building，原Release未重编、未重签，前后安装哈希复核保证身份。自动化观察仍有XCTest开销，不能称真机/无仪器性能测试。

导航原件在 `archive/quality-diagnosis/runs/formal-004-release-navigation-001/`：选择器、完整命令、独立xctestrun、实际测试源、result.xcresult、截图/AX、安装后哈希、主控图审和App日志均保存。主控采集导航PID时间窗16621条日志，Bearer值/JWT/邮箱模式均0候选；系统框架与自动化噪声存在。未测真实登录/同步失败/用户内容泄露，不能据此宣称全日志安全。

本轮不触发残留deeplink.settings参数；保留RELEASE-RUNTIME-004-PREPARATION中的源码/包字符串结论，不声称残留参数执行效果通过。QD009/020/021不撤销。普通Release基本运行缺口已补，SC37仍有部分隔离/真实发布层限制；未签名发布、未修改业务/资产。

## 18:23 原始安装检查点

2026-09-08 18:23：已新建专用iPhone17Pro/iOS26.2设备36379572-4169-495D-A5A5-D47869ED9FDE，名称QD004-Release-Runtime-20260908。直接安装已归档的Release优化模拟器包，未重编或替换成Debug。

原包984项SHA逐项一致；simctl install成功，安装后同984项再次比对改变/缺失均0。安装身份与命令原件在archive/quality-diagnosis/observations/release-runtime004-install001/。无需补签名，原包未改。

CUA读取Simulator时明确返回Mac锁屏且自动解锁失败，已向用户请求手动解锁。未执行普通App启动、引导或导航，不能声称Release已运行通过；没有启动句柄需要重跑或终止。设备保留Booted及已安装包，解锁后从一次无参普通启动继续，按RELEASE-RUNTIME-004-PREPARATION.md记录准确PID、截图、正常入口及日志。

该环境条件仅影响当前桌面交互；上传服务边界诊断仍可独立准备，不是整个目标阻塞。SC37保持部分覆盖，旧Release包审问题仍保留。
