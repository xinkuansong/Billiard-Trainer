from pathlib import Path
import shutil
D=Path(__file__).resolve().parent;ROOT=D.parents[1];A=ROOT/'research/rack-spin-experiments-20261026'
for n in ['EventDrivenEngine.swift','BreakSimulator.swift','EngineNumerics.swift','PhysicsEvent.swift','CollisionDetector.swift','CollisionResolver.swift','AnalyticalMotion.swift','Han2005CushionModel.swift','main.swift','build.py','mathavan-reference.json']:
 shutil.copy2(A/n,D/n)
s=(ROOT/'QiuJi/Core/Rack/RackLayout.swift').read_text().replace('enum RackLayout {','enum RackLayout {\n static var researchPattern="current"')
s=s.replace('        let count = Double(slots.count)','        if researchPattern == "independent" {return balls}\n        let count = Double(slots.count)',1)
s=s.replace('            let angle = -60.0 * weight * Double.pi / 180','''            let phase:Double = researchPattern == "inward" ? 0 : (researchPattern == "sideP60" ? 60 : (researchPattern == "sideM120" ? -120 : -60))
            let angle = phase * weight * Double.pi / 180''')
s=s.replace('            x = -abs(rotatedX)','            x = researchPattern == "outward" ? abs(rotatedX) : -abs(rotatedX)')
(D/'RackLayout.swift').write_text(s)
p=D/'main.swift';s=p.read_text().replace('            let original = RackLayout.make','            RackLayout.researchPattern=input["pattern"] as! String\n            let original = RackLayout.make');p.write_text(s)
p=D/'build.py';s=p.read_text().replace("OUT=ROOT/'output/rack-spin-experiments-20261026'","OUT=ROOT/'output/rack-spin-dispersion-20261026'")
s=s.replace("old.name in ['EventDrivenEngine.swift'","old.name in ['RackLayout.swift','EventDrivenEngine.swift'");p.write_text(s)
s=(A/'run.py').read_text();start=s.index('variants=[');end=s.index('def main(uid):',start)
s=s[:start]+'''variants=[(pattern+'__'+str(alpha),2,'han',.14,alpha) for pattern in ['current','independent','inward','sideP60','sideM120','outward'] for alpha in [10.9,22]]
'''+s[end:]
s=s.replace("ROOT/'output/rack-solver-repair-20261026'/phase/'raw.jsonl.gz'","ROOT/'output/rack-spin-experiments-20261026'/('sweep-r2' if phase=='pilot-r2' else 'holdout')/'raw.jsonl.gz'")
s=s.replace("r['input']['mode'] in [0,2]","r['input']['experiment'] in ['han14','han14_spin22']")
s=s.replace("r['input']['rackID'],r['input']['mode']","r['input']['rackID'],r['input']['experiment']")
s=s.replace("old=oldmap[rid,0]","old=oldmap[rid,'han14']")
s=s.replace("mode=mode,mirror=False","pattern=label.split('__')[0],mode=mode,mirror=False")
s=s.replace("if label in ['production','repair']:","if label.startswith('current__'):")
s=s.replace("prev=oldmap[rid,mode]","prev=oldmap[rid,'han14' if alpha==10.9 else 'han14_spin22']")
(D/'run.py').write_text(s)
