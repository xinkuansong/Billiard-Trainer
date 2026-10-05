from pathlib import Path
import subprocess,json
import numpy as np
from PIL import Image
p=Path(__file__).resolve().parents[2]/'output/cue-scratch-selection-20261005/r13-black-pot-line';m=json.loads((p/'manifest.json').read_text());report=[]
for c in m['cases']:
    old=np.array(Image.open(p.parent/'r12-complete-pocket'/f"{c['id']}-0000.png").convert('RGB')).astype(float)
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p/'V023-six-full-shots-120fps.mp4'),'-vf',f"select=eq(n\\,{c['startFrame']})",'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','-'])
    new=np.frombuffer(raw,dtype=np.uint8).reshape(2560,1440,3)
    r,g,b=old[:,:,0],old[:,:,1],old[:,:,2]
    mask=(r>140)&(g>90)&(g<r*.95)&(b<g*.6)
    mask[:600]=False
    changed=mask&(new.max(axis=2)<65)&((old-new).mean(axis=2)>70)
    n=int(changed.sum());assert n>100,(c['id'],n)
    report.append({'case':c['id'],'encodedBlackPixelsAtFormerYellowLine':n})
(p/'black-line-verification.json').write_text(json.dumps(report,indent=2));print(report)
