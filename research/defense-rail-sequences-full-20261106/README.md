# 按两颗球各自库序生成防守多解

新定义覆盖`defense-multisolution-full-20261106`：类键为母球主库顺序和本杆我方目标球主库顺序。两球事件的交错不影响类别；保留每颗球的重复碰库，空序列表示不吃库。六段物理主库0…5，不按厘米落点或球球接触拆类。

搜索保留类内参数候选，验证四探针后再按类挑低代价代表；至少两个不同库序类才可提前停止扩展，最多输出六类。评分≥80、静止球不动、无进袋、无袋角/目标球互撞/我方吃库回碰、30cm及窗口不下降条件均沿用，不借修订放宽。

旧档案以源码、资源、输入和政策其他字段一致为前提复用：保存的解已覆盖至少两类则直接按类去重；旧0/1解已经完成四层搜索时保留原结论；旧多解变单类者补搜，因为可能此前提前停止。原记录保留，新结果含sourceIdentity和sourceArchive，不伪称重跑了已复用的物理。

```sh
python3 research/defense-rail-sequences-full-20261106/test_sequences.py
python3 scripts/local_test_lifecycle.py run --task defense-rail-sequences-full-20261106 -- python3 research/defense-rail-sequences-full-20261106/run.py
```

已经启动，不要重复执行。中断使用同目录resume.py复用冻结二进制。status.json新增initialCompleted/newlyCompleted，估算新运行吞吐须排除复用数。独立候选包schema为`defense-rail-sequences-candidate-v2`，不替换App。
