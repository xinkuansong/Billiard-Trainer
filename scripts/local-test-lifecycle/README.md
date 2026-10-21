# 本地测试工作目录生命周期

`local_test_lifecycle.py` 为每轮测试创建独立目录，并在整轮命令成功结束后自动清理。不是定时按日期扫盘，也不依赖交付时手工运行删除命令。

## 已默认接入的入口

- `make -f scripts/Makefile test`：普通 `TEST_ACTION=test` 自动使用受管 DerivedData，测试成功后删除本轮工作目录。
- `make -f scripts/Makefile sim-test`：沿用上面的本地目录收尾，并继续使用既有模拟器租约。
- `python3 scripts/run_simulator_matrix.py run ...`：整轮矩阵成功后删除本轮 DerivedData；矩阵原有截图、结果包、报告路径不变。

默认每轮目录为 `output/local-test-runs/<随机ID>/`：

| 内容 | 生命周期 |
|---|---|
| `work/` | 本轮独占的构建、缓存、复制的临时源码；成功后自动删除 |
| `evidence/` | 命令日志；普通 make test 的原始日志、JUnit、xcresult；保留并记录 SHA-256 |
| `run.json` | 命令、任务、原退出码、保留原因、目录身份、证据哈希、删除结果及实际空间增量 |

普通 `make test` 的 `BUILD_DIR` / `DERIVED_DATA` / `TEST_LOG` 被重定向到本轮独立目录，不再共用 `build/DerivedData`。需要继续读取产品时显式保留并从输出中的 run 目录读取。自定义 `TEST_BUILD_SETTINGS` 已指定 `-resultBundlePath` 时继续使用该外部证据路径，不重复传参或删除它。

## 复验、失败与任务完成

```bash
# 成功后仍需产品做人工复验：运行前明确保留。
make -f scripts/Makefile sim-test TEST_KEEP_REASON='等待手机复验'
python3 scripts/run_simulator_matrix.py run --keep-build-reason '等待复验'

# 运行中也可补充保护；不会被结束时的状态更新覆盖。
python3 scripts/local_test_lifecycle.py protect --id RUN_ID --reason '待复验'

# 复验或失败诊断结束：明确关闭，即刻自动回收，无需另跑 rm。
make -f scripts/Makefile test-work-complete \
  TEST_RUN_ID=RUN_ID TEST_COMPLETE_REASON='复验结束，临时产品不再需要'

make -f scripts/Makefile test-work-status
make -f scripts/Makefile test-work-clean
```

失败/中断保留现场并原样返回失败码；`complete` 不改写原测试结果。运行中的任务不能被 complete。已关闭但因打开文件而暂缓的目录，在下一次受管任务启动时自动重试，`test-work-clean` 也可主动重试。明确保留、失败待诊断或证据有变化的目录不因下次测试成功而被删除。

## 自定义多步任务

构建→安装→多轮测试/截图是一个完整任务边界，使用同一入口包住整段流程：

```bash
python3 scripts/local_test_lifecycle.py run --task my-validation -- \
  python3 /path/to/validation.py --work '{work}' --evidence '{evidence}'
```

脚本将临时文件写入传入的 work，将需要保留的日志、结果、图像写入 evidence。同样通过环境变量 `QIUJI_TEST_WORK`、`QIUJI_TEST_EVIDENCE` 传递；`{work}` 和 `{evidence}` 按参数替换，不经 shell 拼接。不要把唯一源码或原始素材移进可删除目录。

`TEST_ACTION=build-for-testing` 和 `test-without-building` 是这种多步流程的子步骤，保持其调用方指定的路径，不能在中间步骤删掉后续要用的产品。自定义脚本须把它们的 `BUILD_DIR` 指向 work、`TEST_LOG`/`TEST_JUNIT`/结果包指向 evidence；整个脚本成功退出后自动回收。Mac mini 队列已有自己的任务关闭管理，不嵌套改写其路径。原生图册或人工预览使用的外部产品也不会被无依据地接管删除。

## 删除边界与验证

工具只删除自己新建且登记的 `work/`，不接管历史目录。删除前检查目录身份、符号链接边界、挂载点、完整进程参数、打开文件和证据哈希。进程仍以 work 为工作目录也会阻止删除。登记写入和回收使用锁，启动记录原子发布；保留标记可以在运行中写入。绕过入口的任意外部进程不受锁约束，复用前应先 protect。

`make -f scripts/Makefile test-work-check` 执行边界测试。真实 Makefile/CLI 测试只替换 Xcode/格式化器，不启动模拟器；另有真实进程 cwd 占用及实际删除验证，见 `output/local-test-lifecycle-20261020/`。本轮未运行 iOS 功能测试。
