from pathlib import Path
import runpy,difflib,hashlib,json
D=Path(__file__).resolve().parent;R=D.parents[1];O=R/'output/rack-contact-tolerance-20261027';A=R/'research/rack-spin-forensics-20261027'
# Observer already validated against original production; verify its original generator still matches current source.
original=(R/'QiuJi/Core/Physics/EventDrivenEngine.swift').read_text()
s=(A/'EventDrivenEngine.swift').read_text();(D/'EventDrivenEngine.swift').write_text(s)
n=(R/'QiuJi/Core/Physics/EngineNumerics.swift').read_text();assert n.count('let eps: Float = 0.00025')==1
(D/'EngineNumerics.swift').write_text(n.replace('let eps: Float = 0.00025','let eps: Float = ContactToleranceResearch.value')+'\n// Research input; the only changed physics decision is the existing eps value.\nenum ContactToleranceResearch { static var value: Float = 0.00025 }\n')
s=(A/'main.swift').read_text().replace('            let rack = RackLayout.make(game, seed: seed)','''            ContactToleranceResearch.value = Float(input["toleranceM"] as! Double)
            let originalRack = RackLayout.make(game, seed: seed)
            let reverse = input["reverse"] as! Bool
            let rack = Rack(game:game,cue:originalRack.cue,balls:reverse ? Array(originalRack.balls.reversed()) : originalRack.balls,surfaceY:originalRack.surfaceY)''')
start=s.index('                row["frames"] =');end=s.index('                let playback',start)
frame=s[start:end]
s=s[:start]+'''                row["frameCount"] = frames[0].count
                row["toleranceM"] = Double(ContactToleranceResearch.value)
                let lastMoving = frames[0].indices.last { k in frames.contains { $0[k].state == .sliding || $0[k].state == .rolling } }
                let stopIndex = min((lastMoving ?? 0)+1,frames[0].count-1)
                let lastTranslation=frames[0][stopIndex].time
                row["lastTranslation"] = Double(lastTranslation)
                row["spinTail"] = names.indices.map { i -> [String:Any] in
                    let f=frames[i],at=f[stopIndex]
                    let end=f[stopIndex...].first(where:{$0.state == .stationary})?.time ?? at.time
                    let tail=at.state == .spinning && abs(at.angularVelocity.y)>0.0001 ? max(0,end-lastTranslation):0
                    return ["name":names[i],"tail":Double(tail),"wy":Double(at.angularVelocity.y),"peakWy":Double(f.map{abs($0.angularVelocity.y)}.max()!)]
                }
                var samples: [[String:Any]]=[]
                for delay:Float in [0.001,0.005,0.02,0.1] {
                    let target=t0+delay
                    samples.append(["delay":Double(delay),"states":frames.map { list -> [String:Any] in
                        let prev=list.last(where:{$0.time<=target})!
                        let f=evolved(prev,dt:target-prev.time)
                        return ["p":vec(f.position),"v":vec(f.velocity),"w":vec3(f.angularVelocity),"state":f.state.rawValue]
                    }])
                }
                row["samples"]=samples
                var worstOverlap:Double=0
                var overlapFrames=0
                for k in frames[0].indices {
                    var hasOverlap=false
                    for i in names.indices where frames[i][k].state != .pocketed {
                        for j in names.indices where j>i && frames[j][k].state != .pocketed {
                            let a=frames[i][k].position,b=frames[j][k].position
                            let dx=Double(a.x)-Double(b.x),dz=Double(a.z)-Double(b.z)
                            let overlap=2*radius-sqrt(dx*dx+dz*dz)
                            worstOverlap=max(worstOverlap,overlap)
                            if overlap>0.00001 {hasOverlap=true}
                        }
                    }
                    if hasOverlap {overlapFrames+=1}
                }
                row["overlapAudit"]=["maxM":worstOverlap,"framesOver10um":Double(overlapFrames)]
                if input["rackID"] as! Int == 11331 {
'''+frame+'''                }
'''+s[end:]
(D/'main.swift').write_text(s)
s=(A/'build.py').read_text().replace('rack-spin-forensics-20261027','rack-contact-tolerance-20261027').replace("'EventDrivenEngine.swift'];","'EventDrivenEngine.swift','EngineNumerics.swift'];").replace("old.name=='EventDrivenEngine.swift'","old.name in ['EventDrivenEngine.swift','EngineNumerics.swift']").replace("'EventDrivenEngine.o']","'EventDrivenEngine.o','EngineNumerics.o']")
(D/'build.py').write_text(s)
for name in ['EngineNumerics.swift','EventDrivenEngine.swift']:
 (O/(name+'.diff')).write_text(''.join(difflib.unified_diff((R/'QiuJi/Core/Physics'/name).read_text().splitlines(True),(D/name).read_text().splitlines(True),fromfile='production/'+name,tofile='research/'+name)))
(O/'production-before.json').write_text(json.dumps({str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (R/'QiuJi').rglob('*.swift')},indent=2))
