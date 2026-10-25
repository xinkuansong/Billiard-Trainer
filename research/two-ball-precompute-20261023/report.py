#!/usr/bin/env python3
"""Publish saved experiment facts as exportable plots and an offline viewer."""
from pathlib import Path
import csv, html, json, math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle
from matplotlib.colors import ListedColormap

OUT=Path(__file__).resolve().parent
def read(n):return json.loads((OUT/n).read_text())
def pos(d):return [d['x'],d['z']]
plt.rcParams.update({'font.family':'sans-serif','font.sans-serif':['Arial Unicode MS','PingFang SC','DejaVu Sans'],'axes.unicode_minus':False,'font.size':10})
sample=read('sample.json');scan=read('scan-results.json');ranks=read('rankings.json');summary=read('summary.json')
candidates=read('candidates.json');maps={m['id']:m['rows'] for m in read('map-results.json')['maps']}
validation={(x['route'],x['id']):x['rows'] for x in read('validate-results.json')['results']}
names=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
imageDir=OUT/'figures';imageDir.mkdir(exist_ok=True)
radius=scan['radius'];nominalIndex=read('protocol.json')['designOffsets'].index([0,0,0,0])

def table(ax,pk):
    ax.set_facecolor('#f5f8f7')
    ax.add_patch(Rectangle((-1.27,-.635),2.54,1.27,facecolor='#eaf3ef',edgecolor='#38534b',linewidth=8,zorder=0))
    for i,p in enumerate(sample['geometry']['pockets']):
        x,z=pos(p['center']);ax.add_patch(Circle((x,z),p['radius'],facecolor='#dd8d19' if i==pk else '#263833',edgecolor='white',linewidth=1.2,zorder=6))
        ax.text(x,z+(-.075 if z<0 else .095),names[i],ha='center',va='center',fontsize=8,color='#314c42')
    ax.set(xlim=(-1.43,1.43),ylim=(.85,-.85),xlabel='X / m',ylabel='Z / m')
    ax.set_aspect('equal');ax.spines[['top','right']].set_visible(False)
def ball(ax,p,label,color):
    ax.add_patch(Circle(p,radius,facecolor=color,edgecolor='#243730',linewidth=1.2,zorder=10))
    ax.text(p[0],p[1]-.06,label,ha='center',va='bottom',fontweight='bold',color='#1c3129',zorder=12)
def path(ax,points,color,label=None,lw=1.3,ls='-'):
    if points:
        p=np.array(points);ax.plot(p[:,0],p[:,1],color=color,lw=lw,label=label,ls=ls,alpha=.85,zorder=4)

