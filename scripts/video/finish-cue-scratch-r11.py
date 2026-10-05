#!/usr/bin/env python3
"""Align native contact audio, stream-copy mux, and verify 120 fps native export."""
from pathlib import Path
import json,subprocess,wave,hashlib
import numpy as np
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parents[2];p=root/'output/cue-scratch-selection-20261005/r11-fade-on-pocket';old=p.parent/'r8-sound-transitions'
m=json.loads((p/'manifest.json').read_text());fps=m['fps'];assert fps==120 and m['exported']
states=json.loads((p/'frame-states.json').read_text());prior=json.loads((old/'manifest.json').read_text())
assert m['targetBallKey']=='_8' and m['strikeIndicatorRGB']==[1,0,0]
assert len(m['transitions'])==5 and all(t['frames']==120 for t in m['transitions'])
assert len(states)+600==m['frames']
for previous,transition in zip(m['cases'][:-1],m['transitions']):
    assert transition['startFrame']==previous['startFrame']+previous['bothDropFrame']+1
motion=[]
for c,o in zip(m['cases'],prior['cases']):
    for k in ('cameraXYZ','cameraFOV','pitchDegrees','speed','spin','events','ghostXYZ','cutDegrees'):assert c[k]==o[k],k
    ss=[x for x in states if x['case']==c['id']]
    assert len(ss)==c['frames'] and c['strokeStartFrame']==60 and c['frames']-c['bothDropFrame']-1==(36 if c['id']==m['cases'][-1]['id'] else 0)
    assert all(not x['guidesHidden'] and not x['ghostHidden'] for x in ss[:60])
    assert all(x['guidesHidden'] and x['ghostHidden'] for x in ss[60:])
    assert all(abs(ss[i+1]['wallTime']-ss[i]['wallTime']-1/120)<1e-8 for i in range(len(ss)-1))
    for name in ('cueXYZ','objectXYZ'):
        assert ss[c['bothDropFrame']][name][1]+.028575<=.800001
        assert all(x[name]==ss[c['bothDropFrame']][name] for x in ss[c['bothDropFrame']:])
    n=int(np.ceil(c['impactTime']*fps))+2
    assert len({tuple(x['cueXYZ']) for x in ss[n:n+10]})==10
    motion.append({'case':c['id'],'startFrame':c['startFrame']+n,'uniquePositionsIn10Frames':10})
    im=np.array(Image.open(p/f"{c['id']}-0000.png").convert('RGB'))
    for x,y in ((196,1489),(196,1440),(145,1489)):
        r,g,b=map(int,im[y,x]);assert r>200 and g<160 and b<160,(c['id'],x,y,r,g,b)

sr=48000;mix=np.zeros(m['frames']*sr//fps);audioDir=p/'audio';audioDir.mkdir(exist_ok=True)
gain=json.loads((old/'audio/mix-manifest.json').read_text())['globalGain'];samples={};events=[]
for c in m['cases']:
    seg=np.zeros(c['frames']*sr//fps)
    for e in c['soundEvents']:
        asset=e['asset']
        if asset not in samples:samples[asset]=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(old/f'audio/{asset}.caf'),'-ac','1','-ar',str(sr),'-f','f32le','-']),dtype='<f4').astype(float)
        waveData=samples[asset]*e['gain']*gain;local=round(e['time']*sr);globalOffset=c['startFrame']*sr//fps+local
        n=min(len(waveData),len(mix)-globalOffset);mix[globalOffset:globalOffset+n]+=waveData[:n]
        n=max(0,min(len(waveData),len(seg)-local));seg[local:local+n]+=waveData[:n]
        events.append(dict(e,case=c['id'],globalTime=globalOffset/sr))
    def save(name,data):
        assert np.abs(data).max()<1
        pcm=np.repeat(np.rint(data*32767).astype('<i2')[:,None],2,axis=1)
        with wave.open(str(audioDir/name),'wb') as f:f.setparams((2,2,sr,len(data),'NONE','not compressed'));f.writeframes(pcm.tobytes())
    save(c['id']+'.wav',seg)
