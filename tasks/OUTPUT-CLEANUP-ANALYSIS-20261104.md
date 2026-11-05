> 执行状态更新：用户已批准，本轮候选已清理完成。实际收益、保留方式及验证见 [清理结果](OUTPUT-CLEANUP-RESULT-20261104.md)。下文为执行前分析记录。

# output 占用与清理建议 · 2026-11-04

状态：只读分析已完成，补充后的output候选约138.06GB（见末节），本轮未删除任何 output 业务资料。本报告取代上一份清单中“整份删除旧工程快照”的粗粒度建议；快照内部包含最终验收图片，必须按文件/子目录处理。

## 实测与方法

- 全目录扫描 1,682,097 个普通文件，无访问错误，文件分配量合计 562.80 GB；du 含目录元数据约564.25 GB。遍历不跟随符号链接，对硬链接inode去重。扫描期间其他任务仍在写入，并非冻结全盘快照。
- 文件分配量仍会重复计入APFS共享块，不是独占物理空间，也不是可释放保证。
- 内容容器优先分类：先遇到的工程快照、xcresult、app或DerivedData归为整体；其中嵌套内容不在主分类表重复计数。构建目录包含Products/日志，不能全部叫可丢弃缓存。

| 主分类 | GB | 判断 |
|---|---:|---|
| 测试结果包 | 142.06 | 大量历史轮次，可按最终覆盖/故障诊断价值分级淘汰 |
| 工程快照 | 134.19 | 大头是重复的教学图片、模型等资源 |
| 独立图片 | 111.40 | 混有母版、正式验收、过程截图，不宜按扩展名清空 |
| 数据及压缩包 | 64.28 | 研究全量、过程记录、备份混合 |
| 独立视频 | 35.80 | 包含待发布成片与原始素材 |
| 独立App副本 | 33.09 | 包含恢复原包、评审现场归档 |
| 其他二进制/资产 | 28.32 | 含Blender母版、自动备份、设计资产等 |
| 构建目录 | 10.36 | 包括App和日志，仅少量狭义编译中间缓存 |
| 独立日志/文档/脚本 | 3.30 | 体积小，不作为优先目标 |

## 第一优先：重复资源，保持每个版本至少一份

选取最大的12份历史快照资源树，并与当前生产Resources一起逐文件SHA-256比较。只将同相对路径、同长度、同SHA文件认作重复，不因同文件名/同目录大小判断。

- 确认重复 46,104 个文件，目录分配量 **74.78 GB**。
- 比对期间文件身份/大小/mtime未变；保留路径与删除候选集合无交集，保留文件当前存在。
- 每份快照的Swift代码、独有资源、内嵌output图片、manifest、日志保留。
- 实施前应将每种独有内容保存在固定版本的资源归档中，并保存恢复映射；不要只依赖以后会变化的当前生产资源。删除副本后旧快照不再直接自包含，须按映射恢复后复跑。
- 机器清单 `resource-duplicates-verified.json` 为逐文件duplicate/keep/SHA/长度映射；本轮仅审核，没有创建归档或删副本。

| 资源副本位置（相对output） | 已验证重复 GB |
|---|---:|
| `pro-implementation-20261019/frozen-r2/QiuJi/Resources` | 8.103 |
| `table-optimization-20261014/source/QiuJi/Resources` | 8.023 |
| `table-runtime-device-20261014/source/QiuJi/Resources` | 7.895 |
| `table-materials-v64/W4/baseline-source/QiuJi/Resources` | 6.531 |
| `table-materials-v64/W5/device-source/QiuJi/Resources` | 6.530 |
| `pocket-profile-20260913/source/QiuJi/Resources` | 6.516 |
| `ui-inventory-20260915/xcuitest-r1/source/QiuJi/Resources` | 6.502 |
| `3d-scope-audit-20260912/source/QiuJi/Resources` | 6.466 |
| `3d-v63/W01/red-control/QiuJi/Resources` | 6.466 |
| `aim-preview-v61/validation-checkout/QiuJi/Resources` | 6.465 |
| `table-optimization-20261014/merged-source/QiuJi/Resources` | 2.708 |
| `table-materials-v64/W4/candidate-source/QiuJi/Resources` | 2.571 |

## 第二优先：恢复任务已经结束的App安装包副本

`drill-copy-full-20261016/native/*-pre-*/app` 共11份，**7.15 GB**。这些是测试前复制的App，非App源码或用户数据。`REPORT.md`与`native/NATIVE-FULL-LOG.md`记录手机、SE、iPad的App/数据/settings已逐项恢复；两次恢复错误也已完成后续修复与核验。

建议淘汰这些旧安装包，保留旁边的 `data`、恢复回执、指纹、原生截图和报告。这里的依据是恢复用途已经结束，不是声称11份安装包全部字节相同。具体路径见 `restored-app-backup-candidates.json`。

## 第三优先：已完成研究的完整微调过程

