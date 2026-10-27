from pathlib import Path
import json,hashlib,difflib
R=Path.cwd();D=R/'research/rack-contact-repair-20261027';O=R/'output/rack-contact-repair-20261027';A=R/'research/rack-solver-repair-20261026';T=R/'research/rack-contact-tolerance-20261027'
for name in ['EngineNumerics.swift','CollisionDetector.swift','CollisionResolver.swift','PhysicsEvent.swift','BreakSimulator.swift']:(D/name).write_text((A/name).read_text())
p=D/'EngineNumerics.swift';s=p.read_text().replace('let eps: Float = 0.00025','let eps: Float = ContactToleranceResearch.value');s+='\nenum ContactToleranceResearch { static var value: Float = 0.00025 }\n';p.write_text(s)
s=(A/'EventDrivenEngine.swift').read_text()
# Reuse previous corrected algorithm, extend read-only coverage from 20ms to full shot.
s=s.replace('            InvarianceTrace.rejected.append(["t":Double(currentTime),"a":ballA,"b":ballB])','            InvarianceTrace.rejected.append(["t":Double(currentTime),"a":ballA,"b":ballB,"preA":ForensicTrace.state(stateA),"preB":ForensicTrace.state(stateB)])')
s=s.replace('        InvarianceTrace.pair("beforeKiss",a:stateA,b:stateB,now:currentTime)','        let beforeKissA=stateA,beforeKissB=stateB')
s=s.replace('        InvarianceTrace.pair("beforeImpulse",a:stateA,b:stateB,now:currentTime)','        let preA=stateA,preB=stateB')
s=s.replace('        InvarianceTrace.pair("afterImpulse",a:stateA,b:stateB,now:currentTime)','        ForensicTrace.rows.append(["kind":"ball","t":Double(currentTime),"beforeKissA":ForensicTrace.state(beforeKissA),"beforeKissB":ForensicTrace.state(beforeKissB),"preA":ForensicTrace.state(preA),"preB":ForensicTrace.state(preB),"postA":ForensicTrace.state(stateA),"postB":ForensicTrace.state(stateB)])')
s=s.replace('        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)','        let preState=state\n        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)',1)
s=s.replace('        balls[ball] = state\n        return true\n    }\n    \n    /// Resolve state transition','        ForensicTrace.rows.append(["kind":"cushion","t":Double(currentTime),"index":cushionIndex,"normal":ForensicTrace.v(normal),"pre":ForensicTrace.state(preState),"post":ForensicTrace.state(state)])\n        balls[ball] = state\n        return true\n    }\n    \n    /// Resolve state transition',1)
s=s.replace('        state.state = toState','        let preState=state\n        state.state = toState',1)
s=s.replace('        balls[ball] = state\n    }\n    \n    /// Resolve pocket event','        ForensicTrace.rows.append(["kind":"transition","t":Double(currentTime),"pre":ForensicTrace.state(preState),"post":ForensicTrace.state(state)])\n        balls[ball] = state\n    }\n    \n    /// Resolve pocket event',1)
# Observe prediction origin without changing selection or cache.
s=s.replace('                    candidates.append(immediate)','                    StudyPrediction.record("immediate",a:ballA,b:ballB,now:currentTime,dt:immediate.time)\n                    candidates.append(immediate)',1)
a=s.index('                // Check cache first',s.index('// Find ball-ball collisions'));b=s.index('// Find ball-cushion collisions',a);c=s[a:b]
c=c.replace('                        candidates.append(cached)','                        StudyPrediction.record("cache",a:ballA,b:ballB,now:currentTime,dt:cached.time)\n                        candidates.append(cached)',1)
c=c.replace('                    candidates.append(event)','                    StudyPrediction.record("quartic",a:ballA,b:ballB,now:currentTime,dt:event.time)\n                    candidates.append(event)',1)
marker='                    candidates.append(event)';pos=c.index('// Quartic missed');c=c[:pos]+c[pos:].replace(marker,'                    StudyPrediction.record("fallback",a:ballA,b:ballB,now:currentTime,dt:event.time)\n'+marker,1)
s=s[:a]+c+s[b:]
s=s.replace('        return candidates.min()','''        let selected=candidates.min()
        if let selected,case .ballBall(let a,let b)=selected.type,let ba=balls[a],let bb=balls[b] {
            StudyPrediction.record("selected",a:ba,b:bb,now:currentTime,dt:selected.time)
        }
        return selected''',1)
