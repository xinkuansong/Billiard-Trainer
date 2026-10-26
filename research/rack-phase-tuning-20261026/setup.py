from pathlib import Path
import json,hashlib,random,datetime,subprocess
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name;PREV=ROOT/'research/rack-correlated-pattern-20261026'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,indent=2,ensure_ascii=False))
assert not (OUT/'discovery/protocol.json').exists()
# Change only independent research entry. Positive phase is local tangential +90deg.
s=(PREV/'confirmation/main.swift').read_text()
s=s.replace('["contract", "independent"].contains(parts[1])','(["contract", "independent", "pure"].contains(parts[1]) || parts[1].hasPrefix("band"))')
needle='                    let (cs,sn,reflect) = rotations[i]'
insert='''                    if family == "radial" && (parts[1] == "pure" || parts[1].hasPrefix("band")) {
                        let originalPhase = atan2(abs(z), abs(x))
                        let band = parts[1] == "pure" ? 0 : Int(parts[1].dropFirst(4))!
                        precondition((0...5).contains(band))
                        let angle = parts[1] == "pure" ? 0 : (Double(band)*15 + originalPhase/(Double.pi/2)*15)*Double.pi/180
                        let sign = z >= 0 ? 1.0 : -1.0
                        x = -cos(angle); z = sign*sin(angle); norm = 1
                    }
'''
assert needle in s;s=s.replace(needle,insert+needle);(HERE/'main.swift').write_text(s)
b=(PREV/'build.py').read_text().replace('rack-correlated-pattern-20261026','rack-phase-tuning-20261026')
b=b.replace("entry = HERE / ('confirmation/main.swift' if os.environ.get('RACK_STAGE')=='confirmation' else 'main.swift')","entry = HERE / 'main.swift'")
# Exact exception for an independently changed UI authorization wrapper; not on direct BreakSimulator path.
frozen=ROOT/'research/two-ball-strike-full-20261024/native-source/BreakFlowRunner.swift';current=ROOT/'QiuJi/Core/Rack/BreakFlowRunner.swift'
old=frozen.read_text();new=current.read_text()
new=new.replace('    /// Called only after physical strike eligibility is established, before any\n    /// simulation or shot state mutates. Other break consumers need no gate.\n    var authorizeStrike: (() -> Bool)?\n\n','').replace('        guard authorizeStrike?() ?? true else { return }\n','')
assert old==new,'Unreviewed wrapper drift'
exc={'path':str(current.relative_to(ROOT)),'currentSHA256':sha(current),'frozenSHA256':sha(frozen),'reason':'Only adds optional authorizeStrike UI gate in BreakFlowRunner.breakNow. Research invokes BreakSimulator.breakShot directly and never instantiates BreakFlowRunner; frozen wrapper unused. Exact additions removed and remaining source compared byte-for-byte.'}
write(OUT/'source-exception.json',exc)
b=b.replace("assert sha(p) == sha(q), f'Production drift: {q}'",'''if sha(p) != sha(q):
                exception = json.loads((OUT.parent/'source-exception.json').read_text())
                assert str(q.relative_to(ROOT)) == exception['path'] and sha(p) == exception['frozenSHA256'] and sha(q) == exception['currentSHA256'], f'Production drift: {q}' ''')
b=b.replace("method='unchanged production physics objects; new research entry only'","method='unchanged physics objects and direct simulator path; exact unused UI wrapper exception documented', wrapperException=json.loads((OUT.parent/'source-exception.json').read_text())")
(HERE/'build.py').write_text(b)
r=(PREV/'run.py').read_text();r=r.replace("write('generation.json',dict(count=sum(c['count'] for c in closures),productionDrift=drift));assert not drift","write('generation.json',dict(count=sum(c['count'] for c in closures),productionDrift=drift));assert not drift\n  write('progress.json',dict(done=sum(c['count'] for c in closures),total=len(jobs)))")
(HERE/'run.py').write_text(r)
# All historical protocols checked; raw initial studies seeds supplement protocol records.
used=set()
for folder in ROOT.glob('output/rack-*'):
 for p in folder.rglob('*protocol*.json'):
  try:
   obj=json.loads(p.read_text())
   for r in obj.get('racks',[]):used.add(str(r['seed']))
  except (ValueError,KeyError,AttributeError):pass
for p in (ROOT/'output/rack-center-mechanism-20261026').glob('*.json'):
 try:
  obj=json.loads(p.read_text())
  if isinstance(obj,list):
   for r in obj:
    if isinstance(r,dict) and 'input' in r and 'seed' in r['input']:used.add(str(r['input']['seed']))
 except ValueError:pass
rng=random.Random(202610261830);racks=[]
for i in range(1800):
 seed=str(rng.getrandbits(64));assert seed not in used;used.add(seed);racks.append(dict(rackID=7700+i,seed=seed))
base=dict(createdUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),workers=4,conditions='15 balls; production gap 0.20mm and original disk jitter radius <=0.09mm. Preserve each realized radius and numbers. Center aim actual apex, strength9.75, zero spin. Research direction transform only; no score or production changes.',coordinateContract='SceneKit XZ metres, Y up; nominal rack center is centroid. u_i=-cos(theta)*radial_i + sign*sin(theta)*tangent_i. theta angle from directly inward; sign from pooled original canonical offsets.',primary='Mean unchanged dispersion, paired to both baseline and previous radial_contract. >=1.20 secondary.',selection='Seven candidates ranked by discovery mean; take top two regardless of scratch. Scratch and runtime explicitly reported; no claim of an overall improvement when tradeoffs unresolved.',inference='Validation 5 mean contrasts: contract-baseline, each selected-baseline, each selected-contract. 20000 paired rack bootstrap, Bonferroni family95. Separate 5-test families for scratch, pass, wall time; no global family95 claim across metrics. Exploratory sign/cluster diagnostics labeled.',variants=['baseline','radial_contract']+['radial_pure']+[f'radial_band{i}' for i in range(6)],seedGenerator=202610261830,sourceEntrySHA256=sha(HERE/'main.swift'))
for stage,rr in [('discovery',racks[:300]),('validation',racks[300:])]:
 (OUT/stage).mkdir(exist_ok=True)
 p=dict(base,racks=rr,stage=stage)
 if stage=='validation':p['variantsPending']=p.pop('variants');write(OUT/'validation-plan.json',p)
 else:write(OUT/stage/'protocol.json',p)
write(OUT/'plan-binding.json',{'discoveryProtocolSHA256':sha(OUT/'discovery/protocol.json'),'validationPlanSHA256':sha(OUT/'validation-plan.json'),'entrySHA256':sha(HERE/'main.swift'),'historicalPlusNewSeedCount':len(used)})
print('Protocols frozen: 300 x 9 discovery; 1500 x 4 validation; 8700 formal simulations.')
