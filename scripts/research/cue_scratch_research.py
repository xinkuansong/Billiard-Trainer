#!/usr/bin/env python3
"""V023 production Swift research build/run. Never substitutes Python physics."""
import argparse,hashlib,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/cue-scratch-research-20261004'
DEVICE='CC94EE66-94E2-4E97-80D8-47DBCDFAEB80'
TARGET=ROOT/'QiuJiTests/BreakRackPhysicsTests.swift'
HARNESS=Path(__file__).with_suffix('.swift')
BEGIN=b'\n// BEGIN CUE SCRATCH RESEARCH 20261004\n'
END=b'\n// END CUE SCRATCH RESEARCH 20261004\n'
def write(path,data):
 path.parent.mkdir(parents=True,exist_ok=True)
 temp=path.with_suffix(path.suffix+'.tmp');temp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');temp.replace(path)
def hashes():
 paths=list((ROOT/'QiuJi/Core/Physics').glob('*.swift'))+list((ROOT/'QiuJi/Core/SpatialPhysics').rglob('*.swift'))
 paths += [ROOT/'QiuJi/Core/Scene/AngleSceneCalculator.swift',ROOT/'QiuJi/Core/PositionPlay/PositionPlayShotSolver.swift']
 return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.exists()}
def command(action,selector,log):
 return ['make','-f','scripts/Makefile','test',f'TEST_ACTION={action}',f'DERIVED_DATA={OUT}/DerivedData',f'TEST_LOG={log}',f'TEST_DESTINATION=platform=iOS Simulator,id={DEVICE}', 'TEST_CODE_COVERAGE=NO',f'ONLY_TESTING=QiuJiTests/CueScratchResearchTests/{selector}', 'TEST_BUILD_SETTINGS=SWIFT_OPTIMIZATION_LEVEL=-O OTHER_SWIFT_FLAGS="$(inherited) -D CUE_SCRATCH_QUIET" -parallel-testing-enabled NO -jobs 8']
def build():
 OUT.mkdir(parents=True,exist_ok=True)
 original=TARGET.read_bytes();assert BEGIN not in original
 block=BEGIN+HARNESS.read_bytes()+END
 (OUT/'original-test-source.swift').write_bytes(original)
 (OUT/'compiled-harness.swift').write_bytes(HARNESS.read_bytes())
 write(OUT/'source-before.json',hashes())
 TARGET.write_bytes(original+block)
 try:
  with (OUT/'build-console.log').open('w') as f:r=subprocess.run(command('build-for-testing','test_parallelAndPresentationParity',OUT/'build.log'),cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
 finally:
  current=TARGET.read_bytes();assert current.count(block)==1,'Research fence changed'
  TARGET.write_bytes(current.replace(block,b'',1))
 if r.returncode: raise SystemExit(r.returncode)
 assert hashes()==json.loads((OUT/'source-before.json').read_text()),'Sources changed during build'
 binary=next((OUT/'DerivedData/Build/Products/Debug-iphonesimulator').glob('*.app/PlugIns/QiuJiTests.xctest/QiuJiTests'))
 write(OUT/'compiled.json',dict(sources=hashes(),binary=str(binary),sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),device=DEVICE,harness=hashlib.sha256(HARNESS.read_bytes()).hexdigest()))
 print('BUILD COMPLETE',flush=True)
def run(config=None):
 evidence=json.loads((OUT/'compiled.json').read_text())
 assert hashes()==evidence['sources'],'Frozen source drift'
 assert hashlib.sha256(Path(evidence['binary']).read_bytes()).hexdigest()==evidence['sha256']
 batch=config['batch'] if config else 'preflight'
 assert not (OUT/f'{batch}.log').exists(),'Refuse overwrite'
 if config:write(OUT/'config.json',config);write(OUT/f'{batch}-config.json',config)
 selector='test_runResearchBatch' if config else 'test_parallelAndPresentationParity'
 start=time.monotonic()
 with (OUT/f'{batch}-console.log').open('w') as f:r=subprocess.run(command('test-without-building',selector,OUT/f'{batch}.log'),cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
 log=(OUT/f'{batch}.log').read_text(errors='replace')
 valid=r.returncode==0 and bool(re.search(r'Executed [1-9]\d* test',log)) and f"{selector}]' passed" in log
 write(OUT/f'{batch}-execution.json',dict(exit=r.returncode,executed=valid,wallSeconds=time.monotonic()-start))
 assert valid, f'Batch {batch} failed; inspect log'
 print(batch,'COMPLETE',round(time.monotonic()-start,2),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['build','preflight','run']);p.add_argument('--config',type=Path);args=p.parse_args()
 if args.action=='build':build()
 elif args.action=='preflight':run()
 else:run(json.loads(args.config.read_text()))
