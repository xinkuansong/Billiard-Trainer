"""Build an isolated diagnostic and preserve the exact currently installed binary."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--work', required=True, type=Path)
p.add_argument('--evidence', required=True, type=Path)
p.add_argument('--no-probe', action='store_true')
a = p.parse_args()
repo = Path(__file__).resolve().parents[3]
source = a.work/'source'
source.mkdir()
baseline = Path('/Users/song/Library/Developer/Xcode/DerivedData/QiuJi-dkiuwgqmnxqvwugawchgefntuxxw/Build/Products/Debug-iphoneos/球迹.app')
assert shutil.disk_usage(a.work).free > 8*1024**3
subprocess.run(['cp','-cR',str(baseline),str(a.work/'original.app')],check=True)
for name in ['QiuJi','QiuJiLiveActivity','QiuJiUITests','QiuJiTests','Config','Packages','scripts','QiuJi.xcodeproj']:
    subprocess.run(['cp','-cR',str(repo/name),str(source/name)],check=True)
if not a.no_probe:
    subprocess.run(['python3',str(repo/'scripts/research/topdown_latency_20261115/instrument_device.py'),str(source)],check=True)
files=['QiuJi/Core/Scene/AngleSceneView.swift','QiuJi/Core/Scene/AngleTrainingScene.swift','QiuJi/Core/Scene/CameraRig.swift','QiuJi/Features/PositionPlay/ViewModels/PositionPlayViewModel.swift']
manifest={}
for f in files:
    dest=a.evidence/Path(f).name
    shutil.copy2(source/f,dest)
    manifest[f]=hashlib.sha256(dest.read_bytes()).hexdigest()
(a.evidence/'sources.json').write_text(json.dumps(manifest,indent=2))
cmd=['make','-f',str(source/'scripts/Makefile'),'build-device-profile',f'BUILD_DIR={a.work}']
(a.evidence/'build-command.json').write_text(json.dumps(cmd,indent=2))
with (a.evidence/'build.log').open('w') as log:
    result=subprocess.run(cmd,cwd=source,stdout=log,stderr=subprocess.STDOUT)
(a.evidence/'build-result.json').write_text(json.dumps({'exitCode':result.returncode}))
raise SystemExit(result.returncode)
