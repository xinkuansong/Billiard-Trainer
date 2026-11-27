from pathlib import Path
import json,re,hashlib
p=Path(__file__).resolve().parent
root=p.parents[2]
checks={}
for mode in ['2D','3D']:
 states=[json.loads((p/f'separation-{mode}-{x}-state.json').read_text()) for x in 'ABC']
 def inputs(d):return {k:v for k,v in re.findall(r'(\w+)=([^ ]+)',d['inputs']) if k!='sequenceID'}
 assert inputs(states[0])==inputs(states[1])==inputs(states[2])
 cams=[{key:re.search(key+r'=(SCNVector3\([^)]*\)|[^ ]+)',d['camera']).group(1) for key in ['eye','pivot','yaw','distance','elevation','pitch','fov']} for d in states]
 assert cams[0]==cams[1]==cams[2]
 checks[mode]={'inputs_equal':True,'camera_equal':True,'camera':cams[0]}
(p/'same-condition-check.json').write_text(json.dumps(checks,indent=2))
f=root/'CuePhys/Core/Components/PoolBallFace.swift';s=f.read_text();block=(p/'temporary-block.txt').read_text();assert block in s
f.write_text(s.replace(block,'static let lineMain: Float = 0.0028'))
f=root/'CuePhysUITests/W3_HomeCoverUITests.swift';s=f.read_text();a=s.index('\n// BEGIN TEMPORARY WIDTH45 CAPTURE\n');b=s.index('// END TEMPORARY WIDTH45 CAPTURE\n',a)+len('// END TEMPORARY WIDTH45 CAPTURE\n');f.write_text(s[:a]+s[b:])
before=json.loads((p/'source-before.json').read_text());after={f:{'sha256':hashlib.sha256((root/f).read_bytes()).hexdigest(),'unchanged':hashlib.sha256((root/f).read_bytes()).hexdigest()==sha} for f,sha in before.items()}
(p/'source-after.json').write_text(json.dumps(after,indent=2));assert all(x['unchanged'] for x in after.values())
print('Input and camera match; original source SHA restored.')
