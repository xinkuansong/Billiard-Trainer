from pathlib import Path
import sys,json,hashlib,math,zipfile
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-best-100-20261026';DATA=OUT/'gallery'
sys.path.insert(0,str(ROOT/'research/rack-regional-phase-20261026'))
from analyze import geometry,extract,outcome,readraw,stats,L,W,R
plan=json.loads((DATA/'protocol.json').read_text());meta=json.loads((DATA/'metadata.json').read_text())
raws={}
for raw in readraw(DATA):
 key=(raw['input']['rackID'],raw['input']['variant']);assert key not in raws and raw['status']=='settled';raws[key]=raw
assert set(raws)=={(r['rackID'],v) for r in plan['racks'] for v in plan['variants']}
assert len(raws)==200
cases=[];rows={v:[] for v in plan['variants']};audits=[]
for idx,r in enumerate(plan['racks'],1):
 case=dict(index=idx,rackID=r['rackID'],seed=r['seed'],variants={})
 for v in plan['variants']:
  raw=raws[r['rackID'],v];assert raw['input']['seed']==r['seed'];audit,_=geometry(raw,raws[r['rackID'],'baseline']);audits.append(audit)
  row=extract(raw);row.update(outcome(raw));rows[v].append(row)
  assert set(raw['names'])-set(raw['board'])==set(raw['pocketed'])
  assert raw['cueScratched']==('cueBall' in raw['pocketed'])
  before=[dict(n=b['number'],x=b['x'],z=b['z']) for b in raw['rack']]+[dict(n=0,x=raw['cue'][0],z=raw['cue'][1])]
  after=[dict(n=0 if k=='cueBall' else int(k[1:]),x=p[0]*L-L/2,z=p[1]*L-W/2) for k,p in raw['board'].items()]
  assert len(after)==16-len(raw['pocketed'])
  case['variants'][v]=dict(before=before,after=after,score=row['score'],scratch=raw['cueScratched'],potted=sorted(int(k[1:]) for k in raw['pocketed'] if k!='cueBall'),remaining=row['remaining'])
 cases.append(case)
summary={v:dict(**stats(rr),scratches=sum(r['scratch'] for r in rr)) for v,rr in rows.items()}
(OUT/'atlas.json').write_text(json.dumps(dict(meta=meta,cases=cases,summary=summary),ensure_ascii=False,indent=2))
(OUT/'summary.json').write_text(json.dumps(summary,indent=2))
colors=['#faf9ee','#efc22f','#3275ce','#d94d43','#8b5aaa','#ed8e3b','#32885b','#9c463d','#202522']
fontpath='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n):return ImageFont.truetype(fontpath,n)
def point(x,z):return (70+(x+L/2)*1060/L,115+(z+W/2)*1060/L)
def render(c,v='radial_sideM60'):
 d=c['variants'][v];im=Image.new('RGB',(1200,760),'#101d24');dr=ImageDraw.Draw(im)
 dr.text((40,20),f"{c['index']:03d} / 100   两侧差异化偏移",font=font(25),fill='white')
 dr.text((770,24),f"散开评分 {d['score']:.3f}  ·  {'≥1.20' if d['score']>=1.2 else '<1.20'}",font=font(22),fill='#e4cf9c')
 dr.rounded_rectangle((32,77,1168,683),radius=23,fill='#4d3b2d');dr.rectangle((57,102,1143,658),fill='#143b32');dr.rectangle((70,115,1130,645),fill='#246956')
 for x,z in meta['pockets']:
  a,b=point(x,z);rr=29;dr.ellipse((a-rr,b-rr,a+rr,b+rr),fill='#091116')
 rr=R*1060/L
 for b in sorted(d['after'],key=lambda b:b['n']):
  x,y=point(b['x'],b['z']);n=b['n'];col=colors[n if n<9 else n-8]
  dr.ellipse((x-rr,y-rr,x+rr,y+rr),fill=col,outline='#0f2421',width=1)
  if n>8:
   dr.chord((x-rr,y-rr,x+rr,y+rr),180,360,fill=col)
   dr.arc((x-rr+2,y-rr+2,x+rr-2,y+rr-2),205,335,fill='white',width=4)
   dr.arc((x-rr+2,y-rr+2,x+rr-2,y+rr-2),25,155,fill='white',width=4)
  if n:
   nr=7.5;dr.ellipse((x-nr,y-nr,x+nr,y+nr),fill='#faf9ee');dr.text((x,y+.5),str(n),anchor='mm',font=font(12),fill='#101b20')
  else:dr.ellipse((x-3,y-3,x+3,y+3),fill='#d54d43')
 dr.text((40,704),f"进球 {len(d['potted'])}  ·  {'母球落袋' if d['scratch'] else '母球在台'}  ·  杆速 9.75 m/s · 正中无塞",font=font(19),fill='#d3dedb')
 dr.text((40,735),'等比例俯视示意 · 球位来自模拟 · 袋口外观简化 · 全部新样本按原顺序展示',font=font(14),fill='#92a7a1')
 return im
