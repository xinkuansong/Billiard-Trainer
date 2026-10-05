#!/usr/bin/env python3
from pathlib import Path
import json,subprocess
import numpy as np
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parents[2];p=root/'output/cue-scratch-selection-20261005/r9-cross-dissolve';src=p.parent/'r8-sound-transitions'
m=json.loads((p/'manifest.json').read_text());v=p/'V023-six-full-shots-cross-dissolve.mp4'
def run(a):return subprocess.check_output(a)
probe=json.loads(run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(v)]));vs,au=probe['streams']
assert (vs['width'],vs['height'],vs['r_frame_rate'],int(vs['nb_frames']))==(1440,2560,'60/1',1257)
assert vs['codec_name']=='h264' and au['codec_name']=='aac'
assert abs(float(vs['duration'])-20.95)<.00001 and abs(float(au['duration'])-20.95)<.03
run(['ffmpeg','-v','error','-xerror','-i',str(v),'-f','null','-'])
tiny=np.frombuffer(run(['ffmpeg','-v','error','-i',str(v),'-vf','scale=144:256','-pix_fmt','rgb24','-f','rawvideo','-']),dtype=np.uint8).reshape(-1,256,144,3)
assert len(tiny)==1257
means=tiny.mean(axis=(1,2,3));assert means.min()>35
def frame(path,n):
    return np.frombuffer(run(['ffmpeg','-v','error','-i',str(path),'-vf',f"select='eq(n,{n})',scale=144:256",'-frames:v','1','-pix_fmt','rgb24','-f','rawvideo','-']),dtype=np.uint8).reshape(256,144,3)
checks=[];bodychecks=[]
for i,c in enumerate(m['cases']):
    source=src/f"{c['id']}-silent.mp4"
    for local in (0,29,30,c['frames']-1):
        ref=frame(source,c['sourceStartFrame']+local)
        error=float(np.abs(tiny[c['startFrame']+local].astype(float)-ref).mean());assert error<3
        bodychecks.append({'case':c['id'],'frame':c['startFrame']+local,'meanAbsoluteError':error})
    assert c['strokeStartFrame']-c['startFrame']==30 and c['endFrameExclusive']-c['bothDropFrame']-1==18
    if i==5:continue
    nxt=m['cases'][i+1];start=c['endFrameExclusive'];assert nxt['startFrame']==start+30
    a=frame(source,c['sourceEndFrameExclusive']-1).astype(float)
    b=frame(src/f"{nxt['id']}-silent.mp4",nxt['sourceStartFrame']).astype(float)
    errs=[]
    for j in range(30):
        expected=a*(1-j/29)+b*j/29
        errs.append(float(np.abs(tiny[start+j].astype(float)-expected).mean()))
    assert max(errs)<3,(c['id'],max(errs))
    checks.append({'from':c['id'],'to':nxt['id'],'startFrame':start,'frames':30,'maxMeanAbsoluteError':max(errs),'minimumMeanBrightness':float(means[start:start+30].min())})
pcm=np.frombuffer(run(['ffmpeg','-v','error','-i',str(v),'-map','0:a','-f','f32le','-']),dtype='<f4');peak=float(np.abs(pcm).max());assert 0<peak<1
indices=sorted(set([0,29,30,1256]+[x['startFrame']+k for x in checks for k in (-1,0,14,29,30)]))
review=p/'encoded-review';review.mkdir(exist_ok=True)
expr='+'.join(f'eq(n,{n})' for n in indices)
run(['ffmpeg','-y','-v','error','-i',str(v),'-vf',f"select='{expr}',scale=288:512",'-fps_mode','vfr',str(review/'frame-%02d.png')])
lookup={n:review/f'frame-{i+1:02d}.png' for i,n in enumerate(indices)}
for i,c in enumerate(checks):
    ns=[c['startFrame']+k for k in (-1,0,14,29,30)]
    sheet=Image.new('RGB',(1440,542),(24,24,24));draw=ImageDraw.Draw(sheet)
    for j,n in enumerate(ns):sheet.paste(Image.open(lookup[n]),(j*288,30));draw.text((j*288+8,8),f"{c['from']} > {c['to']}   f{n}",fill='white')
    sheet.save(review/f'transition-{i+1}.jpg',quality=92)
Image.open(lookup[1256]).save(p/'final-frame.png')
Image.open(lookup[0]).save(p/'poster.png')
(p/'verification.json').write_text(json.dumps({'probe':probe,'frames':1257,'duration':20.95,'fullDecode':True,'minimumFrameBrightness':float(means.min()),'blackFrames':int(np.sum(means<5)),'transitionChecks':checks,'bodyFrameChecks':bodychecks,'lastFrameIsCompletedShot':True,'lastFrameBrightness':float(means[-1]),'audioPeak':peak,'reviewIndices':indices},indent=2))
print('PASS: 1257 frames, five 30-frame complementary dissolves, zero black frames, final pot held; audio peak',peak,flush=True)
