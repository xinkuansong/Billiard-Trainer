"""Render the sixty audited original formations using the production CAD table."""
from pathlib import Path
import sys,json,html
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'research/defense-threshold-comparison-20261105'))
import geometric_table as g
from matplotlib.collections import PolyCollection
from matplotlib.colors import Normalize,LinearSegmentedColormap
from matplotlib.cm import ScalarMappable
OUT=ROOT/'output/defense-maxscore-gallery-20261106'
cases=json.loads((OUT/'selected.json').read_text());cfg=json.loads((OUT/'scenario.json').read_text())
plt=g.plt
cmap=LinearSegmentedColormap.from_list('defense',['#e0eae4','#aecdbb','#4b9a87','#f2d772','#e9a155','#bc4c47'])
norm=Normalize(0,100);bg='#f4f5f0';ink='#173b32'
branch={'formula':'公式','zero-width':'0°估算','route-estimate':'路线估算','bound-estimate':'边界估算','pot-block':'进球封锁','direct-block':'瞄准封锁'}

def draw(ax,c,large=False):
    g.table(ax)
    scan=json.loads((OUT/c['dataDirectory']/'scan-adaptive.json').read_text())
    verts=[];scores=[]
    for r in scan['rows']:
        if 'score' not in r:continue
        x,z,x1,z1=r['bounds'];verts.append([(x,z),(x1,z),(x1,z1),(x,z1)]);scores.append(r['score'])
    coll=PolyCollection(verts,array=g.np.array(scores),cmap=cmap,norm=norm,edgecolors='none',zorder=2.5)
    ax.add_collection(coll);coll.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))
    # Erase excluded circle visually, even when a cell straddles its boundary.
    excluded=g.Circle(c['target'],.30,facecolor='#ecf0e9',edgecolor='#596c64',linewidth=.8,linestyle='--',alpha=.85,zorder=2.7)
    ax.add_patch(excluded);excluded.set_clip_path(g.Polygon(g.outline,closed=True,transform=ax.transData))
    q=c['question'];g.ball(ax,q['cue'],0)
    for b in q['balls']:g.ball(ax,b['position'],b['number'])
    x,z=c['maximumPoint'];ax.scatter([x],[z],s=70 if large else 34,marker='x',color='#6d1fa6',linewidths=2,zorder=14)
    status=branch.get(c['maximumStatus'],c['maximumStatus'])
    ax.set_title(f"{c['displayID']}  最高 {c['maximum']:.2f} 分  ·  {status}",loc='left',fontsize=16 if large else 12,color=ink,pad=5)
    d=g.np.linalg.norm(g.np.array(c['maximumPoint'])-g.np.array(c['target']))
    ax.text(.015,-.025,f"最高分点距9号 {d*100:.0f}cm  ·  {c['label']}" + (' · 角色适配' if 'adaptation' in c else ''),transform=ax.transAxes,fontsize=11 if large else 9,color='#355950',va='top')

(OUT/'images').mkdir(exist_ok=True)
for b in cfg['bins']:
    group=[c for c in cases if c['bin']==b]
    for i,c in enumerate(group,1):
        c['displayID']=f'{b}-{i:02d}'
        fig,ax=plt.subplots(figsize=(12,7));fig.patch.set_facecolor(bg);fig.subplots_adjust(left=.03,right=.96,top=.85,bottom=.18)
        draw(ax,c,True)
        fig.text(.04,.94,f"{b}分档 · 扫描最高分 [{b-2.5:g}, {b+2.5:g})",fontsize=18,color=ink)
        if 'adaptation' in c:fig.text(.04,.89,c['adaptation'],fontsize=9,color='#355950')
        cax=fig.add_axes([.30,.10,.40,.017]);bar=fig.colorbar(ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation='horizontal',ticks=[0,25,50,70,80,90,100]);bar.ax.tick_params(labelsize=9)
        fig.text(.04,.035,'颜色为防守分，越高表示对方越难进攻。紫色×为扫描最高分点；灰圈内30cm不统计。\n固定9号、无其他球遮挡；白球与8号只表示原题初始位置，尚未验证击球可达。',fontsize=10,color='#355950')
        fig.savefig(OUT/'images'/f"{c['displayID']}.png",dpi=140,facecolor=bg);plt.close(fig)
    fig,axes=plt.subplots(5,2,figsize=(14,22));fig.patch.set_facecolor(bg);fig.subplots_adjust(left=.03,right=.97,top=.915,bottom=.075,wspace=.08,hspace=.20)
    for ax,c in zip(axes.flat,group):draw(ax,c)
    fig.text(.04,.965,f"最高防守分 {b} 分档 · 10个球形",fontsize=25,color=ink)
    fig.text(.04,.94,f"入档范围 [{b-2.5:g}, {b+2.5:g})；固定9号，排除球心距不足30cm的位置。",fontsize=12,color='#355950')
    cax=fig.add_axes([.30,.045,.40,.009]);bar=fig.colorbar(ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation='horizontal',ticks=[0,25,50,70,80,90,100]);bar.ax.tick_params(labelsize=10)
    fig.text(.04,.013,'紫色×：采样最高分点。白球和8号：原题参照，不参与区域评分。\n5cm扫描＋局部加密；最高分为采样结果，尚未验证击球可达。',fontsize=10,color='#355950')
    fig.savefig(OUT/f'class-{b}.png',dpi=130,facecolor=bg);plt.close(fig)
    print('Rendered class',b,flush=True)

