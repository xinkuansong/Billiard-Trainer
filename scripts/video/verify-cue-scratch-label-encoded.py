from pathlib import Path
import json,subprocess
import numpy as np
from PIL import Image,ImageDraw
r=Path(__file__).resolve().parents[2];p=r/'output/cue-scratch-selection-20261005/r15-case-label-border';m=json.loads((p/'manifest.json').read_text());old=p.parent/'r13-black-pot-line'
checks=[];items=[]
for c in m['cases']:
    n=c['startFrame'];expr=f'eq(n,{n+119})+eq(n,{n+120})'
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p/'V023-six-full-shots-120fps.mp4'),'-vf',f"select='{expr}'",'-fps_mode','passthrough','-f','rawvideo','-pix_fmt','rgb24','-'])
    frames=np.frombuffer(raw,dtype=np.uint8).reshape(2,2560,1440,3)
    # Verify native keyframes against the encoded label region on both sides of the hide boundary.
    errors=[]
    for index,local in enumerate([119,120]):
        ref=np.array(Image.open(p/f"{c['id']}-{local:04d}.png").convert('RGB'))
        roi=(slice(250,390),slice(25,345))
        err=float(np.abs(frames[index][roi].astype(float)-ref[roi]).mean());assert err<4,(c['id'],local,err)
        errors.append(err)
    before=frames[0,250:390,25:345];after=frames[1,250:390,25:345]
    assert np.abs(before.astype(float)-after).mean()>12,c['id']
    checks.append({'case':c['id'],'encodedLabelRegionMAE':errors,'labelDisappearsWithGuidesAtFrame':n+120})
    items.append((c['id'],before,after))
sheet=Image.new('RGB',(640,180*6),(24,24,24));d=ImageDraw.Draw(sheet)
for row,(name,before,after) in enumerate(items):
    d.text((8,row*180+7),f'{name} - label visible / stroke starts',fill='white')
    sheet.paste(Image.fromarray(before),(0,row*180+30));sheet.paste(Image.fromarray(after),(320,row*180+30))
sheet.save(p/'encoded-label-boundaries.jpg',quality=95)
assert (p/'audio/soundtrack.wav').read_bytes()==(old/'audio/soundtrack.wav').read_bytes(),'Audio changed'
(p/'label-verification.json').write_text(json.dumps({'cases':checks,'audioUnchangedFromR13':True},indent=2))
print('PASS: six encoded label hide boundaries, audio unchanged.')
