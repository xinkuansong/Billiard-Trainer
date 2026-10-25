from pathlib import Path
import subprocess,json,hashlib,sys,shutil,plistlib
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
SRC=OUT/'native-source'
if SRC.exists():shutil.rmtree(SRC)
SRC.mkdir()
manifest={};sources=[];seen=set()
for p in sorted((ROOT/'QiuJi').rglob('*.swift')):
    assert p.name not in seen,p.name
    seen.add(p.name);raw=p.read_bytes();s=raw.decode()
    manifest[str(p.relative_to(ROOT))]=hashlib.sha256(raw).hexdigest()
    if p.relative_to(ROOT).as_posix()=='QiuJi/App/QiuJiApp.swift':
        assert s.count('@main\n')==1;s=s.replace('@main\n','// CLI owns the entry point; original App type retained.\n',1)
    q=SRC/p.name;q.write_text(s);sources.append(str(q))
(OUT/'source-hashes.json').write_text(json.dumps(manifest,indent=2))
app=OUT/'Worker.app';app.mkdir(exist_ok=True)
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.qiuji.strike-worker','CFBundleExecutable':'Worker','CFBundleName':'StrikeWorker','CFBundlePackageType':'APPL'}))
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
# Compile once for this machine only. All production physics/clearance source bytes unchanged.
objects=OUT/'objects';objects.mkdir(exist_ok=True)
all_sources=sources+[str(OUT/'main.swift')]
output_map={f:{'object':str(objects/(Path(f).stem+'.o')),'swift-dependencies':str(objects/(Path(f).stem+'.swiftdeps'))} for f in all_sources}
output_map['']={'swift-dependencies':str(objects/'master.swiftdeps')}
map_path=OUT/'output-file-map.json';map_path.write_text(json.dumps(output_map))
cmd=['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-swift-version','5','-O','-D','DEBUG','-j','4','-enable-batch-mode','-module-name','QiuJi','-emit-executable','-output-file-map',str(map_path),'-incremental','-Xlinker','-syslibroot','-Xlinker',sdk]+all_sources+['-o',str(app/'Worker')]
(OUT/'build-command.json').write_text(json.dumps(cmd,indent=2))
with (OUT/'build.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,env=dict(__import__('os').environ,SDKROOT=sdk))
print('compile exit',r.returncode)
if r.returncode:print((OUT/'build.log').read_text()[-8000:])
sys.exit(r.returncode)
