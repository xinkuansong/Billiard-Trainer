# 防守容错角权重实验

采用上一轮15个固定终态，候选λ=0、0.1、0.25、1、2、5，另算原始生产公式。每档从原生生产几何可达候选重选路线/袋口；只在独立源码快照中改评分，不改App或恢复全量。

运行：`python3 scripts/local_test_lifecycle.py run --task defense-angle-weight-six-20261106 -- python3 research/defense-angle-weight-20261106/run.py`。
运行前将本目录cases.json和weights.json复制至output同名目录。weights.json含−1作为原始生产基线，其余按5、2、1、0.25、0.1、0降序，主程序验证降权后分数不降低。独立计算后绘图：`/tmp/qiuji-defense-gallery-20261106/bin/python research/defense-angle-weight-20261106/render.py`。

原始effect.scoringVersion未替换，沿用生产结构版本；实际实验公式必须看variants.lambda，不能当作已经发布的新版本。无路线见证的乐观上界估计不伪造切角，保留旧保守值；独立审计要求本批没有进入该分支。

首次未包含2/5的结果保存在output同名目录first-four-weights；6档完整结果为根目录results.json。静态终态评分不证明防守击球可达，不代表实战进球率。全量继续暂停。
