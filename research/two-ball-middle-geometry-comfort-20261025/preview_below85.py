"""Read-only five-route review from retained sub-85 comfort scores."""
from prepare import *
import importlib.util,math,shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle
from matplotlib.font_manager import fontManager
from audit_report import recompute

DEST=OUT/'below85-five'
NAMES=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
BG='#f6f8f1';GREEN='#254c3d';BLUE='#1683ac';ORANGE='#ce8b18';RED='#b95042'
FIELDS=['distanceScore','spaceScore','angleScore']
LABELS=['球距分','出杆空间分','角度分']
fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False,'font.size':12})

def table(ax,g,s):
    hx=g['length']/2;hz=g['width']/2;r=g['radius'];q=s['score'];stop=np.array(q['stop']);b=np.array(s['position']);board=s['board']
    ax.set_facecolor('#dfecd9')
    for l in g['lines']:
        ax.plot([l['start']['x'],l['end']['x']],[l['start']['z'],l['end']['z']],color=GREEN,lw=2)
    for a in g['arcs']:
        lo=a['start'];hi=a['end'];hi+=2*math.pi if hi<lo else 0;t=np.linspace(lo,hi,40)
        ax.plot(a['center']['x']+a['radius']*np.cos(t),a['center']['z']+a['radius']*np.sin(t),color=GREEN,lw=2)
    for i,p in enumerate(g['pockets']):
        lip=np.array([[v['x'],v['z']] for v in p['lip']]);ax.fill(lip[:,0],lip[:,1],color='#9fb8a3')
        ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius'],color=GREEN))
        if i==q['pocket']:ax.add_patch(Circle((p['center']['x'],p['center']['z']),p['radius']+.014,fill=False,color=ORANGE,lw=3))
    anchors=[[-hx+r,-hz+r],[hx-r,-hz+r],[-hx+r,hz-r],[hx-r,hz-r],[0,-hz],[0,hz]]
    aim=np.array(anchors[q['pocket']]);d=aim-b;d/=np.linalg.norm(d);ghost=b-2*r*d
    ax.plot([stop[0],ghost[0]],[stop[1],ghost[1]],ls='--',color=RED,lw=1.6,zorder=3)
    ax.plot([b[0],aim[0]],[b[1],aim[1]],ls='--',color=ORANGE,lw=2,zorder=3)
    path=np.array(s['route']['trajectory2mm']['points'])[:,1:3]
    ax.plot(path[:,0],path[:,1],color=BLUE,lw=1.7,alpha=.8,zorder=2)
    delta=np.linalg.norm(np.diff(path,axis=0),axis=1);idx=int(np.argmax(delta));a=path[idx];z=path[idx+1]
    ax.annotate('',xy=a+.65*(z-a),xytext=a+.45*(z-a),arrowprops={'arrowstyle':'->','color':BLUE,'lw':1.8})
    ax.plot([board['cue'][0],path[0,0]],[board['cue'][1],path[0,1]],color='#98a99c',ls=':',lw=1)
    for pos,color,label in [(board['cue'],'#ffffff','C₀'),(board['object'],'#efc469','A'),(b,BLUE,'B')]:
        ax.add_patch(Circle(pos,r,facecolor=color,edgecolor=GREEN,zorder=5));ax.text(*pos,label,color='white' if label=='B' else GREEN,ha='center',va='center',fontsize=9,zorder=6)
    ax.add_patch(Circle(stop,r,facecolor='white',edgecolor=RED,lw=2.5,zorder=7))
    ax.annotate('母球停点',xy=stop,xytext=(stop[0]+(.22 if stop[0]<0 else -.22),stop[1]+(.16 if stop[1]<0 else -.16)),color=RED,fontsize=12,ha='center',arrowprops={'arrowstyle':'-','color':RED},bbox={'fc':BG,'ec':'none','pad':2},zorder=8)
    # Mark the surface-to-rectangular-rail gap used by the approved space formula.
    gaps=np.array([hx-stop[0]-r,hx+stop[0]-r,hz-stop[1]-r,hz+stop[1]-r]);i=int(np.argmin(gaps));normal=np.array([[1,0],[-1,0],[0,1],[0,-1]])[i]
    edge=stop+normal*r;rail=edge+normal*gaps[i]
    if gaps[i]<.15:
        ax.plot([edge[0],rail[0]],[edge[1],rail[1]],color='#728177',ls=':',lw=1.4,zorder=8)
    ax.set(xlim=(-hx-.10,hx+.10),ylim=(hz+.13,-hz-.13));ax.set_aspect('equal');ax.set_xticks([]);ax.set_yticks([])

