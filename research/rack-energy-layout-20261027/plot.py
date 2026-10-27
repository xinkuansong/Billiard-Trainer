"""Geometric diagnostic using actual native outputs; PIL makes a standalone PNG."""
from study import *
from PIL import Image,ImageDraw,ImageFont
data=json.load(open(OUT/'examples.json'));candidate=next(p for p in data if p!='baseline')
im=Image.new('RGB',(1740,1140),'#f4f6f9');d=ImageDraw.Draw(im)
fontpath='/System/Library/Fonts/Supplemental/Arial.ttf'
font=lambda n:ImageFont.truetype(fontpath,n)
def txt(x,y,s,size=19,fill='#182634'):d.text((x,y),s,font=font(size),fill=fill)
def arrow(a,b,color,width=3):
    d.line([a,b],fill=color,width=width);dx,dy=b[0]-a[0],b[1]-a[1];l=math.hypot(dx,dy)
    if l<3:return
    ux,uy=dx/l,dy/l
    d.polygon([b,(b[0]-9*ux+4*uy,b[1]-9*uy-4*ux),(b[0]-9*ux-4*uy,b[1]-9*uy+4*ux)],fill=color)
txt(30,20,'Frozen repaired engine | same rack seed 40000 | tip speed 10 m/s',29)
txt(30,60,'Actual first holdout, not a selected best case. X right, Z down. Physical constants unchanged.',20)
for rowidx,p in enumerate(['baseline',candidate]):
    row=data[p];top=110+rowidx*500;txt(30,top,p,25)
    slots=row['slots'];names=row['canonicalNames'];s=dict(zip(row['names'],row['samples'][1]['states']))
    for col,label in enumerate(['Initial offsets (arrows x500)','5 ms after first ball contact','Final positions (full table)']):
        left=25+col*575;y=top+45
        d.rounded_rectangle((left,y,left+555,y+425),radius=14,fill='white',outline='#d4dce6',width=2)
        txt(left+16,y+13,label,21)
        if col<2:
            xmin=-.93;xmax=-.53;zmin=-.17;zmax=.17
            scale=min(490/(xmax-xmin),300/(zmax-zmin))
            # Equal X/Z scales, preserving actual geometry.
            def xy(x,z):return (left+80+(x-xmin)*scale,y+65+(z-zmin)*scale)
            for i,(sx,sz) in enumerate(slots):
                if col==0:
                    pt=xy(sx,sz);r=R*scale
                    d.ellipse((pt[0]-r,pt[1]-r,pt[0]+r,pt[1]+r),outline='#a9b7c9',width=2)
                    b=row['rack'][i];end=xy(sx+500*(b['x']-sx),sz+500*(b['z']-sz))
                    arrow(pt,end,'#d15b26');txt(pt[0]-7,pt[1]-8,str(i),14)
                else:
                    b=s[names[i]];pt=xy(b['p'][0],b['p'][2]);speed=math.sqrt(sum(v*v for v in b['v']));r=R*scale
                    color='#e99a35' if speed>=1 else '#cad8e6'
                    d.ellipse((pt[0]-r,pt[1]-r,pt[0]+r,pt[1]+r),fill=color,outline='#506579',width=1)
                    end=xy(b['p'][0]+.005*b['v'][0],b['p'][2]+.005*b['v'][2]);arrow(pt,end,'#235ca4',2)
                    txt(pt[0]-7,pt[1]-8,str(i),14)
            # Cue is on the right of apex, heading left.
            arrow(xy(-.55,0),xy(-.60,0),'#276c53',3)
            txt(left+16,y+391,'Slot labels 0-14; arrows show direction, not ball size.',14)
        else:
            x0=left+24;y0=y+105;w=508;h=254
            d.rounded_rectangle((x0,y0,x0+w,y0+h),radius=12,fill='#135d52',outline='#654b38',width=9)
            for n,pt in row['board'].items():
                xx=x0+w*pt[0];yy=y0+w*pt[1];r=R/L*w
                d.ellipse((xx-r,yy-r,xx+r,yy+r),fill='white' if n=='cueBall' else '#efbe57',outline='#152824')
            score=metrics(row)['score'];tail=max(s['tail'] for s in row['spinTail'])
            txt(left+20,y+375,f'Spread {score:.3f} | spin-only tail {tail:.2f} s',19)
txt(30,1110,'Orange: speed >= 1 m/s. Blue arrows: 5 ms velocity extrapolation. Final score is observational only.',18)
im.save(OUT/'comparison.png')
print(OUT/'comparison.png')
