#!/usr/bin/env python3
"""Compile the actual shared transformer under Debug and Release; no string emulation."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
work, evidence = (Path(os.environ[k]) for k in ["QIUJI_TEST_WORK","QIUJI_TEST_EVIDENCE"])
owner = (root/"CuePhys/Core/Scene/MobileRailAppearance.swift").read_text()
source = "import Foundation\nimport CryptoKit\n" + owner[owner.index("enum StaticClothRailReuse {"):]
source += '''
let input=try String(contentsOfFile:CommandLine.arguments[1],encoding:.utf8)
let expected=try String(contentsOfFile:CommandLine.arguments[2],encoding:.utf8)
let start=ProcessInfo.processInfo.systemUptime
let first=StaticClothRailReuse.replacing(in:input)
let firstMilliseconds=(ProcessInfo.processInfo.systemUptime-start)*1000
guard let result=first, result==expected,
      StaticClothRailReuse.restoring(in:result)==input,
      StaticClothRailReuse.replacing(in:result)==nil,
      StaticClothRailReuse.replacing(in:input+" ")==nil else {fatalError("Program contract failed")}
print(StaticClothRailReuse.outputSHA256)
print("disabledArgumentRequested=",StaticClothRailReuse.requested(arguments:[StaticClothRailReuse.disableArgument]))
print("firstTransformCPUms=",firstMilliseconds)
'''
(work/"main.swift").write_text(source)
(evidence/"compiled-source.swift").write_text(source)
rows=[]
for configuration in ["Debug","Release"]:
    binary=work/configuration
    command=["xcrun","swiftc","-O","-module-cache-path",str(work/"module-cache"),str(work/"main.swift"),"-o",str(binary)]
    if configuration=="Debug": command += ["-D","DEBUG"]
    subprocess.run(command,check=True)
    result=subprocess.check_output([str(binary),str(root/"output/render-regression-20261126/phone.surface"),
                                   str(root/"output/static-cloth-20261126/B3.surface")],text=True)
    rows.append({"configuration":configuration,"output":result})
(evidence/"program-contract.json").write_text(json.dumps(rows,indent=2)+"\n")
print(json.dumps(rows))
