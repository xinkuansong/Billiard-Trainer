#!/usr/bin/env python3
"""Run the production pure camera test class and v74 contract on macOS XCTest.
This deliberately excludes the UIApplication/SceneKit idle-renderer class.
"""
import subprocess,sys,re,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
kernel=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
existing=(root/'CuePhysTests/P01CameraMotionTests.swift').read_text().split('@MainActor\nfinal class P01CameraIdleTransitionTests')[0]
existing=existing.replace('import SceneKit\n','').replace('import UIKit\n','').replace('@testable import CuePhys\n','')
extra=(root/'scripts/camera-v74/TimingTests.swift').read_text()
count=len(re.findall(r'    func test\w+\(',existing+extra))
main=existing+'\n'+extra+'''
let suite=XCTestSuite(name:"Camera pure contracts")
suite.addTest(XCTestSuite(forTestCaseClass:P01CameraMotionTests.self))
suite.addTest(XCTestSuite(forTestCaseClass:P01CameraTimingV74Tests.self))
suite.run()
let run=suite.testRun!
print("Executed \\(run.executionCount), failures \\(run.totalFailureCount)")
exit(run.totalFailureCount == 0 && run.executionCount == '''+str(count)+''' ? 0 : 1)
'''
(out/'main.swift').write_text(main)
# Standalone compilation uses the same three referenced production constants.
constants=root/'output/camera-speed-diagnosis-20261126/constants.swift'
dev='/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer'
cmd=['xcrun','swiftc','-I',dev+'/usr/lib','-F',dev+'/Library/Frameworks','-L',dev+'/usr/lib',
     '-Xlinker','-rpath','-Xlinker',dev+'/Library/Frameworks','-Xlinker','-rpath','-Xlinker',dev+'/usr/lib',
     str(kernel),str(constants),str(out/'main.swift'),'-o',str(out/'tests')]
(out/'command.json').write_text(json.dumps({'command':cmd,'expected':count,'scope':'macOS pure XCTest, not iOS host'}))
with (out/'compile.log').open('w') as log:result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
if result.returncode:sys.exit(result.returncode)
with (out/'tests.log').open('w') as log:result=subprocess.run([str(out/'tests')],cwd=root,stdout=log,stderr=subprocess.STDOUT)
print(json.dumps({'expected':count,'exit':result.returncode,'evidence':str(out)}))
sys.exit(result.returncode)
