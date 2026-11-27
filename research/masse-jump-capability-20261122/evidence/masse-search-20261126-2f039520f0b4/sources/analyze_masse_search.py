#!/usr/bin/env python3
"""Audit actual simulator packets and draw measured trajectories (no synthetic paths).

Run: uv run --with matplotlib python research/masse-jump-capability-20261122/analyze_masse_search.py
"""
from collections import Counter
import gzip
import json
import math
from pathlib import Path

import run_masse_search as run

HERE = Path(__file__).resolve().parent


def analyze():
    current = json.loads((HERE / "masse-search-current.json").read_text())
    out = Path(current["evidence"])
    request = json.loads((out / "manifest.json").read_text())
    summary = run.summarize(out, request)
    lookup = {x["sampleIndex"]: x for x in request["shapes"]}
    rows = [json.load(gzip.open(p, "rt")) for p in sorted((out / "shapes").glob("*.json.gz"))]
    solved = [r for r in rows if r["status"] == "solved"]
    assert len({r["sampleIndex"] for r in rows}) == len(rows)
    assert run.sha(run.source.INPUT) == request["sourceSampleSHA256"]
    assert run.sha(run.source.BANK) == request["sourceBankSHA256"]
    questions = []
    for row in solved:
        s = row["solution"]
        shape = lookup[row["sampleIndex"]]
        param = s["parameter"]
        assert param in request["parameters"]
        assert param[2] != 0 and param[2]**2 + param[3]**2 <= .64
        assert abs(s["actualContactUpOverR"] - run.source.actual_contact_up(param[2], param[3], param[0])) < 1e-6
        obstacle = s["obstacle"]
        legal = [o for o in run.source.obstacle_candidates(shape) if not o["failures"]]
        assert obstacle in legal and obstacle["directPotLineClearanceMetres"] < -.001
        yaw = s["yawRadians"]
        expected = math.atan2(shape["ghost"]["z"]-shape["cue"]["z"], shape["ghost"]["x"]-shape["cue"]["x"])
        delta = math.atan2(math.sin(yaw-expected), math.cos(yaw-expected))*180/math.pi
        assert abs(delta-s["aimOffsetDegrees"]) < 1e-5
        assert s["trajectory"]["cueBall"] and s["trajectory"]["object"] and s["trajectory"]["obstacle"]
        for name, source in (("cueBall", shape["cue"]), ("object", shape["target"]), ("obstacle", obstacle["center"])):
            first = s["trajectory"][name][0]
            assert math.hypot(first[1]-source["x"], first[3]-source["z"]) < 1e-6
        target_frames = s["trajectory"]["object"]
        origin = target_frames[0]
        first_motion = next(f[0] for f in target_frames if math.hypot(f[1]-origin[1], f[3]-origin[3]) > 1e-6)
        before = [f for f in s["trajectory"]["cueBall"] if f[0] < first_motion]
        a, b = before[0], before[-1]
        chord_gap = run.source.segment_distance(run.source.point(obstacle["center"]), (a[1],a[3]), (b[1],b[3])) - 2*run.source.RADIUS
        # Independent geometric countercheck: a straight line to the recorded
        # last pre-motion contact vicinity also intersects the obstacle.
        assert chord_gap < -.001, "curvature is not demonstrated necessary for this recorded contact"
        questions.append({"id": f"research-masse-{row['sampleIndex']:05d}", "status": "researchCandidate",
                          "sourceSampleIndex": row["sampleIndex"], "sourceLayoutID": shape["sourceLayoutID"],
                          "cue": shape["cue"], "target": shape["target"], "pocket": shape["pocket"],
                          "obstacle": obstacle, "answer": {k: v for k, v in s.items() if k != "trajectory"},
                          "recordedContactChordClearanceMetres": chord_gap,
                          "evidencePacket": f"shapes/{row['sampleIndex']:05d}.json.gz", "runIdentity": request["runIdentity"]})
    with (out / "question-candidates.jsonl").open("w") as f:
        for q in questions:
            f.write(json.dumps(q, ensure_ascii=False, separators=(",", ":")) + "\n")
    audit = {"recordsValidated": len(rows), "positiveRecordsValidated": len(solved),
             "uniqueBaseShapes": len(rows), "sourceHashesMatch": True,
             "complete": len(rows) == len(lookup),
             "diagnostics": dict(sum((Counter(r["diagnostics"]) for r in rows), Counter())),
             "solvedObstacleCells": dict(Counter(f"s={r['solution']['obstacle']['s']},q={r['solution']['obstacle']['q']}" for r in solved)),
             "coverage": {k: dict(Counter(str(r["source"][k]) for r in rows)) for k in ("pocket", "distanceBit", "angleIndex", "railIndex")}}
    audit["solvedByPocket"] = dict(Counter(str(r["source"]["pocket"]) for r in solved))
    audit["unresolvedCategories"] = {
        "noRecordedTargetPot": sum(r["status"] != "solved" and not r["diagnostics"].get("targetPotted", 0) for r in rows),
        "targetPotButNoAcceptedUnobstructedBaseline": sum(r["status"] != "solved" and r["diagnostics"].get("targetPotted", 0)>0 and not r["diagnostics"].get("unobstructedPot", 0) for r in rows),
        "acceptedUnobstructedPotButNoObstacleSolution": sum(r["status"] != "solved" and r["diagnostics"].get("unobstructedPot", 0)>0 for r in rows),
    }
    if solved:
        audit["solvedRanges"] = {
            key: [min(values), max(values)] for key, values in {
                "cueTargetDistanceMetres": [r["source"]["cueTargetDistanceMetres"] for r in solved],
                "elevationDegrees": [r["solution"]["parameter"][0] for r in solved],
                "cueSpeedMetresPerSecond": [r["solution"]["parameter"][1] for r in solved],
                "curveDeviationMillimetres": [1000*r["solution"]["metrics"]["precontactChordDeviationMetres"] for r in solved],
                "obstacleGapMillimetres": [1000*r["solution"]["metrics"]["minimumPrecontactObstacleGapMetres"] for r in solved],
                "cueMaximumHeightMillimetres": [1000*r["solution"]["metrics"]["cueMaximumHeightMetres"] for r in solved],
            }.items()}
    run.atomic(out / "audit.json", audit)
    print(json.dumps(summary, ensure_ascii=False))
    print(json.dumps(audit, ensure_ascii=False))
    if solved:
        plot(solved, out)


