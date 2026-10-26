from pathlib import Path
import shutil
D=Path(__file__).resolve().parent;ROOT=D.parents[1];A=ROOT/'research/rack-solver-repair-20261026'
for n in ['EventDrivenEngine.swift','BreakSimulator.swift','EngineNumerics.swift','PhysicsEvent.swift','CollisionDetector.swift','CollisionResolver.swift','main.swift','build.py']:shutil.copy2(A/n,D/n)
p=D/'CollisionResolver.swift';s=p.read_text();s=s.replace('let sliding=u*(-mu*abs(e*normal)/speed)','let limit = FixedPhysicsResearch.coulomb ? 0.5*(1+e)*abs(normal) : abs(e*normal)\n            let sliding=u*(-mu*limit/speed)')
s=s.replace('        let result = Han2005CushionModel.solve(','''        if FixedPhysicsResearch.supportedCushion,let result=FixedPhysicsResearch.supported(v:v,w:w,n:N,e:restitution) {return result}
        let result = Han2005CushionModel.solve(''',1)
s+='\n'+(D/'extensions.swift.txt').read_text();p.write_text(s)
p=D/'EventDrivenEngine.swift';s=p.read_text();marker='    /// Resolve ball-ball collision using pure computation'
s=s.replace(marker,(D/'joint.swift.txt').read_text()+'\n'+marker)
s=s.replace('        InvarianceTrace.pair("beforeKiss",a:stateA,b:stateB,now:currentTime)','        if InvarianceTrace.mode>0 && researchJoint(ballA,ballB) {return true}\n        InvarianceTrace.pair("beforeKiss",a:stateA,b:stateB,now:currentTime)',1)
s=s.replace('        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)','        let preState=state\n        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)')
s=s.replace('        balls[ball] = state\n        return true\n    }\n    \n    /// Resolve state transition','''        FixedPhysicsResearch.cushionRows.append(["time":Double(currentTime),"index":cushionIndex,"pre":InvarianceTrace.state(preState),"post":InvarianceTrace.state(state),"normal":InvarianceTrace.v(normal)])
        balls[ball] = state
        return true
    }
    
    /// Resolve state transition''');p.write_text(s)
p=D/'main.swift';s=p.read_text().replace('"probe":probe,','"probe":probe,"parameters":FixedPhysicsResearch.parameters,')
s=s.replace('            InvarianceTrace.mode = input["mode"] as! Int','            InvarianceTrace.mode = input["mode"] as! Int\n            FixedPhysicsResearch.variant=input["experiment"] as! String\n            FixedPhysicsResearch.reset()')
s=s.replace('                row["pairTrace"] = InvarianceTrace.rows','''                row["pairTrace"] = InvarianceTrace.rows
                row["cushionTrace"] = FixedPhysicsResearch.cushionRows
                row["jointTrace"] = FixedPhysicsResearch.jointRows
                row["contactComponents"] = Dictionary(uniqueKeysWithValues:FixedPhysicsResearch.clusters.map{(String($0.key),$0.value)})
                row["researchFailures"] = FixedPhysicsResearch.failures
                row["parameters"] = FixedPhysicsResearch.parameters''')
s=s.replace('                row["status"] = result.settled ? "settled" : "incomplete"','                row["status"] = !FixedPhysicsResearch.failures.isEmpty ? "research_failed" : (result.settled ? "settled" : "incomplete")');p.write_text(s)
p=D/'build.py';s=p.read_text().replace("output/rack-solver-repair-20261026","output/rack-fixed-physics-20261027");p.write_text(s)
s=(ROOT/'research/rack-spin-experiments-20261026/run.py').read_text();a=s.index('variants=[');b=s.index('def main(uid):',a)
s=s[:a]+"variants=[('production',0),('baseline',2),('coulomb',2),('joint',2),('support',2),('combined',2)]\n"+s[b:]
a=s.index('   reference=json.loads');b=s.index('   with gzip.open',a);s=s[:a]+s[b:]
s=s.replace("ids=list(range(11300,11400)) if sys.argv[2].startswith('sweep') else list(range(11400,11500))","ids=list(range(11300,11310))+[11331,11399] if sys.argv[2]=='pilot' else list(range(11300,11500))")
s=s.replace('for label,mode,model,mu,alpha in variants:','for label,mode in variants:')
s=s.replace(",cushionModel=model,mu=mu,spinScale=alpha/10.9,step=.0001",'')
s=s.replace("if label in ['production','repair']:","if label in ['production','baseline']:")
(D/'run.py').write_text(s)

p=D/'main.swift';s=p.read_text().replace('// Research entry only. All rack/strike/collision/pocket/settlement code is production code.','// Research entry. Rack, strike, material constants, motion decay and pockets are production code; collision algorithms vary explicitly.')
s=s.replace('let probe=repairProbe()', (D/'fixed-probes.swift.txt').read_text()+'\nlet fixedProbe=fixedPhysicsProbe()\nlet probe=repairProbe()').replace('"probe":probe,','"probe":probe,"fixedProbe":fixedProbe,')
p.write_text(s)
