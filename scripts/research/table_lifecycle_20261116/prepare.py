import argparse, importlib.util, json, shutil, subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
p=argparse.ArgumentParser(); p.add_argument('--work',type=Path,required=True); p.add_argument('--evidence',type=Path,required=True)
a=p.parse_args(); a.work=a.work.resolve(); a.evidence=a.evidence.resolve()
spec=importlib.util.spec_from_file_location('queue',REPO/'scripts/mac_mini_queue.py'); q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
src=a.work/'source'
subprocess.run(['git','clone','--shared','--no-checkout',str(REPO),str(src)],check=True)
before=q.working_files(REPO,q.ROOTS)
for rel in before:
    dest=src/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(REPO/rel,dest)
assert before==q.working_files(REPO,q.ROOTS), 'Source changed during copy; reject mixed baseline'
assert before==q.working_files(src,q.ROOTS), 'Copied source mismatch'
(a.evidence/'baseline.json').write_text(json.dumps(before,indent=2))
shutil.copytree(HERE,a.evidence/'research-source',ignore=shutil.ignore_patterns('__pycache__'))
subprocess.run(['python3',HERE/'instrument.py',src],check=True)
after=q.working_files(src,q.ROOTS)
changed={k:{'before':before.get(k),'after':v} for k,v in after.items() if before.get(k)!=v}
for rel in changed:
    dest=a.evidence/'instrumented'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src/rel,dest)
(a.evidence/'instrumentation.json').write_text(json.dumps(changed,indent=2))
# The isolated copy has this task as its only writer; shared workspace is never declared quiescent.
bundle=a.work/'bundle';manifest=q.snapshot(src,bundle,dirty=True,quiescent=True)
(a.evidence/'snapshot-manifest.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps({'work':str(a.work),'bundle':str(bundle),'snapshot':manifest['snapshot_id'],'changed':list(changed)}),flush=True)
