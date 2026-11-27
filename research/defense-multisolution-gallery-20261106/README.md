# 防守已找到解的轨迹图册

读取全量生成器已核验且SHA匹配的完成归档，首次运行冻结snapshot.json；后续运行重画同一个快照，不读新增题。包含所有有解题（多解及单解分开）、每题全部解，以及12组人工阅读覆盖样本。抽样仅供看图，不改变题库抽题权重或筛选。

```sh
python3 -m venv /tmp/qiuji-defense-gallery-20261106
/tmp/qiuji-defense-gallery-20261106/bin/pip install numpy matplotlib
/tmp/qiuji-defense-gallery-20261106/bin/python research/defense-multisolution-gallery-20261106/render.py
python3 research/defense-multisolution-gallery-20261106/check.py
```

输出：`output/defense-multisolution-gallery-20261106/index.html`、`selected.html`、逐题SVG/JSON/HTML、12张全部路线PNG、12张前两解PNG。当前1022题3503路线（742多解，280单解），三球与我方1号两球来自先导已完成部分。保持原坐标，不重新求解，不碰后台进程。

检查8651链接、3503条SVG及终点/颜色/实虚线、目录真实JS全部筛选和搜索。四张PNG目视检查覆盖三种球权、区域与遮挡，浏览器自动打开file协议被安全策略拒绝，未绕过；不声称浏览器或原生App交互验收。任务卡`tasks/DEFENSE-MULTISOLUTION-GALLERY-20261106.md`含TP01–36适用性。
