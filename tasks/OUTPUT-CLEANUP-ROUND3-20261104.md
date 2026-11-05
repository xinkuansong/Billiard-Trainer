# output 第三轮清理 · 2026-11-04

用户要求继续检查剩余400多GB，并明确沿用上一轮策略：保留最终结果、最终有效截图、测试摘要和关键失败证据，清理已经结束的任务产物。不再重复请求相同范围的批准。

## 执行范围

### 历史测试包

审查298个结果包，原扫描分配量42.20GB。覆盖准度、多球、两球、蛇彩、自定义球形、布局推广、练习页集中整改、几何参考、瞄准特写、文章接入、视觉回退及HUD任务；另包含9个已收尾分离角专项的受管测试记录。逐项依据与原始路径见`third-round/plan.json`，并非按日期批量删除。

- 本轮先导出每个可读包的测试摘要、测试树、全部PNG和JSON附件；失败方法另保存完整活动树，关联失败的其它附件也保留。因此最终结果不只依赖最后一轮文件名。
- 导出附件按完整SHA归并，映射文件名和附件清单保持可用；原有外置截图、录像、日志、研究数据、源码和报告不删。
- 受管run必须已reclaimed、有结束时间且无hold。两项题库待续hold、其他运行中任务不在范围内，不操作模拟器。
- 新增归档不是Xcode原包的无损压缩。原始xcresult删除后，无法完整重浏览每轮Xcode内部日志/非关键录屏；保留摘要、数据、截图和关键失败证据。历史失败/未验/用户待确认状态不变。
- 原`run.json`中的完整历史证据哈希不改写为新结果；增加独立退役记录说明哪些原包已转为精简证据。

### 旧快照的重复资源

审查82棵旧快照Resources，约52.38GB普通文件。针对≥64KiB文件逐字节SHA比对（小文件约0.86GB暂留），与生产资源及第一轮固定对象比较；审查发现70,308个可归并路径、51.16GB原分配量，内容漂移0。

- 只归并已证实相同内容，独有版本不删；App生产Resources不改。
- 优先复用第一轮只读对象；新增内容固定在`archive/deduplicated-output-round3-20261104/objects/`，使用APFS克隆后读回SHA。
- 原路径变为指向固定内容的相对符号链接，字节与原来一致；保存原mode、uid/gid、时间、扩展属性及恢复映射。
- 持续复查进程引用与打开文件。有占用、内容变化或身份不符的路径跳过。
- 首次替换在只读冻结目录被权限拒绝，尚未替换任何资源即停止。核实为当前用户拥有的0555目录后，调整为仅在单文件原子替换期间增加owner写权限，并在finally恢复原目录权限。第一尝试记录单独保留，不隐藏错误。
- 本轮不整份删除快照，不修改Swift代码；若旧工具要求常规文件，可按下方恢复。

## 验证与结果

- **本轮实测净增可用空间 52.81 GB**：65.80→118.61GB。并发任务仍可能读写，该数值是观察差。
- **output目录分配量404.88→321.38GB**，减少约83.50GB；不等同物理释放量。新增资源固定对象目录约0.515GB，用APFS克隆保留。
- 删除 **293个历史测试包，分配量41.85GB**；5个不完整包无法读取，保持原件。保留并复核 **6,136份导出文件SHA**；原有 **14,455个文件**的inode/大小/mtime/mode/链接指向与清理前一致。
- 4,467个附件路径归并至3,767份固定内容，其中有截图与数据附件。全部PNG/JSON的原始导出映射保留。
- 归并 **68,281个资源副本路径，原分配量50.71GB**。4,109份固定内容全量SHA正确，全部别名指向、长度和父目录原权限通过。
- **2,027个资源路径因检测到任务/文件引用跳过**（每日入口旧任务1,954个、profile-crown-r9任务73个，合计约0.44GB），不强行删除或关闭进程。
- 实际运行恢复工具还原PNG/USDZ样本；字节SHA、文件mode、mtime、扩展属性相同，0555只读目标目录的权限在恢复后保持0555，原别名仍在。
- 测试清理与资源归并验证均为`errors=[]`；所有删除目标不存在，所有跳过测试包仍存在。没有将旧失败结果改写为通过。

|任务组|删除测试包数|删除分配量GB|
|---|---:|---:|
|`aim-point-result-closeup-20261026`|11|1.845|
|`training-visual-rollback-20261028`|22|2.509|
|`practice-review-20261029`|52|2.387|
|`custom-formation-20261018`|6|1.056|
|`custom-formation-20261017`|9|1.461|
|`geometric-reference-20261028`|5|1.864|
|`accuracy-practice-20261020`|41|3.584|
|`snake-practice-20261015`|18|2.165|
|`multi-ball-app-20261026`|19|3.451|
|`training-hud-20261025`|4|1.252|
|`two-ball-practice-20261025`|11|2.133|
|`local-test-runs/separation-angle-object-route`|9|1.409|
|`local-test-runs/separation-six-fixes`|8|0.864|
|`local-test-runs/separation-reference-stages`|6|0.535|
|`local-test-runs/separation-guides`|4|0.588|
|`local-test-runs/separation-practice-build`|17|2.947|
|`local-test-runs/separation-feedback`|4|0.519|
|`local-test-runs/separation-sidebar-spacing`|6|0.997|
|`local-test-runs/separation-default-reference`|3|0.527|
|`local-test-runs/separation-scoring`|8|1.854|
|`learning-articles-rewrite-20261016`|4|1.454|
|`custom-formation-refine-20261018`|5|0.819|
|`layout-local-rollout-20261019`|10|3.382|
|`training-hud-feedback-20261025`|4|0.805|
|`multi-ball-access-r2`|7|1.446|


## 证据与恢复

机器清单位于`output/disk-cleanup-20261104/third-round/`：

- 测试：plan、prepared、protected-files、retained/*/receipt、deleted-tree、result、deletion-journal、attachment-aliases、verification。
- 资源：resource-roots、resource-plan、resource-aliases.jsonl、resource-result、resource-verification；首轮权限停止记录另存。
- `third-round/attachment-objects/`与上述archive目录是真正保留的内容，不能单独当缓存删除。

资源恢复工具：`output/disk-cleanup-20261104/restore_round3_resources.py --prefix /绝对路径/旧快照`先查看匹配项，加`--apply`恢复普通文件。恢复使用独立APFS克隆并恢复原权限/扩展属性；不包含已删除的xcresult。

本轮没有运行App构建/功能测试、更新真机、清理模拟器、提交或发布。清理验证不冒充产品回归验证。
