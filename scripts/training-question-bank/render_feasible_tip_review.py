#!/usr/bin/env python3
"""Render native accessibility results; does not infer or solve feasible tips."""
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import grid_anchor_gallery as base

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/accuracy-feasible-tip-20261021'

def main():
    samples = json.loads((OUT/'samples.json').read_text())
    geom = json.loads((ROOT/'QiuJi/Resources/training-grid-bank.json').read_text())['geometry']
    def font(n): return ImageFont.truetype(base.FONT,n)
    def xy(p): return (420+float(p[0])*280,350+float(p[1])*280)
    def point(p): return np.array([p['x'],p['z']])
    (OUT/'images').mkdir(exist_ok=True)
    cards=[]
    for i,s in enumerate(samples,1):
        b=s['board']; tip=s['tip']; im=Image.new('RGB',(1200,680),'#f2f7f4');d=ImageDraw.Draw(im)
        d.text((28,22),f'{i:02d}  '+s['name'],font=font(28),fill='#173f35')
        d.text((28,68),'目标：'+base.POCKET_NAMES[b['pocketIndex']]+f"  ·  实际切角 {b['angle']:.2f}°",font=font(22),fill='#567467')
        base.table(d,geom,xy,280)
        c,o,a=map(point,[b['cue'],b['target'],b['effectiveAim']]);g=o-2*geom['radius']*(a-o)/np.linalg.norm(a-o)
        d.line([xy(c),xy(g)],fill='#d5942a',width=3);d.line([xy(g),xy(a)],fill='#187b63',width=2)
        for p,fill in [(g,None),(o,'#de6557'),(c,'white')]:
            x,y=xy(p);r=geom['radius']*280;d.ellipse((x-r,y-r,x+r,y+r),fill=fill,outline='#245946',width=2)
        px,py=xy(point(geom['pockets'][b['pocketIndex']]['center']));d.ellipse((px-15,py-15,px+15,py+15),outline='#d5942a',width=3)
        cx,cy,r=1000,320,145
        d.text((852,145),'实际出杆可行打点',font=font(22),fill='#173f35')
        d.ellipse((cx-r,cy-r,cx+r,cy+r),fill='#e0e6e2',outline='#7b9085',width=2)
        for row,line in enumerate(s['feasibleDisc']):
            for col,ok in enumerate(line):
                if ok:
                    x=cx-(col-10)*.05*r;y=cy-(10-row)*.05*r
                    d.rectangle((x-3.5,y-3.5,x+3.5,y+3.5),fill='#75bc88')
        d.line((cx-r,cy,cx+r,cy),fill='#9baba1');d.line((cx,cy-r,cx,cy+r),fill='#9baba1')
        d.ellipse((cx-r*.5,cy-r*.5,cx+r*.5,cy+r*.5),outline='#8b9e92',width=1)
        x,y=cx-tip['x']*r,cy-tip['y']*r;d.ellipse((x-6,y-6,x+6,y+6),fill='#de6557',outline='white',width=2)
        d.text((850,495),'绿色：可行区域  红点：本题打点',font=font(17),fill='#567467')
        old='可行' if s['centerAvailable'] else '不可行'
        chosen='中杆' if not tip['raisedForClearance'] else '高杆（避让）'
        d.text((28,570),f"中杆：{old}  →  {chosen}   x={tip['x']:.4f}R  y={tip['y']:.4f}R",font=font(24),fill='#173f35')
        d.text((28,613),f"正式方向出杆检查：通过  ·  球杆仰角 {s['elevationDegrees']:.2f}°  ·  同一球形未移动",font=font(20),fill='#567467')
        name=f'images/{i:02d}.png';im.save(OUT/name)
        cards.append(f'<article><img src="{name}" alt="{s["name"]}"><details><summary>球形索引</summary>{b["id"]}<br>{b["combinationID"]}</details></article>')
    raised=sum(s['tip']['raisedForClearance'] for s in samples)
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>母球靠库／袋口 · 可行打点验证</title><style>body{margin:0;background:#eaf1ed;color:#173f35;font:17px -apple-system,sans-serif}main{max-width:1400px;margin:auto;padding:28px}p{line-height:1.7}article{background:#f2f7f4;border-radius:16px;margin:20px 0;overflow:hidden}img{width:100%;display:block}details{padding:14px}a{color:#137f70}</style><main><h1>母球靠库／袋口 · 可行打点验证</h1>'''
    page+=f'<p>从当前球形库选出10个位置样例：六个袋口附近、四边库附近。默认不开放高低杆／左右塞时，{raised}例中杆不可行，改用最低可行高杆；其余保留中杆。全部通过原生页面的出杆许可检查。绿色区域由原生可行性判据采样，红点为保存的精确打点。</p>'
    page+='<p>本页展示的是出杆可行性，不是进球求解；连线为正式瞄准几何。其他杆法开关组合也使用相同判据验证，不能找到可行打点时在同组合换题。打点盘正左为左塞，向上为高杆。</p>'+''.join(cards)+'<p><a href="samples.json">原生检查数据</a></p></main></html>'
    (OUT/'可行打点验证.html').write_text(page)
    print(f'Rendered {len(samples)} samples, {raised} raised for clearance')
if __name__=='__main__':main()
