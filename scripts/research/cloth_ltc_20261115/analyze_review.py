"""R6 distributions, cloth ROI, paired stills and lossless motion evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import numpy as np
from PIL import Image, ImageDraw


def image(data,w,h):return Image.fromarray(data.reshape(h,w,4)[:,:,[2,1,0]])


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);ap.add_argument('--evidence',type=Path,required=True);a=ap.parse_args();a.evidence.mkdir(parents=True,exist_ok=True)
    rows=json.loads((a.source/'results.json').read_text());out=[]
    for row in rows:
        w,h=row['width'],row['height'];pose=row['pose'];cases=[];frames=[];previous=None
        for c in row['comparisons']:
            f=c['frame'];stem=f'{pose}-{f}'
            aa=np.fromfile(a.source/f'{stem}-A.bgra8',np.uint8).reshape(-1,4);bb=np.fromfile(a.source/f'{stem}-B.bgra8',np.uint8).reshape(-1,4)
            mask=np.fromfile(a.source/f'{stem}-mask.bgra8',np.uint8).reshape(-1,4)[:,:3].min(axis=1)>128
            error=bb[:,:3].astype(np.int16)-aa[:,:3].astype(np.int16);d=np.abs(error).max(axis=1)
            regions={}
            for name,region in [('whole',np.ones(len(d),dtype=bool)),('cloth',mask)]:
                v=d[region];assert len(v)>0
                regions[name]={'pixels':int(len(v)),'maximum':int(v.max()),'meanMaxChannel':float(v.mean()),'percentiles':dict(zip(['p95','p99','p99_9'],map(float,np.percentile(v,[95,99,99.9])))),
                               'over':{str(level):{'pixels':int((v>level).sum()),'percent':float((v>level).mean()*100)} for level in [1,2,4,8]},
                               'meanSignedRGB':error[region].mean(axis=0)[::-1].tolist()}
            temporal={} if previous is None else {'maxErrorChange':int(abs(error-previous).max()),'p99_9ErrorChange':float(np.percentile(abs(error-previous).max(axis=1),99.9))}
            previous=error;cases.append({'frame':f,'regions':regions,'temporal':temporal})
            ia,ib=image(aa,w,h),image(bb,w,h)
            if row['mode']=='motion' or f==0:
                paired=Image.new('RGB',(w*2,h+30),(22,22,22));paired.paste(ia,(0,30));paired.paste(ib,(w,30))
                draw=ImageDraw.Draw(paired);draw.text((10,8),'A: production reference',fill='white');draw.text((w+10,8),'B: single LTC R3',fill='white')
                if row['mode']=='motion':frames.append(paired)
                if f==0:paired.save(a.evidence/f'{pose}-comparison.png')
            if f==0:
                heat=np.zeros((len(d),3),np.uint8);heat[:,0]=np.minimum(d*60,255);heat[:,1]=np.minimum(d*15,255)
                Image.fromarray(heat.reshape(h,w,3)).save(a.evidence/f'{pose}-difference-x60.png')
        if frames:
            frames[0].save(a.evidence/f'{pose}-motion.webp',save_all=True,append_images=frames[1:],duration=50,loop=0,lossless=True,method=4)
        timing={}
        for kind in sorted(set(t['kind'] for t in row['times'])):
            groups=[]
            for cycle in range(6):
                samples={arm:[v for t in row['times'] if t['kind']==kind and t['cycle']==cycle and t['arm']==arm for v in t['gpuMS']] for arm in ['A','B']}
                av,bv=statistics.median(samples['A']),statistics.median(samples['B'])
                groups.append({'cycle':cycle,'aMS':av,'bMS':bv,'decreasePercent':(av-bv)/av*100})
            values=[g['decreasePercent'] for g in groups]
            timing[kind]={'groups':groups,'medianDecreasePercent':statistics.median(values),'positiveGroups':sum(v>0 for v in values)}
        out.append({'pose':pose,'width':w,'height':h,'cases':cases,'timing':timing})
    (a.evidence/'review.json').write_text(json.dumps({'source':str(a.source),'sourceSHA':hashlib.sha256((a.source/'results.json').read_bytes()).hexdigest(),'rows':out},indent=2)+'\n')
    print(a.evidence/'review.json')


if __name__=='__main__':main()
