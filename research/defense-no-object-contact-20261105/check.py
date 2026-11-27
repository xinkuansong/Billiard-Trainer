from pathlib import Path
import subprocess,json,shutil,gzip,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-no-object-contact-20261105';check=OUT/'consumer-check';check.mkdir(exist_ok=True)
source=ROOT/'QiuJi/Features/DefensePractice'
(check/'Store.swift').write_text((source/'DefenseQuestionPreparer.swift').read_text().split('enum DefenseQuestionPreparer {')[0])
(check/'Kinds.swift').write_text((source/'DefensePracticeRecord.swift').read_text().split('struct DefenseConfiguration:')[0])
shutil.copy2(source/'DefenseBankModels.swift',check/'Models.swift')
for n in ['defense-practice-bank.json.gz','defense-free-bank.json.gz']:shutil.copy2(ROOT/'QiuJi/Resources'/n,check/n)
(check/'main.swift').write_text('''import Foundation
let trajectory=try DefenseBankStore.load(.trajectory),free=try DefenseBankStore.load(.free)
precondition(trajectory.count==3511 && trajectory.flatMap(\\.references).count==7928 && free.count==58470)
precondition(trajectory.flatMap(\\.references).allSatisfy{DefenseReferenceRoute.allows($0.expected.events)})
typealias Event=DefenseBankQuestion.Reference.Expected.Event
for ball in [0,1,8,9] {
 for index:Int? in [nil,-1,0,1,2,3,4,5,6,14,43,44,55,999] {
  var value:[String:Any]=["kind":"cushion","timeSeconds":1.0,"ballNumbers":[ball]]
  if let index {value["railIndex"]=index}
  let e=try JSONDecoder().decode(Event.self,from:JSONSerialization.data(withJSONObject:value))
  precondition(DefenseReferenceRoute.allows([e]) == (index.map{(0..<6).contains($0)} ?? false))
 }
}
for pair in [[1,8],[8,1],[8,9],[9,8],[1,9],[9,1],[0,1],[1,0],[0,8],[8,0],[0,9],[9,0]] {
 let value:[String:Any]=["kind":"ballBall","timeSeconds":1.0,"ballNumbers":pair]
 let e=try JSONDecoder().decode(Event.self,from:JSONSerialization.data(withJSONObject:value))
 precondition(DefenseReferenceRoute.allows([e]) == pair.contains(0))
}
for value:[String:Any] in [["kind":"ballBall","timeSeconds":0.1,"ballNumbers":[0,8]],["kind":"pocket","timeSeconds":1.0,"ballNumbers":[9],"pocketIndex":0]] {
 let e=try JSONDecoder().decode(Event.self,from:JSONSerialization.data(withJSONObject:value));precondition(DefenseReferenceRoute.allows([e]))
}
print("PASS production Store SHA/decompression/DTO; 3511 questions, 7928 references, free 58470; every reference main-rails-only and no object-object collisions; 12 ball-pair cases, 56 ball/index boundary cases and normal contact/pocket acceptance")
''')
subprocess.run(['xcrun','swiftc',*[str(check/n) for n in ['Store.swift','Kinds.swift','Models.swift','main.swift']],'-o',str(check/'check')],check=True)
r=subprocess.run([str(check/'check')],check=True,capture_output=True,text=True);(check/'result.txt').write_text(r.stdout);print(r.stdout)
report=json.loads((OUT/'report.json').read_text());assert hashlib.sha256((ROOT/'QiuJi/Resources/defense-free-bank.json.gz').read_bytes()).hexdigest()==report['freeSHA256']
old=json.loads(gzip.decompress((OUT/'before/defense-practice-bank.json.gz').read_bytes()));new=json.loads(gzip.decompress((ROOT/'QiuJi/Resources/defense-practice-bank.json.gz').read_bytes()))
# Independent reconstruct-the-subset check, including whole-question deletion.
expected=[]
for q in old['questions']:
 q=dict(q,references=[r for r in q['references'] if not any(e['kind']=='ballBall' and all(n != 0 for n in e['ballNumbers']) for e in r['expected']['events'])])
 if q['references']:expected.append(q)
assert expected==new['questions']
print('PASS exact subset and free resource unchanged')