details=[]
for rank in ranks['rankings']:
    route=next(r for r in scan['routes'] if r['id']==rank['route'])
    design=[r for r in scan['rows'] if r['route']==route['id']]
    nominal=next(r for r in design if r['sampleIndex']==nominalIndex)
    counts={int(k):v for k,v in rank['occupiedCells'].items()}
    for c in candidates:
        score=next(s for s in rank['scores'] if s['id']==c['id'])
        metrics=[m for m in summary['metrics'] if m['route']==route['id'] and m['id']==c['id']]
        fig,axes=plt.subplots(1,2,figsize=(14,6.8))
        fig.subplots_adjust(left=.05,right=.99,top=.83,bottom=.26,wspace=.14)
        for ax in axes:table(ax,c['pocket'])
        ax=axes[0]
        mask=np.array([1 if r['pass'] else np.nan for r in maps[c['id']]]).reshape(41,21).T
        ax.imshow(mask,extent=(-1.23,1.23,.63,-.63),origin='upper',cmap=ListedColormap(['#99c9a5']),vmin=0,vmax=1,interpolation='nearest',alpha=.75,zorder=1)
        for k,n in counts.items():
            ix,iz=divmod(k,21);x,z=-1.2+ix*.06,-.6+iz*.06
            if k in score['intersectionCellIDs']:ax.add_patch(Rectangle((x-.03,z-.03),.06,.06,facecolor='#f1c45b',edgecolor='#ab7700',lw=.4,zorder=2))
            ax.scatter([x],[z],s=13+10*n,color='#6847b7',edgecolor='white',lw=.5,zorder=8)
        ball(ax,c['point'],'B','#e29128')
        ax.set_title(f'离散可行图与落点密度｜B#{c["id"]} → {names[c["pocket"]]}',fontsize=11)
        fig.text(.05,.15,'绿：有进球见证的网格中心代理格\n黄：停点占用与可行格的交集\n紫圆大小：落入该格的设计样本数',fontsize=8,va='top')
        ax=axes[1]
        path(ax,nominal.get('cuePath',[]),'#b78525','未放 B 的名义母球轨迹',ls='--')
        path(ax,nominal.get('objectPath',[]),'#bd5a61','名义 A 球轨迹',lw=1)
        valid=[r for r in design if r['accepted']]
        if valid:
            p=np.array([r['stop'] for r in valid]);ax.scatter(p[:,0],p[:,1],s=12,c='#6847b7',alpha=.55,zorder=7,label='首杆有效设计停点')
        rows=validation.get((route['id'],c['id']),[])
        witness=next((r for r in rows if r['complete'] and r['split']=='design' and r['sampleIndex']==nominalIndex),None)
        if witness is None:witness=next((r for r in rows if r['complete'] and r.get('second',{}).get('replay',{}).get('objectPath')),None)
        label='未做完整两杆复验'
        if rows:
            label='本候选复验未找到两杆成功样本'
        if witness:
            path(ax,witness.get('cuePath',[]),'#087f8c','含 B 的成功首杆',lw=1.5)
            path(ax,witness['second']['replay'].get('objectPath',[]),'#d76d08','成功第二杆 B 球',lw=2)
            path(ax,witness['second']['replay'].get('cuePath',[]),'#087f8c','成功第二杆母球',lw=1,ls=':')
            label=f'成功见证：{witness["split"]} 样本 {witness["sampleIndex"]}；并非所有扰动均成功'
        ball(ax,pos(sample['cue']),'C','#fffdf7');ball(ax,pos(sample['target']),'A','#c86d74');ball(ax,c['point'],'B','#e29128')
        ax.set_title('完整开局与真实轨迹',fontsize=11)
        fig.text(.54,.16,label,fontsize=8,va='top')
        handles,legendLabels=ax.get_legend_handles_labels()
        fig.legend(handles,legendLabels,loc='upper center',bbox_to_anchor=(.76,.12),ncol=2,fontsize=8,frameon=False)
        rate=next((m for m in metrics if m['split']=='holdout'),None)
        subtitle=f'交集代理面积 {score["intersectionM2"]*10000:.0f} cm² · 设计检索 {score["coveredSamples"]}/81'
        if rate:subtitle+=f' · 独立复验 {rate["complete"]}/96'
        fig.suptitle(route['label']+f'｜首杆有效 {rank["firstPass"]}/81'+'\n'+subtitle,fontsize=14,color='#18382c',y=.97)
        filename=f'{route["id"]}-{c["id"]}.png';fig.savefig(imageDir/filename,dpi=140,facecolor='white');plt.close(fig)
        details.append({'route':route['id'],**c,**score,'metrics':metrics,'image':'figures/'+filename,'nominalRails':nominal.get('rails',[])})

# Export all ranking and validation rows for reuse.
with (OUT/'ranking-comparison.csv').open('w',newline='') as f:
    writer=csv.writer(f);writer.writerow(['route','targetID','pocket','areaRank','coverageRank','intersectionCm2','retrievalHits81','designComplete81','holdoutComplete96','nominalComplete'])
    for d in details:
        dm=next((m for m in d['metrics'] if m['split']=='design'),{});hm=next((m for m in d['metrics'] if m['split']=='holdout'),{})
        writer.writerow([d['route'],d['id'],d['pocket'],d['areaRank'],d['coverageRank'],d['intersectionM2']*10000,d['coveredSamples'],dm.get('complete',''),hm.get('complete',''),hm.get('nominalComplete','')])