save('soundtrack.wav',mix)
(p/'audio-timeline.json').write_text(json.dumps({'events':events,'sourceManifest':str(old/'audio/source-manifest.json'),'globalGain':gain,'pcmPeak':float(np.abs(mix).max())},indent=2))
def run(a):return subprocess.check_output(a)
jobs=[('V023-six-full-shots-silent.mp4','soundtrack.wav','V023-fade-on-pocket-120fps.mp4',m['frames'])]
results=[]
for source,audio,dest,count in jobs:
    run(['ffmpeg','-y','-v','error','-i',str(p/source),'-i',str(audioDir/audio),'-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart',str(p/dest)])
    probe=json.loads(run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(p/dest)]));v,a=probe['streams']
    assert (v['width'],v['height'],v['r_frame_rate'],v['avg_frame_rate'],int(v['nb_frames']))==(1440,2560,'120/1','120/1',count)
    assert abs(float(v['duration'])-count/fps)<1e-5 and a['codec_name']=='aac'
    run(['ffmpeg','-v','error','-xerror','-i',str(p/dest),'-f','null','-'])
    def payload(path):return run(['ffmpeg','-v','error','-i',str(path),'-map','0:v','-c','copy','-f','hash','-hash','sha256','-']).decode().strip()
    assert payload(p/source)==payload(p/dest)
    pcm=np.frombuffer(run(['ffmpeg','-v','error','-i',str(p/dest),'-map','0:a','-f','f32le','-']),dtype='<f4');peak=float(np.abs(pcm).max());assert 0<peak<1
    results.append({'file':dest,'probe':probe,'fullDecode':True,'videoPayloadUnchanged':True,'audioPeak':peak})
    print('verified',dest,flush=True)
master=p/jobs[0][2]
pts=json.loads(run(['ffprobe','-v','error','-select_streams','v:0','-show_entries','frame=best_effort_timestamp_time','-of','json',str(master)]))['frames']
times=np.array([float(x['best_effort_timestamp_time']) for x in pts])
assert len(times)==m['frames'] and np.max(np.abs(np.diff(times)-1/120))<.000002
tiny=np.frombuffer(run(['ffmpeg','-v','error','-i',str(master),'-vf','scale=144:256','-pix_fmt','rgb24','-f','rawvideo','-']),dtype=np.uint8).reshape(-1,256,144,3)
assert len(tiny)==m['frames'];brightness=tiny.mean(axis=(1,2,3));assert brightness.min()>35
for item in motion:
    frames=tiny[item['startFrame']:item['startFrame']+10]
    assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==10
transitionChecks=[]
for t in m['transitions']:
    start=t['startFrame'];a=tiny[start-1].astype(float);b=tiny[start+120].astype(float)
    errors=[float(np.abs(tiny[start+j].astype(float)-(a*(1-j/119)+b*j/119)).mean()) for j in range(120)]
    assert max(errors)<3
    transitionChecks.append(dict(t,maxMeanAbsoluteError=max(errors)))
indices=sorted(set([0,m['frames']-1]+[c['startFrame']+n for c in m['cases'] for n in (59,60,int(np.ceil((c['impactTime']+c['events'][0]['time'])*fps))+4,c['bothDropFrame'])]+[t['startFrame']+60 for t in m['transitions']]))
review=p/'encoded-review';review.mkdir(exist_ok=True);expr='+'.join(f'eq(n,{n})' for n in indices)
run(['ffmpeg','-y','-v','error','-i',str(master),'-vf',f"select='{expr}',setpts=N/(120*TB),scale=360:640",'-fps_mode','passthrough',str(review/'frame-%02d.png')])
for page in range((len(indices)+5)//6):
    sheet=Image.new('RGB',(2160,670),(24,24,24));draw=ImageDraw.Draw(sheet)
    for j,n in enumerate(indices[page*6:page*6+6]):
        sheet.paste(Image.open(review/f'frame-{page*6+j+1:02d}.png'),(j*360,30));draw.text((j*360+8,8),f'Frame {n}',fill='white')
    sheet.save(review/f'sheet-{page+1}.jpg',quality=94)
(p/'verification.json').write_text(json.dumps({'frames':m['frames'],'duration':m['duration'],'nativeMotionSampling':motion,'transitions':transitionChecks,'minimumBrightness':float(brightness.min()),'blackFrames':0,'targetBallKey':'_8','strikeIndicatorRGB':[1,0,0],'cameraPhysicsUnchanged':True,'media':results,'reviewIndices':indices},indent=2))
print('PASS native 120 fps motion, black eight, red indicator, five 120-frame dissolves; frames',m['frames'],flush=True)
