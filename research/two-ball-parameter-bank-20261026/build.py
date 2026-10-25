from pathlib import Path
import subprocess,json,os,hashlib,plistlib,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;BASE=ROOT/'research/two-ball-strike-full-20261024';OUT=ROOT/'output/two-ball-parameter-bank-20261026'
work=Path(os.environ['QIUJI_TEST_WORK']);ev=Path(os.environ['QIUJI_TEST_EVIDENCE']);sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
# Use unchanged production physics/recorder/trajectory/access object files. UI drift is outside harness.
manifest=json.loads((BASE/'source-hashes.json').read_text());current={p.name:p for p in (ROOT/'QiuJi').rglob('*.swift')};critical=[]
for p in (BASE/'native-source').glob('*.swift'):
 q=current[p.name]
 if '/Physics/' in str(q) or any(x in p.name for x in ('ShotPredict','ShotRecord','TableGeometry','CueStrike','CuePhysics','BallPhysics','BTPhysics','SeparationQuestionGenerator','AccuracyTipSelector','CueClearance')):
  digest=hashlib.sha256(q.read_bytes()).hexdigest();assert digest==manifest[str(q.relative_to(ROOT))],f'Production simulation drift: {q}';critical.append({'path':str(q.relative_to(ROOT)),'sha256':digest})
source=(ROOT/'QiuJi/Features/TwoBallPractice/TwoBallQuestionPreparer.swift').read_text();a=source.index('    static func solve(board:');b=source.index('\n/// Reuses the durable');solve='enum ParameterReplaySolver {\n    static let secondBallName = "second"\n'+source[a:b]
metric=(ROOT/'QiuJi/Features/TwoBallPractice/TwoBallBankStore.swift').read_text().split('enum TwoBallDifficultyMetric {',1)[1]
comfort=source.split('enum TwoBallComfortScore {',1)[1]
arc=(ROOT/'QiuJi/Features/SeparationPractice/SeparationTrajectoryScore.swift').read_text();arc=arc[arc.index('enum SeparationArcRMSMetric {'):arc.index('/// Immutable versioned score;')]
compact=(ROOT/'research/two-ball-middle-grid18-20261025/main.swift').read_text();compact=compact[compact.index('func compactTrajectory('):compact.index('final class StrikeGridWorker')]
adapters='import Foundation\nimport SceneKit\n'+solve+'\nenum TwoBallDifficultyMetric {'+metric+'\nenum TwoBallComfortScore {'+comfort+'\n'+arc+compact
(work/'SourceAdapters.swift').write_text(adapters)
app=work/'ParameterWorker.app';app.mkdir();(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.parameter-benchmark','CFBundleExecutable':'Worker','CFBundleName':'ParameterBenchmark','CFBundlePackageType':'APPL'}))
# Read-only resource links avoid copying the large app; the benchmark does not install it.
for p in (BASE/'Worker.app').iterdir():
 if p.name not in ('Worker','Info.plist','_CodeSignature'): (app/p.name).symlink_to(p)
sources=sorted(map(str,(BASE/'native-source').glob('*.swift')));extra=[str(work/'SourceAdapters.swift'),str(HERE/'main.swift')];objects=[];commands=[]
for path in extra:
 obj=work/(Path(path).stem+'.o');cmd=['xcrun','swiftc','-frontend','-c',*sources,*[x for x in extra if x!=path],'-primary-file',path,'-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-D','DEBUG','-module-name','QiuJi','-o',str(obj)];commands.append(cmd);objects.append(str(obj))
old=[str(p) for p in sorted((BASE/'objects').glob('*.o')) if p.name!='main.o'];commands.append(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*old,*objects,'-lz','-Xlinker','-syslibroot','-Xlinker',sdk,'-o',str(app/'Worker')])
(ev/'build-commands.json').write_text(json.dumps(commands,indent=2));(OUT/'source-binding.json').write_text(json.dumps({'criticalProductionSources':critical,'adaptersSHA256':hashlib.sha256(adapters.encode()).hexdigest(),'method':'unchanged frozen physics objects; exact current production solve/failure/comfort/geometry/P2 methods extracted; no App edits; optimized simulator harness','swiftSources':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'QiuJi/Features/TwoBallPractice/TwoBallQuestionPreparer.swift',ROOT/'QiuJi/Features/TwoBallPractice/TwoBallBankStore.swift',ROOT/'QiuJi/Features/SeparationPractice/SeparationTrajectoryScore.swift',HERE/'main.swift']}},indent=2))
with (ev/'build.log').open('w') as log:
 for cmd in commands:
  result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
  if result.returncode:print((ev/'build.log').read_text()[-7000:]);sys.exit(result.returncode)
print(str(app/'Worker'),flush=True)
