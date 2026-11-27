"""Resume only the original frozen binary/controller and matching immutable input."""
from pathlib import Path
import json,hashlib,subprocess,sys,os
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-rail-sequences-full-20261106'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
paths=json.loads((OUT/'run-paths.json').read_bytes());identity=json.loads((OUT/'run-identity.json').read_bytes())
work=Path(paths['work']);run=json.loads((work.parent/'run.json').read_bytes())
if run['state']=='running':
 try:os.kill(run['pid'],0)
 except ProcessLookupError:pass
 else:raise SystemExit('Original manager still running; do not start a duplicate job')
assert sha(Path(paths['binary']))==identity['binarySHA256']
assert sha(OUT/'inputs.json')==identity['inputsSHA256'] and sha(OUT/'policy.json')==identity['policySHA256']
assert paths['identity']==identity['identity']
# Frozen script path must remain available in the retained failed-run workspace.
controller=work/'tooling/controller.py';assert controller.exists()
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','defense-rail-sequences-full-20261106-resume','--',sys.executable,str(controller),'{udid}',paths['binary'],paths['identity']],check=True)
print('Resumed generation and packing completed; original failed build evidence retained for audit.')
