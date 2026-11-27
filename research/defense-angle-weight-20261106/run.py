from pathlib import Path
import hashlib, json, os, plistlib, shutil, subprocess, sys, tarfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output/defense-angle-weight-20261106'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
OUT.mkdir(exist_ok=True,parents=True)

work = Path(os.environ['QIUJI_TEST_WORK']); evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
src = work/'sources'; paths = []; manifest = {}
for p in sorted((ROOT/'QiuJi').rglob('*.swift')):
    rel = p.relative_to(ROOT); data = p.read_bytes(); manifest[str(rel)] = sha(p)
    if b'@main' in data:
        assert p.name == 'QiuJiApp.swift', p
        data = data.replace(b'@main', b'// Native benchmark supplies main')
    dest = src/rel; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data); paths.append(str(dest))

# Only this isolated snapshot changes, production source stays untouched.
p=src/'QiuJi/Features/DefensePractice/DefenseAttackAssessment.swift';s=p.read_text()
s=s.replace('struct DefenseAttackAssessment {', 'var defenseAngleExperiment = false\nvar defenseAngleWeight = 1.0\nfunc defenseExperimentCut(_ c:DefenseAttackAssessment.P,_ b:DefenseAttackAssessment.P,_ aim:DefenseAttackAssessment.P)->Double {\n let n=(aim-b)*(1/(aim-b).length),v=b-n*Double(2*AngleSceneCalculator.ballRadius)-c\n return atan2(abs(v.cross(n)),v.dot(n))*180/Double.pi\n}\nstruct DefenseAttackAssessment {')
s=s.replace('var zeroWidthEstimate: Bool? = nil','var zeroWidthEstimate: Bool? = nil\n var experimentCutDegrees: Double? = nil')
s=s.replace('var score: Double { DefenseEffect.value(pipeDegrees:tolerance,comfort:comfort)! }','var score: Double {\n let weight=defenseAngleExperiment ? defenseAngleWeight*pow(cos((experimentCutDegrees ?? 0)*Double.pi/180),2):1\n return 100*sqrt((1-comfort/100)/(1+tolerance*weight/DefenseEffect.pipeReferenceDegrees))\n }')
s=s.replace('zeroWidthEstimate:estimated ? true:nil)', 'zeroWidthEstimate:estimated ? true:nil,experimentCutDegrees:defenseExperimentCut(cue,ball,end))')
s=s.replace('aim:[Double(candidate.aim.x),Double(candidate.aim.z)])','aim:[Double(candidate.aim.x),Double(candidate.aim.z)],experimentCutDegrees:defenseExperimentCut(cue,ball,P(Double(candidate.aim.x),Double(candidate.aim.z))))')
s=s.replace('zeroWidthEstimate:interval == nil ? true:nil)','zeroWidthEstimate:interval == nil ? true:nil,experimentCutDegrees:defenseExperimentCut(cue,ball,end))')
s=s.replace('best == nil || candidate.comfort>best!.comfort','best == nil || (defenseAngleExperiment ? candidate.score<best!.score : candidate.comfort>best!.comfort)')
assert s.count('experimentCutDegrees:defenseExperimentCut')==3
p.write_text(s)
effect_source=(ROOT/'QiuJi/Features/DefensePractice/DefenseEffect.swift').read_text()
body=effect_source.split('        if fullyBlocked(cue, target, blockers) {',1)[1].split('    /// Upper bounds',1)[0]
body='        if fullyBlocked(cue, target, blockers) {'+body
body=body.replace('var assessment = DefenseAttackAssessment()', 'var assessment = windows ?? DefenseAttackAssessment()')
wrapper='import Foundation\nimport SceneKit\nextension DefenseEffect {\nstatic func regionState(cue:SCNVector3,target:SCNVector3,blockers:[SCNVector3],windows:DefenseAttackAssessment?=nil,opponent:Int=9) throws -> Self {\nvar timing=Timing();let usePrecomputedWindows=false\n'+body+'}\n'
p=src/'RegionState.swift';p.write_text(wrapper);paths.append(str(p))
main=work/'main.swift';shutil.copy2(HERE/'main.swift',main)
app=work/'DefenseBench.app';app.mkdir();binary=app/'Worker'
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.defense-angle-experiment','CFBundleExecutable':'Worker','CFBundlePackageType':'APPL'}))
(OUT/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
with tarfile.open(OUT/'source-snapshot.tar.gz','w:gz') as ar:
 ar.add(src,arcname='sources');ar.add(main,arcname='main.swift')
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(main),'-lz','-o',str(binary)]
(evidence/'build-command.json').write_text(json.dumps(cmd,indent=2))
print('Compiling isolated A/B evaluator',len(paths),flush=True)
with (evidence/'build.log').open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
if r.returncode:print((evidence/'build.log').read_text()[-5000:]);sys.exit(r.returncode)
print('Build passed; evaluating 15 fixed positions across 7 formulas, no route generation',flush=True)
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','defense-angle-weight-20261106','--',sys.executable,str(HERE/'worker.py'),'{udid}',str(binary),str(OUT)],check=True)
drift=[p for p,h in manifest.items() if sha(ROOT/p)!=h]
(OUT/'execution.json').write_text(json.dumps(dict(passed=True,sourceDrift=drift,evidence=str(evidence),scope='15 terminal positions across production baseline plus 6 candidate weights; no defense trajectory generation; no production replacement'),indent=2))
assert not drift
