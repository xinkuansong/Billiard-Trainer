"""Axis-preserving 14/42/18/51 sampling, version stratified125-axis-v1.
Spin coordinates are dimensionless production spinX/spinY; accepted disk radius .5.
Draw the frozen grid first, then lock axes, retaining identical mixed points and speeds.
"""
import hashlib,random,collections
VERSION='stratified125-axis-v1'
QUOTAS={'center':14,'vertical':42,'horizontal':18,'mixed':51}
def rng_for(label,lid):return random.Random(int(hashlib.sha256((label+'\0'+lid).encode()).hexdigest(),16))
def full_grid(layout_id):
 rng=rng_for('strike-grid-v1',layout_id);tips=[]
 for iy in range(3,-4,-1):
  for ix in range(3,-4,-1):
   cx,cy=ix*.15,iy*.15
   if max(abs(cx)-.075,0)**2+max(abs(cy)-.075,0)**2>=.25:continue
   for _ in range(10000):
    x,y=rng.uniform(cx-.075,cx+.075),rng.uniform(cy-.075,cy+.075)
    if x*x+y*y<=.25:break
   else:raise RuntimeError('jitter budget exhausted')
   category='center' if ix==iy==0 else 'vertical' if ix==0 else 'horizontal' if iy==0 else 'mixed'
   x=0. if ix==0 else x;y=0. if iy==0 else y
   tips.append((x,y,category,ix,iy))
 speeds=[rng.uniform(max(.6,.6+j*.3-.15),min(4.5,.6+j*.3+.15)) for j in range(14)]
 assert len(tips)==45
 return [dict(comboIndex=i*14+j,tipID=i+1,speedID=j+1,spinX=x,spinY=y,velocity=v,strokeCategory=cat) for i,(x,y,cat,ix,iy) in enumerate(tips) for j,v in enumerate(speeds)]
def combinations(layout_id,count=125):
 assert count==125
 full=full_grid(layout_id);rng=rng_for(VERSION,layout_id);indices=[];mixed=[]
 for i in range(45):
  cat=full[i*14]['strokeCategory']
  if cat=='center':speeds=range(14)
  elif cat=='vertical':speeds=[rng.choice([j,j+1]) for j in range(0,14,2)]
  elif cat=='horizontal':speeds=[rng.choice(list(g)) for g in [range(0,5),range(5,10),range(10,14)]]
  else:mixed.append(i);continue
  indices.extend(i*14+j for j in speeds)
 # Mixed speed counts exactly 3 or 4 per bin; all 32 mixed tip regions represented.
 remaining=[3]*14
 for j in rng.sample(range(14),9):remaining[j]+=1
 rng.shuffle(mixed);selected=set()
 for i in mixed:
  j=rng.choices(range(14),weights=remaining)[0];selected.add(i*14+j);remaining[j]-=1
 while sum(remaining):
  j=rng.choices(range(14),weights=remaining)[0]
  i=rng.choice([i for i in mixed if i*14+j not in selected]);selected.add(i*14+j);remaining[j]-=1
 indices+=list(selected);assert len(indices)==len(set(indices))==125
 result=[full[i] for i in sorted(indices)];assert collections.Counter(r['strokeCategory'] for r in result)==QUOTAS
 return result
