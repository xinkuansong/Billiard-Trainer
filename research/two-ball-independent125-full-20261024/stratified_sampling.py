"""Independent per-combination tip jitter, with exact zero axes and fixed center.
Only tip coordinates change vs stratified125-axis-v1: selected IDs/speeds/quotas stay fixed.
"""
import quota_sampling_v1 as baseline
QUOTAS=baseline.QUOTAS
VERSION='stratified125-axis-independent-v2'
rng_for=baseline.rng_for
REGIONS=[]
for iy in range(3,-4,-1):
 for ix in range(3,-4,-1):
  cx,cy=ix*.15,iy*.15
  if max(abs(cx)-.075,0)**2+max(abs(cy)-.075,0)**2<.25:REGIONS.append((cx,cy))
assert len(REGIONS)==45
def combinations(layout_id,count=125):
 result=baseline.combinations(layout_id,count)
 for c in result:
  cx,cy=REGIONS[c['tipID']-1];cat=c['strokeCategory']
  if cat=='center':x=y=0.
  else:
   rng=rng_for(VERSION,layout_id+'\0'+str(c['comboIndex']))
   for _ in range(10000):
    x=0. if cat=='vertical' else rng.uniform(cx-.075,cx+.075)
    y=0. if cat=='horizontal' else rng.uniform(cy-.075,cy+.075)
    if x*x+y*y<=.25:break
   else:raise RuntimeError('independent jitter budget exhausted')
  c['spinX']=x;c['spinY']=y
 return result
