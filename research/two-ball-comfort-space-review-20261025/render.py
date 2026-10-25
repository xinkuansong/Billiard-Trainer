"""Controlled space-score calibration. Pure geometry, no corpus mutation."""
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
from matplotlib.font_manager import fontManager

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'output/two-ball-comfort-heatmap-five-20261025/data.json'
OUT = ROOT/'output/two-ball-comfort-space-review-20261025'
D = json.loads(SOURCE.read_text()); G = D['geometry']; POLICY = D['policy']
HX = G['length']/2; HZ = G['width']/2; R = G['radius']
ANCHORS = np.array([(-HX+R,-HZ+R),(HX-R,-HZ+R),(-HX+R,HZ-R),(HX-R,HZ-R),(0,-HZ),(0,HZ)])
NAMES = ['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']


def evaluate(cue, ball, pocket):
    cue, ball = np.asarray(cue), np.asarray(ball)
    n = ANCHORS[pocket]-ball; n /= np.linalg.norm(n)
    ghost = ball-2*R*n
    aim = ghost-cue; aim /= np.linalg.norm(aim)
    back = -aim
    ray = min(((bound-c) if direction>0 else (-bound-c))/direction
              for c,direction,bound in zip(cue,back,[HX,HZ]) if abs(direction)>1e-12)
    h = max(0,ray-R)
    gap = min(HX-abs(cue[0]),HZ-abs(cue[1]))-R
    rear_factor = 1-math.exp(-(h/POLICY['rearRoomScale'])**2)
    side_factor = 1-POLICY['sideGapWeight']+POLICY['sideGapWeight']*(1-math.exp(-(max(gap,0)/POLICY['sideGapScale'])**2))
    score = 100*rear_factor*side_factor
    cut = math.degrees(math.atan2(abs(aim[0]*n[1]-aim[1]*n[0]),np.dot(aim,n)))
    return dict(score=score, gap=gap, rear=h, rearFactor=rear_factor, sideFactor=side_factor,
                aim=aim.tolist(), back=back.tolist(), angle=cut,
                cue=cue.tolist(), ball=ball.tolist(), pocket=pocket,
                distance=float(np.linalg.norm(cue-ball)))


def scenario(cue, pocket, rail):
    cue = np.asarray(cue,dtype=float)
    direction = ANCHORS[pocket]-cue; direction /= np.linalg.norm(direction)
    ball = cue+.42*direction  # fixed distance isolates the space component
    q = evaluate(cue,ball,pocket)
    q['railReference'] = rail
    q['railAngle'] = math.degrees(math.atan2(abs(q['aim'][1] if rail=='长库' else q['aim'][0]),
                                           abs(q['aim'][0] if rail=='长库' else q['aim'][1])))
    for point in [cue,ball]:
        assert abs(point[0]) <= HX-R+1e-12 and abs(point[1]) <= HZ-R+1e-12
    assert q['angle'] < 1e-8 and abs(q['distance']-.42)<1e-12
    assert 0 <= q['score'] <= 100 and q['gap'] >= 0
    return q


def draw(ax, q, title):
    ax.set_aspect('equal');ax.axis('off')
    ax.add_patch(Rectangle((-HX-.04,-HZ-.04),2*HX+.08,2*HZ+.08,color='#355e52'))
    ax.add_patch(Rectangle((-HX,-HZ),2*HX,2*HZ,color='#dce9d6'))
    for i,p in enumerate(G['pockets']):
        c = p['center']; pos = (c['x'],c['z'])
        ax.add_patch(Polygon([(v['x'],v['z']) for v in p['lip']],color='#183c33'))
        ax.add_patch(Circle(pos,p['radius'],color='#183c33'))
        if i==q['pocket']:ax.add_patch(Circle(pos,.07,fill=False,ec='#dc921c',lw=2))
    cue = np.array(q['cue']);ball = np.array(q['ball']);target=ANCHORS[q['pocket']]
    ax.plot([ball[0],target[0]],[ball[1],target[1]],'--',lw=1.2,color='#c68b30',zorder=3)
    ax.annotate('',xy=ball,xytext=cue,arrowprops=dict(arrowstyle='->',color='#1683ac',lw=2),zorder=5)
    end=cue+np.array(q['back'])*min(.35,q['rear'])
    ax.annotate('',xy=end,xytext=cue,arrowprops=dict(arrowstyle='->',color='#8351a4',lw=2),zorder=5)
    for point,color,label in [(cue,'white','C'),(ball,'#1683ac','B')]:
        ax.add_patch(Circle(point,R,fc=color,ec='#36594a',zorder=6))
        ax.text(point[0],point[1]-.07,label,ha='center',va='center',fontsize=10,color='#24523f',zorder=7)
    ax.set_xlim(-HX-.12,HX+.12);ax.set_ylim(HZ+.12,-HZ-.12)
    ax.set_title(f'{title} · {NAMES[q["pocket"]]} · 空间分 {q["score"]:.1f}\n'
                 f'离库 {q["gap"]*100:.1f}cm / 杆后 {q["rear"]*100:.1f}cm / 与{q["railReference"]}夹角 {q["railAngle"]:.1f}°',
                 fontsize=11,color='#2b513e',loc='left',pad=7)


