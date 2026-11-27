"""Render native final states and scores; never invent simulation trajectories."""
from pathlib import Path
import base64, html, json, math
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-score-gallery-20261105'
display=OUT/'display-cases.json'
rows=json.loads((display if display.exists() else OUT/'cases.json').read_text())
assert json.loads((OUT/'results.json').read_text())['passed']
font_path='/System/Library/Fonts/STHeiti Medium.ttc'
def font(size): return ImageFont.truetype(font_path,size)
POCKETS=[(-1.312,-.677),(1.312,-.677),(-1.312,.677),(1.312,.677),(0,-.675964713),(0,.675964713)]
NAMES=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
W,H=900,700
def dashed(d,a,b,fill,width=2,dash=9):
 dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy)
 if not length:return
 for offset in range(0,math.ceil(length),dash*2):
  lo,hi=offset/length,min(length,offset+dash)/length
  d.line((a[0]+dx*lo,a[1]+dy*lo,a[0]+dx*hi,a[1]+dy*hi),fill=fill,width=width)
def arrow(d,a,b,fill):
 dashed(d,a,b,fill,3)
 theta=math.atan2(b[1]-a[1],b[0]-a[0]);n=10
 d.polygon([b,(b[0]-n*math.cos(theta-.45),b[1]-n*math.sin(theta-.45)),
  (b[0]-n*math.cos(theta+.45),b[1]-n*math.sin(theta+.45))],fill=fill)
def category(e):
 if e.get('fullDirectBlock'):return '完整遮挡'
 if e.get('potContactsBlocked'):return '下球点受阻'
 if e.get('score') is None:return '未评分'
 if e.get('pipeRoute',{}).get('zeroWidthEstimate'):return '零角度计分'
 return '有进攻路线'
def card(row):
 e=row['effect'];score=e.get('score');kind=category(e);target=row['target']
 im=Image.new('RGB',(W,H),'#ffffff');d=ImageDraw.Draw(im)
 d.rounded_rectangle((1,1,W-2,H-2),radius=22,outline='#d9dfda',width=2)
 tag={'S03-01-46':'A','S04-01-60':'B','S01-01-30':'C'}.get(row['id'],'')
 title=(tag+' · ' if tag else '')+kind
 d.text((30,26),title,font=font(30),fill='#203e37')
 d.text((30,67),row['id']+'  ·  对手目标 '+target[1:]+'号',font=font(19),fill='#64766f')
 text='未评分' if score is None else f'{score:.1f} 分'
 d.text((W-34,22),text,font=font(42),fill='#167b64' if score is not None and score>=90 else '#344b46',anchor='ra')
 x0,y0=43,139;scale=814/2.54;tw,th=814,814/2
 def point(p):return(x0+(p[0]+1.27)*scale,y0+(p[1]+.635)*scale)
 d.rounded_rectangle((x0-24,y0-24,x0+tw+24,y0+th+24),radius=23,fill='#5d5449')
 d.rectangle((x0,y0,x0+tw,y0+th),fill='#245e53')
 # Pocket mouths are schematic; ball coordinates and radius remain metric.
 for i,p in enumerate(POCKETS):
  x,y=point(p)
  if i<4:
   corner=point((math.copysign(1.27,p[0]),math.copysign(.635,p[1])))
   d.line((x,y,*corner),fill='#17231f',width=29)
  else:
   mouth=point((0,math.copysign(.635,p[1])))
   d.line((x,y,*mouth),fill='#17231f',width=31)
  d.ellipse((x-14,y-14,x+14,y+14),fill='#111c18')
 cue=row['positions']['cueBall'];ball=row['positions'][target];route=e.get('pipeRoute')
 if route:
  aim=route['aim'];dx,dz=aim[0]-ball[0],aim[1]-ball[1];length=math.hypot(dx,dz)
  ghost=[ball[0]-.05715*dx/length,ball[1]-.05715*dz/length]
  arrow(d,point(cue),point(ghost),'#dce6e1')
  arrow(d,point(ball),point(aim),'#f4b95e')
  x,y=point(ghost);rr=.028575*scale
  d.ellipse((x-rr,y-rr,x+rr,y+rr),outline='#cfdbd4',width=2)
  px,py=point(POCKETS[route['pocket']]);d.ellipse((px-19,py-19,px+19,py+19),outline='#f4b95e',width=3)
 elif e.get('fullDirectBlock'):
  dashed(d,point(cue),point(ball),'#e6a19a',2)
 radius=.028575*scale
 for key,p in row['positions'].items():
  if key in row['pocketed']:continue
  x,y=point(p)
  if key==target:
   d.ellipse((x-radius-5,y-radius-5,x+radius+5,y+radius+5),outline='#f4b95e',width=3)
  color='#f7f7ef' if key=='cueBall' else '#191d1a' if key=='_8' else '#edc64f'
  d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=color,outline='#0e2820',width=1)
  if key=='_9':
   d.rectangle((x-radius+1,y-3,x+radius-1,y+3),fill='#faf7e9')
  if key!='cueBall':d.text((x,y+1),key[1:],font=font(13),fill='#ffffff' if key=='_8' else '#222b26',anchor='mm')
 if route:
  theta=e['targetPipeToleranceDegrees'];comfort=e['comfort']
  d.text((30,588),f'管道角 {theta:.4f}°     舒适分 {comfort:.2f}     {NAMES[route["pocket"]]}',font=font(23),fill='#263f37')
  if route.get('zeroWidthEstimate'):caption='C 按 0°参与公式；下球点与球路仍检查遮挡。' if tag=='C' else '无正宽管道，按 0°结合可达路线的舒适分计分。'
  elif comfort>80:caption='对手进攻很舒服，因此防守分较低。'
  elif comfort>40:caption='对手仍有较舒服的进攻机会，防守效果有限。'
  else:caption='对手有进攻方向，但舒适分很低。'
 elif e.get('fullDirectBlock'):
  d.text((30,588),'完整遮挡规则档：100 分',font=font(23),fill='#263f37')
  caption='母球的直接击球范围被挡住，区别于仅封下球点。'
 elif e.get('potContactsBlocked'):
  d.text((30,588),'下球点受阻规则档：100 分',font=font(23),fill='#263f37')
  caption='仍能碰到目标球，但当前模型的进袋下球点受阻。'
 else:
  d.text((30,588),'未确认可评分路线',font=font(23),fill='#263f37');caption='不硬给 0 或 100 分，不计入均分。'
 d.text((30,632),caption,font=font(22),fill='#63736c')
 return im
