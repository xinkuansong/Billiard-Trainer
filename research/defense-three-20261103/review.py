"""Independent continuous union proof, ray audit, and measured scientific figures."""
from pathlib import Path
import ast, hashlib, html, json, math, os, subprocess, tarfile
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ.get('DEFENSE_PILOT_OUTPUT',str(ROOT/'output/defense-three-20261103')))
rows=json.loads((OUT/'questions.json').read_text());geom=json.loads((OUT/'geometry.json').read_text())
L,W,R=(geom[k] for k in ['length','width','radius']);CUE=geom['cueKey']
# Reuse independent arithmetic and drawing only. No inherited audit or IO.
for file,names in [('research/defense-pilot-20261103/review.py',['comfort']),('research/defense-two-expand-20261103/review.py',['first','text','ball','panel','opening_label'])]:
    tree=ast.parse((ROOT/file).read_text())
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:exec(compile(ast.Module(body=[node],type_ignores=[]),file,'exec'))
FONT='PingFang SC,Heiti SC,sans-serif'
COLORS={CUE:'#fffdf5','_1':'#f9c447','_8':'#18231f','_9':'#f9c447'}
NAMES={'own':'用1号做遮挡','black':'借8号做遮挡','joint':'1号与8号联合遮挡'}

def sweep(c,bs,t,n=4097):
    angle=math.atan2(t[1]-c[1],t[0]-c[0]);h=math.asin(2*R/math.dist(c,t))
    exposed=0
    for i in range(n):
        a=angle-h+2*h*i/(n-1);td=first(c,t,a)
        assert math.isfinite(td)
        exposed+=min(first(c,b,a) for b in bs)>=td
    return exposed

def proof(c,bs,t):
    # Independent interval subtraction from the entire target cone.
    dt=math.dist(c,t);h=math.asin(2*R/dt);a=math.atan2(t[1]-c[1],t[0]-c[0])
    gaps=[(-h,h)];intervals=[]
    for b in bs:
        db=math.dist(c,b)
        if db<=2*R or dt-db<=4*R:continue
        d=math.atan2(b[1]-c[1],b[0]-c[0])-a;d=math.atan2(math.sin(d),math.cos(d))
        bh=math.asin(2*R/db);lo,hi=d-bh+1e-6,d+bh-1e-6
        intervals.append([lo,hi]);remaining=[]
        for left,right in gaps:
            if hi<left or lo>right:remaining.append((left,right));continue
            if lo>left:remaining.append((left,lo))
            if hi<right:remaining.append((hi,right))
        gaps=remaining
    return not gaps,sorted(intervals),h

# True combined screen; either ball alone leaves a side open.
c=[0,0];t=[1,0];bs=[[.25,-.05],[.25,.05]]
assert proof(c,bs,t)[0] and sweep(c,bs,t)==0
assert all(sweep(c,[b],t)>0 for b in bs)
# Both extreme edge directions blocked but an interior gap remains: must reject.
bs=[[.5,-.065],[.5,.065]];h=math.asin(2*R)
assert all(min(first(c,b,a) for b in bs)<first(c,t,a) for a in [-h,h])
assert not proof(c,bs,t)[0] and sweep(c,bs,t)>0
assert not proof(c,[[1.3,0]],t)[0] and sweep(c,[[1.3,0]],t)==4097
assert proof(c,[[.25,0]],t)[0] and sweep(c,[[.25,0]],t)==0


def positions(ps):
    assert set(ps)=={CUE,'_1','_8','_9'}
    vs=list(ps.values())
    for i,p in enumerate(vs):
        assert all(math.isfinite(v) for v in p)
        assert abs(p[0])<=L/2-R+1e-5 and abs(p[1])<=W/2-R+1e-5
        for q in vs[i+1:]:assert math.dist(p,q)>=2*R-1e-5

