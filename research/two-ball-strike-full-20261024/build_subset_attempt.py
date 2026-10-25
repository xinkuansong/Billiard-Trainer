from pathlib import Path
import subprocess,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[2]; OUT=Path(__file__).resolve().parent
SRC=OUT/'native-source';SRC.mkdir(exist_ok=True)
physics=ROOT/'QiuJi/Core/Physics'
exclude={'DrillBoardBuilder.swift','DrillShotResolver.swift','ShotBaker.swift','ShotIntent.swift','SimulationWorker.swift'}
paths=[str(p.relative_to(ROOT)) for p in physics.glob('*.swift') if p.name not in exclude]
paths += ['QiuJi/Core/Scene/'+n+'.swift' for n in ['AngleSceneCalculator','BTSceneConstants','CueClearance','CueStick','CueStyleModel','TableModelLoader']]
paths += ['QiuJi/Features/AngleTraining/'+n+'.swift' for n in ['BankShotCalculator','DiamondSystemCalculator']]
paths += ['QiuJi/Data/Services/CueStyle.swift']
extra=OUT/'extra-sources.json'
if extra.exists():paths+=json.loads(extra.read_text())
paths=list(dict.fromkeys(paths));manifest={}
for s in paths:
 p=ROOT/s;d=p.read_bytes();(SRC/p.name).write_bytes(d);manifest[s]=hashlib.sha256(d).hexdigest()
# Keep production declarations byte-for-byte, omit unrelated scene/UI extensions.
def declaration(path,marker):
 s=(ROOT/path).read_text();start=s.index(marker);opening=s.index('{',start);depth=1;i=opening+1
 # These selected declarations contain balanced braces in comments/strings.
 while depth:
  depth+=(s[i]=='{')-(s[i]=='}');i+=1
 manifest[path]=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
 return s[start:i]
parts=['import Foundation\nimport SceneKit\n']
parts += [declaration('QiuJi/Core/PositionPlay/PositionPlayModels.swift','struct RecordedStrikeDirection:'),declaration('QiuJi/Core/PositionPlay/DirectPotBankFallback.swift','final class PredictionCancellation:')]
s=(ROOT/'QiuJi/Core/Scene/CueStroke.swift').read_text();parts.append(s.split('extension AngleTrainingScene {')[0]);manifest['QiuJi/Core/Scene/CueStroke.swift']=hashlib.sha256(s.encode()).hexdigest()
(SRC/'ExtractedDeclarations.swift').write_text('\n'.join(parts))
(OUT/'source-hashes.json').write_text(json.dumps(manifest,indent=2))
app=OUT/'Worker.app';app.mkdir(exist_ok=True)
import plistlib
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.strike-worker','CFBundleExecutable':'Worker','CFBundleName':'StrikeWorker','CFBundlePackageType':'APPL'}))
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-whole-module-optimization','-module-name','StrikeWorker']+[str(p) for p in SRC.glob('*.swift')]+[str(OUT/'main.swift'),'-o',str(app/'Worker')]
(OUT/'build-command.json').write_text(json.dumps(cmd,indent=2))
with (OUT/'build.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
print('compile exit',r.returncode)
if r.returncode:print((OUT/'build.log').read_text()[:12000])
sys.exit(r.returncode)
