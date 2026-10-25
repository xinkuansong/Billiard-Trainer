#!/usr/bin/env python3
"""One reproducible jittered tip/speed grid. Parameter preview, not shot validation."""
import hashlib
import json
import math
from pathlib import Path
import random
import re

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Circle, Rectangle

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/two-ball-strike-sampling-preview-20261024'


def main():
    source=ROOT/'output/two-ball-second-grid-20261024/preview-data.json'
    original=json.loads(source.read_text())['boards'][2]
    constants=ROOT/'QiuJi/Core/Physics/BTPhysicsConstants.swift'
    limit=float(re.search(r'static let miscueLimitFraction: Float = ([0-9.]+)',constants.read_text())[1])
    assert limit==.5
    seed_key='strike-grid-v1\0'+original['id']
    seed_digest=hashlib.sha256(seed_key.encode()).hexdigest()
    rng=random.Random(int(seed_digest,16))
    levels=[i*.15 for i in range(-3,4)];half=.075
    tips=[];empty=[]
    # Rows from top to bottom, columns from left to right, matching BTSpinPad.
    # spinX positive is screen LEFT, spinY positive is screen UP.
    for row,cy in enumerate(reversed(levels)):
        for col,cx in enumerate(reversed(levels)):
            if max(abs(cx)-half,0)**2+max(abs(cy)-half,0)**2>=limit**2:
                empty.append(dict(row=row,col=col,center=[cx,cy]));continue
            for attempts in range(1,10001):
                x,y=rng.uniform(cx-half,cx+half),rng.uniform(cy-half,cy+half)
                if x*x+y*y<=limit*limit: break
            else: raise RuntimeError('Sampling rejection budget exhausted')
            tips.append(dict(id=len(tips)+1,row=row,col=col,center=[cx,cy],spinX=x,spinY=y,attempts=attempts))
    speeds=[]
    for i in range(14):
        center=.6+i*.3;lo=max(.6,center-.15);hi=min(4.5,center+.15)
        speeds.append(dict(id=i+1,center=center,lower=lo,upper=hi,velocity=rng.uniform(lo,hi)))
    combos=[dict(tipID=t['id'],speedID=v['id'],spinX=t['spinX'],spinY=t['spinY'],velocity=v['velocity']) for t in tips for v in speeds]
    assert len(tips)==45 and len(empty)==4 and len(combos)==630
    assert len({(t['row'],t['col']) for t in tips})==45
    for t in tips:
        assert math.hypot(t['spinX'],t['spinY'])<=limit
        assert abs(t['spinX']-t['center'][0])<=half and abs(t['spinY']-t['center'][1])<=half
    assert all(v['lower']<=v['velocity']<=v['upper'] and .6<=v['velocity']<=4.5 for v in speeds)
    assert all(a['velocity']<b['velocity'] for a,b in zip(speeds,speeds[1:]))
    OUT.mkdir(parents=True,exist_ok=True)
    data=dict(schema='strike-grid-parameter-preview-v1',originalLayout=original['id'],originalAngle=original['angle'],
              sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),seedSHA256=seed_digest,
              seedRule='Python Random(int(SHA256(UTF8("strike-grid-v1" + NUL + layoutID)).hexdigest(),16))',
              coordinateContract='spinX positive=left; spinY positive=high; contact offset/ball radius R',
              sampling=dict(tipGridStep=.15,tipJitterPerAxis=half,tipLimit=limit,speedRange=[.6,4.5],speedCenterStep=.3,speedJitter=.15),
              tips=tips,speeds=speeds,combinations=combos,
              validation=dict(tipCircleAndCells=True,speedIntervals=True,uniqueCombinations=630,cueAccessChecked=False,physicsSimulated=False))
    (OUT/'sampling-example.json').write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
    font_manager.fontManager.addfont('/Library/Fonts/Arial Unicode.ttf')
    plt.rcParams.update({'font.family':'Arial Unicode MS','axes.unicode_minus':False})
    fig=plt.figure(figsize=(15,9),facecolor='#f8faf8')
    ax=fig.add_axes([.045,.16,.54,.68]);sv=fig.add_axes([.66,.17,.29,.64])
    ax.set_aspect('equal');ax.set_xlim(-.60,.60);ax.set_ylim(-.59,.59);ax.axis('off')
    disc=Circle((0,0),limit,facecolor='#e9f1e9',edgecolor='#466b5b',lw=2,zorder=1)
    ax.add_patch(disc)
    for v in [(-.525+i*.15) for i in range(8)]:
        line,=ax.plot([v,v],[-.525,.525],color='#b8c9be',lw=.75,zorder=2);line.set_clip_path(disc)
        line,=ax.plot([-.525,.525],[v,v],color='#b8c9be',lw=.75,zorder=2);line.set_clip_path(disc)
    for t in tips:
        cx,cy=t['center'];x,y=-t['spinX'],t['spinY']
        ax.plot([-cx,x],[cy,y],color='#8b9c93',lw=.65,zorder=2,clip_path=disc)
        if cx*cx+cy*cy<=limit*limit:
            ax.plot(-cx,cy,marker='+',color='#7c8e82',ms=5,mew=.8,zorder=3)
        ax.add_patch(Circle((x,y),.012,facecolor='#217e9a',edgecolor='white',lw=.55,zorder=4))
        # Place labels toward the interior so edge points stay legible.
        ay=y+(-.025 if y>0 else .025)
        ax.text(x,ay,f"{t['id']:02}",ha='center',va='center',fontsize=8,color='#284e60',zorder=5)
    ax.plot(0,0,marker='+',color='#476556',ms=9,mew=1.1,zorder=3)
    ax.text(0,.555,'高杆（+）',ha='center',fontsize=12,color='#435e50')
    ax.text(0,-.555,'低杆（−）',ha='center',fontsize=12,color='#435e50')
    ax.text(-.555,0,'左塞\n（+）',ha='center',va='center',fontsize=11,color='#435e50')
    ax.text(.555,0,'右塞\n（−）',ha='center',va='center',fontsize=11,color='#435e50')
    ax.set_title('45个随机打点 · 合法区域放大图（外圈半径0.5R）',fontsize=15,pad=18,loc='center')
    for i,v in enumerate(speeds):
        sv.plot([v['lower'],v['upper']],[i,i],color='#c8d8d0',lw=9,solid_capstyle='round',zorder=1)
        sv.plot(v['center'],i,marker='|',color='#71887c',ms=11,zorder=2)
        sv.plot(v['velocity'],i,marker='o',color='#bf7b26',ms=6,zorder=3)
        sv.text(4.70,i,f"{v['velocity']:.3f}",va='center',fontsize=10,color='#8a591c')
    sv.set_yticks(range(14),[f'{i+1:02}' for i in range(14)],fontsize=10)
    sv.set_ylim(13.7,-.7);sv.set_xlim(.45,5.45)
    sv.set_xticks([.6,1.5,2.5,3.5,4.5]);sv.set_xlabel('杆速（m/s）',fontsize=12,labelpad=10)
    sv.set_title('14个随机杆速',loc='left',fontsize=15,pad=18)
    sv.text(4.70,-1.05,'实际值',fontsize=10,color='#8a591c')
    sv.spines[['left','top','right']].set_visible(False);sv.tick_params(axis='y',length=0)
    sv.set_facecolor('#f8faf8')
    fig.suptitle('一个球形的随机参数组合：45个打点 × 14个杆速 = 630组',x=.05,ha='left',y=.97,fontsize=23)
    fig.text(.05,.905,'每个打点格在圆内随机取1点；每个杆速档随机取1值；全部两两组合。',fontsize=13,color='#576f61')
    fig.text(.05,.075,'蓝点：实际打点    灰十字：格中心    浅绿条：杆速随机区间    金点：实际杆速',fontsize=12,color='#576f61')
    fig.text(.05,.03,f"原球形：{original['id']}（{original['angle']}°） · 仅参数预览，尚未检查球杆遮挡或运行物理模拟。",fontsize=11,color='#718479')
    fig.savefig(OUT/'random-grid-example.png',dpi=180)
    fig.savefig(OUT/'random-grid-example.svg')
    plt.close(fig)
    print(json.dumps(dict(layout=original['id'],tipCount=len(tips),speeds=[round(v['velocity'],4) for v in speeds],combinations=len(combos),maxTipRadius=max(math.hypot(t['spinX'],t['spinY']) for t in tips),checks='PASS'),ensure_ascii=False))


if __name__=='__main__': main()
