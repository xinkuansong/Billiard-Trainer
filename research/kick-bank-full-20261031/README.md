# 解球完整离散题库（2026-10-31）

入口沿用已审阅的 `kick-grid-filtered-20261030` 原生生产物理工作器，只撤掉小样配额和提前停止。所有生成数据在 `output/kick-bank-full-20261031/`，App资源另有SHA绑定。

## 范围

四分之一台面12×6格，每格72个5°方向；每方向重新在格内随机母球起点（5184个独立起点）。同一起点/方向组合4档杆速1.5/2.5/3.5/4.5m/s和5档侧塞0/±0.25/±0.5R，共103680输入。每个输入寻找1–4库、各取最先通过的目标球位置；不枚举连续参数或所有可能目标点。高低杆为0，不做5–6库、镜像扩展、扰动或障碍球少库排他搜索。

## 重跑

```sh
python3 scripts/local_test_lifecycle.py run --task kick-bank-full-20261031 -- python3 research/kick-bank-full-20261031/run.py
/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 research/kick-bank-full-20261031/audit.py
python3 research/kick-bank-full-20261031/render.py
```

原生工作器通过受管构建目录、共享fleet的notch-phone租约运行；每格独立保存并精确重放全部候选。已完成格仅在可执行文件、输入、Swift入口与文件SHA均相同时复用，否则拒绝覆盖。成功后自动回收临时构建目录和释放设备，保留gzip证据。失败轮次保留现场；不绕过生命周期。再次构建若可执行文件SHA变化，需新输出目录而非删除旧证据。

`audit.py --selftest` 验证旧去重算法与索引算法的等价性。`--partial` 只审计已完成格，不发布题库；`--partial --benchmark` 加5000条性能探针，不替代完整审计。

## 保留的筛选

首库真实行程≥0.20m；入库与切线夹角15–75°；六个主直库且离每段端点≥0.10m；禁止相对墙A→B→A往返。目标球合法、不重叠、不截断更早路线、杆身可击；放入目标球后重跑，首次碰目标前实际完整库序相符，模拟完成且母球全程不落袋。目标所在出库段>.22m，端部留.09m，横偏≤.9R。

去重同库数/物理墙序，相应两球位置各≤1球直径，整段碰球前路线双向距离≤1球直径（路径每≤1cm采样并预留5mm）。按绝对横偏、低杆速、稳定ID选代表；不链式合并，不移球或改参数。空间索引仅缩小比较集合，不改变语义或代表顺序。每条合并直接回验，所有保留题再核无近邻重复。

用户实打新增的“碰目标后母球或目标球必须再碰库（含袋角）”独立于题库构建。本流水线只报告参考参数是否具有该事件，**不按它删题**。参考参数证明所标碰球前轨迹可达，不能冒称所有参考参数都是新作答规则的完整成功解。

## 证据

- `input-binding.json` / `sampling.json`：输入与随机位置。
- `source-binding.json` / `build.json`：当前生产物理与工作器绑定。
- `cells/00..71/receipt.json`：每格摘要、文件哈希、输入/入口/可执行文件身份。
- 每格 `accepted.json.gz`、`verification.json.gz`：完整事件/轨迹和逐事件精确重放。
- `audit.json`、`deduplication.json`：独立审计与代表映射。
- `bank-index.json`：每题网格、角度、库段和碰球后碰库诊断。
- `kick-practice-bank.json`：无研究轨迹的紧凑App候选资源。
- `selected.json` / `index.html`：36道实测样题、每行3道。

App最终资源、统计断言和消费端验证须在完整审计后更新。研究证据不等同于真机、实台或发布验收。

本轮附加收尾：`player_rule_diagnostic.py`只补最新“碰球后任一球碰任意库（含袋角）”的诊断，不改变题目集合；`integrate.py`在审核后首次发布，拒绝意外旧断言；`validate_app.py`经fleet独占设备使用受保护构建目录，`--collect-only`仅校验已成功的原始结果，不重跑或改写测试；`publish_report.py`在App验证证据齐备后生成报告。
