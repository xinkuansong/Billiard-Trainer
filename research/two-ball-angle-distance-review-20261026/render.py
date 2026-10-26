"""Research-only angle/distance calibration; never writes app or bank files."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json
import math

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/two-ball-angle-distance-review-20261026'
SOURCE = ROOT / 'output/two-ball-comfort-angle-review-v2-20261025/data.json'
spec = importlib.util.spec_from_file_location('previous_angle', ROOT / 'research/two-ball-comfort-angle-review-20261025/render.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
b = prior.b
ANGLES = [0, 10, 15, 20, 25, 35, 50]
POLICY = dict(version='angle-distance-experiment-r1', referenceD1CM=65, referenceD2CM=65,
              distanceExponent=0.5, minimumScale=0.6, maximumScale=2.5,
              plateauDegrees=15, decayDegrees=30, approved=False,
              formula='k=clip(sqrt((d1/65)*(d2/65)),0.6,2.5); theta0=15/k; sigma=30/k; A=100*exp(-(max(abs(theta)-theta0,0)/sigma)^2)',
              scope='angle component only; not full potting difficulty or total comfort')


def old_score(angle):
    return 100 * math.exp(-(max(abs(angle)-15, 0)/30)**2)


def score(angle, d1, d2):
    k = min(2.5, max(0.6, math.sqrt(d1*d2)/0.65))
    plateau, width = 15/k, 30/k
    return 100*math.exp(-(max(abs(angle)-plateau, 0)/width)**2), k, plateau, width


def enrich(q):
    q = copy.deepcopy(q)
    d2 = math.dist(q['ball'], b.ANCHORS[q['pocket']])
    value, k, plateau, width = score(q['angle'], q['distance'], d2)
    q.update(objectPocketDistance=d2, baselineScore=old_score(q['angle']), trialScore=value,
             scale=k, plateau=plateau, decay=width)
    return q


def draw(ax, q, label):
    prior.draw(ax, q, label)
    ax.set_title(f'{label}  |  {q["angle"]:.0f}°  |  旧 {q["baselineScore"]:.1f} → 试验 {q["trialScore"]:.1f}\n'
                 f'母→目标 {q["distance"]*100:.0f} cm   目标→袋 {q["objectPocketDistance"]*100:.0f} cm',
                 fontsize=13, color='#183e31', loc='left', pad=10)


def finish(fig, title, filename, subtitle):
    fig.suptitle(title, fontsize=23, x=.04, ha='left', y=.98)
    fig.text(.04, .94, subtitle, fontsize=12, color='#365b48')
    fig.text(.04, .018, 'C 白色母球 · B 蓝色目标球 · 蓝线至假想球 · 橙虚线至目标袋。仅角度分；新系数待校准，非成功率。', fontsize=11)
    fig.savefig(OUT/filename, dpi=125)
    b.plt.close(fig)


def verify(rows, old_data):
    from decimal import Decimal, localcontext
    errors = []
    for q in rows:
        cue, ball = b.np.array(q['cue']), b.np.array(q['ball'])
        target = b.ANCHORS[q['pocket']]
        normal = (target-ball)/b.np.linalg.norm(target-ball)
        ghost = ball-2*b.R*normal
        aim = ghost-cue
        cut = math.degrees(math.acos(float(b.np.clip(b.np.dot(aim, normal)/b.np.linalg.norm(aim), -1, 1))))
        assert abs(cut-q['angle']) < 2e-6
        assert abs(math.dist(cue, ball)-q['distance']) < 1e-10
        assert abs(math.dist(ball, target)-q['objectPocketDistance']) < 1e-10
        assert abs(math.dist(ghost, ball)-2*b.R) < 1e-10
        for point in [cue, ball]:
            assert abs(point[0]) <= b.HX-b.R+1e-10 and abs(point[1]) <= b.HZ-b.R+1e-10
        assert math.dist(cue, ball) >= 2*b.R
        with localcontext() as ctx:
            ctx.prec = 45
            d1, d2, angle = map(lambda v: Decimal(str(v)), [q['distance'], q['objectPocketDistance'], q['angle']])
            k = min(Decimal('2.5'), max(Decimal('.6'), (d1*d2).sqrt()/Decimal('.65')))
            # Algebraically independent evaluation without theta0/sigma divisions.
            z = max(k*abs(angle)-Decimal(15), Decimal(0))/Decimal(30)
            expected = float(Decimal(100)*(-z*z).exp())
        errors.append(abs(expected-q['trialScore']))
        assert abs(expected-q['trialScore']) < 1e-10
        assert score(-q['angle'], q['distance'], q['objectPocketDistance'])[0] == q['trialScore']
    for d1 in [.15,.3,.5,.65,.9,1.2,1.8,2.2]:
        for d2 in [.15,.3,.5,.65,.9,1.2,1.8,2.2]:
            values = [score(a, d1, d2)[0] for a in range(90)]
            assert all(x >= y-1e-10 for x,y in zip(values,values[1:]))
            _,_,plateau,_ = score(0,d1,d2)
            assert abs(score(plateau-1e-7,d1,d2)[0]-score(plateau+1e-7,d1,d2)[0]) < 1e-9
            for a in [0,10,15,20,25,35,50]:
                assert score(a,d1+.01,d2)[0] <= score(a,d1,d2)[0]+1e-10
                assert score(a,d1,d2+.01)[0] <= score(a,d1,d2)[0]+1e-10
    for a in range(90):
        assert abs(score(a,.65,.65)[0]-old_score(a)) < 1e-10
    for group in old_data['groups']:
        for q in group['rows']:
            assert abs(old_score(q['angle'])-q['newAngleScore']) < 1e-9
    return dict(scenarioCount=len(rows), geometry=True, independentDecimalScore=True,
                maxScoreError=max(errors), leftRightScoreSymmetry=True,
                angleAndDistanceMonotonicity=True, continuousPlateau=True,
                referenceMatchesOldCurve=True, old36ScoresMatched=True,
                physicalPotValidation=False, playerCalibration=False)


def main():
    OUT.mkdir(exist_ok=True)
    source_bytes = SOURCE.read_bytes()
    original = json.loads(source_bytes)
    b.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    b.plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    groups = []
    for d2, phi in [(.3,45),(.65,35),(1.2,29)]:
        n = b.np.array([math.cos(math.radians(phi)), -math.sin(math.radians(phi))])
        ball = b.ANCHORS[1]-d2*n
        for d1 in [.3,.65,1.2]:
            rows = [enrich(prior.construct(ball,1,d1,a,1)) for a in ANGLES]
            groups.append(dict(number=len(groups)+1, d1=d1, d2=d2, rows=rows))
    historical = []
    for g in original['groups']:
        historical.append(dict(number=g['number'], title=g['title'], rows=[enrich(q) for q in g['rows']]))
    all_rows = [q for g in groups+historical for q in g['rows']]
    audit = verify(all_rows, original)
    for angle in [15,25,35]:
        fig, axes = b.plt.subplots(3,3,figsize=(17,13),facecolor='#f6f8f1')
        fig.subplots_adjust(left=.04,right=.98,top=.87,bottom=.06,hspace=.34,wspace=.13)
        for ax,g in zip(axes.flat, groups):
            q = next(q for q in g['rows'] if q['requestedAngle']==angle)
            draw(ax,q,f'组{g["number"]}')
        finish(fig, f'同为 {angle}°：两段距离改变后，角度分如何变化', f'compare-{angle}.png',
               '每行固定目标球与袋口，母球距离从左到右增大；目标球袋距从上到下增大。每格是独立球形。')
    for angle in [15,25,35]:
        for g in groups:
            q = next(q for q in g['rows'] if q['requestedAngle']==angle)
            fig, ax = b.plt.subplots(figsize=(6.2,4),facecolor='#f6f8f1')
            fig.subplots_adjust(left=.04,right=.97,top=.78,bottom=.07)
            draw(ax,q,f'组{g["number"]}')
            fig.savefig(OUT/f'card-{angle}-{g["number"]}.png',dpi=140)
            b.plt.close(fig)
    for g in groups:
        fig, axes = b.plt.subplots(4,2,figsize=(13,16),facecolor='#f6f8f1')
        fig.subplots_adjust(left=.04,right=.97,top=.88,bottom=.05,hspace=.4,wspace=.15)
        for ax,q in zip(axes.flat,g['rows']):draw(ax,q,f'组{g["number"]}')
        ax = axes.flat[-1]
        xs = b.np.linspace(0,65,260)
        ax.plot(xs,[old_score(x) for x in xs],ls='--',color='#aa7852',label='旧版')
        ax.plot(xs,[score(x,g['d1'],g['d2'])[0] for x in xs],color='#187b5a',label='距离联动试验')
        ax.axvline(g['rows'][0]['plateau'],color='#187b5a',ls=':',alpha=.5)
        ax.set(xlim=(0,65),ylim=(0,105),xlabel='切角（度）',ylabel='角度分')
        ax.legend();ax.grid(alpha=.15)
        q = g['rows'][0]
        finish(fig,f'组{g["number"]} · 母→目标 {g["d1"]*100:.0f} cm / 目标→袋 {g["d2"]*100:.0f} cm',f'group-{g["number"]}.png',
               f'同组只改变切角；试验满分范围 0–{q["plateau"]:.1f}°，衰减尺度 {q["decay"]:.1f}°。旧版始终15° / 30°。')
    for g in historical:
        fig, axes = b.plt.subplots(3,2,figsize=(13,12),facecolor='#f6f8f1')
        fig.subplots_adjust(left=.04,right=.97,top=.86,bottom=.06,hspace=.38,wspace=.13)
        for j,(ax,q) in enumerate(zip(axes.flat,g['rows']),1):draw(ax,q,f'旧例{g["number"]}-{j}')
        finish(fig,f'之前的球形复评 · 组{g["number"]}',f'history-{g["number"]}.png',g['title']+'；原球位、袋口、角度均保留。')
    result = dict(policy=POLICY, sourceSHA256=hashlib.sha256(source_bytes).hexdigest(),
                  coordinates='world XZ metres; landscape +X right, +Z down, Y up',
                  geometry=dict(length=2*b.HX,width=2*b.HZ,radius=b.R,anchors=b.ANCHORS.tolist()),
                  groups=groups, historical=historical, synthetic=True, physicalValidation=False)
    (OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
    audit['sourceUnchanged'] = SOURCE.read_bytes()==source_bytes
    assert audit['sourceUnchanged']
    (OUT/'verification.json').write_text(json.dumps(audit,indent=2))
    table = ''.join(f'<tr><td>{g["number"]}</td><td>{g["d1"]*100:.0f}</td><td>{g["d2"]*100:.0f}</td><td>{g["rows"][0]["plateau"]:.1f}°</td><td>{g["rows"][0]["decay"]:.1f}°</td><td>{g["rows"][4]["baselineScore"]:.1f} → <b>{g["rows"][4]["trialScore"]:.1f}</b></td></tr>' for g in groups)
    group_sections = ''.join(f'<section id="g{g["number"]}"><h2>组{g["number"]}：母→目标 {g["d1"]*100:.0f} cm / 目标→袋 {g["d2"]*100:.0f} cm</h2><a href="group-{g["number"]}.png"><img loading="lazy" src="group-{g["number"]}.png" alt="组{g["number"]}七种切角与曲线"></a></section>' for g in groups)
    history_sections = ''.join(f'<section id="h{g["number"]}"><h2>原图册组{g["number"]}：{g["title"]}</h2><a href="history-{g["number"]}.png"><img loading="lazy" src="history-{g["number"]}.png" alt="原图册组{g["number"]}复评"></a></section>' for g in historical)
    nav = ''.join(f'<a href="#g{g["number"]}">组{g["number"]}</a>' for g in groups)
    mobile_parts = []
    for g in groups:
        values = {a:next(q['trialScore'] for q in g['rows'] if q['requestedAngle']==a) for a in [15,25,35]}
        attrs = ' '.join(f'data-score{a}="{values[a]:.1f}"' for a in [15,25,35])
        mobile_parts.append(f'<a href="#g{g["number"]}"><p class="cardcaption"><b>组{g["number"]} · 母→目标{g["d1"]*100:.0f}cm / 目标→袋{g["d2"]*100:.0f}cm</b><br><span class="cardscore" {attrs}>25°：旧89.5 → 试验{values[25]:.1f}</span></p><img class="overviewcard" data-group="{g["number"]}" src="card-25-{g["number"]}.png" alt="组{g["number"]}两段距离评分对照"></a>')
    mobile = '<div class="overviewmobile">'+''.join(mobile_parts)+'</div>'

    html = '''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>角度分：两段距离新旧对照</title><style>body{margin:0;background:#f3f6ee;color:#203e30;font:17px system-ui;line-height:1.65}header,main,footer{max-width:1280px;margin:auto;padding:24px}header{background:#e2ecdf}h1{line-height:1.3}nav{position:sticky;top:0;background:#fffdf4f5;padding:12px;display:flex;gap:16px;flex-wrap:wrap;justify-content:center;z-index:2}a{color:#1c6c52}img{display:block;width:100%;height:auto}section{scroll-margin-top:110px;margin:28px 0}.note{padding:16px;background:#fff7de;border-left:4px solid #be8b3d}select{font:inherit;padding:8px}table{width:100%;border-collapse:collapse;background:white}td,th{padding:10px;border:1px solid #d2dccb;text-align:center}.scroll{overflow:auto}code{overflow-wrap:anywhere}.overviewmobile{display:none}@media(max-width:600px){.overviewdesktop{display:none}.overviewmobile{display:block}.overviewmobile a{display:block;margin:24px -16px;text-decoration:none}.cardcaption{margin:0 16px;font-size:16px}}</style><header><h1>两段距离，怎样改变舒服的切角范围？</h1><p>9种距离组合 × 7个切角，另复评之前36个球形，共99例。只比较角度项，不计算总分，不修改App或题库。</p><p class="note"><b>新公式为待校准试验r1。</b>65/65厘米是本轮临时参考点，不是之前确认的标准。短距放宽、长距收窄；相同距离下，舒服区内仍同分。直球始终100分，因此本项不能单独代表整杆难度。</p></header><nav><a href="#overview">同角度对照</a><a href="#formula">参数</a>'''+nav+'''<a href="#h1">原36例</a></nav><main><section id="overview"><h2>先看同角度、不同距离</h2><label for="angle">切角：</label><select id="angle"><option value="25">25°</option><option value="15">15°</option><option value="35">35°</option></select><p>每行固定目标球位置和袋口，母球距离从左向右增大；三行袋距依次为30、65、120厘米。各行入袋方向不同，方向不参与本轮评分。</p><a class="overviewdesktop" id="overviewLink" href="compare-25.png"><img id="overviewImage" src="compare-25.png" alt="25度九种距离组合"></a>'''+mobile+'''</section><section id="formula"><h2>试验参数与边界</h2><p>距离单位厘米。<br><code>k = clip(√[(d1/65)×(d2/65)], 0.6, 2.5)<br>舒服角上限 θ0 = 15° / k；衰减尺度 σ = 30° / k<br>试验角度分 = 100 exp[−(max(|θ|−θ0,0)/σ)²]<br>旧版 = 100 exp[−(max(|θ|−15°,0)/30°)²]</code></p><p>两段距离暂时等权，用乘积的平方根形成平滑尺度；上下限避免极端距离把范围无限放大或缩小。这是可解释的校准候选，不是实测物理公式。30/120与120/30会同分，值得重点判断这种补偿是否合理。</p><div class="scroll"><table><tr><th>组</th><th>母→目标 cm</th><th>目标→袋 cm</th><th>试验满分上限</th><th>衰减尺度</th><th>25°旧→试验</th></tr>'''+table+'''</table></div><p>图形沿用旧图册的几何与袋口生成瞄点，不把生成瞄点当作所有真实打法的最佳入袋点。球距为球心距离，切角按母球至假想球方向计算。球位在台内、不重叠已核验；未做物理入袋验证，袋型、入袋方向、速度、塞及出杆空间均未计入这一项。</p></section>'''+group_sections+history_sections+'''</main><footer><a href="data.json">全部坐标和分数</a> · <a href="verification.json">计算核验</a> · <a href="README.md">说明</a></footer><script>const sel=document.getElementById('angle');sel.addEventListener('change',()=>{const a=sel.value;document.getElementById('overviewImage').src='compare-'+a+'.png';document.getElementById('overviewImage').alt=a+'度九种距离组合';document.getElementById('overviewLink').href='compare-'+a+'.png';document.querySelectorAll('.overviewcard').forEach(img=>{img.src='card-'+a+'-'+img.dataset.group+'.png';});document.querySelectorAll('.cardscore').forEach(el=>{el.textContent=a+'°：旧'+({15:'100.0',25:'89.5',35:'64.1'})[a]+' → 试验'+el.dataset['score'+a];});});</script></html>'''
    (OUT/'index.html').write_text(html)
    print(json.dumps(audit))
    print(json.dumps([dict(group=g['number'],d1=g['d1'],d2=g['d2'],plateau=g['rows'][0]['plateau'],score25=g['rows'][4]['trialScore']) for g in groups]))


if __name__ == '__main__':
    main()
