"""Solve the 10 cm / 75-point opening pool with the same native app sources as its opening scan."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT/'output'/HERE.name
deep = "--deep" in sys.argv
if deep:
    OUT = OUT/'deep'
    os.environ['SINGLE_EIGHT_DEEP'] = '1'
WORK = Path(os.environ['QIUJI_TEST_WORK'])
OUT.mkdir(parents=True,exist_ok=True)
opening = ROOT/'output/defense-single-eight-opening-20261106-10cm'
manifest = json.loads((opening/'native-source.json').read_bytes())
sources = []
for name, digest in manifest.items():
    if not name.endswith('.swift'):
        continue
    src = ROOT/name
    data = src.read_bytes()
    if hashlib.sha256(data).hexdigest() != digest:
        # Use the source snapshot used to compile the opening assessment.
        frozen = ROOT/'output/local-test-runs/daa00767eb744b8a91c8a0403569f224/work'/name
        data = frozen.read_bytes()
        assert hashlib.sha256(data).hexdigest() == digest, name
    if name.endswith('/QiuJiApp.swift'):
        data = data.replace(b'@main',b'// Research entry point')
    dest = WORK/name
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(data)
    sources.append(str(dest))
old = ROOT/'output/defense-opening-routes-20261106/rollout-full-v2/runner/OpeningRoutes.app'
app = WORK/'OpeningRoutes.app'
subprocess.run(['cp','-cR',old,app],check=True)
binary=app/'Worker'
binary.unlink()
cached = OUT/'SingleEightWorker'
identity = OUT/'identity.json'
inputs = {'driver': HERE/'main.swift', 'candidates': opening/'candidates.csv', 'sourceManifest': opening/'native-source.json'}
archived = OUT/'quick-driver.swift'
if not deep and archived.exists() and identity.exists():
    inputs['driver'] = archived
else:
    inputs['ranker'] = HERE/'DeepSearch.swift'
if deep:
    inputs['seedIdentity'] = OUT.parent/'identity.json'
    inputs['auditDriver'] = HERE/'batch.py'
metadata = {k: hashlib.sha256(path.read_bytes()).hexdigest() for k,path in inputs.items()}
if identity.exists():
    frozen = json.loads(identity.read_bytes())
    assert all(frozen[k] == v for k,v in metadata.items()), "Inputs differ from existing single-eight run"
    assert frozen['binary'] == hashlib.sha256(cached.read_bytes()).hexdigest()
    shutil.copy2(cached,binary)
else:
    sdk = subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
    subprocess.run(['xcrun','swiftc','-O','-whole-module-optimization','-num-threads','4','-D','DEBUG',
                    '-swift-version','5','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator',
                    *sources,HERE/'DeepSearch.swift',HERE/'main.swift','-lz','-o',binary],check=True)
    shutil.copy2(binary,cached)
    metadata['binary'] = hashlib.sha256(binary.read_bytes()).hexdigest()
    identity.write_text(json.dumps(metadata,indent=2))
subprocess.run([sys.executable,ROOT/'scripts/simulator_fleet.py','run','--role','large-pad','--task',HERE.name,'--',sys.executable,HERE/'batch.py','{udid}',binary],check=True)
