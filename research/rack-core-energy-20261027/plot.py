from study import *
from PIL import Image,ImageDraw,ImageFont
selection=json.load(open(OUT/'selection.json'))['selected'];energies=json.load(open(OUT/'slot-energies.json'));examples=json.load(open(OUT/'examples.json'));summary=json.load(open(OUT/'summary.json'))
im=Image.new('RGB',(1800,1070),'#f4f6f9');d=ImageDraw.Draw(im);fontpath='/System/Library/Fonts/Supplemental/Arial.ttf'
font=lambda n:ImageFont.truetype(fontpath,n)
def txt(x,y,s,size=18,fill='#172b3a'):d.text((x,y),s,font=font(size),fill=fill)
def arrow(a,b,color,width=3):
    d.line([a,b],fill=color,width=width);dx,dy=b[0]-a[0],b[1]-a[1];l=math.hypot(dx,dy)
    if l<3:return
    ux,uy=dx/l,dy/l;d.polygon([b,(b[0]-8*ux+4*uy,b[1]-8*uy-4*ux),(b[0]-8*ux-4*uy,b[1]-8*uy+4*ux)],fill=color)
txt(30,20,'Core-ball energy retention | frozen engine and physical parameters',30)
txt(30,63,'Top: average per-slot energy at 5 ms, all 200 new racks. Bottom: first rack offsets x500.',21)
maximum=max(v for a in energies.values() for v in a)
for col,p in enumerate(selection):
    left=20+col*595;row=examples[p];slots=row['slots'];txt(left+15,110,p,24)
    for rr in range(2):
        top=155+rr*440;d.rounded_rectangle((left,top,left+575,top+420),radius=13,fill='white',outline='#cad4e0',width=2)
        label='Mean translational energy (joules)' if rr==0 else 'Initial offsets (core slots outlined purple)'
        txt(left+15,top+15,label,20)
        scale=930
        def xy(x,z):return (left+85+(x+.93)*scale,top+65+(z+.17)*scale)
        radius=R*scale
        for i,(sx,sz) in enumerate(slots):
            x,y=xy(sx,sz)
            if rr==0:
                t=math.sqrt(energies[p][i]/maximum);fill=(int(231-25*t),int(239-100*t),int(248-210*t))
            else:fill='white'
            d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=fill,outline='#7926a7' if i in CORE else '#869bac',width=4 if i in CORE else 2)
            if rr==0:
                txt(x-7,y-18,str(i),14);txt(x-22,y+1,f'{energies[p][i]:.3f}',14)
            else:
                b=row['rack'][i];arrow((x,y),xy(sx+500*(b['x']-sx),sz+500*(b['z']-sz)),'#ce5e25');txt(x-7,y-8,str(i),14)
        arrow(xy(-.55,0),xy(-.60,0),'#286b50')
        if rr==0:
            a=summary[p];txt(left+15,top+374,f"Core total {a['coreEnergy5']:.3f} J | core >=1 m/s {a['coreActive5']:.2f}/3",18)
        else:txt(left+15,top+374,'Seed 60000. Arrows exaggerated; actual offsets <=0.09 mm.',16)
txt(30,1040,'Core slots: 4, 7, 8. Slot IDs describe initial positions, not ball numbers. X right; Z down.',19)
im.save(OUT/'core-comparison.png');print(OUT/'core-comparison.png')
