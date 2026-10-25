"""Rail-supported cueing heuristic comparison; frozen 46 geometries, no corpus edits."""
from pathlib import Path
import importlib.util, json, math, hashlib, copy, shutil
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('baseline',ROOT/'research/two-ball-comfort-space-review-20261025/render.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
SOURCE=ROOT/'output/two-ball-comfort-space-review-20261025/data.json'
OUT=ROOT/'output/two-ball-comfort-space-review-v3-20261025'
POLICY=dict(gapScaleCm=8,basePenalty=45,directionPenalty=15,gapPower=1.2,secondaryWeight=.25,secondaryCap=8)

def evaluate(cue,back):
    x,z=cue;bx,bz=back
    rails=[('右短库','x',old.HX-x-old.R,bx),('左短库','x',old.HX+x-old.R,-bx),
           ('下长库','z',old.HZ-z-old.R,bz),('上长库','z',old.HZ+z-old.R,-bz)]
    details=[]
    for name,axis,g,dot in rails:
        assert g>=-1e-10
        weight=math.exp(-(max(0,g)*100/POLICY['gapScaleCm'])**POLICY['gapPower'])
        incidence=max(0,dot)**2 # outward component of the rear direction only
        penalty=(POLICY['basePenalty']+POLICY['directionPenalty']*incidence)*weight
        details.append(dict(rail=name,axis=axis,gapCm=g*100,proximity=weight,rearToward=math.sqrt(incidence),penalty=penalty))
    primary=max(details,key=lambda d:d['penalty'])
    secondary=max((d for d in details if d['axis']!=primary['axis']),key=lambda d:d['penalty'])
    extra=min(POLICY['secondaryCap'],POLICY['secondaryWeight']*secondary['penalty'])
    return dict(score=100-primary['penalty']-extra,primaryRail=primary['rail'],primaryPenalty=primary['penalty'],
                secondaryRail=secondary['rail'],cornerPenalty=extra,rails=details)

def validate(data):
    rows=[r for g in data['groups'] for r in g['rows']];assert len(rows)==46
    for q in rows:
        base=old.evaluate(q['cue'],q['ball'],q['pocket'])
        assert abs(base['score']-q['score'])<1e-9
        assert abs(base['angle'])<1e-8 and abs(base['distance']-.42)<1e-12
        a=evaluate(q['cue'],q['back']);assert 32<=a['score']<=100
        mirror=evaluate([-q['cue'][0],q['cue'][1]],[-q['back'][0],q['back'][1]])
        assert abs(a['score']-mirror['score'])<1e-10
    # Symmetry and monotonicity at controlled single rail and two-rail corner.
    for corner in [False,True]:
        for ang in range(0,360,5):
            back=[math.cos(math.radians(ang)),math.sin(math.radians(ang))]
            scores=[]
            for i in range(151):
                gap=i/1000
                c=[old.HX-old.R-gap if corner else 0,old.HZ-old.R-gap]
                scores.append(evaluate(c,back)['score'])
            assert all(a<=b+1e-10 for a,b in zip(scores,scores[1:]))
    near=[0,old.HZ-old.R]
    assert abs(evaluate(near,[0,1])['score']-40)<1e-8
    assert abs(evaluate(near,[1,0])['score']-55)<1e-8
    return dict(frozen46OldScoresMatch=True,geometryUnchanged=True,cut0Distance42cm=True,
                xMirrorPassed=True,railAndCornerGapMonotonic=True,singleRailContact40to55=True,
                policyBounds32to100=True,sourceSHA256=hashlib.sha256(SOURCE.read_bytes()).hexdigest())

def main():
    OUT.mkdir(exist_ok=True)
    original=json.loads(SOURCE.read_text());data=copy.deepcopy(original)
    verification=validate(original)
    prior=json.loads((ROOT/'output/two-ball-comfort-space-review-v2-20261025/data.json').read_text())
    for a,b in zip(data['groups'],prior['groups']):
        for q,r in zip(a['rows'],b['rows']):q['previousScore']=r['v2']['score']
    contacts=[]
    for c,p,rail in [([.45,old.HZ-old.R],4,'长库'),([.45,old.HZ-old.R],0,'长库'),
                     ([-.65,old.HZ-old.R],3,'长库'),([old.HX-old.R,.15],0,'短库'),
                     ([old.HX-old.R,.15],4,'短库'),([old.HX-old.R,.30],1,'短库')]:
        c=old.np.array(c);u=old.ANCHORS[p]-c;u/=old.np.linalg.norm(u);q=old.evaluate(c,c+.42*u,p)
        assert abs(q['gap'])<1e-10 and q['angle']<1e-8 and abs(q['distance']-.42)<1e-10
        q['gap']=0.0 # normalize floating-point representation of exact tangency
        q['railReference']=rail
        q['railAngle']=math.degrees(math.atan2(abs(q['aim'][1] if rail=='长库' else q['aim'][0]),abs(q['aim'][0] if rail=='长库' else q['aim'][1])))
        for v in [q['cue'],q['ball']]:assert abs(v[0])<=old.HX-old.R+1e-10 and abs(v[1])<=old.HZ-old.R+1e-10
        # Contacts are on straight rail interiors, away from pocket openings.
        if rail=='长库':assert .10<abs(c[0])<1.10
        else:assert abs(c[1])<.50
        contacts.append(q)
    data['groups'].append(dict(number='9',title='球面离库0cm：长库与短库的不同方向',description='新增6个相切摆法；母球在直库中段，避开袋口开口。每小图独立，球距42cm、切角0°。方向不同，贴库分也不同。',rows=contacts))
    verification['additional6ContactGeometriesPassed']=True
    old.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    old.plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    sections=[]
    for group in data['groups']:
        n=group['number'];rows=group['rows']
        fig,axes=old.plt.subplots(3,2,figsize=(14,13),facecolor='#f6f8f1')
        fig.subplots_adjust(left=.04,right=.97,top=.83,bottom=.055,hspace=.44,wspace=.12)
        for i,ax in enumerate(axes.flat):
            if i>=len(rows):ax.axis('off');continue
            q=rows[i];q['v3']=evaluate(q['cue'],q['back']);v=q['v3']
            old.draw(ax,q,f'{n}-{i+1}')
            ax.set_title(f'{n}-{i+1} · {old.NAMES[q["pocket"]]} · 初版 {q["score"]:.1f} → 最新 {v["score"]:.1f}\n'
                         f'最近离库 {q["gap"]*100:.1f}cm · 与{q["railReference"]}夹角 {q["railAngle"]:.1f}°\n'
                         f'主库扣 {v["primaryPenalty"]:.1f} + 角落附加扣 {v["cornerPenalty"]:.1f}',
                         fontsize=11,color='#2b513e',loc='left',pad=8)
        fig.suptitle(f'出杆空间分 v3 · 组{n} · {group["title"]}',fontsize=19,y=.975)
        fig.text(.04,.936,'保留库上架杆的可打性，同时提高贴库扣分，放缓恢复速度。原46摆法不变。',fontsize=12,color='#365b48')
        fig.text(.04,.91,'蓝箭头为击球方向，紫箭头为杆尾方向示意（不是可用杆长）；球距42cm、切角0°。',fontsize=11,color='#365b48')
        fig.text(.04,.884,'新分为待校准试验值：单库最多扣60，方向最多影响15；第二条邻库最多附加扣8。',fontsize=11,color='#365b48')
        fig.text(.04,.018,'只比较空间分，不合成总分、不筛选题库。矩形库线近似，未模拟球杆/架杆/仰角，分数不是成功率。',fontsize=10,color='#526859')
        filename=f'group-{n}.png';fig.savefig(OUT/filename,dpi=130);old.plt.close(fig)
        trs=''.join(f'<tr><td>{n}-{i+1}</td><td>{q["gap"]*100:.1f}</td><td>{q["railAngle"]:.1f}°</td><td>{q["score"]:.1f}</td><td>{format(q["previousScore"],".1f") if "previousScore" in q else "—"}</td><td class="new">{q["v3"]["score"]:.1f}</td><td>{q["v3"]["primaryRail"]} −{q["v3"]["primaryPenalty"]:.1f}</td><td>{q["v3"]["secondaryRail"]} −{q["v3"]["cornerPenalty"]:.1f}</td></tr>' for i,q in enumerate(rows))
        sections.append(f'<section id="group-{n}"><h2>组{n} · {group["title"]}</h2><p>{group["description"]}</p><a href="{filename}"><img src="{filename}" alt="组{n}各球形的新旧空间分及扣分拆解"></a><div class="scroll"><table><tr><th>编号</th><th>离库cm</th><th>参考库夹角</th><th>初版v1</th><th>上一版v2</th><th>最新版v3</th><th>主要扣分</th><th>角落附加</th></tr>{trs}</table></div></section>')
        print(n,[(round(q['score'],1),round(q['v3']['score'],1)) for q in rows])
    data['schema']='space-score-controlled-review-v3';data['newPolicy']=POLICY;data['sourceSHA256']=verification['sourceSHA256']
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))
    formula='''对四条矩形库线分别计算 pᵢ=(45+15tᵢ²)×exp[−(gᵢ/8)^1.2]。gᵢ为球面离该库距离（厘米）；tᵢ=max(0，杆尾单位方向·该库朝外单位法向)，朝向该库垂直时为1、平行或背离时为0。选p最大者作为主库；在垂直于主库的两条库中取p最大者作为邻库。新分=100−p主−min(8，0.25p邻)。'''
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>库上架杆 · 出杆空间分新旧对照</title><style>body{margin:0;background:#f2f5ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1350px;margin:auto;padding:24px}header{background:#e3eddf}p{line-height:1.8}nav{position:sticky;top:0;background:#fffef4f5;padding:15px;display:flex;flex-wrap:wrap;gap:20px;justify-content:center;z-index:5}a{color:#23674f}section{scroll-margin-top:90px;border-bottom:1px solid #ccd6c4;padding:20px 0}img{width:100%}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;background:#fff}td,th{padding:12px;border:1px solid #d7e0ce;white-space:nowrap;text-align:center}.new{color:#157a54;font-weight:bold}summary{cursor:pointer}</style><header><h1>出杆空间分 v3：贴库40～55分，逐渐恢复</h1><p>沿用原8组46个球形，球位、目标袋、方向和旧分不变，加上第9组6个0cm贴库摆法，共52例。球距固定42cm、切角0°。不改题库，不计算总分。</p><p>建议先看<b>组1的2/5/8cm近库</b>，再看<b>组5和组8的角落</b>。组6/7是母球不动、只换方向的对照。第9组是新增0cm相切摆法；原46例同时列出v1、v2和v3，新增例的v2列留空。</p><p>新规则：单库贴球时约40～55分；离库逐渐恢复到100。方向最多改变单库扣分15分。角落附加最多8分，不把两个库的系数连乘。系数45、15、8cm、指数1.2、25%和8分均为本轮待评阅的试验值，尚未选为正式规则。</p><details><summary>展开新旧公式与口径</summary><p>'''+formula+'''</p><p>旧分=100×(1−exp[−(h/25)²])×(0.75+0.25×(1−exp[−(g/8)²]))。h为沿杆尾射线至矩形库线距离减球半径；g为最近库线净距。新版不再使用h扣分。</p><p>仍按矩形四边近似，袋口开口不单独豁免；不是球杆三维碰撞模型，未计具体打点、仰角、手架或桌外站位。合成几何例未验证进球，分数不是进球率。紫箭头保留原方向示意，不表示可用杆长或实体球杆。</p></details></header><nav>'''+''.join(f'<a href="#group-{i}">组{i}</a>' for i in range(1,10))+'</nav><main>'+''.join(sections)+'</main><footer><a href="data.json">坐标、旧分、新分与逐库扣分</a></footer></html>')
    for before,after in zip(original['groups'],data['groups']):
        for a,b in zip(before['rows'],after['rows']):assert {k:b[k] for k in a}==a
    verification['all46OriginalFieldsPreserved']=True
    (OUT/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-space-review-v3';served.mkdir(exist_ok=True)
    for f in OUT.iterdir():
        if f.is_file():shutil.copy2(f,served/f.name)
if __name__=='__main__':main()
