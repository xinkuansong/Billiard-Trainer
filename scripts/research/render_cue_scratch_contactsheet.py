#!/usr/bin/env python3
"""Render measured paths only, using the exported production table geometry."""
import json,sys,math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/cue-scratch-research-20261004';RAW=ROOT/'build/cue-scratch-research-20261004'
rows=json.loads(Path(sys.argv[1]).read_text()) if len(sys.argv)>1 else json.loads((OUT/'verified-cases.json').read_text())
geo=json.loads((RAW/'geometry.json').read_text())
fontpath='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(fontpath,n)
selected=[]
for n in range(4):
 candidates=[x for x in rows if len(x['rails'])==n]
 if candidates:
  candidates.sort(key=lambda x:(-x.get('fixedAimSpeedChecks',{}).get('sameRoute',0),x.get('cueClearance',0)<.05,abs(x['speed']-3.3)))
  selected.append(candidates[0])
image=Image.new('RGB',(1760,1160),'#edf2ed');d=ImageDraw.Draw(image)
d.rounded_rectangle((32,24,1728,135),20,fill='#f9d747');d.text((60,41),'母球掉袋 · 真实引擎轨迹',font=font(38),fill='#18382c')
d.text((60,93),'中杆无塞 ｜ 推荐目标袋 ｜ 白线为母球，黄线为目标球',font=font(22),fill='#284438')
for k,row in enumerate(selected):
 ox=32+(k%2)*864;oy=158+(k//2)*488
 d.rounded_rectangle((ox,oy,ox+832,oy+466),18,fill='white')
 d.text((ox+20,oy+15),f'{len(row["rails"])} 库掉袋   杆速 {row["speed"]:.3f} m/s',font=font(28),fill='#193b2c')
 tx=ox+416;ty=oy+245;scale=240
 def p(q):return (tx+q[0]*scale,ty+q[1]*scale)
 d.rectangle((tx-1.40*scale,ty-.75*scale,tx+1.40*scale,ty+.75*scale),fill='#123b2c')
 d.rectangle((tx-geo['length']/2*scale,ty-geo['width']/2*scale,tx+geo['length']/2*scale,ty+geo['width']/2*scale),fill='#28785b')
 for pocket in geo['pockets']:
  if pocket['lip']:d.polygon([p(q) for q in pocket['lip']],fill='#091c17')
  x,y=p(pocket['center']);r=pocket['radius']*scale;d.ellipse((x-r,y-r,x+r,y+r),fill='#091c17')
 for rail in geo['rails']:d.line([p(rail['a']),p(rail['b'])],fill='#729c80',width=2)
 for name,color in [('object','#ffce64'),('cueBall','#ffffff')]:
  path=[p([f[1],f[2]]) for f in row.get('paths',{}).get(name,[])]
  if len(path)>1:d.line(path,fill=color,width=3)
 for key,color in [('cue','white'),('object','#ffce64')]:
  x,y=p(row[key]);r=geo['radius']*scale;d.ellipse((x-r,y-r,x+r,y+r),fill=color,outline='#122d23',width=1)
 target=next((x for x in geo['pockets'] if x['id']==row['cuePocket']),None)
 if target:
  x,y=p(target['center']);d.ellipse((x-17,y-17,x+17,y+17),outline='#ff8374',width=3)
 count=0
 for e in row.get('events',[]):
  if e.get('kind')=='rail' and e.get('ball')=='cueBall' and 0<=e.get('segment',99)<6 and 'p' in e:
   count+=1;x,y=p(e['p']);d.ellipse((x-10,y-10,x+10,y+10),fill='#f5a554');d.text((x-4,y-9),str(count),font=font(14),fill='#123b2c')
 label=f'球心距 {math.dist(row["cue"],row["object"])*100:.1f} cm ｜ 目标袋 {row["pocket"]} → 母球袋 {row["cuePocket"].replace("pocket_","")} ｜ 切角 {row["cut"]:.1f}°'
 d.text((ox+20,oy+430),label,font=font(20),fill='#3b5647')
d.text((40,1140),'实测采样轨迹；图册候选尚待原生画面与出杆空间核验。',font=font(17),fill='#486356')
OUT.mkdir(parents=True,exist_ok=True);dest=Path(sys.argv[2]) if len(sys.argv)>2 else OUT/('early-contactsheet.png' if len(sys.argv)>1 else 'contactsheet.png');image.save(dest);print(dest)
