from pathlib import Path
import json,math,csv,hashlib
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.patches import Circle
from matplotlib.backends.backend_pdf import PdfPages
import geometric_table as g

out=g.OUT;plt=g.plt
config=json.loads((out/'scenario.json').read_text());inputs={x['label']:x for x in config['cases']}
selected=json.loads((out/'selected.json').read_text())
checks=[];summary=[]

def score_label(score):
    return "≈100" if 99.95 <= score < 100 else f"{score:.1f}"

def overlay(ax,scan,alpha=.45):
    vertices=[];colors=[]
    for r in scan['rows']:
        if r.get('score',-1)<90:continue
        x,z,x1,z1=r['bounds'];vertices.append([(x,z),(x1,z),(x1,z1),(x,z1)])
        colors.append('#ffc247' if r['score']<95 else '#f38b45')
    p=PolyCollection(vertices,facecolors=colors,edgecolors='none',alpha=alpha,zorder=2.5);ax.add_collection(p)
    p.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))

def initial(ax,label,scan):
    g.table(ax);overlay(ax,scan,.7);q=inputs[label]['question']
    g.ball(ax,q['cue'],0)
    for b in q['balls']:g.ball(ax,b['position'],b['number'])
    ax.set_title(label+'  初态＋母球目标区域',loc='left',fontsize=14,pad=6,color='#193a35')

def shot(ax,label,scan,route):
    g.table(ax);overlay(ax,scan)
    if route is None:
        ax.text(0,0,'本轮有限搜索未找到合格轨迹',ha='center',color='white',fontsize=13);return
    q=inputs[label]['question'];hit=next(e['time'] for e in route['events'] if e['kind']=='ballBall')
    tracks=route['tracks'];cuekey=next(k for k in tracks if not k.startswith('_'))
    cue=np.array(tracks[cuekey]);obj=np.array(tracks['_8'])
    before=cue[cue[:,0]<=hit+1e-5];after=cue[cue[:,0]>=hit-1e-5]
    for p,c,style in [(before,'white','-'),(after,'white','--'),(obj,'#16211e','--')]:
        if len(p)>1:
            ax.plot(p[:,1],p[:,2],color='#dae9df' if c!='white' else '#355447',lw=2.7,ls=style,alpha=.65,zorder=5)
            ax.plot(p[:,1],p[:,2],color=c,lw=1.5,ls=style,zorder=6)
    g.ball(ax,q['cue'],0)
    for b in q['balls']:g.ball(ax,b['position'],b['number'])
    for key,color in [(cuekey,'white'),('_8','#17221d')]:
        p=route['finalPositions'][key];ax.add_patch(Circle(p,g.R,fill=False,ec=color,lw=1.7,zorder=12))
    s=route['shot'];grade=route['effect']['score'];side='左侧' if s['side']<0 else '右侧'
    marker="†" if route["effect"].get("pipeRoute",{}).get("zeroWidthEstimate") else ""
    # Side labels are numeric contact branches, not an unverified screen-left assertion.
    ax.set_title(f"轨迹{route['id']}  {s['cutDegrees']}°／接触侧{s['side']:+d}  防守{score_label(grade)}分{marker}",loc='left',fontsize=14,pad=6,color='#193a35')
    ax.text(0,-.035,f"杆速{s['speed']:.2f}  打点({s['spinX']:+.2f}, {s['spinY']:+.2f})  ·  扰动通过{route['probePasses']}/4",transform=ax.transAxes,fontsize=9,color='#526660')

