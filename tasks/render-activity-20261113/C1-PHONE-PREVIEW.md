# C1 台呢预计算手机试用（2026-11-14）

> 已被用户后续明确要求取代：直接接入 App，Debug/Release 均默认启用，不以手机连接为前置。当前结果见 [默认接入](C1-DEFAULT-INTEGRATION.md)。下文仅保留中间过程，不代表当前配置或待办。

用户明确要求把 `ddb9c4f88` 中的固定灯几何积分预计算应用到 App 并亲自试用；后续截图再次确认就是 C1。沿用该提交的空间插值算法、资产和共享接入边界，本轮不重新进行 GPU 排名，也不把试用授权当作手机性能或温升验收。

## 本轮改动

- 普通 Debug 启动默认请求 C1，安装后从桌面图标重开仍有效。Release 编译边界保持原样。
- 共享 `MobileReferenceLighting.refreshClothLighting` 的既有 guard-combo 有效场景自动使用；包括分离角与走位、每日清台等共享 3D 场景。设备不支持、灯参数不符或资源不可用时继续原算法，其他材质路径不强制替换。
- `-rendering.noStaticClothField` 可单独退回上一轮 guard 基线；`-rendering.referenceCloth` 仍优先。旧 `-rendering.staticClothField` 参数兼容。
- 取消初始化失败的进程永久锁定，后续场景/材质准备可重试。仅初始化及球实例容量扩展触发，不在逐帧回调重试。
- 绑定成功增加一次准备期日志，便于后续确认所用配方；它不是 GPU 编译/实际绘制成功的证明。

## 验证与安装

受管任务：`output/local-test-runs/0fbfc37094a645aa848ee180e7c195d6/`。

- 本机原生检查通过：默认启用、禁用优先、reference 优先；真实纹理读回与资产逐字节相同，消费者 shader 与上一轮实测对象完全相同，共享资源和包装对象释放通过。
- 缺失、损坏、截断资源均被拒绝；同进程换回正确资产后均恢复成功。
- 手机 Debug `-O` 构建成功；签名、包内资产 SHA 与构建前后源码身份检查通过。`verify-gate`、`verify-doc-size`、Python 语法、非 DEBUG Swift 语法及 `git diff --check` 通过。
- 首次无线安装失败：CoreDevice/RemotePairing error 4，开发隧道未建立；不是 App 编译或渲染失败。原安装回执保留，受管工作目录已保护，等待用户解锁并连接数据线后安装同一包。
- 未运行新的完整页面自动化、最低 iOS 17 绘制或温升采集。画质与连续击球感受待用户试用；既有约 19.7% 数字仍只代表上一轮本机近景材质 GPU 时间。

本轮不卸载 App、不清除用户训练数据、不修改物理/相机/交互，也不发布 TestFlight 或 App Store。
