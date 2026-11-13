"""Generate numerical diagnostic curves, not product screenshots."""
from pathlib import Path
import argparse, json
import numpy as np
from PIL import Image,ImageDraw
import study

ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
im=Image.new('RGB',(1280,820),'white');d=ImageDraw.Draw(im)
d.text((30,15),'NUMERICAL DIAGNOSTIC - direct GGX S only; not an App screenshot',(0,0,0))
colors=[(25,25,25),(195,65,35),(30,120,205)]
records=[]
for idx,rough in enumerate([.3,.5,.8,1.]):
 x=np.linspace(study.R,.18,320);p=np.column_stack((x,np.full(len(x),.8),np.zeros(len(x))))
 n=np.tile([0,1,0],(len(x),1));v=np.tile(study.unit(np.array([-1.,.25,0.])),(len(x),1))
 r=np.full(len(x),rough);balls=np.zeros((16,4));balls[0]=[0,0,study.R,.85]
 E0,E,S,data=study.reference(p,n,v,r,balls);ys=[S]
 for nx,nz in [(2,2),(4,2)]:
  num,den,cs,use,*_=study.candidate(p,n,v,r,data,nx,nz);ys.append(np.where(use,cs,S))
 left=40+(idx%2)*630;top=70+(idx//2)*370;w=570;h=275
 ymin=min(float(y.min()) for y in ys);ymax=max(float(y.max()) for y in ys);span=max(1e-9,ymax-ymin)
 d.text((left,top-28),f'roughness={rough}, N=(0,1,0), eye direction=normalize(-1,.25,0)',(0,0,0))
 d.line([(left,top),(left,top+h),(left+w,top+h)],fill=(100,100,100),width=1)
 for y,color,label in zip(ys,colors,['Reference 64/8','4 groups/light','8 groups/light']):
  points=[(left+i*w/(len(x)-1),top+h-(float(a)-ymin)/span*h) for i,a in enumerate(y)]
  d.line(points,fill=color,width=2)
  j=['Reference 64/8','4 groups/light','8 groups/light'].index(label)
  d.text((left+20+j*170,top+h+36),label,color)
 d.text((left,top+h+6),'x=ball radius (28.575mm)',(0,0,0));d.text((left+w-85,top+h+6),'x=180mm',(0,0,0))
 d.text((left+8,top+4),f'S range {ymin:.6f} .. {ymax:.6f}',(0,0,0))
 records.append({'roughness':rough,'x':x.tolist(),'reference':ys[0].tolist(),'K4':ys[1].tolist(),'K8':ys[2].tolist(),'near':data[3].tolist()})
im.save(args.out/'cross-section.png');(args.out/'cross-section.json').write_text(json.dumps(records)+'\n')
# Concrete unguarded-moment counterexample, no tunable threshold.
p=np.tile([.04,.8,0],(5,1));angles=np.deg2rad([0,20,40,60,80]);n=np.column_stack((np.sin(angles),np.cos(angles),np.zeros(5)))
v=np.tile([0,1,0],(5,1));rough=np.full(5,.8);balls=np.zeros((16,4));balls[0]=[0,0,study.R,.85]
E0,E,S,data=study.reference(p,n,v,rough,balls);num,den,_,use,guard,*_=study.candidate(p,n,v,rough,data,2,2)
rows=[{'normal_tilt_deg':a,'reference_ratio':float(x),'unguarded_ratio':float(y),'guard_allows':bool(g)} for a,x,y,g in zip([0,20,40,60,80],E/E0,num/den,guard)]
assert all(abs(row['reference_ratio']-row['unguarded_ratio'])<1e-12 for row in rows if row['guard_allows'])
assert any(abs(row['reference_ratio']-row['unguarded_ratio'])>.01 and not row['guard_allows'] for row in rows)
(args.out/'horizon-counterexample.json').write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(rows,indent=2))
