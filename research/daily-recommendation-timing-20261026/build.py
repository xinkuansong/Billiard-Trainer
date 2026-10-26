from pathlib import Path
import re,json,hashlib,subprocess
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=root/'output/daily-recommendation-timing-20261026'
p=root/'QiuJi/Core/Scene/AngleSceneCalculator.swift';s=p.read_text()
def block(pattern):
 m=re.search(pattern,s);assert m,pattern
 start=m.start();a=s.index('{',m.end()-1);n=1;i=a+1
 while n:
  if s[i]=='{':n+=1
  elif s[i]=='}':n-=1
  i+=1
 return s[start:i]
names=['ghostBallPosition','pocketCenters','pocketJaws','closestPointOnSegment','segmentDistance','pointSegmentDistance','segmentsIntersect','cutAngle','isPathBlocked','horizontalDistance','dailyPocketCandidate']
funcs={n:block(r'(?:private )?static func '+n+r'\(') for n in names}
parts=['import Foundation\nstruct SCNVector3 { var x,y,z: Float; init(_ x:Float,_ y:Float,_ z:Float){self.x=x;self.y=y;self.z=z} }\nenum AngleSceneCalculator {\nstatic let innerLength:Float=2.54, innerWidth:Float=1.27, ballRadius:Float=0.028575\nstatic let maxCutAngle:Double=89\nstatic func pocketPositions(surfaceY:Float)->[SCNVector3]{pocketCenters(surfaceY:surfaceY,c:0.042,m:0.6759647130966187-innerWidth/2)}']
parts += [block(r'private struct Vector2 \{'),block(r'private struct Segment2D \{'),block(r'struct DailyPocketCandidate \{')]
a=s.index('    private static let mainCushionSegments:');b=s.index('    ]',a)+5;parts+=[s[a:b]]
parts+=list(funcs.values())
f=funcs['dailyPocketCandidate'].replace('func dailyPocketCandidate(','func proposedCandidate(')
f=f.replace('        let nominal =', '''        if pocketIndex >= 4 {
            let side:Double = pocketIndex == 4 ? -1 : 1
            if Double(innerWidth)/2-side*Double(target.z) < 0.009263577585997284+0.29983165331981754*abs(Double(target.x)) {return nil}
        }
        var best:DailyPocketCandidate?; var bestScore = -Double.infinity
        let nominal =''',1)
f=f.replace('            return DailyPocketCandidate(', '            let candidate = DailyPocketCandidate(')
f=f.replace('targetPocketDistance: Double(horizontalDistance(target, nominal)))','''targetPocketDistance: Double(horizontalDistance(target, aim)))
            let score = comfort(cue:cue,target:target,aim:aim,angle:angle)
            if score > bestScore { best=candidate; bestScore=score }''')
f=f.replace('        return nil\n    }','        return best\n    }')
parts+=[f,'}\n', (here/'driver.swift').read_text()]
(out/'main.swift').write_text('\n'.join(parts))
manifest={'source':str(p.relative_to(root)),'sourceSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'extractedFunctions':names,'adaptations':['SCNVector3 represented by same three Float fields; no SceneKit renderer','measured middle center constant from native metadata','new region gate, all existing aims evaluated with W; no candidate cache','D/E/A formula port with explicit aim; not shipping integration'],'build':['xcrun','swiftc','-O',str(out/'main.swift'),'-o',str(out/'bench')]}
(out/'source-binding.json').write_text(json.dumps(manifest,indent=2)+'\n')
r=subprocess.run(manifest['build'],capture_output=True,text=True);(out/'build.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
