# 真机连续击球发热记录（2026-11-13）

## 当前决定

用户要求以已有约40秒操作段分析，不追加真机录制或扩展恢复。实际分析窗口约47秒，包含瞄准、击球、滚动及杆间间隔，不是纯物理计算时间。无生产代码修改。

## 条件及有效证据

iPhone 16 Pro，iOS27.2，当前共享guard版本（Debug -O），分离角与走位3D，用户选择60FPS。用户确认拔线、未无线充电、初始正常温度；无线localNetwork查询/启动与Instruments GUI录制导出已验证。CLI录制仍有连接问题，未证明根因解决。进程45483以METAL_PERFORMANCE_PER_FRAME_SIGNPOSTS=1启动，无诊断参数；亮度、电池健康、表面温度及瓦数未知。

保存的 `output/phone-heat-20261113/work/wireless-gpu-startup-smoke.trace` 仅含Run1–4。Run3完整录制106.014974秒，包含前后静止段，用户约6杆，结束温感正常、差不多停稳。

| Run3阶段 | 窗口 | CPU采样估算（单核满载=100%） | 帧证据 |
|---|---|---|---|
| 操作前 | 2–29秒 | 0.13% | 无新增帧记录 |
| 操作段 | 31–78秒 | 32.0% | 2781帧，逐帧FPS均值59.68；显示间隔P50/P95约16.669ms，P99约20.837ms |
| 停止后 | 80–105秒 | 1.22% | 无新增帧记录 |

CPU以样本权重除窗口时长估算，不是整机CPU百分比或功耗；窗口来自主机提示，非精确逐杆标记。操作段主线程累计采样约5.321秒；SceneKit、Swift运行时、AttributeGraph与驱动均有样本，不能把重叠调用栈占比相加，也不能直接分摊发热。静止画面长驻留不算掉帧。

该操作段Metal帧关联Command Buffers与GPU时间全0，关联失效，不代表GPU没有工作。Run4独立GPU事件7.757561秒导出4704行并发现45483进程，但只是采集能力验证，不能替代Run3或热轮的GPU成本。

原值：`output/phone-heat-20261113/work/analysis.json`、`formal-time-profile.xml`、`formal-metal-perf-overview-layer-per-frame-metric.xml`、`formal-device-thermal-state-intervals.xml`。短轮热状态Nominal不代表表面不热，更不能代表后续三分钟。

## 三分钟轮失败与保全

Run5用户约13杆，约1分钟开始发热，结束比较烫，球已停稳；未明确回答是否掉帧。请求操作180秒，含前后准备的工具窗口约220秒。停止封存时2026-11-13 16:46:14日志明确write failure 28 No space left on device，Instruments原进程退出，Run5未保存进trace。CPU/GPU完整结果均不可用；不能把短轮数据当热轮数据。

本轮开始约9.35GiB可用不足以覆盖GPU原始缓存和封存峰值，是采集准备失误（FL-266复发），不是App崩溃。原始ktrace约4.67GB及缓存已保全至 `output/phone-heat-20261113/recovery/`；6份GPU缓存压缩后逐一校验原始SHA。首次离线import出现continuation泄漏提示并挂起，已终止owned进程。末尾不完整块仅在独立副本裁去，尚未导入验证；用户要求使用已有数据后停止扩展恢复。原失败状态不改成成功。

## 现阶段判断

1. 短轮静止前后CPU明显下降且无新增帧，支持该轮休眠生效；不能推广所有状态。
2. 操作时接近60帧且CPU有持续工作。流畅仅表示能及时完成一帧，不能推出低功耗。
3. 生产台呢仍有双灯积分、近影64/远处8总样本及BRDF，正常R球反射为预过滤环境+响应LUT，只有资源失败回退才为64采样，视图MSAA4与相机HDR保留。guard减少无关遮挡测试，文本缓存减少构建成本，没有消除每帧渲染主体。代码依据MobileReferenceLighting.swift、AngleSceneView.swift、AngleTrainingScene.swift及ROLLOUT.md。
4. 持续工作导致热积累与用户反馈相符；GPU像素/材质成本值得优先优化，但当前不能测定CPU/GPU发热占比，不能证明台呢就是主要热源，也不能排除采集额外开销。
5. 下一实施方向优先复用不变光照/材质中间结果、减少与当前变化无关的工作；保持约定画质和60FPS。不据此直接降低采样或宣称温升已改善。


后续代码与CPU分账见[COST-ENERGY-AUDIT](COST-ENERGY-AUDIT-20261113.md)：最终互斥调用栈归属UI31.35%、SceneKit23.44%、Metal/驱动CPU23.45%，FramePacing3.21%另列；能源模型包含P/E敏感性假设，非整机实测。
