"""Independent arithmetic/contract audit and measured-trajectory review figures."""
from pathlib import Path
import html, json, math, subprocess, os

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get('DEFENSE_PILOT_OUTPUT', str(ROOT / 'output/defense-pilot-20261103')))
rows = json.loads((OUT / 'questions.json').read_text())
geometry = json.loads((OUT / 'geometry.json').read_text())
L, W, R = (geometry[k] for k in ('length','width','radius'))
cue_key = geometry['cueKey']

def comfort(c, b, p):
    d = math.dist(b,p); cue_distance = math.dist(c,b)
    u = [(p[i]-b[i])/d for i in range(2)]
    v = [b[i]-2*R*u[i]-c[i] for i in range(2)]
    norm = math.hypot(*v); dot = sum(v[i]*u[i] for i in range(2))
    angle_degrees = math.degrees(math.atan2(abs(v[0]*u[1]-v[1]*u[0]),dot))
    depths = [((bound if direction > 0 else -bound)-pos)/direction
              for pos,direction,bound in zip(b,[-u[0],-u[1]],[L/2-R,W/2-R]) if abs(direction)>1e-12]
    depth = max(0,min(depths))
    scale = min(1,max(.4,depth/.9)); lo = .5*scale; hi = .8*scale
    near = max(lo-cue_distance,0)/(.8*lo); far = max(cue_distance-hi,0)/.75
    distance = 100*math.exp(-near*near-far*far)
    back = [-v[0]/norm,-v[1]/norm]
    gaps = [L/2-c[0]-R,L/2+c[0]-R,W/2-c[1]-R,W/2+c[1]-R]
    dirs = [back[0],-back[0],back[1],-back[1]]
    penalties = [(45+15*max(t,0)**2)*math.exp(-(max(g,0)*100/8)**1.2) for g,t in zip(gaps,dirs)]
    main = max(range(4),key=penalties.__getitem__)
    adjacent = max(penalties[2:] if main<2 else penalties[:2])
    space = 100-penalties[main]-min(8,.25*adjacent)
    plateau = min(15,9/d); decay = min(20,20*math.sqrt(.6/d))
    angle = 100*math.exp(-(max(angle_degrees-plateau,0)/decay)**2)
    total = .5*min(distance,space,angle)+.5*(distance*space*angle)**(1/3)
    return dict(distance=distance,space=space,angle=angle,score=total)

checks = []
def finite_rail_gap(p):
    distances=[]
    for seg in geometry['railSegments']:
        a,b=seg['start'],seg['end'];v=[b[i]-a[i] for i in range(2)]
        u=max(0,min(1,sum((p[i]-a[i])*v[i] for i in range(2))/sum(x*x for x in v)))
        distances.append(math.dist(p,[a[i]+u*v[i] for i in range(2)])-R)
    return min(distances)

statuses={}
for q in rows:
    assert q['openingComfort'] <= 40 and q['exactReplay']
    sets = [(q['cue'],q['black'],q['openingOpportunities'])]
    for key in ['reference','poorComparison']:
        r=q[key]; c=r['finalCue']; b=r['finalBlack']
        assert r['settled'] and not r['pocketed']
        events=r['events']; hit=next(e for e in events if e['kind']=='ballBall')
        assert set(hit['balls'])=={cue_key,'_8'}
        assert any(e['kind']=='cushion' and e['time']>hit['time'] for e in events)
        assert math.dist(c,b)>=2*R-1e-5
        for p in [c,b]:
            assert abs(p[0])<=L/2-R+1e-5 and abs(p[1])<=W/2-R+1e-5
        assert abs(r['defenseScore']-(100-max(o['score'] for o in r['opportunities'])))<1e-9
        for name,p in [(cue_key,c),('_8',b)]:
            track=r['tracks'][name]
            assert all(a[0]<=b[0] for a,b in zip(track,track[1:]))
            assert math.dist(track[-1][1:],p)<1e-4
        sets.append((c,b,r['opportunities']))
    errors=[]
    for c,b,options in sets:
        for option in options:
            independent=comfort(c,b,option['aim'])
            for field in independent:
                error=abs(independent[field]-option[field]); errors.append(error)
                assert error<1e-7,(q['id'],field,error)
    assert q['reference']['defenseScore']>=70
    assert q['reference']['defenseScore']-q['openingDefense']>=10
    assert q['reference']['defenseScore']-q['poorComparison']['defenseScore']>=20
    r=q['reference']
    if 'tacticalFilter' in q:
        assert math.dist(r['finalCue'],r['finalBlack'])>=1.2 or finite_rail_gap(r['finalCue'])<=.04
    probes=q['perturbations']
    if any('rejection' in p for p in probes):
        statuses[q['id']]={'state':'diagnosticOnly','label':'暂缓：扰动后存在未评分局面'}
    elif min(p['score'] for p in probes)<70:
        statuses[q['id']]={'state':'diagnosticOnly','label':'暂缓：方向微调后评分大幅下降'}
    else:
        statuses[q['id']]={'state':'reviewCandidate','label':'待用户审阅'}
    statuses[q['id']]['method']='留长台' if math.dist(r['finalCue'],r['finalBlack'])>=1.2 else '母球靠库'
    statuses[q['id']]['cueRailGapMeters']=finite_rail_gap(r['finalCue'])
    statuses[q['id']]['ballDistanceMeters']=math.dist(r['finalCue'],r['finalBlack'])
    checks.append(dict(id=q['id'],passed=True,maxArithmeticError=max(errors),
                       perturbationScorable=sum('score' in p for p in q['perturbations'])))
