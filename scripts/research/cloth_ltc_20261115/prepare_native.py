"""Install the reviewed frozen R3 fixture into the existing research XCTest file."""
import base64
import hashlib
from pathlib import Path

root=Path(__file__).resolve().parents[3]
archive=root/'output/local-test-runs/98e2942ea6ec449bb12b5ef7bf5f7b0a/evidence'
template=Path(__file__).with_name('native_test.swift').read_text()
for marker,file in [('CANDIDATE','integral.surface'),('TABLE0','ltc0.f32'),('TABLE1','ltc1.f32')]:
    template=template.replace('__'+marker+'_BASE64__',base64.b64encode((archive/file).read_bytes()).decode())
template=template.replace('__BASELINE_SHA__',hashlib.sha256((archive/'baseline.surface').read_bytes()).hexdigest())
target=root/'QiuJiTests/ClothSupportPerformanceResearchTests.swift'
text=target.read_text();begin='    // BEGIN GENERATED H18 R6\n';end='    // END GENERATED H18 R6\n'
if begin in text:
    start=text.index(begin);finish=text.index(end,start)+len(end);text=text[:start]+text[finish:]
anchor='    func testNativeClothComputeReuse() throws'
assert text.count(anchor)==1
text=text.replace(anchor,begin+template+end+'\n'+anchor)
target.write_text(text)
print('Updated research-only XCTest fixture',len(template.encode()),'bytes')