payload={'details':details,'routes':scan['routes'],'rankings':ranks['rankings'],'summary':summary,'pockets':names}
template='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>两球走位 · 预计算匹配实验</title>
<style>*{box-sizing:border-box}body{margin:0;background:#f4f6f3;color:#203b31;font:16px/1.6 system-ui,-apple-system,sans-serif}main{max-width:1240px;margin:0 auto;padding:34px 24px}h1{font-size:30px;margin:5px 0 10px}h2{font-size:21px;margin:0 0 12px}.eyebrow{font-size:12px;letter-spacing:2px;color:#687b6c}p{margin:8px 0}section{background:white;border:1px solid #dbe4da;border-radius:12px;padding:22px;margin:20px 0}.note{color:#56685e;font-size:14px}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.card{padding:16px;background:#eef4ec;border-radius:8px}.card strong{font-size:27px;display:block}.controls{display:flex;gap:16px;flex-wrap:wrap;margin:15px 0}label{font-size:14px}select,button{font:inherit;padding:8px 12px;border:1px solid #c3d0c1;border-radius:7px;background:white;color:#203b31}button{cursor:pointer}button.active{background:#dcebcf}img{display:block;width:100%;height:auto;border-radius:7px}table{width:100%;border-collapse:collapse;font-size:14px}th,td{padding:10px;text-align:left;border-bottom:1px solid #e6ece3}th{white-space:nowrap}tr.selected{background:#f1f6df}td button{padding:3px 8px}a{color:#176c55}.scroll{overflow:auto}.badge{font-size:12px;padding:3px 8px;background:#f4ead0;border-radius:9px}.warning{border-left:4px solid #bb8b26;padding-left:13px}.metrics{font-size:15px;padding:10px 0}.methods{display:grid;grid-template-columns:1fr 1fr;gap:12px}.methods div{background:#f7f8f4;padding:12px;border-radius:7px}@media(max-width:720px){main{padding:18px 12px}.cards,.methods{grid-template-columns:1fr}section{padding:14px}h1{font-size:24px}}</style>
<main><div class="eyebrow">球迹研究 / 2026.10.23 / 小样本试点</div><h1>先算第二杆，再匹配第一杆落点</h1><p>同一套第二球可行网格，比较“面积交集”和“扰动样本覆盖率”。候选放回开局后，用未参与排序的样本完成两杆复验。</p>
<div class="cards"><div class="card"><strong id="nMaps"></strong>第二球＋袋口配置 · 六袋覆盖</div><div class="card"><strong>81 ＋ 96</strong>每方案设计扰动 ＋ 留出扰动</div><div class="card"><strong id="nTrials"></strong>完整两杆试验 · 所有失败留在分母</div></div>
<section><h2>先看两种排序的结果</h2><div id="comparisons"></div><p class="note">百分比为每种方法选出的前 3 个候选的留出完成率均值。候选共享同一批扰动，结果并不相互独立；这是一个初始球形、三个击球方案的小试验，不证明某种方法普遍更好。</p></section>
<section><h2>逐个查看球形与落点</h2><div class="controls"><label>第一杆方案 <select id="route"></select></label><label>候选排列 <select id="order"><option value="coverageRank">按覆盖率</option><option value="areaRank">按交集面积</option></select></label><label>第二球 <select id="candidate"></select></label></div><div id="metrics" class="metrics"></div><p><a id="figureLink" target="_blank">查看原尺寸图</a></p><img id="figure" alt="第二球母球可行网格、首杆扰动停点和完整两杆轨迹对照"><p class="note">绿色只表示网格中心有成功见证；整格涂色是检索代理，未证明格内处处可行。黄色是交集格，紫圆大小反映停点频数。未求出见证的位置不能直接称为无解。</p><div class="scroll"><table><thead><tr><th>候选 / 袋口</th><th>面积名次</th><th>覆盖名次</th><th>交集 cm²</th><th>检索 /81</th><th>完整复验 /81</th><th>留出 /96</th><th>名义两杆</th></tr></thead><tbody id="rows"></tbody></table></div></section>
<section><h2>这次到底验证了什么</h2><div class="methods"><div><b>面积排序</b><p>有效停点占用格 ∩ 第二杆有见证格；每格记一次，再乘 36cm²。不会把散点外轮廓内的空白填满。</p></div><div><b>覆盖排序</b><p>相同交集格内，累计落点样本数量，除以全部 81 组扰动。保留母球落点的疏密差异。</p></div></div><p>每个第一杆方案只求一次名义方向，之后固定瞄准并加误差。第二杆可以根据真实停点重新规划；B 从开局就在场，若被碰动则本试点不通过。</p><p class="warning">第二杆限定切角≤35°、球心距离15–120cm、母球离库≥5cm，无侧塞、最多12组杆法/速度搜索。满足这些条件且找到解，才记为本轮可行；不是全台球打法的可行边界。</p><p>当前引擎采用既有平杆物理，出杆姿态只做生产几何可达性检查；未作真人成功率或抬杆物理标定。正式准度题库与 App 均未改写。</p><p><a href="REPORT.md">完整报告</a> · <a href="EXPERIMENT.md">预先固定的实验协议</a> · <a href="ranking-comparison.csv">导出排名 CSV</a> · <a href="summary.json">统计 JSON</a></p></section></main>
<script>const D=__DATA__;
const route=document.getElementById('route'),order=document.getElementById('order'),candidate=document.getElementById('candidate');
document.getElementById('nMaps').textContent=new Set(D.details.map(x=>x.id)).size;
document.getElementById('nTrials').textContent=D.summary.designAndHoldoutTrials.toLocaleString();
route.innerHTML=D.routes.map(r=>`<option value="${r.id}">${r.label}</option>`).join('');
document.getElementById('comparisons').innerHTML=D.summary.comparison.map(c=>{const r=D.routes.find(x=>x.id===c.route);return `<p><b>${r.label}</b>：面积前3名 ${(100*c.area.meanHoldoutRate).toFixed(1)}% · 覆盖前3名 ${(100*c.coverage.meanHoldoutRate).toFixed(1)}%</p>`}).join('');
function current(){return D.details.filter(x=>x.route===route.value).sort((a,b)=>a[order.value]-b[order.value]);}
function options(keep=false){const before=candidate.value;candidate.innerHTML=current().map(x=>`<option value="${x.id}">B#${x.id} · ${D.pockets[x.pocket]}</option>`).join('');if(keep&&current().some(x=>String(x.id)===before))candidate.value=before;render();}
function render(){const list=current(),d=list.find(x=>String(x.id)===candidate.value),hm=d.metrics.find(x=>x.split==='holdout');document.getElementById('figure').src=d.image;document.getElementById('figureLink').href=d.image;
document.getElementById('metrics').textContent=`B#${d.id} → ${D.pockets[d.pocket]}｜交集 ${(d.intersectionM2*10000).toFixed(0)} cm²｜设计检索 ${d.coveredSamples}/81｜`+(hm?`独立复验 ${hm.complete}/96；95%区间 ${(hm.wilson95[0]*100).toFixed(1)}–${(hm.wilson95[1]*100).toFixed(1)}%`:'未进入完整复验集合');
document.getElementById('rows').innerHTML=list.map(x=>{const a=x.metrics.find(m=>m.split==='design'),b=x.metrics.find(m=>m.split==='holdout');return `<tr class="${x.id===d.id?'selected':''}"><td><button data-id="${x.id}">B#${x.id}</button> ${D.pockets[x.pocket]}</td><td>${x.areaRank}</td><td>${x.coverageRank}</td><td>${(x.intersectionM2*10000).toFixed(0)}</td><td>${x.coveredSamples}</td><td>${a?a.complete:'未验'}</td><td>${b?b.complete:'未验'}</td><td>${b?(b.nominalComplete?'通过':'未通过'):'未验'}</td></tr>`}).join('');document.querySelectorAll('[data-id]').forEach(b=>b.onclick=()=>{candidate.value=b.dataset.id;render();});}
route.onchange=()=>options();order.onchange=()=>options(true);candidate.onchange=render;options();
</script></html>'''
(OUT/'report.html').write_text(template.replace('__DATA__',json.dumps(payload,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')))
print('Wrote',len(details),'figures and offline viewer')
