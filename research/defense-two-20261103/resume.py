"""Run an already frozen binary when the original fleet role became occupied."""
from pathlib import Path
import hashlib,json,os,subprocess,sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=Path(os.environ['DEFENSE_PILOT_OUTPUT'])
binary=Path(sys.argv[1]);role=sys.argv[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
build=json.loads((OUT/'build.json').read_text())
assert sha(binary)==build['binarySHA256']
if (OUT/'execution.json').exists():
    number=len(list(OUT.glob('execution-attempt-*.json')))+1
    (OUT/f'execution-attempt-{number}.json').write_bytes((OUT/'execution.json').read_bytes())
result=subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role',role,
    '--task','defense-two-resume-20261103','--',sys.executable,str(HERE/'run.py'),'worker','{udid}',str(binary)])
manifest=json.loads((OUT/'source-manifest.json').read_text())
drift=[p for p,h in manifest.items() if sha(ROOT/p)!=h]
(OUT/'execution.json').write_text(json.dumps(dict(exitCode=result.returncode,sourceDrift=drift,
    resumedFrozenBinary=str(binary),binarySHA256=sha(binary),fleetRole=role,
    originalBuildEvidence=build['evidence'],scope='Frozen CLI geometry/physics; no App UI acceptance'),indent=2))
sys.exit(result.returncode)
