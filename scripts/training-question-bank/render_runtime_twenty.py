#!/usr/bin/env python3
"""Render the native production sampler export; never select or solve layouts here."""
import collections
import hashlib
import html
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import grid_anchor_gallery as base

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/accuracy-runtime-twenty-20261021'
BANK = ROOT / 'QiuJi/Resources/training-grid-bank.json'
FONT = base.FONT
INK, GREEN, ORANGE = '#173f35', '#137f70', '#d58726'
LABELS = [['近直球0–10°', '小角度11–30°', '中角度31–50°', '大角度51–70°', '极薄球71–85°'],
          ['角袋', '中袋'], ['短', '中', '长'], ['短', '中', '长'], ['离库', '半贴库', '贴库']]
NAMES = ['生成角度档位', '目标袋型', '母球距离 CO', '目标球距生成P', '库边情况']
KEYS = ['angleIndex', 'pocketType', 'cueIndex', 'objectIndex', 'railIndex']

def point(p): return np.array([p['x'], p['z']], dtype=float)
def xy(p): return (600 + p[0]*390, 395 + p[1]*390)
def font(n): return ImageFont.truetype(FONT, n)
def dashed(draw, a, b, color=ORANGE, width=3):
    a, b = np.array(a), np.array(b); length = np.linalg.norm(b-a)
    if length == 0: return
    for i in range(math.ceil(length/17)):
        start = i*17
        if start < length:
            draw.line([tuple(a+(b-a)*start/length), tuple(a+(b-a)*min(start+10,length)/length)], fill=color, width=width)

def make_image(s, geom, cell):
    b=s['board']; p=point(s['generationP']); a=point(b['effectiveAim']); c=point(b['cue']); o=point(b['target'])
    gg=point(s['generationGhost']); ga=point(s['actualGhost'])
    delta=b['angle']-b['generationAngle']
    im=Image.new('RGB',(1200,800),'#f4f8f6'); d=ImageDraw.Draw(im)
    d.text((26,18),f"{s['number']:02d}  {base.POCKET_NAMES[b['pocketIndex']]} · {LABELS[4][cell['railIndex']]}",font=font(28),fill=INK)
    d.text((26,66),f"生成 {b['generationAngle']:.2f}°",font=font(34),fill=ORANGE)
    d.text((408,66),f"实际 {b['angle']:.2f}°",font=font(34),fill=GREEN)
    d.text((818,66),f"差值 {delta:+.2f}°",font=font(34),fill='#6c527c')
    base.table(d,geom,xy,390)
    pc=point(geom['pockets'][b['pocketIndex']]['center']); px,py=xy(pc)
    d.ellipse((px-22,py-22,px+22,py+22),outline='#dfb54e',width=4)
    for x,y in [(c,gg),(gg,p)]: dashed(d,xy(x),xy(y))
    for x,y in [(c,ga),(ga,a)]: d.line([xy(x),xy(y)],fill=GREEN,width=3)
    for pos,col in [(p,ORANGE),(a,GREEN)]:
        x,y=xy(pos); d.line((x-6,y,x+6,y),fill=col,width=3);d.line((x,y-6,x,y+6),fill=col,width=3)
    r=geom['radius']*390
    for pos,col,fill in [(gg,ORANGE,None),(ga,GREEN,None),(o,'#9c4138','#de6b5c'),(c,'#496a63','#ffffff')]:
        x,y=xy(pos);d.ellipse((x-r,y-r,x+r,y+r),outline=col,fill=fill,width=3)
    co=float(np.linalg.norm(c-o)); op=float(np.linalg.norm(p-o)); gap=max(0,s['railGap'])*100
    d.text((26,678),f"CO {LABELS[2][cell['cueIndex']]} {co:.2f}m  ·  OP {LABELS[3][cell['objectIndex']]} {op:.2f}m  ·  球面库距 {gap:.2f}cm",font=font(25),fill=INK)
    d.text((26,719),b['combinationID']+'  ·  '+b['id'],font=font(22),fill='#65766f')
    status='角袋：几何候选' if b['pocketIndex']<4 else '中袋：已通过直进筛选'
    d.text((26,758),status+'  ·  参考线不是物理轨迹',font=font(22),fill='#65766f')
    return im

