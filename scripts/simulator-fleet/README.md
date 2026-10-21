# 统一模拟器使用

配置真源：`scripts/simulator-fleet.json`。本地基线为8台常规覆盖＋6台数据/待复验保留设备；14是本轮过渡数量，不是永久保留指标。预览、矩阵、native-atlas共用核心设备，不再各维护一套池。保留例外不参与自动分配。

```sh
python3 scripts/simulator_fleet.py validate
python3 scripts/simulator_fleet.py resolve --role standard-pad
make -f scripts/Makefile sim-test SIM_TASK=my-test ONLY_TESTING=QiuJiTests/SomeTests
python3 scripts/simulator_fleet.py run --role standard-pad --task my-test -- command '{udid}'
```

`sim-test` 默认标准手机；忙或正在运行时退出，不另建替代机。可以选择其他确实符合验证范围的角色，或转Mac mini队列。显式 `simulator_lifecycle.py run --udid …` 留给用户指定的人工评审，须先查租约与保留原因。自动入口不选择额外6台，不擦除数据。所有入口保持共享独占租约；归还核心设备不删机，临时测试目录由local-test-lifecycle收尾。

角色：standard-phone、compact-phone-floor、compact-phone、large-phone、notch-phone、standard-pad、compact-pad、large-pad。具体型号、系统、UDID以JSON及实时inventory为准。iOS26.3 Runtime的实际版本为26.3.1，矩阵精确匹配已安装版本。

预览原01/03/04/05/07/09标签保留，02改17Pro，新增11-SE17；原06/08/10横屏专机取消。三台iPad分别在同一实例串行切横竖屏，Light/Dark也轮换。preview的orientation是目标声明，不是已测方向；应实际旋转并验证画面。native-atlas任务已包含方向状态，不同时租借同一UDID。历史十窗口验收结果仍是历史结果，不能冒称已在新八台上复验。

新覆盖用生命周期 `--temporary --evidence …`，本地最多额外1台（总数15时拒绝再建）。只用于需要干净安装/额外机型/系统的任务；不按任务、主题、方向建常驻副本。测试关闭并行克隆。失败现场保留，诊断闭合、证据导出后通过生命周期退役；不能靠失败标签无限累积，也不能仅凭关机或进程退出就删除。

Mac mini规划：现有8台先不改动，建议最多2台人工/故障复验保留设备，FIFO队列一次1个任务，每任务1台临时设备。历史5台失败临时设备及1台旧失败池需逐任务核对后关闭，不能混入正在使用的设备；收敛目标通常2台常驻＋1台在测，诊断例外另列。远端iOS26.2及17.0均已安装，承担跨系统与批量测试，本地承担26.3界面交互和用户数据。不要复制本地8台，也不机械要求远端14台。新快照通过`mac_mini_queue.py`调度；不修改运行中快照、不替换已有排队任务的脚本。`fetch`并校验、`complete`后清理构建目录及无人引用快照，失败/待复验例外写明原因和下一步。详见`../mac-mini-queue/README.md`。

核对命令：`python3 -m unittest discover -s scripts/simulator-fleet -v`。本轮归档和实际执行见`tasks/SIMULATOR-FLEET-20261020.md`。