data=[]
for case in selected:
    label=case['label'];q=inputs[label]['question'];folder=out/label
    scan=json.loads((folder/'scan-adaptive.json').read_text());result=json.loads((folder/'routes.json').read_text())
    valid=[r for r in scan['rows'] if 'score' in r]
    def area(r):x,z,x1,z1=r['bounds'];return (x1-x)*(z1-z)
    total=sum(map(area,valid));shares={str(t):100*sum(area(r) for r in valid if r['score']>=t)/total for t in [90,95]}
    assert any(r['score']>=95 for r in valid)
    route_ids=set();signatures=set()
    for route in result['routes']:
        s=route['shot'];assert s['cutDegrees'] in [15,30,45,60] and s['side'] in [-1,1]
        assert abs(route['measuredCutDegrees']-s['cutDegrees'])<=.5
        assert route['baseScore']>=90 and route['effect']['score']>=90 and route['replayVerified']
        target=next(b['position'] for b in q['balls'] if b['number']==9)
        assert math.dist(route['finalPositions']['_9'],target)<1e-6
        assert not any(e['kind']=='pocket' for e in route['events'])
        assert not any('_9' in e.get('balls',[]) for e in route['events'] if e['kind']=='ballBall')
        assert route['signature'] not in signatures;signatures.add(route['signature'])
        final=list(route['finalPositions'].values())
        for i,p in enumerate(final):
            for p2 in final[i+1:]:assert math.dist(p,p2)>=2*g.R-1e-5
        for k,frames in route['tracks'].items():
            assert all(math.isfinite(v) for p in frames for v in p)
            assert all(b[0]>=a[0] for a,b in zip(frames,frames[1:]))
            assert math.dist(frames[-1][1:],route['finalPositions'][k])<1e-5
        effect=route['effect']
        if not effect['fullDirectBlock'] and not effect.get('potContactsBlocked'):
            assert abs(effect['score']-100*math.sqrt((1-effect['comfort']/100)/(1+effect['targetPipeToleranceDegrees'])))<1e-8
    chosen=max(result['routes'],key=lambda r:(r['probePasses'],r['regionMarginMeters'],r['effect']['score']),default=None)
    summary.append({'label':label,'questionID':q['id'],'area90Percent':shares['90'],'area95Percent':shares['95'],'counts':result['counts'],'unique':result['deduplicatedCount'],'retained':len(result['routes']),'cutCounts':{str(a):sum(r['shot']['cutDegrees']==a for r in result['routes']) for a in [15,30,45,60]},'stableFourOfFour':sum(r['probePasses']==4 for r in result['routes']),'seconds':result['seconds'],'overviewRoute':chosen['id'] if chosen else None})
    data.append((label,scan,result,chosen))
    fig,axes=plt.subplots(1,2,figsize=(16,5.8));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.03,right=.97,top=.86,bottom=.16,wspace=.08)
    initial(axes[0],label,scan);shot(axes[1],label,scan,chosen)
    fig.text(.03,.05,'橙黄＝90–95分；橙红＝≥95分（基础图不计8号遮挡）。白线母球／黑线8号；空心圈为终点；†为0°管道分支。',fontsize=11,color='#52665b')
    fig.savefig(folder/'overview.png',dpi=180,facecolor=fig.get_facecolor());plt.close(fig)
    if result['routes']:
        with PdfPages(folder/'routes.pdf') as pdf:
            for route in result['routes']:
                fig,ax=plt.subplots(figsize=(12,7));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.04,right=.96,bottom=.17,top=.88)
                shot(ax,label,scan,route)
                fig.text(.04,.04,f"{label} · 区域块{route['block']} · {', '.join(route['tags']) or '综合困难'} · 基础分{score_label(route['baseScore'])}\n固定9号；完整物理重放与终态精算通过。†为0°管道分支；高分仍需实战校准。",fontsize=11,color='#52665b')
                fig.savefig(folder/f"route-{route['id']:02}.png",dpi=150,facecolor=fig.get_facecolor());pdf.savefig(fig);plt.close(fig)
fig,axes=plt.subplots(len(data),2,figsize=(16,4.6*len(data)));fig.patch.set_facecolor('#f4f5f0');fig.subplots_adjust(left=.035,right=.965,top=.95,bottom=.05,wspace=.07,hspace=.24)
for row,(label,scan,result,chosen) in enumerate(data):initial(axes[row,0],label,scan);shot(axes[row,1],label,scan,chosen)
fig.text(.035,.98,'区域引导防守：5个原始球形与实算轨迹',fontsize=24,color='#173b32')
fig.text(.035,.017,'橙黄90–95／橙红≥95；初态白球、8号、9号保留原位。右图展示实际轨迹，空心圈为终点。\n评分采用现行v8；†为0°管道分支，尚未实战校准；区域格不等同连续安全保证。',fontsize=11,color='#52665b')
fig.savefig(out/'five-cases-overview.png',dpi=150,facecolor=fig.get_facecolor());fig.savefig(out/'five-cases-overview.pdf',facecolor=fig.get_facecolor());plt.close(fig)
(out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
(out/'validation.json').write_text(json.dumps({'passed':True,'cases':len(data),'routesChecked':sum(x['retained'] for x in summary),'checks':['real bank coordinates','all regions include >=95 sample','cut-angle bins and measured cut <=0.5 degree','no pocketing and no opponent contact or displacement','base and actual final scores >=90','production final score formula','dedup signatures unique','full replay matches scoring-only terminal positions','trajectory timestamps finite monotonic and final positions equal','no final ball overlaps'],'geometrySourceHashes':g.checked},indent=2))
print(json.dumps(summary,ensure_ascii=False,indent=2))
