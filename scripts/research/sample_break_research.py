#!/usr/bin/env python3
"""Fixed-control, paired independent-rack study. Screening and holdout seeds are disjoint."""
from __future__ import annotations
import argparse
import json
import math
import statistics
import subprocess
import sys
from pathlib import Path
from analyze_break_research import REPORT, read_rows, summary, effective, write_csv
from break_research import ROOT, OUT, job, write_json

SCREEN_N = 1000
FINAL_N = 10000
CHUNK = 1000


def controls():
    path = OUT / "fixed-controls.json"
    if path.exists():
        return json.loads(path.read_text())["controls"]
    candidates = json.loads((OUT / "candidates.json").read_text())
    rows = read_rows("geometry")
    result = []
    for c in candidates:
        r = next(r for r in rows if r["rackKind"] == "nominal" and r["theta"] == c["theta"]
                 and abs(r["fraction"]-c["fraction"]) < 1e-5)
        result.append(dict(**c, contactSpeed=10, cueX=r["cuePosition"][0], cueZ=r["cuePosition"][2],
                           aimTheta=r["aimTheta"], power=r["power"], spinY=r["spinY"]))
    write_json(path, dict(reference="Nominal symmetric rack with production 0.20 mm gaps; controls frozen once",
                         controls=result, screeningSeeds=[10000,10999], holdoutSeeds=[100000,109999],
                         selection="Largest effective-pot rate in screening; scratch rate breaks ties",
                         primary="At least one ordinary object potted, no cue scratch, settled",
                         paired="Every candidate uses identical independent rack seeds; no execution-error noise"))
    return result


def execute(batch, jobs):
    evidence = OUT / f"{batch}-execution.json"
    if evidence.exists():
        manifest = json.loads(evidence.read_text())
        old = json.loads((OUT/f"{batch}-config.json").read_text())["jobs"]
        if old != jobs or not (manifest["exitCode"] == 0 and manifest["batchComplete"]
                               and manifest["rows"] == len(jobs) and manifest["productionUnchanged"]):
            raise RuntimeError(f"Cannot reuse incomplete, changed, or invalid evidence: {batch}")
        return
    path = OUT/f"{batch}-input.json"
    write_json(path, dict(jobs=jobs))
    subprocess.run([sys.executable, str(ROOT/"scripts/research/break_research.py"), "custom",
                    "--batch", batch, "--config", str(path)], check=True, cwd=ROOT)


def make_jobs(c, phase, seeds, reverse=False):
    fields = {k:v for k,v in c.items() if k != "name"}
    return [job(f"{phase}_{c['name']}_s{s}", mode="execute", seed=s, reverse=reverse,
                trace=phase in ("screen","order") and s==10000, **fields) for s in seeds]


def paired(a, b):
    aa={r["seed"]:r for r in a}; bb={r["seed"]:r for r in b}
    if len(aa)!=len(a) or len(bb)!=len(b) or set(aa)!=set(bb):
        raise RuntimeError("Paired samples must have unique identical rack seeds")
    if summary(a)["unknown"] or summary(b)["unknown"]:
        return dict(n=len(a), unknown=True)
    diffs=[int(effective(bb[s]))-int(effective(aa[s])) for s in sorted(aa)]
    mean=statistics.mean(diffs)
    se=statistics.stdev(diffs)/math.sqrt(len(diffs)) if len(diffs)>1 else 0
    return dict(n=len(diffs), meanDifference=mean, pairedNormal95=[mean-1.95996398454*se,mean+1.95996398454*se],
                improved=diffs.count(1), worsened=diffs.count(-1), identical=diffs.count(0))


def screening():
    records=[]; samples={}
    for c in controls():
        batch=f"screen-{c['name']}"
        execute(batch,make_jobs(c,"screen",range(10000,11000)))
        rows=read_rows(batch); samples[c["name"]]=rows
        records.append(dict(**c,**summary(rows)))
    if any(r["unknown"] for r in records):
        raise RuntimeError("Unresolved screening outcomes; do not select a winner from a filtered subset")
    ranked=sorted([r for r in records if r["name"]!="C0"],key=lambda r:(-r["effectiveRate"],r["scratchRate"],abs(r["theta"])))
    selected=ranked[0]["name"]
    write_json(REPORT/"screening.json",dict(groups=records,selected=selected,
                 paired=[dict(candidate=c["name"],**paired(samples["C0"],samples[c["name"]])) for c in controls()[1:]]))
    write_csv(REPORT/"screening.csv",records)
    write_json(OUT/"holdout-selection.json",dict(names=["C0",selected],screeningN=SCREEN_N,
                 finalN=FINAL_N,reason="Locked before inspecting any holdout outcome"))
    print(json.dumps(dict(selected=selected,groups=records)),flush=True)


def selection():
    names=json.loads((OUT/"holdout-selection.json").read_text())["names"]
    return [c for c in controls() if c["name"] in names]


def audit():
    records=[]
    for c in selection():
        batch=f"order-{c['name']}"
        execute(batch,make_jobs(c,"order",range(10000,11000),reverse=True))
        original=read_rows(f"screen-{c['name']}"); reversed_rows=read_rows(batch)
        changed=sum((a["ordinaryPots"],a["scratch"],a["eight"]) != (b["ordinaryPots"],b["scratch"],b["eight"])
                    for a,b in zip(original,reversed_rows))
        records.append(dict(candidate=c["name"],original=summary(original),reversed=summary(reversed_rows),
                            outcomeChanged=changed,**paired(original,reversed_rows)))
    write_json(REPORT/"order-ensemble-audit.json",records)
    print(json.dumps(records),flush=True)


def holdout():
    chosen=selection()
    for start in range(0,FINAL_N,CHUNK):
        for c in chosen:
            batch=f"holdout-{c['name']}-{start//CHUNK+1:02}"
            execute(batch,make_jobs(c,"holdout",range(100000+start,100000+start+CHUNK)))
        aggregate()


def aggregate():
    records=[]; samples={}
    for c in selection():
        rows=[]; batches=[]
        for i in range(1,FINAL_N//CHUNK+1):
            batch=f"holdout-{c['name']}-{i:02}"
            if not (OUT/f"{batch}-execution.json").exists():
                break
            m=json.loads((OUT/f"{batch}-execution.json").read_text())
            if not (m["exitCode"]==0 and m["batchComplete"] and m["productionUnchanged"]):
                raise RuntimeError(f"Invalid evidence: {batch}")
            rows.extend(read_rows(batch)); batches.append(batch)
        records.append(dict(**c,batches=batches,**summary(rows)))
        samples[c["name"]]=rows
    names=[c["name"] for c in selection()]
    sizes={len(v) for v in samples.values()}
    comparison=paired(samples[names[0]],samples[names[1]]) if len(sizes)==1 and 0 not in sizes else None
    result=dict(complete=sizes=={FINAL_N},groups=records,paired=comparison,
                rule="Fixed N; interim files are progress only, no outcome-dependent stopping",
                modelOnly=True,executionErrorsIncluded=False)
    write_json(REPORT/"holdout.json",result)
    write_csv(REPORT/"holdout.csv",records)
    print(json.dumps(dict(complete=result["complete"],samples=[r["n"] for r in records],paired=comparison)),flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("phase",choices=["screen","audit","holdout","aggregate"])
    REPORT.mkdir(parents=True,exist_ok=True)
    globals()[{"screen":"screening","audit":"audit","holdout":"holdout","aggregate":"aggregate"}[p.parse_args().phase]]()
