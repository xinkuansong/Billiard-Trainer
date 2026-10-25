"""Read-only aggregation of the frozen five-question comfort preview."""
from pathlib import Path
import copy
import hashlib
import html
import json
import math
import shutil

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon
from matplotlib.font_manager import fontManager

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/two-ball-comfort-heatmap-five-20261025/data.json'
OUT = ROOT / 'output/two-ball-comfort-score-five-20261025'
NAMES = ['左上角袋', '右上角袋', '左下角袋', '右下角袋', '上中袋', '下中袋']
KEYS = ['distanceScore', 'spaceScore', 'angleScore']
COLORS = ['#1683ac', '#e78b24', '#8365bf', '#258c67', '#bf5578']


def comfort_total(distance, space, angle):
    """Equal-weight geometric mean, 0..100; not a pot probability."""
    values = [float(distance), float(space), float(angle)]
    if any(not math.isfinite(v) or not 0 <= v <= 100 for v in values):
        raise ValueError('Comfort components must be finite and within 0..100')
    if min(values) == 0:
        return 0.0
    return min(100.0, math.exp(sum(math.log(v) for v in values) / 3))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    raw = SOURCE.read_bytes()
    source = json.loads(raw)
    for path, expected in source['sourceSHA256'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected
    result = copy.deepcopy(source)
    result['schema'] = 'comfort-total-preview-v1'
    result['componentSourceSHA256'] = hashlib.sha256(raw).hexdigest()
    result['policy']['aggregateScore'] = {
        'formula': '(distanceScore * spaceScore * angleScore) ** (1/3)',
        'weights': [1/3, 1/3, 1/3],
        'ranking': 'descending unrounded total within each sample, original rank breaks exact ties',
        'experimental': True,
        'firstShotDifficultyIncluded': False,
        'newPhysicalValidation': False,
    }
    assert abs(comfort_total(100, 100, 100)-100) < 1e-10
    assert comfort_total(100, 0, 100) == 0
    assert abs(comfort_total(50, 50, 50)-50) < 1e-10
    assert comfort_total(100, 10, 100) < 70  # arithmetic mean would be 70
    for v in range(100):
        assert comfort_total(70, v, 80) < comfort_total(70, v+1, 80)
    for invalid in [float('nan'), float('inf'), -1, 101]:
        try:
            comfort_total(invalid, 50, 50)
        except ValueError:
            pass
        else:
            raise AssertionError('invalid component accepted')

    fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family': 'Arial Unicode MS', 'axes.unicode_minus': False})
    g = source['geometry']; hx = g['length']/2; hz = g['width']/2; radius = g['radius']
    sections = []
    for sample, original in zip(result['samples'], source['samples']):
        for row in sample['routes']:
            assert row['valid'], 'Do not rank a geometrically invalid point as comfortable'
            row['totalScore'] = comfort_total(*(row[k] for k in KEYS))
        ordered = sorted(sample['routes'], key=lambda q: (-q['totalScore'], q['rank']))
        for rank, row in enumerate(ordered, 1):
            row['comfortRank'] = rank
        for row, old in zip(sample['routes'], original['routes']):
            assert all(row[k] == v for k, v in old.items())
        sample['comfortOrderOriginalRanks'] = [q['rank'] for q in ordered]

        fig = plt.figure(figsize=(13, 10), facecolor='#f6f8f1')
        ax = fig.add_axes([.04, .36, .92, .55]); ax.set_aspect('equal'); ax.axis('off')
        ax.add_patch(Rectangle((-hx-.04, -hz-.04), 2*hx+.08, 2*hz+.08, color='#355e52'))
        ax.add_patch(Rectangle((-hx, -hz), 2*hx, 2*hz, color='#dce9d6'))
        for i, pocket in enumerate(g['pockets']):
            c = pocket['center']; pos = (c['x'], c['z'])
            ax.add_patch(Polygon([(v['x'], v['z']) for v in pocket['lip']], color='#183c33'))
            ax.add_patch(Circle(pos, pocket['radius'], color='#183c33'))
            if i in {q['pocket'] for q in ordered}:
                ax.add_patch(Circle(pos, .066, fill=False, ec='#1683ac', lw=2))
        for pos, color, label in [(sample['board']['cue'], 'white', 'C'),
                                  (sample['board']['object'], '#edbf55', 'A'),
                                  (sample['position'], '#1683ac', 'B')]:
            ax.add_patch(Circle(pos, radius, fc=color, ec='#36594a', zorder=5))
            ax.text(*pos, label, ha='center', va='center', fontsize=10, zorder=6)
        # Label positions are presentation-only; all plotted stops are source coordinates.
        by_z = sorted(ordered, key=lambda q: q['stop'][1])
        for index, row in enumerate(by_z):
            color = COLORS[row['rank']-1]
            x, z = row['stop']; label_z = -hz+.10+index*(2*hz-.20)/max(1, len(by_z)-1)
            label_x = .75 if x < 0 else -.75
            ax.plot(x, z, 'o', mfc='white', mec=color, ms=10, mew=2, zorder=8)
            ax.annotate(f'新{row["comfortRank"]} / 原{row["rank"]} · {row["totalScore"]:.1f}分',
                        (x, z), xytext=(label_x, label_z), ha='center', va='center',
                        fontsize=11, color=color, bbox=dict(boxstyle='round,pad=.3', fc='white', ec=color),
                        arrowprops=dict(arrowstyle='-', color=color, lw=.8), zorder=9)
        ax.set_xlim(-hx-.12, hx+.12); ax.set_ylim(hz+.12, -hz-.12)
        fig.suptitle(f'样本{sample["number"]} · B{sample["cellID"]} · 原版停点舒适度试排', fontsize=19, y=.97)
        fig.text(.05, .925, '球距 × 出杆空间 × 角度，取立方根；原版停点全部保留。蓝圈为第二杆目标袋；细线仅连接标签与停点，并非走位轨迹。', fontsize=11)
        tableax = fig.add_axes([.025, .07, .95, .25]); tableax.axis('off')
        rows = [[str(q['comfortRank']), str(q['rank']), NAMES[q['pocket']],
                 f'{q["distanceScore"]:.1f}', f'{q["spaceScore"]:.1f}', f'{q["angleScore"]:.1f}',
                 f'{q["totalScore"]:.1f}', f'{q["distance"]*100:.1f} / {q["rear"]*100:.1f} / {q["angle"]:.2f}°']
                for q in ordered]
        table = tableax.table(cellText=rows, colLabels=['新排名', '原排名', '目标袋', '球距', '空间', '角度', '总分', '球距cm / 杆后净空cm / 切角'],
                              cellLoc='center', loc='center', colWidths=[.065,.065,.13,.09,.09,.09,.09,.28])
        table.auto_set_font_size(False); table.set_fontsize(11); table.scale(1, 2)
        for (r,c), cell in table.get_celld().items():
            cell.set_edgecolor('#cfdbca')
            cell.set_facecolor('#dae6d4' if r == 0 else 'white')
            if r > 0 and c == 6: cell.set_text_props(weight='bold', color='#17533b')
        fig.text(.05, .025, '试验评价，不是进球概率；空间为平面近似。未加入第一杆力度/杆法难度，未重新验证物理入袋。', fontsize=10, color='#576b5e')
        filename = f'sample-{sample["number"]}.png'
        fig.savefig(OUT / filename, dpi=140); plt.close(fig)
        htmlrows = ''.join('<tr>'+''.join(f'<td>{html.escape(v)}</td>' for v in row)+'</tr>' for row in rows)
        sections.append(f'<section id="sample-{sample["number"]}"><h2>样本{sample["number"]} · B{sample["cellID"]}</h2>'
                        f'<p>{sample["id"]} · 组合编号按新顺序：'+', '.join(str(q['comboIndex']) for q in ordered)+'</p>'
                        f'<a href="{filename}" target="_blank"><img src="{filename}" alt="样本{sample["number"]}停点、三个分项和总分排序"></a>'
                        '<div class="table"><table><thead><tr><th>新排名</th><th>原排名</th><th>目标袋</th><th>球距</th><th>空间</th><th>角度</th><th>总分</th><th>球距cm / 杆后净空cm / 切角</th></tr></thead><tbody>'
                        +htmlrows+'</tbody></table></div></section>')
    assert sum(len(s['routes']) for s in result['samples']) == 22
    (OUT/'data.json').write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>五题原停点 · 舒适度总分试排</title>
<style>body{margin:0;background:#f1f4ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1250px;margin:auto;padding:24px}p{line-height:1.8}nav{position:sticky;top:0;background:#fffff5f5;padding:16px;display:flex;gap:20px;justify-content:center;z-index:10}a{color:#26765d}img{width:100%}section{scroll-margin-top:75px;border-bottom:1px solid #ccc;padding:20px 0}.table{overflow:auto}table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;border:1px solid #dae3d4;white-space:nowrap;text-align:center}td:nth-child(7){font-weight:bold;color:#17533b}header{background:#e4ecdE}</style>
<header><h1>五题原停点 · 舒适度总分试排</h1><p>全部22个原版停点，沿用上一版三个分项，按每题总分由高到低展示。不同袋口按各自原袋口评价；C/A仅作初始球位参考，第一球A已进袋。图中细线仅为标注引线，并非走位轨迹。原排名保留对照，不删除、不改题库、不改路线。</p>
<p><b>总分 = ∛（球距评分 × 出杆空间评分 × 角度评分）</b>，三项等权。明显短板会拉低总分，但并非一票否决。例：100/100/10 → 46.4分；三项均80 → 80分。按未舍入总分排序，完全同分沿用原排名；显示同为100.0仍可能有极小差异。</p>
<p>只评价第二杆落点舒适度，不含第一杆力度/杆法成本；空间为沿杆尾方向至矩形库线的平面近似，未含仰角、架杆或站位。本轮无新物理验证，分数不是进球概率。仍是待评阅的试验机制，无及格线。</p>
<p><a href="../comfort-heatmap-five/">对照上一版分项热力图和曲线说明</a></p></header><nav>'''
        + ''.join(f'<a href="#sample-{n}">样本{n}</a>' for n in range(1,6))
        + '</nav><main>'+''.join(sections)+'</main><footer><a href="data.json">全部分项、总分、原/新排名及来源</a></footer></html>')
    (OUT/'verification.json').write_text(json.dumps({'sourceSHA256':result['componentSourceSHA256'], 'originalFieldsUnchanged':True,
        'allSourcePartHashesPassed':True, 'sampleCount':5, 'routeCount':22, 'aggregationBoundaryAndMonotonicityPassed':True,
        'ranking':{s['number']:s['comfortOrderOriginalRanks'] for s in result['samples']}}, ensure_ascii=False, indent=2))
    served = ROOT/'output/two-ball-multi-position-top10-20261024/comfort-score-five'
    served.mkdir(exist_ok=True)
    for path in OUT.iterdir():
        if path.is_file(): shutil.copy2(path, served/path.name)
    for s in result['samples']:
        print(s['number'], [(q['rank'], round(q['totalScore'],2)) for q in sorted(s['routes'], key=lambda q:q['comfortRank'])])


if __name__ == '__main__':
    main()
