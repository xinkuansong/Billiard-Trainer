# 当前生产入口：参数题库（2026-10-26）

用户已批准正式接入。资源仅保留参数，运行时真实三球生成。**先重建完整舒适度消费包，再转换参数包；不得对参数包再次使用完整包脚本。**

```sh
python3 scripts/two-ball-consumer/pack_parameters.py FULL_BANK NEW_PARAMETER_BANK PACK_REPORT
python3 scripts/two-ball-consumer/audit_parameters.py FULL_BANK NEW_PARAMETER_BANK AUDIT_REPORT
```

独立审计通过后整目录替换 `QiuJi/Resources/TwoBallBank`；旧包备份到App包外。当前31.45MB、166443题/677488推荐、policy `comfort85-parameters-v1`。参数及引用顺序精确保留，生成失败路线不交付；无离线轨迹的runtime RMS字段为nil。方案、回退和实测证据见 `tasks/TWO-BALL-PARAMETER-CONSUMER-20261026.md`。

以下为上游完整消费包重建方法与历史说明。

# 当前生产消费包（2026-10-26）

用户批准舒适度≥85训练子集，并按首杆执行难度E升序逐条展示。当前脚本：

```sh
python3 scripts/two-ball-consumer/pack_comfort85.py output/two-ball-comfort-refine-full-20261025 NEW_STAGING_PATH REPORT_PATH
python3 scripts/two-ball-consumer/audit_comfort85.py output/two-ball-comfort-refine-full-20261025 NEW_STAGING_PATH REPORT_PATH
```

必须独立审计通过再整体替换QiuJi/Resources/TwoBallBank，并保留旧包。当前166443题/677488推荐；源final/refinement只读。版本、公式及验证见tasks/TWO-BALL-CONSUMER85-EXECUTION-20261026.md。旧pack.py仅保留历史25°消费流程，不作为当前重建入口。

---

# 两球走位消费端资源

`pack.py` 仅只读最终题库，输出原样 gzip 分片与消费索引，不导入、不执行、不改动生成端脚本。

```sh
python3 scripts/two-ball-consumer/pack.py --help
```

目前资源来自 `output/two-ball-refine-full-20261025/final/`，入口读取同目录上级的 `summary.json`、`manifest.json`、`parts-index.json`。必须 `state=complete` 且 `auditPassed=true`。输出 `QiuJi/Resources/TwoBallBank/`，通过 Xcode folder reference 保留层级；全量 1,357 片，gzip 共 282,423,343 字节，不在手机启动时整库解压。

打包逐片核 SHA/大小、行ID/行内comboIndex关联、坐标时间单位、推荐数量/空值/有限数与生成角度，并用独立公式对拍全部推荐难度。报告见 `output/two-ball-practice-20261025/b1/audit.json`。

运行时最多缓存两片；题目按设置过滤并执行完整三球复核，只使用首球进指定袋、母球安全、未碰动第二球且与源线 RMS≤5毫米的路线。题面目标线保留源数据，真实击球与回放保存完整物理记录。不存在用2mm折线拼接三球动画的路径。

切库时重新打包到独立临时目录并完成审计，再替换消费资源；不得只换index或混用不同版本分片。当前题保留冻结快照，下一题校验题库指纹，版本不同需要重新开始。

## 按 App 筛选条件统计

`python3 scripts/two-ball-consumer/filter_statistics.py` 输出单项分布、1080个分类与杆法组合JSON，以及可交互组合筛选页。只读当前参数包，不运行全量物理。题数以首杆布局+第二球ID去重；推荐数按题引用计。见 `tasks/TWO-BALL-FILTER-STATISTICS-20261026.md`。