cards={}
for row in rows:
 image=card(row);path=OUT/(row['id']+'.png');image.save(path);cards[row['id']]=image
groups=[('strong-defense.png','高防守分的几种情况',['S02-01-60','S01-01-30','S03-01-46','S04-01-60']),
 ('open-opportunities.png','对手仍有进攻机会时',['S01-01-2','S02-01-2','S02-01-4','S03-01-2'])]
for filename,title,ids in groups:
 sheet=Image.new('RGB',(W*2+60,H*2+230),'#f0f3ef');d=ImageDraw.Draw(sheet)
 d.text((30,25),title,font=font(38),fill='#203e37')
 d.text((30,83),'防守分 = 100 × √[(1−舒适分/100) ÷ (1+管道角/1°)]',font=font(27),fill='#53685d')
 for i,key in enumerate(ids):sheet.paste(cards[key],(20+(W+20)*(i%2),140+(H+20)*(i//2)))
 d.text((30,H*2+180),'实测终态示意 · 白球为母球，橙环为对手目标球；虚线为几何方向，非实测轨迹。',font=font(23),fill='#53685d')
 sheet.save(OUT/filename)
ordered=sorted(rows,key=lambda r:-(r['effect'].get('score',-1)))
tiles=[]
for row in ordered:
 src=base64.b64encode((OUT/(row['id']+'.png')).read_bytes()).decode()
 tiles.append(f'<article data-kind="{html.escape(category(row["effect"]))}"><img src="data:image/png;base64,{src}" alt="{html.escape(row["id"])}"></article>')
document='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>防守评分球形对照</title><style>body{margin:24px;background:#f0f3ef;color:#203e37;font-family:system-ui}h1{font-size:28px}p{line-height:1.6}button{padding:10px 18px;margin:0 8px 10px 0;border:1px solid #aebfb3;border-radius:8px;background:white;color:#203e37;cursor:pointer}button[aria-pressed=true]{background:#203e37;color:white}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,500px),1fr));gap:16px}img{width:100%;display:block}article[hidden]{display:none}</style><h1>不同防守后球形 · 15个实测终态</h1><p>已确认公式：100 × √[(1−舒适分/100) ÷ (1+管道角/1°)]。分数越高，表示防守效果越好。完整遮挡100分、下球点受阻100分单列规则档。</p><p>白球为母球；橙环标对手目标；空心圆为所需母球接触位置。虚线是评分选取的几何方向，不是实际击球轨迹。袋口外形为示意，球位与球半径按实测坐标绘制。</p><nav>'''
for label in ['全部','完整遮挡','下球点受阻','零角度计分','有进攻路线','未评分']:
 document+=f'<button aria-pressed="{str(label=="全部").lower()}">{label}</button>'
document+='</nav><main class="grid">'+''.join(tiles)+'''</main><script>document.querySelectorAll('button').forEach(b=>b.onclick=()=>{document.querySelectorAll('button').forEach(x=>x.setAttribute('aria-pressed',x===b));document.querySelectorAll('article').forEach(a=>a.hidden=b.textContent!=='全部'&&a.dataset.kind!==b.textContent)})</script></html>'''
(OUT/'index.html').write_text(document)
print('Rendered 15 cards, 2 comparison sheets, self-contained filtered gallery')
