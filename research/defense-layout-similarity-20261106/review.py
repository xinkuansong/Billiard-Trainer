"""Draw boundary pairs on the shared CAD table and report source-role counts."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / Path(__file__).resolve().parent.name
sys.path.insert(0, str(ROOT / "research/defense-threshold-comparison-20261105"))
import geometric_table as table
import matplotlib.pyplot as plt
from matplotlib.patches import Circle

examples = json.loads((OUT / "examples.json").read_text())
counts = json.loads((OUT / "counts.json").read_text())
thresholds = sorted({row["cm"] for row in counts})
fig, panels = plt.subplots(2, len(thresholds), figsize=(6.5 * len(thresholds), 8))
fig.patch.set_facecolor("#f4f5ef")
fig.subplots_adjust(left=.035, right=.965, top=.85, bottom=.10, wspace=.05, hspace=.28)
for pair in examples:
    three = pair["kind"] == "three"
    ax = panels[int(three), thresholds.index(pair["cm"])]
    table.table(ax)
    balls = [0, 1, 9, 8] if three else [0, 8, 9]
    title = "三球 · 我方 1 / 对方 9 / 静止 8" if three else "两球 · 我方 8 / 对方 9"
    ax.set_title(f'{pair["cm"]} cm   {title}', loc="left", color="#163d36", fontsize=13)
    for a, b, number in zip(pair["a"], pair["b"], balls):
        ax.plot([a[0], b[0]], [a[1], b[1]], color="#e4f9ff", lw=1.2, zorder=6)
        table.ball(ax, a, number)
        ax.add_patch(Circle(b, table.R, fill=False, edgecolor="#a7f2ff", lw=1.8, zorder=13))
    label = "   ".join(f'{"母" if n == 0 else n} {d:.1f}' for n,d in zip(balls,pair["distances"]))
    ax.text(.01,-.045,"各球位移（cm）  "+label, transform=ax.transAxes, color="#24483d", fontsize=10)
fig.text(.035,.945,"同一球形允许相差多少？",color="#163d36",fontsize=22)
fig.text(.035,.89,"实心球是代表题，浅蓝圈是另一题的同号球。连线表示两题之间的球位差。",fontsize=12,color="#355e52")
fig.savefig(OUT / "boundary-comparison.png", dpi=145, facecolor=fig.get_facecolor())
plt.close(fig)
lines = ["# 防守球形 10、15 与 20 cm 相似度比较", "",
         "输入为原始库全部 1,331,922 条球权组合，尚未选定区域潜力的淘汰分数。按同球权、同朝向、同角色计算各球心的欧氏距离。每颗球都在半径内才进入候选。按原题 ID 顺序选择首个尚未入组的真实球形作为代表，成员直接匹配代表。结果与选代表的顺序有关。", "",
         "| 球权 | 原始组合 | 10 cm 仅距离 | 15 cm 仅距离 | 20 cm 仅距离 | 10 cm 加几何条件 | 15 cm 加几何条件 | 20 cm 加几何条件 |",
         "|---|---:|---:|---:|---:|"]
for k,label in [("two_black","我方8／对方9"),("two_own","我方1／对方8"),("three","我方1／对方9／静止8")]:
    values = {(x["cm"],x["mode"]): x for x in counts if x["kind"] == k}
    row = [values[10,"distance"]["total"]] + [values[cm,mode]["retained"] for mode in ("distance","guarded") for cm in thresholds]
    lines.append("|"+label+"|"+"|".join(f"{n:,}" for n in row)+"|")
lines += ["","几何条件按每颗球与六段主库的球面间隙（≤1 cm）保留靠库状态，并区分六个袋心方向的粗略直进机会。每个方向检查切球侧、母球至假想球和对方球至袋心的其他球干涉。实际袋口有宽度，精确边界仍需生产管道复核。这三档用来比较初始球形的几何相似程度，未按轨迹或分数淘汰原题。", "",
          "![六对阈值边界样本](boundary-comparison.png)", "",
          "图取各档最大单球位移达到阈值 99% 的候选，再从中选各球位移总和最大的一对。所有来源 ID 和原始坐标见 examples.json。各模式的 npz 代表索引与同球权的 ids.txt.gz 逐行对应（从 0 开始）。"]
(OUT / "README.md").write_text("\n".join(lines)+"\n")
