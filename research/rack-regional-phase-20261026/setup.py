from pathlib import Path
import json,hashlib,random,datetime
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name;PREV=ROOT/'research/rack-phase-tuning-20261026'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,indent=2,ensure_ascii=False))
assert not (OUT/'discovery/protocol.json').exists()
variants=['baseline','radial_contract']+[f'radial_{g}{a}' for g in ['core','side','front'] for a in ['M60','M30','P30','P60','Flip']]
s=(ROOT/'research/rack-correlated-pattern-20261026/confirmation/main.swift').read_text()
s=s.replace('["contract", "independent"].contains(parts[1])','(["contract", "independent"].contains(parts[1]) || ["core", "side", "front"].contains(where: { parts[1].hasPrefix($0) }))')
needle='                    let (cs,sn,reflect) = rotations[i]'
insert='''                    if family == "radial", let region = ["core", "side", "front"].first(where: { parts[1].hasPrefix($0) }) {
                        let mode = String(parts[1].dropFirst(region.count))
                        let isCore = [4,7,8].contains(i)
                        let isFront = rows[i] <= 2
                        if mode == "Flip" {
                            let flip = region == "core" ? isCore : (region == "front" ? isFront : nominal[i].1 < 0)
                            if flip { z = -z }
                        } else {
                            precondition(["M60", "M30", "P30", "P60"].contains(mode))
                            let degrees = Double(mode.dropFirst())! * (mode.hasPrefix("M") ? -1 : 1)
                            let weight = region == "core" ? (isCore ? 1.0 : 0) : (region == "front" ? (isFront ? 1.0 : 0) : (nominal[i].1 > 0 ? 0.5 : (nominal[i].1 < 0 ? -0.5 : 0)))
                            let a = degrees * weight * Double.pi / 180
                            let xx = cos(a)*x-sin(a)*z, zz = sin(a)*x+cos(a)*z
                            x = xx; z = zz
                        }
                        x = -abs(x); norm = hypot(x,z)
                    }
'''
assert needle in s;s=s.replace(needle,insert+needle);(HERE/'main.swift').write_text(s)
for name in ['build.py','run.py']:
 s=(PREV/name).read_text().replace('rack-phase-tuning-20261026',HERE.name)
 (HERE/name).write_text(s)
excs=json.loads((ROOT/'output/rack-phase-tuning-20261026/source-exceptions.json').read_text())
for e in excs:assert sha(ROOT/e['path']) in [e['currentSHA256'],e['frozenSHA256']]
excs=[e for e in excs if sha(ROOT/e['path'])!=e['frozenSHA256']]
write(OUT/'source-exceptions.json',excs)
old=set();sources=[]
def collect(x,acc):
 if isinstance(x,dict):
  if 'seed' in x:acc.add(str(x['seed']))
  for v in x.values():collect(v,acc)
 elif isinstance(x,list):
  for v in x:collect(v,acc)
for folder in ROOT.glob('output/rack-*'):
 if folder==OUT:continue
 for p in folder.rglob('*.json'):
  if p.name not in ['inputs.json','racks.json','protocol.json','validation-plan.json','confirmation-plan.json']:continue
  ss=set();collect(json.loads(p.read_text()),ss);old|=ss;sources.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p),uniqueSeeds=len(ss)))
assert len(old)==9500,len(old)
rng=random.Random(202610261905);racks=[];new=set()
for i in range(1800):
 seed=str(rng.getrandbits(64));assert seed not in old|new;new.add(seed);racks.append(dict(rackID=9500+i,seed=seed))
write(OUT/'seed-audit.json',dict(historicalUnique=len(old),newUnique=len(new),overlap=[],sources=sources))
base=dict(createdUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),workers=4,variants=variants,conditions='15 balls; nominal gap0.20mm; preserve each original <=0.09mm offset radius and ball numbers. Center at L/4,0, aim actual apex, power9.75, spin0. No production changes or simulation rejection.',coordinateContract='SceneKit XZ metres Y up; radial from nominal centroid, tangent=radial rotated +90deg. Canonical pooled direction (x,z). Region rotates pooled direction before inward fold x=-abs(x). Full-circle angle rotations and z reflection preserve theoretical one-ball inward marginal; region dependence differs. P/M signed degrees BEFORE fold, not constant final pairwise angular separation.',groups={'core':[4,7,8],'front':[0,1,2,3,4,5],'sidePositive':[i for i,(r,c) in enumerate([(r,c) for r in range(5) for c in range(r+1)]) if r/2-c>0],'sideNegative':[i for i,(r,c) in enumerate([(r,c) for r in range(5) for c in range(r+1)]) if r/2-c<0]},transforms='Core/front: selected group rotates +/-30 or60deg, complement unchanged. Side: +Z side rotates delta/2, -Z side rotates -delta/2, midline unchanged. Flip: reflect z canonical component for core/front selected group or -Z side, then inward fold for all.',primary='Unchanged mean dispersion, paired to production and original radial_contract; >=1.20 secondary.',selection='Rank fifteen candidates by discovery mean descending, name ascending for ties. Select two. No replacement after validation readout; report scratch and timing tradeoffs.',inference='Five predefined validation mean comparisons: contract-baseline; each selected-baseline; each selected-contract. 20000 paired rack bootstrap with Bonferroni family95. Separate five-comparison families for pass/scratch/wall/CPU; no across-metric global95 claim. Energy/order/clusters descriptive.',seedGenerator=202610261905,sourceEntrySHA256=sha(HERE/'main.swift'))
for stage,rr in [('discovery',racks[:300]),('validation',racks[300:])]:
 (OUT/stage).mkdir(exist_ok=True);p=dict(base,racks=rr,stage=stage)
 if stage=='validation':p['variantsPending']=p.pop('variants');write(OUT/'validation-plan.json',p)
 else:write(OUT/stage/'protocol.json',p)
write(OUT/'plan-binding.json',{'discoveryProtocolSHA256':sha(OUT/'discovery/protocol.json'),'validationPlanSHA256':sha(OUT/'validation-plan.json'),'entrySHA256':sha(HERE/'main.swift')})
print('Frozen: 300x17 discovery +1500x4 validation=11100 formal simulations; 1800 disjoint new seeds.')
