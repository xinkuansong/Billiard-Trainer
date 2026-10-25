"""Frozen 36-layout comparison of angle-only curves. No question-bank mutation."""
from pathlib import Path
import copy,hashlib,importlib.util,json,math,shutil
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('prior',ROOT/'research/two-ball-comfort-angle-review-20261025/render.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
b=a.b
SOURCE=ROOT/'output/two-ball-comfort-angle-review-20261025/data.json'
OUT=ROOT/'output/two-ball-comfort-angle-review-v2-20261025'

def score(angle):return 100*math.exp(-(max(abs(angle)-15,0)/30)**2)

def main():
    OUT.mkdir(exist_ok=True)
    sourceBytes=SOURCE.read_bytes();original=json.loads(sourceBytes);data=copy.deepcopy(original)
    b.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');b.plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    count=0;sections=[]
    for g in data['groups']:
        number=g['number'];title=g['title'];rows=g['rows']
        fig,axes=b.plt.subplots(3,2,figsize=(14,12),facecolor='#f6f8f1');fig.subplots_adjust(left=.04,right=.97,top=.84,bottom=.05,hspace=.38,wspace=.12)
        for j,(ax,q) in enumerate(zip(axes.flat,rows)):
            actual=b.evaluate(q['cue'],q['ball'],q['pocket'])
            assert abs(actual['angle']-q['angle'])<1e-9 and abs(actual['distance']-q['distance'])<1e-12
            assert abs(a.score(actual['angle'])-q['angleScore'])<1e-9
            q['newAngleScore']=score(actual['angle']);assert q['newAngleScore']>=q['angleScore']-1e-10
            assert score(-actual['angle'])==q['newAngleScore']
            a.draw(ax,q,f'{number}-{j+1}')
            ax.set_title(f'{number}-{j+1} · 切角 {q["angle"]:.0f}° · 旧 {q["angleScore"]:.1f} → 新 {q["newAngleScore"]:.1f}\n球距 {q["distance"]*100:.0f}cm · {b.NAMES[q["pocket"]]}',fontsize=12,color='#2b513e',loc='left',pad=8)
            count+=1
        fig.suptitle(f'角度分新旧对照 · 组{number} · {title}',fontsize=19,y=.975)
        fig.text(.04,.93,'蓝线：母球至假想球的瞄准方向；橙虚线：目标球入袋方向；虚圈：假想球。',fontsize=11,color='#365b48')
        fig.text(.04,.905,'球位与切角保持不变。旧：10°满分/18°尺度；新：15°满分/30°尺度。',fontsize=11,color='#365b48')
        fig.text(.04,.018,'仅比较角度分，不混入球距/空间分、不筛选题库。几何校准图未验证物理入袋，分数不是成功率。',fontsize=10,color='#526859')
        fn=f'group-{number}.png';fig.savefig(OUT/fn,dpi=130);b.plt.close(fig)
        trs=''.join(f'<tr><td>{number}-{i+1}</td><td>{q["angle"]:.1f}°</td><td>{q["angleScore"]:.1f}</td><td class="new">{q["newAngleScore"]:.1f}</td><td>+{q["newAngleScore"]-q["angleScore"]:.1f}</td><td>{q["distance"]*100:.0f}cm</td></tr>' for i,q in enumerate(rows))
        sections.append(f'<section id="group-{number}"><h2>组{number} · {title}</h2><a href="{fn}"><img src="{fn}" alt="{title}的六种切角与新旧角度分"></a><div class="scroll"><table><tr><th>编号</th><th>切角</th><th>旧分</th><th>新分</th><th>变化</th><th>球距（不计分）</th></tr>{trs}</table></div></section>')
    assert count==36
    for g,h in zip(original['groups'],data['groups']):
        for p,q in zip(g['rows'],h['rows']):assert {k:q[k] for k in p}==p
    for angle in range(16):assert score(angle)==100
    xs=b.np.linspace(0,89.99,1000);ys=[score(x) for x in xs];assert all(p>=q for p,q in zip(ys,ys[1:]))
    assert abs(score(15-1e-6)-score(15+1e-6))<1e-8
    fig,ax=b.plt.subplots(figsize=(11,4.5),facecolor='#f6f8f1')
    ax.plot(xs,[a.score(x) for x in xs],color='#aa7852',ls='--',lw=2,label='旧：10°满分，18°尺度')
    ax.plot(xs,ys,color='#187b5a',lw=2.5,label='新：15°满分，30°尺度')
    ax.axvspan(0,15,color='#dce9d6',alpha=.6);ax.axvline(15,color='#6b9678',lw=.8)
    ticks=[0,5,10,15,18,22,25,30,35,40,50,60]
    ax.scatter(ticks,[score(x) for x in ticks],s=22,color='#187b5a')
    ax.set(xlim=(0,65),ylim=(0,105),xlabel='切角（度）',ylabel='角度分');ax.grid(alpha=.2);ax.legend();fig.tight_layout();fig.savefig(OUT/'curve.png',dpi=140);b.plt.close(fig)
    curveRows=''.join(f'<tr><td>{x}°</td><td>{a.score(x):.1f}</td><td class="new">{score(x):.1f}</td></tr>' for x in ticks)
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>角度分v2 · 15度平台与平缓下降</title><style>body{margin:0;background:#f2f5ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1350px;margin:auto;padding:24px}header{background:#e3eddf}p{line-height:1.8}nav{position:sticky;top:0;background:#fffef4f5;padding:15px;display:flex;flex-wrap:wrap;gap:20px;justify-content:center;z-index:5}a{color:#23674f}section{scroll-margin-top:90px;padding:24px 0;border-bottom:1px solid #ccd6c4}img{width:100%}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;border:1px solid #d7e0ce;text-align:center}.new{color:#167452;font-weight:bold}.curve{display:grid;grid-template-columns:3fr 1fr;gap:20px}@media(max-width:700px){.curve{display:block}}</style><header><h1>角度分新旧对照：15度以内满分</h1><p>原6组36个球形的球位、目标袋、切角与旧分保持不变，仅新增角度分。球距与空间分不参与，本轮不计算总分、不筛选或修改题库。</p><p><b>新版：100×exp[−(max(|切角|−15°,0)/30°)²]</b><br>旧版：100×exp[−(max(|切角|−10°,0)/18°)²]。</p><p>0～15°同为100分，之后按30°尺度平滑下降。15°是满分平台边界，不是筛选线；左右同角同分，平台内不奖励更直。曲线表额外显示15°等参考点，36个球形仍保留原来的0/10/18/25/35/50°。</p><p>本页是几何评分校准，未验证物理入袋，分数不是进球概率。球距放缓v2和空间v3的选定方案不变。</p></header><nav><a href="#curve">新旧曲线</a>'''+''.join(f'<a href="#group-{i}">组{i}</a>' for i in range(1,7))+'</nav><main><section id="curve"><h2>新旧曲线与典型分数</h2><div class="curve"><img src="curve.png" alt="旧角度曲线与15度平台新版曲线"><table><tr><th>切角</th><th>旧分</th><th>新分</th></tr>'+curveRows+'</table></div></section>'+''.join(sections)+'</main><footer><a href="data.json">全部球位与新旧分数</a></footer></html>')
    data.update(schema='angle-score-controlled-review-v2',sourceSHA256=hashlib.sha256(sourceBytes).hexdigest(),oldAnglePolicy=original['anglePolicy'],anglePolicy=dict(plateauDegrees=15,decayScaleDegrees=30,filterApplied=False))
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))
    verification=dict(scenarios=count,allOriginalFieldsPreserved=True,oldScoresAndCutsRecomputed=True,leftRightScoreSymmetric=True,plateau0to15Passed=True,monotonicPassed=True,plateauBoundaryContinuous=True,newNotBelowOld=True,sourceSHA256=data['sourceSHA256'])
    assert SOURCE.read_bytes()==sourceBytes
    (OUT/'verification.json').write_text(json.dumps(verification,indent=2))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-angle-review-v2';served.mkdir(exist_ok=True)
    for f in OUT.iterdir():
        if f.is_file():shutil.copy2(f,served/f.name)
    print(json.dumps({x:round(score(x),1) for x in ticks}));print('All 36 original records preserved; old/new checks passed')
if __name__=='__main__':main()