def main():
    OUT.mkdir(exist_ok=True)
    fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    # Check extraction against every original score and metric, not rounded labels.
    for sample in D['samples']:
        for row in sample['routes']:
            q=evaluate(row['stop'],sample['position'],row['pocket'])
            for a,b in [('score','spaceScore'),('rear','rear'),('gap','gap'),('angle','angle')]:
                assert abs(q[a]-row[b])<1e-9
    gaps=[.02,.05,.08,.15,.25,.40]
    groups=[
        ('1','靠下长库，向桌内击球','母球逐渐离开下长库；杆尾方向朝向下库。B及目标袋按0°切角构造，球距固定42cm。',
         [scenario([.45,HZ-R-gap],4,'长库') for gap in gaps]),
        ('2','靠右短库，向桌内击球','母球逐渐离开右短库；杆尾方向朝向右库。与例1对照长库和短库的表现。',
         [scenario([HX-R-gap,.15],0,'短库') for gap in gaps]),
        ('3','靠下长库，近似顺库出杆','目标袋为右下角袋。即使最近离库距离较小，杆尾方向也可能有较长空间；并非所有点严格平行库边。',
         [scenario([-.65,HZ-R-gap],3,'长库') for gap in gaps]),
        ('4','靠右短库，近似顺库出杆','目标袋为右上角袋。与例2在相同离库距离下对照，观察方向造成的分差。',
         [scenario([HX-R-gap,.30],1,'短库') for gap in gaps]),
        ('5','右下角附近，斜向桌内击球','母球到右短库与下长库的净距相等；向左上角袋击球，杆尾朝向角落。',
         [scenario([HX-R-gap,HZ-R-gap],0,'长库') for gap in gaps]),
        ('6','长库旁同一母球，只换出杆方向','母球固定，最近离库净距始终5cm；改变B与目标袋，保持球距42cm、切角0°。只比较方向的影响。',
         [scenario([.45,HZ-R-.05],p,'长库') for p in [0,4,1,2,3]]),
        ('7','短库旁同一母球，只换出杆方向','母球固定，最近离库净距始终5cm；改变B与目标袋，保持球距42cm、切角0°。',
         [scenario([HX-R-.05,.10],p,'短库') for p in [0,2,4,5,1,3]]),
        ('8','角落同一母球，只换出杆方向','母球到右/下库净距均5cm；改变B与目标袋，观察角落对不同杆尾方向的限制。',
         [scenario([HX-R-.05,HZ-R-.05],p,'长库') for p in [0,1,2,4,5]]),
    ]
    # Mirroring in X preserves space, distances and cut under the matching pocket.
    mirrors={0:1,1:0,2:3,3:2,4:4,5:5}
    for _,_,_,rows in groups:
        for q in rows:
            c=np.array(q['cue'])*[-1,1];b=np.array(q['ball'])*[-1,1]
            mirrored=evaluate(c,b,mirrors[q['pocket']])
            assert abs(mirrored['score']-q['score'])<1e-10
    # Same gap, ample space along the rail must score above facing the nearby rail.
    assert groups[2][3][1]['score'] > groups[0][3][1]['score']
    assert groups[3][3][1]['score'] > groups[1][3][1]['score']
    sections=[];records=[]
    for number,title,description,rows in groups:
        fig,axes=plt.subplots(3,2,figsize=(14,12),facecolor='#f6f8f1')
        fig.subplots_adjust(left=.035,right=.97,top=.84,bottom=.055,hspace=.38,wspace=.12)
        for i,ax in enumerate(axes.flat):
            if i<len(rows):draw(ax,rows[i],f'{number}-{i+1}')
            else:ax.axis('off')
        fig.suptitle(f'出杆空间分校准 · {number} · {title}',fontsize=20,y=.975)
        fig.text(.04,.93,'蓝箭头：击球方向；紫箭头：杆尾方向（最多画35cm）；橙虚线：B至目标袋。',fontsize=12,color='#365b48')
        fig.text(.04,.905,'每小图只有一颗母球C、一颗目标球B。球距均42cm、切角0°；只计算空间分，不计总分。',fontsize=11,color='#365b48')
        fig.text(.04,.018,'现行试验公式；“杆后”是到矩形库线的平面净空代理，并非完整架杆/仰角/站位可行性。合成示例未作物理入袋验证。',fontsize=10,color='#526859')
        filename=f'group-{number}.png';fig.savefig(OUT/filename,dpi=130);plt.close(fig)
        htmlrows=''.join(f'<tr><td>{number}-{i+1}</td><td>{NAMES[q["pocket"]]}</td><td>{q["gap"]*100:.1f}</td><td>{q["rear"]*100:.1f}</td><td>{q["railAngle"]:.1f}°</td><td>{q["rearFactor"]*100:.1f}%</td><td>{q["sideFactor"]*100:.1f}%</td><td><b>{q["score"]:.1f}</b></td></tr>' for i,q in enumerate(rows))
        sections.append(f'<section id="group-{number}"><h2>{number} · {title}</h2><p>{description}</p>'
            f'<a href="{filename}" target="_blank"><img src="{filename}" alt="{title}的不同摆法和出杆空间分对比"></a>'
            '<div class="table"><table><tr><th>编号</th><th>目标袋</th><th>离库净距cm</th><th>杆后净空cm</th><th>与参考库夹角</th><th>后方系数</th><th>侧向系数</th><th>空间分</th></tr>'+htmlrows+'</table></div></section>')
        records.append(dict(number=number,title=title,description=description,rows=rows))
    result=dict(schema='space-score-controlled-review-v1',synthetic=True,physicalValidation=False,
                sourceSHA256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                coordinates='world XZ metres, landscape +X right/+Z down; Y up',
                spacePolicy={k:POLICY[k] for k in ['rearRoomScale','sideGapScale','sideGapWeight']},
                distancePolicyDecision='v2 selected by user 2026-10-25; not part of this score',groups=records)
    (OUT/'data.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,allow_nan=False))
    (OUT/'index.html').write_text('''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>出杆空间分 · 长库短库与方向校准</title><style>
body{margin:0;background:#f1f4ed;color:#243f32;font:17px system-ui}header,main,footer{max-width:1350px;margin:auto;padding:24px}p,li{line-height:1.8}nav{position:sticky;top:0;background:#fffff5f5;padding:16px;display:flex;flex-wrap:wrap;gap:20px;justify-content:center;z-index:10}a{color:#26765d}img{width:100%}section{scroll-margin-top:90px;border-bottom:1px solid #ccc;padding:20px 0}.table{overflow:auto}table{border-collapse:collapse;width:100%;background:white}td,th{padding:12px;border:1px solid #dae3d4;white-space:nowrap;text-align:center}header{background:#e4ecde}</style>
<header><h1>单独校准出杆空间分</h1><p>球距分已按用户选择采用放缓版。本页只检验现行空间分，不调系数、不计算总分。8组46个合成球形，每个小图的球距固定42cm、切角固定0°；通过改变母球位置、B位置与目标袋，对照库边距离和出杆方向。</p>
<p>建议先看组1与3、组2与4：同样靠库距离，朝桌内与顺库出杆有什么差别。再看组6、7、8：母球完全不动，只有B和目标袋变化，最近离库距离都是5cm。</p>
<p>蓝箭头是击球方向，紫箭头是杆尾方向，橙虚线是B的目标进球方向。参考库夹角0°表示平行库边，90°表示垂直库边；朝向哪一侧须结合箭头看。每个小图是独立摆法。</p>
<details><summary>现行公式与近似边界</summary><p>距离单位为cm：空间分=100×(1−exp[−(h/25)²])×(0.75+0.25×(1−exp[−(g/8)²]))。h为母球中心沿杆尾射线至矩形库线的距离减球半径；g为最近矩形库线距球心减球半径。25和8是曲线尺度，不是合格线。</p><p>两项分别是后方空间系数与侧向系数。侧向贴库最多再扣25%；后方净空不足的影响更大。袋口开口也按矩形边界保守计算，未含杆径、打点高度、仰角、架杆或桌外站位。因此顺库高分、朝库低分都只是待校准的平面估计，并非实际出杆许可。</p></details>
<p>全部为新构造的几何校准例，未验证物理入袋，不是原题库推荐；没有改题库或正在运行的冻结计算。</p></header><nav>'''
        +''.join(f'<a href="#group-{n}">组{n}</a>' for n in range(1,9))+'</nav><main>'+''.join(sections)
        +'</main><footer><a href="data.json">全部坐标与分项系数</a></footer></html>')
    count=sum(len(g[3]) for g in groups);assert count==46
    (OUT/'verification.json').write_text(json.dumps(dict(original22MetricsMatch=True,all46CutZeroAndDistance42cm=True,
        allBallBodiesInside=True,allMirrorChecksPassed=True,sameGapParallelHigherPassed=True,groups=8,scenarios=count),indent=2))
    served=ROOT/'output/two-ball-multi-position-top10-20261024/comfort-space-review';served.mkdir(exist_ok=True)
    for p in OUT.iterdir():
        if p.is_file():shutil.copy2(p,served/p.name)
    for n,_,_,rows in groups:print(n,[(round(q['gap']*100,1),round(q['rear']*100,1),round(q['score'],1)) for q in rows])


if __name__=='__main__':main()
