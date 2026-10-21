# 模拟器生命周期

所有 worktree 共用 `~/Library/Application Support/QiuJi/simulator-lifecycle/` 的登记表、独占租约、操作日志。目录不放在 `build/`，不会被 `make clean` 擦掉。只依赖 Python 标准库和本机 Xcode。

## 日常入口

```bash
# 从仓库根目录执行；先预览清单。
make -f scripts/Makefile sim-inventory
make -f scripts/Makefile sim-clean
make -f scripts/Makefile sim-clean-apply

# 从统一核心设备独占借用，结束归还租约；继续使用相同的 UDID。
make -f scripts/Makefile sim-test ONLY_TESTING=QiuJiTests/SomeTests
# 按本机已安装的 Runtime/设备类型覆盖，不会下载 Runtime。
make -f scripts/Makefile sim-test SIM_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-17-0 SIM_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation
```

`sim-test` 默认 iPhone 17 Pro / iOS 26.3，复用[统一8台核心设备](../simulator-fleet/README.md)，与评审/矩阵共用；不再另建8台池。本地核心设备忙或Booted时退出，额外6台数据/待复验设备不自动选用；需要全新覆盖时最多额外1台临时设备。异地主机仍遵守其独立队列与容量限制。App数据保留，测试负责自己的数据初始化。

本地 `make test` / `sim-test` 及矩阵 `run` 已默认接入[测试目录自动收尾](../local-test-lifecycle/README.md)：成功后删除本轮独占工作目录，证据另存；需继续复验时设置 `TEST_KEEP_REASON='具体原因'`（矩阵用 `--keep-build-reason`）。失败和受保护的目录保留，诊断/复验结束执行 `test-work-complete` 即自动回收。设备生命周期与磁盘工作目录分别登记。

`make run`、走位导出/静帧导出和缩略图烘焙也在设备操作期间持有同一租约。普通 `make test` 保持调用者的目标设备，新增占用锁并把实际目标固定为 UDID；`build-for-testing` 和真机目标不借用模拟器。进程保护同样排除单一generic模拟器目标的纯`build-for-testing`编译；真实test、指定UDID、多目标或未知命令仍阻止冲突使用。`run_simulator_matrix.py`、`native-atlas/run.py`、`simulator-preview/preview.py` 的修改操作均接入同一占用锁。借用已有设备不自动擦除数据或改变它原有的收尾策略。人工评审设备始终保留。测试/导出入口关闭Xcode并行测试克隆（`-parallel-testing-enabled NO`），并行任务通过管理器借用不同设备；自定义xcodebuild任务也须关闭自动克隆，避免产生登记表以外的设备。

## 制作、诊断或其他自定义任务

```bash
# 全新临时设备：命令退出 0 且本轮结果文件已导出，才释放并自动删除。
python3 scripts/simulator_lifecycle.py run \
  --task video-VXXX \
  --type com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
  --runtime com.apple.CoreSimulator.SimRuntime.iOS-26-3 \
  --temporary --evidence output/my-task/result.json \
  -- python3 my_capture.py --device '{udid}'

# 明确使用已有设备：保护数据，仅借用，不自动删除或关机。
python3 scripts/simulator_lifecycle.py run --task my-task --udid DEVICE_UUID -- command '{udid}'
```

`{udid}` 按参数替换，同时通过环境变量 `QIUJI_SIMULATOR_UDID` 传给子进程。不经过 shell 拼接。证据文件必须在本轮启动后写入。调用方必须写出自己的结果/素材，不能只依赖模拟器内部文件。成功退出只证明命令成功，不证明素材质量或用户验收。

每次受管命令启动前、释放后自动扫描可回收项，不安装后台服务。失败设备保留 7 天；无其他保护、已关机且无外部使用时，后续受管命令或 `sim-clean-apply` 才会回收。成功的池设备长期复用，成功的临时设备立即回收。失败退出码原样传回。SIGINT/SIGTERM 尝试终止本轮子进程组并保留失败现场；强杀/崩溃留下的租约不自动解除。

## 保护与历史设备退役

以下任一条件都会禁止自动删除：未知归属、人工保留、评审配置引用、默认开发设备、尚未释放的租约、运行或启动中的设备、外部 simctl/xcodebuild 占用、释放后再次启动、设备身份变化、保留期未到、缺少导出证据。不能把“关机”“名字带旧日期”“Runtime unavailable”当作删除许可。禁止直接使用 `simctl delete all`、`delete unavailable` 或删除 CoreSimulator 目录。

```bash
python3 scripts/simulator_lifecycle.py protect --udid DEVICE_UUID --reason '仍需人工验收'
# 必须已确认任务结束且无需要保留的设备数据，才能解除历史保护。
python3 scripts/simulator_lifecycle.py unprotect --udid DEVICE_UUID --reason '已核实完成且可重建'
python3 scripts/simulator_lifecycle.py retire --udid DEVICE_UUID \
  --reason '已核实结束，导出证据齐全' --evidence output/task/result.json --retain-days 7
make -f scripts/Makefile sim-clean
make -f scripts/Makefile sim-clean-apply
```

`unprotect` 仍拒绝正在使用的设备及当前评审/默认设备。`cleanup --udid DEVICE_UUID --apply` 可限定精确设备（可重复传入），只清理该范围内符合条件者。`retire` 只登记；默认 7 天后才可清理，明确已可删除时可指定 0。历史设备不会按名字自动纳入可删除范围。

中断租约用 `recover --udid … --reason …` 恢复；必须原进程已退出、设备已关机且无外部占用，恢复后仍置为保护状态，需人工判断是否退役。不要直接编辑登记表或通过删除锁文件抢占设备。

## 边界与验证

锁只能协调接入本入口的工具。回收前会重新检查进程和设备状态，但不能与绕开入口的任意 `simctl` 操作形成原子互斥；所以后续任务都应通过这个入口创建设备和借用设备。运行中的旧会话没有被本次改动强制迁移。

本轮证据见 `output/simulator-lifecycle-20261014/`；完整历史分类见 `tasks/SIMULATOR-LIFECYCLE-20261014.md`。自动测试：`make -f scripts/Makefile sim-lifecycle-check`。
