#!/usr/bin/env python3
"""Mix frozen App audition samples on production contact timestamps; preserve video streams."""
from pathlib import Path
import json,subprocess,wave,hashlib
import numpy as np
root=Path(__file__).resolve().parents[2]
p=root/'output/cue-scratch-selection-20261005/r8-sound-transitions'
m=json.loads((p/'manifest.json').read_text());sr=48000
samples={}
for name in {e['asset'] for c in m['cases'] for e in c['soundEvents']}:
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p/'audio'/f'{name}.caf'),'-ac','1','-ar',str(sr),'-f','f32le','-'])
 samples[name]=np.frombuffer(raw,dtype='<f4').astype(np.float64)
segments=[];placements=[]
for c in m['cases']:
 n=c['frames']*sr//60;mix=np.zeros(n)
 for e in c['soundEvents']:
  start=round(e['time']*sr)
  if start>=n:continue
  sound=samples[e['asset']]*e['gain'];length=min(len(sound),n-start)
  mix[start:start+length]+=sound[:length]
  placements.append({'case':c['id'],'kind':e['kind'],'asset':e['asset'],'localTime':e['time'],'globalTime':c['startFrame']/60+e['time'],'sampleOffset':start,'gain':e['gain'],'alignmentErrorSeconds':abs(start/sr-e['time'])})
 start=round(c['fadeOutStartFrame']/60*sr)
 mix[start:]*=np.linspace(1,0,n-start,endpoint=True)
 segments.append(mix)
peak=max(float(np.max(np.abs(x))) for x in segments);assert peak>0
# One global gain retains calibrated relative strengths, including quiet impacts.
masterGain=.8/peak
for c,segment in zip(m['cases'],segments):
 segment*=masterGain
 assert np.max(np.abs(segment))<=.800001
 def save(name,data):
  pcm=np.rint(np.clip(data,-1,1)*32767).astype('<i2');stereo=np.repeat(pcm[:,None],2,axis=1)
  with wave.open(str(p/'audio'/name),'wb') as f:f.setparams((2,2,sr,len(pcm),'NONE','not compressed'));f.writeframes(stereo.tobytes())
 save(c['id']+'.wav',segment)
master=np.concatenate(segments);save('soundtrack.wav',master)
(p/'audio/mix-manifest.json').write_text(json.dumps({'sampleRate':sr,'channels':2,'sampleCount':len(master),'duration':len(master)/sr,'globalGain':masterGain,'peak':float(np.max(np.abs(master))),'rms':float(np.sqrt(np.mean(master**2))),'clippedSamples':int(np.sum(np.abs(master)>=1)),'placements':placements,'sourceHashes':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in (p/'audio').glob('*.caf')}},indent=2))
print('audio',len(master)/sr,'seconds;',len(placements),'contact cues; peak',float(np.max(np.abs(master))),'gain',masterGain,flush=True)
