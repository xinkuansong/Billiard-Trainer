#!/usr/bin/env python3
"""Compile isolated native fixture via Makefile; always restore owning test file."""
import os,sys,pathlib,subprocess,hashlib,re
root=pathlib.Path(__file__).resolve().parents[2]
out=root/'output/cue-scratch-selection-20261005/topdown-r1'
mode=sys.argv[1]
assert mode in ('stills','export')
fixture=root/'scripts/video/cue-scratch-topdown-cards.swift'
target=root/'QiuJiTests/BreakRackPhysicsTests.swift'
original=target.read_bytes()
block=b'\n// BEGIN SCRATCH_SELECTION NATIVE VIDEO\n'+fixture.read_bytes()+b'\n// END SCRATCH_SELECTION NATIVE VIDEO\n'
env=dict(os.environ,TEST_RUNNER_SCRATCH_SELECTION_VIDEO_DIR=str(out),TEST_RUNNER_SCRATCH_SELECTION_VIDEO_EXPORT='1' if mode=='export' else '0')
args=['make','-f','scripts/Makefile','test',f'DERIVED_DATA={root}/build/DerivedData-cue-scratch-selection-20261005',f'TEST_LOG={out}/{mode}.log','TEST_DESTINATION=platform=iOS Simulator,id=CC94EE66-94E2-4E97-80D8-47DBCDFAEB80','TEST_CODE_COVERAGE=NO','TEST_BUILD_SETTINGS=CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO SWIFT_OPTIMIZATION_LEVEL=-O','ONLY_TESTING=QiuJiTests/CueScratchTopdownCardsTests/testExportCards']
try:
    target.write_bytes(original+block)
    result=subprocess.run(args,cwd=root,env=env,stdout=open(out/f'{mode}-make.log','w'),stderr=subprocess.STDOUT)
finally:
    current=target.read_bytes()
    if current==original+block: target.write_bytes(original)
    elif current.count(block)==1: target.write_bytes(current.replace(block,b''))
    else: raise RuntimeError('Fixture changed; restoration requires review')
(out/'fixture.swift').write_bytes(fixture.read_bytes())
log=(out/f'{mode}.log').read_text()
if result.returncode == 0:
    assert re.search(r'Test Case .*testExportCards.*passed',log), 'No export test passed'
    assert re.search(r'Executed [1-9][0-9]* tests?, with 0 failures',log), 'No successful test count'
print('exit',result.returncode,'log',out/f'{mode}.log',flush=True)
sys.exit(result.returncode)