assert len(rows)>=3
(OUT/'review-status.json').write_text(json.dumps(statuses,ensure_ascii=False,indent=2))
(OUT/'audit.json').write_text(json.dumps(dict(passed=True,questions=len(rows),checks=checks,
    limitations=['Geometry candidates are not measured pot probabilities.',
                 'Search is bounded; reference is not proved globally optimal.',
                 'No App UI/device/real-table acceptance.']),indent=2))

FONT='PingFang SC,Heiti SC,sans-serif'
def score_label(value):
    return '≥99（未遮挡）' if value>=99 else f'{value:.1f}'
def txt(x,y,s,size=18,color='#193731',weight=400,anchor='start'):
    return f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{html.escape(str(s))}</text>'
def table_svg(c,b,shot=None,opening=False):
    # Fixed portrait physical metric projection; no image editing or fake paths.
    scale=226; x0=47; y0=56
    def project(p): return x0+(p[1]+W/2)*scale,y0+(L/2-p[0])*scale
    w=W*scale; h=L*scale
    s=f'<rect x="{x0-18}" y="{y0-18}" width="{w+36}" height="{h+36}" rx="23" fill="#705d48"/>'
    s+=f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" rx="8" fill="#147453"/>'
    for pocket in geometry['pockets']:
        x,y=project(pocket['center']);s+=f'<circle cx="{x}" cy="{y}" r="12" fill="#182a24" stroke="#ad9b78" stroke-width="3"/>'
    if shot:
        for name,color in [(cue_key,'#bcefff'),('_8','#ffe16b')]:
            points=' '.join(f'{x:.2f},{y:.2f}' for x,y in map(lambda r:project(r[1:]),shot['tracks'][name]))
            s+=f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2.1" opacity=".9"/>'
        for p,color in [(c,'white'),(b,'#ffe16b')]:
            x,y=project(p);s+=f'<circle cx="{x}" cy="{y}" r="{R*scale}" fill="none" stroke="{color}" stroke-dasharray="2 2"/>'
        c,b=shot['finalCue'],shot['finalBlack']
    for p,black in [(c,False),(b,True)]:
        x,y=project(p)
        s+=f'<circle cx="{x}" cy="{y}" r="{R*scale}" fill="{"#121c19" if black else "#fffdf5"}" stroke="{"#d9e5de" if black else "#d9c99b"}" stroke-width="1"/>'
        if black:s+=txt(x,y+3,'8',9,'white',600,'middle')
    return s

