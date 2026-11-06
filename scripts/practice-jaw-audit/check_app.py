"""Run the opt-in XCTest in the installed App and demand its per-manifest report."""
import json,plistlib,subprocess,sys
from pathlib import Path
device,work,family=sys.argv[1:]
work=Path(work).resolve()
build=work/'host-build'
products=build/'Build/Products'
def xcode(args,log):
    with (work/log).open('w') as f:subprocess.run(['xcodebuild',*map(str,args)],check=True,stdout=f,stderr=subprocess.STDOUT)
dest='platform=iOS Simulator,id='+device
xcode(['-project','QiuJi.xcodeproj','-scheme','QiuJi','-derivedDataPath',build,'-destination','generic/platform=iOS Simulator','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','build-for-testing'],family+'-app-build.log')
spec=next(p for p in products.glob('*.xctestrun') if not p.name.startswith('jaw-review-'))
plan=plistlib.loads(spec.read_bytes())
if 'TestConfigurations' in plan:
    targets=[t for c in plan['TestConfigurations'] for t in c['TestTargets']]
else:
    targets=[plan['QiuJiTests']]
for target in targets:
    target.setdefault('EnvironmentVariables',{}).update(QJ_JAW_AUDIT=str(work),QJ_JAW_FAMILY=family)
path=products/('jaw-review-'+family+'.xctestrun')
path.write_bytes(plistlib.dumps(plan))
report=work/(family+'-app-replay.json')
report.unlink(missing_ok=True)
result=work/(family+'-app.xcresult')
attempt=1
while result.exists():
    attempt+=1
    result=work/(family+'-app-'+str(attempt)+'.xcresult')
selector = ('QiuJiTests/SeparationPracticeTests/testAdjustedGridAnswersInAppHost' if family=='sep'
            else 'QiuJiTests/KBallPracticeTests/testPromotedPocketJawReferencesInAppHost')
xcode(['-xctestrun',path,'-destination',dest,'-destination-timeout','240','-parallel-testing-enabled','NO','-only-testing:'+selector,'-resultBundlePath',result,'test-without-building'],family+'-app.log')
data=json.loads(report.read_bytes())
assert data['failed']==[] and data['expected']==data['seen']==len(json.loads((work/(family+'-changed.json')).read_bytes()))
print(data)
