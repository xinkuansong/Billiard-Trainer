from pathlib import Path
import math,json,sys,subprocess
from PIL import Image,ImageDraw
p=Path(__file__).resolve().parents[2]/'output/cue-scratch-selection-20261005/r12-complete-pocket';m=json.loads((p/'manifest.json').read_text())
source=p
suffix=''
if '--encoded' in sys.argv:
    source=p/'encoded-pockets';source.mkdir(exist_ok=True);suffix='-encoded'
    frames=sorted((c['startFrame']+n,c['id'],n) for c in m['cases'] for n in [c['belowClothFrame'],c['bothDropFrame']])
    expr='+'.join(f'eq(n,{f})' for f,_,_ in frames)
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(p/'V023-six-full-shots-120fps.mp4'),'-vf',f"select='{expr}',setpts=N/(120*TB)",'-fps_mode','passthrough',str(source/'frame-%02d.png')],check=True)
    for i,(_,name,n) in enumerate(frames,1): (source/f'frame-{i:02d}.png').rename(source/f'{name}-{n:04d}.png')
pockets=[(-1.312,-.677),(1.312,-.677),(-1.312,.677),(1.312,.677),(0,-.676),(0,.676)]
sheet=Image.new('RGB',(1200,6*270),(25,25,25));draw=ImageDraw.Draw(sheet)
for row,c in enumerate(m['cases']):
    ax,az=c['aimXZ'];cx,cy,cz=c['cameraXYZ'];pitch=math.radians(c['pitchDegrees']);tan=math.tan(math.radians(c['cameraFOV']/2))
    for j,k in enumerate(['cuePocket','targetPocket']):
        px,pz=pockets[c[k]];dx,dy,dz=px-cx,.8-cy,pz-cz
        f=dx*ax+dz*az;r=-dx*az+dz*ax;depth=f*math.cos(pitch)-dy*math.sin(pitch);up=f*math.sin(pitch)+dy*math.cos(pitch)
        x=(r/(depth*(1440/2560)*tan)+1)*720;y=(1-up/(depth*tan))*1280
        for stage,n in enumerate([c['belowClothFrame'],c['bothDropFrame']]):
            im=Image.open(source/f"{c['id']}-{n:04d}.png").convert('RGB');crop=im.crop((round(x)-150,round(y)-110,round(x)+150,round(y)+140))
            pos=(j*600+stage*300,row*270+20);sheet.paste(crop,pos);draw.text((pos[0]+5,row*270+3),f"{c['id']} {k} {'old stop' if stage==0 else 'complete'}",fill='white')
sheet.save(p/f'pocket-review{suffix}.jpg')
