# Mac mini 快照与测试队列

入口：`python3 scripts/mac_mini_queue.py --help`。仅依赖 Python 标准库、Git、系统 SSH/scp/rsync，以及远端 Xcode。当前执行配置面向球迹；不是任意命令执行平台。

## 多智能体协作约定

每个写代码的智能体使用独立 worktree。默认从确定的 Git commit 建立不可变快照，工作区随后继续编辑不影响该版本。任务提交包含 task、独立 job ID、snapshot SHA-256、源码 commit/模式、测试选择器、runtime 和设备类型；结果按这些标识归属。任务各自通过后，仍须测试合并后的新快照。

未提交内容使用 `--include-dirty --quiescent`；**调用前必须确认该工作区所有写入者已暂停**。工具用 worktree 内的协作锁并在复制前后核对文件全集、内容、执行位及 Git ref，发现漂移拒绝发布。这个选项是调用方对交接完成的明确声明，不是能锁住编辑器的系统写入锁。多人仍在共享目录写入时不可使用；先完成交接或转到私有 worktree/固定 commit。

不包含原目录位置/修改时间的内容清单决定 snapshot ID；清单同时绑定基础 commit 与采集模式。快照封存后只读，每次入队和执行前后验证；新增、删除、修改文件和可执行位变化均会被发现。源码允许清单在脚本 `ROOTS` 中，明确排除大体积非打包母版、凭据、缓存和编辑器个人状态，拒绝符号链接及归档越界。不要把它当作恶意同账号进程之间的安全沙箱。

## 日常使用

在主机开一个 SSH 控制连接，交互式输入技能所存密码；不要把密码写进参数：

```bash
ssh -M -S /tmp/macmini-queue.sock -o ControlPersist=1800 \
  song@fengchuibuchuifengdeMac-mini.local true
```

默认队列根为 Mac mini `/Users/song/simulator-work/queue`，所有智能体必须共用这一根目录，不能各建一套队列规避串行。项目 Makefile 对路径的引用有限，工具明确拒绝带空格/特殊字符的队列根。

```bash
# 使用本任务 worktree 的确定版本；out 必须是未使用的新目录。
python3 scripts/mac_mini_queue.py snapshot \
  --repo /path/to/task-worktree --ref HEAD --out /path/to/snapshots/task-a-v1

# 只有完成暂停写入交接后，才可替代上一命令使用此模式。
python3 scripts/mac_mini_queue.py snapshot \
  --repo /path/to/task-worktree --include-dirty --quiescent \
  --out /path/to/snapshots/task-a-v1

python3 scripts/mac_mini_queue.py submit \
  --bundle /path/to/snapshots/task-a-v1 --task task-a --job-id task-a-v1 \
  --ssh-option ControlPath=/tmp/macmini-queue.sock

python3 scripts/mac_mini_queue.py remote-status --job task-a-v1 \
  --ssh-option ControlPath=/tmp/macmini-queue.sock

# 终态后回传日志、xcresult和截图，并逐文件校验 SHA-256。
python3 scripts/mac_mini_queue.py fetch --job task-a-v1 \
  --out output/task-a-v1 --ssh-option ControlPath=/tmp/macmini-queue.sock
```

`submit` 默认启动按需 worker，队列清空即退出，没有 launchd/定时任务。`--no-start` 仅入队，之后用 `remote-start` 启动。多智能体同时提交安全；提交前先输出 job ID，网络中断时先按此 ID 查询，可用相同 ID/参数重新提交，不能直接生成新 ID 重跑未知结果。相同 ID 的不同请求会被拒绝；修订代码或测试选择器使用新 ID。

默认运行 iPhone 17 Pro / iOS 26.2：7 项 `DrillContentServiceTests` + 冷启动、五标签切换、动作库加载 3 项 UI 测试。用重复的 `--test TARGET/CLASS[/METHOD]` 指定本任务范围；`--runtime`/`--device` 必须是远端已有标识。缺运行时会失败，不静默降级或下载。仅零退出码不能算通过：xcresult 必须实际命中所有选择器、测试数量非零且无失败/跳过。

## 执行与隔离

- `queue.lock` 原子分配入队序号；`worker.lock` 覆盖整轮构建、安装和测试，多个启动者只有一个能消费队列。按序号 FIFO，普通失败保留证据后继续下一任务。
- 上传先进入随机 incoming 目录，校验完成后才发布到快照库并入队。执行器自身按文件哈希部署并随任务固定，后续工具升级不会改变已入队任务的执行器。
- 每个 job 有独立源码副本（不共享可写硬链接）、build/DerivedData、`.xcresult`、日志和截图；首版优先保证隔离，没有跨任务构建缓存共享。每次新快照首次上传完整所需文件；同一内容可在远端去重存储，但尚未实现差量上传。
- 构建使用原 Makefile，限定 arm64、4 jobs。测试通过原生命周期管理器取得全新临时设备，数据不跨任务复用。成功且证据导出后管理器释放并回收本任务设备；失败保留现场并按既有规则处理。其他任务、评审或未知设备保持原有保护。
- 所有客户端必须通过此队列提交；文件锁不能约束绕过入口直接执行的外部 xcodebuild。切勿在队列 UI 测试期间手动操作远端 Simulator 的共享键盘/焦点。
- 不自动合并、提交或推送开发代码。任务结束后的回收按下面的完成／复验协议执行；不能把测试退出直接当作任务关闭。

