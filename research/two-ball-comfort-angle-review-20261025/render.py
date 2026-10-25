"""Angle-only review: geometric ghost-ball cuts, no corpus or physics mutation."""
from pathlib import Path
import importlib.util,json,math,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('spacebase',ROOT/'research/two-ball-comfort-space-review-20261025/render.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
OUT=ROOT/'output/two-ball-comfort-angle-review-20261025'
SOURCE=ROOT/'output/two-ball-comfort-heatmap-five-20261025/data.json'
D=json.loads(SOURCE.read_text());PLATEAU=D['policy']['anglePlateauDegrees'];SCALE=D['policy']['angleDecayScaleDegrees']
ANGLES=[0,10,18,25,35,50]

def score(angle):return 100*math.exp(-(max(abs(angle)-PLATEAU,0)/SCALE)**2)

def construct(ball,pocket,distance,angle,sign):
    ball=b.np.array(ball);n=b.ANCHORS[pocket]-ball;n/=b.np.linalg.norm(n)
    theta=math.radians(angle*sign)
    aim=b.np.array([math.cos(theta)*n[0]-math.sin(theta)*n[1],math.sin(theta)*n[0]+math.cos(theta)*n[1]])
    ghost=ball-2*b.R*n
    length=-2*b.R*math.cos(theta)+math.sqrt(distance**2-(2*b.R*math.sin(theta))**2)
    cue=ghost-length*aim
    row=b.evaluate(cue,ball,pocket)
    assert abs(row['distance']-distance)<1e-10 and abs(row['angle']-angle)<1e-8
    for point in [cue,ball]:assert abs(point[0])<=b.HX-b.R+1e-12 and abs(point[1])<=b.HZ-b.R+1e-12,(point,angle)
    row.update(angleScore=score(row['angle']),requestedAngle=angle,signedAngle=angle*sign,ghost=ghost.tolist(),potDirection=n.tolist())
    return row

def draw(ax,q,ident):
    ax.set_aspect('equal');ax.axis('off')
    ax.add_patch(b.Rectangle((-b.HX-.04,-b.HZ-.04),2*b.HX+.08,2*b.HZ+.08,color='#355e52'))
    ax.add_patch(b.Rectangle((-b.HX,-b.HZ),2*b.HX,2*b.HZ,color='#dce9d6'))
    for i,p in enumerate(b.G['pockets']):
        c=p['center'];pos=(c['x'],c['z']);ax.add_patch(b.Circle(pos,p['radius'],color='#183c33'))
        if i==q['pocket']:ax.add_patch(b.Circle(pos,.07,fill=False,ec='#d99b24',lw=2))
    cue=b.np.array(q['cue']);ball=b.np.array(q['ball']);ghost=b.np.array(q['ghost']);target=b.ANCHORS[q['pocket']]
    ax.plot([ball[0],target[0]],[ball[1],target[1]],'--',color='#ce9130',lw=1.3)
    ax.annotate('',xy=ghost,xytext=cue,arrowprops=dict(arrowstyle='->',color='#1683ac',lw=2))
    n=b.np.array(q['potDirection']);end=ghost+n*.16
    ax.annotate('',xy=end,xytext=ghost,arrowprops=dict(arrowstyle='->',color='#ce9130',lw=1.3))
    ax.add_patch(b.Circle(ghost,b.R,fill=False,ec='#799887',ls=':',lw=1))
    for p,color,label in [(cue,'white','C'),(ball,'#1683ac','B')]:
        ax.add_patch(b.Circle(p,b.R,fc=color,ec='#325c49',zorder=5));ax.text(p[0],p[1]-.07,label,ha='center',fontsize=10,color='#24523f')
    ax.set_xlim(-b.HX-.12,b.HX+.12);ax.set_ylim(b.HZ+.12,-b.HZ-.12)
    ax.set_title(f'{ident} · 切角 {q["angle"]:.0f}° · 角度分 {q["angleScore"]:.1f}\n球距 {q["distance"]*100:.0f}cm · {b.NAMES[q["pocket"]]}',fontsize=12,color='#2b513e',loc='left',pad=8)

def main():
    OUT.mkdir(exist_ok=True)
    b.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');b.plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    originals=0
    for sample in D['samples']:
        for q in sample['routes']:
            actual=b.evaluate(q['stop'],sample['position'],q['pocket'])['angle']
            assert abs(score(actual)-q['angleScore'])<1e-8;originals+=1
    configs=[('台中目标球，上中袋，一侧切角',[0,0],4,.5,1),
             ('同一目标球和袋口，反侧切角',[0,0],4,.5,-1),
             ('左半台目标球，左上角袋',[-.5,-.2],0,.5,1),
             ('右半台目标球，右下角袋',[.5,.2],3,.5,1),
             ('靠右上方目标球，较近球距',[.65,-.25],1,.3,-1),
             ('左半台目标球，较远球距',[-.4,-.15],0,.7,1)]
    groups=[];sections=[]
    for index,(title,ball,pocket,distance,sign) in enumerate(configs,1):
        rows=[construct(ball,pocket,distance,a,sign) for a in ANGLES]
        fig,axes=b.plt.subplots(3,2,figsize=(14,12),facecolor='#f6f8f1');fig.subplots_adjust(left=.04,right=.97,top=.84,bottom=.05,hspace=.38,wspace=.12)
        for j,(ax,q) in enumerate(zip(axes.flat,rows)):draw(ax,q,f'{index}-{j+1}')
        fig.suptitle(f'单独评价角度分 · 组{index} · {title}',fontsize=19,y=.975)
        fig.text(.04,.93,'蓝线：母球至假想球的瞄准方向；橙虚线：目标球入袋方向；虚圈：假想球。',fontsize=11,color='#365b48')
        fig.text(.04,.905,'同组目标球/袋口/球距固定，只改变切角；0～10°均100分，之后平滑下降。',fontsize=11,color='#365b48')
        fig.text(.04,.018,'角度分独立展示，不混入球距或空间分，不作筛选。18°仅参考；几何合成例未验证物理入袋，非进球概率。',fontsize=10,color='#526859')
        filename=f'group-{index}.png';fig.savefig(OUT/filename,dpi=130);b.plt.close(fig)
        tables=''.join(f'<tr><td>{index}-{j+1}</td><td>{q["angle"]:.1f}°</td><td><b>{q["angleScore"]:.1f}</b></td><td>{q["distance"]*100:.1f}</td><td>{q["gap"]*100:.1f}</td></tr>' for j,q in enumerate(rows))
        sections.append(f'<section id="group-{index}"><h2>组{index} · {title}</h2><a href="{filename}"><img src="{filename}" alt="{title}的六种切角及评分"></a><div class="scroll"><table><tr><th>编号</th><th>切角</th><th>角度分</th><th>球距cm（不计分）</th><th>离库cm（不计分）</th></tr>{tables}</table></div></section>')
        groups.append(dict(number=index,title=title,ball=ball,pocket=pocket,distance=distance,rows=rows))
    for i in range(6):
        assert abs(groups[0]['rows'][i]['cue'][0]+groups[1]['rows'][i]['cue'][0])<1e-10
        assert abs(groups[0]['rows'][i]['cue'][1]-groups[1]['rows'][i]['cue'][1])<1e-10
        assert max(g['rows'][i]['angleScore'] for g in groups)-min(g['rows'][i]['angleScore'] for g in groups)<1e-9
    xs=b.np.linspace(0,89.99,1000);ys=[score(x) for x in xs];assert all(a>=c for a,c in zip(ys,ys[1:]))
    fig,ax=b.plt.subplots(figsize=(11,4),facecolor='#f6f8f1');ax.plot(xs,ys,color='#187b5a',lw=2.5)
    ax.axvspan(0,10,color='#dce9d6');ax.axvline(18,color='#978363',ls='--',label='18°参考线，不筛选')
    ticks=[0,5,10,15,18,22,25,30,35,40,50,60];ax.scatter(ticks,[score(x) for x in ticks],s=20,color='#187b5a');ax.set(xlim=(0,65),ylim=(0,105),xlabel='切角（度）',ylabel='角度分');ax.grid(alpha=.2);ax.legend();fig.tight_layout();fig.savefig(OUT/'curve.png',dpi=140);b.plt.close(fig)
    curveTable=''.join(f'<tr><td>{x}°</td><td>{score(x):.1f}</td></tr>' for x in ticks)
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>角度分独立校准</title><style>body{margin:0;background:#f2f5ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1350px;margin:auto;padding:24px}header{background:#e3eddf}p{line-height:1.8}nav{position:sticky;top:0;background:#fffef4f5;padding:15px;display:flex;flex-wrap:wrap;gap:20px;justify-content:center;z-index:5}a{color:#23674f}section{scroll-margin-top:90px;padding:24px 0;border-bottom:1px solid #ccd6c4}img{width:100%}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;border:1px solid #d7e0ce;text-align:center}.curve{display:grid;grid-template-columns:3fr 1fr;gap:20px}@media(max-width:700px){.curve{display:block}}</style><header><h1>单独看看角度分：不同球形、不同切角</h1><p>球距已选放缓v2，出杆空间已选最新版v3。本轮只校准角度：沿用现有公式，不混入另外两项，不计算总分、不筛选题库。</p><p><b>角度分=100×exp[−(max(|切角|−10°,0)/18°)²]</b>。0～10°保持100分；18°是曲线尺度和历史参考，不是本页的合格线。左右相同切角同分，不继续奖励10°以内变得更直。</p><p>6组36个独立摆法，每组固定B、袋口和球距；切角0/10/18/25/35/50°。前两组左右对照，后四组更换目标球位置、角袋及30/50/70cm球距。同切角必然同角度分——这是分项隔离，不代表整杆难度相同。</p><p>切角按“C至假想球的方向”与“B至目标袋瞄点的方向”计算，不用C至B球心夹角替代。所有图均为几何校准例，未做物理入袋验证；评分不是成功率。</p></header><nav><a href="#curve">分数曲线</a>'''+''.join(f'<a href="#group-{i}">组{i}</a>' for i in range(1,7))+'</nav><main><section id="curve"><h2>先看曲线与典型分数</h2><div class="curve"><img src="curve.png" alt="角度分随切角变化曲线"><table><tr><th>切角</th><th>角度分</th></tr>'+curveTable+'</table></div></section>'+''.join(sections)+'</main><footer><a href="data.json">球位与评分数据</a></footer></html>')
    result=dict(schema='angle-score-controlled-review-v1',sourceSHA256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),coordinates='world XZ metres; landscape +X right, +Z down; Y up',synthetic=True,physicalValidation=False,anglePolicy=dict(plateauDegrees=PLATEAU,decayScaleDegrees=SCALE,filterApplied=False),groups=groups)
    (OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
    (OUT/'verification.json').write_text(json.dumps(dict(originalScoresMatched=originals,scenarios=36,ghostCutAndDistancePassed=True,ballBodiesInsidePassed=True,leftRightMirrorPassed=True,sameAngleSameScoreAcrossLayouts=True,angleMonotonicPassed=True,sourceSHA256=result['sourceSHA256']),indent=2))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-angle-review';served.mkdir(exist_ok=True)
    for f in OUT.iterdir():
        if f.is_file():shutil.copy2(f,served/f.name)
    print(json.dumps({a:round(score(a),1) for a in ticks}));print('36 scenarios passed; 22 original angle scores matched')
if __name__=='__main__':main()