def svg(s, geom):
    b=s['board']; c=point(b['cue']);o=point(b['target']);p=point(s['generationP']);a=point(b['effectiveAim'])
    gg=point(s['generationGhost']);ga=point(s['actualGhost'])
    parts=['<svg viewBox="0 112 1200 550" role="img" aria-label="本题球形与两种瞄准几何">']
    left,top=xy(np.array([-geom['length']/2,-geom['width']/2]));parts.append(f'<rect x="{left}" y="{top}" width="{geom["length"]*390}" height="{geom["width"]*390}" fill="#e4f2ed"/>')
    def line(a,b,cl,color,width=3,dash=''):
        x1,y1=xy(a);x2,y2=xy(b)
        return f'<line class="{cl}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}" {dash}/>'
    def circle(p,r,color,fill='none',cl=''):
        x,y=xy(p);return f'<circle class="{cl}" cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{color}" stroke-width="3"/>'
    for l in geom['lines']:parts.append(line(point(l['start']),point(l['end']),'', '#235948'))
    for arc in geom['arcs']:
        angles=np.linspace(arc['start'],arc['start']+(arc['end']-arc['start'])%(2*np.pi),48)
        ps=[xy(point(arc['center'])+arc['radius']*np.array([np.cos(t),np.sin(t)])) for t in angles]
        parts.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in ps)+'" fill="none" stroke="#235948" stroke-width="3"/>')
    for pocket in geom['pockets']:
        parts.append(circle(point(pocket['center']),pocket['radius']*390,'#243c34','#243c34'))
        parts.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in [xy(point(p)) for p in pocket['lip']])+'" fill="#243c34"/>')
    parts.append(circle(point(geom['pockets'][b['pocketIndex']]['center']),22,'#dfb54e'))
    for x,y in [(c,gg),(gg,p)]:parts.append(line(x,y,'gen',ORANGE,dash='stroke-dasharray="10 7"'))
    for x,y in [(c,ga),(ga,a)]:parts.append(line(x,y,'actual',GREEN))
    for pos,col,cl in [(p,ORANGE,'gen'),(a,GREEN,'actual')]:
        x,y=xy(pos);parts.append(f'<path class="{cl}" d="M{x-6},{y}h12 M{x},{y-6}v12" stroke="{col}" stroke-width="3"/>')
    r=geom['radius']*390
    for pos,col,fill,cl in [(gg,ORANGE,'none','gen'),(ga,GREEN,'none','actual'),(o,'#9c4138','#de6b5c',''),(c,'#496a63','white','')]:parts.append(circle(pos,r,col,fill,cl))
    parts.append('</svg>');return ''.join(parts)