## 任务完成与自动回收（2026-10-20）

执行者在交付前必须完成资源收尾，不需要再次向用户请求删除临时构建文件的许可：

```bash
# 本轮已完成，不再依赖远端产品做复验：回传校验后自动回收。
python3 scripts/mac_mini_queue.py fetch --job JOB_ID --out output/JOB_ID \
  --complete --reason '本轮诊断/验证已结束，必要证据回传，无待复验或产品复用' \
  --ssh-option ControlPath=/tmp/macmini-queue.sock

# 已经 fetch 过：复核本地原始证据后关闭并自动回收，无需重复下载。
python3 scripts/mac_mini_queue.py complete --out output/JOB_ID \
  --reason '复验已结束，临时构建不再需要' \
  --ssh-option ControlPath=/tmp/macmini-queue.sock

# 仍需用户试用/人工复验：普通 fetch 保留文件，并登记具体原因。
python3 scripts/mac_mini_queue.py remote-protect --job JOB_ID --reason '等待手机复验'
# 复验结束后明确 release，再执行 complete；release 本身不删除。
python3 scripts/mac_mini_queue.py remote-release --job JOB_ID --reason '复验已结束'

# 历史任务可先 complete --defer-cleanup，然后预览精确范围。
python3 scripts/mac_mini_queue.py remote-cleanup --job JOB_ID
python3 scripts/mac_mini_queue.py remote-cleanup --job JOB_ID --apply
```

回收删除 `jobs/JOB_ID/build` 和 `source`，保留 job 元数据、worker 日志、全部 evidence、回传收据及清理记录。所有引用任务都回收后才删除共享快照，并把小型源码清单保存到各 job。失败任务只有诊断结束并执行相同关闭流程才回收，失败状态不会改成通过。普通 fetch、缺少关闭标记的历史任务以及明确 hold 的任务不回收。

回传收据同时绑定 job 状态、snapshot ID、所有 evidence 文件和 worker 日志。删除前再次核对内容、队列状态、完整进程命令、打开文件与模拟器登记表；源码与冻结快照有差异、活动租约、未退役诊断设备、符号链接边界、挂载点、检查失败均保留。`queue.lock` 协调入队、保护与回收；不停止正在执行的任务，不回收模拟器。绕过队列直接复用旧目录前应先 protect，文件锁不能约束不遵循协议的外部进程。

回收随 `fetch --complete` / `complete` 自动执行；新版 worker 启动时重试已关闭但此前被占用的任务。不安装定时服务、不改写已有任务固定执行器。低于 12 GiB 时拒绝新的上传/构建，待执行项仍为 queued；清理后用 remote-start 恢复。新 ingest 成功或失败都会移除本次上传暂存，失败保留错误记录；历史 incoming 中无法归属的文件不按年龄批量删除。

证据保存与临时工作目录是两回事：长期只需一份可核验原件和必要报告/图像，不应在两台机器无限复制完整工作区。旧候选或已被替代版本的产物可以回收；复验只保留实际需要的版本。涉及证据压缩/去重时记录恢复路径及验证结果，不修改原测试结论。

## 失败、取消与恢复

`remote-cancel --job ID` 仅取消 queued 任务，避免强杀正在运行的模拟器流程。普通构建/断言失败是 failed，不自动重试。

worker 崩溃后留下 running 状态，或执行进程被信号终止/残留租约时，后续 worker 会停止。检查状态和进程，先按 `scripts/simulator-lifecycle/README.md` 恢复本任务设备租约，再在远端运行：

```bash
python3 /path/to/deployed-engine.py recover --root /Users/song/simulator-work/queue \
  --job JOB_ID --reason '已检查进程结束及设备租约，保留失败证据'
```

恢复会检查执行器/worker PID、构建进程及本任务租约，满足条件后标记 interrupted，**不会把原任务重新入队**。需要重跑时另交新 job ID。终态结果用 `fetch` 获取；执行器启动前失败可能没有测试证据，不能把日志回传成功视作测试通过。

## 验证

```bash
python3 -m unittest discover -s scripts/mac-mini-queue -v
```

真实双任务验证记录见 `tasks/MAC-MINI-QUEUE-20261018.md`，涵盖不同快照、并发启动者、排队时间边界、各自真实构建/测试、独立临时设备及证据回传。UI截图仍应人工或由当前任务实际打开检查，工具不把 PNG 文件存在当作视觉验收。