def plot(rows, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib import font_manager
    from matplotlib.patches import Circle, Rectangle
    font_manager.fontManager.addfont("/System/Library/Fonts/STHeiti Light.ttc")
    plt.rcParams["font.family"] = font_manager.FontProperties(fname="/System/Library/Fonts/STHeiti Light.ttc").get_name()
    plt.rcParams["axes.unicode_minus"] = False
    # Show largest measured curvature, a second elevation, and a different pocket where possible.
    ordered = sorted(rows, key=lambda r: -r["solution"]["metrics"]["precontactChordDeviationMetres"])
    chosen = [ordered[0]]
    for predicate in (lambda r: r["solution"]["parameter"][0] != chosen[0]["solution"]["parameter"][0],
                      lambda r: r["source"]["pocket"] != chosen[0]["source"]["pocket"]):
        options = [r for r in ordered if r not in chosen and predicate(r)]
        if options:
            chosen.append(options[0])
    for row in ordered:
        if len(chosen) >= 3:
            break
        if row not in chosen:
            chosen.append(row)
    fig, axes = plt.subplots(len(chosen), 2, figsize=(14, 4*len(chosen)), gridspec_kw={"width_ratios": [2.4, 1]}, squeeze=False)
    fig.patch.set_facecolor("#f5f4ef")
    pockets = [(-1.312,-.677),(1.312,-.677),(-1.312,.677),(1.312,.677),(0,-.67596474),(0,.67596474)]
    for (ax, zoom), row in zip(axes, chosen):
        shape, s = row["source"], row["solution"]
        trace = s["trajectory"]
        origin = trace["object"][0]
        # Use the first recorded target motion to split the measured cue path for display.
        contact = next((f[0] for f in trace["object"] if math.hypot(f[1]-origin[1], f[3]-origin[3]) > 1e-6), trace["cueBall"][-1][0])
        before = [f for f in trace["cueBall"] if f[0] <= contact]
        after = [f for f in trace["cueBall"] if f[0] >= contact]
        for panel in (ax, zoom):
            panel.set_facecolor("#166557")
            panel.add_patch(Rectangle((-1.27,-.635), 2.54, 1.27, fill=False, edgecolor="#b28e65", lw=12, zorder=1))
            for x,z in pockets:
                panel.add_patch(Circle((x,z), .043 if x==0 else .042, color="#15251f",zorder=2))
            panel.plot([shape["cue"]["x"],shape["ghost"]["x"]],[shape["cue"]["z"],shape["ghost"]["z"]],color="#f09991",ls="--",lw=1.4,label="原直线进球路线（受阻）")
            panel.plot([f[1] for f in before],[f[3] for f in before],color="white",lw=2.2,label="母球碰撞前")
            panel.plot([f[1] for f in after],[f[3] for f in after],color="#93cdc5",lw=1.2,alpha=.7,label="母球碰撞后")
            panel.plot([f[1] for f in trace["object"]],[f[3] for f in trace["object"]],color="#ffcd55",lw=2,label="目标球")
            obstacle = s["obstacle"]["center"]
            panel.add_patch(Circle((obstacle["x"],obstacle["z"]),2*.028575,fill=False,edgecolor="#efb1a7",ls=":",lw=1.2,label="母球球心禁入区（2R）"))
            for p,color in ((shape["cue"],"white"),(shape["target"],"#ffcd55"),(s["obstacle"]["center"],"#e96565")):
                panel.add_patch(Circle((p["x"],p["z"]),.028575,facecolor=color,edgecolor="#26332c",lw=1,zorder=5))
            panel.set_aspect("equal")
            panel.set_xlabel("X (m)")
            panel.set_ylabel("Z (m)")
        ax.set_xlim(-1.40,1.40); ax.set_ylim(.75,-.75)
        p=s["parameter"];m=s["metrics"]
        ax.set_title(f"球形 {row['sampleIndex']} | 仰角 {p[0]:g}° | 杆速 {p[1]:g} m/s | 打点 ({p[2]:g}, {p[3]:g})",fontsize=10)
        o=s["obstacle"]["center"]
        zoom.set_xlim(o["x"]-.16,o["x"]+.16);zoom.set_ylim(o["z"]+.16,o["z"]-.16)
        zoom.set_title(f"绕障局部放大\n球面间隙 {1000*m['minimumPrecontactObstacleGapMetres']:.2f} mm；弧线偏离 {1000*m['precontactChordDeviationMetres']:.1f} mm",fontsize=10)
    handles, labels = axes[0][0].get_legend_handles_labels()
    fig.legend(handles,labels,loc="lower center",ncol=3,fontsize=9)
    fig.suptitle("扎杆研究候选｜真实模拟轨迹｜2.54 × 1.27 米球桌",fontsize=15)
    fig.tight_layout(rect=(0,.04,1,.96))
    fig.savefig(out / "trajectory-examples.png", dpi=160)
    fig.savefig(out / "trajectory-examples.svg")
    run.atomic(out / "trajectory-examples.json", {"sampleIndexes": [r["sampleIndex"] for r in chosen], "source": "recorded BallFrame positions; no fitted or invented curves"})
    print(out / "trajectory-examples.png")


if __name__ == "__main__":
    analyze()
