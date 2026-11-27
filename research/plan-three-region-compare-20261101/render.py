"""Standalone research charts and a local interactive comparison, not App UI."""
from pathlib import Path
import json, math, statistics
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/plan-three-region-compare-20261101'
data=json.loads((OUT/'data.json').read_text())
cases=data['cases'];G=data['audit']['geometry'];L,W,R=[G[k] for k in ['length','width','radius']]
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
def point(p,box):
    x,y,w,h=box
    return (x+(p[0]/L+.5)*w,y+(p[1]/W+.5)*h)
def line_dashed(draw,points,fill,width=3,dash=10,gap=7):
    phase=0
    for a,b in zip(points,points[1:]):
        length=math.dist(a,b)
        if length==0:continue
        t=0
        while t<length:
            chunk=min(length-t,(dash if phase<dash else dash+gap)-phase)
            if phase<dash:
                q=lambda f:(a[0]+(b[0]-a[0])*f/length,a[1]+(b[1]-a[1])*f/length)
                draw.line([q(t),q(t+chunk)],fill=fill,width=width)
            t+=chunk;phase=(phase+chunk)%(dash+gap)

def draw_case(im,c,rect):
    d=ImageDraw.Draw(im);x,y,w,h=rect
    d.rounded_rectangle((x,y,x+w,y+h),radius=17,fill='#ffffff',outline='#dce3df',width=2)
    d.text((x+24,y+20),f"{c['number']:02d}  底图 {c['sample']} · {c['pocketName']}",font=font(23),fill='#183c35')
    box=(x+30,y+77,w-60,(w-60)/2)
    bx,by,bw,bh=box
    d.rounded_rectangle((bx-9,by-9,bx+bw+9,by+bh+9),radius=16,fill='#294c43')
    d.rectangle((bx,by,bx+bw,by+bh),fill='#225e4d')
    for a in range(1,8):
        gx=bx+bw*a/8;d.line((gx,by,gx,by+bh),fill='#2c6958',width=1)
    for a in range(1,4):
        gy=by+bh*a/4;d.line((bx,gy,bx+bw,gy),fill='#2c6958',width=1)
    fill=Image.new('RGBA',im.size,(0,0,0,0));fd=ImageDraw.Draw(fill)
    for poly in c['variants'][0]['loops']:fd.polygon([point(p,box) for p in poly],fill=(92,222,198,75))
    im.alpha_composite(fill);d=ImageDraw.Draw(im)
    for poly in c['variants'][0]['loops']:d.line([point(p,box) for p in poly],fill='#68e2cd',width=3)
    for poly in c['current']['loops']:line_dashed(d,[point(p,box) for p in poly],'#ffce61',3,8,5)
    pockets=[[-L/2,-W/2],[L/2,-W/2],[-L/2,W/2],[L/2,W/2],[0,-W/2],[0,W/2]]
    for i,p in enumerate(pockets):
        px,py=point(p,box);d.ellipse((px-10,py-10,px+10,py+10),fill='#102b26')
        if i==c['pocket']:d.ellipse((px-13,py-13,px+13,py+13),outline='#ffd36e',width=3)
    b=point(c['ball'],box);a=point(c['aim'],box)
    line_dashed(d,[b,a],'#d7dfd8',2,5,5)
    br=R/L*bw
    d.ellipse((b[0]-br-3,b[1]-br-3,b[0]+br+3,b[1]+br+3),outline='#ffd36e',width=2)
    d.ellipse((b[0]-br,b[1]-br,b[0]+br,b[1]+br),fill='#2c69a5',outline='#dbe8f1',width=1)
    d.text(b,'2',font=font(13),fill='white',anchor='mm')
    v=c['variants'][0]
    d.text((x+24,y+h-62),f"2 cm 简化区与精细区重合 {v['overlapPct']:.1f}%",font=font(21),fill='#24463e')
    d.text((x+24,y+h-31),f"粗网格计算 {v['milliseconds']:.1f} ms   ·   现扇形 5°–20° / 11–55 cm",font=font(17),fill='#69796f')