(OUT/'selected.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2))
nav=' · '.join(f'<a href="#c{b}">{b}分档</a>' for b in cfg['bins'])
parts=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>初始球形最高防守分对照 · 60张</title><style>body{font-family:system-ui;background:#f4f5f0;color:#173b32;max-width:1400px;margin:auto;padding:24px}nav{position:sticky;top:0;background:#f4f5f0;padding:14px;z-index:1}a{color:#256a65}section{scroll-margin-top:65px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:16px}img{width:100%;display:block}figure{margin:0}figcaption{padding:0 18px 16px;font-size:13px;overflow-wrap:anywhere}p{line-height:1.7}@media(max-width:480px){.grid{grid-template-columns:1fr}body{padding:8px}}</style><h1>初始球形最高防守分对照 · 60张</h1>',f'<nav>{nav}</nav>','<p>每档10个球形（优先原题，缺额采用其他题型原始坐标并明确角色适配），按排除近球位置后的<b>扫描最高防守分</b>归档（目标分±2.5分，左闭右开）。每档采用相同0–100色阶。固定9号，无其他球遮挡；初始8号和白球仅作参照。<br>灰圈为9号球心周围30cm，不参与统计；紫色×为扫描最高分点。5cm粗扫、边界2cm加密、峰值候选≤5mm复核，结果不是连续全局最优证明，也不证明有可达打法。30cm与分档宽度仅供本次研究对照。</p>']
md=['# 初始球形最高防守分对照（60张）','','每档10个球形（原题优先；适配题保留原始坐标，并标明变化）；目标分±2.5，左闭右开。固定对方9号，不加入8号遮挡。排除母球与9号球心距不足30cm的位置。最高分仅指采样最高分；不证明击球可达。','','[交互图册](index.html) · [验证数据](validation.json) · [原题与精确数值](selected.json)','']
for b in cfg['bins']:
    group=[c for c in cases if c['bin']==b]
    parts.append(f'<section id="c{b}"><h2>{b}分档 · [{b-2.5:g}, {b+2.5:g})</h2><p><a href="class-{b}.png">打开本档10张总览</a></p><div class="grid">')
    md.extend([f'## {b}分档','',f'![{b}分档10张](class-{b}.png)','','| 编号 | 最高分 | 评分分支 | 原题ID |','|---|---:|---|---|'])
    for c in group:
        q=c['question'];qid=str(q.get('id',q.get('questionID',c['label'])))
        parts.append(f'<figure><a href="images/{c["displayID"]}.png"><img loading="lazy" src="images/{c["displayID"]}.png" alt="{c["displayID"]} 最高防守分{c["maximum"]:.2f}"></a><figcaption>原题 {html.escape(qid)} · {c["label"]} · {html.escape(c.get('adaptation','原题，无调整'))}</figcaption></figure>')
        md.append(f'| [{c["displayID"]}](images/{c["displayID"]}.png) | {c["maximum"]:.4f} | {branch.get(c["maximumStatus"],c["maximumStatus"])} | {qid} {c.get('adaptation','')} |')
    parts.append('</div></section>');md.append('')
parts.append('</html>');(OUT/'index.html').write_text('\n'.join(parts));(OUT/'gallery.md').write_text('\n'.join(md))
print('Rendered 60 individual images, 6 sheets, HTML and Markdown gallery')
fig,axes=plt.subplots(3,2,figsize=(14,12));fig.patch.set_facecolor(bg);fig.subplots_adjust(left=.03,right=.97,top=.90,bottom=.10,wspace=.08,hspace=.26)
for ax,b in zip(axes.flat,cfg['bins']):draw(ax,next(c for c in cases if c['bin']==b))
fig.text(.04,.96,'六档最高防守分对照 · 每档首例预览',fontsize=23,color=ink)
fig.text(.04,.925,'完整图册每档10张，共60张；灰圈内30cm不统计，紫色×为扫描最高分点。',fontsize=12,color='#355950')
cax=fig.add_axes([.30,.052,.40,.012]);bar=fig.colorbar(ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation='horizontal',ticks=[0,25,50,70,80,90,100])
fig.text(.04,.017,'固定9号，不加入8号遮挡；原题母球和8号仅作参照。采样最高分，不证明击球可达。',fontsize=11,color='#355950')
fig.savefig(OUT/'overview.png',dpi=140,facecolor=bg);plt.close(fig)
