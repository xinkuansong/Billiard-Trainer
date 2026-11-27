"""Cross-tabulate guarded 20 cm representatives with previously computed potential."""
from pathlib import Path
import gzip
import json
import sqlite3

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / Path(__file__).resolve().parent.name
SOURCE = ROOT / "output/defense-lambda5-source-filter-20261106"
db = sqlite3.connect(f"file:{SOURCE}/inputs.sqlite3?mode=ro", uri=True)
db.execute("ATTACH DATABASE ? AS scores", (f"file:{SOURCE}/region-results.sqlite3?mode=ro",))
metrics = []
for kind in ("two_black", "two_own", "three"):
    with np.load(OUT / f"{kind}-20-guarded.npz") as index:
        assignment = index["representative"]
    with gzip.open(OUT / f"{kind}-ids.txt.gz", "rt") as ids:
        chosen = {name.rstrip() for i, name in enumerate(ids) if assignment[i] == i}
    db.execute("CREATE TEMP TABLE selected(id TEXT PRIMARY KEY)")
    db.executemany("INSERT INTO selected VALUES (?)", ((key,) for key in chosen))
    rows = db.execute("""SELECT s.maximum, s.estimated FROM selected q
        JOIN roles r ON r.id=q.id JOIN scores.results s ON r.map=s.id WHERE r.kind=?""", (kind,))
    values = np.array(rows.fetchall())
    assert len(values) == len(chosen) and np.isfinite(values).all() and (values[:,0]>=0).all()
    summary = {"kind":kind, "total":len(chosen), "bands":[]}
    for threshold in (70,75,80,85,90,95):
        keep = values[:,0] >= threshold
        summary["bands"].append({"threshold":threshold, "reached":int(keep.sum()),
                                 "estimatedPeak":int(values[keep,1].sum())})
    metrics.append(summary)
    db.execute("DROP TABLE selected")
db.close()
assert sum(row["total"] for row in metrics) == 516478
(OUT / "potential-20.json").write_text(json.dumps(metrics, indent=2)+"\n")
for row in metrics:
    print(row["kind"],row["total"],[b for b in row["bands"] if b["threshold"] in (85,95)])
