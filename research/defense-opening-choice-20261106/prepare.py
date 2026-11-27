import gzip
import json
import sqlite3
import struct
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/"output"/HERE.name
SIM=ROOT/"output/defense-layout-similarity-20261106"
source=sqlite3.connect(f"file:{ROOT}/output/defense-lambda5-source-filter-20261106/inputs.sqlite3?mode=ro", uri=True)
temporary=OUT/"inputs.tmp"
db=sqlite3.connect(temporary)
db.executescript("CREATE TABLE geom(id INTEGER PRIMARY KEY, points TEXT); CREATE TABLE members(id TEXT PRIMARY KEY,kind TEXT,geom INTEGER);")
keys={}
for kind in ("two_black","two_own","three"):
    with np.load(SIM/f"{kind}-20-guarded.npz") as data:
        m=data["representative"]
    with gzip.open(SIM/f"{kind}-ids.txt.gz","rt") as f:
        reps={s.strip() for i,s in enumerate(f) if m[i]==i}
    for name,cue,objects,own,enemy,static in source.execute("SELECT r.id,b.cue,b.positions,r.own,r.opponent,r.static FROM roles r JOIN boards b ON b.id=r.board WHERE r.kind=? ORDER BY r.id",(kind,)):
        if name not in reps: continue
        balls=json.loads(objects)
        points=[json.loads(cue),balls[own],balls[enemy]]+([balls[static]] if static>=0 else [])
        key=b"".join(struct.pack("<ff",*p) for p in points)
        if key not in keys:
            keys[key]=len(keys)
            db.execute("INSERT INTO geom VALUES(?,?)",(keys[key],json.dumps(points,separators=(",",":"))))
        db.execute("INSERT INTO members VALUES(?,?,?)",(name,kind,keys[key]))
    db.commit()
assert db.execute("SELECT COUNT(*) FROM members").fetchone()[0]==516478
db.execute("CREATE INDEX lookup ON members(geom)")
db.commit()
db.close()
temporary.replace(OUT/"inputs.sqlite3")
print(len(keys),"distinct starting geometries")
