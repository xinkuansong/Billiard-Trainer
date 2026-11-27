# λ=5 多因素对照

cases.json保存52个终态及构造意图；main.swift对每个终态评估六袋，输出指定袋和整体分。本轮无防守物理击球生成。

运行：将cases.json和weights.json复制到output/defense-lambda5-factors-20261106后，使用python3 scripts/local_test_lifecycle.py run --task defense-lambda5-factors-20261106 -- python3 research/defense-lambda5-factors-20261106/run.py。

出图：/tmp/qiuji-defense-gallery-20261106/bin/python research/defense-lambda5-factors-20261106/render.py。原生修改仅限独立源快照，公式与前轮六权重对照同源。main导出全部袋口候选及无路线原因；estimated/global/fullblock分支保持原来语义。

原生effect.scoringVersion是生产DTO版本，实验身份是lambda=5，不冒充新发布评分。静态终态评分不代表实际击球可达或真实进球概率。原始未知窗口/截图近似标记保留。
