# v62 真机 trace 采集与来源检查

此文件是续测操作入口，不是性能通过报告。当前无合格真机样本。S198只验证本机xctrace录制/导出链路，不能填入手机指标。

## 设备与构建

1. `xcrun xcdevice list` 确认物理iPhone可用；记录实际UDID、型号、iOS、温度/电量/亮度。不要用模拟器UDID替代。
2. 按README「真机续测」使用Release优化加`RENDER_QUALITY_VALIDATION`诊断构建，记录已安装版本、构建日志和本地App哈希。本地文件哈希本身不证明设备安装的是同一包。
3. 使用正常实际训练入口，两组都加`-v62.fixture`，候选另加`-v62.mobileRendering`。基线与候选必须同设备/分辨率/题型/操作负载/电量/初始热状态。
4. 预热60秒，再单独录制60秒；每组3次，交替运行、冷却后再换组。20分钟稳态、20次往返、能耗和启动另测，不以短测代替。

## 录制与导出

以下占位值须替换成实际设备UDID和全新输出路径，不覆盖已有trace。

```sh
xcrun xctrace record --template 'Game Performance' --device DEVICE_UDID --attach '球迹' --time-limit 60s --output NEW_RUN.trace
xcrun xctrace export --input NEW_RUN.trace --toc --output NEW_RUN-toc.xml
python3 scripts/render-quality-v62/audit_trace_metadata.py NEW_RUN-toc.xml
xcrun xctrace export --input NEW_RUN.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="ca-client-presented-handler"]' --output NEW_RUN-presented.xml
```

先从实际toc核对schema，再选择导出表；不同Xcode/设备版本可能不同，不能假定名称和字段恒定。S198的Game Performance包含`ca-client-presented-handler`、`display-surface-queue`、`metal-command-buffer-completed`等。S198呈现表只有schema、无row，故无法算帧率。

`audit_trace_metadata.py`只检查设备平台、目标进程、录制时长、呈现表是否列出；exit2表示来源前置不满足，exit0也**不代表性能通过**。输出FPS/CPU/GPU均为空，performance_accepted永远为false。必须继续检查真实row、目标进程、对应显示层及采样窗口，不能计入其他App或其他图层。

## 指标解释边界

- 呈现次数/间隔须来自目标App对应显示层的实际呈现事件；CADisplayLink、snapshot次数、preferredFramesPerSecond都不能替代。
- CPU/GPU耗时分别统计，不相加；单个command buffer耗时不等于整帧GPU耗时，需关联所属帧及并行区间。
- 60秒文件可能包含空闲、切页或提前退出；必须核对负载持续区间和结束原因。
- 无数据填null/未测，不能填0、默认60或“通过”。
- 模拟器与本机原生trace只可验证工具链，不作为手机性能证据。最终按问题集合_v62第3节逐项验收。
