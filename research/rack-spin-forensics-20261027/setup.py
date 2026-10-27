from pathlib import Path
D=Path(__file__).resolve().parent;ROOT=D.parents[1];A=ROOT/'research/rack-spin-tail-20261026'
s=(ROOT/'QiuJi/Core/Physics/EventDrivenEngine.swift').read_text()
s=s.replace('        EngineNumerics.makeBallBallKiss(stateA: &stateA, stateB: &stateB)','        let beforeKissA=stateA,beforeKissB=stateB\n        EngineNumerics.makeBallBallKiss(stateA: &stateA, stateB: &stateB)',1)
s=s.replace('        let result = CollisionResolver.resolveBallBallPure(','        let preA=stateA,preB=stateB\n        let result = CollisionResolver.resolveBallBallPure(',1)
s=s.replace('        balls[ballA] = stateA\n        balls[ballB] = stateB','''        ForensicTrace.rows.append(["kind":"ball","t":Double(currentTime),"beforeKissA":ForensicTrace.state(beforeKissA),"beforeKissB":ForensicTrace.state(beforeKissB),"preA":ForensicTrace.state(preA),"preB":ForensicTrace.state(preB),"postA":ForensicTrace.state(stateA),"postB":ForensicTrace.state(stateB)])
        balls[ballA] = stateA
        balls[ballB] = stateB''',1)
s=s.replace('        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)','        let preState=state\n        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)',1)
s=s.replace('        balls[ball] = state\n        return true\n    }\n    \n    /// Resolve state transition','''        ForensicTrace.rows.append(["kind":"cushion","t":Double(currentTime),"index":cushionIndex,"normal":ForensicTrace.v(normal),"pre":ForensicTrace.state(preState),"post":ForensicTrace.state(state)])
        balls[ball] = state
        return true
    }
    
    /// Resolve state transition''',1)
s=s.replace('        state.state = toState','        let preState=state\n        state.state = toState',1)
s=s.replace('        balls[ball] = state\n    }\n    \n    /// Resolve pocket event','        ForensicTrace.rows.append(["kind":"transition","t":Double(currentTime),"pre":ForensicTrace.state(preState),"post":ForensicTrace.state(state)])\n        balls[ball] = state\n    }\n    \n    /// Resolve pocket event',1)
s+='''\n// Read-only research observer, never read by physics decisions.
enum ForensicTrace {
 static var rows:[[String:Any]]=[]
 static func v(_ x:SCNVector3)->[Double]{[Double(x.x),Double(x.y),Double(x.z)]}
 static func state(_ b:BallState)->[String:Any]{["name":b.name,"p":v(b.position),"v":v(b.velocity),"w":v(b.angularVelocity),"state":b.state.rawValue]}
}
'''
assert s.count('ForensicTrace.rows.append')==3
(D/'EventDrivenEngine.swift').write_text(s)
s=(A/'main.swift').read_text().replace('                let result = BreakSimulator.breakShot','                ForensicTrace.rows=[]\n                let result = BreakSimulator.breakShot').replace('                row["duration"] = Double(result.recorder.duration)','                row["duration"] = Double(result.recorder.duration)\n                row["eventTrace"] = ForensicTrace.rows')
(D/'main.swift').write_text(s)
s=(A/'build.py').read_text().replace('output/rack-spin-tail-20261026','output/rack-spin-forensics-20261027')
s=s.replace("replacements=['RackLayout.swift','BreakFlowRunner.swift']","replacements=['RackLayout.swift','BreakFlowRunner.swift','EventDrivenEngine.swift']")
s=s.replace('q if old.name in replacements else old',"(HERE/old.name if old.name=='EventDrivenEngine.swift' else q) if old.name in replacements else old")
s=s.replace("'BreakFlowRunner.o']","'BreakFlowRunner.o','EventDrivenEngine.o']")
(D/'build.py').write_text(s)
s=(A/'run.py').read_text();a=s.index('    for file in sorted');b=s.index('   assert n==100',a)
s=s[:a]+'''    old=json.loads((OUT/'frames.json').read_text())
    new=w.run(old['input'])
    for field in ['rack','status','termination','pocketed','board','contacts','duration','frames','initialCueVelocity']:
     assert new[field]==old[field],field
    assert new['status']=='settled';n+=1;out.write(json.dumps(new)+'\\n')
'''+s[b:]
s=s.replace('assert n==100','assert n==1');(D/'run.py').write_text(s)
