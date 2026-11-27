"""Compare representative radii on immutable, role-labelled source boards."""
from pathlib import Path
import gzip
import json
import sqlite3
import argparse

import numpy as np
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / Path(__file__).resolve().parent.name
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "output/defense-lambda5-source-filter-20261106/inputs.sqlite3"
TABLE = ROOT / "output/defense-approved-filter-20261104/geometry.json"
RAILS = ROOT / "output/defense-region-adaptive-20261105/geometry.json"
geometry = json.loads(TABLE.read_text())
radius = geometry["radius"]


def segment_distance(points, start, end):
    axis = end - start
    denominator = np.maximum((axis * axis).sum(axis=-1), 1e-20)
    t = np.clip(((points - start) * axis).sum(axis=-1) / denominator, 0, 1)
    return np.linalg.norm(points - (start + t[..., None] * axis), axis=-1)


def signature(points):
    """Conservative coarse review gates: near individual rails, pocket-centre lines."""
    cue, own, opponent = points[:, 0], points[:, 1], points[:, 2]
    bits = []
    for a, b in json.loads(RAILS.read_text())["rails"]:
        gaps = segment_distance(points, np.array(a), np.array(b)) - radius
        bits.extend((gaps <= .01).T)
    obstacles = [own, *points[:, 3:].transpose(1, 0, 2)]
    for pocket in geometry["pockets"]:
        end = np.array(pocket["center"])
        axis = end - opponent
        unit = axis / np.linalg.norm(axis, axis=1)[:, None]
        ghost = opponent - 2 * radius * unit
        clear = ((ghost - cue) * unit).sum(axis=1) > 0
        for obstacle in obstacles:
            clear &= segment_distance(obstacle, opponent, end) >= 2 * radius
            clear &= segment_distance(obstacle, cue, ghost) >= 2 * radius
        bits.append(clear)
    return np.packbits(np.stack(bits, axis=1), axis=1)


def load(source, kind):
    ids, positions = [], []
    for name, cue, balls, own, opponent, stationary in source.execute(
        """SELECT r.id,b.cue,b.positions,r.own,r.opponent,r.static
           FROM roles r JOIN boards b ON r.board=b.id WHERE r.kind=? ORDER BY r.id""",
        (kind,),
    ):
        objects = json.loads(balls)
        positions.append([json.loads(cue), objects[own], objects[opponent]] +
                         ([objects[stationary]] if stationary >= 0 else []))
        ids.append(name)
    return ids, np.array(positions)


def representatives(points, tree, threshold, tags=None):
    # A member always points directly to an actual source representative.
    chosen = np.full(len(points), -1, dtype=np.int32)
    for i, layout in enumerate(points):
        if chosen[i] >= 0:
            continue
        near = np.asarray(tree.query_ball_point(layout.ravel(), threshold, p=np.inf))
        near = near[chosen[near] < 0]
        if tags is not None:
            near = near[(tags[near] == tags[i]).all(axis=1)]
        delta = points[near] - layout
        inside = ((delta * delta).sum(axis=2) <= threshold ** 2).all(axis=1)
        chosen[near[inside]] = i
    assert (chosen >= 0).all() and np.array_equal(chosen[chosen], chosen)
    distances = np.linalg.norm(points - points[chosen], axis=2)
    assert distances.max() <= threshold + 1e-12
    if tags is not None:
        assert np.array_equal(tags, tags[chosen])
    return chosen, distances


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--add-20", action="store_true", help="Extend the existing 10 and 15 cm results")
    extend = parser.parse_args().add_20
    thresholds = (20,) if extend else (10, 15, 20)
    source = sqlite3.connect(f"file:{SOURCE}?mode=ro&immutable=1", uri=True)
    results, examples = [], []
    if extend:
        results = [r for r in json.loads((OUT / "counts.json").read_text()) if r["cm"] in (10, 15)]
        examples = [r for r in json.loads((OUT / "examples.json").read_text()) if r["cm"] in (10, 15)]
        assert len(results) == 12 and len(examples) == 4
    for kind in ["two_black", "two_own", "three"]:
        ids, points = load(source, kind)
        expected = 666150 if kind == "three" else 332886
        assert len(ids) == expected
        tree = cKDTree(points.reshape(expected, -1))
        tags = signature(points)
        id_path = OUT / f"{kind}-ids.txt.gz"
        if extend:
            with gzip.open(id_path, "rt") as stream:
                assert stream.read().splitlines() == ids
        else:
            with gzip.open(id_path, "wt") as stream:
                stream.writelines(name + "\n" for name in ids)
        for cm in thresholds:
            for mode in ("distance", "guarded"):
                selected, distances = representatives(points, tree, cm / 100, tags if mode == "guarded" else None)
                count = int(np.sum(selected == np.arange(expected)))
                results.append(dict(kind=kind, cm=cm, mode=mode, total=expected, retained=count))
                np.savez_compressed(OUT / f"{kind}-{cm}-{mode}.npz", representative=selected)
                print(kind, cm, mode, count, flush=True)
                if mode == "guarded" and kind != "two_own":
                    # At the threshold edge, show a pair with as many visibly moved balls as possible.
                    near = np.flatnonzero(distances.max(axis=1) >= .99 * cm / 100)
                    j = near[np.argmax(distances[near].sum(axis=1))]
                    examples.append(dict(kind=kind, cm=cm, member=ids[j], representative=ids[selected[j]],
                                         a=points[selected[j]].tolist(), b=points[j].tolist(),
                                         distances=(distances[j]*100).tolist()))
    assert sum(row["total"] for row in results if row["cm"] == 10 and row["mode"] == "distance") == 1331922
    (OUT / "counts.json").write_text(json.dumps(results, indent=2))
    (OUT / "examples.json").write_text(json.dumps(examples, indent=2))


if __name__ == "__main__":
    main()
