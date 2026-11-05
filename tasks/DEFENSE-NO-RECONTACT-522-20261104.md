> 2026-11-04 最新授权与交付：两批522＋853均完成（8进程），1375道受影响题已全部重搜。用户现明确要求将全部合格结果替换到正式库并删除不合格题，覆盖下方“仅保留pending、不发布”的阶段要求。正式轨迹库4234题10191参考，106道无合格解题已移出；自由59000保持。产物与删除名单在`output/defense-no-recontact-1375-20261104/r1/`，App资源、加载SHA/指纹及题量测试已同步。历史原件与pending清单仅作研究证据。

> 用户最新纠正：保留原题重新找答案，不以移除旧坏解直接删题。范围扩为全部1375道涉及回撞的题：当前522先完成，另853随后以8进程重搜，总并发最多8。最终合并到output/defense-no-recontact-1375-20261104/r1，question-inventory.json保留原4340个题ID；未补到答案的题留pending-questions.json，禁止丢失或用坏解补数。filtered-bank和此前final-bank仅作阶段草稿，不发布/不覆盖App。生产App资源尚未修改。

# 排除目标球吃库后回撞母球，八进程补搜522题

状态：清理完成✅；522题补搜🔄编译成功，8进程均已产出；进度以status.json为准。

用户明确授权剔除该类参考，求解过程增加限制，对失去全部参考的522题用8个进程补搜。事件定义：首次母球—己方目标球接触，随后该目标球碰主库0–5，再次发生同一对球的接触。按事件数组顺序，不按时间戳大小、不看绘制折线。母球吃库后碰目标球、目标只碰jaw、首次接触前碰库、其他球相碰不属于此规则；不把此内容准入约束当作实际用户击球犯规。

输入真源：`output/defense-full-5698-20261104/r1/`已完成5698输入，4340题10467参考。新输出独立目录`output/defense-no-recontact-522-20261104/r1/`，旧原件不改。

- `filtered-bank/`：已移出2008参考，剩3818题8459参考。522空题记pending-research；其余原本未找到的1358题不额外扩大补搜范围。
- `removed-references.json`、`missing-question-ids.json`：精确删除及补搜名单，与上一轮独立分析名单逐项相同。
- `research/defense-no-recontact-522-20261104/main.swift`：新事件检测纳入defenseRouteViolation；候选、局部细化种子、扰动、最终重放均执行相同约束。双指标/厚度/库数/网格保持。导出器另有事件门禁，防止坏解被装包。
- 8进程各65/66题，固定打散、无旧坏解热启动；复用原全量冻结source-snapshot与原资产指纹，隔离其他会话App变更。输入不动、原子checkpoint/压缩/断点机制保持。
- 完成后自动输出`bank/`（522补搜子集），再与3818保留题合并至`final-bank/`；后者是完整修订版，schema仍defense-parameters-v1，policy升为pure-defense-cut60-rails1-total2-no-target-rail-recontact-v2。
- 保留参考的旧selectionProbes未重模拟，其政策记录在selectionProbePolicyVersion中；不得声称旧四探针已按新禁回撞条件复验。新补搜探针执行新政策。补搜无结果仍记not-found，不能强凑。

验证：纯事件Swift检测函数7种边界通过（主库/母球库/jaw/接触前库/重碰早于库/其他球/球顺序对换）；与Python独立检测交叉核对完整10467真实参考，命中2008条完全一致。证据`r1/tests/check.swift`、fixtures.json。筛后包逐分片SHA、回读字段相等、零禁用事件链通过。

受管运行：`6cff265098e04e3fb8ee93629c0f11ef`，launcher.json/log和status.json保存PID与进度。完成前不宣称补搜通过或App更新完成。

清理版的App消费资源已生成在r1/filtered-app-package（未覆盖生产资源）。生成器已支持新policy并再次校验零禁用事件链；自由库SHA保持3d9b9311…，轨迹包3818题8459参考。

后续853任务队列：research/defense-no-recontact-853-20261104/queue.py，等待522受管运行成功释放租约后才启动新8进程，随后merge_all.py按题合并既有合规参考和两批新参考。双方初始球位/球号/球权逐字段相等；最终审计deletedQuestionIDs=0、forbiddenReferences=0。队列日志在output/defense-no-recontact-853-20261104/r1/queue.log。

第一批522已完成：416题找到562个新参考，106题继续保留为待补解；bank/audit通过、运行退出0。使用原冻结代码，execution.sourceDrift仅记录相对当前工作树的其他会话变更，不代表本次运行中切换物理。后续853已排队启动，最终合并仍需等待。

853队列首轮启动失败（FL-250）：queue.py遮蔽标准库导致递归；已精确停止并保留证据，改名launch_queue.py和__main__保护。修正版日志queue-fixed.log，受管run639cac0c538a45358b7eaa360f998ac6，实际编译中；旧“已启动编译”判断撤回。522完成结果不受影响。

## 正式替换验收（2026-11-04）

- App轨迹资源已替换；SHA `6310a12902467829cba46116a3f9ebf5a7145a81c75fe79d072dc4ace35548ff`，sourceFingerprint `8ade37155415125b2e59f50b9550802e9c70d7192fcd795db4cc7e3f85872565`。加载器训练指纹升为`defense-full4234-free59000-v2-6310a129-3d9b9311`，保留已有历史兼容策略，旧训练不继续混用新包。
- 题量断言同步1001/1040/1050/1143；删除ID集合与106项pending逐项相等；自由库字节不变。
- 生成器分片校验及零回撞事件审计通过。将真实生产Store（含SHA、gunzip、validate）、DTO、枚举原样提取为macOS CLI编译执行，4234题10191解/自由59000解码与全参考事件审计通过；证据`consumer-check/result.txt`。这是数据消费检查，不是全App XCTest/UI/真机验收。
- `verify-doc-size`通过。`verify-gate`内容及DTO段通过，最后被既有路由登记`route-coverage.csv:69`引用已删除`SnookerTacticsView.swift`阻断；日志`verify-gate.log`。未修改该无关路由。
- `publication.json`保存删除ID、正式资源SHA、验证边界；`before-publish/`与原研究包仅作审计，不再作为正式题库。此任务已完成正式资源替换，无待补搜题进入App。