def main():
    selection=read(DEST/'selection.json');g=read(OUT/'geometry.json');summary=read(OUT/'summary.json');assert summary['auditPassed']
    index={p['stem']:p for p in read(OUT/'parts-index.json')};samples=[];hashes={}
    for n,s in enumerate(selection['samples'],1):
        q=s['score'];assert q['totalScore']<85
        for folder in ['final','scores']:
            path=OUT/folder/(s['stem']+'.jsonl.gz');assert sha(path)==index[s['stem']][folder+'SHA256'];hashes[str(path)]=sha(path)
        row=next(r for r in rows(OUT/'final'/(s['stem']+'.jsonl.gz')) if r['id']==s['id']);sc=next(r for r in rows(OUT/'scores'/(s['stem']+'.jsonl.gz')) if r['id']==s['id'])
        cand=next(c for c in row['candidates'] if c['cellID']==s['cellID']);scorecand=next(c for c in sc['candidates'] if c['cellID']==s['cellID']);assert q in scorecand['recommendations']
        origq=next(x for x in cand['top5'] if x['comboIndex']==q['comboIndex'] and x['pocket']==q['pocket']);route=next(r for r in row['routes'] if r['comboIndex']==q['comboIndex']);assert route['cueStop']==q['stop'] and cand['position']==s['position']
        points=np.array(route['trajectory2mm']['points']);assert np.max(np.abs(points[-1,1:3]-q['stop']))<1e-6
        values=recompute(g,np.array([q['stop']]),np.array([s['position']]),np.array([q['pocket']]))[0];assert np.max(np.abs(values-np.array([q[k] for k in FIELDS+['totalScore']])))<1e-8
        dominant=LABELS[int(np.argmin(values[:3]))];lo,hi=q['preferredMeters'];dist=q['distanceMeters']
        causes=[]
        if q['distanceScore']<85:causes.append('母球与B偏近' if dist<lo else '母球与B偏远' if dist>hi else '球距')
        if q['spaceScore']<85:causes.append('停点靠库，出杆空间扣分')
        if q['angleScore']<85:causes.append('切角偏大')
        s={**s,'number':n,'board':row['board'],'route':route,'recommendation':origq,'reason':'；'.join(causes) or f'{dominant}最低','dominant':dominant}
        samples.append(s)
        fig=plt.figure(figsize=(15,8),facecolor=BG);ax=fig.add_axes([.035,.28,.66,.57]);table(ax,g,s)
        ax.set_title('原走位轨迹与第二杆停点',fontsize=13,pad=12)
        bars=fig.add_axes([.765,.39,.20,.38]);vals=[q[k] for k in FIELDS]
        bars.barh([2,1,0],vals,color=[BLUE,ORANGE,'#8465b0'],height=.55)
        for y,v in zip([2,1,0],vals):bars.text(min(v+2,102),y,f'{v:.1f}',va='center',fontsize=13)
        bars.set(xlim=(0,118),yticks=[2,1,0],yticklabels=LABELS,xticks=[0,50,100]);bars.spines[['top','right']].set_visible(False);bars.grid(axis='x',alpha=.15);bars.set_axisbelow(True)
        fig.suptitle(f'样本 {n} · 总分 {q["totalScore"]:.1f} / 100 · {s["reason"]}',fontsize=21,y=.97)
        fig.text(.04,.90,f'B{s["cellID"]} → {NAMES[q["pocket"]]}  |  原推荐第{q["originalRank"]}条  |  {s["id"]}',fontsize=12,color='#5b7061')
        fig.text(.73,.29,f'本题最高分 {s["bestQuestionScore"]:.1f}\n本题已有其他≥85分路线',fontsize=13,color=GREEN)
        fig.text(.04,.21,f'母球到B：{dist*100:.1f} cm    满分球距：{lo*100:.0f}–{hi*100:.0f} cm    母球球面离库：{q["gapMeters"]*100:.2f} cm    第二杆切角：{q["angleDegrees"]:.2f}°',fontsize=13)
        fig.text(.04,.15,f'首杆速度 {route["velocity"]:.3f} m/s · 打点（{route["spinX"]:+.3f}, {route["spinY"]:+.3f}） · 原组合 {q["comboIndex"]}',fontsize=11,color='#5b7061')
        fig.text(.04,.09,'蓝实线：保存的碰A后母球轨迹；红圈：母球停点；红虚线：第二杆瞄准方向；橙虚线/圈：B进球方向/目标袋。',fontsize=11)
        fig.text(.04,.045,'C₀、A仅为初始位置参考，第二杆时A已入袋。总分为三项等权几何平均，不是进球概率；本次未改题库、未优化。',fontsize=11,color='#5b7061')
        for ext in ['png','svg']:fig.savefig(DEST/f'sample-{n}.{ext}',dpi=140)
        plt.close(fig)
    write(DEST/'data.json',dict(geometry=g,selection=selection,samples=samples))
    cards=[]
    for s in samples:
        q=s['score'];n=s['number']
        cells=''.join(f'<td>{q[k]:.1f}</td>' for k in FIELDS+['totalScore'])
        cards.append(f'<section id="sample-{n}"><h2>样本{n} · {q["totalScore"]:.1f}分 · {s["reason"]}</h2><a href="sample-{n}.svg" target="_blank"><img src="sample-{n}.png" alt="样本{n}原路线与三项评分：{s["reason"]}"></a><table><tr><th>球距分</th><th>出杆空间分</th><th>角度分</th><th>总分</th><th>同题最高分</th></tr><tr>{cells}<td>{s["bestQuestionScore"]:.1f}</td></tr></table></section>')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>85分以下的原路线 · 随机五例</title><style>body{margin:0;background:#f6f8f1;color:#243f32;font:17px/1.8 system-ui}main{max-width:1450px;margin:auto;padding:24px}section{scroll-margin-top:85px;background:white;padding:20px;border:1px solid #ccd8c9;margin:28px 0;border-radius:12px}img{width:100%;display:block}nav{position:sticky;top:0;background:#f6f8f1f5;padding:12px 24px;display:flex;gap:24px;flex-wrap:wrap;z-index:3;border-bottom:1px solid #ccd8c9}a{color:#276b55}table{width:100%;border-collapse:collapse}td,th{padding:12px;border:1px solid #ccd8c9;text-align:center}td:nth-child(4){font-weight:bold;color:#b95042}h1{line-height:1.4}@media(max-width:650px){main,section{padding:10px}td,th{padding:6px;font-size:13px}}</style><nav>'''+''.join(f'<a href="#sample-{i}">样本{i}</a>' for i in range(1,6))+'''<a href="../comfort-middle-geometry/">全量统计</a></nav><main><h1>85分以下的原路线 · 随机五例</h1><p>从中袋过滤后222,917条低于85分的推荐中等概率随机抽5条，恰好来自5个不同球形。保留抽样原顺序，不按原因或分数挑选。</p><p><b>这5条都低于85分，但这5道题都有其他合格路线。</b>每张图同时标出同题最高分，避免把低分路线误认为整题不合格。总分=∛（球距分×出杆空间分×角度分）；85分仍是讨论中的处理门槛。</p><p>5例角度分均为100，主要扣分在球距和出杆空间。图上距离/离库按现行评分口径；蓝线取原保存的2mm关键点，无新物理模拟。点击图片打开SVG可放大查看。</p>'''+''.join(cards)+f'<p>抽样种子 {selection["seed"]} · <a href="selection.json">抽样记录</a> · <a href="data.json">完整原轨迹和分项数据</a></p></main></html>'
    (DEST/'index.html').write_text(page)
    write(DEST/'verification.json',dict(passed=True,samples=5,sourceHashes=hashes,allBelow85=True,allOriginalRoutesAndStops=True,independentScoreRecompute=True,endpointMatches=True,allQuestionsHaveOtherQualifyingRoutes=all(s['bestQuestionScore']>=85 for s in samples),corpusChanged=False))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-below85-five';served.mkdir(exist_ok=True)
    for p in DEST.iterdir():
        if p.is_file():shutil.copy2(p,served/p.name)
    print(json.dumps([dict(sample=s['number'],score=s['score']['totalScore'],reason=s['reason']) for s in samples],ensure_ascii=False))

if __name__=='__main__':main()
