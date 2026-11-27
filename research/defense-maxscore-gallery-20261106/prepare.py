from pathlib import Path
import json,gzip,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
bank=ROOT/'QiuJi/Resources/defense-practice-bank.json.gz';data=json.loads(gzip.decompress(bank.read_bytes()))
unique={}
for q in sorted(data['questions'],key=lambda q:q['id']):
 if q['kind']!='two_black' or q['ownBallNumber']!=8 or q['opponentBallNumber']!=9:continue
 t=next(b['position'] for b in q['balls'] if b['number']==9);key=tuple(t)
 if key not in unique:unique[key]=q
cases=[{'label':f'M{i+1:04}','target':list(t),'question':q,'symmetryKey':':'.join(f'{abs(v):.5f}' for v in t)} for i,(t,q) in enumerate(sorted(unique.items()))]
config={'bins':[70,75,80,85,90,95],'halfWidth':2.5,'perBin':10,'minimumCueTargetDistanceMeters':.30,'gridStepMeters':.05,'refinementStepMeters':.02,'refinementScoreChange':12.0,'bankSHA256':hashlib.sha256(bank.read_bytes()).hexdigest(),'cases':cases}
(HERE/'scenario.json').write_text(json.dumps(config,ensure_ascii=False,indent=2))
old=ROOT/'research/defense-threshold-comparison-20261105'
s=(old/'run.py').read_text().replace('defense-threshold-comparison-20261105',HERE.name).replace("['Scan.swift','OwnPotential.swift','DefenseRegionSolver.swift']","['Scan.swift']")
(HERE/'run.py').write_text(s)
s=(old/'Scan.swift').read_text().replace('throws {\nlet targetInput','throws -> [String:Any] {\nlet targetInput',1)
s=s.replace('let targetInput = input["target"] as! [Double]','''let targetInput = input["target"] as! [Double]
let exclusion=input["minimumCueTargetDistanceMeters"] as! Double
let coarseOnly=input["coarseOnly"] as? Bool ?? false''')
s=s.replace('(p-target).length>=2*r+0.00001','(p-target).length>=max(exclusion,2*r+0.00001)')
s=s.replace('var marked=[Int:Set<String>]()','var marked=[Int:Set<String>]()')
s=s.replace('for (i,a) in coarse.enumerated() {','for (i,a) in coarse.enumerated() where !coarseOnly {',1)
s=s.replace('var fine=[Sample](),leaves=[Sample]()','''if !coarseOnly {
    for i in coarse.indices.sorted(by:{(coarse[$0].effect?.score ?? -1)>(coarse[$1].effect?.score ?? -1)}).prefix(24) {mark(i,"maximum-candidate")}
}
var fine=[Sample](),leaves=[Sample]()''')
s=s.replace('let measuredCoreSeconds=windowSeconds+scoringSeconds','''// Probe inside the eight best leaf cells at <=5mm, in addition to the map.
var peaks=[Sample]()
if !coarseOnly {
    for sample in leaves.filter({$0.effect != nil}).sorted(by:{$0.effect!.score! > $1.effect!.score!}).prefix(8) {
        let c=sample.cell,nx=Int(ceil((c.x1-c.x0)/0.005)),nz=Int(ceil((c.z1-c.z0)/0.005))
        for z in 0..<nz {for x in 0..<nx {
            let cell=Cell(x0:c.x0+(c.x1-c.x0)*Double(x)/Double(nx),z0:c.z0+(c.z1-c.z0)*Double(z)/Double(nz),x1:c.x0+(c.x1-c.x0)*Double(x+1)/Double(nx),z1:c.z0+(c.z1-c.z0)*Double(z+1)/Double(nz),ix:c.ix,iz:c.iz,level:2)
            peaks.append(try evaluate(cell))
        }}
    }
}
let eligible=(coarse+leaves+peaks).filter{$0.effect != nil}
let best=eligible.max(by:{$0.effect!.score! < $1.effect!.score!})!
let summary:[String:Any]=["maximum":best.effect!.score!,"maximumPoint":best.cell.centre.json,"maximumStatus":best.state,"maximumEffect":try object(best.effect!),"coarseMaximum":coarse.compactMap{$0.effect?.score}.max()!,"exclusionMeters":exclusion,"coarseOnly":coarseOnly,"evaluations":validCount]
try write(summary,"maximum.json")
if !coarseOnly {try write(try peaks.map{try $0.json},"peak-probes.json")}
let measuredCoreSeconds=windowSeconds+scoringSeconds''')
s=s.replace('if !issues.isEmpty {exit(2)}','if !issues.isEmpty {exit(2)}\nreturn summary')
(HERE/'Scan.swift').write_text(s)
print('Unique original target positions',len(cases))
