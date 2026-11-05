import Foundation
@main struct Check {
 static func main() throws {
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  let index=try JSONDecoder().decode(DefenseBankIndex.self,from:Data(contentsOf:root.appendingPathComponent("index.json")))
  var questions=0,references=0
  for shard in index.shards {
   let raw=try Data(contentsOf:root.appendingPathComponent(shard.name+".jsonl"))
   for line in raw.split(separator:10) {
    let q=try JSONDecoder().decode(DefenseBankQuestion.self,from:Data(line))
    precondition(q.cue.count==2 && q.balls.allSatisfy{$0.position.count==2})
    precondition(!q.references.isEmpty)
    for r in q.references {precondition(r.parameters.direction.count==2 && (r.effect.fullDirectBlock ? r.effect.score==100:r.effect.score==nil))}
    questions+=1;references+=q.references.count
   }
  }
  precondition(questions==index.counts.questions && references==index.counts.references)
  print("PASS Swift DTO decode: \(questions) questions, \(references) references")
 }
}