(OUT/'boards').mkdir(exist_ok=True);(OUT/'overviews').mkdir(exist_ok=True)
for c in cases:render(c).save(OUT/'boards'/f"{c['index']:03d}.png")
for page in range(10):
 sheet=Image.new('RGB',(1200,1980),'#101d24');dr=ImageDraw.Draw(sheet);dr.text((24,18),f'开球效果 · {page*10+1:03d}–{page*10+10:03d} / 100',font=font(25),fill='white')
 for j,c in enumerate(cases[page*10:page*10+10]):
  im=Image.open(OUT/'boards'/f"{c['index']:03d}.png");im.thumbnail((600,380),Image.Resampling.LANCZOS);sheet.paste(im,((j%2)*600,65+(j//2)*380))
 sheet.save(OUT/'overviews'/f'{page+1:02d}.jpg',quality=92)
with zipfile.ZipFile(OUT/'100-break-results.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted((OUT/'boards').glob('*.png')):z.write(p,'boards/'+p.name)
 for p in sorted((OUT/'overviews').glob('*.jpg')):z.write(p,'overviews/'+p.name)
 z.write(OUT/'atlas.json','atlas.json');z.write(OUT/'summary.json','summary.json')
binding=json.loads((DATA/'source-binding.json').read_text());drift=[]
for r in binding['production']:
 current=hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()
 if current!=r['sha256']:
  assert r['path']=='QiuJi/Core/Physics/BTPhysicsConstants.swift' and r['sha256']=='40fefcd8846f77e3fbedbc7a26e91e0c09ce2008a32251146c7d7145889c383a' and current=='e375754439ebfb0587073b4fbb88a32d561aaafa1695979a909c7d98279221a9'
  frozen=(ROOT/'research/two-ball-strike-full-20261024/native-source/BTPhysicsConstants.swift').read_text()
  expected=frozen.replace('/// 全 App 击打页默认力度 (m/s)（条 13.2：低速走位是常态，默认从 3.3 降至 1.5）。','/// Shared initial shot speed (m/s); saved inputs and per-page reset timing remain unchanged.').replace('static let defaultVelocity: Double = 1.5','static let defaultVelocity: Double = 2.0')
  assert expected==(ROOT/r['path']).read_text()
  drift.append(dict(path=r['path'],atRun=r['sha256'],current=current,review='Post-generation concurrent default shot input changed 1.5 to 2.0 only; this frozen binary explicitly uses 9.75, all 200 outputs checked.'))
assert json.loads((DATA/'generation.json').read_text())['productionDrift']==[]
(OUT/'post-generation-source-review.json').write_text(json.dumps(drift,indent=2))
audit=dict(candidateCount=100,pairedControlCount=100,allSettled=True,allUniqueNewSeeds=True,sourceBindings=len(binding['production']),coordinateContract='World XZ metres; +X right, +Z down; both normalized board axes multiply table length',geometry={k:(min(a[k] for a in audits) if k=='minGapMM' else max(a[k] for a in audits)) for k in audits[0]},pocketedAndCueChecked=True,pngCount=len(list((OUT/'boards').glob('*.png'))))
assert json.loads((DATA/'closure.json').read_text())['success'];assert json.loads((OUT/'seed-audit.json').read_text())['overlap']==[]
(OUT/'verification.json').write_text(json.dumps(audit,indent=2));print(json.dumps(summary,indent=2))
