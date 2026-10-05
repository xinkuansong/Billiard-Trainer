#!/usr/bin/env python3
"""Retain native shot footage and replace black fades with 30-frame dissolves."""
from pathlib import Path
import hashlib, json, subprocess, wave
import numpy as np

root=Path(__file__).resolve().parents[2]
src=root/'output/cue-scratch-selection-20261005/r8-sound-transitions'
out=src.parent/'r9-cross-dissolve';out.mkdir(exist_ok=True)
m=json.loads((src/'manifest.json').read_text());fps=60;sr=48000;w=1440;h=2560
records=[];frame=0
for i,c in enumerate(m['cases']):
    start=c['fadeInFrames'];end=c['fadeOutStartFrame'];n=end-start
    records.append({'id':c['id'],'sourceStartFrame':start,'sourceEndFrameExclusive':end,'startFrame':frame,'frames':n,'strokeStartFrame':frame+30,'bothDropFrame':frame+c['bothDropFrame']-start,'endFrameExclusive':frame+n,'transitionFrames':30 if i<5 else 0})
    frame+=n+(30 if i<5 else 0)
assert frame==1257
manifest={'version':'r9-cross-dissolve','fps':fps,'width':w,'height':h,'frames':frame,'duration':frame/fps,'transition':'simultaneous-out-in-no-black','fadeOutSeconds':.5,'fadeInSeconds':.5,'finalHoldSeconds':.3,'finalFade':False,'cases':records,'sourceHashes':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in [src/'manifest.json']+[src/f"{c['id']}-silent.mp4" for c in records]}}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
# Reuse original event samples and gain; shift event offsets with the picture edit.
audio=np.zeros(frame*sr//fps,dtype=np.float64);events=[];samples={}
gain=json.loads((src/'audio/mix-manifest.json').read_text())['globalGain']
for c,r in zip(m['cases'],records):
    for e in c['soundEvents']:
        name=e['asset']
        if name not in samples:
            raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(src/'audio'/f'{name}.caf'),'-ac','1','-ar',str(sr),'-f','f32le','-'])
            samples[name]=np.frombuffer(raw,dtype='<f4').astype(np.float64)
        time=(r['startFrame']-r['sourceStartFrame'])/fps+e['time'];offset=round(time*sr)
        sound=samples[name]*e['gain']*gain;n=min(len(sound),len(audio)-offset)
        audio[offset:offset+n]+=sound[:n]
        events.append(dict(e,case=c['id'],globalTime=time,sampleOffset=offset))
assert np.max(np.abs(audio))<=.80001
pcm=np.repeat(np.rint(audio*32767).astype('<i2')[:,None],2,axis=1)
with wave.open(str(out/'soundtrack.wav'),'wb') as f:
    f.setparams((2,2,sr,len(audio),'NONE','not compressed'));f.writeframes(pcm.tobytes())
(out/'audio-timeline.json').write_text(json.dumps({'events':events,'gain':gain,'peak':float(np.abs(audio).max()),'source':str(src/'audio/source-manifest.json')},indent=2))

def decode_frame(c,index):
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(src/f"{c['id']}-silent.mp4"),'-vf',f"select='eq(n,{index})'",'-frames:v','1','-pix_fmt','rgb24','-f','rawvideo','-'])
    assert len(raw)==w*h*3
    return np.frombuffer(raw,dtype=np.uint8).reshape(h,w,3)

log=open(out/'encode.log','w')
encoder=subprocess.Popen(['ffmpeg','-y','-v','warning','-f','rawvideo','-pixel_format','rgb24','-video_size',f'{w}x{h}','-framerate',str(fps),'-i','-','-i',str(out/'soundtrack.wav'),'-map','0:v','-map','1:a','-c:v','libx264','-preset','fast','-crf','15','-pix_fmt','yuv420p','-threads','6','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out/'V023-six-full-shots-cross-dissolve.mp4')],stdin=subprocess.PIPE,stderr=log)
written=0
try:
    for i,r in enumerate(records):
        decoder=subprocess.Popen(['ffmpeg','-v','error','-i',str(src/f"{r['id']}-silent.mp4"),'-vf',f"trim=start_frame={r['sourceStartFrame']}:end_frame={r['sourceEndFrameExclusive']},setpts=PTS-STARTPTS",'-pix_fmt','rgb24','-f','rawvideo','-'],stdout=subprocess.PIPE)
        for n in range(r['frames']):
            data=decoder.stdout.read(w*h*3);assert len(data)==w*h*3
            encoder.stdin.write(data);written+=1
        assert not decoder.stdout.read(1) and decoder.wait()==0
        if i<5:
            a=np.frombuffer(data,dtype=np.uint8).reshape(h,w,3).astype(np.uint16)
            nxt=records[i+1];b=decode_frame(nxt,nxt['sourceStartFrame']).astype(np.uint16)
            for n in range(30):
                # Complementary weights sum to one: no black background contribution.
                mixed=((a*(29-n)+b*n+14)//29).astype(np.uint8)
                encoder.stdin.write(mixed.tobytes());written+=1
        print('encoded',r['id'],'total frames',written,flush=True)
finally:
    encoder.stdin.close()
assert encoder.wait()==0 and written==frame
print('done',written,frame/fps,flush=True)
