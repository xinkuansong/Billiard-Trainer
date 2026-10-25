"""Controlled synthetic distance-score calibration; no corpus writes/physics."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Polygon
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.font_manager import fontManager

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-comfort-distance-review-v2-20261025'
SOURCE=ROOT/'output/two-ball-comfort-heatmap-five-20261025/data.json'
D=json.loads(SOURCE.read_text());G=D['geometry'];OLD_POLICY=D['policy'];POLICY=dict(OLD_POLICY)
POLICY.update(distanceNearWidthFactor=.8,distanceFarWidth=.75)
HX=G['length']/2;HZ=G['width']/2;R=G['radius']
ANCHORS=[(-HX+R,-HZ+R),(HX-R,-HZ+R),(-HX+R,HZ-R),(HX-R,HZ-R),(0,-HZ),(0,HZ)]
NAMES=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']

def setup(b,p):
    n=np.asarray(ANCHORS[p])-b;n=n/np.linalg.norm(n);back=-n
    lengths=[((bound-v) if direction>0 else (-bound-v))/direction
             for v,direction,bound in zip(b,back,[HX-R,HZ-R]) if abs(direction)>1e-12]
    depth=min(lengths)
    scale=min(1,max(POLICY['depthScaleMin'],depth/POLICY['depthScaleDenominator']))
    lo,hi=[v*scale for v in POLICY['distanceBasePlateau']]
    return n,depth,lo,hi

def old_distance_score(d,lo,hi):
    return 100*np.exp(-(np.maximum(lo-d,0)/(OLD_POLICY['distanceNearWidthFactor']*lo))**2
                      -(np.maximum(d-hi,0)/OLD_POLICY['distanceFarWidth'])**2)

def distance_score(d,lo,hi):
    return 100*np.exp(-(np.maximum(lo-d,0)/(POLICY['distanceNearWidthFactor']*lo))**2
                      -(np.maximum(d-hi,0)/POLICY['distanceFarWidth'])**2)

def main():
    OUT.mkdir(exist_ok=True)
    fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    cmap=LinearSegmentedColormap.from_list('comfort',['#b65d56','#e8b56b','#f5edbd','#347c68'])
    configs=[('1','纵向空间充足',[0,-.40],4),('2','纵向空间有限',[0,0],4),
             ('3','纵向空间较小',[0,.25],4),('4','纵向空间很小',[0,.43],4),
             ('5','角袋方向，空间充足',[-1.,-.45],0),('6','角袋方向，空间有限',[.80,.38],0),
             ('7','用户示意：靠右侧短库斜打角袋',[1.08,0.0],1),
             ('8','用户示意：靠上侧长库斜打角袋',[.70,-.50],1)]
    distances=np.asarray([.10,.20,.30,.40,.50,.65,.80,1.,1.2,1.6])
    results=[];sections=[]
    # Existing 22 reference scores must remain numerically identical.
    for s in D['samples']:
        for q in s['routes']:
            _,depth,lo,hi=setup(np.array(s['position']),q['pocket'])
            assert abs(depth-q['depth'])<1e-10
            assert abs(float(old_distance_score(q['distance'],lo,hi))-q['distanceScore'])<1e-10
    for number,title,ball,p in configs:
        b=np.asarray(ball);n,depth,lo,hi=setup(b,p)
        available=[float(v) for v in (np.array([.08,.12,.16]) if depth<.20 else distances) if v<depth]
        extra=float(round(.85*depth,5))
        if min(abs(extra-v) for v in available)>.06: available.append(extra)
        available=sorted(available)
        rows=[]
        for i,dist in enumerate(available,1):
            cue=b-n*dist;ghost=b-2*R*n;v=ghost-cue
            angle=math.degrees(math.atan2(abs(v[0]*n[1]-v[1]*n[0]),np.dot(v,n)))
            assert angle<1e-8 and dist>2*R
            assert abs(cue[0])<HX-R and abs(cue[1])<HZ-R
            rows.append({'index':i,'cue':cue.tolist(),'distance':dist,'distanceScore':float(distance_score(dist,lo,hi)),'oldDistanceScore':float(old_distance_score(dist,lo,hi)),
                         'angle':angle,'nearestRailGap':float(min(HX-abs(cue[0]),HZ-abs(cue[1]))-R)})
        result={'number':number,'title':title,'ball':ball,'pocket':p,'depth':depth,'preferred':[lo,hi],'rows':rows}
        results.append(result)
        fig=plt.figure(figsize=(14,7.4),facecolor='#f6f8f1')
        ax=fig.add_axes([.025,.31,.57,.55]);ax.set_aspect('equal');ax.axis('off')
        ax.add_patch(Rectangle((-HX-.04,-HZ-.04),2*HX+.08,2*HZ+.08,color='#355e52'))
        ax.add_patch(Rectangle((-HX,-HZ),2*HX,2*HZ,color='#dce9d6'))
        for i,pocket in enumerate(G['pockets']):
            c=pocket['center'];pos=(c['x'],c['z'])
            ax.add_patch(Polygon([(v['x'],v['z']) for v in pocket['lip']],color='#183c33'))
            ax.add_patch(Circle(pos,pocket['radius'],color='#183c33'))
            if i==p:ax.add_patch(Circle(pos,.067,fill=False,ec='#d69422',lw=2))
        ax.plot([ANCHORS[p][0],*(b-n*depth)[0:1]],[ANCHORS[p][1],*(b-n*depth)[1:2]],'--',color='#789784',lw=1)
        ax.add_patch(Circle(b,R,fc='#1683ac',ec='#0b536e',zorder=5));ax.text(*b,'B',ha='center',va='center',color='white',fontsize=9,zorder=6)
        for q in rows:
            cue=q['cue'];ax.plot(*cue,'o',ms=10,mfc=cmap(q['distanceScore']/100),mec='#36594a',zorder=5)
            side=1 if q['index']%2 else -1
            offset=np.array([n[1],-n[0]])*.105*side
            ax.text(*(cue+offset),str(q['index']),ha='center',va='center',fontsize=9,color='#2b4f3c')
        ax.set_xlim(-HX-.1,HX+.1);ax.set_ylim(HZ+.1,-HZ-.1)
        ax.set_title('编号是不同假设母球位置；每点切角均为0°',fontsize=12)
        curve=fig.add_axes([.66,.35,.31,.46]);ds=np.linspace(.06,1.8,600)
        curve.plot(ds*100,distance_score(ds,lo,hi),color='#b5b9b1',ls='--',lw=1.4)
        curve.plot(ds*100,old_distance_score(ds,lo,hi),color='#b66c47',ls='--',lw=1.6,label='原版')
        valid=ds<depth;curve.plot(ds[valid]*100,distance_score(ds[valid],lo,hi),color='#287b62',lw=2,label='放缓版');curve.legend(loc='upper right')
        curve.axvspan(lo*100,hi*100,color='#c7dfbe',alpha=.45)
        if depth<1.8:curve.axvspan(depth*100,180,color='#cccccc',alpha=.35)
        for q in rows:curve.scatter(q['distance']*100,q['distanceScore'],c=[cmap(q['distanceScore']/100)],s=35,edgecolors='#36594a',zorder=5)
        curve.set(xlim=(0,180),ylim=(0,105),xlabel='母球—B球心距（cm）',ylabel='球距分')
        curve.grid(alpha=.2);curve.set_title('绿：放缓版；棕虚线：原版；灰区：可摆范围外',fontsize=10)
        fig.suptitle(f'球距评分放缓对比 {number} · {title} · B → {NAMES[p]}',fontsize=18,y=.97)
        fig.text(.05,.90,f'后方中轴可摆深度 {depth*100:.1f}cm · 当前满分区间 {lo*100:.1f}–{hi*100:.1f}cm',fontsize=12,color='#30553f')
        tax=fig.add_axes([.10,.10,.86,.15]);tax.axis('off')
        table=tax.table(cellText=[[str(q['index']) for q in rows],[f'{q["distance"]*100:.1f}' for q in rows],
                                  [f'{q["oldDistanceScore"]:.1f}' for q in rows],[f'{q["distanceScore"]:.1f}' for q in rows]],
                        rowLabels=['母球编号','球距cm','原版分','放缓版分'],loc='center',cellLoc='center')
        table.auto_set_font_size(False);table.set_fontsize(10);table.scale(1,1.65)
        for cell in table.get_celld().values():cell.set_edgecolor('#ccd8c6')
        fig.text(.05,.035,'合成几何校准例，非题库走位结果；只看球距，切角固定0°，出杆空间另评。不做筛选或物理入袋验证。',fontsize=10,color='#526859')
        fig.savefig(OUT/f'case-{number}.png',dpi=140);plt.close(fig)
        tablehtml=''.join(f'<tr><td>{q["index"]}</td><td>{q["distance"]*100:.1f}</td><td>{q["oldDistanceScore"]:.1f}</td><td><b>{q["distanceScore"]:.1f}</b></td></tr>' for q in rows)
        sections.append(f'<section id="case-{number}"><h2>{number} · {title}</h2><p>目标袋：{NAMES[p]}；可摆深度{depth*100:.1f}cm；目前满分区间{lo*100:.1f}–{hi*100:.1f}cm。</p>'
                        f'<a href="case-{number}.png" target="_blank"><img src="case-{number}.png" alt="球距评分例{number}：{title}"></a>'
                        '<details><summary>展开实际距离和评分</summary><table><tr><th>母球编号</th><th>球距cm</th><th>原版分</th><th>放缓版分</th></tr>'+tablehtml+'</table></details></section>')
    result={'schema':'distance-score-controlled-review-v2','synthetic':True,'physicalValidation':False,
            'sourceSHA256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'policy':POLICY,'oldPolicy':OLD_POLICY,
            'coordinates':'world XZ metres, landscape +X right/+Z down, Y up','cases':results}
    previous=json.loads((ROOT/'output/two-ball-comfort-distance-review-20261025/data.json').read_text())
    for current,old in zip(results[:6],previous['cases'],strict=True):
        assert all(current[k]==old[k] for k in ['number','ball','pocket','depth','preferred'])
        for q,r in zip(current['rows'],old['rows'],strict=True):
            assert all(q[k]==r[k] for k in ['index','cue','distance','angle','nearestRailGap'])
            assert abs(q['oldDistanceScore']-r['distanceScore'])<1e-10
            assert q['distanceScore']>=q['oldDistanceScore']-1e-10
    ds=np.linspace(.06,2.5,1000)
    scores=distance_score(ds,.5,.8)
    assert np.all((scores>=0)&(scores<=100))
    assert np.all(np.diff(scores[ds<.5])>=0) and np.all(np.diff(scores[ds>.8])<=0)
    assert np.all(scores[(ds>=.5)&(ds<=.8)]==100)
    (OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>球距评分放缓版 · 新旧对比</title><style>
body{margin:0;background:#f1f4ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1300px;margin:auto;padding:24px}p,li{line-height:1.8}nav{position:sticky;top:0;background:#fffff5f5;padding:16px;display:flex;flex-wrap:wrap;gap:20px;justify-content:center;z-index:10}a{color:#26765d}img{width:100%}section{scroll-margin-top:75px;border-bottom:1px solid #ccc;padding:20px 0}table{border-collapse:collapse;background:white}td,th{padding:12px;border:1px solid #dae3d4;text-align:center}header{background:#e4ecde}</style>
<header><h1>球距评分放缓版 · 同八组新旧对比</h1><p>本页是新构造的几何示例，不是此前五题或已验证的题库路线。每组固定B与目标袋，改变母球距离，切角始终0°。出杆空间会随位置变化，但本页暂不计入分数，不计算总分。</p>
<p>例7、8按用户红色示意追加：分别为靠右短库、靠上长库斜打右上角袋；红圈按第二目标球解释，坐标近似选取，不是图像精确反算。是否好出杆由后续空间分单独讨论，本页仍只看球距。</p><p>每个编号代表母球的一种独立摆法，不表示桌上同时放了多颗母球。图中绿线为放缓版、棕色虚线为原版；灰色右区在该直线的可摆范围之外，仅显示公式延长线。所有案例横轴和分数轴同尺度，方便对比。</p>
<p>重点看三件事：①空间足够时，50–80cm是否应该同为满分，近端/远端扣分是否太快；②同样30cm球距，空间不足时是否应该更高分；③空间极小时，是否应继续放宽，还是承认它本来就不舒服。例4会暴露当前最小缩放0.4的限制：满分区可能在桌外，我们保留这个现象供你判断。</p>
<p>按本轮反馈仅放缓两侧下降：近端宽度由0.4×下限改为0.8×下限，远端宽度由35cm改为75cm。正常50–80cm满分区、空间自适应规则与全部摆法保持不变。空间充足时30cm由36.8升至77.9，120cm由27.1升至75.2。系数仍待评阅，不代表已确认生产规则；0分不是无法进球，100分也不是成功概率。本页不修改题库、不重新模拟。</p></header><nav>'''
        +''.join(f'<a href="#case-{n}">例{n}</a>' for n in range(1,9))+'</nav><main>'+''.join(sections)
        +'</main><footer><a href="data.json">坐标、距离、分数和试验规则</a></footer></html>')
    (OUT/'verification.json').write_text(json.dumps({'reference22OldDistanceScoresMatch':True,'onlyDecayWidthsChanged':True,'allConstructedAnglesZero':True,
        'allDisplayedCueBodiesInsideTable':True,'allDisplayedPairsNonoverlapping':True,'cases':len(results),'positions':sum(len(s['rows']) for s in results)},indent=2))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-distance-review-v2';served.mkdir(exist_ok=True)
    for p in OUT.iterdir():
        if p.is_file():shutil.copy2(p,served/p.name)
    for s in results:print(s['number'],round(s['depth']*100,2),[(round(q['distance']*100,1),round(q['distanceScore'],1)) for q in s['rows']])

if __name__=='__main__':main()
