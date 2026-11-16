# 重打后目标袋再提示

2026-11-16，用户在源码分析后授权所有受影响入口一起实施。

## 合同与范围

主动重打成功、球位和目标恢复后，原短亮目标袋立即重新高亮3秒。复用现有材质和计时；这是视觉提示，不另发选袋触感。普通重绘、调参、回放、规划上一步、无效重打、后台恢复不重新提示；角色常亮袋保持原色；无有效目标袋不提示，也不重新推荐球袋。

- 独立入口：准度、分离角、瞄准点练习的 retry。
- 共用 PositionPlay：正式分离角与走位（含导入）、自定义球形练习、蛇彩、多球自主、动作库可操作试打、批量编排重打/重录。另接入多球自主存档恢复后、缺少上一杆缓存时的控制器重打备用路径。
- 排除：常亮的两球/三球/多球规划/P05/K球/翻袋练习/走位及翻袋求解；无目标袋的解球/防守/颗星；每日清台仅回放或规划上一步；只读序列演示。

## 局部TP复核

| 条款 | 判定 | 本轮验收 |
|---|---|---|
| TP14 | 按用户新决定调整 | 主动重打为同题不续时的例外；3秒、原材质、角色常亮隔离 |
| TP25 | 继承 | 恢复原球袋/参数，回放与上一步不混同 |
| TP26 | 继承 | 不增加首答、次数、成绩或额度，不改变保存事务 |
| TP29/30 | 继承 | 2D/3D共用场景提示；切模式/后台/离页撤销旧反馈 |
| TP31 | 按业务调整 | 重打只提醒视觉，不补选袋触感 |
| TP35 | 继承 | 定向逻辑/原生操作/动态显示分别验证，真机手感不以模拟器替代 |

## 根因与实现

准度按question ID去重，分离角和瞄准点retry没有提醒事件；共用PositionPlay恢复选择会取消瞬时反馈，随后的updatePocketHighlights显式禁止确认事件。修复在成功恢复的末尾触发，渲染重绘本身不承担事件。

## 验证进度

- 初次改前构建被并行球形记忆任务尚未接齐的BoardMemory类型阻断，未运行测试。原件：`output/local-test-runs/c3a6079bd30544178618c63312357cab/evidence/`。
- 使用独立冻结源码继续改前和修后验证：`output/local-test-runs/c873eb39ba9247ff8367d94e6064d919/`。
- 冻结快照初次构建遇到另一任务正在修正的BoardMemory Binding类型错误，补入其已修正文件后继续；未回退或重写另一任务代码。
- baseline-r2：测试使用旧table.scene标识读取瞄准点页面失败；按页面现有aimPointTraining.scene修正测试定位，生产行为未改。
- baseline-r3：原生瞄准点2D点击重打后，原目标仍选中但高亮opacity=0，预期1的断言失败；截图已审，确实无袋口提示。原件：evidence/baseline-r3.xcresult、baseline-r3-images/。
- 生产核心五文件已接入共用remindTargetPocket；仅现有.target允许重启3秒，四条VM路径在成功恢复后调用。修后定向回归最终通过，详下表。

- 源码补查发现多球自主Checkpoint.previous可恢复，但host上一杆缓存不恢复；控制器undo会直接loadBoard/restoreTrainingInput。此明确重打备用路径另接共用提醒，补存档恢复定向测试；其普通回放/恢复存档自身不提示。

## 原生与逻辑验收

设备：本地共享large-pad，iPad Pro 13-inch (M4)，iOS 26.3.1；由生命周期入口持有并释放同一设备租约。采用冻结源码，测试相关六处方法与工作区逐项一致；其余并行球形记忆变化另存差异，不把本轮结果当作整个脏工作区的回归。

| 验证 | 结果／证据 |
|---|---|
| 准度、瞄准点、分离角、正式composer宿主 | after.xcresult中4项UI测试通过；每页2D/3D，覆盖重打前、即时提醒、到期恢复，共24张原图 |
| 瞬时目标／全部角色色／重复重打计时／无效袋／触感隔离 | after.xcresult中场景逻辑测试通过 |
| 选定编排杆重打：普通目标、自由瞄准、规划角色 | after.xcresult中模型逻辑测试通过；保留序列、不补触感、后续重绘不重播 |
| 多球自主存档恢复重打备用路径 | fallback/r4/r5旧夹具在求解期间调用saveCheckpoint，按合同跳过，未保存上一杆；r6增加求解等待与canUndo入口断言，确认原袋正确再亮；仅触感断言误把loadBoard既有1次自动确认当作新增。r7对齐既有行为后通过。生产提示在恢复输入及角色刷新之后 |
| 自动选袋及普通调参不重播 | 既有回归最终在fallback-r6通过；新提醒不让普通调参重播 |

已检查四份截图组：每组上排2D、下排3D，依次为重打前／重打后／提示结束。重打后仅原目标袋呈现既有蓝色提示，结束后恢复主题皮革；球位与相机按原重打逻辑恢复。

- [准度截图组](../../output/local-test-runs/c873eb39ba9247ff8367d94e6064d919/evidence/after-images/accuracy-review.png)
- [瞄准点截图组](../../output/local-test-runs/c873eb39ba9247ff8367d94e6064d919/evidence/after-images/aimPointTraining-review.png)
- [分离角与走位截图组](../../output/local-test-runs/c873eb39ba9247ff8367d94e6064d919/evidence/after-images/composer-review.png)
- [分离角截图组](../../output/local-test-runs/c873eb39ba9247ff8367d94e6064d919/evidence/after-images/separation-review.png)

冻结源码、SHA与并行源码差异保留于同一evidence下的source-after/、source-comparison.json、concurrent-source-difference.diff。原始失败和成功xcresult/log分别保留。

范围限制：其他共用入口逐一做了调用链核对，未逐页跑原生测试；未进行iPhone、真机、VoiceOver或全App回归。本次不调整布局、颜色、成绩、额度和持久化事务。

补充测试环境记录：fallback-r2在App启动前被模拟器Busy拒绝，0项执行；等待共享租约释放后，r3误用test动作未生成的xctestrun，0项执行；后续改回原project/scheme增量入口。失败原件均保留，未用它们断言产品行为。

## 最终结果与收尾

- 8个去重定向测试最终通过：after中2逻辑＋4原生UI（每页2D/3D），fallback-r6中的自动选袋既有回归，fallback-r7中的真实存档恢复重打。0跳过；逐项最终状态见evidence/final-test-status.json。早期失败逐轮保留，不改写成成功。
- 多球备用路径原有loadBoard自动确认产生1次触感；提醒自身不额外触发。其他重打入口与场景提醒逻辑已验证无新增触感。
- TP14及来源表、DR-436 r4、UI接口、讨论与进度已同步。局部功能/原生视觉验收通过，非整页/全App或真机验收。
- 初次失败工作目录已由生命周期入口回收；最终冻结工作目录在证据导出后收尾。共享核心设备保留，任务租约已释放。