s+=(T/'EventDrivenEngine.swift').read_text().split('// Read-only research observer, never read by physics decisions.')[1]
s+='''
enum StudyPrediction {
 static var enabled=false
 static var rows:[[String:Any]]=[]
 static func record(_ origin:String,a:BallState,b:BallState,now:Float,dt:Float) {
  guard enabled && now<0.081 else {return}
  rows.append(["origin":origin,"t":Double(now),"dt":Double(dt),"a":ForensicTrace.state(a),"b":ForensicTrace.state(b),"aa":ForensicTrace.v(EngineNumerics.acceleration(for:a)),"ab":ForensicTrace.v(EngineNumerics.acceleration(for:b))])
 }
}
'''
assert s.count('ForensicTrace.rows.append')==3
(D/'EventDrivenEngine.swift').write_text(s)
s=(T/'main.swift').read_text();a=s.index('            ContactToleranceResearch.value');b=s.index('            let cue =',a)
s=s[:a]+'''            ContactToleranceResearch.value = Float(input["toleranceM"] as! Double)
            InvarianceTrace.mode = input["mode"] as! Int
            let originalRack=RackLayout.make(game,seed:seed)
            let mirror=input["mirror"] as! Bool,reverse=input["reverse"] as! Bool
            let canonical=originalRack.balls.map { b -> RackBall in
                var p=b.position;if mirror {p.z = -p.z}
                return RackBall(key:b.key,number:b.number,position:p)
            }
            let ordered=(input["permutation"] as? [Int]).map {p in p.map{canonical[$0]}} ?? (reverse ? Array(canonical.reversed()):canonical)
            let rack=Rack(game:game,cue:originalRack.cue,balls:ordered,surfaceY:originalRack.surfaceY)
'''+s[b:]
s=s.replace('                ForensicTrace.rows=[]','''                ForensicTrace.rows=[]
                InvarianceTrace.reset()
                StudyPrediction.rows=[];StudyPrediction.enabled=input["diagnostic"] as? Bool ?? false
                let override=input["exactCueVelocity"] as? [Double] ?? vec(initialStrike.velocity)
                InvarianceTrace.cueVelocityOverride=SCNVector3(Float(override[0]),Float(override[1]),Float(override[2]))
                row["initialCueVelocity"]=vec(InvarianceTrace.cueVelocityOverride!)''')
s=s.replace('                row["eventTrace"] = ForensicTrace.rows','''                row["eventTrace"] = ForensicTrace.rows
                row["rejectedPairs"] = InvarianceTrace.rejected
                row["predictions"] = StudyPrediction.rows
                row["canonicalNames"] = canonical.map(\\.key)''')
s=s.replace('if input["rackID"] as! Int == 11331 {','if [11304,11331].contains(input["rackID"] as! Int) {')
# Reuse actual numerical invariants, not scripted expected simulation outcomes.
s=s.replace('let profile = AccuracyTipSelector.renderedProfile()', (A/'probe.swift').read_text()+'\nlet probe=repairProbe()\nlet profile = AccuracyTipSelector.renderedProfile()')
s=s.replace('"pid": ProcessInfo.processInfo.processIdentifier, "length": length,','"pid": ProcessInfo.processInfo.processIdentifier, "probe":probe,"length": length,')
s=s.replace('                row["eventTrace"] = ForensicTrace.rows','''                row["parameters"] = ["ballRadius":Double(BallPhysics.radius),"ballMass":Double(BallPhysics.mass),"ballRestitution":Double(BallPhysics.restitution),"cushionRestitution":Double(TablePhysics.cushionRestitution),"cushionFriction":Double(TablePhysics.cushionFriction),"cushionHeight":Double(TablePhysics.cushionHeight),"slidingFriction":Double(SpinPhysics.slidingFriction),"rollingFriction":Double(SpinPhysics.rollingFriction),"spinFriction":Double(SpinPhysics.spinFriction),"gravity":Double(TablePhysics.gravity),"rackGap":Double(RackLayout.gap),"jitterRadius":Double(RackLayout.jitterRadius)]
                row["eventTrace"] = ForensicTrace.rows''')