def audit(q,r,required=False,teaching=False):
    positions(r['positions']);ps=r['positions'];c,t=ps[CUE],ps['_9'];bs=[ps['_1'],ps['_8']]
    assert r['settled'] and not r['pocketed'] and not any(e['kind']=='pocket' for e in r['events'])
    first_hit=next(e for e in r['events'] if e['kind']=='ballBall')
    assert set(first_hit['balls'])=={CUE,'_1'}
    assert any(e['kind']=='cushion' and e['time']>first_hit['time'] for e in r['events'])
    if teaching:
        assert all(0<=e['index']<6 for e in r['events'] if e['kind']=='cushion')
        assert all(math.dist(ps[k],q['positions'][k])<1e-5 for k in ['_8','_9'])
    assert set(r['tracks'])==set(ps)
    for k,track in r['tracks'].items():
        assert math.dist(track[0][1:],q['positions'][k])<1e-5
        assert math.dist(track[-1][1:],ps[k])<1e-4
        assert all(x[0]<=y[0] for x,y in zip(track,track[1:]))
    full,intervals,half=proof(c,bs,t)
    assert full==r['occlusion']['full']
    assert len(intervals)==len(r['occlusion']['intervals'])
    for x,y in zip(intervals,r['occlusion']['intervals']):assert max(abs(a-b) for a,b in zip(x,y))<1e-5
    assert abs(half-r['occlusion']['halfAngle'])<1e-6
    rays=sweep(c,bs,t)
    if required:assert full
    if full:
        assert rays==0 and r['defenseScore']==100 and not r['opportunities']
    for o in r['opportunities']:
        for k,v in comfort(c,t,o['aim']).items():assert abs(v-o[k])<2e-4
    return rays

checks=[]
for q in rows:
    positions(q['positions']);assert q['ownKey']=='_1' and q['enemyKey']=='_9' and q['blackKey']=='_8'
    source=q['sourceProposal'];p=ROOT/source['source']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==source['sourceSHA256']
    original=next(r for r in json.loads(p.read_text()) if r['id']==source['sourceID'])
    assert original['positions'][CUE]==source['cue'] and original['positions'][original['ownKey']]==source['own'] and original['reference']['shot']==source['shot']
    ps=q['positions'];c,b,t=ps[CUE],ps['_1'],ps['_9']
    assert 0<=q['openingComfort']<=40 and q['exactReplay']
    assert sweep(c,[b,ps['_8']],t)>4097/2
    assert max(o['score'] for o in q['openingOpportunities'])==q['openingComfort']
    for o in q['openingOpportunities']:
        for k,v in comfort(c,b,o['aim']).items():assert abs(v-o[k])<2e-4
    audit(q,q['reference'],True,True)
    f=q['reference']['positions'];fc,ft=f[CUE],f['_9'];solos={k:sweep(fc,[f[k]],ft) for k in ['_1','_8']}
    if q['family']=='own':assert solos['_1']==0 and solos['_8']>0
    elif q['family']=='black':assert solos['_8']==0 and solos['_1']>0
    else:assert all(v>4097*.05 for v in solos.values())
    # Reflect the complete scene; continuous coverage and ray results are invariant.
    mirror=lambda p:[-p[0],p[1]]
    assert proof(mirror(fc),[mirror(f[k]) for k in ['_1','_8']],mirror(ft))[0]
    assert sweep(mirror(fc),[mirror(f[k]) for k in ['_1','_8']],mirror(ft))==0
    assert len(q['perturbations'])==8
    for p in q['perturbations']:assert 'rejection' not in p;audit(q,p['result'],True,True)
    assert audit(q,q['comparison'])>4097/4
    stress={tier:dict(full=0,exposed=0,rejected=0,unproven=0) for tier in ['medium','wide']}
    assert len(q['stressProbes'])==16
    for p in q['stressProbes']:
        s=stress[p['tier']]
        if 'rejection' in p:s['rejected']+=1;continue
        r=p['result'];rays=audit(q,r)
        s['full' if r['occlusion']['full'] else ('exposed' if rays else 'unproven')]+=1
    q['stressCounts']=stress
    checks.append(dict(id=q['id'],family=q['family'],passed=True,soloExposedRays=solos,combinedExposedRays=0,testedRays=4097,smallProbes=8,stress=stress))

# Byte-verify frozen source archive, allowing only the documented @main replacement.
manifest=json.loads((OUT/'source-manifest.json').read_text());verified=0
with tarfile.open(OUT/'source-snapshot.tar.gz') as tar:
    for relative,expected in manifest.items():
        data=tar.extractfile('sources/'+relative.removeprefix('QiuJi/')).read()
        if relative.endswith('/QiuJiApp.swift'):data=data.replace(b'// Research worker supplies main',b'@main')
        assert hashlib.sha256(data).hexdigest()==expected,relative
        verified+=1
    assert tar.extractfile('main.swift').read()==Path(__file__).with_name('main.swift').read_bytes()


