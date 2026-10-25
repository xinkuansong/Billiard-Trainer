"""Re-score frozen 22 original stops with selected component policies; no corpus edits."""
from pathlib import Path
import copy,hashlib,importlib.util,json,math,shutil
ROOT=Path(__file__).resolve().parents[2]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
base=module('score_baseline','research/two-ball-comfort-score-five-20261025/render.py')
distance=module('distance_v2','research/two-ball-comfort-distance-review-v2-20261025/render.py')
space=module('space_v3','research/two-ball-comfort-space-review-v3-20261025/render.py')
angle=module('angle_v2','research/two-ball-comfort-angle-review-v2-20261025/render.py')
SOURCE=ROOT/'output/two-ball-comfort-score-five-20261025/data.json'
OUT=ROOT/'output/two-ball-comfort-score-five-v2-20261025'
SERVE=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-score-five-v2'

def main():
    OUT.mkdir(exist_ok=True);raw=SOURCE.read_bytes();old=json.loads(raw);data=copy.deepcopy(old)
    hashes={str(SOURCE.relative_to(ROOT)):hashlib.sha256(raw).hexdigest(),**old['sourceSHA256']}
    for p,h in hashes.items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h
    base.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf');base.plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    g=data['geometry'];hx=g['length']/2;hz=g['width']/2;radius=g['radius'];sections=[]
    assert (hx,hz,radius)==(space.old.HX,space.old.HZ,space.old.R)
    for sample in data['samples']:
        for q in sample['routes']:
            actual=space.old.evaluate(q['stop'],sample['position'],q['pocket'])
            for a,b in [('distance','distance'),('angle','angle'),('gap','gap'),('score','spaceScore')]:assert abs(actual[a]-q[b])<1e-9
            _,depth,lo,hi=distance.setup(distance.np.array(sample['position']),q['pocket'])
            assert abs(depth-q['depth'])<1e-10
            assert abs(float(distance.old_distance_score(actual['distance'],lo,hi))-q['distanceScore'])<1e-9
            details=space.evaluate(q['stop'],actual['back'])
            latest={'distance':float(distance.distance_score(actual['distance'],lo,hi)),'space':details['score'],'angle':angle.score(actual['angle'])}
            latest['total']=base.comfort_total(latest['distance'],latest['space'],latest['angle'])
            assert abs(latest['total']-(latest['distance']*latest['space']*latest['angle'])**(1/3))<1e-9
            q['latestScores']=latest;q['spaceV3Details']=details
        ordered=sorted(sample['routes'],key=lambda q:(-q['latestScores']['total'],q['rank']))
        for i,q in enumerate(ordered,1):q['latestRank']=i
        sample['latestOrderOriginalRanks']=[q['rank'] for q in ordered]
        n=sample['number']
        fig=base.plt.figure(figsize=(15,10.5),facecolor='#f6f8f1')
        ax=fig.add_axes([.03,.43,.60,.45]);ax.set_aspect('equal');ax.axis('off')
        ax.add_patch(base.Rectangle((-hx-.04,-hz-.04),2*hx+.08,2*hz+.08,color='#355e52'))
        ax.add_patch(base.Rectangle((-hx,-hz),2*hx,2*hz,color='#dce9d6'))
        for i,p in enumerate(g['pockets']):
            c=p['center'];pos=(c['x'],c['z']);ax.add_patch(base.Polygon([(v['x'],v['z']) for v in p['lip']],color='#183c33'));ax.add_patch(base.Circle(pos,p['radius'],color='#183c33'))
            if i in {q['pocket'] for q in ordered}:ax.add_patch(base.Circle(pos,.066,fill=False,ec='#1683ac',lw=2))
        for pos,color,label in [(sample['board']['cue'],'white','C'),(sample['board']['object'],'#edbf55','A'),(sample['position'],'#1683ac','B')]:
            ax.add_patch(base.Circle(pos,radius,fc=color,ec='#36594a',zorder=5));ax.text(*pos,label,ha='center',va='center',fontsize=9,zorder=6)
        for i,q in enumerate(sorted(ordered,key=lambda q:q['stop'][1])):
            x,z=q['stop'];color=base.COLORS[q['rank']-1];labelz=-hz+.10+i*(2*hz-.20)/max(1,len(ordered)-1);labelx=.72 if x<0 else -.72
            ax.plot(x,z,'o',mfc='white',mec=color,ms=9,mew=2,zorder=7)
            ax.annotate(f'原{q["rank"]} → 新{q["latestRank"]} · {q["latestScores"]["total"]:.1f}',(x,z),xytext=(labelx,labelz),ha='center',va='center',fontsize=10,color=color,bbox=dict(boxstyle='round,pad=.25',fc='white',ec=color),arrowprops=dict(arrowstyle='-',color=color,lw=.8),zorder=8)
        ax.set_xlim(-hx-.12,hx+.12);ax.set_ylim(hz+.12,-hz-.12)
        ax.set_title('原版母球停点（细线仅为标签引线）',fontsize=12,pad=12)
        bars=fig.add_axes([.70,.44,.25,.41]);ys=distance.np.arange(len(ordered))
        for offset,key,color,label in [(-.24,'distance','#1683ac','球距v2'),(0,'space','#e78b24','空间v3'),(.24,'angle','#8365bf','角度v2')]:
            vals=[q['latestScores'][key] for q in ordered];bars.barh(ys+offset,vals,height=.21,color=color,label=label)
            for y,v in zip(ys+offset,vals):bars.text(v+1,y,f'{v:.1f}',va='center',fontsize=9)
        bars.set(yticks=ys,yticklabels=[f'新{q["latestRank"]}（原{q["rank"]}）' for q in ordered],xlim=(0,116),xticks=[0,25,50,75,100]);bars.invert_yaxis();bars.spines[['top','right']].set_visible(False);bars.grid(axis='x',alpha=.15);bars.set_axisbelow(True);bars.legend(loc='upper center',bbox_to_anchor=(.5,1.14),ncol=3,fontsize=9)
        labels=['新排','原排','上版舒适排','第二杆袋口','球距分','空间分','角度分','最新总分','上版总分','球距 / 离库 / 切角']
        rows=[[str(q['latestRank']),str(q['rank']),str(q['comfortRank']),base.NAMES[q['pocket']],*[f'{q["latestScores"][k]:.1f}' for k in ['distance','space','angle','total']],f'{q["totalScore"]:.1f}',f'{q["distance"]*100:.1f}cm / {q["gap"]*100:.1f}cm / {q["angle"]:.2f}°'] for q in ordered]
        ta=fig.add_axes([.025,.105,.95,.27]);ta.axis('off');t=ta.table(cellText=rows,colLabels=labels,cellLoc='center',loc='center',colWidths=[.045,.045,.08,.10,.07,.07,.07,.08,.08,.26]);t.auto_set_font_size(False);t.set_fontsize(10);t.scale(1,2.1)
        for (r,c),cell in t.get_celld().items():
            cell.set_edgecolor('#cfdbca');cell.set_facecolor('#dae6d4' if r==0 else 'white')
            if r>0 and c==7:cell.set_text_props(weight='bold',color='#17533b')
        fig.suptitle(f'样本{n} · B{sample["cellID"]} · 最新舒适度总分',fontsize=21,y=.975)
        fig.text(.04,.925,'球距放缓v2 + 库上架杆空间v3 + 角度15°满分/30°衰减；总分取三项等权几何平均。',fontsize=12)
        fig.text(.04,.065,'原排 = 阶段A推荐顺序；上版舒适排 = 之前旧分项的总分排序。表格按本轮未舍入总分降序，完全同分按原排。',fontsize=10,color='#526859')
        fig.text(.04,.035,'全部原停点与原目标袋保留；C/A仅初始位置参考。离库按球面净距。仅评分预览，未筛选、未改题库，分数不是进球概率。',fontsize=10,color='#526859')
        fn=f'sample-{n}.png';fig.savefig(OUT/fn,dpi=140);base.plt.close(fig)
        trs=''.join('<tr>'+''.join(f'<td>{v}</td>' for v in row)+'</tr>' for row in rows)
        sections.append(f'<section id="sample-{n}"><h2>样本{n} · B{sample["cellID"]}</h2><p>{sample["id"]}</p><a href="{fn}" target="_blank"><img src="{fn}" alt="样本{n}原版停点、三个分项、新旧总分与排名"></a><div class="scroll"><table><tr>'+''.join(f'<th>{x}</th>' for x in labels)+'</tr>'+trs+'</table></div></section>')
        print(n,[(q['rank'],round(q['latestScores']['total'],2)) for q in ordered])
    for s,o in zip(data['samples'],old['samples']):
        for q,r in zip(s['routes'],o['routes']):assert {k:q[k] for k in r}==r
    count=sum(len(s['routes']) for s in data['samples']);assert count==22
    data.update(schema='comfort-total-preview-v2',originalTotalPreviewSHA256=hashlib.sha256(raw).hexdigest(),latestPolicy={'distanceVersion':'v2','nearWidthFactor':.8,'farWidthMeters':.75,'spaceVersion':'v3','space':space.POLICY,'angleVersion':'v2','plateauDegrees':15,'angleDecayScaleDegrees':30,'aggregate':'(D*S*A)^(1/3)','selectionApplied':False,'originalPolicyRetainedUnder':'policy'})
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False))
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>五题原版停点 · 最新舒适度总分</title><style>body{margin:0;background:#f1f4ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1450px;margin:auto;padding:24px}header{background:#e3ecdf}p{line-height:1.8}nav{position:sticky;top:0;background:#fffef4f5;padding:16px;display:flex;gap:25px;justify-content:center;z-index:10}a{color:#26765d}section{scroll-margin-top:80px;padding:20px 0;border-bottom:1px solid #ccd6c4}img{width:100%}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;border:1px solid #dae3d4;white-space:nowrap;text-align:center}td:nth-child(8){font-weight:bold;color:#17533b}</style><header><h1>五题原版停点 · 最新舒适度总分</h1><p>沿用同5题、22个原版停点和原目标袋，重新计算球距放缓v2、出杆空间v3、角度v2。每题按新总分排序，同时对照原推荐顺序与上版舒适度排序；不删除、不移动、不重新优化。</p><p><b>总分 = ∛（球距分 × 出杆空间分 × 角度分）</b>，三项等权。角度0～15°同为100分，不额外奖励更直。按未舍入总分排序，完全同分沿用原推荐顺序。</p><p>球距沿用按后方空间缩放的满分区间；近端衰减尺度0.8×下界，远端75cm。空间采用逐库扣分，允许库上架杆，角落附加最多8分。角度超过15°后按30°尺度下降。</p><p>图中编号对应原推荐，细线仅为标签引线。C/A是初始位置参考，评价第二杆时A已经入袋；离库为母球球面至矩形库线净距。本页是主观舒适度校准，不含第一杆难度，无新物理验证，分数不是进球概率。</p><p><a href="../comfort-score-five/">上版总分图册</a> · <a href="../comfort-distance-review-v2/">球距v2</a> · <a href="../comfort-space-review-v3/">空间v3</a> · <a href="../comfort-angle-review-v2/">角度v2</a></p></header><nav>'''+''.join(f'<a href="#sample-{n}">样本{n}</a>' for n in range(1,6))+'</nav><main>'+''.join(sections)+'</main><footer><a href="data.json">全部坐标、旧评分、新评分及空间扣分明细</a></footer></html>')
    for p,h in hashes.items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h
    (OUT/'verification.json').write_text(json.dumps({'sampleCount':5,'routeCount':count,'allOriginalFieldsUnchanged':True,'sourceHashes':hashes,'geometryAndOldScoresRecomputed':True,'latestTotalProductIdentityPassed':True,'latestOrderOriginalRanks':{s['number']:s['latestOrderOriginalRanks'] for s in data['samples']}},ensure_ascii=False,indent=2))
    SERVE.mkdir(exist_ok=True)
    for p in OUT.iterdir():
        if p.is_file():shutil.copy2(p,SERVE/p.name)
if __name__=='__main__':main()