(D/'main.swift').write_text(s)
s=(A/'build.py').read_text().replace('rack-solver-repair-20261026','rack-contact-repair-20261027')
s=s.replace("'-frontend','-c',","'-frontend','-c','-external-plugin-path','/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/swift-plugin-server',")
(D/'build.py').write_text(s)
for name in ['EngineNumerics.swift','EventDrivenEngine.swift','CollisionDetector.swift','CollisionResolver.swift','PhysicsEvent.swift','BreakSimulator.swift']:
 p=next((R/'QiuJi').rglob(name));(O/(name+'.diff')).write_text(''.join(difflib.unified_diff(p.read_text().splitlines(True),(D/name).read_text().splitlines(True),fromfile='production/'+name,tofile='research/'+name)))
(O/'production-before.json').write_text(json.dumps({str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (R/'QiuJi').rglob('*.swift')},indent=2))
# A separately compiled production control prevents inactive candidate branches
# or a changed compiler from being mistaken for production behavior.
C=D/'control';C.mkdir(exist_ok=True)
for name in ['CollisionDetector.swift','CollisionResolver.swift','PhysicsEvent.swift']:
 (C/name).write_text(next((R/'QiuJi').rglob(name)).read_text())
(C/'EngineNumerics.swift').write_text((T/'EngineNumerics.swift').read_text())
(C/'BreakSimulator.swift').write_text((A/'BreakSimulator.swift').read_text())
s=(T/'EventDrivenEngine.swift').read_text()
s=s.replace('                    candidates.append(immediate)','                    StudyPrediction.record("immediate",a:ballA,b:ballB,now:currentTime,dt:immediate.time)\n                    candidates.append(immediate)',1)
a=s.index('                // Check cache first',s.index('// Find ball-ball collisions'));b=s.index('// Find ball-cushion collisions',a);c=s[a:b]
c=c.replace('                        candidates.append(cached)','                        StudyPrediction.record("cache",a:ballA,b:ballB,now:currentTime,dt:cached.time)\n                        candidates.append(cached)',1)
c=c.replace('                    candidates.append(event)','                    StudyPrediction.record("quartic",a:ballA,b:ballB,now:currentTime,dt:event.time)\n                    candidates.append(event)',1)
pos=c.index('// Quartic missed');c=c[:pos]+c[pos:].replace('                    candidates.append(event)','                    StudyPrediction.record("fallback",a:ballA,b:ballB,now:currentTime,dt:event.time)\n                    candidates.append(event)',1)
s=s[:a]+c+s[b:];s=s.replace('        return candidates.min()','''        let selected=candidates.min()
        if let selected,case .ballBall(let a,let b)=selected.type,let ba=balls[a],let bb=balls[b] {
            StudyPrediction.record("selected",a:ba,b:bb,now:currentTime,dt:selected.time)
        }
        return selected''',1)
s+='\nenum InvarianceTrace { static var mode=0;static var rejected:[[String:Any]]=[];static var cueVelocityOverride:SCNVector3?=nil;static func reset(){rejected=[]} }\n'
s+='enum StudyPrediction {'+(D/'EventDrivenEngine.swift').read_text().split('enum StudyPrediction {')[1]
(C/'EventDrivenEngine.swift').write_text(s)
s=(D/'main.swift').read_text();a=s.index('func repairProbe()');b=s.index('let profile =',a);s=s[:a]+'let probe:[String:Any]=[:]\n'+s[b:];(C/'main.swift').write_text(s)
for name in ['EngineNumerics.swift','EventDrivenEngine.swift','CollisionDetector.swift','CollisionResolver.swift','PhysicsEvent.swift','BreakSimulator.swift']:
 p=next((R/'QiuJi').rglob(name));(O/('control-'+name+'.diff')).write_text(''.join(difflib.unified_diff(p.read_text().splitlines(True),(C/name).read_text().splitlines(True),fromfile='production/'+name,tofile='research/control/'+name)))

for folder,label in [(D,'repair'),(C,'production')]:
 p=folder/'main.swift';s=p.read_text();s=s.replace('            let input =',f'            let backendLabel="{label}"\n            let input =');s=s.replace('            try emit("RESULT", row)','            row["backend"]=backendLabel\n            try emit("RESULT", row)');p.write_text(s)
