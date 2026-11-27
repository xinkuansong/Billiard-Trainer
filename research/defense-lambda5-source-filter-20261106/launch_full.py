from pathlib import Path
import os,sys,json,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
assert json.loads((OUT/'pilot-summary.json').read_text())['passed']
paths=json.loads((OUT/'run-paths.json').read_text());identity=json.loads((OUT/'run-identity.json').read_text())
assert hashlib.sha256(Path(paths['binary']).read_bytes()).hexdigest()==identity['binarySHA256']
work=Path(os.environ['QIUJI_TEST_WORK']);tooling=work/'tooling';tooling.mkdir()
manifest={}
for name in ['full.py','controller.py']:
 content=(HERE/name).read_text().replace('OUT=Path(__file__).resolve().parents[2]/"output"/Path(__file__).resolve().parent.name',f'OUT=Path({str(OUT)!r})')
 p=tooling/name;p.write_text(content);manifest[name]=hashlib.sha256(p.read_bytes()).hexdigest()
(OUT/'full-driver-identity.json').write_text(json.dumps(dict(nativeIdentity=identity['id'],tooling=manifest),indent=2))
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','defense-lambda5-all-source-regions-20261106','--',sys.executable,str(tooling/'full.py'),'{udid}',paths['binary']],check=True)
