"""Native-valued partition charts; static proposals are labelled separately."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/plan-three-third-region-20261101'
D=json.loads((OUT/'data.json').read_text());cases=D['cases'];g=D['audit']['sourceGeometry'];L,W,R=[g[k] for k in ['length','width','radius']]
COLORS={'same':'#60ddc0','reverse':'#edb466','straight':'#b5c2ca','blocked':'#df7b83'}
NAMES={'same':'同侧且有角度','reverse':'反向衔接','straight':'近直球 <5°','blocked':'遮挡 / 占位'}
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(FONT,n)
def xy(p,box):x,y,w,h=box;return(x+(p[0]/L+.5)*w,y+(p[1]/W+.5)*h)
def dash(d,pts,color,width=2):
 for a,b in zip(pts,pts[1:]):
  n=max(1,math.ceil(math.dist(a,b)/7))
  for i in range(0,n,2):
   d.line([(a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n),(a[0]+(b[0]-a[0])*min(i+1,n)/n,a[1]+(b[1]-a[1])*min(i+1,n)/n)],fill=color,width=width)
def draw(im,c,rect):
 d=ImageDraw.Draw(im);x,y,w,h=rect;d.rounded_rectangle((x,y,x+w,y+h),18,fill='white',outline='#d9e2d9',width=2)
 d.text((x+24,y+18),c['title'],font=font(24),fill='#244a3f')
 d.text((x+24,y+51),c['pocketName']+' · '+('现有中袋方向系数参与' if c['pocket']>=4 else '角袋几何扩展 · 待确认'),font=font(18),fill='#607669')
 box=(x+30,y+96,w-60,(w-60)/2);bx,by,bw,bh=box
 d.rounded_rectangle((bx-9,by-9,bx+bw+9,by+bh+9),14,fill='#294c43');d.rectangle((bx,by,bx+bw,by+bh),fill='#245d4e')
 for i in range(1,8):d.line((bx+bw*i/8,by,bx+bw*i/8,by+bh),fill='#2b6957')
 for i in range(1,4):d.line((bx,by+bh*i/4,bx+bw,by+bh*i/4),fill='#2b6957')
 overlay=Image.new('RGBA',im.size,(0,0,0,0));od=ImageDraw.Draw(overlay)
 for t in c['tiles']:
  color=COLORS[t['kind']];rgb=tuple(int(color[i:i+2],16) for i in [1,3,5]);od.polygon([xy(p,box) for p in t['poly']],fill=(*rgb,155 if t['kind']=='same' else 110))
 im.alpha_composite(overlay);d=ImageDraw.Draw(im)
 for poly in c['base']['loops']:d.line([xy(p,box) for p in poly],fill='#d0ded4',width=2)
 for poly in c['legacySectors']:dash(d,[xy(p,box) for p in poly],'#ffdd65',3)
 pockets=[[-L/2,-W/2],[L/2,-W/2],[-L/2,W/2],[L/2,W/2],[0,-W/2],[0,W/2]]
 for i,p in enumerate(pockets):
  px,py=xy(p,box);d.ellipse((px-10,py-10,px+10,py+10),fill='#102e27')
  if i==c['pocket']:d.ellipse((px-13,py-13,px+13,py+13),outline='#ffcf63',width=3)
 dash(d,[xy(c['ball'],box),xy(c['aim'],box)],'#d9e3da',2)
 for p,number,color in [(c['ball'],'2','#e7b84e'),(c['third'],'3','#bd9ee8')]:
  px,py=xy(p,box);r=R/L*bw+2;d.ellipse((px-r,py-r,px+r,py+r),fill=color,outline='white',width=1);d.text((px,py+1),number,anchor='mm',font=font(14),fill='#203b32')
 a=c['areas'];d.text((x+24,y+h-70),f"同侧 {a['same']:.0f}% · 反向 {a['reverse']:.0f}% · 近直 {a['straight']:.0f}% · 遮挡 {a['blocked']:.0f}%",font=font(20),fill='#23493c')
 warning='第三球挡住进球线；当前直接进球条件全部不通过' if a['blocked']>99.9 else ('没有同侧且≥5°的区域；不能据此断言无解' if a['same']<.1 else c['note'])
 d.text((x+24,y+h-37),warning,font=font(18),fill='#6d776d')

def poster(indices,name):
 rows=math.ceil(len(indices)/2);height=230+rows*580+75
 im=Image.new('RGBA',(1680,height),'#f1f4ee');d=ImageDraw.Draw(im)
 d.text((44,30),'加入第三球：按衔接方向划分 2 cm 舒适区',font=font(36),fill='#1c4436')
 d.text((44,85),'基础区域仍为≥85分；5°是本轮近直球候选分界，尚未定为正式规则。球位为控制变量对照摆位。',font=font(22),fill='#607466')
 x=46
 for kind in ['same','reverse','straight','blocked']:
  d.rounded_rectangle((x,137,x+24,154),3,fill=COLORS[kind]);d.text((x+35,130),NAMES[kind],font=font(21),fill='#315143');x+=305
 d.text((44,181),'金黄虚线：目前加入第三球后保留的固定扇形；浅色外框：上一轮完整舒适区。',font=font(21),fill='#607466')
 for i,j in enumerate(indices):draw(im,cases[j],(40+(i%2)*820,232+(i//2)*580,780,556))
 d=ImageDraw.Draw(im);d.text((44,height-46),'研究分区，不是物理可达范围。角袋目前无方向扣分；反向仍可能用高低杆或吃库衔接，不能直接判无解。',font=font(20),fill='#607466')
 im.convert('RGB').save(OUT/name)
poster(list(range(8)),'overview.png');poster([0,1,4,5,6,3],'comparison-six.png')

payload=[]
for c in cases:
 item={k:c[k] for k in ['number','title','note','ball','third','pocket','pocketName','aim','areas','actual85Pct','legacySectors','representatives']}
 item['base']=c['base']['loops'];item['tiles']=[]
 for t in c['tiles']:
  item['tiles'].append(dict(poly=[[round(v,6) for v in p] for p in t['poly']],point=[round(v,7) for v in t['point']],kind=t['kind'],angle=t['angle'],base=t['base'],final=t['final'],coefficient=t.get('coefficient'),ghost=t['ghost'],t=t['t']))
 payload.append(item)
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>第三球与母球落区分区</title><style>
*{box-sizing:border-box}body{margin:0;background:#eff4ed;color:#1d4335;font:16px -apple-system,BlinkMacSystemFont,sans-serif}main{max-width:1440px;padding:30px 28px;margin:auto}h1{font-size:32px;margin:10px 0}p{line-height:1.7;color:#627466}.caption{font-size:13px;letter-spacing:2px}.bar,.legend{display:flex;flex-wrap:wrap;gap:15px;align-items:center;margin:18px 0}select,button{font:inherit;background:#fff;color:#214b39;padding:10px 13px;border:1px solid #c5d3c5;border-radius:9px;cursor:pointer}button.active{background:#27533e;color:white}.legend span:before{content:'';width:17px;height:12px;display:inline-block;border-radius:2px;margin-right:6px;background:var(--c)}.legend{font-size:14px}.boards{display:grid;grid-template-columns:1fr 1fr;gap:16px}.panel{border:1px solid #d8e2d6;border-radius:16px;padding:20px;background:white;margin:16px 0}h3{margin:0 0 10px}svg{width:100%;display:block}.metrics{display:flex;flex-wrap:wrap;gap:12px}.metric{background:#f0f5ed;padding:14px;border-radius:10px;min-width:140px}.metric strong{display:block;font-size:24px;margin:5px 0}.metric small{color:#6d7e70}.note{font-size:14px}.pill{padding:6px 10px;border-radius:7px;background:#f6eed7;color:#856325;font-size:14px}label{display:flex;align-items:center;gap:6px}input{accent-color:#2c684d}.sample{display:flex;flex-wrap:wrap;gap:10px}a{color:#216849}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:12px 6px;border-bottom:1px solid #e2e8de}summary{cursor:pointer;font-weight:600}@media(max-width:800px){main{padding:18px 12px}.boards{grid-template-columns:1fr}h1{font-size:26px}.panel{padding:13px}}
</style><main><div class="caption">球迹 · 第三球衔接研究 · 2026.11.01</div><h1>同一个舒适区，第三球改变该留哪一边</h1><p>保持已选定的 2 cm 精度。先保证第二球好打，再区分分离方向、预留角度和第三球遮挡。<br>中袋沿用现有三球评分的方向判断；角袋的着色是候选几何扩展，尚未接入 App。</p>
<div class="bar"><label>对照球形 <select id="case"></select></label><span id="scope" class="pill"></span></div>
<div class="bar"><button data-mode="partition" class="active">四类分区</button><button data-mode="keep">只看建议优先区</button><button data-mode="score">按现有三球实评分 ≥85</button><button data-mode="base">完整基础区</button></div>
<div class="legend"><span style="--c:#60ddc0">同侧且有角度</span><span style="--c:#edb466">反向衔接</span><span style="--c:#b5c2ca">近直球 &lt;5°</span><span style="--c:#df7b83">遮挡 / 占位</span></div>
<div class="boards"><section class="panel"><h3>目前：第三球决定固定扇形的一侧</h3><div id="old"></div><p class="note">金黄虚线为当前生产扇形。浅色外框为上一轮完整舒适区。</p></section><section class="panel"><h3 id="newtitle">候选：在完整区域内区分衔接条件</h3><div id="new"></div><p id="description" class="note"></p></section></div>
<section class="panel"><div id="metrics" class="metrics"></div><p id="warning"></p><h3>看一个具体母球位置</h3><div id="sample" class="sample"></div><p class="note">也可以直接点右侧区域。白色虚线是该位置到假想球的瞄准线，短箭头仅表示分离方向，不是走位轨迹。</p><div id="point" class="metrics"></div></section>
<section class="panel"><h3>现有三球第一杆到底怎么算</h3><p>先用首杆真实停点检查第二球能否直打、是否被第三球遮挡；再合成球距、出杆空间和切角的基础分。仅在第二球打中袋且仍有第三球时，最终分 = 基础分 × 分离方向系数 K。角袋与最后两球不乘这项系数。</p><p>同侧、在线上和恰好直球的 K=1；反向才折减，最低为0.6。反向离线距离、球距、分侧面积和切角共同影响折减。它没有求出通向第三球的最佳预留角度，也不搜索高低杆、吃库或第三球目标袋。</p><details><summary>本轮候选分区与现有评分的区别</summary><p>近直球的5°界线借自当前扇形下限，只用于本次看图。它是候选过渡区，不是现有K的扣分门槛。同侧区只是优先候选，反向和近直区不等于无解；被遮挡的点则不能按当前直接击球判断通过。</p><p>上一轮区域按有效进球点算舒适度；现有三球基础分用冻结题库锚点，方向系数用中袋孔心。本图保留这些实际口径。“实评分≥85”只在上一轮基础区内部展示当前评分达标部分，没有偷偷更换已选基准区域。</p><p>着色按2cm网格中裁剪三角形的中心点分类，分界可有细小台阶，不是毫米精确边界。研究摆位第一球视为已进袋。尚未模拟第二杆和第三杆，不能把颜色作为路线可达证明。</p></details></section>
<p><a href="overview.png">全部8组大图</a> · <a href="README.md">研究记录</a> · <a href="http://127.0.0.1:54211/">上一轮2cm完整区域对比</a></p></main>
<script>const DATA=__DATA__,L=__L__,W=__W__,R=__R__;const colors={same:'#60ddc0',reverse:'#edb466',straight:'#b5c2ca',blocked:'#df7b83'},names={same:'同侧且有角度',reverse:'反向衔接',straight:'近直球',blocked:'遮挡 / 占位'};const $=s=>document.querySelector(s);let mode='partition',selected=null;const sel=$('#case');DATA.forEach((c,i)=>sel.add(new Option(c.title,i)));const xy=p=>[55+(p[0]/L+.5)*1000,55+(p[1]/W+.5)*500];const path=loops=>loops.map(poly=>poly.map((p,i)=>`${i?'L':'M'}${xy(p)}`).join(' ')+'Z').join(' ');
function chart(c,isOld){let s='<svg viewBox="0 0 1110 610" role="img" aria-label="'+(isOld?'当前单侧扇形':'第三球分区')+'"><defs><marker id="arrow'+isOld+'" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0L8 4L0 8Z" fill="#edf5ef"/></marker></defs><rect x="34" y="34" width="1042" height="542" rx="25" fill="#294d40"/><rect x="55" y="55" width="1000" height="500" fill="#245d4e"/>';
for(let i=1;i<8;i++)s+=`<path d="M${55+125*i} 55V555" stroke="#2d6b58"/>`;for(let i=1;i<4;i++)s+=`<path d="M55 ${55+125*i}H1055" stroke="#2d6b58"/>`;
if(!isOld){c.tiles.forEach((t,i)=>{const show=mode==='partition'||mode==='base'||mode==='keep'&&t.kind==='same'||mode==='score'&&t.final>=85;if(show){const color=mode==='base'||mode==='score'?colors.same:colors[t.kind];s+=`<path d="${path([t.poly])}" fill="${color}" fill-opacity=".65" stroke="${color}" stroke-width=".4" stroke-opacity=".65" data-tile="${i}" style="cursor:crosshair"/>`}})}
s+=`<path d="${path(c.base)}" fill="none" stroke="#ceddd4" stroke-width="1.5" pointer-events="none"/>`;
if(isOld)s+=`<path d="${path(c.legacySectors)}" fill="#ffdc67" fill-opacity=".1" stroke="#ffdc67" stroke-width="3" stroke-dasharray="9 6"/>`;
const pockets=[[-L/2,-W/2],[L/2,-W/2],[-L/2,W/2],[L/2,W/2],[0,-W/2],[0,W/2]];pockets.forEach((p,i)=>{const [x,y]=xy(p);s+=`<circle cx="${x}" cy="${y}" r="16" fill="#102d26" ${i===c.pocket?'stroke="#ffd268" stroke-width="4"':''}/>`});const b=xy(c.ball),a=xy(c.aim);s+=`<path d="M${b}L${a}" fill="none" stroke="#dae5dc" stroke-width="1.5" stroke-dasharray="6 6" pointer-events="none"/>`;
for(const [p,n,color] of [[c.ball,2,'#e7b84e'],[c.third,3,'#bd9ee8']]){const [x,y]=xy(p);s+=`<circle cx="${x}" cy="${y}" r="${R/L*1000+3}" fill="${color}" stroke="white"/><text x="${x}" y="${y+1}" fill="#203b32" font-size="19" text-anchor="middle" dominant-baseline="middle">${n}</text>`}
if(!isOld&&selected){const v=selected,C=xy(v.point),G=xy(v.ghost);s+=`<path d="M${C}L${G}" stroke="white" stroke-dasharray="5 5" stroke-width="2" pointer-events="none"/><circle cx="${C[0]}" cy="${C[1]}" r="11" fill="white" stroke="#4f695d" stroke-width="2" pointer-events="none"/>`;let len=Math.hypot(...v.t);if(v.angle>=5&&v.kind!=='blocked'&&len>1e-8){const end=xy([v.ghost[0]+v.t[0]/len*.17,v.ghost[1]+v.t[1]/len*.17]);s+=`<path d="M${G}L${end}" stroke="#edf5ef" stroke-width="3" marker-end="url(#arrowfalse)" pointer-events="none"/>`}}
return s+'</svg>'}
function render(){const c=DATA[+sel.value];$('#scope').textContent=c.pocket>=4?'中袋：现有K已参与':'角袋：候选几何扩展，现有K不适用';$('#old').innerHTML=chart(c,true);$('#new').innerHTML=chart(c,false);$('#newtitle').textContent={partition:'候选：按衔接条件分区',keep:'只看同侧且有角度的优先区',score:'基础区内，现有三球实评分 ≥85',base:'不考虑第三球的完整基础区'}[mode];$('#description').textContent={partition:'四种颜色表示不同条件，不能把反向区直接当成无解。',keep:'这只是一种优先选择候选；若为空，不自动降低门槛或声称无解。',score:'调用现有基础分、遮挡判断及中袋K。角袋没有方向折减，因此可能保留反向区域。',base:'与上一轮保持相同的2cm网格、85分门槛和有效进球点。'}[mode];$('#metrics').innerHTML=Object.entries(c.areas).map(([k,v])=>`<div class="metric"><small>${names[k]}</small><strong>${v.toFixed(1)}%</strong><small>占完整基础区面积</small></div>`).join('');$('#warning').textContent=c.areas.blocked>99.9?'第三球挡住进球线，当前直接进球条件全部不通过；方向选侧不能解决这项遮挡。':c.areas.same<.1?'此例没有同侧且≥5°的优先区。仅凭这个几何条件，不能判定下一杆无解。':c.note;
$('#sample').innerHTML=c.representatives.map((r,i)=>`<button data-probe="${i}">${names[r.kind]}示例</button>`).join('');document.querySelectorAll('[data-probe]').forEach(b=>b.onclick=()=>{selected=c.representatives[+b.dataset.probe];render()});document.querySelectorAll('[data-tile]').forEach(p=>p.onclick=()=>{selected=c.tiles[+p.dataset.tile];render()});
if(selected){let v=selected;$('#point').innerHTML=[['分区',names[v.kind]],['第二球切角',v.angle.toFixed(1)+'°'],['三球现有基础分',v.base.toFixed(1)],['现有方向系数K',v.coefficient==null?'不适用':v.coefficient.toFixed(3)],['三球现有最终分',v.final.toFixed(1)]].map(x=>`<div class="metric"><small>${x[0]}</small><strong>${x[1]}</strong></div>`).join('')}else $('#point').innerHTML='<p class="note">选择一个示例或点击右侧区域，查看该位置的角度、系数与现有得分。</p>';
}sel.onchange=()=>{selected=null;render()};document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;selected=null;document.querySelectorAll('[data-mode]').forEach(x=>x.classList.toggle('active',x===b));render()});render();</script></html>'''
html=html.replace('__DATA__',json.dumps(payload,ensure_ascii=False,separators=(',',':'))).replace('__L__',str(L)).replace('__W__',str(W)).replace('__R__',str(R))
(OUT/'index.html').write_text(html)
print('Rendered',len(cases),'cases; 2cm cells;',len(html),'HTML chars')
