from pathlib import Path
import sys,json,html,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-85-validation-20261106'
sys.path.insert(0,str(ROOT/'research/defense-threshold-comparison-20261105'))
import geometric_table as g
from matplotlib.collections import PolyCollection
plt=g.plt;np=g.np;bg='#f4f5f0';ink='#173b32'
cases=json.loads((OUT/'scenario.json').read_text())['cases'];validation=json.loads((OUT/'validation.json').read_text());assert validation['passed']
colors=['#d6dc7a','#f3b955','#e67967'];recommend=[]
def branch(e):
 if e.get('fullDirectBlock') or e.get('potContactsBlocked'):return '封锁'
 if e.get('estimateReason'):return '估算'
 if (e.get('pipeRoute') or {}).get('zeroWidthEstimate'):return '0°估算'
 return '公式'
def rank(r):return (r['effort'],r['shot']['speed'],sum(e['kind']=='cushion' for e in r['events']),r['id'])
def draw(ax,c,r=None):
 g.table(ax);scan=json.loads((OUT/c['label']/'scan-adaptive.json').read_text());verts=[];cs=[]
 for row in scan['rows']:
  v=row.get('score',-1)
  if v<75:continue
  x,z,x1,z1=row['bounds'];verts.append([(x,z),(x1,z),(x1,z1),(x,z1)]);cs.append(colors[0 if v<80 else 1 if v<85 else 2])
 coll=PolyCollection(verts,facecolors=cs,edgecolors='none',alpha=.65,zorder=2.5);ax.add_collection(coll);coll.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))
 circle=g.Circle(c['target'],.3,facecolor='#d0e0d4',edgecolor='#6d8175',linestyle='--',linewidth=.8,zorder=2.7);ax.add_patch(circle);circle.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))
 if r:
  hit=next(e['time'] for e in r['events'] if e['kind']=='ballBall');cue=np.array(r['tracks']['cueBall']);obj=np.array(r['tracks']['_8'])
  for p,col,ls in [(cue[cue[:,0]<=hit+1e-5],'white','-'),(cue[cue[:,0]>=hit-1e-5],'white','--'),(obj,'#16211e','--')]:
   if len(p)>1:
    ax.plot(p[:,1],p[:,2],color='#cde5df' if col!='white' else '#365546',lw=3.0,ls=ls,alpha=.8,zorder=5)
    ax.plot(p[:,1],p[:,2],color=col,lw=1.6,ls=ls,zorder=6)
  for key,col in [('cueBall','white'),('_8','#17221d')]:ax.add_patch(g.Circle(r['finalPositions'][key],g.R,fill=False,ec=col,lw=2,zorder=13))
  for p in r['probes']:
   if p.get('finalPositions'):
    for key,col in [('cueBall','white'),('_8','#111f1b')]:ax.scatter(*p['finalPositions'][key],s=11,color=col,marker='+',zorder=12)
 q=c['question'];g.ball(ax,q['cue'],0)
 for b in q['balls']:g.ball(ax,b['position'],b['number'])

def fmt(v):return '未知' if v is None else f'{v:.3f}°'
for c in cases:
 d=OUT/c['label'];data=json.loads((d/'routes.json').read_text());routes=data['routes'];bands=json.loads((d/'region-bands.json').read_text());b80=next(b for b in bands if b['threshold']==80)
 bests={str(t):min((r for r in routes if t in r['stableThresholds']),key=rank,default=None) for t in [75,80,85]}
 primary=bests['80'] or bests['75'];goal=80 if bests['80'] else (75 if primary else None)
 radius=max((b['sampledCoreRadius'] for b in b80['blocks']),default=0)
 recommend.append({'label':c['label'],'routeID':primary['id'] if primary else None,'goal':goal,'bestByThreshold':{t:r['id'] if r else None for t,r in bests.items()},'area80CM2':b80['area']*10000,'largestSampledCoreDiameter80CM':radius*200,'ownBefore':data['ownBefore']['bestClearDegrees']})
 for r in routes:
  fig,ax=plt.subplots(figsize=(12,8));fig.patch.set_facecolor(bg);fig.subplots_adjust(left=.04,right=.96,bottom=.25,top=.85);draw(ax,c,r)
  s=r['shot'];worst=min(p['score'] for p in r['probes']);cushions=sum(e['kind']=='cushion' for e in r['events'])
  ax.set_title(f"{c['label']} 路线{r['id']} · 防守 {r['effect']['score']:.1f}分（{branch(r['effect'])}）",loc='left',fontsize=18,color=ink)
  fig.text(.04,.94,f"85分档验证 · 初始区域峰值 {c['maximum']:.2f}分",fontsize=19,color=ink)
  fig.text(.04,.18,f"切角{s['cutDegrees']}°  杆速{s['speed']:.3f}  打点({s['spinX']:+.2f}, {s['spinY']:+.2f})  两球合计吃库{cushions}次\n8号已确认窗口：{fmt(r['ownBefore']['bestClearDegrees'])} → {fmt(r['ownAfter']['bestClearDegrees'])}\n四次扰动最低防守{worst:.1f}分；稳定达标档："+'/'.join(str(int(t)) for t in r['stableThresholds']),fontsize=12,color='#355950')
  fig.text(.04,.04,'白实线：母球碰撞前；白虚线：碰撞后；黑虚线：8号。空心圈为终点，小十字为扰动终点。\n背景仅固定9号评分：黄75–80，橙80–85，红≥85；灰圈内30cm排除。实际评分另计8号遮挡。\n四次扰动不等于实战成功率；8号窗口不下降是暂用检查，尚不等于绝对舒服。',fontsize=10,color='#49645a')
  fig.savefig(d/f"route-{r['id']:02}.png",dpi=140,facecolor=bg);plt.close(fig)
 # Each case gets a standalone primary result, including an explicit no-solution card.
 fig,ax=plt.subplots(figsize=(12,7.2));fig.patch.set_facecolor(bg);fig.subplots_adjust(left=.04,right=.96,top=.83,bottom=.21);draw(ax,c,primary)
 title=(f"{goal}分目标：找到四次扰动通过的路线" if primary else '本轮未找到联合达标路线')
 ax.set_title(f"{c['label']} · {title}",loc='left',fontsize=17,color=ink)
 fig.text(.04,.94,f"初始峰值{c['maximum']:.2f}分 · ≥80分区域约{b80['area']*10000:.0f}cm²",fontsize=19,color=ink)
 if primary:
  r=primary;s=r['shot'];text=f"防守{r['effect']['score']:.1f}分；四次扰动最低{min(p['score'] for p in r['probes']):.1f}分\n杆速{s['speed']:.3f}；打点({s['spinX']:+.2f}, {s['spinY']:+.2f})；8号窗口{fmt(r['ownBefore']['bestClearDegrees'])} → {fmt(r['ownAfter']['bestClearDegrees'])}"
 else:text='有界搜索未找到，不代表物理上无解。\n继续区分：区域较窄、现有方向/力度采样、8号窗口保留条件。'
 fig.text(.04,.13,text,fontsize=12,color='#355950')
 fig.text(.04,.035,'黄色75–80／橙色80–85／红色≥85；灰圈内30cm不统计。白线母球、黑线8号；空心终点。\n背景无8号遮挡；路线按完整物理终态计分。四次扰动不是成功率，窗口不下降不是绝对舒服。',fontsize=10,color='#49645a')
 fig.savefig(d/'recommended.png',dpi=140,facecolor=bg);plt.close(fig)

