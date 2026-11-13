"""Compare full real-cloth PNGs for an exact-support mask experiment."""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image,ImageDraw
p=Path(sys.argv[1]);caps=json.loads((p/'captures.json').read_text());manifest=json.loads((p/'shader-manifest.json').read_text());mode=manifest['support_mask'].get('mode','safe');rows=[];prev=None;temporal=[]
def read(name):return np.asarray(Image.open(p/name).convert('RGB')).astype(np.int16)
for rec in caps['records']:
 name=rec['id'];r=read(name+'-reference.png');c=read(name+'-height-safe.png');d=abs(r-c);cov=read(name+'-coverage.png');pruned=(cov[...,0]==0)&(cov[...,1]==255)&(cov[...,2]==0)
 row={'id':name,'exact_rgb_equal':bool(np.array_equal(r,c)),'max_8bit_channel_error':int(d.max()),'rmse_8bit_channels':float(np.sqrt(np.mean(d.astype(float)**2))),'changed_pixels':int(np.any(d,axis=-1).sum()),'pruned_near_visible_pixels':int(pruned.sum()),'repeat_equal':bool(np.array_equal(r,read(name+'-repeat.png'))),'restore_equal':bool(np.array_equal(r,read(name+'-restored.png'))),'red_control_changed_pixels':int(np.any(r!=read(name+'-red-control.png'),axis=-1).sum())};rows.append(row)
 heat=np.zeros(r.shape,np.uint8);heat[...,0]=np.clip(d.max(axis=-1)*32,0,255);Image.fromarray(heat).save(p/f'{name}-diff-x32.png')
 canvas=Image.new('RGB',(1200,830),'#151515');draw=ImageDraw.Draw(canvas)
 labels=[('reference','R production cloth'),('height-safe','Guarded legacy + safe mask' if mode.startswith('legacy-') else 'Safe support mask'),('coverage','Green: shadow loop or ball checks skipped' if mode.startswith('legacy-') else 'Green: near fragment with removed mask entries'),('diff-x32','RGB difference x32')]
 for k,(suffix,label) in enumerate(labels):
  tile=Image.open(p/f'{name}-{suffix}.png').convert('RGB').resize((600,400));x=(k%2)*600;y=(k//2)*415;canvas.paste(tile,(x,y+15));draw.text((x+8,y+2),label,fill='white')
 canvas.save(p/f'{name}-comparison.png')
 if name.startswith('move-'):
  if prev:
   rid,rr,cc=prev;dd=(c-cc)-(r-rr);temporal.append({'from':rid,'to':name,'max_delta_difference':int(abs(dd).max()),'different_delta_pixels':int(np.any(dd,axis=-1).sum())})
  prev=(name,r,c)
description=manifest.get('candidate_description','Unconditional below-bed mask OR term replaced with source-hashed conservative helper; original support predicate, 8/64 selection, visibility filtering, BRDF and material untouched.'+(' Completed near predicate gates mask construction, originalInSupport is checked first, and unused far diagnostic mask becomes0.' if mode=='safe-near-first' else ''))
report={'scope':'macOS isolated real USDZ cloth with complete production cloth modifiers/material/native PBR/light/exposure. Not full App, phone or continuous lifecycle/motion evidence.','candidate':description,'mode':mode,'helper':manifest['support_mask'],'rows':rows,'frozen_motion_sequence':{'frames':sum(x['id'].startswith('move-') for x in rows),'meaning':'Fixed camera, deterministic ball positions per frame; compare inter-frame RGB deltas. Not native App replay/touch lifecycle test.','consecutive_deltas':temporal},'hashes':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in p.iterdir() if f.suffix in ['.surface','.png']}}
(p/'support-analysis.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'rows':rows,'temporal':temporal},indent=2))