cards=[]
for q in rows:
    good=q['reference']; bad=q['poorComparison']
    status=statuses[q['id']]
    panels=[('开局 · 先考虑怎样防守',None),('参考打法 · 模拟停稳结果',good),('较差打法 · 对照结果',bad)]
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="850" viewBox="0 0 1200 850"><rect width="1200" height="850" fill="#f5f7f2"/>'
    svg+=txt(32,39,f'{q["id"]}  双方争8号',27,weight=650)
    svg+=txt(32,68,f'开局最佳进攻舒适度 {q["openingComfort"]:.1f} / 100 · {status["method"]} · {status["label"]}',16)
    for i,(title,result) in enumerate(panels):
        svg+=f'<g transform="translate({i*400},86)">'
        svg+=txt(200,15,title,18,weight=600,anchor='middle')
        svg+=table_svg(q['cue'],q['black'],result,opening=result is None)
        if result:
            svg+=txt(200,682,f'防守效果 {score_label(result["defenseScore"])}',22,weight=650,anchor='middle')
            shot=result['shot']; spin='中心' if abs(shot['spinY'])<1e-8 else ('高' if shot['spinY']>0 else '低')+f'{abs(shot["spinY"])/.5*100:.0f}%'
            svg+=txt(200,708,f'{spin} · 杆速 {shot["speed"]:.1f} m/s · 无侧塞',15,anchor='middle')
        else:
            svg+=txt(200,682,f'初始反向分 {q["openingDefense"]:.1f}',20,anchor='middle')
            svg+=txt(200,708,'进攻困难；这杆需合法碰球并碰库',15,anchor='middle')
        svg+='</g>'
    svg+=txt(32,825,'引擎模拟轨迹  ·  浅蓝：母球  ·  黄色：8号  ·  虚圈：起点  ·  实心球：停点',16)
    svg+='</svg>'
    path=OUT/f'{q["id"]}.svg';path.write_text(svg)
    subprocess.run(['rsvg-convert',str(path),'-o',str(path.with_suffix('.png'))],check=True)
    probes=q['perturbations']; legal=[p['score'] for p in probes if 'score' in p]
    probe_text=f'{len(legal)}/4次合法且可评分，效果范围 {min(legal):.1f}–{max(legal):.1f}' if legal else '4次扰动均未得到可评分合法结果'
    pockets=['左下角袋','左上角袋','右下角袋','右上角袋','左中袋','右中袋']
    best=good['opportunities'][0]
    cards.append(f'''<article><h2>{q['id']} · {status['method']} · {status['label']}</h2>
<p>双方争8号。先考虑母球和8号分别留在哪里。</p>
<details><summary>展开参考打法与较差结果</summary><a href="{q['id']}.png"><img src="{q['id']}.svg" alt="{q['id']}开局、参考与对照" /></a>
<p>参考效果 {score_label(good['defenseScore'])}；较差对照 {score_label(bad['defenseScore'])}；相对开局改善 {good['defenseScore']-q['openingDefense']:.1f}。</p>
<p>参考结果：两球距离 {status['ballDistanceMeters']:.2f} 米；母球球面距最近实际主库段 {status['cueRailGapMeters']*100:.1f} 厘米。对手几何上最舒服的袋口为{pockets[best['pocket']]}，舒适度 {best['score']:.3f}（距离项 {best['distance']:.1f}、出杆空间项 {best['space']:.1f}、角度项 {best['angle']:.1f}）。</p>
<p>方向±0.15°、杆速±5%的四次单项扰动：{probe_text}。这是敏感性检查，不是成功率。</p></details></article>''')

body=''.join(cards)
(OUT/'review.html').write_text(f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>纯防守样题 · 双方争8号</title>
<style>body{{font-family:{FONT};max-width:1200px;margin:40px auto;padding:0 24px;background:#f5f7f2;color:#193731;line-height:1.65}}h1{{font-size:32px}}article{{margin:28px 0;padding:24px;background:white;border:1px solid #dbe3da;border-radius:14px}}img{{width:100%;height:auto}}summary{{cursor:pointer;color:#14664c;font-weight:600}}.meta{{color:#52645e}}a{{color:#14664c}}</style>
<h1>纯防守样题：双方争8号</h1><p>第一批固定源码试验，共{len(rows)}道候选，其中{sum(v['state']=='reviewCandidate' for v in statuses.values())}道待用户审阅，其余暂作诊断。开局进攻困难，练习控制母球与8号的最终位置。</p>
<p class="meta">开局舒适度≤40为本轮试验筛选线；防守效果=100−对手最舒服的直接进攻分。只有8号时没有其他球可作遮挡，不把接近100的数值解释为完全斯诺克。参考解来自有限搜索，不是唯一答案。</p>
<p><a href="overview.png">查看全部参考结果总览</a> · <a href="questions.json">样题数据</a> · <a href="audit.json">校验结果</a></p>{body}
<p class="meta">图形按实际引擎轨迹绘制，非App截图。已做固定快照回放与分数独立复算；未做App接入、实台或用户验收。</p></html>''')

# Six compact reference-result panels, not a raster edit of an existing image.
height=820*math.ceil(len(rows)/3)
svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="{height}" viewBox="0 0 1200 {height}"><rect width="1200" height="{height}" fill="#f5f7f2"/>'
for i,q in enumerate(rows):
    svg+=f'<g transform="translate({i%3*400},{i//3*820})">'
    svg+=txt(200,35,q['id']+' · '+statuses[q['id']]['method'],23,weight=650,anchor='middle')
    svg+='<g transform="translate(0,22)">'+table_svg(q['cue'],q['black'],q['reference'])+'</g>'
    svg+=txt(200,710,f'开局进攻舒适度 {q["openingComfort"]:.1f}',18,anchor='middle')
    svg+=txt(200,741,f'防守效果 {score_label(q["reference"]["defenseScore"])}',24,weight=650,anchor='middle')
    svg+=txt(200,770,f'较差对照 {q["poorComparison"]["defenseScore"]:.1f}',17,anchor='middle')
    svg+=txt(200,797,statuses[q['id']]['label'],15,anchor='middle')
    svg+='</g>'
svg+='</svg>'
(OUT/'overview.svg').write_text(svg)
subprocess.run(['rsvg-convert',str(OUT/'overview.svg'),'-o',str(OUT/'overview.png')],check=True)
print(json.dumps({'audit':'PASS','questions':len(rows),'review':str(OUT/'review.html')},ensure_ascii=False))
