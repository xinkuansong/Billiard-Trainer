"""Resume the verified build after the original fleet role was busy."""
from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/kick-obstacles-20261030'
old=ROOT/'output/local-test-runs/a4e8d8366a2945deaa3e0b325f4ceb9e/work/KBallWorker.app/Worker'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((OUT/'source-binding.json').read_text());assert sha(HERE/'main.swift')==b['entrySHA256']
for x in b['sources']:
 if x['currentProduction']:assert sha(ROOT/x['path'])==x['sha256'],x['path']
assert sha(old)==json.loads((OUT/'build.json').read_text())['executableSHA256']
subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','kick-obstacles-20261030','--',sys.executable,str(HERE/'run.py'),'worker','{udid}',str(old)],check=True)
