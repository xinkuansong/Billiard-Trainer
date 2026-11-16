"""Compile the production LTC generator and compare its core to frozen R3."""
import json
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[3]
work = Path(os.environ['QIUJI_TEST_WORK'])
evidence = Path(os.environ['QIUJI_TEST_EVIDENCE'])
archive = root / 'output/local-test-runs/98e2942ea6ec449bb12b5ef7bf5f7b0a/evidence'
main = r'''
import Foundation
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let archive=root.appendingPathComponent("output/local-test-runs/98e2942ea6ec449bb12b5ef7bf5f7b0a/evidence")
let baseline=try String(contentsOf:archive.appendingPathComponent("baseline.surface"))
guard let source=ClothSpecularLTC.replacingSpecular(in:baseline) else {fatalError("Production transform rejected exact baseline")}
try source.write(to:URL(fileURLWithPath:CommandLine.arguments[2]),atomically:true,encoding:.utf8)
let frozen=try String(contentsOf:archive.appendingPathComponent("integral.surface"))
func compact(_ s:String)->String {s.filter{!$0.isWhitespace}}
let oldStart=baseline.range(of:"for(int panel=0;panel<2;++panel) {",options:.backwards)!
let oldEnd=baseline.range(of:"E=temporalFieldDiffuse",range:oldStart.upperBound..<baseline.endIndex)!
let oldLoop=String(baseline[oldStart.lowerBound..<oldEnd.lowerBound])
precondition(source.contains(oldLoop),"Original integrator retained exactly")
let frozenStart=frozen.range(of:"float3 h18T=v-n*dot(n,v);")!
let frozenEnd=frozen.range(of:"}else{\nfor(int panel=0;panel<2;++panel) {",range:frozenStart.upperBound..<frozen.endIndex)!
let originalBody=String(frozen[frozenStart.lowerBound..<frozenEnd.lowerBound]).replacingOccurrences(of:"_surface.roughness",with:"roughness")
let functionStart=source.range(of:"float3 h18T=v-n*dot(n,v);")!
let functionEnd=source.range(of:"return {E,unoccludedE,S};",range:functionStart.upperBound..<source.endIndex)!
precondition(compact(originalBody)==compact(String(source[functionStart.lowerBound..<functionEnd.lowerBound])),"LTC core unchanged by function extraction")
precondition(ClothSpecularLTC.requested(arguments:[]))
#if DEBUG
precondition(!ClothSpecularLTC.requested(arguments:[ClothSpecularLTC.disableArgument]))
#else
precondition(ClothSpecularLTC.requested(arguments:[ClothSpecularLTC.disableArgument]))
#endif
precondition(ClothSpecularLTC.replacingSpecular(in:baseline+" ")==nil)
precondition(ClothSpecularLTC.replacingSpecular(in:source)==nil)
print("Production integrators match frozen R3 and C1/H9; source guards and default passed")
'''
(work / 'main.swift').write_text(main)
sources = [root / 'QiuJi/Core/Scene/StaticClothIrradiance.swift', root / 'QiuJi/Core/Scene/ClothSpecularLTC.swift']
for p in sources:
    shutil.copy2(p, evidence / p.name)
shutil.copy2(work / 'main.swift', evidence / 'main.swift')
for label, flags in [('debug', ['-D', 'DEBUG']), ('release', [])]:
    with (evidence / (label+'-compile.log')).open('w') as log:
        subprocess.run(['xcrun', 'swiftc', '-O', *flags, *map(str, sources), str(work / 'main.swift'), '-o', str(work / 'preflight')], stdout=log, stderr=subprocess.STDOUT, check=True)
    subprocess.run([str(work / 'preflight'), str(root), str(evidence / 'production.surface')], check=True)
(evidence / 'result.json').write_text(json.dumps({'coreMatchesFrozenR3': True, 'sourceDriftRejected': True}) + '\n')