def zoom(q):
    ps=q['reference']['positions'];used=['_1'] if q['family']=='own' else ['_8'] if q['family']=='black' else ['_1','_8']
    show=[CUE,*used,'_9'];c,t=ps[CUE],ps['_9'];bs=[ps[k] for k in used]
    xs=[ps[k][0] for k in show];zs=[ps[k][1] for k in show]
    mx,mz=(min(xs)+max(xs))/2,(min(zs)+max(zs))/2
    scale=min(300/(max(zs)-min(zs)+.22),460/(max(xs)-min(xs)+.22))
    def project(p):return 190+(p[1]-mz)*scale,312-(p[0]-mx)*scale
    s='<rect x="27" y="56" width="326" height="525" rx="16" fill="#e7eee4"/>'
    for p in [*bs,t]:
        x,y=project(p);s+=f'<circle cx="{x}" cy="{y}" r="{2*R*scale}" fill="none" stroke="#b26450" stroke-width="1.3" stroke-dasharray="5 4"/>'
    a=math.atan2(t[1]-c[1],t[0]-c[0]);half=math.asin(2*R/math.dist(c,t))
    for f in [-1,-.5,0,.5,1]:
        angle=a+half*f;td=first(c,t,angle);bd=min(first(c,b,angle) for b in bs)
        assert bd<td
        end=[c[0]+td*math.cos(angle),c[1]+td*math.sin(angle)]
        stop=[c[0]+bd*math.cos(angle),c[1]+bd*math.sin(angle)]
        x1,y1=project(c);x2,y2=project(end);x3,y3=project(stop)
        s+=f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#bb6858" stroke-dasharray="4 4" stroke-width="1.2"/>'
        s+=f'<line x1="{x1}" y1="{y1}" x2="{x3}" y2="{y3}" stroke="#b84030" stroke-width="1.6"/>'
    for k in show:s+=ball(k,ps[k],project,scale)
    s+=text(190,610,'完整直击角域已检查，含两球间隙',16,anchor='middle')
    s+=text(190,638,'虚线圆计入母球半径；非球体大小',14,anchor='middle')
    return s

