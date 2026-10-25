from pathlib import Path
import subprocess, json, os
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'two-ball-strike-full-20261024'
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
sources=sorted(map(str,(BASE/'native-source').glob('*.swift')))
obj=HERE/'main.o';app=HERE/'Worker.app'
if not app.exists(): subprocess.run(['cp','-cR',str(BASE/'Worker.app'),str(app)],check=True)
compile_cmd=['xcrun','swiftc','-frontend','-c',*sources,'-primary-file',str(HERE/'main.swift'),'-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-D','DEBUG','-module-name','QiuJi','-o',str(obj)]
objects=[str(p) for p in sorted((BASE/'objects').glob('*.o')) if p.name!='main.o']
link_cmd=['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*objects,str(obj),'-Xlinker','-syslibroot','-Xlinker',sdk,'-o',str(app/'Worker')]
(HERE/'build-commands.json').write_text(json.dumps([compile_cmd,link_cmd],indent=2))
with (HERE/'build.log').open('w') as log:
    for cmd in [compile_cmd,link_cmd]:
        r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,SDKROOT=sdk))
        if r.returncode: raise SystemExit(r.returncode)
print('Native trajectory capture built from frozen production objects; only main entry recompiled.')
