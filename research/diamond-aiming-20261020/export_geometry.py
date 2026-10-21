"""Export actual Swift geometry constructors without building or changing the app."""
from pathlib import Path
import hashlib, json, subprocess, tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def block(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

def main():
    names = ['QiuJi/Core/Physics/BTPhysicsConstants.swift',
             'QiuJi/Core/Physics/TableGeometry.swift',
             'QiuJi/Core/Physics/TableGeometry+QiuJi.swift',
             'QiuJi/Core/Scene/AngleSceneCalculator.swift']
    constants, geometry, factory, calculator = [(ROOT/p).read_text() for p in names]
    # iOS SCNVector3 stores Float; macOS SceneKit uses CGFloat. Preserve iOS arithmetic.
    source = 'import Foundation\nstruct SCNVector3 { var x:Float; var y:Float; var z:Float; init(_ x:Float,_ y:Float,_ z:Float) { self.x=x;self.y=y;self.z=z } }\n'
    source += 'enum ContactSoundEvent { enum Surface { case cushion, jaw, liner } }\n'
    source += 'func +(a:SCNVector3,b:SCNVector3)->SCNVector3 { SCNVector3(a.x+b.x,a.y+b.y,a.z+b.z) }\n'
    source += 'func *(a:SCNVector3,b:Float)->SCNVector3 { SCNVector3(a.x*b,a.y*b,a.z*b) }\n'
    for marker in ['enum BallPhysics', 'enum TablePhysics', 'enum SceneLayout']:
        source += block(constants, marker) + '\n'
    for marker in ['struct LinearCushionSegment', 'struct CircularCushionSegment',
                   'private struct CornerJawGeometry', 'private func buildCornerJawGeometries']:
        source += block(geometry, marker) + '\n'
    source += '''struct Pocket {
      let id:String; let center:SCNVector3; let radius:Float; let isCorner:Bool
      var captureLip:[SIMD2<Double>] = []
    }
    struct TableGeometry {
      var linearCushions:[LinearCushionSegment]
      var circularCushions:[CircularCushionSegment]
      var pockets:[Pocket]
    ''' + block(geometry, 'static func chineseEightBallCushions') + '\n}\n'
    source += factory.replace('import SceneKit', '')
    source += '''
    let g = TableGeometry.chineseEightBallQiuJi(surfaceY:0.8)
    func v(_ p:SCNVector3)->[Double] { [Double(p.x),Double(p.z)] }
    let data:[String:Any] = [
      "length_m":Double(TablePhysics.innerLength), "width_m":Double(TablePhysics.innerWidth),
      "diameter_m":Double(BallPhysics.diameter),
      "pockets":g.pockets.map { ["id":$0.id,"center":v($0.center),"radius":Double($0.radius),"lip":$0.captureLip.map{[$0.x,$0.y]}] as [String:Any] },
      "lines":g.linearCushions.map { ["start":v($0.start),"end":v($0.end)] },
      "arcs":g.circularCushions.map { ["center":v($0.center),"radius":Double($0.radius),"start":Double($0.startAngle),"end":Double($0.endAngle)] as [String:Any] }
    ]
    print(String(data:try JSONSerialization.data(withJSONObject:data,options:[.sortedKeys]),encoding:.utf8)!)
    '''
    with tempfile.TemporaryDirectory(prefix='diamond-geometry-') as temp:
        path = Path(temp)/'export.swift'
        path.write_text(source)
        result = subprocess.run(['swift', str(path)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr)
    data = json.loads(result.stdout)
    data['source_hashes'] = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in names}
    # The snapshot is evidence, not a replacement for the actual asset identity.
    proof = ROOT/'output/diamond-position-fix-20261019/optimized-r4/proof.json'
    data['sight_evidence'] = str(proof.relative_to(ROOT))
    data['sight_evidence_sha256'] = hashlib.sha256(proof.read_bytes()).hexdigest()
    data['asset_sha256'] = hashlib.sha256((ROOT/'QiuJi/Resources/ModelTrial20261010_TaiQiuZhuo.usdz').read_bytes()).hexdigest()
    sight_proof = json.loads(proof.read_text())
    assert sight_proof['candidate_sha256'] == data['asset_sha256'], 'Asset changed; remeasure sights'
    data['sights_m'] = [[p['after_m'][0], p['after_m'][2]] for p in sight_proof['dots']]
    data['coordinate_contract'] = 'grid x=(world X+L/2)/(L/8), y=(world Z+W/2)/(L/8); screen y down'
    (HERE/'geometry.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
    print(f"Exported {len(data['lines'])} lines, {len(data['arcs'])} arcs, {len(data['pockets'])} pockets")

if __name__ == '__main__':
    main()
