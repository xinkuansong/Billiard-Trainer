from pathlib import Path
import hashlib,json,os,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'output/rail-aim-repair-20261102'
OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'results.jsonl').exists():
    raise SystemExit('Archive previous results before starting a new regression run')
(OUT/'boards.json').write_bytes((HERE/'boards.json').read_bytes())
work=Path(os.environ['QIUJI_TEST_WORK']);evidence=Path(os.environ['QIUJI_TEST_EVIDENCE'])
sources=work/'sources';sources.mkdir()
manifest={};paths=[]
for p in sorted((ROOT/'QiuJi').rglob('*.swift')):
    raw=p.read_bytes();manifest[str(p.relative_to(ROOT))]=hashlib.sha256(raw).hexdigest()
    q=sources/p.relative_to(ROOT/'QiuJi');q.parent.mkdir(parents=True,exist_ok=True)
    if p.name=='QiuJiApp.swift':raw=raw.replace(b'@main',b'// diagnostic executable supplies main')
    q.write_bytes(raw);paths.append(str(q))
(OUT/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
(work/'main.swift').write_bytes((HERE/'main.swift').read_bytes())
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
cmd=['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG','-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',*paths,str(work/'main.swift'),'-lz','-o',str(work/'Worker')]
(OUT/'build-command.json').write_text(json.dumps(cmd,indent=2))
os.environ['SDKROOT']=sdk
with (evidence/'build.log').open('w') as f:
    r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
if r.returncode:
    print((evidence/'build.log').read_text()[-7000:]);sys.exit(r.returncode)
print('BUILD COMPLETE',flush=True)
uid=sys.argv[1]
subprocess.run(['xcrun','simctl','boot',uid],check=True)
try:
    subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
    with (OUT/'run.log').open('w') as f:
        r=subprocess.run(['xcrun','simctl','spawn',uid,str(work/'Worker'),str(ROOT/'QiuJi/Resources/training-grid-bank.json'),str(OUT)],stdout=f,stderr=subprocess.STDOUT)
    if r.returncode:print((OUT/'run.log').read_text()[-7000:]);sys.exit(r.returncode)
finally:
    subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
drift=[p for p,h in manifest.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h]
(OUT/'execution.json').write_text(json.dumps(dict(exit=r.returncode,sourceDrift=drift,uid=uid,work=str(work),evidence=str(evidence)),indent=2))
print((OUT/'run.log').read_text()[-2000:])
