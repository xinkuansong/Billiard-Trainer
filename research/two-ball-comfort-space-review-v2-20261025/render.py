"""Rail-supported cueing heuristic comparison; frozen 46 geometries, no corpus edits."""
from pathlib import Path
import importlib.util, json, math, hashlib, copy, shutil
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('baseline',ROOT/'research/two-ball-comfort-space-review-20261025/render.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
SOURCE=ROOT/'output/two-ball-comfort-space-review-20261025/data.json'
OUT=ROOT/'output/two-ball-comfort-space-review-v2-20261025'
POLICY=dict(gapScaleCm=8,basePenalty=25,directionPenalty=10,secondaryWeight=.25,secondaryCap=8)

def evaluate(cue,back):
    x,z=cue;bx,bz=back
    rails=[('右短库','x',old.HX-x-old.R,bx),('左短库','x',old.HX+x-old.R,-bx),
           ('下长库','z',old.HZ-z-old.R,bz),('上长库','z',old.HZ+z-old.R,-bz)]
    details=[]
    for name,axis,g,dot in rails:
        assert g>=-1e-10
        weight=math.exp(-(max(0,g)*100/POLICY['gapScaleCm'])**2)
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
        a=evaluate(q['cue'],q['back']);assert 57<=a['score']<=100
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
    assert abs(evaluate(near,[0,1])['score']-65)<1e-8
    assert abs(evaluate(near,[1,0])['score']-75)<1e-8
    return dict(frozen46OldScoresMatch=True,geometryUnchanged=True,cut0Distance42cm=True,
                xMirrorPassed=True,railAndCornerGapMonotonic=True,singleRailContact65to75=True,
                policyBounds57to100=True,sourceSHA256=hashlib.sha256(SOURCE.read_bytes()).hexdigest())

def main():
    OUT.mkdir(exist_ok=True)
    original=json.loads(SOURCE.read_text());data=copy.deepcopy(original)
    verification=validate(original)
    old.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    old.plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    sections=[]
    for group in data['groups']:
        n=group['number'];rows=group['rows']
        fig,axes=old.plt.subplots(3,2,figsize=(14,13),facecolor='#f6f8f1')
        fig.subplots_adjust(left=.04,right=.97,top=.83,bottom=.055,hspace=.44,wspace=.12)
        for i,ax in enumerate(axes.flat):
            if i>=len(rows):ax.axis('off');continue
            q=rows[i];q['v2']=evaluate(q['cue'],q['back']);v=q['v2']
            old.draw(ax,q,f'{n}-{i+1}')
            ax.set_title(f'{n}-{i+1} · {old.NAMES[q["pocket"]]} · 旧 {q["score"]:.1f} → 新 {v["score"]:.1f}\n'
                         f'最近离库 {q["gap"]*100:.1f}cm · 与{q["railReference"]}夹角 {q["railAngle"]:.1f}°\n'
                         f'主库扣 {v["primaryPenalty"]:.1f} + 角落附加扣 {v["cornerPenalty"]:.1f}',
                         fontsize=11,color='#2b513e',loc='left',pad=8)
        fig.suptitle(f'出杆空间分新旧对照 · 组{n} · {group["title"]}',fontsize=19,y=.975)
        fig.text(.04,.936,'同一球位同一方向：旧版按杆后长度扣分；新版允许库上架杆，以贴库程度为主。',fontsize=12,color='#365b48')
        fig.text(.04,.91,'蓝箭头为击球方向，紫箭头为杆尾方向示意（不是可用杆长）；球距42cm、切角0°。',fontsize=11,color='#365b48')
        fig.text(.04,.884,'新分为待校准试验值：单库最多扣35，方向最多影响10；第二条邻库最多附加扣8。',fontsize=11,color='#365b48')
        fig.text(.04,.018,'只比较空间分，不合成总分、不筛选题库。矩形库线近似，未模拟球杆/架杆/仰角，分数不是成功率。',fontsize=10,color='#526859')
        filename=f'group-{n}.png';fig.savefig(OUT/filename,dpi=130);old.plt.close(fig)
        trs=''.join(f'<tr><td>{n}-{i+1}</td><td>{q["gap"]*100:.1f}</td><td>{q["railAngle"]:.1f}°</td><td>{q["score"]:.1f}</td><td class="new">{q["v2"]["score"]:.1f}</td><td>{q["v2"]["primaryRail"]} −{q["v2"]["primaryPenalty"]:.1f}</td><td>{q["v2"]["secondaryRail"]} −{q["v2"]["cornerPenalty"]:.1f}</td></tr>' for i,q in enumerate(rows))
        sections.append(f'<section id="group-{n}"><h2>组{n} · {group["title"]}</h2><p>{group["description"]}</p><a href="{filename}"><img src="{filename}" alt="组{n}各球形的新旧空间分及扣分拆解"></a><div class="scroll"><table><tr><th>编号</th><th>离库cm</th><th>参考库夹角</th><th>旧分</th><th>新分</th><th>主要扣分</th><th>角落附加</th></tr>{trs}</table></div></section>')
        print(n,[(round(q['score'],1),round(q['v2']['score'],1)) for q in rows])
    data['schema']='space-score-controlled-review-v2';data['newPolicy']=POLICY;data['sourceSHA256']=verification['sourceSHA256']
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))
    formula='''对四条矩形库线分别计算 pᵢ=(25+10tᵢ²)×exp[−(gᵢ/8)²]。gᵢ为球面离该库距离（厘米）；tᵢ=max(0，杆尾单位方向·该库朝外单位法向)，朝向该库垂直时为1、平行或背离时为0。选p最大者作为主库；在垂直于主库的两条库中取p最大者作为邻库。新分=100−p主−min(8，0.25p邻)。'''
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>库上架杆 · 出杆空间分新旧对照</title><style>body{margin:0;background:#f2f5ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1350px;margin:auto;padding:24px}header{background:#e3eddf}p{line-height:1.8}nav{position:sticky;top:0;background:#fffef4f5;padding:15px;display:flex;flex-wrap:wrap;gap:20px;justify-content:center;z-index:5}a{color:#23674f}section{scroll-margin-top:90px;border-bottom:1px solid #ccd6c4;padding:20px 0}img{width:100%}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;background:#fff}td,th{padding:12px;border:1px solid #d7e0ce;white-space:nowrap;text-align:center}.new{color:#157a54;font-weight:bold}summary{cursor:pointer}</style><header><h1>允许库上架杆后，空间分应该扣多少？</h1><p>沿用原8组46个球形，球位、目标袋、方向和旧分不变，只新增试验空间分。球距固定42cm、切角0°。不改题库，不计算总分。</p><p>建议先看<b>组1的2/5/8cm近库</b>，再看<b>组5和组8的角落</b>。组6/7是母球不动、只换方向的对照。本批最近离库为2cm，未新增0cm相切摆法。</p><p>新规则：单库贴球时约65～75分；离库逐渐恢复到100。方向最多改变单库扣分10分。角落附加最多8分，不把两个库的系数连乘。系数25、10、8cm、25%和8分均为本轮待评阅的试验值，尚未选为正式规则。</p><details><summary>展开新旧公式与口径</summary><p>'''+formula+'''</p><p>旧分=100×(1−exp[−(h/25)²])×(0.75+0.25×(1−exp[−(g/8)²]))。h为沿杆尾射线至矩形库线距离减球半径；g为最近库线净距。新版不再使用h扣分。</p><p>仍按矩形四边近似，袋口开口不单独豁免；不是球杆三维碰撞模型，未计具体打点、仰角、手架或桌外站位。合成几何例未验证进球，分数不是进球率。紫箭头保留原方向示意，不表示可用杆长或实体球杆。</p></details></header><nav>'''+''.join(f'<a href="#group-{i}">组{i}</a>' for i in range(1,9))+'</nav><main>'+''.join(sections)+'</main><footer><a href="data.json">坐标、旧分、新分与逐库扣分</a></footer></html>')
    for before,after in zip(original['groups'],data['groups']):
        for a,b in zip(before['rows'],after['rows']):assert {k:b[k] for k in a}==a
    verification['all46OriginalFieldsPreserved']=True
    (OUT/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-space-review-v2';served.mkdir(exist_ok=True)
    for f in OUT.iterdir():
        if f.is_file():shutil.copy2(f,served/f.name)
if __name__=='__main__':main()