`two-ball-comfort-refine-full-20261025/refinement/`：**14.635 GB文件内容**，已gzip9压缩；包含约3370万次原生搜索的候选轨迹和淘汰过程。任务complete/auditPassed，资源收尾closed。

建议如不再需要逐候选追溯，可淘汰这一过程档案。保留 `final/`（约0.342 GB）、summary、manifest、parts-index、closure、报告和研究源码。

依据：当前 `scripts/two-ball-consumer/pack_comfort85.py` 与 `audit_comfort85.py`读取final及索引，不读取refinement。因此最终库打包/消费端审计不受其删除影响；但研究runner的完整深审会检查refinement，删除后无法按原档案重做完整过程审计，必须重新计算。不能宣称这是无价值缓存或可以无成本再生成。

## 第四优先：淘汰过期测试原始包，保留结论与必要原件

全局识别2144个xcresult目录。经过目录结构/长度分组再逐文件内容哈希，完整相同的包只有7组，重复分配量 **0.096 GB**；不是上百GB都能靠删除重复包解决。

具体首批可选：`training-hud-20261025` 的iPad r2/r3/r4，合计 **1.527 GB**。r2是只读文字误用isHittable的测试断言失败；r3/r4是旋转超时，随后r5完成真实旋转/窗口复验。本轮HUD后来又被 `training-hud-feedback-20261025` 用户反馈修订覆盖。建议保留r5、首轮成功覆盖、后续反馈最终证据；旧三包先保留失败摘要/日志/关键原图，再移除重型原始包。删除后失去这些旧轮次的完整Xcode附件重浏览能力，不改写原失败结论。

| 旧包 | GB |
|---|---:|
| `training-hud-20261025/pad-r2/tests.xcresult` | 0.419 |
| `training-hud-20261025/pad-r3/tests.xcresult` | 0.552 |
| `training-hud-20261025/pad-r4/tests.xcresult` | 0.556 |

其他大测试目录需沿同样方法逐任务挑选，不能根据r1/r2、日期或“失败”字样自动删除。原始包内也可能有未导出的独有视频/崩溃附件。最大测试包集合：local-test-runs约23.67GB、daily-adaptive-execution约11.59GB、training-accessibility约5.85GB、p01-standard-fix约5.70GB、daily-adaptive-v4约5.27GB；这些数字是审查池，不是已批准/已确认可删除量。

## 本轮保留项

- `local-test-runs`：367项已reclaimed，work已自动收尾；仅两项仍有work，且明确hold用于准度题库继续研究。约30GB整个目录主要是外置证据，不是漏清30GB缓存。失败/hold两项保持。
- `simulator-fleet-20261020`约12GB：23台已退役设备的应用数据与20份去重原版App恢复归档；不是普通测试残留。删除会撤销旧设备恢复能力。
- `tutorial-refresh-20261015`约12.73GB：9.72GB旧教学母图备份、3.01GB新原生图，不等同可删屏幕截图。
- `render-quality-v62`的S250/S251暂停袋口实验、Blender母版；`3d-v63`待验材料、每日适配未闭环诊断，均不按老日期清空。
- `待发布视频`约3.91GB以及其它视频台账对应成片/素材。
- 当前防守任务、近期题库及正在写入的目录。

## 建议实施顺序与限制

1. 先做74.78GB重复资源的按内容归档与副本清理，再移除7.15GB已完成恢复用途的App副本。
2. 若接受放弃完整搜索过程追溯，再清14.635GB refinement；保留0.342GB最终库。
3. 旧测试包先从1.527GB明确已被后续复验覆盖的三包做起，随后逐任务扩展，不整目录清空。

以上三批/四类涉及约98GB目录与文件分配量，实际释放需实施后df实测。共享块可能使收益明显更小。扫描得到的27个具体候选根在检查时无打开句柄/进程参数引用；正式删除前仍需重新检查身份、占用和保留副本。当前仅分析，没有按建议执行删除。

## 依据与机器清单

- `output-content-audit.json`：全量分类、最大文件及候选容器。
- `snapshot-resources.json` / `resource-duplicates-verified.json`：资源规模及完整内容哈希映射。
- `xcresult-duplicates-verified.json`：完整相同测试结果包。
- `restored-app-backup-candidates.json` / `output-candidate-activity.json`：安装包路径与当前占用检查。
- 任务依据：`tasks/materials-v64/W4-验收与交付.md`、`W5-皮革内壁返修.md`、`tasks/SIMULATOR-FLEET-20261020.md`、`tasks/DISK-MEDIA-CLEANUP-ROUND2-20261028.md`、`tasks/TUTORIAL-FIGURES-REFRESH-20261015.md`、`tasks/ui-reviews/UR-20261025-training-hud.md`及feedback、`output/drill-copy-full-20261016/REPORT.md`与`native/NATIVE-FULL-LOG.md`、`output/two-ball-comfort-refine-full-20261025/README.md`和closure、两个consumer脚本。