def main():
    data=json.loads((OUT/'native-twenty.json').read_text());bank=json.loads(BANK.read_text());geom=bank['geometry']
    assert data['bankSHA256']==hashlib.sha256(BANK.read_bytes()).hexdigest()
    samples=data['samples'];assert len(samples)==20 and len({s['board']['id'] for s in samples})==20
    table={c['id']:c for c in bank['combinationTable']}
    counts=[collections.Counter() for _ in KEYS];deltas=[];crossed=[];actual_bands=collections.Counter()
    (OUT/'samples').mkdir(exist_ok=True)
    cards=[];rows=[];images=[]
    for s in samples:
        b=s['board'];cell=table[b['combinationID']];delta=b['angle']-b['generationAngle'];deltas.append(delta)
        c,o,a,g=(point(v) for v in [b['cue'],b['target'],b['effectiveAim'],s['actualGhost']])
        d1=(a-o)/np.linalg.norm(a-o);d2=(g-c)/np.linalg.norm(g-c)
        angle=min(90,math.degrees(math.acos(float(np.clip(d1@d2,-1,1)))))
        assert abs(angle-b['angle'])<2e-4,(s['number'],angle,b['angle'])
        assert abs(np.linalg.norm(o-g)-2*geom['radius'])<2e-7
        for i,k in enumerate(KEYS):counts[i][cell[k]]+=1
        ai=next((i for i,upper in enumerate([10,30,50,70,85]) if math.floor(b['angle']+.5)<=upper),5)
        actual_bands[ai]+=1
        if ai!=cell['angleIndex']:crossed.append(s['number'])
        image=make_image(s,geom,cell);image.save(OUT/f"samples/{s['number']:02d}.png");images.append(image)
        title=f"{s['number']:02d} · {base.POCKET_NAMES[b['pocketIndex']]} · {LABELS[4][cell['railIndex']]}"
        classification=' / '.join(LABELS[i][cell[k]] for i,k in enumerate(KEYS))
        state='角袋几何候选' if b['pocketIndex']<4 else '中袋已通过直进筛选'
        cards.append(f'''<article id="q{s['number']}"><h3>{title}</h3><div class="angles"><span class="orange">生成 <b>{b['generationAngle']:.2f}°</b></span><span class="green">实际 <b>{b['angle']:.2f}°</b></span><span>差值 <b>{delta:+.2f}°</b></span></div>{svg(s,geom)}<p class="meta">{classification}<br>球面库距 {max(0,s['railGap'])*100:.2f}cm · {state}</p><details><summary>查看本题索引与原图</summary><p><a href="samples/{s['number']:02d}.png">打开高清图</a></p><code>{b['id']}<br>{b['combinationID']}</code></details></article>''')
        rows.append(f'<tr><td><a href="#q{s["number"]}">{s["number"]:02d}</a></td><td>{base.POCKET_NAMES[b["pocketIndex"]]}</td><td>{b["generationAngle"]:.2f}°</td><td>{b["angle"]:.2f}°</td><td>{delta:+.2f}°</td><td>{LABELS[4][cell["railIndex"]]}</td></tr>')
    max_index=max(range(20),key=lambda i:abs(deltas[i]));mean=sum(map(abs,deltas))/20
    summary={'seed':data['seed'],'bankSHA256':data['bankSHA256'],'sampleCount':20,'counts':[{LABELS[i][v]:counts[i][v] for v in range(len(LABELS[i]))} for i in range(5)],'actualAngleBands':{(LABELS[0]+['>85°'])[i]:actual_bands[i] for i in range(6)},'crossedRoundedAngleBands':crossed,'maxAbsoluteDelta':abs(deltas[max_index]),'maxDeltaQuestion':max_index+1,'meanAbsoluteDelta':mean,'sampling':'TrainingBankStore.load().draw(defaultConfig, seed), original order, no reselection','angleMeaning':'generation parameter vs production effectivePocketAimPoint/cutAngle; not measured shot trajectory'}
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    # Full-order contact sheet, useful outside the interactive page.
    sheet=Image.new('RGB',(1200,10*400),'white')
    for i,im in enumerate(images):sheet.paste(im.resize((600,400),Image.Resampling.LANCZOS),((i%2)*600,(i//2)*400))
    sheet.save(OUT/'20题总览.jpg',quality=92)
    table_rows=[]
    for i,name in enumerate(NAMES):
        for j,label in enumerate(LABELS[i]):
            n=counts[i][j];target=data['weights'][i][j]
            table_rows.append(f'<tr><td>{name}</td><td>{label}</td><td>{target:.0%}</td><td><b>{n}</b> / 20</td><td>{n/20:.0%}</td><td>{(n/20-target)*100:+.0f} 个百分点</td></tr>')
    actual='、'.join(f'{(LABELS[0]+[">85°"])[i]}：{actual_bands[i]}题' for i in range(6) if actual_bands[i])
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>当前抽题 · 20题角度对照</title><style>
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#edf3ef;color:#173f35;font:16px -apple-system,BlinkMacSystemFont,sans-serif}main{max-width:1480px;margin:auto;padding:30px 24px}h1{font-size:30px;margin:0 0 16px}p{line-height:1.75}h2{font-size:23px;margin:28px 0 14px}.intro,.panel{background:white;border:1px solid #d8e3dd;border-radius:15px;padding:22px;margin-bottom:18px}.kpis{display:flex;gap:30px;flex-wrap:wrap}.kpis b{font-size:28px;display:block}.muted,.meta{color:#5f756b}.toolbar{position:sticky;top:0;z-index:3;background:#f8fbf8ee;backdrop-filter:blur(8px);padding:14px 20px;border:1px solid #cdded2;border-radius:12px;display:flex;gap:24px;flex-wrap:wrap}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px;margin-top:20px}article{background:#f4f8f6;border:1px solid #cdded2;border-radius:15px;overflow:hidden;scroll-margin-top:80px}h3{font-size:19px;margin:20px 20px 12px}.angles{display:flex;justify-content:space-between;gap:10px;padding:0 20px;font-size:16px}.angles b{font-size:23px;display:block;margin-top:5px}.orange{color:#aa6512}.green{color:#137f70}svg{display:block;width:100%;height:auto}.meta,article details{padding:0 20px;margin:8px 0 18px;font-size:14px}table{width:100%;border-collapse:collapse;font-size:15px}td,th{padding:10px 14px;text-align:left;border-bottom:1px solid #e1e8e3}th{background:#edf5ee}a{color:#137f70}.scroll{overflow:auto}.hide-gen .gen,.hide-actual .actual{display:none}input{accent-color:#137f70}summary{cursor:pointer}@media(max-width:850px){.grid{grid-template-columns:1fr}main{padding:20px 12px}.angles b{font-size:22px}}@media print{.toolbar{position:static}article{break-inside:avoid}}
</style><main>'''
    page+=f'''<h1>当前抽题逻辑 · 一轮20题</h1><div class="intro"><p>默认全随机 · 固定中杆 · 原生 <code>TrainingGridBank.draw</code> · 种子 <b>{data['seed']}</b>。一次抽出后按原顺序展示，未挑题、未补齐档位；20个球形互不重复。</p><div class="kpis"><div><b>{mean:.3f}°</b>平均绝对角差</div><div><b>{abs(deltas[max_index]):.3f}°</b>最大绝对角差 · 第{max_index+1:02d}题</div><div><b>{len(crossed)}题</b>实际角与生成角跨档</div></div><p class="muted">生成角度仅为题库生成/分类参数。实际角度来自正式有效入袋点及其假想球，与App答案一致；差值＝实际－生成。这里的“实际”指正式几何切角，并非出杆后的实测碰撞角。</p></div>'''
    page+='<details class="panel" open><summary><b>本轮分布与长期权重</b></summary><p>20题中每题占5%，短轮比例会波动，不要求精确满足长期权重。角度、距离统计按保存的生成组合标签。</p><div class="scroll"><table><tr><th>条件</th><th>档位</th><th>目标权重</th><th>本轮题数</th><th>本轮比例</th><th>差值</th></tr>'+''.join(table_rows)+'</table></div><p>真实切角另行分档：'+actual+'。跨档题：'+('、'.join(f'{n:02d}' for n in crossed) or '无')+'。角度分档按四舍五入至整数，与现有档位口径一致。</p></details>'
    page+='<div class="toolbar"><label><input type="checkbox" id="gen" checked> 橙色虚线：生成参考几何</label><label><input type="checkbox" id="actual" checked> 绿色实线：正式瞄准几何</label><span>白球＝母球；红球＝目标球；空心圈＝对应假想球；金圈＝目标袋</span></div><p class="muted">坐标按X–Z等比例绘制，屏幕右为+X、下为+Z。两套参考线可独立开关；它们不是物理轨迹。角袋仍为几何候选，中袋沿用已确认的直进筛选。</p><div class="grid">'+''.join(cards)+'</div>'
    page+='<details class="panel" style="margin-top:25px"><summary><b>20题角度明细</b></summary><div class="scroll"><table><tr><th>题号</th><th>袋口</th><th>生成</th><th>实际</th><th>差值</th><th>库边</th></tr>'+''.join(rows)+'</table></div></details><p><a href="20题总览.jpg">下载20题总览</a> · <a href="native-twenty.json">原生抽题记录</a> · <a href="summary.json">分布数据</a></p></main><script>for(const id of ["gen","actual"]){document.getElementById(id).addEventListener("change",e=>document.body.classList.toggle("hide-"+id,!e.target.checked))}</script></html>'
    (OUT/'当前抽题20题.html').write_text(page)
    print(json.dumps(summary,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
