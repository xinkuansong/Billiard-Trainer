"""Independent ray/circle first-hit audit plus scientific trajectory figures."""
from pathlib import Path
import ast, hashlib, html, json, math, os, subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get('DEFENSE_PILOT_OUTPUT', str(ROOT/'output/defense-two-expand-20261103')))
rows = json.loads((OUT/'questions.json').read_text())
if (OUT/'source-map.json').exists():
    source_map=json.loads((OUT/'source-map.json').read_text())
    assert len(source_map)==len(rows)
    for q in rows:
        entry=source_map[q['id']];p=ROOT/entry['file']
        assert hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256']
        original=next(r for r in json.loads(p.read_text()) if r['id']==entry['originalID'])
        original['id']=q['id']
        assert original==q, q['id']
geom = json.loads((OUT/'geometry.json').read_text())
L,W,R = (geom[k] for k in ['length','width','radius'])
CUE=geom['cueKey']
# Reuse only the independent Python arithmetic function, not the old script's IO.
old = ast.parse((ROOT/'research/defense-pilot-20261103/review.py').read_text())
node = next(n for n in old.body if isinstance(n,ast.FunctionDef) and n.name=='comfort')
exec(compile(ast.Module(body=[node],type_ignores=[]),'independent_comfort','exec'))

def first(c,p,a):
    # Quadratic line/disc intersection; discs expanded by the cue radius.
    vx,vz=math.cos(a),math.sin(a)
    dx,dz=c[0]-p[0],c[1]-p[1]
    b=2*(dx*vx+dz*vz); q=dx*dx+dz*dz-(2*R)**2
    discriminant=b*b-4*q
    if discriminant < -1e-11:return math.inf
    near=(-b-math.sqrt(max(0,discriminant)))/2
    return near if near>=0 else math.inf

def sweep(c,b,t,n=4097):
    base=math.atan2(t[1]-c[1],t[0]-c[0]);half=math.asin(2*R/math.dist(c,t))
    exposed=0;min_lead=math.inf
    for i in range(n):
        a=base-half+2*half*i/(n-1)
        tt=first(c,t,a);tb=first(c,b,a)
        assert math.isfinite(tt)
        if tb>=tt:exposed+=1
        min_lead=min(min_lead,tt-tb)
    return dict(exposedRays=exposed,testedRays=n,minBlockerLeadMeters=min_lead if math.isfinite(min_lead) else None)

def proof(c,b,t):
    db=math.dist(c,b);dt=math.dist(c,t)
    ab=math.atan2(b[1]-c[1],b[0]-c[0]);at=math.atan2(t[1]-c[1],t[0]-c[0])
    diff=abs(math.atan2(math.sin(ab-at),math.cos(ab-at)))
    return math.asin(2*R/db)-diff-math.asin(2*R/dt),dt-db-4*R

# Counterexamples explicitly distinguish centre-line blocking from full blocking.
assert sweep([0,0],[.25,0],[1,0])['exposedRays']==0
assert sweep([0,0],[.9,.05],[1,0])['exposedRays']>0
assert first([0,0],[.9,.05],0)<first([0,0],[1,0],0)
assert sweep([0,0],[1.3,0],[1,0])['exposedRays']==4097
assert sweep([0,0],[.25,.3],[1,0])['exposedRays']==4097

def check_positions(ps):
    vals=list(ps.values())
    assert len(vals)==3
    for i,p in enumerate(vals):
        assert all(math.isfinite(v) for v in p)
        assert abs(p[0])<=L/2-R+1e-5 and abs(p[1])<=W/2-R+1e-5
        for q in vals[i+1:]: assert math.dist(p,q)>=2*R-1e-5