## 补充：output其余部分全量分账与新增候选（同日）

用户进一步明确只问截图里的output约563GB。本节不将build/archive/research中的其它87.95GB已验证重复量混入output候选。前文约98GB为第一批，不代表其余均需保留。

### 新增确认

1. **同任务内重复媒体 25.042 GB**：扫描68,119个独立媒体文件、约140.81GB；排除工程/xcresult/App/构建容器、前批11份App备份、local-test-runs及当前defense目录。7,895组同大小且完整SHA-256相同内容。该量与第一批候选不重叠。不改变画面像素即可合并；先固定保留一份、调整HTML/报告/脚本引用或提供恢复映射，不能直接删掉有引用的路径。母版和不同版本都至少保留一份，暂停项目保留语义不因重复扫描而解除。

| 主要目录 | 内容相同的额外副本 GB |
|---|---:|
| `tutorial-refresh-20261015` | 5.120 |
| `render-quality-v62` | 2.828 |
| `table-resources-r2-20261014` | 1.878 |
| `daily-adaptive-execution-20261006` | 1.251 |
| `render-system-audit-20261011` | 1.096 |
| `training-accessibility-numerics-20261028` | 1.054 |
| `daily-adaptive-v4` | 0.986 |
| `two-ball-practice-20261025` | 0.582 |
| `table-materials-v64` | 0.547 |
| `practice-review-20261029` | 0.459 |
| `3d-v63` | 0.410 |
| `shot-recommendation-acceptance-20261026` | 0.318 |

2. **另外两批研究过程档案**：

- `two-ball-refine-full-20261025/refinement`：4.398 GB。
- `two-ball-grid18-20261025/proofs`：4.480 GB。

旧25°微调的final约0.285GB仍是后续阶段的来源，保留；refinement是完整搜索过程，可在接受不再深审逐候选后淘汰。18°网格不是现行舒适度85主链输入，proofs约4.48GB记录已弃用研究分支搜索证据；建议保留约0.37GB parts及README/统计/清单，淘汰proofs意味着失去该历史分支完整过程证据。参考当前完整题库方案第7–10节与两个输出README。保留1357分片清单不等同保留已删数据，实施时应明确标记档案退役。

3. **已完成性能对照的旧App包**：下列3个任务的App/Runner子目录合计 6.058 GB。任务报告已记模拟器对照与集成完成，原指标、源码、资源原版、图片及结果包保留；这些旧可执行产品建议退休。它们是历史性能对照版本，不是现行App，删除后不能直接启动该历史二进制做对照。精确路径在output-additional-candidates.json。未将模拟器恢复原包、当前人工评审App一并纳入。

| 任务目录 | App/Runner GB |
|---|---:|
| `table-resolution-20261014` | 2.627 |
| `table-resources-r2-20261014` | 2.028 |
| `table-runtime-20261013` | 1.403 |

新增候选合计约 **39.98 GB**，与前批合计约 **138.06 GB**。这是可按上述条件处理的目录分配量，未承诺独占空间或已释放。当前没有删除。

### 剩余占用的判断

- 142.06GB测试原始包：第一批仅明确挑出1.53GB旧HUD轮次，其余仍需要按每个任务的最终有效覆盖、故障已闭合/未闭合、附件是否已导出选留。完整相同包只有约0.096GB，不把142GB当全量可删。
- 134.19GB源码快照：已验证重复资源74.78GB。剩余不是60GB纯代码，仍含未在前批12棵大资源树中核对的资源、内嵌产物、独有版本；建议继续按内容去重并保存恢复映射。
- 111.40GB独立图片与35.80GB独立视频：新增媒体去重已覆盖大部分非受保护独立媒体，25.04GB是同任务内容相同的冗余。余下含教学母图/旧备份、不同实验图、最终截图、待发布和原始视频；不能把图片总量当截图垃圾。
- 64.28GB数据/压缩包：三批微调/搜索过程合计约23.51GB已列候选；当前final、原125组基础模拟库、现行题库来源和未完研究保留。其它旧分支可逐步退休，需看消费者链。
- 33.09GB独立App＋10.36GB构建目录：其中约11.93GB属于退役模拟器的原App恢复归档；另有当前评审和待续包。新增6.06GB为已完成性能对照旧包；App目录内无后缀的其它旧备份另在前批按实际内容识别。
- 其它二进制/资产28.32GB＋文本脚本3.30GB：包含Blender母版/自动备份、设计文件和无.app后缀的测试备份。文档脚本不是优先目标；需把母版与自动保存备份拆开，不整类清空。

推荐下一步保留策略：已关闭任务保留报告、指纹、最终必要图/结果及关键失败证据；普通中间截图、录屏、完整测试包和旧安装产品不永久全留。未关闭和明确待续项目另列。此策略若获确认，再逐任务产出精确清单实施；不因用户询问分析而直接删原件。
