#!/usr/bin/env python3
"""Mux native footage losslessly and verify encoded media and transition samples."""
from pathlib import Path
import json, subprocess, hashlib
import numpy as np
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
p = root / 'output/cue-scratch-selection-20261005/r8-sound-transitions'
m = json.loads((p/'manifest.json').read_text())
assert m['exported'] and m['frames'] == 1305
states = json.loads((p/'frame-states.json').read_text())
prior = json.loads((p.parent/'r7-six-full-shots/manifest.json').read_text())
for c,old in zip(m['cases'],prior['cases']):
    for key in ('id','cameraXYZ','cameraFOV','pitchDegrees','speed','spin','cutDegrees','events','ghostXYZ'):
        assert c[key] == old[key],key
    s=[x for x in states if x['case']==c['id']]
    assert len(s)==c['frames'] and c['strokeStartFrame']-c['fadeInFrames']==30
    assert all(not x['guidesHidden'] and not x['ghostHidden'] and x['cuePull']==0 for x in s[:c['strokeStartFrame']])
    assert all(x['guidesHidden'] and x['ghostHidden'] for x in s[c['strokeStartFrame']:])
    assert s[c['strokeStartFrame']+10]['cuePull']>0
    assert c['bothDropFrame']==max(c['dropFrames'].values())
    assert c['fadeOutStartFrame']-c['bothDropFrame']-1==18
    assert c['frames']-c['fadeOutStartFrame']==18
    for name in ('cueXYZ','objectXYZ'):
        assert s[c['bothDropFrame']][name][1]+.028575<=.800001
        assert all(x[name]==s[c['bothDropFrame']][name] for x in s[c['bothDropFrame']:])
    assert s[-1]['fadeAlpha']==1 and s[c['fadeOutStartFrame']-1]['fadeAlpha']==0
(p/'timing-verification.json').write_text(json.dumps({'frames':len(states),'duration':len(states)/60,'staticHoldFrames':30,'guidesAndGhostHideAtStrokeStart':True,'bothBallsDropBeforeHold':True,'postHoldFrames':18,'fadeOutFrames':18,'nextFadeInFrames':18,'cameraAndPhysicsUnchanged':True},indent=2))
review = p/'encoded-review'; review.mkdir(exist_ok=True)
def run(args):
    return subprocess.check_output(args)
def video_hash(path):
    return run(['ffmpeg','-v','error','-i',str(path),'-map','0:v:0','-c','copy','-f','hash','-hash','sha256','-']).decode().strip()
jobs = [(p/'V023-six-full-shots-silent.mp4',p/'audio/soundtrack.wav',p/'V023-six-full-shots-sound.mp4',m['frames'])]
jobs += [(p/f"{c['id']}-silent.mp4",p/f"audio/{c['id']}.wav",p/f"{c['id']}-full-shot-sound.mp4",c['frames']) for c in m['cases']]
results=[]
for source, audio, dest, count in jobs:
    run(['ffmpeg','-y','-v','error','-i',str(source),'-i',str(audio),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart',str(dest)])
    probe=json.loads(run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(dest)]))
    v,a=probe['streams'];assert v['codec_name']=='h264' and a['codec_name']=='aac'
    assert (v['width'],v['height'],v['r_frame_rate'],int(v['nb_frames']))==(1440,2560,'60/1',count)
    assert abs(float(v['duration'])-count/60)<.00001 and abs(float(a['duration'])-count/60)<.03
    run(['ffmpeg','-v','error','-xerror','-i',str(dest),'-f','null','-'])
    assert video_hash(source)==video_hash(dest)
    pcm=np.frombuffer(run(['ffmpeg','-v','error','-i',str(dest),'-map','0:a','-f','f32le','-']),dtype='<f4')
    peak=float(np.abs(pcm).max());assert 0<peak<1
    results.append({'file':dest.name,'frames':count,'duration':float(v['duration']),'videoBitrate':int(v['bit_rate']),'bytes':dest.stat().st_size,'videoPayloadUnchanged':True,'fullDecode':True,'audioPeak':peak,'audioRMS':float(np.sqrt(np.mean(pcm**2))),'streams':probe['streams']})
    print('verified',dest.name,flush=True)

transitions=[]
for c in m['cases']:
    indices=[c['strokeStartFrame']-1,c['strokeStartFrame'],round(c['impactTime']*60)+8,c['bothDropFrame'],c['fadeOutStartFrame']-1,c['fadeOutStartFrame']+8,c['frames']-1]
    if c['fadeInFrames']: indices.extend([0,8,17])
    indices=sorted(set(indices))
    expr='+'.join(f'eq(n,{n})' for n in indices)
    run(['ffmpeg','-y','-v','error','-i',str(p/f"{c['id']}-full-shot-sound.mp4"),'-vf',f"select='{expr}',scale=288:512",'-fps_mode','vfr',str(review/f"{c['id']}-%02d.png")])
    frames={n:Image.open(review/f"{c['id']}-{i+1:02d}.png").convert('RGB') for i,n in enumerate(indices)}
    lum=lambda n: float(np.asarray(frames[n].convert('L')).mean())
    full=lum(c['fadeOutStartFrame']-1);mid=lum(c['fadeOutStartFrame']+8);end=lum(c['frames']-1)
    assert full>15 and .2<mid/full<.7 and end<1,(c['id'],full,mid,end)
    if c['fadeInFrames']:assert lum(0)<1 and .2<lum(8)/lum(17)<.7
    transitions.append({'case':c['id'],'holdMeanLuma':full,'fadeMidMeanLuma':mid,'endMeanLuma':end,'checkedFrames':indices})
    sheet=Image.new('RGB',(len(indices)*288,542),(25,25,25));draw=ImageDraw.Draw(sheet)
    for j,n in enumerate(indices):sheet.paste(frames[n],(j*288,30));draw.text((j*288+8,8),f"{c['id']}  frame {n}",fill='white')
    sheet.save(review/f"{c['id']}-sheet.jpg",quality=90)
    print('transitions verified',c['id'],full,mid,end,flush=True)
(p/'media-verification.json').write_text(json.dumps({'media':results,'encodedTransitionChecks':transitions},indent=2))