fig,axes=plt.subplots(5,2,figsize=(14,23));fig.patch.set_facecolor(bg);fig.subplots_adjust(top=.93,bottom=.07,left=.03,right=.97,hspace=.35,wspace=.08)
for ax,c,row in zip(axes.flat,cases,recommend):
 data=json.loads((OUT/c['label']/'routes.json').read_text());r=next((x for x in data['routes'] if x['id']==row['routeID']),None);draw(ax,c,r)
 ax.set_title(f"{c['label']} · "+(f"{row['goal']}分目标通过" if r else '本轮未找到'),loc='left',fontsize=13,color=ink)
 note=f"≥80区域约{row['area80CM2']:.0f}cm²"
 if r:note+=f"  ·  实际防守{r['effect']['score']:.1f}\n8号窗 {fmt(r['ownBefore']['bestClearDegrees'])} → {fmt(r['ownAfter']['bestClearDegrees'])}"
 else:note+='\n暂无满足防守、四次扰动及8号窗口条件的代表'
 ax.text(.01,-.03,note,transform=ax.transAxes,fontsize=9,color='#355950',va='top')
fig.text(.04,.975,'85分档 · 十个球形的路线验证',fontsize=24,color=ink)
fig.text(.04,.95,'优先80分目标；75分结果单列。背景为固定9号评分，实际路线另计8号遮挡。',fontsize=12,color='#355950')
fig.text(.04,.025,'黄色75–80，橙色80–85，红色≥85；灰圈内30cm排除。白线母球、黑线8号，空心圈终点。\n四次方向/力度扰动通过不等于实战成功率；本轮未找到不等于无解。',fontsize=11,color='#49645a')
fig.savefig(OUT/'overview.png',dpi=140,facecolor=bg);plt.close(fig)
(OUT/'recommendations.json').write_text(json.dumps(recommend,ensure_ascii=False,indent=2))
parts=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>85分档防守验证</title><style>body{font-family:system-ui;background:#f4f5f0;color:#173b32;max-width:1200px;margin:auto;padding:24px}img{width:100%}a{color:#176760}p{line-height:1.7}section{border-top:1px solid #acb9af;margin-top:30px;padding-top:20px}</style><h1>85分档 · 十个球形的路线验证</h1><p>优先寻找80分目标的简单打法；75分结果另列。四次扰动为方向±0.1°、杆速±5%，分别测试；未测真实成功率。8号暂以已确认进球窗口不下降为检查，不最大化窗口，也不等同绝对舒服。</p>']
md=['# 85分档十例路线验证','','按现行评分和完整物理终态验证；80分为主目标，75/85为诊断。四次扰动分别为方向±0.1°、速度±5%；我方8号已确认窗口暂要求不下降，不最大化。','','| 球形 | ≥80区域cm² | 主结果 | 8号初始窗口 |','|---|---:|---|---:|']
for c,row in zip(cases,recommend):
 label=c['label'];status=f"{row['goal']}分目标通过" if row['goal'] else '本轮未找到';md.append(f"| [{label}]({label}/recommended.png) | {row['area80CM2']:.0f} | {status} | {fmt(row['ownBefore'])} |")
 parts.append(f'<section><h2>{label} · {status}</h2><a href="{label}/recommended.png"><img src="{label}/recommended.png"></a>')
 routes=json.loads((OUT/label/'routes.json').read_text())['routes']
 for r in routes:parts.append(f'<p><a href="{label}/route-{r["id"]:02}.png">路线{r["id"]} · 防守{r["effect"]["score"]:.1f} · 达标档 {r["stableThresholds"]}</a></p>')
 parts.append('</section>')
parts.append('</html>');(OUT/'index.html').write_text('\n'.join(parts));(OUT/'report.md').write_text('\n'.join(md)+'\n')
print('Rendered',sum(len(json.loads((OUT/c['label']/'routes.json').read_text())['routes']) for c in cases),'route images and ten result cards')
