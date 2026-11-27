# 扎杆10,000基础球形全量运行（2026-11-26）

状态：**已实际启动，后台计算中，尚未全量完成**。范围是既定10,000个基础球形，不重新抽样；每个球形只导出一个障碍位置和一个合格扎杆解。正式题库和训练页面未修改。

## 当前执行后端（8 路，2026-11-26 更新）

串行保存4,680个后完成对照：32个球形在1/2/4/8路下与原包逐字段一致；8路搜索189.32→37.60秒（5.04倍），宿主RSS峰值约915MiB。现采用同一compact-phone内部8路，每批400个；首批400真实测试通过、独立复核337合格，累计5,080个、3,127合格（此为首批结束快照）；原搜索/候选判定与已保存包不变，新包记录executionRevision。原串行生命周期已被替代，当前运行定位见 `masse-parallel-current.json` 和 `job-state.json`；测速与证据见[并行报告](masse-parallel-20261126.md)。下文100题/批和原生命周期ID为首次启动记录，不是当前运行配置。

## 启动验证

- 已校验复用首批60个原始结果（20个候选），原始证据不改写；新包记录原runIdentity和原包SHA-256。新增待计算9,940个。
- 首个新增20球形批次真实XCTest通过：搜索73.642秒、几何用例0.002秒，0失败；已确认逐题落盘和独立候选审计串联运行。
- 截至首批验证：80个球形完成，38个候选通过独立审计。原始模拟通过数39，其中球形18未通过记录接触弦线受阻检查，单列待复核、不导出；其他41个为本轮未找到解，其中4个包含不完整模拟，不能判为不可解。
- 后续进入每批100个的连续计算。统计是首批验证快照，实时进度以下方状态文件为准；部分当前批次球形已落盘时，实时文件数会领先上一批汇总。

## 保持不变的求解口径

复用首批验证的生产物理二进制，Swift求解源码、256组打点/杆速/仰角候选、瞄准补偿、障碍位置搜索、可出杆、贴台/进袋/避障判定和独立几何复核均不改变。不做扰动试验。低仰角优先、找到一个模拟合格解早停；只有通过独立复核的结果进入候选导出，待复核记录不当作合格题。详细参数见[首批报告](masse-search-results-20261126.md)。

本轮仅扩展任务编排：10,000清单、60个结果带来源复用、流式汇总、持续运行、候选原子发布和有限启动重试。流式汇总已对原60条逐字段等价验证，候选提取对原20题完整等价验证；错误首碰球和直线轨迹负例仍拒绝。

## 运行和资源

- 全量身份：`b9eb39866b367c12cddb3089be3bc56138bf7950936c866fc1f180043c281615`。
- 本地compact-phone共享独占租约，关闭Xcode自动并行克隆。不会新建第二套模拟器。
- 运行副本通过APFS克隆到受管work目录，签名和测试输入只改克隆副本。原构建不被本轮运行覆盖。
- 本地工作目录生命周期ID：`2c13af9710584a558b112fc7e326c3ca`。任务完成后由既有生命周期入口自动清理本轮work、归还并关闭设备；结果、原始日志和失败证据保留。失败时work保留待诊断，不清理其他任务。
- `caffeinate -i`覆盖本次命令生命周期，避免空闲休眠中断。对话结束后进程继续；关机/重启后需要从结果断点重新启动。
- 每题原子写入压缩结果；每批更新汇总及单解候选清单。执行后端启动时校验输入与求解二进制身份，逐题校验来源和结果。
- 仅对明确的模拟器宿主启动失败自动重试，连续3次仍失败则停止并保存错误；数据校验错误不自动跳过。
- 起跑可用约56 GiB，按首批外推保守证据预算约25 GiB；每批检查剩余空间，低于20 GiB停止并保留断点。
- 首批60的求解用时合计342.051秒，单机外推纯求解约16小时，另有批次启动/审计开销；不同球形的早停会改变总时长，此为粗估，不是完成时间承诺。

## 查看进度和结果

- [实时作业状态](evidence/masse-search-20261126-b9eb39866b36/job-state.json)
- [最近完整汇总](evidence/masse-search-20261126-b9eb39866b36/summary.json)：solved是模拟判定通过数，正式候选数量看下面独立审计。
- [独立候选审计](evidence/masse-search-20261126-b9eb39866b36/candidate-audit.json)：acceptedCandidates为真正导出的候选数，reviewRequired单列。
- [每题单位置单答案的候选清单](evidence/masse-search-20261126-b9eb39866b36/question-candidates.jsonl)
- [10,000个输入与参数](evidence/masse-search-20261126-b9eb39866b36/manifest.json)
- [60个复用结果的来源](evidence/masse-search-20261126-b9eb39866b36/reused-pilot-packets.json)
- [启动前核对](evidence/masse-search-20261126-b9eb39866b36/preflight.json)

```bash
python3 research/masse-jump-capability-20261122/run_masse_full.py status
```

该命令同时显示最后批次统计与savedPacketsNow（实际已落盘数量）。原始结果在同目录shapes/*.json.gz；测试日志、xcresult和成功批次receipt保留在该目录。启动命令及PID记录于launcher.json；生命周期证据路径在job-state.json。

## 中断后续跑

先确认原任务已退出、租约已释放；不得启动两个全量任务。若旧租约因强杀残留，按共享模拟器生命周期规则核实后recover，不直接删除锁。保持现有请求文件和结果目录，使用同一受管入口：

```bash
/usr/bin/caffeinate -i python3 scripts/local_test_lifecycle.py run --task cb01-masse-full-10000-resume -- python3 scripts/simulator_fleet.py run --role compact-phone --task cb01-masse-full-10000-resume -- python3 research/masse-jump-capability-20261122/run_masse_full.py work --udid '{udid}' --work '{work}' --evidence '{evidence}' --batch-size 100
```

已经落盘且身份匹配的球形自动跳过。请勿在运行中调用prepare或重写全量清单；独占锁会拒绝冲突操作。暂未执行全量收尾或发布，后续以pending=0、候选审计和最终资源回执共同核对完成。
