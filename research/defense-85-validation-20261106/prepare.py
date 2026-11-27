from pathlib import Path
import json,shutil,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
BASE=ROOT/'output/defense-maxscore-gallery-20261106';OLD=ROOT/'research/defense-threshold-comparison-20261105'
OUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((BASE/'source-manifest.json').read_text());assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in manifest.items()),'Production source changed: rescan before reuse'
selected=[c for c in json.loads((BASE/'selected.json').read_text()) if c['bin']==85];assert len(selected)==10
cases=[]
for c in selected:
 label=c['displayID'];source=BASE/c['dataDirectory'];dest=OUT/label;dest.mkdir(exist_ok=True)
 for name in ['scan-adaptive.json','geometry.json','maximum.json','peak-probes.json','windows-base.json']:
  shutil.copy2(source/name,dest/name)
 cases.append({**c,'label':label,'sourceLabel':c['label'],'scanSHA256':hashlib.sha256((source/'scan-adaptive.json').read_bytes()).hexdigest()})
cfg={'cases':cases,'primaryGoal':80,'diagnosticThresholds':[75,80,85],'mapSeedThreshold':75,'minimumCueTargetDistanceMeters':.3,'ownRule':'positive known clear window, not below initial; provisional, not an absolute comfort definition','bankSHA256':json.loads((BASE/'scenario.json').read_text())['bankSHA256']}
for p in [HERE/'scenario.json',OUT/'scenario.json']:p.write_text(json.dumps(cfg,ensure_ascii=False,indent=2))
for name in ['OwnPotential.swift','DefenseRegionSolver.swift']:
 shutil.copy2(OLD/name,HERE/name)
s=(OLD/'run.py').read_text().replace('defense-threshold-comparison-20261105',HERE.name).replace("['Scan.swift','OwnPotential.swift','DefenseRegionSolver.swift']","['OwnPotential.swift','DefenseRegionSolver.swift']")
(HERE/'run.py').write_text(s)
s=(HERE/'DefenseRegionSolver.swift').read_text()
# Keep full connected components: tile seams must not masquerade as narrow region edges.
s=s.replace('let tx=(start%nx)/21,tz=(start/nx)/21,id=blocks.count','let id=blocks.count')
s=s.replace(',xx/21==tx,zz/21==tz','')
s=s.replace('// Connected regions split into ~35 cm tiles, so a large region has multiple goals.','// Full connected score region; width is not limited by artificial tile seams.')
# Raster cells crossing the exclusion circle cannot seed an excluded landing.
s=s.replace('for start in scores.indices where', '''let target=scan["target"] as! [Double]
        for k in scores.indices {
            let x = -hx+(Double(k%nx)+0.5)*dx,z = -hz+(Double(k/nx)+0.5)*dz
            if hypot(x-target[0],z-target[1])<0.30 {scores[k] = -1}
        }
        for start in scores.indices where''')
s=s.replace('"cells":b.cells,','"cells":b.cells,"sampledCoreRadius":-Double(b.region.signedDistanceMeters(fromScene:SCNVector3(Float(b.centre.x),BTTablePhysics.surfaceY+BallPhysics.radius,Float(b.centre.y)),surfaceY:BTTablePhysics.surfaceY)),')
# Apply the same 30cm restriction to actual and perturbed terminal states.
s=s.replace('if !p.hasFinalTableState {return "incomplete"}', '''if !p.hasFinalTableState {return "incomplete"}
        guard let end=p.finalPositions[cueKey],defenseDistance(end,enemy)>=0.30 else{return "cue-opponent-under-30cm"}''')
s=s.replace('total>=70','total>=75').replace('final-below-70','final-below-75').replace('e.score!>=70','e.score!>=75').replace('score>=70','score>=75').replace('stableAt($0,70)','stableAt($0,75)')
s=s.replace('[70.0,80,90]','[75.0,80,85]').replace('stableAt($0,90)','stableAt($0,80)')
s=s.replace('// Expand only while the highest diagnostic threshold lacks a robust solution.','// Expand only while the primary 80-point goal lacks a four-probe solution.')
s=s.replace('if a.own.bestClearDegrees != b.own.bestClearDegrees {return (a.own.bestClearDegrees ?? 0)>(b.own.bestClearDegrees ?? 0)}','''let ac=a.prediction.events.filter{if case .ballCushion=$0.kind{return true};return false}.count
        let bc=b.prediction.events.filter{if case .ballCushion=$0.kind{return true};return false}.count
        if ac != bc {return ac<bc}''',1)
start=s.index('            let strong=group.sorted')
end=s.index('        }}',start)
s=s[:start]+'''            for c in easy where !shortlist.contains(where:{$0.stroke.key==c.stroke.key}) {shortlist.append(c)}
'''+s[end:]
start=s.index('            // Show lowest effort')
end=s.index('        }\n        thresholdResults',start)
s=s[:start]+'''            // One simple representative per pathway/threshold, no maximum-window bonus.
            for c in group.sorted(by:qualityLess).prefix(1) where !selected.contains(where:{$0.stroke.key==c.stroke.key}) {selected.append(c)}
'''+s[end:]
s=s.replace('// Bounded validation shortlist: easy execution and strong own potential,','// Bounded validation shortlist: simple execution with preserved own potential,')
(HERE/'DefenseRegionSolver.swift').write_text(s)
print('Prepared',len(cases),'original 85-bin cases; unchanged current scoring source verified')
