# C1 固定灯预计算默认接入（2026-11-14）

## 用户要求与结果

用户用截图明确指定 `ddb9c4f88` 中完成九轮研究的固定灯几何积分预计算，并进一步纠正：“直接应用到app代码中，既然已经实现并测试过了”。本轮以默认 App 接入为交付，不把手机连接、再次试用批准或新性能测试作为前置。

`StaticClothIrradiance`、scene 资源所有权以及共享材质接线已移出 `#if DEBUG`。Debug 和 Release 都默认启用；Debug 保留 `-rendering.noStaticClothField` 对照开关，Release 不消费诊断启动参数。两纹理、插值函数、光源及资产与上一轮实测对象一致。

## 覆盖与保留

- 共享 `MobileReferenceLighting.refreshClothLighting` 下有效的 guard-combo 台呢材质自动接入，分离角与走位、每日清台及其他使用该配方的 3D 场景无需各页开关。已有消费者清单见 [B4](B4-COVERAGE.md)，本轮不把源码覆盖称作逐页新运行验收。
- 不支持32位浮点过滤、固定灯身份不符、资源缺失/损坏、shader锚点不匹配时使用原计算路径；场外/跨法线地平线的片元仍按原解析积分。
- 移除加载失败的进程永久锁定，下次场景/材质准备可恢复；不会在逐帧循环加载或重试。切离该渲染配置时释放scene包装对象，缓存材质持有纹理的既有边界保留。
- 物理、球影/AO、法线、高光、分辨率、帧率及页面操作保持原逻辑。TP16/17/29/30继承现有模式、相机及资源合同；TP35按编译/功能检查和手机/用户体验分别记录。其余页面布局和业务合同本轮未改。

## 验证

- 实际 App 类型分别以 Debug/非DEBUG 编译的本机资源检查通过：默认开启、诊断开关边界、纹理读回一致、消费者 shader 与上轮实测源码一致、活跃资源共享、包装对象释放；缺失/损坏/截断拒绝且同进程恢复通过。
- 第一轮最终源码 iOS Debug 构建及签名/资产身份通过：`output/local-test-runs/8134cb3baf6942c6858b6f373f449b49/`。该轮尝试通过 make 环境变量清空 Swift 条件，但实际编译命令仍有 `-DDEBUG`；因此其 `build-identity.json` 中 non-DEBUG scope 描述不成立，只计 Debug 构建，原件保留。构建脚本已改为传递明确 xcodebuild 参数并检查真实编译命令。
- 非DEBUG完整 iOS 构建、签名及资产身份通过：`output/local-test-runs/6fd2a159964647b9be503d154def772d/`。真实 App 编译命令已确认无 Swift `-DDEBUG`，构建后源码身份一致。使用 Debug 配置清空 Swift DEBUG 条件，覆盖生产 Swift 分支；不改变项目既有 Release API 配置和 HTTPS 门禁，不冒称正式 Release 发布验收。
- 最终 `verify-gate`、文档体积、Python语法及差分检查通过；汇总见 [机器结果](C1-default-results.json)，门禁日志位于 `output/render-activity-20261113/c1-default-integration/verify-gate.log`。
- 本轮没有追加 GPU 排名、整页自动化或温升采集；已有研究结果见 [C1交付](C1-DELIVERY.md)。约19.7%仍是本机近景材质 GPU 时间结果，手机收益与温升未作新结论。

## 安装与收尾

最初曾误按“Debug手机试用”准备并尝试无线安装，开发隧道失败，未成功安装。用户纠正范围后已停止该流程；详见 [中间记录](C1-PHONE-PREVIEW.md)。旧试用包不再等待安装，最终交付为本仓库默认启用的源码，无手机连接依赖，也未发布 TestFlight/App Store。

中间两轮临时构建已按管理器回收，记录的实际可用空间变化分别为1,375,977,472和1,376,387,072字节；原日志及失败回执保留。最终轮也已回收，管理器记录的实际可用空间变化为1,364,099,072字节；不保留待安装手机包。
