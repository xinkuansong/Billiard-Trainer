from pathlib import Path
import shutil,subprocess,json
from prepare import ROOT,OUT
check=OUT/'consumer-check';check.mkdir(exist_ok=True)
source=ROOT/'QiuJi/Features/DefensePractice'
(check/'Store.swift').write_text((source/'DefenseQuestionPreparer.swift').read_text().split('enum DefenseQuestionPreparer {')[0])
(check/'Kinds.swift').write_text((source/'DefensePracticeRecord.swift').read_text().split('struct DefenseConfiguration:')[0])
shutil.copy2(source/'DefenseBankModels.swift',check/'Models.swift')
for name in ['defense-practice-bank.json.gz','defense-free-bank.json.gz']:shutil.copy2(ROOT/'QiuJi/Resources'/name,check/name)
(check/'main.swift').write_text(r'''import Foundation
let trajectory=try DefenseBankStore.load(.trajectory), free=try DefenseBankStore.load(.free)
precondition(trajectory.count==3984 && trajectory.flatMap(\.references).count==9846 && free.count==58470)
func gridKey(_ q:DefenseBankQuestion)->String {
 func cell(_ p:[Double])->String {"\(min(19,Int(floor((p[0]+1.27)/2.54*20)))):\(min(19,Int(floor((p[1]+0.635)/1.27*20))))"}
 return q.kind+"/"+cell(q.cue)+"/"+q.balls.sorted{$0.number<$1.number}.map{"\($0.number):"+cell($0.position)}.joined(separator:"/")
}
precondition(Set(free.map(gridKey)).count==free.count)
precondition(Set(trajectory.map(gridKey)).count==trajectory.count)
let f=Dictionary(uniqueKeysWithValues:free.map{($0.id,$0)})
for q in trajectory {
 let other=f[q.id]!;precondition(q.cue==other.cue && q.balls.map(\.position)==other.balls.map(\.position))
 for r in q.references {
  var hit=false,rail=false
  for e in r.expected.events {
   if e.kind=="ballBall" && Set(e.ballNumbers)==Set([0,q.ownBallNumber]) {precondition(!(hit && rail));hit=true}
   else if hit && e.kind=="cushion" && e.ballNumbers==[q.ownBallNumber],let index=e.railIndex,(0..<6).contains(index) {rail=true}
  }
 }
}
print("PASS production Store SHA, gunzip, DTO and isValid; trajectory 3984/9846, free 58470; unique 20x20 cells, same-orientation subset, no forbidden recontact")
''')
report=json.loads((OUT/'app-package/defense-practice-provenance.json').read_bytes())
p=check/'main.swift';p.write_text(p.read_text().replace('3984',str(report['referenceQuestions'])).replace('9846',str(report['references'])))
subprocess.run(['xcrun','swiftc',*[str(check/n) for n in ['Store.swift','Kinds.swift','Models.swift','main.swift']],'-o',str(check/'check')],check=True)
result=subprocess.run([str(check/'check')],check=True,capture_output=True,text=True)
(check/'result.txt').write_text(result.stdout);print(result.stdout)