def audit_result(q,r,full):
    own,enemy=q['ownKey'],q['enemyKey'];ps=r['positions'];check_positions(ps)
    assert r['settled'] and not r['pocketed']
    hit=next(e for e in r['events'] if e['kind']=='ballBall')
    assert set(hit['balls'])=={CUE,own}
    assert any(e['kind']=='cushion' and e['time']>hit['time'] for e in r['events'])
    for key,track in r['tracks'].items():
        assert math.dist(track[-1][1:],ps[key])<1e-4
        assert all(a[0]<=b[0] for a,b in zip(track,track[1:]))
    c,b,t=ps[CUE],ps[own],ps[enemy]
    rays=sweep(c,b,t)
    am,depth=proof(c,b,t)
    assert abs(math.degrees(am)-r['occlusion']['angularMarginDegrees'])<1e-4
    assert abs(depth-r['occlusion']['depthGapMeters'])<1e-6
    if full:
        assert r['occlusion']['full'] and r['defenseScore']==100
        assert am>1e-6 and depth>0 and rays['exposedRays']==0
        assert not r['opportunities']
    for option in r['opportunities']:
        calc=comfort(c,t,option['aim'])
        for field in calc:assert abs(calc[field]-option[field])<2e-4
    return rays

audits=[]
for q in rows:
    assert q['exactReplay'];check_positions(q['positions'])
    assert {q['ownKey'],q['enemyKey']}==({'_1','_8'} if q['branch']=='A' else {'_8','_9'})
    assert 0<=q['openingComfort']<=40
    ps=q['positions'];c,b,t=ps[CUE],ps[q['ownKey']],ps[q['enemyKey']]
    assert sweep(c,b,t)['exposedRays']>4097/2
    assert abs(max(o['score'] for o in q['openingOpportunities'])-q['openingComfort'])<1e-8
    for option in q['openingOpportunities']:
        calc=comfort(c,b,option['aim'])
        for field in calc:assert abs(calc[field]-option[field])<2e-4
    result=audit_result(q,q['reference'],True)
    assert len(q['perturbations'])==8
    for p in q['perturbations']:assert 'rejection' not in p;audit_result(q,p['result'],True)
    alternative=audit_result(q,q['comparison'],False)
    assert alternative['exposedRays']>4097/4
    # Horizontal reflection preserves the blockage result and margin.
    final=q['reference']['positions'];fc,fb,ft=(final[k] for k in [CUE,q['ownKey'],q['enemyKey']])
    mirrored=[[-p[0],p[1]] for p in [fc,fb,ft]]
    assert sweep(*mirrored)['exposedRays']==0
    if q['family']=='longRail':
        assert .02 <= W/2-abs(b[1])-R <= .16
        assert L/2-abs(b[0])-R >= .3
    else:
        assert min(L/2-abs(b[0]),W/2-abs(b[1]))-R>=.22
    hit=next(e for e in q['reference']['events'] if e['kind']=='ballBall')
    actual_cue_bank=any(e['kind']=='cushion' and e['ball']==CUE and e['time']>hit['time'] and 0<=e['index']<6 for e in q['reference']['events'])
    if q['family']=='openBank':assert actual_cue_bank
    if 'cueBankAfterContact' in q:assert q['cueBankAfterContact']==actual_cue_bank
    q['actualCueBank']=actual_cue_bank
    cushion_events=[e for e in q['reference']['events'] if e['kind']=='cushion']
    non_main=[e for e in cushion_events if not 0<=e['index']<6]
    small_non_main=sum(any(e['kind']=='cushion' and not 0<=e['index']<6 for e in p['result']['events']) for p in q['perturbations'])
    q['reviewState']='diagnosticOnly' if non_main or small_non_main else 'reviewCandidate'
    q['reviewLabel']='暂缓：参考或微调涉及袋角' if non_main or small_non_main else '待审阅'
    q['nonMainContacts']=non_main
    stress_counts={tier:dict(full=0,exposed=0,rejected=0,unproven=0) for tier in ['medium','wide']}
    assert len(q['stressProbes'])==16
    for probe in q['stressProbes']:
        count=stress_counts[probe['tier']]
        if 'rejection' in probe:count['rejected']+=1;continue
        r=probe['result'];full=r['occlusion']['full']
        ray=audit_result(q,r,full)
        count['full' if full else ('exposed' if ray['exposedRays']>0 else 'unproven')]+=1
    q['stressCounts']=stress_counts
    audits.append(dict(id=q['id'],passed=True,reviewState=q['reviewState'],reviewLabel=q['reviewLabel'],nonMainContacts=non_main,smallProbeNonMainCount=small_non_main,stressCounts=stress_counts,referenceRayAudit=result,comparisonRayAudit=alternative,
        perturbationsFullyBlocked=8,exactReplay=True))