im=Image.new('RGBA',(1680,2470),'#f1f4ef');d=ImageDraw.Draw(im)
d.text((50,32),'母球建议落区：简化版与当前扇形',font=font(39),fill='#173c33')
d.text((50,91),'相同目标球、相同有效进球点 · 5 张旧底图 / 8 个球袋组合 · 第三球未选，扇形显示双侧',font=font(22),fill='#526a5e')
d.line((52,149,96,149),fill='#3fbca5',width=5);d.text((110,133),'青绿：2 cm 网格 / ≥85 分',font=font(23),fill='#23483c')
line_dashed(d,[(540,149),(584,149)],'#c79125',4,9,5);d.text((598,133),'金黄虚线：当前固定扇形',font=font(23),fill='#23483c')
for i,c in enumerate(cases):draw_case(im,c,(40+(i%2)*820,188+(i//2)*550,780,528))
d=ImageDraw.Draw(im)
d.text((50,2404),'独立研究示意，非 App 截图。仅评分区域，不代表首杆可达、无遮挡或一定进球；耗时为本机 Python 实测。',font=font(20),fill='#526a5e')
im.convert('RGB').save(OUT/'overview.png')
preview=Image.new('RGBA',(1680,1370),'#f1f4ef')
preview.paste(im.crop((0,0,1680,182)),(0,0))
for i,index in enumerate([0,2,5,6]):draw_case(preview,cases[index],(40+(i%2)*820,188+(i//2)*550,780,528))
ImageDraw.Draw(preview).text((50,1312),'四组代表对比 · 完整图册含全部 8 组，可切换 2 / 4 / 6 cm 与精细参考边界。',font=font(22),fill='#526a5e')
preview.convert('RGB').save(OUT/'comparison-four.png')

# Only show 4 cm and 6 cm as alternative precision choices; default is 2 cm.
payload=[]
for c in cases:
    slim={k:c[k] for k in ['number','sample','pocketName','pocket','ball','aim','current','variants','fine']}
    for item in [slim['fine'],slim['current'],*slim['variants']]:
        item['loops']=[[[round(v,7) for v in p] for p in poly] for poly in item['loops']]
    payload.append(slim)
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>母球落区 · 简化对比</title>
<style>*{box-sizing:border-box}body{margin:0;background:#f0f4ee;color:#163e33;font:16px -apple-system,BlinkMacSystemFont,sans-serif}main{max-width:1260px;margin:auto;padding:34px 28px}h1{font-size:32px;margin:0 0 14px}p{line-height:1.7;color:#5a6e63}.eyebrow{font-size:13px;letter-spacing:2px;color:#658779;margin-bottom:12px}.toolbar,.switches{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin:18px 0}select,button{font:inherit;border:1px solid #bdcec2;padding:11px 15px;border-radius:10px;background:white;color:#214c3c;cursor:pointer}button.active{background:#214f40;color:white}label{display:flex;align-items:center;gap:8px}input{accent-color:#245b48;width:18px;height:18px}.panel{background:white;border-radius:18px;border:1px solid #dce5db;padding:22px;margin-top:20px}.legend{display:flex;gap:24px;flex-wrap:wrap;font-size:14px;margin:0 0 16px}.legend span:before{content:'';display:inline-block;width:23px;height:3px;background:var(--c);margin-right:8px;vertical-align:middle}svg{width:100%;display:block}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-top:20px}.metric{background:#f2f6ef;border-radius:12px;padding:16px}.metric strong{display:block;font-size:27px;margin:7px 0}.metric small{color:#64766a}table{border-collapse:collapse;width:100%;font-size:14px}td,th{text-align:left;padding:12px;border-bottom:1px solid #e2e9e1}.scroll{overflow:auto}.note{font-size:14px;line-height:1.7}a{color:#266b53}@media(max-width:650px){main{padding:20px 12px}h1{font-size:25px}.metrics{grid-template-columns:repeat(2,1fr)}.panel{padding:12px}}</style>
<main><div class="eyebrow">球迹 / 走位研究 / 2026.11.01</div><h1>不用毫米级，也能画出合适的母球落区</h1><p>固定目标球与目标袋，用已有舒适度公式圈出 ≥85 分的位置。只把计算网格变粗；评分公式、门槛保持一致。<br>第三球未选，当前扇形按双侧显示；第一球视为已经进袋。</p>
<div class="toolbar"><label>球形 <select id="case"></select></label><label>网格 <select id="step"><option value="0">2 cm（建议）</option><option value="1">4 cm</option><option value="2">6 cm</option></select></label></div>
<div class="switches"><button class="active" data-mode="both">叠加对比</button><button data-mode="old">只看当前扇形</button><button data-mode="new">只看简化区域</button><label><input id="fine" type="checkbox">显示 1 mm 精细参考边界</label></div>
<section class="panel"><div class="legend"><span style="--c:#53c9b1">青绿：简化 ≥85 分区域</span><span style="--c:#e3ad40">金黄虚线：当前固定扇形</span><span style="--c:#a0acb0">灰白细线：精细参考（可选）</span></div><div id="chart"></div><div id="metrics" class="metrics"></div></section>
<section class="panel"><h3>三种粗网格的实际差别</h3><div class="scroll"><table><thead><tr><th>网格</th><th>与精细区域重合率</th><th>漏掉的达标区</th><th>圈入的不达标区</th><th>计算耗时</th></tr></thead><tbody id="rows"></tbody></table></div><p class="note">重合率＝交集 / 并集。覆盖误差用独立 2 mm 网格对真实评分判断，属于离散抽检，不是连续域误差证明。耗时：本机 Python/NumPy，粗版 7 次中位数；不含瞄点求取、绘制和文件读写，不代表手机性能。</p></section>
<section class="panel"><h3>这次省掉了什么</h3><p>1 mm → 2 cm 网格；交点只做一次线性插值；不二分求根、不递归细化、不画 90 / 95 分内层。保留闭合轮廓，不用外接矩形或凸包扩大区域。</p><p class="note">精细参考按当前页面的有效进球点重新计算，避免与旧题库锚点混比。区域只表达第二球的击球舒适度；未加入第三球方向、其他球遮挡、首杆可达性及进球物理验证。当前扇形采用生产绘制路径的离库裁剪。</p><a href="overview.png">查看全部 8 个对比</a> · <a href="README.md">计算记录</a></section></main>
<script>const DATA=__DATA__;const L=__L__,W=__W__,R=__R__;let mode='both';const $=s=>document.querySelector(s);const select=$('#case');DATA.forEach((c,i)=>select.add(new Option(`${String(i+1).padStart(2,'0')} · 底图 ${c.sample} → ${c.pocketName}`,i)));
const xy=p=>[70+(p[0]/L+.5)*1000,60+(p[1]/W+.5)*500];
function path(loops){return loops.map(poly=>poly.map((p,i)=>`${i?'L':'M'}${xy(p).join(',')}`).join(' ')+'Z').join(' ')}
function render(){const c=DATA[+select.value],v=c.variants[+$('#step').value];let svg='<svg viewBox="0 0 1140 620" role="img" aria-label="目标球母球落区对比"><rect x="48" y="38" width="1044" height="544" rx="27" fill="#294b40"/><rect x="70" y="60" width="1000" height="500" fill="#225e4d"/>';
for(let i=1;i<8;i++)svg+=`<path d="M${70+125*i} 60V560" stroke="#2d6b58"/>`;for(let i=1;i<4;i++)svg+=`<path d="M70 ${60+125*i}H1070" stroke="#2d6b58"/>`;
if(mode!=='old')svg+=`<path d="${path(v.loops)}" fill="#67dfc6" fill-opacity=".27" fill-rule="evenodd" stroke="#67dfc6" stroke-width="2.5"/>`;
if($('#fine').checked)svg+=`<path d="${path(c.fine.loops)}" fill="none" stroke="#d5dddc" stroke-width="1.3"/>`;
if(mode!=='new')svg+=`<path d="${path(c.current.loops)}" fill="#ffce61" fill-opacity=".06" stroke="#ffce61" stroke-width="2.5" stroke-dasharray="9 6"/>`;
const pockets=[[-L/2,-W/2],[L/2,-W/2],[-L/2,W/2],[L/2,W/2],[0,-W/2],[0,W/2]];pockets.forEach((p,i)=>{const [x,y]=xy(p);svg+=`<circle cx="${x}" cy="${y}" r="16" fill="#102b26" ${i===c.pocket?'stroke="#ffd268" stroke-width="4"':''}/>`});
const b=xy(c.ball),a=xy(c.aim),r=R/L*1000;svg+=`<path d="M${b}L${a}" stroke="#d8dfd9" stroke-width="1.5" stroke-dasharray="6 6"/><circle cx="${b[0]}" cy="${b[1]}" r="${r+4}" fill="none" stroke="#ffd268" stroke-width="2"/><circle cx="${b[0]}" cy="${b[1]}" r="${r}" fill="#2c69a5" stroke="white"/><text x="${b[0]}" y="${b[1]+1}" text-anchor="middle" dominant-baseline="middle" font-size="15" fill="white">2</text></svg>`;$('#chart').innerHTML=svg;
$('#metrics').innerHTML=[['网格间距',`${v.step*100} cm`,'线性插值，单层轮廓'],['与精细区重合',`${v.overlapPct.toFixed(1)}%`,'相同评分、相同瞄点'],['粗网格计算',`${v.milliseconds.toFixed(2)} ms`,'本机研究原型实测'],['采样点数',v.evaluations.toLocaleString(),'精细版约 302 万点']].map(x=>`<div class="metric"><small>${x[0]}</small><strong>${x[1]}</strong><small>${x[2]}</small></div>`).join('');
$('#rows').innerHTML=c.variants.map(v=>`<tr><td>${v.step*100} cm</td><td>${v.overlapPct.toFixed(2)}%</td><td>${v.missedPct.toFixed(2)}%</td><td>${v.extraPct.toFixed(3)}%</td><td>${v.milliseconds.toFixed(2)} ms</td></tr>`).join('')+`<tr><td>1 mm 精细参考</td><td>—</td><td>—</td><td>—</td><td>${c.fine.milliseconds.toFixed(1)} ms（单次）</td></tr>`;
}
document.querySelectorAll('select,input').forEach(e=>e.addEventListener('change',render));document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;document.querySelectorAll('[data-mode]').forEach(x=>x.classList.toggle('active',x===b));render()});render();</script></html>'''
html=html.replace('__DATA__',json.dumps(payload,ensure_ascii=False,separators=(',',':'))).replace('__L__',str(L)).replace('__W__',str(W)).replace('__R__',str(R))
(OUT/'index.html').write_text(html)
summary={}
for i,cm in enumerate([2,4,6]):
    vs=[c['variants'][i] for c in cases]
    summary[str(cm)]=dict(overlapMin=min(v['overlapPct'] for v in vs),overlapMax=max(v['overlapPct'] for v in vs),timeMin=min(v['milliseconds'] for v in vs),timeMax=max(v['milliseconds'] for v in vs),maxExtra=max(v['extraPct'] for v in vs),maxMiss=max(v['missedPct'] for v in vs))
(OUT/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2));print('Rendered overview.png and index.html')
