# 防守全自由题库两球／三球多解生成

状态：已被[按两颗球各自库序去重的新版](DEFENSE-RAIL-SEQUENCES-FULL-20261106.md)替代；旧批已受控停止、归档保留。原记录：用户授权全自由库57575个非单球原题；每个入选球形多个解；区域型／遮挡型都保留。

范围与条件：[统一记录§21](../docs/research/20261105-防守现状与区域生成.md)、[执行README](../research/defense-multisolution-full-20261106/README.md)。实际生产App资源不替换。本次为独立离线候选包。

- [x] 冻结原始球形ID/坐标/球权，9918 + 9941 + 37716 = 57575。
- [x] 通用球权、三球静止8号遮挡，区域及遮挡分别种子搜索；生产v8精算。
- [x] 多解按实际碰撞序列或终点间距去重，至少2最多6，四探针均通过。
- [x] 480个Swift编译输入原生构建成功；36例先导完成并独立核验。
- [x] 先导10多解、4单解、22未找到；40条完整重放，32区域/8遮挡增益。7项破坏性反例测试通过。
- [ ] 57575全部逐题完成；任何错误须排除，不能当无解。
- [ ] 全部归档SHA、原始输入、物理/评分/窗口、多解差异二次核验。
- [ ] 新schema分片候选包与multi/single/noSolution完整清单、manifest。
- [ ] 更新实际完成数据；归还模拟器、受管工作目录收尾。

当前执行：`output/local-test-runs/aaf93f4057f942c6aae1defc70f598f1`，同目录evidence有构建命令、完整日志。运行信息[run-paths](../output/defense-multisolution-full-20261106/run-paths.json)；[status](../output/defense-multisolution-full-20261106/status.json)实时变化。先导[审计](../output/defense-multisolution-full-20261106/pilot-audit.json)。

下一步：继续监控原进程；结束时核验全量manifest而非仅看worker结束。中断按README的resume复用冻结二进制，禁止另起重复全量。仅1解不能进多解包；无解≠物理不可行。窗口不下降和30cm仍是暂用限制，不能包装成已校准舒服程度；四探针不是成功率；5cm峰值是采样值。未做App UI或真机验收。

最近核验快照（以实时status为准）：147/57575已审计，多解39、单解13、本轮未找到95；保存175条诊断/入选路线。8个worker均存活、生产源码与两份题库SHA无漂移。全量吞吐初估数十小时，非精确ETA。

用户新增要求可视化已找到解，已交付[1022球形/3503路线快照图册](DEFENSE-MULTISOLUTION-GALLERY-20261106.md)及12组多解对照；不影响全量运行，不代表全部生成完成。
