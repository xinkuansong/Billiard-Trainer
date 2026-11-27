"""Compile a frozen research runner and audit a finite pilot on a managed simulator."""
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import sys
import time
from pathlib import Path

from prepare import ROOT, HERE, OUT, prepare

LIB=ROOT/"research/defense-lambda5-regeneration-20261106"
OLD=ROOT/"research/defense-rail-sequences-full-20261106"
work=Path(os.environ["QIUJI_TEST_WORK"])
ev=Path(os.environ["QIUJI_TEST_EVIDENCE"])
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
full = "--full" in sys.argv
rollout = "--rollout" in sys.argv or full
if rollout:
    OUT = OUT.parent / ("rollout-full-v2" if full else "rollout-v1")
    OUT.mkdir(parents=True,exist_ok=True)
    if full:
        from prepare import SOURCE, roles, digest
        from rollout_full import prepare_all
        prepare_all(SOURCE, OUT, roles, digest)
    else:
        shutil.copy2(OUT.parent/"inputs.json", OUT/"inputs.json")
else:
    prepare()
src=work/"src"
manifest={}
paths=[]
def stage(name,data):
    dst=src/name
    dst.parent.mkdir(exist_ok=True,parents=True)
    dst.write_bytes(data)
    paths.append(str(dst))
    manifest[str(name)]=sha(dst)
for p in sorted((ROOT/"QiuJi").rglob("*.swift")):
    data=p.read_bytes()
    if b"@main" in data:
        assert p.name=="QiuJiApp.swift"
        data=data.replace(b"@main",b"// research runner supplies main")
    stage(p.relative_to(ROOT),data)
effect=(src/"QiuJi/Features/DefensePractice/DefenseEffect.swift").read_text()
start="        if fullyBlocked(cue, target, blockers) {"
part=start+effect.split(start,1)[1].split("    /// Upper bounds",1)[0]
part=part.replace("var assessment = DefenseAttackAssessment()", "var assessment = windows ?? DefenseAttackAssessment()")
stage("RegionState.swift",("import Foundation\nimport SceneKit\nextension DefenseEffect {\nstatic func regionState(cue:SCNVector3,target:SCNVector3,blockers:[SCNVector3],windows:DefenseAttackAssessment?=nil,opponent:Int=9) throws -> Self {\nvar timing=Timing();let usePrecomputedWindows=false\n"+part+"}\n").encode())
for name in ("DefenseRegionSolver.swift","RegionScan.swift","OwnPotential.swift"):
    stage(name,(LIB/name).read_bytes())
stage("main.swift",((HERE/"rollout-worker.swift") if rollout else (OLD/"main.swift")).read_bytes())
app=work/"OpeningRoutes.app"
app.mkdir()
(app/"Info.plist").write_bytes(plistlib.dumps(dict(CFBundleIdentifier="local.qiuji.opening-routes",CFBundleExecutable="Worker",CFBundlePackageType="APPL")))
resources=ROOT/"QiuJi/Resources"
for name in ("PocketPipe","ModelTrial20261010_CueUV.usdz","ModelTrial20261010_TaiQiuZhuo.usdz","TaiQiuZhuo.usdz","CueStyles","TableMaterials","TableStyles","ClothColors","BallStickers","MobilePocketOcclusion.png","MobilePocketOcclusionBounds.json","MobileRailOcclusion.png","MobileTableSoftbox.hdr"):
    files=list(resources.rglob(name))
    assert len(files)==1,name
    path=files[0]
    if path.is_dir(): shutil.copytree(path,app/name)
    else: shutil.copy2(path,app/name)
for p in sorted(app.rglob("*")):
    if p.is_file(): manifest["app/"+str(p.relative_to(app))]=sha(p)
sdk=subprocess.check_output(["xcrun","--sdk","iphonesimulator","--show-sdk-path"],text=True).strip()
binary=app/"Worker"
with (ev/"build.log").open("w") as log:
    result=subprocess.run(["xcrun","swiftc","-O","-whole-module-optimization","-num-threads","4","-D","DEBUG","-swift-version","5","-sdk",sdk,"-target","arm64-apple-ios17.0-simulator",*paths,"-lz","-o",str(binary)],env=dict(os.environ,SDKROOT=sdk),stdout=log,stderr=subprocess.STDOUT)
if result.returncode: sys.exit((ev/"build.log").read_text()[-4000:])
tools=work/"tools"
tools.mkdir()
for file in (OLD/"controller.py", LIB/"audit.py",HERE/"batch.py", HERE/"rollout_full.py"):
    shutil.copy2(file,tools/file.name)
    manifest[file.name]=sha(tools/file.name)
manifest.update(binary=sha(binary),inputs=sha(OUT/"inputs.json"))
identity=hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()
existing = OUT/"identity.json"
if full and existing.exists():
    raise RuntimeError("Full run already initialized. Resume with its frozen runner and original identity.")
if full:
    frozen = OUT/"runner"
    frozen.mkdir()
    shutil.copytree(app, frozen/app.name)
    shutil.copytree(tools, frozen/"tools")
    binary = frozen/app.name/"Worker"
    tools = frozen/"tools"
(OUT/"identity.json").write_text(json.dumps(dict(identity=identity,files=manifest),indent=2))
role=os.environ.get("DEFENSE_PILOT_ROLE","standard-pad")
fleet=[sys.executable,str(ROOT/"scripts/simulator_fleet.py")]
if full:
    uid=subprocess.check_output([*fleet,"resolve","--role",role],text=True).strip()
    while True:
        devices=json.loads(subprocess.check_output(["xcrun","simctl","list","devices","-j"]))["devices"]
        if any(d["udid"]==uid and d["state"]=="Shutdown" for group in devices.values() for d in group):
            break
        time.sleep(15)
subprocess.run([sys.executable,str(ROOT/"scripts/simulator_fleet.py"),"run","--role",os.environ.get("DEFENSE_PILOT_ROLE","standard-pad"),"--task",HERE.name,"--",sys.executable,str(tools/"batch.py"),"{udid}",str(binary),identity,str(OUT)],check=True)
