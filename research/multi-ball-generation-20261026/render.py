"""Self-contained interactive atlas and a native-coordinate PNG contact sheet."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont
from analyze import OUT,HERE

data=json.loads((OUT/'atlas-data.json').read_text())
template=(HERE/'atlas.html').read_text()
(OUT/'index.html').write_text(template.replace('__DATA__',json.dumps(data,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')))
font='/System/Library/Fonts/STHeiti Medium.ttc'
def f(n):return ImageFont.truetype(font,n)
colors={1:'#efc22f',2:'#3275ce',3:'#d94d43',4:'#8b5aaa',5:'#ed8e3b',6:'#32885b',7:'#9c463d',8:'#202522'}
L,W,R=[data['meta'][k] for k in ['length','width','radius']]
img=Image.new('RGB',(1680,7*360+155),'#111718');d=ImageDraw.Draw(img)
d.text((30,22),'真实开球球形 · 校准后单一分散指数',font=f(32),fill='#edf3ee')
d.text((30,72),'每行同球数，依次为最低分／中位数／最高分；保留真实球位，不显示自由球母球。7／8球为现有兜底摆架。',font=f(19),fill='#becfc5')
ids=[]
for row,n in enumerate([4,5,6,7,8,9,15]):
 boards=sorted([b for b in data['boards'] if b['kind']=='base' and b['n']==n],key=lambda b:b['index'])
 for col,(label,b) in enumerate(zip(['最低','中位','最高'],[boards[0],boards[len(boards)//2],boards[-1]])):
  ids.append(b['id']);x0=20+col*555;y0=130+row*360;scale=190;ox=x0+25;oy=y0+67
  d.rounded_rectangle((x0,y0,x0+540,y0+345),radius=12,fill='#1b2823',outline='#3f5147')
  d.text((x0+16,y0+10),f'{n}球 · {label}  {b["index"]:.3f}',font=f(23),fill='#e7efd9')
  d.rectangle((ox-12,oy-12,ox+L*scale+12,oy+W*scale+12),fill='#574732')
  d.rectangle((ox,oy,ox+L*scale,oy+W*scale),fill='#1e745e')
  for px,pz in [(0,0),(L/2,0),(L,0),(0,W),(L/2,W),(L,W)]:
   x,z=ox+px*scale,oy+pz*scale;d.ellipse((x-10,z-10,x+10,z+10),fill='#101915')
  for ball in b['balls']:
   x=ox+(ball['x']+L/2)*scale;y=oy+(ball['z']+W/2)*scale;r=R*scale;k=ball['number'];c=colors[k if k<=8 else k-8]
   d.ellipse((x-r,y-r,x+r,y+r),fill=c if k<=8 else '#eeeeda',outline='#ddddc5',width=1)
   if k>8:d.rectangle((x-r*.8,y-r*.4,x+r*.8,y+r*.4),fill=c)
   d.ellipse((x-r*.53,y-r*.53,x+r*.53,y+r*.53),fill='#f4f2e7')
   d.text((x,y),str(k),font=f(7),fill='#151d17',anchor='mm')
  d.text((x0+16,y0+318),b['id'],font=f(14),fill='#a6bcb0')
img.save(OUT/'overview.png')
(OUT/'overview-manifest.json').write_text(json.dumps(dict(ids=ids,coordinateContract='world X right; world Z down; equal metres per pixel; physical diameter'),indent=2))
print('atlas and 21-board overview written')
