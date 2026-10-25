"""Compile unchanged geometry predicates with portable Float vector/JSON adapters.
No simulator or physics stepping is needed for this geometry-only query.
"""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/two-ball-middle-geometry-comfort-20261025';FROZEN=ROOT/'research/two-ball-strike-full-20261024/native-source'
def block(s,start):
 i=s.index(start);a=s.index('{',i);depth=1;j=a+1
 while depth:
  depth+=(s[j]=='{')-(s[j]=='}');j+=1
 return s[i:j]
grid=(ROOT/'QiuJiTests/TrainingGridInventoryTests.swift').read_text()
geom=block(grid,'private struct GridGeometry')
geom=geom.replace('private struct GridGeometry','struct GridGeometry').replace('let table = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)','let table: TableGeometry').replace('let radius = Double(BallPhysics.radius)','let radius: Double')
geom=geom.replace(block(geom,'func validPosition'), '')
table=(FROZEN/'TableGeometry.swift').read_text();pocket=block(table,'struct Pocket {');angular=block(table,'func isAngleInRange')
root=block((FROZEN/'EngineNumerics.swift').read_text(),'static func smallestPositiveRoot')
adapter='''import Foundation
struct SCNVector3 {var x:Float;var y:Float;var z:Float;init(_ x:Float,_ y:Float,_ z:Float){self.x=x;self.y=y;self.z=z}}
let SCNVector3Zero=SCNVector3(0,0,0)
struct LinearCushionSegment {let start:SCNVector3;let end:SCNVector3}
struct CircularCushionSegment {let center:SCNVector3;let radius:Float;let startAngle:Float;let endAngle:Float
ANGULAR
}
struct TableGeometry {let pockets:[Pocket];let linearCushions:[LinearCushionSegment];let circularCushions:[CircularCushionSegment]}
enum TablePhysics {static var innerLength:Float=0;static var innerWidth:Float=0}
enum SceneTrainingRailGeometry {static let contactRoundoff:Float=4*Float.ulpOfOne}
enum EngineNumerics {ROOTFUNC}
'''.replace('ANGULAR',angular).replace('ROOTFUNC',root)
main='''
func json(_ p:String)throws->Any {try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:p)))}
let g=try json(CommandLine.arguments[1]) as! [String:Any]
func v(_ x:Any)->SCNVector3 {let p=x as! [String:Double];return SCNVector3(Float(p["x"]!),0,Float(p["z"]!))}
TablePhysics.innerLength=Float(g["length"] as! Double);TablePhysics.innerWidth=Float(g["width"] as! Double)
let pockets=(g["pockets"] as! [[String:Any]]).enumerated().map {i,p in Pocket(id:"pocket_\\(i)",center:v(p["center"]!),radius:Float(p["radius"] as! Double),isCorner:i<4,captureLip:(p["lip"] as! [[String:Double]]).map {SIMD2($0["x"]!,$0["z"]!)})}
let lines=(g["lines"] as! [[String:Any]]).map {LinearCushionSegment(start:v($0["start"]!),end:v($0["end"]!))}
let arcs=(g["arcs"] as! [[String:Any]]).map {CircularCushionSegment(center:v($0["center"]!),radius:Float($0["radius"] as! Double),startAngle:Float($0["start"] as! Double),endAngle:Float($0["end"] as! Double))}
let geometry=GridGeometry(table:TableGeometry(pockets:pockets,linearCushions:lines,circularCushions:arcs),radius:g["radius"] as! Double)
struct Input:Decodable {let key:String;let object:[Double];let pocket:Int}
struct Proof:Encodable {let key:String;let object:[Double];let pocket:Int;let aim:[Double];let direction:[Double];let passed:Bool;let captureDistance:Double?;let solidDistance:Double;let otherPocketDistance:Double}
var results:[Proof]=[]
for row in try JSONDecoder().decode([Input].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))) {
 let b=row.object,p=row.pocket,origin=SIMD2(b[0],b[1]),aim=geometry.generationAnchor(p),direction=geometry.unit(aim-origin)
 let extent=2*hypot(Double(TablePhysics.innerLength),Double(TablePhysics.innerWidth))
 let entry=geometry.table.pockets[p].entryTime(position:geometry.scene(origin),velocity:geometry.scene(direction),acceleration:SCNVector3Zero,maxTime:Float(extent))
 let bound=entry.map {Double($0)+0.01} ?? extent
 let solid=geometry.solidLimit(origin,direction,maximum:bound),other=geometry.captureLimit(origin,direction,maximum:bound,excluding:p)
 results.append(Proof(key:row.key,object:b,pocket:p,aim:[aim.x,aim.y],direction:[direction.x,direction.y],passed:geometry.cleanObjectPath(origin,aim,pocket:p),captureDistance:entry.map {Double($0)},solidDistance:solid,otherPocketDistance:other))
}
try JSONEncoder().encode(results).write(to:URL(fileURLWithPath:CommandLine.arguments[3]),options:.atomic)
print("checked \\(results.count) B/pocket rays")
'''
(HERE/'main.swift').write_text(adapter+pocket+'\n'+geom+'\n'+main)
sources=[FROZEN/'QuarticSolver.swift',HERE/'main.swift']
cmd=['xcrun','swiftc','-O',*map(str,sources),'-o',str(HERE/'geometry-check')]
r=subprocess.run(cmd,capture_output=True,text=True);(OUT/'build.log').write_text(r.stdout+r.stderr);r.check_returncode()
allSources=[*sources,ROOT/'QiuJiTests/TrainingGridInventoryTests.swift',FROZEN/'TableGeometry.swift',FROZEN/'EngineNumerics.swift',HERE/'build.py']
(OUT/'geometry-source.json').write_text(json.dumps(dict(command=cmd,sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in allSources},adapters='Float SCNVector3 storage only; geometry from native export; exact Pocket/angle/root and GridGeometry query bodies; validPosition unused and omitted'),indent=2))
print('compiled geometry-only checker')
