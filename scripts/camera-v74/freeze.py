#!/usr/bin/env python3
"""Capture validated build inputs into a private repository, then seal a commit.
No quiescence assertion is made about the shared checkout; changed files reject
capture. Queue's quiescent flag is used only on the exclusively owned copy.
"""
import sys,json,shutil,subprocess
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from mac_mini_queue import working_files,ROOTS,snapshot,digest
out=Path(sys.argv[1]).resolve();src=out/'private-source';src.mkdir(parents=True)
before=working_files(ROOT,ROOTS)
for rel in before:
 p=src/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,p)
after=working_files(ROOT,ROOTS)
assert before==after,'Concurrent source changed; reject capture'
assert all(digest(src/p)==v['sha256'] for p,v in before.items())
(out/'capture.json').write_text(json.dumps({'baseCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':before},indent=2))
# Private capture has no concurrent writers; normal dirty snapshot is safe here.
subprocess.run(['git','init','-q',str(src)],check=True)
subprocess.run(['git','-C',str(src),'-c','user.name=Codex','-c','user.email=codex@local','commit','--allow-empty','-qm','Camera v74 isolated capture identity'],check=True)
m=snapshot(src,out/'bundle',dirty=True,quiescent=True)
print(json.dumps({'bundle':str(out/'bundle'),'snapshot':m['snapshot_id']}))
