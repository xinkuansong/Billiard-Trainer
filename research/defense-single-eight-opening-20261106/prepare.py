"""Group original accuracy starts by both ball positions, rail proximity and pocket directions."""
import gzip
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / (Path(__file__).resolve().parent.name + "-10cm")
sys.path.insert(0, str(ROOT / "research/defense-layout-similarity-20261106"))
from compare import geometry, radius, RAILS, representatives, segment_distance
sys.path.insert(0, str(ROOT / "scripts/training-question-bank"))
from pocket_geometry_filter import layouts


SIMILARITY_METERS = 0.10


def guard_bits(points):
    cue, ball = points[:, 0], points[:, 1]
    bits = []
    for a, b in json.loads(RAILS.read_bytes())["rails"]:
        gap = segment_distance(points, np.array(a), np.array(b)) - radius
        bits.extend((gap <= .01).T)
    # The shared 8 is the target for both players. There is no third-ball obstacle.
    for pocket in geometry["pockets"]:
        axis = np.array(pocket["center"]) - ball
        direction = axis / np.linalg.norm(axis, axis=1)[:, None]
        ghost = ball - 2 * radius * direction
        bits.append(((ghost-cue)*direction).sum(axis=1) > 0)
    return np.packbits(np.stack(bits,axis=1),axis=1)


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    src = ROOT / "QiuJi/Resources/training-grid-bank.json"
    raw = src.read_bytes()
    rows = sorted(layouts(json.loads(raw)), key=lambda r:r[0])
    assert len(rows) == len({r[0] for r in rows}) == 782528
    xy = np.array([[r[1],r[2]] for r in rows])
    labels, distances = representatives(xy,cKDTree(xy.reshape(len(xy),4)),SIMILARITY_METERS,guard_bits(xy))
    assert distances.max() <= SIMILARITY_METERS + 1e-12
    chosen = np.flatnonzero(labels == np.arange(len(rows)))
    weights = np.bincount(labels,minlength=len(rows))
    tmp = OUT / "inputs.tmp"
    tmp.unlink(missing_ok=True)
    with sqlite3.connect(tmp) as db:
        db.execute("CREATE TABLE geom(id INTEGER PRIMARY KEY,points TEXT,sourceID TEXT UNIQUE,originalPocket INT,assigned INT)")
        db.executemany("INSERT INTO geom VALUES(?,?,?,?,?)", ((i,json.dumps(xy[j].tolist()),rows[j][0],rows[j][3],int(weights[j])) for i,j in enumerate(chosen)))
    tmp.replace(OUT/"inputs.sqlite3")
    with gzip.open(OUT/"source-to-representative.tsv.gz","wt") as f:
        f.write("sourceID\trepresentativeID\n")
        f.writelines(f"{r[0]}\t{rows[labels[i]][0]}\n" for i,r in enumerate(rows))
    summary = dict(similarityMeters=SIMILARITY_METERS,inputs=len(rows),representatives=len(chosen),maxBallDistanceMeters=float(distances.max()),sourceSHA256=hashlib.sha256(raw).hexdigest())
    (OUT/"grouping.json").write_text(json.dumps(summary,indent=2))
    print(summary)