cards=[]
for q in rows:
    heading=f"{q['id']} · {NAMES[q['family']]}"
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="870"><rect width="1200" height="870" fill="#f5f7f2"/>'
    svg+=text(32,39,heading,27,weight=650)
    svg+=text(32,70,f"我方1号 · 对方9号 · 公共8号暂不可首碰  |  开局进攻舒适度 {opening_label(q['openingComfort'])}/100",17)
    for i,(title,body) in enumerate([('开局 · 先考虑怎样做遮挡',panel(q)),('参考打法 · 引擎模拟轨迹',panel(q,q['reference'])),('停稳遮挡检查 · 局部放大',zoom(q))]):
        svg+=f'<g transform="translate({400*i},90)">'+text(190,12,title,19,weight=600,anchor='middle')+body+'</g>'
    shot=q['reference']['shot'];spin='中杆' if shot['spinY']==0 else '高杆' if shot['spinY']>0 else '低杆'
    svg+=text(32,773,f"参考：{spin} · 杆速 {shot['speed']:.2f} m/s · 无侧塞",18,weight=550)
    svg+=text(610,773,'完整直击遮挡100 · 8次小幅微调仍挡住',20,weight=650)
    svg+=text(32,814,'浅蓝：母球轨迹 · 黄色：1号轨迹 · 虚圈：起点 · 实心球：停点；8号、9号保持原位',16)
    svg+=text(32,844,f"较大微调仍挡住：±0.3°/±10% {q['stressCounts']['medium']['full']}/8；±0.6°/±15% {q['stressCounts']['wide']['full']}/8。仅为有限探针，不是成功率。",16)+'</svg>'
    (OUT/f"{q['id']}.svg").write_text(svg)
    subprocess.run(['rsvg-convert',str(OUT/f"{q['id']}.svg"),'-o',str(OUT/f"{q['id']}.png")],check=True)
    for kind,shot in [('opening',None),('comparison',q['comparison'])]:
        title='开局 · 先考虑怎样做遮挡' if kind=='opening' else '同一开局 · 没有挡严的合法杆'
        picture='<svg xmlns="http://www.w3.org/2000/svg" width="400" height="730"><rect width="400" height="730" fill="#f5f7f2"/>'+text(190,28,title,18,weight=600,anchor='middle')+f'<g transform="translate(0,15)">{panel(q,shot)}</g></svg>'
        (OUT/f"{q['id']}-{kind}.svg").write_text(picture)
        subprocess.run(['rsvg-convert',str(OUT/f"{q['id']}-{kind}.svg"),'-o',str(OUT/f"{q['id']}-{kind}.png")],check=True)
    explanation={'own':'先合法碰1号，再让1号处于母球与9号之间。8号在场，但不是这杆的主要挡球。','black':'先合法碰1号，再把母球送到8号的遮挡范围内；8号保持原位。','joint':'先合法碰1号，再让1号和8号共同封住9号的直击角域；单独任一颗都不能挡严。'}[q['family']]
    check=next(r for r in checks if r['id']==q['id'])
    solo='；'.join(f"仅保留{k[1:]}号作挡球：4097条射线中{v}条可接触9号" for k,v in check['soloExposedRays'].items())
    cards.append(f'<article><h2>{heading}</h2><p>{explanation}</p><img class="small" src="{q["id"]}-opening.svg" alt="开局球形"/><details><summary>查看参考打法与遮挡检查</summary><a href="{q["id"]}.png"><img src="{q["id"]}.svg" alt="{heading}"/></a><p>{solo}；两球同时保留：0条可接触。该单球移除仅为停稳几何分析，不是另一杆物理模拟。</p><p>8次小幅扰动均合法且完整遮挡，参考和小扰动均不涉及袋角；较大扰动统计见图。不代表实台概率。</p><details><summary>查看同一开局的合法露球对照</summary><img class="small" src="{q["id"]}-comparison.svg" alt="没有挡严的实际模拟杆"/></details></details></article>')
(OUT/'review.html').write_text(f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>三球纯防守 · 利用球做遮挡</title><style>body{{font-family:{FONT};max-width:1200px;margin:32px auto;padding:0 20px;background:#f5f7f2;color:#193731;line-height:1.65}}article{{padding:22px;background:white;border:1px solid #dbe3da;border-radius:16px;margin:24px 0}}img{{width:100%;height:auto}}.small{{max-width:400px}}summary{{cursor:pointer;font-weight:600;color:#14664c}}a{{color:#14664c}}</style><h1>三球纯防守：双方各剩一颗，加8号</h1><p>我方1号、对方9号、公共8号；母球不计入三颗目标球。本杆必须先碰1号，无球入袋且首碰后有球碰库；9号仍在桌面，对方下一杆合法目标只有9号。</p><p>开局己方最佳直接进攻舒适度≤40，先练如何创造遮挡。本批使用现成8号挡球，参考及小扰动中8号、9号均不移动；碰撞移动8号另作后续题型。</p><p>完整遮挡100只表示没有直线首先碰到9号的方向，不代表对方无法吃库解球，也不是题目难度。联合遮挡用连续角域并集证明，再扫4097条射线交叉核验，不能只验中心线或两个边界。</p>{''.join(cards)}<p>基于动作库c060的利用球遮挡思路继续研究，球形为新生成。冻结生产引擎模拟；离线图册，非App截图。未接入App、未做实台校准。</p></html>''')
report=dict(passed=True,questions=len(rows),checks=checks,geometryCounterexamples=4,verifiedFrozenSwiftFiles=verified,exactReplays=len(rows),smallProbeCount=8*len(rows),stressProbeCount=16*len(rows),scope='frozen physics and independent geometry, not App/real-table acceptance')
(OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
(OUT/'review-source.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__),ROOT/'research/defense-pilot-20261103/review.py',ROOT/'research/defense-two-expand-20261103/review.py']},indent=2))
print(json.dumps(dict(audit='PASS',questions=len(rows),review=str(OUT/'review.html')),ensure_ascii=False))
