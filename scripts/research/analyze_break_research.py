#!/usr/bin/env python3
"""Analyze model-only break trials, retaining incomplete and invalid outcomes."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import csv
import html
import json
import math
from pathlib import Path
import random
import statistics

from break_research import OUT, ROOT, job, write_json

REPORT = ROOT / "output/break-potting-research-20261002"


def read_rows(batch):
    return [r for r in json.loads((OUT / f"{batch}-results.json").read_text()) if "id" in r and "kind" not in r]


def wilson(k, n):
    if not n:
        return [None, None]
    z = 1.95996398454
    c = (k / n + z*z/(2*n)) / (1+z*z/n)
    h = z * math.sqrt(k/n*(1-k/n)/n+z*z/(4*n*n)) / (1+z*z/n)
    return [c-h, c+h]


def effective(r):
    # Execution errors may change the first object legally; that is an observed outcome,
    # not an unknown simulation. Matched-state trials must pass their calibration check.
    contact_ok = bool(r.get("contact")) if r.get("mode") == "execute" else r.get("contactValid",False)
    return bool(r.get("settled") and contact_ok and r.get("ordinaryPots",0)>0 and not r.get("scratch"))


def bootstrap_interval(values, iterations=4000):
    if not values:
        return [None,None]
    rng=random.Random(20261002)
    draws=sorted(statistics.mean(rng.choices(values,k=len(values))) for _ in range(iterations))
    return [draws[int(.025*iterations)],draws[int(.975*iterations)]]


def summary(rows):
    n = len(rows)
    valid = [r for r in rows if r.get("settled") and
             (r.get("mode")=="execute" or r.get("contactValid"))]
    success = sum(effective(r) for r in valid)
    unknown = n-len(valid)
    return dict(n=n, resolved=len(valid), unknown=unknown, successes=success,
                inputInvalid=sum("inputError" in r for r in rows),
                notSettled=sum("inputError" not in r and not r.get("settled") for r in rows),
                contactMismatch=sum(r.get("mode")!="execute" and r.get("settled",False) and not r.get("contactValid",False) for r in rows),
                firstApexRate=sum(r.get("contact",{}).get("firstSlot")==0 for r in valid)/n if n else None,
                effectiveRate=success/n if n else None,
                unknownBounds=[success/n, (success+unknown)/n] if n else [None, None],
                wilson95=wilson(success, n),
                ordinaryPotRate=sum(r.get("ordinaryPots", 0)>0 for r in valid)/n if n else None,
                scratchRate=sum(r.get("scratch", False) for r in valid)/n if n else None,
                eightRate=sum(r.get("eight", False) for r in valid)/n if n else None,
                meanOrdinaryPots=sum(r.get("ordinaryPots", 0) for r in valid)/n if n else None,
                meanMS=statistics.mean(r["computeMS"] for r in rows if "computeMS" in r) if valid else None)


def write_csv(path, records):
    keys = sorted(set().union(*(r.keys() for r in records)))
    with path.open("w") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for r in records:
            w.writerow({k: json.dumps(v) if isinstance(v, (list, dict)) else v for k, v in r.items()})


def pooled_summary(rows):
    result=summary(rows)
    controls={(r.get("theta"),round(r.get("fraction",0),5),r.get("contactSpeed"),r.get("rackKind")) for r in rows}
    if len(controls)>1:
        result["wilson95"]=None
        result["scope"]="Mixed controls and shared racks: pooled fractions describe this experiment, not one break probability"
    return result


def select_candidates(rows):
    groups = defaultdict(list)
    for r in rows:
        if r["rackKind"] == "production":
            groups[(r["theta"], round(r["fraction"], 5))].append(r)
    scores = [(key, summary(value)) for key, value in groups.items()]
    scores.sort(key=lambda item: (-item[1]["effectiveRate"], item[1]["scratchRate"],
                                 -item[1]["meanOrdinaryPots"], abs(item[0][0]), abs(item[0][1])))
    selected = [(0, 0)]
    for key, s in scores:
        if s["unknown"] or any(abs(key[0]-a)<6 and abs(key[1]-b)<0.15 for a, b in selected):
            continue
        selected.append(key)
        if len(selected) == 6:
            break
    candidates = [dict(name=f"C{i}", theta=a, fraction=b) for i, (a, b) in enumerate(selected)]
    write_json(OUT / "candidates.json", candidates)
    jobs = []
    for c in candidates:
        for v in (6, 8, 10, 12):
            for seed in range(101, 133):
                jobs.append(job(f"v_{c['name']}_{v}_s{seed}", theta=c["theta"], fraction=c["fraction"],
                                contactSpeed=v, seed=seed, trace=seed == 101 and v == 10))
    write_json(OUT / "validation-input.json", dict(jobs=jobs))
    return candidates


def diagnostic_jobs(rows):
    bases = [r for r in rows if r["rackKind"] == "production" and r["seed"] == 1 and
             (r["theta"], round(r["fraction"], 4)) in [(0,0),(0,.2),(10,0),(10,.2),(-10,-.2)]]
    jobs=[]
    for base in bases:
        for mode in ("repeat1", "repeat2", "repeat3", "reverse", "mirror"):
            jobs.append(job(f"d_{base['id']}_{mode}", theta=base["theta"], fraction=base["fraction"],
                            seed=1, reverse=mode=="reverse", mirror=mode=="mirror", trace=True))
    write_json(OUT / "diagnostics-input.json", dict(jobs=jobs))


def plot_geometry(rows):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    xs = sorted({round(r["fraction"], 5) for r in rows})
    ys = sorted({r["theta"] for r in rows})
    fig, axes = plt.subplots(1, 3, figsize=(14, 7), constrained_layout=True)
    specifications = [("nominal", "ordinaryPots", "Nominal symmetric rack: ordinary pots", 4),
                      ("production", "effectivePot", "4 production racks: effective-pot fraction", 1),
                      ("production", "scratch", "4 production racks: scratch fraction", 1)]
    for ax, (kind, metric, title, vmax) in zip(axes, specifications):
        image = np.full((len(ys), len(xs)), np.nan)
        for iy, y in enumerate(ys):
            for ix, x in enumerate(xs):
                samples = [r for r in rows if r["rackKind"]==kind and r["theta"]==y and abs(r["fraction"]-x)<1e-5]
                if samples and all(r.get("settled") and r.get("contactValid") for r in samples):
                    image[iy, ix] = statistics.mean(float(r[metric]) for r in samples)
        im = ax.imshow(image, origin="lower", aspect="auto", extent=[xs[0]-.05, xs[-1]+.05, ys[0]-1, ys[-1]+1],
                       vmin=0, vmax=vmax, cmap="viridis" if metric!="scratch" else "magma")
        ax.set_xlabel("Signed impact offset b / ball diameter")
        ax.set_ylabel("Incoming angle relative to rack axis (deg)")
        ax.set_title(title, fontsize=10)
        fig.colorbar(im, ax=ax, shrink=.7)
    fig.suptitle("Exploratory model map: matched 10 m/s impact, zero angular velocity at impact\n"
                 "0.20 mm nominal gaps; n=4 perturbed racks per cell; NOT real-table probabilities", fontsize=12)
    fig.savefig(REPORT / "geometry-map.png", dpi=160)
    fig.savefig(REPORT / "geometry-map.svg")
    plt.close(fig)


def plot_traces(rows, filename="example-trajectories.png"):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    trace_rows = [r for r in rows if "trajectories" in r][:6]
    if not trace_rows:
        return
    fig, axes = plt.subplots(2, 3, figsize=(13, 10), constrained_layout=True)
    for ax, r in zip(axes.flat, trace_rows):
        ax.plot([-1.27,1.27,1.27,-1.27,-1.27],[-.635,-.635,.635,.635,-.635],color="gray")
        for t in r["trajectories"]:
            f = t["frames"]
            ax.plot([p[1] for p in f],[p[2] for p in f],lw=1.3 if t["slot"]==-1 else .6,
                    color="black" if t["slot"]==-1 else None,alpha=.9 if t["slot"]==-1 else .55)
        for i, p in enumerate(r.get("rackPositions", [])):
            ax.add_patch(plt.Circle((p[0],p[2]),.028575,fill=False,color="black",lw=.5))
            ax.text(p[0],p[2],str(i),fontsize=5,ha="center",va="center")
        ax.set_aspect("equal")
        ax.set_title(f"theta={r['theta']} deg; b/D={r['fraction']:.2f}; pots={r['ordinaryPots']}; scratch={r['scratch']}",fontsize=9)
        ax.set_xlabel("SceneKit X (m)"); ax.set_ylabel("SceneKit Z (m)")
    fig.suptitle("Recorded engine trajectories (subsampled for plotting); rack slots labelled")
    fig.savefig(REPORT / filename,dpi=160)
    plt.close(fig)


def execution_jobs(rows):
    # Select one candidate based on the held-out matched-state comparison, retaining baseline.
    groups=defaultdict(list)
    for r in rows:
        groups[(r["theta"],round(r["fraction"],5),r["contactSpeed"])].append(r)
    ranking=sorted(groups.items(),key=lambda item:(-summary(item[1])["effectiveRate"],summary(item[1])["scratchRate"],
                                                    abs(item[0][0]),abs(item[0][1]),item[0][2]))
    winner=ranking[0][0]
    baseline=(0,0,winner[2])
    controls=[]
    for key in dict.fromkeys([baseline,winner]):
        source=next(r for r in rows if (r["theta"],round(r["fraction"],5),r["contactSpeed"])==key)
        controls.append(dict(theta=key[0],fraction=key[1],contactSpeed=key[2],
                             cueX=source["cuePosition"][0],cueZ=source["cuePosition"][2],
                             aimTheta=source["aimTheta"],power=source["power"],spinY=source["spinY"]))
    # Freeze controls from a single reference rack; use entirely new racks and common errors.
    jobs=[]
    rng=random.Random(20261002)
    errors=[]
    for seed in range(1001,1129):
        for replicate in range(4):
            # Chosen scenarios, not measured player distributions.
            errors.append(dict(seed=seed,replicate=replicate,dx=rng.gauss(0,.002),dz=rng.gauss(0,.002),
                               da=rng.gauss(0,.1),dv=rng.gauss(0,.03),ds=rng.gauss(0,.01)))
    for i,c in enumerate(controls):
        for e in errors:
            for condition in ("frozen", "perturbed"):
                if condition == "frozen" and e["replicate"] != 0:
                    continue
                pert=condition=="perturbed"
                jobs.append(job(f"e_C{i}_{condition}_s{e['seed']}_r{e['replicate']}",mode="execute",
                                theta=c["theta"],fraction=c["fraction"],contactSpeed=c["contactSpeed"],seed=e["seed"],
                                cueX=c["cueX"]+(e["dx"] if pert else 0),cueZ=c["cueZ"]+(e["dz"] if pert else 0),
                                aimTheta=c["aimTheta"]+(e["da"] if pert else 0),
                                power=c["power"]*(1+e["dv"] if pert else 1),
                                spinY=c["spinY"]+(e["ds"] if pert else 0)))
    # One frozen trial and four distinct error trials per rack; rack remains the cluster unit.
    write_json(OUT/"execution-controls.json",dict(controls=controls,errors=errors,
                                               warning="Hypothetical independent Gaussian error scenario; no player calibration"))
    write_json(OUT/"execution-input.json",dict(jobs=jobs))
    return controls


def analyze(batch):
    REPORT.mkdir(parents=True,exist_ok=True)
    rows=read_rows(batch)
    write_json(REPORT/f"{batch}-summary.json",pooled_summary(rows))
    grouped=defaultdict(list)
    if batch=="execution":
        for r in rows:
            parts=r["id"].split("_")
            grouped[(parts[1],parts[2])].append(r)
        records=[]
        seed_scores={}
        for key,values in grouped.items():
            by_seed=defaultdict(list)
            for r in values:
                by_seed[r["seed"]].append(float(effective(r)))
            scores={s:statistics.mean(v) for s,v in by_seed.items()}
            seed_scores[key]=scores
            stat=summary(values)
            stat["wilson95"]=None
            stat["clusterBootstrap95"]=bootstrap_interval(list(scores.values()))
            records.append(dict(candidate=key[0],condition=key[1],independentRackClusters=len(scores),**stat))
        paired=[]
        for condition in ("frozen","perturbed"):
            baseline=seed_scores.get(("C0",condition),{})
            for key,scores in seed_scores.items():
                if key[0]=="C0" or key[1]!=condition:
                    continue
                differences=[scores[s]-baseline[s] for s in sorted(set(scores)&set(baseline))]
                paired.append(dict(candidate=key[0],condition=condition,nRackClusters=len(differences),
                                   meanDifference=statistics.mean(differences),clusterBootstrap95=bootstrap_interval(differences)))
        write_json(REPORT/"execution-paired.json",paired)
        write_csv(REPORT/"execution-groups.csv",records)
        write_json(REPORT/"execution-groups.json",records)
        print(json.dumps(dict(groups=records,paired=paired),ensure_ascii=False,indent=2))
        return
    for r in rows:
        grouped[(r["theta"],round(r["fraction"],5),r["contactSpeed"],r["rackKind"])].append(r)
    records=[dict(theta=k[0],fraction=k[1],contactSpeed=k[2],rackKind=k[3],**summary(v)) for k,v in grouped.items()]
    for record in records:
        if record["rackKind"]=="nominal":
            record["wilson95"]=None  # Deterministic reference rack, not a random-rack probability sample.
    write_csv(REPORT/f"{batch}-groups.csv",records)
    if batch=="geometry":
        plot_geometry(rows)
        plot_traces(rows)
        candidates=select_candidates(rows)
        diagnostic_jobs(rows)
        print("Candidates:",json.dumps(candidates))
    elif batch=="validation":
        plot_traces(rows,"validation-trajectories.png")
        print("Frozen execution controls:",json.dumps(execution_jobs(rows)))
    print(json.dumps(pooled_summary(rows),ensure_ascii=False,indent=2))
    print("Top groups:")
    for record in sorted(records,key=lambda r:(-r["effectiveRate"],r["scratchRate"]))[:10]:
        print(json.dumps(record,ensure_ascii=False))


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("batch")
    analyze(p.parse_args().batch)