report=dict(passed=True,questions=len(rows),checks=audits,geometryCounterexamples=4,
    limitations=['Full block is planar straight first-contact access, not kick/jump difficulty or win probability.',
                 'Eight finite probes are not a probability or complete tolerance domain.',
                 'Opening attack comfort is a geometry heuristic, not a calibrated pot probability.',
                 'No App integration, UI/device or real-table acceptance.'])
(OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
(OUT/'review-status.json').write_text(json.dumps({q['id']:dict(state=q['reviewState'],label=q['reviewLabel']) for q in rows},ensure_ascii=False,indent=2))

FONT='PingFang SC,Heiti SC,sans-serif'
COLORS={CUE:'#fffdf5','_1':'#f9c447','_8':'#18231f','_9':'#f9c447'}
def opening_label(value):
    return '<0.1' if 0<value<.1 else f'{value:.1f}'
def text(x,y,s,size=18,color='#193731',weight=400,anchor='start'):
    return f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{html.escape(str(s))}</text>'
def ball(key,p,project,scale,hollow=False):
    x,y=project(p);r=R*scale
    s=f'<circle cx="{x}" cy="{y}" r="{r}" fill="{COLORS[key] if not hollow else "none"}" stroke="#e7eee5" stroke-width="1" {"stroke-dasharray=\"2 2\"" if hollow else ""}/>'
    if not hollow and key!=CUE:
        if key=='_9':s+=f'<rect x="{x-r*.85}" y="{y-r*.28}" width="{r*1.7}" height="{r*.56}" fill="white"/>'
        s+=text(x,y+r*.45,key[1:],max(9,r*1.1),'white' if key=='_8' else '#192a20',600,'middle')
    return s
def panel(q,shot=None):
    scale=226;x0=47;y0=56
    def project(p):return x0+(p[1]+W/2)*scale,y0+(L/2-p[0])*scale
    s=f'<rect x="{x0-18}" y="{y0-18}" width="{W*scale+36}" height="{L*scale+36}" rx="23" fill="#705d48"/>'
    s+=f'<rect x="{x0}" y="{y0}" width="{W*scale}" height="{L*scale}" rx="8" fill="#147453"/>'
    for p in geom['pockets']:
        x,y=project(p['center']);s+=f'<circle cx="{x}" cy="{y}" r="12" fill="#182a24" stroke="#ad9b78" stroke-width="3"/>'
    ps=q['positions']
    if shot:
        for key,track in shot['tracks'].items():
            color='#bcefff' if key==CUE else ('#ffe16b' if key==q['ownKey'] else '#fbaaaa')
            points=' '.join(f'{x:.3f},{y:.3f}' for x,y in [project(t[1:]) for t in track])
            s+=f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2.1"/>'
        for key,p in ps.items():s+=ball(key,p,project,scale,True)
        ps=shot['positions']
    for key,p in ps.items():s+=ball(key,p,project,scale)
    return s
def zoom(q):
    ps=q['reference']['positions'];c,b,t=(ps[k] for k in [CUE,q['ownKey'],q['enemyKey']])
    xs=[p[0] for p in ps.values()];zs=[p[1] for p in ps.values()]
    midx=(min(xs)+max(xs))/2;midz=(min(zs)+max(zs))/2
    scale=min(300/(max(zs)-min(zs)+.22),460/(max(xs)-min(xs)+.22))
    def project(p):return 190+(p[1]-midz)*scale,312-(p[0]-midx)*scale
    s='<rect x="27" y="56" width="326" height="525" rx="16" fill="#e7eee4"/>'
    # Dashed expanded discs are cue-centre exclusion domains, not physical ball sizes.
    for p in [b,t]:
        x,y=project(p);s+=f'<circle cx="{x}" cy="{y}" r="{2*R*scale}" fill="none" stroke="#b26450" stroke-width="1.3" stroke-dasharray="5 4"/>'
    base=math.atan2(t[1]-c[1],t[0]-c[0]);half=math.asin(2*R/math.dist(c,t))
    for angle in [base-half,base+half]:
        td=first(c,t,angle);bd=first(c,b,angle)
        end=[c[0]+td*math.cos(angle),c[1]+td*math.sin(angle)]
        stop=[c[0]+bd*math.cos(angle),c[1]+bd*math.sin(angle)]
        x1,y1=project(c);x2,y2=project(end);x3,y3=project(stop)
        s+=f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#bb6858" stroke-dasharray="4 4" stroke-width="1.4"/>'
        s+=f'<line x1="{x1}" y1="{y1}" x2="{x3}" y2="{y3}" stroke="#b84030" stroke-width="2.5"/>'
        s+=f'<circle cx="{x3}" cy="{y3}" r="4" fill="#b84030"/>'
    for key,p in ps.items():s+=ball(key,p,project,scale)
    s+=text(190,611,'两侧极限直击方向均先遇挡球',17,anchor='middle')
    s+=text(190,638,'虚线圆计入母球半径，并非球体大小',14,anchor='middle')
    return s

cards=[]
for q in rows:
    own=q['ownKey'][1:];enemy=q['enemyKey'][1:]
    family_title='长库附近做遮挡' if q['family']=='longRail' else '我方目标球离库开局'
    own_main=any(e['kind']=='cushion' and e['ball']==q['ownKey'] and 0<=e['index']<6 for e in q['reference']['events'])
    route_title='母球碰目标后吃主库' if q['actualCueBank'] else ('我方目标球碰后吃主库' if own_main else '仅碰到袋口区域，未碰主库')
    heading=f"{q['id']}  我方打{own}号，对方打{enemy}号"
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="870" viewBox="0 0 1200 870"><rect width="1200" height="870" fill="#f5f7f2"/>'
    svg+=text(32,39,heading,27,weight=650)
    svg+=text(32,70,f"{family_title} · 开局进攻舒适度 {opening_label(q['openingComfort'])} / 100 · {q['reviewLabel']}",17)
    for i,(title,body) in enumerate([('开局 · 先考虑怎样做遮挡',panel(q)),('参考打法 · 引擎模拟轨迹',panel(q,q['reference'])),('停稳遮挡检查 · 局部放大',zoom(q))]):
        svg+=f'<g transform="translate({i*400},90)">'+text(190,12,title,19,weight=600,anchor='middle')+body+'</g>'
    shot=q['reference']['shot'];spin='中心' if shot['spinY']==0 else ('低杆' if shot['spinY']<0 else '高杆')
    svg+=text(32,773,f"参考：{spin} · 杆速 {shot['speed']:.1f} m/s · 无侧塞",18,weight=550)
    svg+=text(610,773,'完整直击遮挡 100 · 8次有限微扰保持遮挡',20,weight=650)
    svg+=text(32,814,'浅蓝：母球轨迹  ·  黄色：我方目标球轨迹  ·  虚圈：起点  ·  实心球：停点',16)
    svg+=text(32,844,f"较大微调仍挡住：±0.3°/±10% {q['stressCounts']['medium']['full']}/8；±0.6°/±15% {q['stressCounts']['wide']['full']}/8。仅为探针计数，不是成功率。",16)
    svg+='</svg>'
    (OUT/f"{q['id']}.svg").write_text(svg)
    subprocess.run(['rsvg-convert',str(OUT/f"{q['id']}.svg"),'-o',str(OUT/f"{q['id']}.png")],check=True)
    comparison=f'<svg xmlns="http://www.w3.org/2000/svg" width="400" height="730"><rect width="400" height="730" fill="#f5f7f2"/>'+text(190,28,'同一开局 · 未挡严的合法打法',18,weight=600,anchor='middle')+f'<g transform="translate(0,15)">{panel(q,q["comparison"])}</g></svg>'
    (OUT/f"{q['id']}-comparison.svg").write_text(comparison)
    subprocess.run(['rsvg-convert',str(OUT/f"{q['id']}-comparison.svg"),'-o',str(OUT/f"{q['id']}-comparison.png")],check=True)
    cp=q['comparison']['shot'];visible=q['comparison']['visibleFractionSampled']*100
    opening=f'<svg xmlns="http://www.w3.org/2000/svg" width="400" height="730"><rect width="400" height="730" fill="#f5f7f2"/>'+text(190,28,'开局 · 先考虑怎样做遮挡',18,weight=600,anchor='middle')+f'<g transform="translate(0,15)">{panel(q)}</g></svg>'
    (OUT/f"{q['id']}-opening.svg").write_text(opening)
    stress_rows=''.join(f"<tr><td>{tier}</td><td>{count['full']}</td><td>{count['exposed']}</td><td>{count['rejected']}</td><td>{count['unproven']}</td></tr>" for tier,count in q['stressCounts'].items())
    cards.append(f'''<article><h2>{html.escape(heading)} · {q['reviewLabel']}</h2><p>先合法碰{own}号，再争取让母球与{enemy}号之间隔着{own}号。开局进攻舒适度 {html.escape(opening_label(q['openingComfort']))}。</p><img class="comparison" src="{q['id']}-opening.svg" alt="开局球形"/>
<details><summary>展开参考轨迹与遮挡检查</summary><a href="{q['id']}.png"><img src="{q['id']}.svg" alt="{heading}" /></a>
<p>参考杆与8个方向/速度探针均通过完整遮挡证明；独立扫描每个结果的4097条直击方向，没有可先碰对方目标球的方向。探针为方向±0.15°、速度±5%的3×3组合去掉中心点，不代表实台成功率。</p>
<p>{family_title}；{route_title}。较大偏差的探针记录：</p><table><tr><th>范围</th><th>挡住</th><th>露球</th><th>无效杆</th><th>未证明</th></tr>{stress_rows}</table><p>medium：方向±0.3°／速度±10%；wide：方向±0.6°／速度±15%。每档8个组合，不作为进球概率、实台成功率或正式难度等级。</p>
<details><summary>查看同一开局的合法反例：没有挡严</summary><img class="comparison" src="{q['id']}-comparison.svg"/><p>杆速 {cp['speed']:.2f} m/s；直击角域采样约 {visible:.0f}% 可先碰对方目标球。这是角域占比，不是进球概率。没有直攻进球候选时仍单列未评分，不自动记100。</p></details></details></article>''')
(OUT/'review.html').write_text(f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>两球遮挡 · 长库与吃库回藏</title>
<style>body{{font-family:{FONT};max-width:1200px;margin:32px auto;padding:0 20px;background:#f5f7f2;color:#193731;line-height:1.65}}article{{padding:22px;background:white;border:1px solid #dbe3da;border-radius:16px;margin:24px 0}}img{{width:100%;height:auto}}.comparison{{max-width:400px}}table{{border-collapse:collapse}}td,th{{padding:6px 14px;border-bottom:1px solid #dbe3da}}summary{{cursor:pointer;font-weight:600;color:#14664c}}a{{color:#14664c}}</style>
<h1>两球遮挡：长库与离库开局</h1><p>本轮扩展两种开局；各包含我方1号／我方8号两个分支。开局球形与实际碰库路线分别记录，允许由母球或目标球完成碰后碰库。</p><p>母球不计入目标球数量。A组：我方1号、对方8号；B组：我方8号、对方9号。每题都要求我方先合法碰自己的球，无球入袋，碰后至少一球碰库。</p>
<p>本批包含{sum(q['reviewState']=='reviewCandidate' for q in rows)}道待审阅样题和{sum(q['reviewState']=='diagnosticOnly' for q in rows)}道袋角路线诊断候选。所有候选都通过直击遮挡检查，但涉及袋角者暂不推荐作教学参考。100是遮挡达成标签；题目难度与解球难度另评。参考来源为动作库c060遮挡思路，球形为新生成，不是原动作的逐杆复刻。</p>{''.join(cards)}
<p>研究图册，非App截图。已做冻结源码模拟、精确回放和独立几何审计；未接入App、未做实台校准或用户验收。</p></html>''')
(OUT/'review-source.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__),ROOT/'research/defense-pilot-20261103/review.py']},indent=2))
print(json.dumps(dict(audit='PASS',questions=len(rows),review=str(OUT/'review.html')),ensure_ascii=False))
