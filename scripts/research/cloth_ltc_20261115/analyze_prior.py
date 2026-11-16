"""Reclassify existing R3 pixels without rerendering or changing the old verdict."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw


def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--evidence',type=Path,required=True);a=p.parse_args();a.evidence.mkdir(parents=True,exist_ok=True)
    result=[]
    for row in json.loads((a.source/'results.json').read_text()):
        w,h=row['width'],row['height'];cases=[];worst=None
        for c in row['comparisons']:
            prefix=f"{row['pose']}-{row['variant']}-{str(c['shadows']).lower()}-{c['frame']}"
            aa=np.fromfile(a.source/f'{prefix}-A.bgra8',np.uint8).reshape(h,w,4);bb=np.fromfile(a.source/f'{prefix}-B.bgra8',np.uint8).reshape(h,w,4)
            d=abs(aa[:,:,:3].astype(np.int16)-bb[:,:,:3].astype(np.int16));v=d.max(axis=2)
            case={'frame':c['frame'],'shadows':c['shadows'],'maximum':int(v.max()),'meanChannelDifference':float(d.mean()),'p99MaxChannel':float(np.percentile(v,99)),
                  'pixels':w*h,'over':{str(k):int((v>k).sum()) for k in [1,2,4,8]}}
            cases.append(case)
            if worst is None or case['over']['1']>worst[0]['over']['1']:worst=(case,aa.copy(),bb.copy(),v.copy())
        case,aa,bb,v=worst
        canvas=Image.new('RGB',(w*3,h+32),(22,22,22));draw=ImageDraw.Draw(canvas)
        for i,(name,data) in enumerate([('A: reference',aa[:,:,[2,1,0]]),('B: candidate',bb[:,:,[2,1,0]]),('Difference x60 (not actual appearance)',np.stack([np.minimum(v*60,255),np.minimum(v*15,255),np.zeros_like(v)],axis=2).astype(np.uint8))]):
            canvas.paste(Image.fromarray(data),(i*w,32));draw.text((i*w+8,8),name,fill='white')
        canvas.save(a.evidence/(row['pose']+'-prior-worst.png'))
        result.append({'pose':row['pose'],'cases':cases,'worst':case})
    (a.evidence/'prior-distribution.json').write_text(json.dumps({'source':str(a.source),'denominator':'whole image, not cloth ROI','rows':result},indent=2)+'\n')
    print(a.evidence/'prior-distribution.json')


if __name__=='__main__':main()
